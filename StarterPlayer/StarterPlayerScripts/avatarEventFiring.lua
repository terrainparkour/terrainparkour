--!strict

-- 2024.07. it just monitors everything that happens to the player on clientside and then sends
-- events to all the other monitoring player localScripts.
-- RULE: everybody local script who wants to know anything about a user's avatar movement, position, posture etc changes
-- must hook into signals sent by this.
-- Overall plan: nobody directly subscribes to user actions except this one
-- (although the racing module can accept sign clicks to cancel, and other UI / local sGui clicks)
-- everyone else just has to monitor the stream of these events to get info on what to do.
-- honestly why do I even have multiple scripts? why not just have them all "broadcast" or at least "detected" in one file?
-- as well as acted upon? This current "broadcast once, receive multiple times" approach seems good during development,
-- but will it work in practice, when there are potentially complex interactions between the scripts?  also, how efficient are bindableEvents?

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local aet = require(game.ReplicatedStorage.avatarEventTypes)

-- hmm not sure.
-- local lastWarpStart = tick()

--HUMANOID

local module = {}

module.EventIsATypeWeCareAbout = function(ev: aet.avatarEvent, eventsWeCareAbout: { number }): boolean
	for _, value in pairs(eventsWeCareAbout) do
		if value == ev.eventType then
			return true
		end
	end
	return false
end

module.DescribeEvent = function(ev: aet.avatarEvent): string
	local details = ev.details

	local usingText = ""
	if details.startSignName then
		usingText = string.format("%s startSignName=%s ", usingText, details.startSignName)
	end
	if details.endSignName then
		usingText = string.format("%s endSignName=%s ", usingText, details.endSignName)
	end
	if details.floorMaterial then
		usingText = string.format("%s floorMaterial=%s ", usingText, details.floorMaterial.Name)
	end
	if details.newMoveDirection then
		usingText = string.format("%s newMoveDirection=%s ", usingText, tostring(details.newMoveDirection))
	end
	if details.oldMoveDirection then
		usingText = string.format("%s oldMoveDirection=%s ", usingText, tostring(details.oldMoveDirection))
	end
	if details.newState then
		usingText = string.format("%s newState=%s ", usingText, details.newState.Name)
	end
	if details.oldState then
		usingText = string.format("%s oldState=%s ", usingText, details.oldState.Name)
	end
	if details.oldSpeed then
		usingText = string.format("%s oldSpeed=%.2f ", usingText, details.oldSpeed)
	end
	if details.newSpeed then
		usingText = string.format("%s newSpeed=%.2f ", usingText, details.newSpeed)
	end
	if details.oldJumpPower then
		usingText = string.format("%s oldJumpPower=%.2f ", usingText, details.oldJumpPower)
	end
	if details.newJumpPower then
		usingText = string.format("%s newJumpPower=%.2f ", usingText, details.newJumpPower)
	end
	if details.reason then
		usingText = string.format("%s reason=%s ", usingText, details.reason)
	end
	if details.sender then
		usingText = string.format("%s sender=%s ", usingText, details.sender)
	end
	if ev.id then
		usingText = string.format("%s id=%s ", usingText, ev.id)
	end

	local res = string.format("%s%s", aet.avatarEventTypesReverse[ev.eventType], usingText)
	return res
end

module.GetPlayerPosition = function(): (Vector3, Vector3, number)
	local character = game.Players.LocalPlayer.Character
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local lookVector = rootPart.CFrame.LookVector
	return rootPart.Position, lookVector, character:FindFirstChild("Humanoid").WalkSpeed
end

module.FireEvent = function(avatarEventType: number, details: aet.avatarEventDetails)
	if not avatarEventType then
		warn("bad event.", avatarEventType, details)
		return
	end

	if not details or details == nil then
		warn("bad details.", details)
	end

	if details.position ~= nil or details.lookVector ~= nil then
		warn("why did you already have this?", details.position, details.lookVector)
	end

	local character = game.Players.LocalPlayer.Character

	local s, e = pcall(function()
		local pos, lv, s = module.GetPlayerPosition()
		details.position = pos
		details.lookVector = lv
		details.walkSpeed = s
	end)
	if not s then
		warn("error getting player position", e)
		details.position = Vector3.new(999, 0, 0)
		details.lookVector = Vector3.new(0, 0, 951)
	end

	local actualEv: aet.avatarEvent = {
		eventType = avatarEventType,
		timestamp = tick(),
		details = details,
		id = math.random(1, 1000000), -- Generate a random number between 1 and 1,000,000
	}

	_annotate(string.format("Firing: %s", module.DescribeEvent(actualEv)))

	local remotes = require(game.ReplicatedStorage.util.remotes)
	local AvatarEventBindableEvent = remotes.getBindableEvent("AvatarEventBindableEvent")

	AvatarEventBindableEvent:Fire(actualEv)
end

_annotate("end")
return module
