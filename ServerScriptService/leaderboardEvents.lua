--!strict

-- on join type methods for triggering other players local LBs to update.

--eval 9.25.22

local PlayerService = game:GetService("Players")
local colors = require(game.ReplicatedStorage.util.colors)
local channelDefinitions = require(game.ReplicatedStorage.chat.channelDefinitions)
local playerdata = require(game.ServerScriptService.playerdata)
local lbupdater = require(game.ServerScriptService.lbupdater)
local tt = require(game.ReplicatedStorage.types.gametypes)

local module = {}

local racersChannel = channelDefinitions.getChannel("Racers")

local doAnnotation = false

local function annotate(s: string)
	if doAnnotation then
		print("server: " .. string.format("%.0f", tick()) .. " : " .. s)
	end
end

--leaver should be updated to everyone
module.RemoveFromLeaderboard = function(player: Player)
	for _, otherPlayer in ipairs(PlayerService:GetPlayers()) do
		if otherPlayer.UserId == player.UserId then
			continue --skip why not?
		end
		lbupdater.updateLeaderboardForLeave(otherPlayer, player.UserId)
	end
end

module.PostJoinToRacers = function(player: Player)
	local character = player.Character or player.CharacterAdded:Wait()
	local statTag = playerdata.getPlayerDescriptionLine(player.UserId)
	local text = player.Name .. " joined! " .. statTag
	local options = { ChatColor = colors.greenGo }
	racersChannel:SendSystemMessage(text, options)
end

module.PostLeaveToRacers = function(player: Player)
	local statTag = playerdata.getPlayerDescriptionLine(player.UserId)
	local text = player.Name .. " left! " .. statTag
	local options = { ChatColor = colors.redStop }
	racersChannel:SendSystemMessage(text, options)
end

local function updateSomeone(player: Player)
	local character = player.Character or player.CharacterAdded:Wait()
	for _, otherPlayer: Player in ipairs(PlayerService:GetPlayers()) do
		local stats: tt.afterData_getStatsByUser =
			playerdata.getPlayerStatsByUserId(otherPlayer.UserId, "update joiner lb")
		lbupdater.updateLeaderboardForJoin(player, stats)
	end
end

module.UpdateOwnLeaderboard = function(player: Player)
	player.CharacterAdded:Connect(function(_)
		return updateSomeone(player)
	end)
	local character = player.Character or player.CharacterAdded:Wait()
	updateSomeone(player)
end

local function updateOthersAboutPlayer(player: Player)
	local stats: tt.afterData_getStatsByUser =
		playerdata.getPlayerStatsByUserId(player.UserId, "update other about joiner")
	local character = player.Character or player.CharacterAdded:Wait()
	for _, otherPlayer in ipairs(PlayerService:GetPlayers()) do
		lbupdater.updateLeaderboardForJoin(otherPlayer, stats)
	end
end

module.UpdateOthersAboutJoinerLb = function(player: Player)
	player.CharacterAdded:Connect(function(_)
		updateOthersAboutPlayer(player)
	end)
	updateOthersAboutPlayer(player)
end
return module
