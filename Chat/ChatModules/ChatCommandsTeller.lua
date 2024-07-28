--	// FileName: ChatCommandsTeller.lua
--	// Written by: Xsitsu
--	// Description: Module that provides information on default chat commands to players.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local Chat = game:GetService("Chat")
local ReplicatedModules = Chat:WaitForChild("ClientChatModules")
local ChatSettings = require(ReplicatedModules:WaitForChild("ChatSettings"))
local ChatConstants = require(ReplicatedModules:WaitForChild("ChatConstants"))

local function Run(ChatService)
	local function ShowJoinAndLeaveCommands()
		if ChatSettings.ShowJoinAndLeaveHelpText ~= nil then
			return ChatSettings.ShowJoinAndLeaveHelpText
		end
		return false
	end

	local function ProcessCommandsFunction(fromSpeaker, message, channel)
		return false
	end

	ChatService:RegisterProcessCommandsFunction(
		"chat_commands_inquiry",
		ProcessCommandsFunction,
		ChatConstants.StandardPriority
	)

	local allChannel = ChatService:GetChannel("All")
	if allChannel then
		allChannel.WelcomeMessage = "Chat '/?' or '/help' for a list of chat commands."
	end
end

_annotate("end")
return Run
