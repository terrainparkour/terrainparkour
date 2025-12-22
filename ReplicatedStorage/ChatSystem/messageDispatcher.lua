--!strict

-- messageDispatcher.lua :: ReplicatedStorage.ChatSystem.messageDispatcher
-- Sends RichText system messages into TextChat channels via RemoteEvent (server-only).

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local channelManager = require(game.ReplicatedStorage.ChatSystem.channelManager)
local remotes = require(game.ReplicatedStorage.util.remotes)
local messageFormatter = require(game.ReplicatedStorage.ChatSystem.messageFormatter)

type MessageOptions = {
	ChatColor: Color3?,
}

local module = {}

local function formatText(text: string, options: MessageOptions?): string
	if not options then
		return text
	end

	local formatted = text
	if options.ChatColor then
		formatted = messageFormatter.formatWithColor(formatted, options.ChatColor)
	end
	return formatted
end

module.SendSystemMessage = function(channelName: string, text: string, options: MessageOptions?): ()
	local channel = channelManager.GetChannel(channelName)
	if not channel then
		error(string.format("SendSystemMessage: channel '%s' not registered. Valid channels: Chat, Data, Joins", channelName))
	end

	local formatted = formatText(text, options)
	local displayMsgEvent = remotes.getRemoteEvent("DisplaySystemMessageEvent")
	displayMsgEvent:FireAllClients(formatted, channelName)
	_annotate(string.format("SendSystemMessage -> [%s]: %s", channelName, text))
end

module.SendSystemMessageToPlayer = function(player: Player, channelName: string, text: string, options: MessageOptions?): ()
	local channel = channelManager.GetChannel(channelName)
	if not channel then
		error(string.format("SendSystemMessageToPlayer: channel '%s' not registered. Valid channels: Chat, Data, Joins", channelName))
	end

	local formatted = formatText(text, options)
	local displayMsgEvent = remotes.getRemoteEvent("DisplaySystemMessageEvent")
	displayMsgEvent:FireClient(player, formatted, channelName)
	_annotate(string.format("SendSystemMessageToPlayer -> player=%s channel=[%s]: %s", player.Name, channelName, text))
end

_annotate("end")
return module
