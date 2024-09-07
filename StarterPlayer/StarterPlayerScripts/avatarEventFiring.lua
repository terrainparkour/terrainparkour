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

local remotes = require(game.ReplicatedStorage.util.remotes)

local AvatarEventBindableEvent = remotes.getBindableEvent("AvatarEventBindableEvent")

local mt = require(game.ReplicatedStorage.avatarEventTypes)

local lastWarpStart = nil

--HUMANOID

local module = {}

module.EventIsATypeWeCareAbout = function(ev: mt.avatarEvent, eventsWeCareAbout: { number }): boolean
	for _, value in pairs(eventsWeCareAbout) do
		if value == ev.eventType then
			return true
		end
	end
	return false
end

module.DescribeEvent = function(avatarEventType: number, details: mt.avatarEventDetails?): string
	local usingText = ""
	if details.startSignName then
		usingText = usingText .. " startSignName=" .. tostring(details.startSignName) .. " "
	end
	if details.endSignName then
		usingText = usingText .. " endSignName=" .. tostring(details.endSignName) .. " "
	end
	if details.floorMaterial then
		usingText = usingText .. " floorMaterial=" .. tostring(details.floorMaterial) .. " "
	end
	if details.newMoveDirection then
		usingText = usingText .. " newMoveDirection=" .. tostring(details.newMoveDirection) .. " "
	end
	if details.oldMoveDirection then
		usingText = usingText .. " oldMoveDirection=" .. tostring(details.oldMoveDirection) .. " "
	end
	if details.newState then
		usingText = usingText .. " newState=" .. tostring(details.newState) .. " "
	end
	if details.oldState then
		usingText = usingText .. " oldState=" .. tostring(details.oldState) .. " "
	end
	-- if details.warpSourceSignName then
	-- 	usingText = usingText .. " warpSourceSignName=" .. tostring(details.warpSourceSignName) .. " "
	-- end
	-- if details.warpDestinationSignName then
	-- 	usingText = usingText .. " warpDestinationSignName=" .. tostring(details.warpDestinationSignName) .. " "
	-- end
	if details.oldSpeed then
		usingText = usingText .. " oldSpeed=" .. tostring(details.oldSpeed) .. " "
	end
	if details.newSpeed then
		usingText = usingText .. " newSpeed=" .. tostring(details.newSpeed) .. " "
	end
	if details.oldJumpPower then
		usingText = usingText .. " oldJumpPower=" .. tostring(details.oldJumpPower) .. " "
	end
	if details.newJumpPower then
		usingText = usingText .. " newJumpPower=" .. tostring(details.newJumpPower) .. " "
	end
	if details.reason then
		usingText = usingText .. " reason=" .. tostring(details.reason) .. " "
	end

	local res = string.format("EventType = %s%s", mt.avatarEventTypesReverse[avatarEventType], usingText)
	return res
end

module.GetPlayerPosition = function(): (Vector3, Vector3, number)
	local character = game.Players.LocalPlayer.Character
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local lookVector = rootPart.CFrame.LookVector
	return rootPart.Position, lookVector, character:FindFirstChild("Humanoid").WalkSpeed
end

module.FireEvent = function(avatarEventType: number, details: mt.avatarEventDetails | nil)
	if not avatarEventType then
		warn("bad event.", avatarEventType, details)
		return
	end

	if not details then
		details = {}
	end

	if details.position ~= nil or details.lookVector ~= nil then
		warn("why did you already have this?", details.position, details.lookVector)
	end

	local character = game.Players.LocalPlayer.Character

	local s, e = pcall(function()
		local pos, lv, s = module.GetPlayerPosition()
		details.position = pos
		details.lookVector = lv
		details.walkSpeed = character:FindFirstChild("Humanoid").WalkSpeed
	end)
	if not s then
		warn("error getting player position", e)
		details.position = Vector3.new(999, 0, 0)
		details.lookVector = Vector3.new(0, 0, 951)
	end

	local actualEv: mt.avatarEvent = {
		eventType = avatarEventType,
		timestamp = tick(),
		details = details,
	}

	if actualEv.eventType == mt.avatarEventTypes.GET_READY_FOR_WARP then
		lastWarpStart = actualEv.timestamp
	elseif actualEv.eventType == mt.avatarEventTypes.MARATHON_RESTARTED then
		local duration = actualEv.timestamp - lastWarpStart
		lastWarpStart = nil
		_annotate(string.format("warp delay duration in this situation: %0.5f", duration))
	end

	_annotate(string.format("Firing: %s", module.DescribeEvent(avatarEventType, details)))
	AvatarEventBindableEvent:Fire(actualEv)
end

_annotate("end")
return module
