--!strict

-- leaderboardServer.lua
-- on join type methods for triggering other players local LBs to update.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayerService = game:GetService("Players")

local playerData2 = require(game.ServerScriptService.playerData2)
local tt = require(game.ReplicatedStorage.types.gametypes)
local lbUpdaterServer = require(game.ServerScriptService.lbUpdaterServer)

local module = {}

--this whole set of functions seems highly strange.
-- why should this be so hard?
-- a lot of them are of the form: when a player joins the server, set further rules such taht if they
-- do something else, update other people?
-- i don't get why instead it isn't like, when a player joins, they should get everyone's current state, and also subscribe to new updates.
-- so it's basically: catchup, follow.

--leaver should be updated to everyone. this is called when a player actually leaves.
module.RemoveFromLeaderboardImmediate = function(player: Player)
	_annotate("this player left: " .. player.Name)
	for _, otherPlayer in ipairs(PlayerService:GetPlayers()) do
		if otherPlayer.UserId == player.UserId then
			continue
		end
		lbUpdaterServer.SendLeaveInfoToSomeone(otherPlayer, player.UserId)
	end
end

--update joiner about current players
local function updatePlayerLbAboutAllImmediate(player: Player)
	local character = player.Character or player.CharacterAdded:Wait()
	for _, otherPlayer: Player in ipairs(PlayerService:GetPlayers()) do
		local lbUserStats: tt.lbUserStats = playerData2.GetStatsByUserId(otherPlayer.UserId, "update joiner lb")
		lbUpdaterServer.SendUpdateToPlayer(player, lbUserStats)
		_annotate(string.format("Updating player: %s about %s", player.Name, otherPlayer.Name))
	end
end

module.UpdateAllAboutPlayerImmediate = function(player: Player)
	local lbUserStats: tt.lbUserStats =
		playerData2.GetStatsByUserId(player.UserId, "user did sth which requires telling everyone about it.")
	for _, otherPlayer: Player in ipairs(PlayerService:GetPlayers()) do
		lbUpdaterServer.SendUpdateToPlayer(otherPlayer, lbUserStats)
		_annotate(string.format("Updating player: %s about %s", otherPlayer.Name, player.Name))
	end
end

module.SetPlayerToReceiveUpdates = function(player: Player)
	_annotate("Setting player to receive updates: " .. player.Name)
	player.CharacterAdded:Connect(function(_)
		_annotate("Player " .. player.Name .. " was added, so telling " .. player.Name .. " about it.")
		return updatePlayerLbAboutAllImmediate(player)
	end)
	local character = player.Character or player.CharacterAdded:Wait()
	updatePlayerLbAboutAllImmediate(player)
end

local updateOthersAboutPlayerImmediate = function(player: Player)
	local lbUserStats: tt.lbUserStats = playerData2.GetStatsByUserId(player.UserId, "updateOthersAboutPlayerImmediate")
	for _, otherPlayer in ipairs(PlayerService:GetPlayers()) do
		if otherPlayer.UserId == player.UserId then
			continue
		end
		_annotate(string.format("Updating %s about player: %s", otherPlayer.Name, player.Name))
		lbUpdaterServer.SendUpdateToPlayer(otherPlayer, lbUserStats)
	end
end

-- when a player is added
-- we make it so that, for that player,
-- when that player initially spawns (or respawns)
module.UpdateOthersAboutJoinerLb = function(player: Player)
	player.CharacterAdded:Connect(function()
		_annotate("Player " .. player.Name .. " was added, so telling others about it - top.")
		updateOthersAboutPlayerImmediate(player)
	end)
	_annotate("Player " .. player.Name .. " initial add backfull, so telling others.")
	updateOthersAboutPlayerImmediate(player)
end

_annotate("end")
return module
