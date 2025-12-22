--!strict
-- annotater.lua @ ReplicatedStorage.util.annotater
-- Provides structured annotate helpers for startup diagnostics.
-- Tracks completion of registered scripts to surface slow loaders in testing.

local errorReporting = require(game.ReplicatedStorage.util.errorReporting)
local lua2Json = require(game.ReplicatedStorage.util.lua2Json)
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local debugInfo = if debug then debug.info else nil

type ScriptLike = Script | ModuleScript | LocalScript | LuaSourceContainer
type EmitFn = (string) -> ()
type AnnotateFn = (string, any?, boolean?) -> ()
type ProfileFn = (string, () -> ()) -> ()
type Module = {
	Error: (string, any?) -> (),
	Init: () -> (),
	getAnnotater: (ScriptLike, EmitFn?) -> AnnotateFn,
	Profile: ProfileFn,
	SetContextMetadataEnabled: (boolean) -> (),
}

local function deepToString(obj: any, indent: any): string
	indent = indent or 0
	local result = ""
	if type(obj) == "table" then
		result = result .. "{\n"
		for k, v in pairs(obj) do
			result = result .. string.rep("  ", indent + 1)
			if type(k) == "string" then
				result = result .. string.format("[%q] = ", k)
			else
				result = result .. string.format("[%s] = ", tostring(k))
			end
			result = result .. deepToString(v, indent + 1) .. ",\n"
		end
		result = result .. string.rep("  ", indent) .. "}"
	else
		local stringObj = lua2Json.Lua2StringTable(obj)
		result = result .. tostring(stringObj)
	end
	return result
end

local module: Module = {
	Error = function(message: string, payload: any?)
		local formattedPayload = ""
		if payload ~= nil then
			if type(payload) == "table" then
				formattedPayload = "\n" .. deepToString(payload, 0)
			else
				formattedPayload = " " .. tostring(payload)
			end
		end
		warn(string.format("annotater.Error before Init: %s%s", message, formattedPayload))
	end,
	Init = function(): ()
		return
	end,
	getAnnotater = function(_: ScriptLike, _: EmitFn?): AnnotateFn
		error("annotater.getAnnotater is not initialised")
		return function()
			return
		end
	end,
	Profile = function(label: string, fn: () -> ())
		error("annotater.Profile is not initialised")
	end,
	SetContextMetadataEnabled = function(_: boolean): ()
		return
	end,
}

local function defaultEmit(message: string)
	print(message)
end

local INCLUDE_CONTEXT_METADATA = false
local showAllRegardless = false
local badScriptPatterns = {}
local goodScriptPatterns = {
	-- "warper",
	-- "activeRunSGui",
	-- Widget system logging (disable in prod by moving to silencedScriptPatterns)
	-- "widgetComposer",
	-- "runWidgetPicker",
	-- "widget*Widgets", -- timerWidgets, speedWidgets, etc.
	-- Debug: LB sizing issue
	-- "leaderboard",
}
local silencedScriptPatterns = {
	"settingsServer",
	"chatService",
	"Commands",
	"channelManager",
	"serverBootstrap",
	"*Command",
	"workspaceRemoteSetup",
	"presence",

	"messageDispatcher",
	"Animate",
	"hamburger",
	"*Button",
	"chat",
	"receiveClientEventServer",
	"registerCommands",
	"tpUtil",
	"guiUtil",
	"thumbnails",
	"colors",
	"settingEnums",
	"popularRaces",
	"grantBadge",
	"lbUpdateServer",
	"badgeEnums",
	"banning",
	"messageFormatter",
	"setupFindTouchMonitoring",
	"sounds",
	"pushSigns",
	"marathon",
	"ephemeralMarathon",
	"newRaces",
	"contest",
	"Animate",
	"localRdb",
	"drawFavoritesModal",
	"marathon*",
	"*Sign",
	"HandleClientMessages",
	"userDataClient",

	"keyboard",
	"leaderboard",
	"particles",
	"uiPositionManager",
	"leaderboard*",
	"textHighlighting",
	"leaderboardGui",
	"windowFunctions",
	"chatClient",
	"badges",
	"userDataServer",
	"notifyClient",
	"serverEvents",
	"marathonClient",
	"pickle*",
	"settings",
	"playerData2",
	"shiftLock",
	"rdb",
	"racing",
	"warper",
}
-- Uncomment to enable logging for ALL scripts (useful for debugging):
-- goodScriptPatterns = { "" }

-- if RunService:IsStudio() or config.IsTestGame() then
-- 	showAllRegardless = true
-- end

