--!strict

-- MessageDispatcher.lua :: ReplicatedStorage.ChatSystem.MessageDispatcher
-- Sends RichText system messages into TextChat channels via RemoteEvent (server-only).

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChannelManager = require(script.Parent.channelManager)
local MessageFormatter = require(script.Parent.messageFormatter)

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
		formatted = MessageFormatter.formatWithColor(formatted, options.ChatColor)
	end
	return formatted
end

module.SendSystemMessage = function(channelName: string, text: string, options: MessageOptions?): boolean
	local channel = ChannelManager.GetChannel(channelName)
	if not channel then
		annotater.Error("SendSystemMessage missing channel", {
			channelName = channelName,
			text = text,
		})
		return false
	end

	local formatted = formatText(text, options)
	local remoteEventFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remoteEventFolder then
		annotater.Error("SendSystemMessage: RemoteEvents folder missing")
		return false
	end
	local displayMsg = remoteEventFolder:FindFirstChild("DisplaySystemMessageEvent")
	if not displayMsg or not displayMsg:IsA("RemoteEvent") then
		annotater.Error("SendSystemMessage: DisplaySystemMessageEvent RemoteEvent missing")
		return false
	end
	displayMsg:FireAllClients(formatted, channelName)
	_annotate(string.format("SendSystemMessage -> [%s]: %s", channelName, text))
	return true
end

module.SendSystemMessageToPlayer = function(
	player: Player,
	channelName: string,
	text: string,
	options: MessageOptions?
): boolean
	local channel = ChannelManager.GetChannel(channelName)
	if not channel then
		annotater.Error("SendSystemMessageToPlayer missing channel", {
			channelName = channelName,
			text = text,
			player = player.Name,
		})
		return false
	end

	local formatted = formatText(text, options)
	local remoteEventFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remoteEventFolder then
		annotater.Error("SendSystemMessageToPlayer: RemoteEvents folder missing")
		return false
	end
	local displayMsg = remoteEventFolder:FindFirstChild("DisplaySystemMessageEvent")
	if not displayMsg or not displayMsg:IsA("RemoteEvent") then
		annotater.Error("SendSystemMessageToPlayer: DisplaySystemMessageEvent RemoteEvent missing")
		return false
	end
	displayMsg:FireClient(player, formatted, channelName)
	_annotate(string.format("SendSystemMessageToPlayer -> player=%s channel=[%s]: %s", player.Name, channelName, text))
	return true
end

_annotate("end")
return module
