--!strict

-- stuff where client listens to things from server and replies to commands.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local remotes = require(game.ReplicatedStorage.util.remotes)
local ShowSignsEvent = remotes.getRemoteEvent("ShowSignsEvent")
local textHighlighting = require(game.ReplicatedStorage.gui.textHighlighting)

local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer
local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

----------- GLOBALS -----------

local function showSigns(signIds: { number })
	_annotate("Client commands received: ShowSigns.")
	textHighlighting.doHighlightMultiple(signIds)
end

module.Init = function()
	ShowSignsEvent.OnClientEvent:Connect(showSigns)
end

_annotate("end")
return module
