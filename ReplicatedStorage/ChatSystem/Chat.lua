local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProcessCommand = ReplicatedStorage.RemoteFunctions.ProcessCommand

local ChatUI = {}

function ChatUI:HandleIncomingMessage(message)
	if message ~= nil then
		local player = message.TextSource

		if message.TextChannel then
			if message.TextChannel.Name == "Data" then
				local result = ProcessCommand:InvokeServer(message.Text)

				return true
			elseif message.TextChannel.Name == "Racers" then
				return false
			end
		end

		return true
	end
end

function ChatUI:Initialize()
	TextChatService.OnIncomingMessage = function(message)
		self:HandleIncomingMessage(message)
	end
end

return ChatUI