--!strict

-- annotater.lua.
-- a very special module.
-- include this and also call .getAnnotater for every script since this functions as a registration, too

local config = require(game.ReplicatedStorage.config)

local module = {}

-- the ultimate override. except it still obeys badScripts
local showAllRegardless = false
-- showAllRegardless = true

-- also exclude these guys.
local badScripts = {}
badScripts = { "*movement*" }

--effectively the global erver start tick.
local startTick = tick()

local aliases = { LocalScript = "local", Script = "script", ModuleScript = "module" }

-- this controls which annotate calls are actually shown. Enter the minimal script name here regardless of client/module/script etc.
local goodScripts = { "warper", "serverWarping", "ghostSign", "morphs", "avatarEventFiring", "avatarManipulation" }
goodScripts = { "*draw*", "*sticky*" }
-- goodScripts = {}

if config.IsInStudio() then
	-- table.insert(goodScripts, "httpService")
	-- table.insert(goodScripts, "rdb")
	-- table.insert(goodScripts, "receiveClientEventServer")
	-- table.insert(goodScripts, "morphs")
	-- table.insert(goodScripts, "*avatarM*")
	-- table.insert(goodScripts, "keyboard")
	-- table.insert(goodScripts, "*warp*")
	-- table.insert(goodScripts, "*marathon*")
end

-- for tracking the time gap from the initial loading of the thing - from getAnnotator to calling .annotate('end')
local totalDone: { [string]: boolean } = {}

local lua2Json = require(game.ReplicatedStorage.util.lua2Json)

local function deepToString(obj, indent)
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

local register = function(script: Script | ModuleScript | LocalScript | LuaSourceContainer): string
	if startTick == nil then
		startTick = tick()
		print(string.format("%s setting startTick. %0.5f", script.Name, startTick))
	end
	local scriptType = ""
	local sname = ""
	if not script or script == nil then
		scriptType = "Nil?"
		sname = "missing"
	else
		scriptType = aliases[script.ClassName] or script.ClassName
		sname = script.Name
	end

	local inheritanceTree = ""
	local parent = script.Parent
	while parent do
		if parent.ClassName == "DataModel" then
			break
		end
		if parent.Name == "Game" then
			break
		end
		inheritanceTree = parent.Name .. "." .. inheritanceTree
		parent = parent.Parent
	end

	inheritanceTree = inheritanceTree:sub(1, string.len(inheritanceTree) - 1)

	inheritanceTree = string.gsub(inheritanceTree, "ServerScriptService", "sss")
	inheritanceTree = string.gsub(inheritanceTree, "ReplicatedStorage", "rs")
	inheritanceTree = string.gsub(inheritanceTree, "StarterCharacterScripts", "scs")
	inheritanceTree = string.gsub(inheritanceTree, "StarterPlayerScripts", "sps")
	inheritanceTree = string.gsub(inheritanceTree, "StarterPlayer", "sp")
	inheritanceTree = string.gsub(inheritanceTree, "PlayerScripts", "ps")
	inheritanceTree = string.gsub(inheritanceTree, "Workspace.TerrainParkour", "workspace.me")
	inheritanceTree = string.gsub(inheritanceTree, "Players.TerrainParkour", "players.me")

	local firstLength = 8
	local firstSeen = string.len(scriptType)
	local firstGap = firstLength - firstSeen
	local targetLength = 38
	local seenLength = firstLength + string.len(inheritanceTree)

	local filter = "local"
	if scriptType == filter then
		local gap = targetLength - seenLength
		local res = string.format(
			"%s%s%s%s%s",
			scriptType,
			string.rep(" ", firstGap),
			inheritanceTree,
			string.rep(" ", gap),
			sname
		)
		print(res)
	end

	return sname
end

local function matchWildcard(pattern, str)
	-- Convert wildcard pattern to Lua pattern
	pattern = "^" .. string.gsub(pattern, "%*", ".*") .. "$"
	return string.match(string.lower(str), string.lower(pattern)) ~= nil
end

local function ScriptShouldBeAnnotated(s: Script | ModuleScript | LocalScript | LuaSourceContainer)
	-- Check against badScripts first
	for _, pattern in ipairs(badScripts) do
		if matchWildcard(pattern, s.Name) then
			-- Exclude scripts matching badScripts patterns
			return false
		end
	end

	-- Then check against goodScripts
	for _, pattern in ipairs(goodScripts) do
		if matchWildcard(pattern, s.Name) then
			return true
		end
	end
	return false
end

module.getAnnotater = function(script: Script | ModuleScript | LocalScript | LuaSourceContainer)
	local myname: string = register(script)
	local doAnnotation = ScriptShouldBeAnnotated(script)
	if showAllRegardless then
		doAnnotation = true
	end

	for _, pattern in ipairs(badScripts) do
		if matchWildcard(pattern, script.Name) then
			-- exclusions overrides turning all on
			doAnnotation = false
		end
	end

	if not doAnnotation then
		local s = 3
	end

	local label = script.Name
	local theLabel = label
	totalDone[myname] = false

	local curry = function(myCopyOfDoAnnotation: boolean): (string, any?) -> ()
		local x = function(inputString: string, inputObject: any?)
			if inputString == "end" then
				totalDone[myname] = true
				return
			end
			local stringVersionOfInputObject = ""
			if inputObject then
				stringVersionOfInputObject = "\n" .. deepToString(inputObject, 0)
			end
			if myCopyOfDoAnnotation then
				if typeof(inputString) == "string" then
					print(
						string.format(
							"%0.3f %-25s %s%s",
							tick() - startTick,
							theLabel,
							inputString,
							stringVersionOfInputObject
						)
					)
				else
					print(string.format("  %0.3f %s   - ", tick() - startTick, theLabel))
				end
			end
		end
		return x
	end

	return curry(doAnnotation)
end

local innitted = false

-- this is for measuring how long each thing takes to load.
module.Init = function()
	if innitted then
		return
	end
	innitted = true
	local errorReporting = require(game.ReplicatedStorage.util.errorReporting)
	errorReporting.Init()

	module.Error = errorReporting.Error
	errorReporting.Init()

	-- to help debug loading order issues.
	if config.isTestGame() and true then
		task.spawn(function()
			while true do
				wait(5)

				local bad = false
				for k, v in pairs(totalDone) do
					if not v then
						print(k, v)
						bad = true
					end
				end
				if not bad then
					break
				end
				warn("after:5s")
			end
		end)
	end
end

return module
