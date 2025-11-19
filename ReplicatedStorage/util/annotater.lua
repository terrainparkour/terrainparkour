--!strict
-- annotater.lua @ ReplicatedStorage.util.annotater
-- Provides structured annotate helpers for startup diagnostics.
-- Tracks completion of registered scripts to surface slow loaders in testing.

local config = require(game.ReplicatedStorage.config)
local errorReporting = require(game.ReplicatedStorage.util.errorReporting)
local lua2Json = require(game.ReplicatedStorage.util.lua2Json)

type ScriptLike = Script | ModuleScript | LocalScript | LuaSourceContainer
type AnnotateFn = (string, any?) -> ()
type ProfileFn = (string, () -> ()) -> ()
type Module = {
	Error: (string, any?) -> (),
	Init: () -> (),
	getAnnotater: (ScriptLike) -> AnnotateFn,
	Profile: ProfileFn,
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
	getAnnotater = function(_: ScriptLike): AnnotateFn
		error("annotater.getAnnotater is not initialised")
		return function()
			return
		end
	end,
	Profile = function(label: string, fn: () -> ())
		error("annotater.Profile is not initialised")
	end,
}

local showAllRegardless = false
local badScriptPatterns = {
	"*movement*",
	"*thumbnails*",
	"avatarEventFiring",
	"*badge*",
	"*Badge*",
	"*leaderboard*",
	"*Leaderboard*",
	"*marathon*",
	"*Marathon*",
	"*race*",
	"*Race*",
	"*run*",
	"*Run*",
	"*presence*",
	"*Presence*",
	"*warp*",
	"*Warp*",
	"*avatar*",
	"*Avatar*",
	"*morph*",
	"*Morph*",
	"*thumbnail*",
	"*Thumbnail*",
	"*click*",
	"*Click*",
	"*command*",
	"*Command*",
	"*chat*",
	"*Chat*",
	"*channel*",
	"*Channel*",
	"*message*",
	"*Message*",
	"serverBootstrap",
	"adminWarpCommand",
	"main",
	"notify",
	"userDataServer",
	"serverEvents",
	"receiveClientEventServer",
}
local goodScriptPatterns = {
	-- Sign find system
	-- "setupFindTouchMonitoring",
	-- "*Find*",
	-- "*find*",
	-- "drawFindGui",
	-- "notifyClient",
	-- "userFoundSign",
	-- "UserFoundSign",
	-- Scrolling frame debugging
	"*scrolling*",
	"*Scrolling*",
	"stickyScrollingFrame",
}
-- Uncomment to enable logging for ALL scripts (useful for debugging):
-- goodScriptPatterns = { "" }

if config.IsTestGame() then
	showAllRegardless = true
end

if config.IsInStudio() then
	-- table.insert(goodScriptPatterns, "*leaderboard*")
	-- table.insert(goodScriptPatterns, "rdb")
	-- table.insert(goodScriptPatterns, "receiveClientEventServer")
	-- table.insert(goodScriptPatterns, "morphs")
	-- table.insert(goodScriptPatterns, "*avatarM*")
	-- table.insert(goodScriptPatterns, "keyboard")
	-- table.insert(goodScriptPatterns, "*warp*")
	-- table.insert(goodScriptPatterns, "*marathon*")
end

local scriptAliases = { LocalScript = "local", ModuleScript = "module", Script = "script" }
local startTick = tick()
local totalDone: { [string]: boolean } = {}
local scriptRegistry: { [string]: ScriptLike } = {}
local scriptPathToName: { [string]: string } = {}
local profiledSteps: { { label: string, elapsed: number, startTime: number } } = {}
local requireTimings: { [string]: { requireStart: number, requireEnd: number? } } = {}
local innitted = false
local STARTUP_PROFILING_ENABLED = config.STARTUP_PROFILING_ENABLED

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

local function shouldAnnotateScript(target: ScriptLike): boolean
	-- Check goodScriptPatterns first - if it matches, allow it regardless of bad patterns
	for _, pattern in ipairs(goodScriptPatterns) do
		if matchWildcard(pattern, target.Name) then
			return true
		end
	end

	-- Then check badScriptPatterns - if it matches, filter it out
	for _, pattern in ipairs(badScriptPatterns) do
		if matchWildcard(pattern, target.Name) then
			return false
		end
	end

	return false
end

