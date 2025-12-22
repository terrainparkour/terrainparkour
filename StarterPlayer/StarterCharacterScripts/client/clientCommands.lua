--!strict

-- clientCommands.lua
-- Client-side handler for ShowSignsEvent (sign highlighting).

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local remotes = require(game.ReplicatedStorage.util.remotes)
local textHighlighting = require(game.ReplicatedStorage.gui.textHighlighting)

local ShowSignsEvent = remotes.getRemoteEvent("ShowSignsEvent")

local module = {}

local function showSigns(signIds: { number }, extraText: string?)
	_annotate("Client commands received: ShowSigns.")
	textHighlighting.KillAllExistingHighlights()
	textHighlighting.DoHighlightMultiple(signIds)
end

module.Init = function()
	_annotate("init")
	ShowSignsEvent.OnClientEvent:Connect(showSigns)
	_annotate("init done")
end

_annotate("end")
return module
