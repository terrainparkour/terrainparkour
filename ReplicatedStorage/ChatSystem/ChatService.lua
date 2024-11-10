local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")

local ChannelManager = require(script.Parent["ChannelManager"])

local ChatService = {}
ChatService.Channels = {}

function ChatService:CreateChannels(player: Player): {}
	if not player then
		warn("Attempt to create channels for nil player.")
	end

	local dataChannel = Instance.new("TextChannel")
	dataChannel.Name = "Data"
	dataChannel.Parent = TextChatService.ChannelTabsConfiguration
	ChannelManager:CreateChannel("Data", dataChannel)

	local racersChannel = Instance.new("TextChannel")
	racersChannel.Name = "Racers"
	racersChannel.Parent = TextChatService.ChannelTabsConfiguration
	ChannelManager:CreateChannel("Racers", racersChannel)

	dataChannel:AddUserAsync(player.UserId)
	racersChannel:AddUserAsync(player.UserId)

	return self.Channels
end

function ChatService:InitializeChannels()
	for _, player in Players:GetPlayers() do
		ChatService:CreateChannels(player)
	end

	Players.PlayerAdded:Connect(function(player)
		ChatService:CreateChannels(player)
	end)
end

return ChatService