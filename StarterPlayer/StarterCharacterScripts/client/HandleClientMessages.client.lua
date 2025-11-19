--!strict

-- HandleClientMessages.client.lua :: StarterPlayer.StarterCharacterScripts.client.HandleClientMessages
-- CLIENT-ONLY: Receives system messages from server and displays them in appropriate channels.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
annotater.Init()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local setup = function()
	_annotate("Setting up client message handler")
	
	_annotate("Waiting for RemoteEvents folder...")
	local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents") :: Folder
	_annotate("Info: RemoteEvents folder found")
	
	_annotate("Waiting for DisplaySystemMessageEvent...")
	local RemoteEvent = RemoteEvents:WaitForChild("DisplaySystemMessageEvent") :: RemoteEvent
	_annotate("Info: DisplaySystemMessageEvent found")
	
	_annotate("Connecting to DisplaySystemMessageEvent")
	RemoteEvent.OnClientEvent:Connect(function(message: string, channelName: string)
		_annotate(string.format("Info: Received system message for [%s]: %s", channelName, message:sub(1, 50)))
		
		local channelTabsConfig = TextChatService:FindFirstChild("ChannelTabsConfiguration")
		if not channelTabsConfig then
			_annotate("Error: ChannelTabsConfiguration not found")
			warn("ChannelTabsConfiguration not found")
			return
		end
		
		local dataChannel: TextChannel? = channelTabsConfig:FindFirstChild(channelName) :: TextChannel?
		if not dataChannel then
			_annotate(string.format("Error: Channel %s not found in ChannelTabsConfiguration", channelName))
			warn(string.format("Channel %s not found in ChannelTabsConfiguration", channelName))
			return
		end
		
		_annotate(string.format("Info: Displaying message in channel %s", channelName))
		dataChannel:DisplaySystemMessage(message)
	end)
	
	_annotate("Info: Client message handler fully connected")
end

setup()

_annotate("end")