local scriptAliases = { LocalScript = "local", ModuleScript = "module", Script = "script" }
local startTick = tick()
local scriptRegistry: { [string]: ScriptLike } = {}
local scriptPathToName: { [string]: string } = {}
local innitted = false
local contextCache: { [ScriptLike]: string } = {}
local instanceIdCache: { [ScriptLike]: string } = {}
local nextInstanceSerial = 1

-- print("starting run with the following configuration settings:")
-- print("goodScriptPatterns: " .. table.concat(goodScriptPatterns, ", "))
-- print("silencedScriptPatterns: " .. table.concat(silencedScriptPatterns, ", "))
-- print("showAllRegardless: " .. tostring(showAllRegardless))

local function matchWildcard(pattern: string, value: string): boolean
	local luaPattern = "^" .. string.gsub(pattern, "%%", "%%%%"):gsub("%*", ".*") .. "$"
	return string.match(string.lower(value), string.lower(luaPattern)) ~= nil
end

local function formatContainerPath(script: ScriptLike): string
	local ancestryParts = {}
	local currentParent = script.Parent
	while currentParent do
		if currentParent.ClassName == "DataModel" or currentParent.Name == "Game" then
			break
		end
		table.insert(ancestryParts, 1, currentParent.Name)
		currentParent = currentParent.Parent
	end

	table.insert(ancestryParts, script.Name)
	local path = table.concat(ancestryParts, ".")
	path = path:gsub("ServerScriptService", "sss")
		:gsub("ReplicatedStorage", "rs")
		:gsub("StarterCharacterScripts", "scs")
		:gsub("StarterPlayerScripts", "sps")
		:gsub("StarterPlayer", "sp")
		:gsub("PlayerScripts", "ps")
		:gsub("Workspace.TerrainParkour", "workspace.me")
		:gsub("Players.TerrainParkour", "players.me")

	return path
end

local function safeGetFullName(target: ScriptLike): string
	local ok, fullName = pcall(function()
		return target:GetFullName()
	end)
	if ok and typeof(fullName) == "string" then
		return fullName
	end
	return "unknown"
end

local function matchesPatternList(patterns: { string }, targetName: string): boolean
	for _, pattern in ipairs(patterns) do
		if matchWildcard(pattern, targetName) then
			return true
		end
	end
	return false
end

-- Returns:
-- 1. allowed (boolean): Whether annotations should be displayed for this script
-- 2. blockedByBadPattern (boolean): Whether this script is explicitly blocked (overrides all other settings)
local function shouldAllowAnnotations(target: ScriptLike): (boolean, boolean)
	-- Always respect explicit block list
	if matchesPatternList(badScriptPatterns, target.Name) then
		return false, true
	end

	if showAllRegardless then
		return true, false
	end

	if matchesPatternList(goodScriptPatterns, target.Name) then
		return true, false
	end

	return false, false
end

local function isSilencedScript(target: ScriptLike): boolean
	return matchesPatternList(silencedScriptPatterns, target.Name)
end

local function describeExecutionRealm(): string
	if RunService:IsServer() then
		if RunService:IsStudio() then
			return "studio-server"
		end
		return "live-server"
	end

	if RunService:IsStudio() then
		return "studio-client"
	end
	return "live-client"
end

local function getShortId(value: string, fallback: string): string
	if value == "" then
		return fallback
	end
	if #value <= 8 then
		return value
	end
	return string.sub(value, 1, 8)
end

local function resolveLocalPlayerName(): string
	if RunService:IsServer() then
		return "n/a"
	end
	local ok, player = pcall(function()
		return Players.LocalPlayer
	end)
	if ok and player then
		return player.Name
	end
	return "unknown"
end

local function getOrAssignInstanceId(target: ScriptLike): string
	local existing = instanceIdCache[target]
	if existing then
		return existing
	end
	local id = string.format("ctx%04d", nextInstanceSerial)
	nextInstanceSerial += 1
	instanceIdCache[target] = id
	return id
end

local function describeScriptContext(target: ScriptLike): string
	local cached = contextCache[target]
	if cached then
		return cached
	end

	local parts = {}
	table.insert(parts, describeExecutionRealm())
	table.insert(parts, "job=" .. getShortId(tostring(game.JobId or ""), RunService:IsStudio() and "studio" or "local"))
	table.insert(parts, "id=" .. getOrAssignInstanceId(target))

	if RunService:IsServer() then
		local privateServerId = tostring(game.PrivateServerId or "")
		if privateServerId ~= "" then
			table.insert(parts, "ps=" .. getShortId(privateServerId, "ps"))
		end
	else
		table.insert(parts, "player=" .. resolveLocalPlayerName())
	end

	table.insert(parts, "path=" .. formatContainerPath(target))
	table.insert(parts, "full=" .. safeGetFullName(target))
	local descriptor = table.concat(parts, "|")
	contextCache[target] = descriptor
	return descriptor
