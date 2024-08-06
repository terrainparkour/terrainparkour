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
local ServerEventRemoteEvent = remotes.getRemoteEvent("ServerEventRemoteEvent")
local ServerEventRemoteFunction = remotes.getRemoteFunction("ServerEventRemoteFunction")

local function serverEventClientReceiveMessage(message: string, data: any)
	--_annotate("client received: " .. message)
	--_annotate(data)

	if message == serverEventEnums.messageTypes.UPDATE then
		data = data :: { tt.runningServerEvent }
		for _, event in data do
			serverEventGuis.updateEventVisually(event, localPlayer.UserId)
		end
	elseif message == serverEventEnums.messageTypes.END then
		data = data :: tt.runningServerEvent
		serverEventGuis.endEventVisually(data)
	else
		warn("bad ServerEvent message type: " .. message)
	end
end

module.Init = function()
	--_annotate("serverEvents init start")
	ServerEventRemoteEvent.OnClientEvent:Connect(serverEventClientReceiveMessage)
	ServerEventRemoteFunction:InvokeServer(serverEventEnums.messageTypes.CONNECT, {})
end

_annotate("end")
return module
