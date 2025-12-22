--!strict

-- HandleClientMessages.lua :: StarterPlayer.StarterCharacterScripts.client.HandleClientMessages
-- CLIENT-ONLY: Receives system messages from server and displays them in appropriate channels.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local annotater = require(ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

type Module = {
	Init: () -> (),
}

local module: Module = {} :: Module

local initialized = false

function module.Init()
	if initialized then
		return
	end
	initialized = true

	_annotate("setting up client message handler")

	local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents") :: Folder
	local RemoteEvent = RemoteEvents:WaitForChild("DisplaySystemMessageEvent") :: RemoteEvent

	RemoteEvent.OnClientEvent:Connect(function(message: string, channelName: string)
		_annotate(string.format("received system message for [%s]: %s", channelName, message:sub(1, 50)))

		local channelTabsConfig = TextChatService:FindFirstChild("ChannelTabsConfiguration")
		if not channelTabsConfig then
			_annotate("error: ChannelTabsConfiguration not found")
			warn("ChannelTabsConfiguration not found")
			return
		end

		local dataChannel: TextChannel? = channelTabsConfig:FindFirstChild(channelName) :: TextChannel?
		if not dataChannel then
			_annotate(string.format("error: channel %s not found in ChannelTabsConfiguration", channelName))
			warn(string.format("Channel %s not found in ChannelTabsConfiguration", channelName))
			return
		end

		_annotate(string.format("displaying message in channel %s", channelName))
		dataChannel:DisplaySystemMessage(message)
	end)

	_annotate("initialized")
end

_annotate("end")
return module

