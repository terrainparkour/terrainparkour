--!strict

-- on join type methods for triggering other players local LBs to update.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayerService = game:GetService("Players")
local colors = require(game.ReplicatedStorage.util.colors)
local channeldefinitions = require(game.ReplicatedStorage.chat.channeldefinitions)
local playerdata = require(game.ServerScriptService.playerdata)
local lbupdater = require(game.ServerScriptService.lbupdater)
local tt = require(game.ReplicatedStorage.types.gametypes)

local module = {}

local racersChannel = channeldefinitions.getChannel("Racers")

--this whole set of functions seems highly strange.
-- why should this be so hard?
-- a lot of them are of the form: when a player joins the server, set further rules such taht if they
-- do something else, update other people?
-- i don't get why instead it isn't like, when a player joins, they should get everyone's current state, and also subscribe to new updates.
-- so it's basically: catchup, follow.

--leaver should be updated to everyone. this is called when a player actually leaves.
module.RemoveFromLeaderboardImmediate = function(player: Player)
	--_annotate("this player left: " .. player.Name)
	for _, otherPlayer in ipairs(PlayerService:GetPlayers()) do
		if otherPlayer.UserId == player.UserId then
			continue
		end
		lbupdater.sendLeaveInfoToSomeone(otherPlayer, player.UserId)
	end
end

module.PostJoinToRacersImmediate = function(player: Player)
	--_annotate("Posting join to racers: " .. player.Name)
	local character = player.Character or player.CharacterAdded:Wait()
	local statTag = playerdata.getPlayerDescriptionLine(player.UserId)
	local text = player.Name .. " joined! " .. statTag
	local options = { ChatColor = colors.greenGo }
	racersChannel:SendSystemMessage(text, options)
end

module.PostLeaveToRacersImmediate = function(player: Player)
	--_annotate("Posting leave to racers: " .. player.Name)
	local statTag = playerdata.getPlayerDescriptionLine(player.UserId)
	local text = player.Name .. " left! " .. statTag
	local options = { ChatColor = colors.redStop }
	racersChannel:SendSystemMessage(text, options)
end

--update joiner about current players
local function updatePlayerLbAboutAllImmediate(player: Player)
	local character = player.Character or player.CharacterAdded:Wait()
	for _, otherPlayer: Player in ipairs(PlayerService:GetPlayers()) do
		local stats: tt.afterData_getStatsByUser =
			playerdata.getPlayerStatsByUserId(otherPlayer.UserId, "update joiner lb")
		lbupdater.sendUpdateToPlayer(player, stats)
		--_annotate(string.format("Updating player: %s about %s", player.Name, otherPlayer.Name))
	end
end

module.SetPlayerToReceiveUpdates = function(player: Player)
	--_annotate("Setting player to receive updates: " .. player.Name)
	player.CharacterAdded:Connect(function(_)
		--_annotate("Player " .. player.Name .. " was added, so telling " .. player.Name .. " about it.")
		return updatePlayerLbAboutAllImmediate(player)
	end)
	local character = player.Character or player.CharacterAdded:Wait()
	updatePlayerLbAboutAllImmediate(player)
end

local function updateOthersAboutPlayerImmediate(player: Player)
	local stats: tt.afterData_getStatsByUser =
		playerdata.getPlayerStatsByUserId(player.UserId, "update other about joiner")
	local character = player.Character or player.CharacterAdded:Wait()
	for _, otherPlayer in ipairs(PlayerService:GetPlayers()) do
		if otherPlayer.UserId == player.UserId then
			continue
		end
		--_annotate(string.format("Updating %s about player: %s", otherPlayer.Name, player.Name))
		lbupdater.sendUpdateToPlayer(otherPlayer, stats)
	end
end

-- when a player is added
-- we make it so that, for that player,
-- when that player initially spawns (or respawns)
module.UpdateOthersAboutJoinerLb = function(player: Player)
	player.CharacterAdded:Connect(function()
		--_annotate("Player " .. player.Name .. " was added, so telling others about it - top.")
		updateOthersAboutPlayerImmediate(player)
	end)
	--_annotate("Player " .. player.Name .. " initial add backfull, so telling others.")
	updateOthersAboutPlayerImmediate(player)
end

_annotate("end")
return module
