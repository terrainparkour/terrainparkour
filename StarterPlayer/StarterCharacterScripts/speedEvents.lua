--!strict

local movementEnums = require(game.StarterPlayer.StarterCharacterScripts.movementEnums)

local module = {}

export type speedStatus = { runSpeed: number, maxRunSpeed: number, jumpHeight: number }
export type speedEvent = { type: number, timems: number }
--toss a bunch of events into here via multiple methods.
--then process it every frame to recalculate movement speed.
local events: { speedEvent } = {}

module.events = events
--for some reason I feel like we need a history of events that have happened lately
module.addEvent = function(ev: speedEvent)
	table.insert(events, ev)
	print(string.format("addEvent: %d %s", #events, movementEnums.Id2SpeedEventName[ev.type]))
end

return module
