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
	local start = tick()
	local _character = player.Character or player.CharacterAdded:Wait()
	local playerCount = #PlayerService:GetPlayers()
	_annotate(string.format("updatePlayerLbAboutAll START for %s (%d players)", player.Name, playerCount))
	
	for _, otherPlayer: Player in ipairs(PlayerService:GetPlayers()) do
		local fetchStart = tick()
		local lbUserStats: tt.lbUserStats = playerData2.GetStatsByUserId(otherPlayer.UserId, "update joiner lb")
		local fetchTime = tick() - fetchStart
		lbUpdaterServer.SendUpdateToPlayer(player, lbUserStats)
		if fetchTime > 0.1 then
			_annotate(string.format("  slow GetStats for %s: %.3fs", otherPlayer.Name, fetchTime))
		end
	end
	
	_annotate(string.format("updatePlayerLbAboutAll DONE for %s (%.3fs, %d players)", 
		player.Name, tick() - start, playerCount))
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
	local _character = player.Character or player.CharacterAdded:Wait()
	updatePlayerLbAboutAllImmediate(player)
end

local updateOthersAboutPlayerImmediate = function(player: Player)
	local start = tick()
	local fetchStart = tick()
	local lbUserStats: tt.lbUserStats = playerData2.GetStatsByUserId(player.UserId, "updateOthersAboutPlayerImmediate")
	local fetchTime = tick() - fetchStart
	
	local otherPlayerCount = 0
	for _, otherPlayer in ipairs(PlayerService:GetPlayers()) do
		if otherPlayer.UserId == player.UserId then
			continue
		end
		otherPlayerCount = otherPlayerCount + 1
		lbUpdaterServer.SendUpdateToPlayer(otherPlayer, lbUserStats)
	end
	
	_annotate(string.format("updateOthersAbout DONE for %s (%.3fs: %.3fs fetch + %.3fs send to %d players)", 
		player.Name, tick() - start, fetchTime, tick() - start - fetchTime, otherPlayerCount))
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