local function registerScript(target: ScriptLike): string
	local scriptType = scriptAliases[target.ClassName] or target.ClassName
	local scriptName = target.Name
	local path = formatContainerPath(target)

	-- Check if this exact script path has already been registered
	local existingName = scriptPathToName[path]
	if existingName then
		requireTimings[existingName] = { requireStart = tick() }
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
	requireTimings[scriptName] = { requireStart = tick() }

	if scriptType == "local" then
		-- Always include time since game start in output, format matches main annotate
		print(string.format("%0.3f %-25s %s %s", tick() - startTick, scriptName, scriptType, path))
	end

	return scriptName
end

local function createAnnotater(target: ScriptLike): AnnotateFn
	local scriptName = registerScript(target)
	local isBlocked = not shouldAnnotateScript(target)
	local allowAnnotation = showAllRegardless or shouldAnnotateScript(target)
	totalDone[scriptName] = false

	return function(label: string, payload: any?)
		-- Defensive: convert label to string if it's not already
		if type(label) ~= "string" then
			if label == nil then
				label = "nil"
			else
				label = tostring(label)
			end
		end

		-- Always respect badScriptPatterns, even when showAllRegardless is true
		if isBlocked and not STARTUP_PROFILING_ENABLED then
			return
		end

		if label == "end" then
			totalDone[scriptName] = true
			if STARTUP_PROFILING_ENABLED then
				local timing = requireTimings[scriptName]
				if timing then
					timing.requireEnd = tick()
					local requireEnd = timing.requireEnd
					if requireEnd then
						local _elapsed = requireEnd - timing.requireStart
						-- print(string.format("%0.3f %-25s require complete (%.3fs)", tick() - startTick, scriptName, _elapsed))
					end
				end
			end

			if not allowAnnotation and not showAllRegardless then
				return
			end
		end

		if not allowAnnotation and not STARTUP_PROFILING_ENABLED and not showAllRegardless then
			return
		end

		local suffix = ""
		if payload ~= nil then
			suffix = "\n" .. deepToString(payload, 0)
		end

		-- Always include time since game start in output
		print(string.format("%0.3f %-25s %s%s", tick() - startTick, scriptName, label, suffix))
	end
end

local function createProfiler(): ProfileFn
	return function(label: string, fn: () -> ())
		if not STARTUP_PROFILING_ENABLED then
			fn()
			return
		end

		local start = tick()
		local startTime = start - startTick
		print(string.format("%0.3f %-25s %s", startTime, "profiler", label .. " start"))

		local success = pcall(fn)
		local elapsed = tick() - start

		table.insert(profiledSteps, { label = label, elapsed = elapsed, startTime = startTime })

		if success then
			print(string.format("%0.3f %-25s %s (%.3fs)", tick() - startTick, "profiler", label .. " done", elapsed))
		else
			module.Error(string.format("%s failed after %.3fs", label, elapsed))
			error(string.format("%s failed", label))
		end
	end
end

