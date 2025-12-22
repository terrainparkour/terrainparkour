--!strict

-- serverEvents.lua on the client.
-- listens on client for events, and calls into drawing methods.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local tt = require(game.ReplicatedStorage.types.gametypes)
local remotes = require(game.ReplicatedStorage.util.remotes)
local serverEventGuis = require(game.StarterPlayer.StarterPlayerScripts.guis.serverEventGuis)
local serverEventEnums = require(game.ReplicatedStorage.enums.serverEventEnums)
-- local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)
local colors = require(game.ReplicatedStorage.util.colors)
local windowFunctions = require(game.StarterPlayer.StarterPlayerScripts.guis.windowFunctions)

-- Use guiUtil for UI elements
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)

local PlayersService = game:GetService("Players")
local localPlayer = PlayersService.LocalPlayer

-- EVENTS -----------------
local ServerEventRemoteEvent = remotes.getRemoteEvent("ServerEventRemoteEvent")
local ServerEventRemoteFunction = remotes.getRemoteFunction("ServerEventRemoteFunction")

local function serverEventClientReceiveMessage(message: string, data: any)
	_annotate("client received: " .. message)
	_annotate(data)

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
	_annotate("serverEvents init start")

	local pguiInstance = localPlayer:WaitForChild("PlayerGui")
	if not pguiInstance or not pguiInstance:IsA("PlayerGui") then
		error("PlayerGui not found")
	end
	local pgui: PlayerGui = pguiInstance
	local existingServerEventScreenGui = pgui:FindFirstChild("ServerEventScreenGui")
	if existingServerEventScreenGui then
		existingServerEventScreenGui:Destroy()
	end
	local serverEventScreenGui: ScreenGui = Instance.new("ScreenGui")
	serverEventScreenGui.Name = "ServerEventScreenGui"
	serverEventScreenGui.Parent = pgui
	serverEventScreenGui.IgnoreGuiInset = true

	local serverEventsSystemFrames =
		windowFunctions.SetupFrame("serverEvents", true, true, true, true, UDim2.new(0, 200, 0, 200))
	local serverEventsOuterFrame = serverEventsSystemFrames.outerFrame
	local serverEventsContentFrame = serverEventsSystemFrames.contentFrame
	local serverEventTitle = guiUtil.getTl(
		"0ServerEventTitle",
		UDim2.new(1, 0, 0, 12),
		0, -- padding
		serverEventsContentFrame,
		colors.blueDone,
		1, -- borderSizePixel
		0 -- transparency
	)
	serverEventTitle.Text = "Server Events"
	serverEventTitle.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")
	serverEventsOuterFrame.Parent = serverEventScreenGui
	serverEventsOuterFrame.Size = UDim2.new(0.15, 0, 0.08, 0)
	serverEventsOuterFrame.Position = UDim2.new(0.8, 0, 0.2, 0)

	serverEventsContentFrame.BorderMode = Enum.BorderMode.Inset

	local vv = Instance.new("UIListLayout")
	vv.Name = "serverEventContents-vv"
	vv.Parent = serverEventsContentFrame
	vv.FillDirection = Enum.FillDirection.Vertical
	serverEventGuis.Init()
	ServerEventRemoteEvent.OnClientEvent:Connect(serverEventClientReceiveMessage)
	ServerEventRemoteFunction:InvokeServer(serverEventEnums.messageTypes.CONNECT, {})
	_annotate("init done")
end

_annotate("end")
return module
