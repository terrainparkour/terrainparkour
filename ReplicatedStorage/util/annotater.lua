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
goodScripts = { "windows", "marathonClient", "marathonStatic", "marathon" }
goodScripts = { "textHighlighting" }
goodScripts = { "dynamicServer", "dynamicRunning" }
goodScripts = { "movement", "avatarEventMonitor", "avatarEventFiring", "avatarManipulation", "particleEnums" }
goodScripts = { "particleEnums", "avatarEventFiring" }
goodScripts = { "particleEnums", "movement", "avatarEventMonitor" }
goodScripts = { "leaderboard" }
goodScripts = { "*Chat*", "*channel*", "*ShiftGUI*" }
goodScripts = { "serverWarping", "warper" }
goodScripts = { "*keyboard*", "serverWarping" }
-- goodScripts = { "*setting*" }
goodScripts = {}

if config.isInStudio() then
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

local register = function(s: Script | ModuleScript | LocalScript): string
	if startTick == nil then
		startTick = tick()
		print(string.format("%s setting startTick. %0.5f", s.Name, startTick))
	end
	local scriptType = ""
	local sname = ""
	if not s or s == nil then
		scriptType = "Nil?"
		sname = "missing"
	else
		scriptType = aliases[s.ClassName] or s.ClassName
		sname = s.Name
	end

	local inheritanceTree = ""
	local parent = s.Parent
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

local function ScriptShouldBeAnnotated(s: Script | ModuleScript | LocalScript)
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

module.getAnnotater = function(s: Script | ModuleScript | LocalScript)
	local myname: string = register(s)
	local doAnnotation = ScriptShouldBeAnnotated(s)
	if showAllRegardless then
		doAnnotation = true
	end

	for _, pattern in ipairs(badScripts) do
		if matchWildcard(pattern, s.Name) then
			-- exclusions overrides turning all on
			doAnnotation = false
		end
	end

	if not doAnnotation then
		local s = 3
	end

	local label = s.Name
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
				stringVersionOfInputObject = " "
				for k, v in pairs(inputObject) do
					stringVersionOfInputObject = stringVersionOfInputObject
						.. string.format("\t%s=%s\r\n", tostring(k), tostring(v))
				end
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
