--	// FileName: PrivateMessaging.lua
--	// Written by: Xsitsu
--	// Description: Module that handles all private messaging.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local Chat = game:GetService("Chat")
local RunService = game:GetService("RunService")
local ReplicatedModules = Chat:WaitForChild("ClientChatModules")
local ChatConstants = require(ReplicatedModules:WaitForChild("ChatConstants"))
local ChatSettings = require(ReplicatedModules:WaitForChild("ChatSettings"))

local errorTextColor = ChatSettings.ErrorMessageTextColor or Color3.fromRGB(245, 50, 50)
local errorExtraData = { ChatColor = errorTextColor }

local function Run(ChatService)
	local function ChatSettingsEnabled()
		local chatPrivacySettingsSuccess, chatPrivacySettingsValue = pcall(function()
			return UserSettings():IsUserFeatureEnabled("UserChatPrivacySetting")
		end)
		local chatPrivacySettingsEnabled = true
		if chatPrivacySettingsSuccess then
			chatPrivacySettingsEnabled = chatPrivacySettingsValue
		end
		return chatPrivacySettingsEnabled
	end

	local function CanCommunicate(fromSpeaker, toSpeaker)
		if ChatSettingsEnabled() == false then
			return true
		end
		if RunService:IsStudio() then
			return true
		end
		local fromPlayer = fromSpeaker:GetPlayer()
		local toPlayer = toSpeaker:GetPlayer()
		if fromPlayer and toPlayer then
			local success, canChat = pcall(function()
				return Chat:CanUsersChatAsync(fromPlayer.UserId, toPlayer.UserId)
			end)
			return success and canChat
		end
		return false
	end

	local function DoWhisperCommand(fromSpeaker, message, channel)
		local otherSpeakerName = message
		local sendMessage = nil

		if string.sub(message, 1, 1) == '"' then
			local pos = string.find(message, '"', 2)
			if pos then
				otherSpeakerName = string.sub(message, 2, pos - 1)
				sendMessage = string.sub(message, pos + 2)
			end
		else
			local first = string.match(message, "^[^%s]+")
			if first then
				otherSpeakerName = first
				sendMessage = string.sub(message, string.len(otherSpeakerName) + 2)
			end
		end

		local speaker = ChatService:GetSpeaker(fromSpeaker)
		local otherSpeaker = ChatService:GetSpeaker(otherSpeakerName)
		local channelObj = ChatService:GetChannel("To " .. otherSpeakerName)
		if channelObj and otherSpeaker then
			if not CanCommunicate(speaker, otherSpeaker) then
				speaker:SendSystemMessage("You are not able to chat with this player.", channel, errorExtraData)
				return
			end

			if channelObj.Name == "To " .. speaker.Name then
				speaker:SendSystemMessage("You cannot whisper to yourself.", channel, errorExtraData)
			else
				if not speaker:IsInChannel(channelObj.Name) then
					speaker:JoinChannel(channelObj.Name)
				end

				if sendMessage and (string.len(sendMessage) > 0) then
					speaker:SayMessage(sendMessage, channelObj.Name)
				end

				speaker:SetMainChannel(channelObj.Name)
			end
		else
			speaker:SendSystemMessage(
				string.format("Speaker '%s' does not exist.", tostring(otherSpeakerName)),
				channel,
				errorExtraData
			)
		end
	end

	local function WhisperCommandsFunction(fromSpeaker, message, channel)
		local processedCommand = false

		if string.sub(message, 1, 3):lower() == "/w " then
			DoWhisperCommand(fromSpeaker, string.sub(message, 4), channel)
			processedCommand = true
		elseif string.sub(message, 1, 9):lower() == "/whisper " then
			DoWhisperCommand(fromSpeaker, string.sub(message, 10), channel)
			processedCommand = true
		end

		return processedCommand
	end

	local function PrivateMessageReplicationFunction(fromSpeaker, message, channelName)
		local sendingSpeaker = ChatService:GetSpeaker(fromSpeaker)
		local extraData = sendingSpeaker.ExtraData
		sendingSpeaker:SendMessage(message, channelName, fromSpeaker, extraData)

		local toSpeaker = ChatService:GetSpeaker(string.sub(channelName, 4))
		if toSpeaker then
			if not toSpeaker:IsInChannel("To " .. fromSpeaker) then
				toSpeaker:JoinChannel("To " .. fromSpeaker)
			end
			toSpeaker:SendMessage(message, "To " .. fromSpeaker, fromSpeaker, extraData)
		end

		return true
	end

	local function PrivateMessageAddTypeFunction(speakerName, messageObj, channelName)
		if ChatConstants.MessageTypeWhisper then
			messageObj.MessageType = ChatConstants.MessageTypeWhisper
		end
	end

	ChatService:RegisterProcessCommandsFunction(
		"whisper_commands",
		WhisperCommandsFunction,
		ChatConstants.StandardPriority
	)

	local function GetWhisperChanneNameColor()
		if ChatSettings.WhisperChannelNameColor then
			return ChatSettings.WhisperChannelNameColor
		end
		return Color3.fromRGB(102, 14, 102)
	end

	ChatService.SpeakerAdded:connect(function(speakerName)
		if ChatService:GetChannel("To " .. speakerName) then
			ChatService:RemoveChannel("To " .. speakerName)
		end

		local channel = ChatService:AddChannel("To " .. speakerName)
		channel.Joinable = false
		channel.Leavable = true
		channel.AutoJoin = false
		channel.Private = true

		channel.WelcomeMessage = "You are now privately chatting with " .. speakerName .. "."
		channel.ChannelNameColor = GetWhisperChanneNameColor()

		channel:RegisterProcessCommandsFunction(
			"replication_function",
			PrivateMessageReplicationFunction,
			ChatConstants.LowPriority
		)
		channel:RegisterFilterMessageFunction("message_type_function", PrivateMessageAddTypeFunction)
	end)

	ChatService.SpeakerRemoved:connect(function(speakerName)
		if ChatService:GetChannel("To " .. speakerName) then
			ChatService:RemoveChannel("To " .. speakerName)
		end
	end)
end
_annotate("end")
return Run
