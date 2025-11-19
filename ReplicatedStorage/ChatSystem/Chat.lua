--!strict

-- Chat.lua :: ReplicatedStorage.ChatSystem.Chat
-- CLIENT-ONLY: Handles incoming chat messages and command routing.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local channelManager = require(script.Parent.channelManager)
local MessageFormatter = require(script.Parent.messageFormatter)
local colors = require(game.ReplicatedStorage.util.colors)

local ProcessCommandFunction: RemoteFunction? = nil

type Module = {
	HandleIncomingMessage: (self: Module, message: TextChatMessage) -> TextChatMessageProperties?,
	GetIncomingMessageHandler: (self: Module) -> (TextChatMessage) -> TextChatMessageProperties?,
	Initialize: (self: Module) -> (),
	ProcessSlashCommand: (self: Module, messageText: string, channelName: string?) -> boolean,
}

local ChatUI: Module = {} :: Module

local function createEmptyProperties(): TextChatMessageProperties
	local props = Instance.new("TextChatMessageProperties")
	props.PrefixText = ""
	props.Text = ""
	return props
end

local function getProcessCommandFunction(): RemoteFunction
	if ProcessCommandFunction then
		return ProcessCommandFunction
	end

	local remoteFunctionsFolder = ReplicatedStorage:WaitForChild("RemoteFunctions") :: Folder
	local remoteFunctionInstance = remoteFunctionsFolder:WaitForChild("ProcessCommandFunction")
	if not remoteFunctionInstance:IsA("RemoteFunction") then
		error("ProcessCommandFunction must be a RemoteFunction")
	end
	local remoteFunction = remoteFunctionInstance :: RemoteFunction
	ProcessCommandFunction = remoteFunction
	return remoteFunction
end

function ChatUI:ProcessSlashCommand(messageText: string, channelName: string?): boolean
	_annotate(
		string.format("Info: Forwarding slash command to server. channel=%s text=%s", channelName or "nil", messageText)
	)

	local processCommand = getProcessCommandFunction()
	local success, resultOrErr = pcall(function()
		-- Pass both command text and source channel name
		return processCommand:InvokeServer(messageText, channelName)
	end)

	if success then
		_annotate(string.format("Info: Command handled successfully (result=%s)", tostring(resultOrErr)))
		return true
	end

	local errMessage = string.format("Error: Command processing error: %s", tostring(resultOrErr))
	_annotate(errMessage)
	warn(errMessage)
	return false
end

function ChatUI:GetIncomingMessageHandler(): (TextChatMessage) -> TextChatMessageProperties?
	return function(message: TextChatMessage): TextChatMessageProperties?
		_annotate(
			string.format(
				"Notice: OnIncomingMessage fired. Channel: %s, Text: %s",
				tostring(message and message.TextChannel and message.TextChannel.Name or "nil"),
				tostring(message and message.Text or "nil")
			)
		)
		return self:HandleIncomingMessage(message)
	end
end

function ChatUI:HandleIncomingMessage(message: TextChatMessage): TextChatMessageProperties?
	if not message or not message.TextChannel then
		_annotate("Warn: Received message with no TextChannel")
		return createEmptyProperties()
	end

	local channelName = message.TextChannel.Name
	local messageText = message.Text or ""
	local textSource: TextSource? = message.TextSource

	if messageText == "" and textSource ~= nil then
		return createEmptyProperties()
	end

	-- Intercept slash commands in any channel - suppress completely to prevent any display
	if messageText:sub(1, 1) == "/" then
		local suppressProps = createEmptyProperties()
		suppressProps.Text = ""
		suppressProps.PrefixText = ""
		return suppressProps
	end

	-- System messages should always be allowed
	-- System messages have no TextSource OR TextSource.UserId is nil/0
	local isSystemMessage = false
	if textSource == nil then
		isSystemMessage = true
	else
		-- textSource is not nil here, but linter needs explicit check
		local checkedTextSource: TextSource = textSource :: TextSource
		local userId = checkedTextSource.UserId
		if userId == nil or userId == 0 then
			isSystemMessage = true
		end
	end

	if isSystemMessage then
		_annotate(string.format("Info: System message allowed in channel %s", channelName))
		return nil
	end

	-- Respect channel configuration for user generated chat
	if not channelManager.ShouldAllowUserMessages(channelName) then
		_annotate(string.format("Info: User messages blocked in channel %s", channelName))
		return createEmptyProperties()
	end

	-- Apply username colors for user messages in main tabs
	-- Get username and determine color
	-- At this point, textSource cannot be nil (system messages returned early)
	if not textSource then
		_annotate("Warn: Unexpected nil textSource after system message check")
		return createEmptyProperties()
	end
	
	-- textSource is now guaranteed to be non-nil
	local nonNilTextSource: TextSource = textSource :: TextSource
	local localPlayer = Players.LocalPlayer
	local userId: number? = nonNilTextSource.UserId
	if not userId then
		_annotate("Warn: User message has no userId, cannot apply color")
		return nil
	end

	local userIdNumber: number = userId :: number
	local isLocalPlayer = localPlayer and userIdNumber == localPlayer.UserId

	-- Get username from Players service
	local username: string = "Player"
	local player = Players:GetPlayerByUserId(nonNilTextSource.UserId)
	if player then
		username = player.Name
	end

	-- Determine color: meColor for local player, otherGuyPresentColor for others
	local usernameColor: Color3 = colors.otherGuyPresentColor
	if isLocalPlayer then
		usernameColor = colors.meColor
	end

	-- Format username with color using RichText
	local coloredUsername = MessageFormatter.formatWithColor(username, usernameColor)
	local prefixText = coloredUsername .. ": "

	-- Create properties with colored prefix
	local props = Instance.new("TextChatMessageProperties")
	props.PrefixText = prefixText
	props.Text = messageText

	_annotate(
		string.format(
			"Info: Applied username color for user message. channel=%s userId=%d username=%s color=%s",
			channelName,
			userId or 0,
			username,
			isLocalPlayer and "meColor" or "otherGuyPresentColor"
		)
	)

	return props
end

_annotate("end")
return ChatUI