end

local function registerScript(target: ScriptLike): string
	local scriptType = scriptAliases[target.ClassName] or target.ClassName
	local scriptName = target.Name
	local path = formatContainerPath(target)

	-- Check if this exact script path has already been registered
	local existingName = scriptPathToName[path]
	if existingName then
		return existingName
	end

	-- Check for duplicate script names at different paths
	if scriptRegistry[scriptName] then
		local existingScript = scriptRegistry[scriptName]
		local existingPath = formatContainerPath(existingScript)
		if existingPath ~= path then
			error(
				string.format(
					"Duplicate script name detected: '%s'\n  First: %s\n  Second: %s\nScript names must be unique for accurate profiling.",
					scriptName,
					existingPath,
					path
				)
			)
		end
	end

	scriptRegistry[scriptName] = target
	scriptPathToName[path] = scriptName

	if scriptType == "local" then
		-- Always include time since game start in output, format matches main annotate
		print(string.format("%0.3f %-25s %s %s", tick() - startTick, scriptName, scriptType, path))
	end

	return scriptName
end

local suppressedSimpleLabels = {
	["end"] = true,
	["init"] = true,
}

local function normalizeLabel(label: string): string
	local trimmed = string.gsub(label, "^%s+", "")
	trimmed = string.gsub(trimmed, "%s+$", "")
	return trimmed
end

local function shouldSuppressLabel(label: string): boolean
	local normalized = normalizeLabel(label)
	if suppressedSimpleLabels[normalized] then
		return true
	end
	-- ignore bare "module" or "local" path echoes like "local players.me.ps.chatClient"
	if normalized == "" then
		return false
	end
	-- Heuristic: hide labels that look like raw context paths without verbs.
	if string.match(normalized, "^local%s") then
		return true
	end
	return false
end

local function createAnnotater(target: ScriptLike, emitterOverride: EmitFn?): AnnotateFn
	local scriptName = registerScript(target)
	local allowAnnotation, blockedByBadPattern = shouldAllowAnnotations(target)
	local isSilenced = isSilencedScript(target)
	local emit: EmitFn = emitterOverride or defaultEmit
	return function(label: string, payload: any?, forceStudioVisibility: boolean?)
		-- Defensive: convert label to string if it's not already
		if type(label) ~= "string" then
			if label == nil then
				label = "nil"
			else
				label = tostring(label)
			end
		end

		-- Always respect badScriptPatterns, even when showAllRegardless is true
		if blockedByBadPattern then
			return
		end

		local allowOutput = allowAnnotation
		local silenced = isSilenced

		if forceStudioVisibility == true then
			if RunService:IsStudio() then
				allowOutput = true
				silenced = false
			else
				allowOutput = false
			end
		end

		if not allowOutput then
			return
		end

		if shouldSuppressLabel(label) then
			return
		end

		if silenced then
			return
		end

		local suffix = ""
		if payload ~= nil then
			suffix = "\n" .. deepToString(payload, 0)
		end

		-- Always include time since game start in output
		local annotatedLabel = label
		if INCLUDE_CONTEXT_METADATA then
			local descriptor = describeScriptContext(target)
			annotatedLabel = string.format("[%s] %s", descriptor, label)
		end
		if debugInfo then
			local callerLine = debugInfo(2, "l")
			if typeof(callerLine) == "number" then
				annotatedLabel = string.format("%s:%d %s", scriptName, callerLine, annotatedLabel)
			end
		end
		emit(string.format("%0.3f %-25s %s%s", tick() - startTick, scriptName, annotatedLabel, suffix))
	end
end

local function createProfiler(): ProfileFn
	return function(_label: string, fn: () -> ())
		fn()
	end
end

local function init()
	if innitted then
		return
	end
	innitted = true

	errorReporting.Init()
	module.Error = errorReporting.Error
	module.Profile = createProfiler()
end

module.Init = init
module.getAnnotater = createAnnotater
module.SetContextMetadataEnabled = function(enabled: boolean)
	INCLUDE_CONTEXT_METADATA = enabled
end

local _annotate: AnnotateFn = module.getAnnotater(script)
_annotate("end")

return module
