--!strict

-- listens on client for events, and calls into drawing methods.

local serverEventGuis = require(game.StarterPlayer.StarterCharacterScripts.serverEventGuis)

local PlayersService = game:GetService("Players")
repeat
	game:GetService("RunService").RenderStepped:wait()
until game.Players.LocalPlayer.Character ~= nil
local localPlayer = PlayersService.LocalPlayer

local tt = require(game.ReplicatedStorage.types.gametypes)
local remotes = require(game.ReplicatedStorage.util.remotes)
local serverEventEnums = require(game.ReplicatedStorage.enums.serverEventEnums)
local vscdebug = require(game.ReplicatedStorage.vscdebug)
--how to convert N manual "set breakpoint to debug" actions in studio
--into one setup step, and subsequently control debugging entirely from VS code

---------ANNOTATION----------------
local doAnnotation = false
-- doAnnotation = true
local annotationStart = tick()
local function annotate(s: string)
	if doAnnotation then
		if typeof(s) == "string" then
			print("serverEvents.Client: " .. string.format("%.0f", tick() - annotationStart) .. " : " .. s)
		else
			print("serverEvents.Client.object: " .. string.format("%.0f", tick() - annotationStart) .. " : ")
			print(s)
		end
	end
end

local function clientReceiveMessage(message: string, data: any)
	annotate("client received: " .. message)
	annotate(data)

	if message == serverEventEnums.messageTypes.UPDATE then
		data = data :: tt.runningServerEvent
		serverEventGuis.updateEventVisually(data, localPlayer.UserId)
	end

	if message == serverEventEnums.messageTypes.END then
		data = data :: tt.runningServerEvent
		serverEventGuis.endEventVisually(data)
	end
end

local serverEventRemoteEvent = remotes.getRemoteEvent("ServerEventRemoteEvent")

local function init()
	annotate("serverEvents init start")
	serverEventRemoteEvent.OnClientEvent:Connect(clientReceiveMessage)
end

init()
