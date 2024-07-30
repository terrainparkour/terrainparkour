--!strict

--include this and also call .getAnnotater for every script since this functions as a registration, too

local module = {}

local aliases = { LocalScript = "local", Script = "script", ModuleScript = "module" }

-- this controls which annotate calls are actually shown. Enter the minimal script name here regardless of client/module/script etc.
local goodScripts = { "movement", "avatarEventMonitor", "avatarEventFiring", "serverWarping" }
goodScripts = { "warper", "dynamicRunning", "main", "movement" }
goodScripts = { "morphs", "runProgressSgui", "angerSign" }
goodScripts = {}

local showAllRegardless = false
-- showAllRegardless = true

local register = function(s: Script | ModuleScript | LocalScript): string
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

local totalDone: { [string]: boolean } = {}

module.getAnnotater = function(s: Script | ModuleScript | LocalScript)
	local myname: string = register(s)
	local doAnnotation = false

	if table.find(goodScripts, s.Name) then
		doAnnotation = true
	end
	if showAllRegardless then
		doAnnotation = true
	end

	local startTick = tick()
	local label = s.Name
	local theLabel = label
	local theStartTick = startTick
	totalDone[myname] = false
	local function annotate(input: string | any)
		if input == "end" then
			local gap = tick() - startTick
			if gap > 0.1 then
				print(string.format("%s (%s) done in %0.2fs", myname, s.ClassName, gap))
			end
			totalDone[myname] = true
			return
		end
		if doAnnotation then
			if typeof(input) == "string" then
				print(string.format("%s %0.3f %s", theLabel, tick() - theStartTick, input))
			else
				print(string.format("  %s %0.3f", theLabel, tick() - theStartTick))
			end
		end
	end
	return annotate
end

module.Init = function()
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

return module
