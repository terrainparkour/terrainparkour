--!strict
--serversign player joining setup - subbing to events, etc.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local leaderboardServer = require(game.ServerScriptService.leaderboardServer)
local leaderboardBadgeEvents = require(game.ServerScriptService.leaderboardBadgeEvents)
local playerMonitoring = require(game.ServerScriptService.playerStateMonitoringFuncs)
local badgeCheckers = require(game.ServerScriptService.badgeCheckersSecret)
local nomesh = require(game.ServerScriptService.noMesh)
local playerData2 = require(game.ServerScriptService.playerData2)
local PlayersService = game:GetService("Players")
local joiningServer = require(game.ServerScriptService.joiningServer)

local module = {}
type storedFunc = { func: (player: Player) -> nil, name: string }

local playerAddFuncs: { storedFunc } = {}
local playerRemovingFuncs: { storedFunc } = {}

local function applyPlayerAddFuncs(player: Player)
	for _, storedFunc: storedFunc in pairs(playerAddFuncs) do
		task.spawn(function()
			_annotate("running.Add " .. storedFunc.name .. " on " .. player.Name)
			storedFunc.func(player)
		end)
	end
end

local function applyPlayerRemovingFuncs(player: Player)
	for _, storedFunc in pairs(playerRemovingFuncs) do
		_annotate("running.Removing " .. storedFunc.name .. " on " .. player.Name)
		task.spawn(function()
			storedFunc.func(player)
		end)
	end
end

local function preloadFinds(player: Player)
	playerData2.HasUserFoundSign(player.UserId, 1)
end

module.Init = function()
	table.insert(playerAddFuncs, { func = preloadFinds, name = "preloadFinds" })
	table.insert(playerAddFuncs, { func = playerMonitoring.LogJoin, name = "logJoin" })
	table.insert(playerAddFuncs, { func = playerMonitoring.BackfillBadges, name = "BackfillBadges" })
	table.insert(playerAddFuncs, { func = nomesh.StandardizeCharacter, name = "NoMesh" })
	table.insert(playerAddFuncs, { func = badgeCheckers.JoinerCheckers, name = "badgeChecksWhileJoining" })
	table.insert(playerAddFuncs, { func = playerMonitoring.LogLocationOnDeath, name = "logLocationOnDeath" })
	table.insert(
		playerAddFuncs,
		{ func = leaderboardServer.UpdateOthersAboutJoinerLb, name = "UpdateOthersAboutJoinerLb" }
	)
	table.insert(playerAddFuncs, { func = leaderboardServer.SetPlayerToReceiveUpdates, name = "UpdateOwnLeaderboard" })
	table.insert(
		playerAddFuncs,
		{ func = leaderboardBadgeEvents.TellPlayerAboutAllOthersBadges, name = "TellAllAboutMeBadges" }
	)
	table.insert(playerAddFuncs, { func = leaderboardBadgeEvents.TellMeAboutOBadges, name = "TellMeAboutOBadges" })
	table.insert(playerAddFuncs, { func = joiningServer.PostJoinToRacersImmediate, name = "PostJoinToRacers" })

	PlayersService.PlayerAdded:Connect(applyPlayerAddFuncs)

	--backfill.
	for _, player: Player in ipairs(PlayersService:GetPlayers()) do
		--"retroactive" re-simulate them joining.
		applyPlayerAddFuncs(player)
	end

	table.insert(playerRemovingFuncs, { func = playerMonitoring.LogQuit, name = "LogQuit" })
	table.insert(playerRemovingFuncs, { func = playerMonitoring.LogPlayerLeft, name = "LogPlayerLeft" })
	table.insert(
		playerRemovingFuncs,
		{ func = leaderboardServer.RemoveFromLeaderboardImmediate, name = "RemoveFromLeaderboard" }
	)
	table.insert(playerRemovingFuncs, { func = joiningServer.PostLeaveToRacersImmediate, name = "PostLeaveToRacers" })

	PlayersService.PlayerRemoving:Connect(applyPlayerRemovingFuncs)

	--players 100% gone by this point but whatever.
	game:BindToClose(function()
		for _, player in pairs(game.Players:GetPlayers()) do
			for _, func in ipairs(playerRemovingFuncs) do
				_annotate("calling final server close: " .. func.name .. " on " .. player.Name)
				func.func(player)
			end
		end
	end)
end

_annotate("end")
return module
