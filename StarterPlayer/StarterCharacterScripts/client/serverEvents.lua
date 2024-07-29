--!strict

-- listens on client for events, and calls into drawing methods.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local tt = require(game.ReplicatedStorage.types.gametypes)
local remotes = require(game.ReplicatedStorage.util.remotes)
local serverEventGuis = require(game.StarterPlayer.StarterPlayerScripts.guis.serverEventGuis)
local serverEventEnums = require(game.ReplicatedStorage.enums.serverEventEnums)

local PlayersService = game:GetService("Players")
local localPlayer = PlayersService.LocalPlayer
local serverEventRemoteEvent = remotes.getRemoteEvent("ServerEventRemoteEvent")

local function clientReceiveMessage(message: string, data: any)
	_annotate("client received: " .. message)
	_annotate(data)

	if message == serverEventEnums.messageTypes.UPDATE then
		data = data :: tt.runningServerEvent
		serverEventGuis.updateEventVisually(data, localPlayer.UserId)
	end

	if message == serverEventEnums.messageTypes.END then
		data = data :: tt.runningServerEvent
		serverEventGuis.endEventVisually(data)
	end
end

module.Init = function()
	_annotate("serverEvents init start")
	serverEventRemoteEvent.OnClientEvent:Connect(clientReceiveMessage)
end

_annotate("end")
return module
