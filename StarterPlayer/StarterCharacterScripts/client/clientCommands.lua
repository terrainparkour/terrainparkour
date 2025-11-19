--!strict

-- commands.lua? ah, for named eventsa/ seems overkill shouldn't this be just one sender/receiver? whatever.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local remotes = require(game.ReplicatedStorage.util.remotes)
local ShowSignsEvent = remotes.getRemoteEvent("ShowSignsEvent")
local GenericClientUIEvent = remotes.getRemoteEvent("GenericClientUIEvent")
local textHighlighting = require(game.ReplicatedStorage.gui.textHighlighting)

-- local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local drawRunResultsGui = require(ReplicatedStorage.gui.runresults.drawRunResultsGui)
-- local localPlayer: Player = Players.LocalPlayer
-- local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
-- local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local tt = require(ReplicatedStorage.types.gametypes)
-- local playerGui = localPlayer:WaitForChild("PlayerGui")
----------- GLOBALS -----------

local function showSigns(signIds: { number }, extraText: string?)
	_annotate("Client commands received: ShowSigns.")
	textHighlighting.KillAllExistingHighlights()
	textHighlighting.DoHighlightMultiple(signIds)
	if extraText then
		--we want to chat it to the player:
		-- local chatText = "You have " .. #signIds .. " signs that " .. extraText
		-- localPlayer:Chat(chatText)
		--TODO
	end
end

local drawWRHistoryProgressionGui = require(game.ReplicatedStorage.gui.menu.drawWRHistoryProgressionGui)
local function HandleGenericClientUIEvent(data: any)
	_annotate("Client commands received: GenericClientUIEvent.", data)
	if data.command == "wrProgressionRequest" then
		local converted2: tt.WRProgressionEndpointResponse = data.data :: tt.WRProgressionEndpointResponse
		if converted2.raceExists then
			drawWRHistoryProgressionGui.CreateWRHistoryProgressionGui(converted2)
		end
	elseif data.command == "runResultsDelivery" then
		local converted: tt.userFinishedRunResponse = data.data.userFinishedRunResponse :: tt.userFinishedRunResponse
		drawRunResultsGui.DrawRunResultsGui(converted)
	end
end

module.Init = function()
	_annotate("init")
	ShowSignsEvent.OnClientEvent:Connect(showSigns)
	GenericClientUIEvent.OnClientEvent:Connect(HandleGenericClientUIEvent)
	_annotate("init done")
end

_annotate("end")
return module
