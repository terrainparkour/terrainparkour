--!strict

-- joiningServer some notifications.
-- on join type methods for triggering other players local LBs to update.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local colors = require(game.ReplicatedStorage.util.colors)
local channelDefinitions = require(game.ReplicatedStorage.chat.channelDefinitions)
local playerData2 = require(game.ServerScriptService.playerData2)

local module = {}

local racersChannel

module.PostJoinToRacersImmediate = function(player: Player)
	racersChannel = channelDefinitions.GetChannel("Racers")
	_annotate("Posting join to racers: " .. player.Name)
	local statTag = playerData2.GetPlayerDescriptionLine(player.UserId)
	local text = player.Name .. " joined! " .. statTag
	local options = { ChatColor = colors.greenGo }
	racersChannel:SendSystemMessage(text, options)
end

module.PostLeaveToRacersImmediate = function(player: Player)
	racersChannel = channelDefinitions.GetChannel("Racers")
	_annotate("Posting leave to racers: " .. player.Name)
	local statTag = playerData2.GetPlayerDescriptionLine(player.UserId)
	local text = player.Name .. " left! " .. statTag
	local options = { ChatColor = colors.redStop }
	racersChannel:SendSystemMessage(text, options)
end

_annotate("end")
return module
