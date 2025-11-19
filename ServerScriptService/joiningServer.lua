--!strict

-- joiningServer some notifications.
-- on join type methods for triggering other players local LBs to update.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local colors = require(game.ReplicatedStorage.util.colors)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MessageDispatcher = require(ReplicatedStorage.ChatSystem.messageDispatcher)
local playerData2 = require(game.ServerScriptService.playerData2)

local module = {}

local function formatTime(): string
	local time = os.date("*t", os.time())
	return string.format("%02d:%02d:%02d", time.hour, time.min, time.sec)
end

local function getServerPlayerCount(): number
	return #Players:GetPlayers()
end

-- Module internals
module.PostJoinToJoinsImmediate = function(player: Player)
	local start = tick()
	local fetchStart = tick()
	local statTag = playerData2.GetPlayerDescriptionLine(player.UserId)
	local fetchTime = tick() - fetchStart
	local timeStr = formatTime()
	local playerCount = getServerPlayerCount()
	local text = string.format("[%s] %s joined! (%d players) %s", timeStr, player.Name, playerCount, statTag)
	local options = { ChatColor = colors.greenGo }
	if not MessageDispatcher.SendSystemMessage("Joins", text, options) then
		return
	end
	_annotate(
		string.format("PostJoinToJoins DONE for %s (%.3fs: %.3fs fetch)", player.Name, tick() - start, fetchTime)
	)
end

module.PostLeaveToJoinsImmediate = function(player: Player)
	_annotate("Posting leave to joins: " .. player.Name)
	local statTag = playerData2.GetPlayerDescriptionLine(player.UserId)
	local timeStr = formatTime()
	local playerCount = getServerPlayerCount()
	local text = string.format("[%s] %s left! (%d players) %s", timeStr, player.Name, playerCount, statTag)
	local options = { ChatColor = colors.redStop }
	MessageDispatcher.SendSystemMessage("Joins", text, options)
end

_annotate("end")
return module
