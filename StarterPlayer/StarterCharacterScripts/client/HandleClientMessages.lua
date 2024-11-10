local Textchat = game:GetService("TextChatService")

local RemoteEvent = game.ReplicatedStorage.RemoteEvents.DisplaySystemMessage

RemoteEvent.OnClientEvent:Connect(function(message: string, channel: string)
	local dataChannel: TextChannel = Textchat.ChannelTabsConfiguration:WaitForChild(channel)
	
	dataChannel:DisplaySystemMessage(`<font color="#B83928">[SYSTEM]</font>`.. message)
end)