local function printStartupSummary()
	if not STARTUP_PROFILING_ENABLED then
		return
	end

	local totalElapsed = tick() - startTick

	print("\n" .. string.rep("=", 80))
	print("STARTUP ANALYSIS - Total time: " .. string.format("%.3fs", totalElapsed))
	print(string.rep("=", 80))

	-- Show critical path timeline
	if #profiledSteps > 0 then
		print("\n>> CRITICAL PATH (when each operation started):")
		print(string.rep("-", 80))

		-- Sort by start time to show execution order
		local timelineSteps = {}
		for _, step in ipairs(profiledSteps) do
			table.insert(timelineSteps, step)
		end
		table.sort(timelineSteps, function(a, b)
			return a.startTime < b.startTime
		end)

		for i, step in ipairs(timelineSteps) do
			local bar = string.rep("█", math.floor(step.elapsed * 10))
			print(string.format("  %6.3fs  %-45s %6.3fs %s", step.startTime, step.label, step.elapsed, bar))
		end

		-- Calculate gaps between operations (idle time)
		local gapTime = 0
		for i = 2, #timelineSteps do
			local prevEnd = timelineSteps[i - 1].startTime + timelineSteps[i - 1].elapsed
			local currentStart = timelineSteps[i].startTime
			local gap = currentStart - prevEnd
			if gap > 0.001 then
				gapTime = gapTime + gap
			end
		end

		local profiledTime = 0
		for _, step in ipairs(profiledSteps) do
			profiledTime = profiledTime + step.elapsed
		end

		print(string.rep("-", 80))
		print(string.format("  Profiled operations: %.3fs", profiledTime))
		print(string.format("  Gaps between Inits:  %.3fs  (require time, sync work)", gapTime))
		print(string.format("  Total startup:       %.3fs", totalElapsed))
	end

	-- Show slowest operations
	if #profiledSteps > 0 then
		print("\n>> SLOWEST OPERATIONS:")
		print(string.rep("-", 80))

		local sortedByDuration = {}
		for _, step in ipairs(profiledSteps) do
			table.insert(sortedByDuration, step)
		end
		table.sort(sortedByDuration, function(a, b)
			return a.elapsed > b.elapsed
		end)

		local profiledTime = 0
		for _, step in ipairs(profiledSteps) do
			profiledTime = profiledTime + step.elapsed
		end

		for i = 1, math.min(10, #sortedByDuration) do
			local step = sortedByDuration[i]
			local pct = (step.elapsed / profiledTime) * 100
			print(string.format("  %2d. %-50s %6.3fs (%5.1f%%)", i, step.label, step.elapsed, pct))
		end

		if #sortedByDuration > 10 then
			local remainingTime = 0
			for i = 11, #sortedByDuration do
				remainingTime = remainingTime + sortedByDuration[i].elapsed
			end
			local remainingPct = (remainingTime / profiledTime) * 100
			print(
				string.format(
					"  ... %d more operations%s%6.3fs (%5.1f%%)",
					#sortedByDuration - 10,
					string.rep(" ", 36),
					remainingTime,
					remainingPct
				)
			)
		end
	end

	-- Show slowest require times
	print("\n>> SLOWEST SCRIPT LOADS (require time):")
	print(string.rep("-", 80))

	local requireList = {}
	for scriptName, timing in pairs(requireTimings) do
		if timing.requireEnd then
			local elapsed = timing.requireEnd - timing.requireStart
			table.insert(requireList, { name = scriptName, elapsed = elapsed })
		end
	end

	table.sort(requireList, function(a, b)
		return a.elapsed > b.elapsed
	end)

	for i = 1, math.min(10, #requireList) do
		local item = requireList[i]
		print(string.format("  %2d. %-50s %6.3fs", i, item.name, item.elapsed))
	end

	if #requireList > 10 then
		local remainingTime = 0
		for i = 11, #requireList do
			remainingTime = remainingTime + requireList[i].elapsed
		end
		print(string.format("  ... %d more scripts%s%6.3fs", #requireList - 10, string.rep(" ", 39), remainingTime))
	end

	print("\n" .. string.rep("=", 80))
	print("The gap between operations shows require overhead and synchronous work.")
	print("Optimize the items that START late (they block everything after them).")
	print(string.rep("=", 80) .. "\n")
end

local function init()
	if innitted then
		return
	end
	innitted = true

	errorReporting.Init()
	module.Error = errorReporting.Error
	module.Profile = createProfiler()

	-- Run watchdog in Studio (always useful for development)
	if config.IsInStudio() and config.STARTUP_PROFILING_ENABLED then
		local isTestGame = config.IsTestGame()
		print(
			string.format(
				"\nStartup profiling active (Studio: true, TestGame: %s, GameName: %s)",
				tostring(isTestGame),
				game.Name
			)
		)

		task.spawn(function()
			-- Give scripts a moment to register
			task.wait(0.5)

			local totalRegistered = 0
			for _ in pairs(totalDone) do
				totalRegistered = totalRegistered + 1
			end
			print(string.format("Watchdog monitoring %d registered scripts...", totalRegistered))

			local cycleCount = 0
			local maxCycles = 6 -- Stop checking after 30s
			while cycleCount < maxCycles do
				task.wait(5)
				cycleCount = cycleCount + 1

				local outstanding = {}
				local completed = 0
				for name, isComplete in pairs(totalDone) do
					if isComplete then
						completed = completed + 1
					else
						table.insert(outstanding, name)
					end
				end

				if #outstanding == 0 then
					print(string.format("\nAll %d scripts loaded successfully.", completed))
					printStartupSummary()
					break
				end

				warn(
					string.format(
						"after:%ds - %d/%d scripts complete, %d still loading",
						cycleCount * 5,
						completed,
						totalRegistered,
						#outstanding
					)
				)

				if cycleCount >= 2 then -- After 10s, show which ones
					for _, name in ipairs(outstanding) do
						print("  Waiting for: " .. name)
					end
				end
			end

			if cycleCount >= maxCycles then
				warn("Startup timeout reached (30s), printing summary anyway...")
				printStartupSummary()
			end
		end)
	end
end

module.Init = init
module.getAnnotater = createAnnotater

local _annotate: AnnotateFn = module.getAnnotater(script)
_annotate("end")

return module
