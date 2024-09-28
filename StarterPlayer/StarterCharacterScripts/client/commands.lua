--!strict

-- commands.lua? ah, for named eventsa/ seems overkill shouldn't this be just one sender/receiver? whatever.

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

local function showSigns(signIds: { number }, extraText: string?)
	_annotate("Client commands received: ShowSigns.")
	textHighlighting.KillAllExistingHighlights()
	textHighlighting.DoHighlightMultiple(signIds)
	if extraText then
		--we want to chat it to the player:
		local chatText = "You have " .. #signIds .. " signs that " .. extraText
		-- localPlayer:Chat(chatText)
		--TODO
	end
end

module.Init = function()
	_annotate("init")
	ShowSignsEvent.OnClientEvent:Connect(showSigns)
	_annotate("init done")
end

_annotate("end")
return module
