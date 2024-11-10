local TextChatService = game:GetService("TextChatService")

local ChannelManager = {}
local channels = {}

function ChannelManager:CreateChannel(channelName: string, channel: TextChannel): TextChannel
	if channels[channelName] then warn("Channel '" .. channelName .. "' already exists.") return channels[channelName] end
	
	local newChannel = channel
	channels[channelName] = channel
	
	return newChannel
end

function ChannelManager:GetChannel(channelName: string): TextChannel?
	return channels[channelName]
end

return ChannelManager