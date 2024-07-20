--!strict

--2022.03 pulled out commands from channel definitions
--eval 9.21

local textUtil = require(game.ReplicatedStorage.util.textUtil)
local grantBadge = require(game.ServerScriptService.grantBadge)
local enums = require(game.ReplicatedStorage.util.enums)
local text = require(game.ReplicatedStorage.util.text)
local config = require(game.ReplicatedStorage.config)

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local playerdata = require(game.ServerScriptService.playerdata)
local rdb = require(game.ServerScriptService.rdb)
local remoteDbInternal = require(game.ServerScriptService.remoteDbInternal)
local badges = require(game.ServerScriptService.badges)
local leaderboardBadgeEvents = require(game.ServerScriptService.leaderboardBadgeEvents)
local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)
local banning = require(game.ServerScriptService.banning)
local serverwarping = require(game.ServerScriptService.serverwarping)
local tt = require(game.ReplicatedStorage.types.gametypes)
local PopularResponseTypes = require(game.ReplicatedStorage.types.PopularResponseTypes)
local popular = require(game.ServerScriptService.data.popular)
local sendMessageModule = require(game.ReplicatedStorage.chat.sendMessage)
local sm = sendMessageModule.sendMessage

local PlayersService = game:GetService("Players")

local sg=require(game.ReplicatedStorage.commands.profileSguiCreator)

local module = {}

local function prepayerData(targetUserId):tt.playerProfileData
	local res:tt.playerProfileData
	return res	
end

module.profileCommand=function(targetUserId:number, localPlayer:Player)
	local data=prepayerData(targetUserId)
	sg.createSgui(localPlayer, data)
end

return module
