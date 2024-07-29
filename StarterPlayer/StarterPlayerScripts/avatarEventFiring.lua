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

local module = {}

module.FireEvent = function(avatarEventType: number, details: mt.avatarEventDetails?)
	if not avatarEventType then
		warn("bad event.")
		return
	end
	if not details then
		details = {}
	end
	local actualEv: mt.avatarEvent = {
		eventType = avatarEventType,
		timestamp = tick(),
		details = details,
	}

	local excludedDescriptionTypesFromDescriptions = {
		-- mt.avatarEventTypes.CHANGE_DIRECTION,
		-- mt.avatarEventTypes.STATE_CHANGED,
		-- mt.avatarEventTypes.DO_SPEED_CHANGE,
		-- mt.avatarEventTypes.DO_JUMPPOWER_CHANGE,
		-- mt.avatarEventTypes.FLOOR_CHANGE,
	}
	local blocked = false
	for _, type in ipairs(excludedDescriptionTypesFromDescriptions) do
		if actualEv.eventType == type then
			blocked = true
			break
		end
	end
	if not blocked then
		local details = ""
		if actualEv.details ~= {} then
			if actualEv.details then
				for a, b in pairs(actualEv.details) do
					details = details .. string.format("%s: %s", a, tostring(b)) .. "\t"
				end
			end
		end
		if details then
			details = " (" .. details .. ")"
		end
		_annotate(
			string.format("AvatarEventFiring: %s%s", tostring(mt.avatarEventTypesReverse[actualEv.eventType]), details)
		)
	end
	AvatarEventBindableEvent:Fire(actualEv)
end

_annotate("end")
return module
