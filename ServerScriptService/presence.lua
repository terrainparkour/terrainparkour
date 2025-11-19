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
	local overallStart = tick()
	_annotate(string.format("Player.Add START for %s (userId: %d)", player.Name, player.UserId))
	
	for _, storedFunc: storedFunc in pairs(playerAddFuncs) do
		task.spawn(function()
			local start = tick()
			_annotate(string.format("Player.Add.%s START %s", storedFunc.name, player.Name))
			local success, err = pcall(function()
				storedFunc.func(player)
			end)
			local elapsed = tick() - start
			if success then
				_annotate(string.format("Player.Add.%s DONE %s (%.3fs)", storedFunc.name, player.Name, elapsed))
			else
				annotater.Error(string.format("Player.Add.%s FAILED %s after %.3fs: %s", 
					storedFunc.name, player.Name, elapsed, tostring(err)))
			end
		end)
	end
	
	-- Note: functions run in parallel, so this just tracks dispatch time
	local dispatchTime = tick() - overallStart
	_annotate(string.format("Player.Add DISPATCHED %d funcs for %s (%.3fs)", 
		#playerAddFuncs, player.Name, dispatchTime))
end

local function applyPlayerRemovingFuncs(player: Player)
	_annotate(string.format("Player.Remove START for %s (userId: %d)", player.Name, player.UserId))
	
	for _, storedFunc in pairs(playerRemovingFuncs) do
		task.spawn(function()
			local start = tick()
			_annotate(string.format("Player.Remove.%s START %s", storedFunc.name, player.Name))
			local success, err = pcall(function()
				storedFunc.func(player)
			end)
			local elapsed = tick() - start
			if success then
				_annotate(string.format("Player.Remove.%s DONE %s (%.3fs)", storedFunc.name, player.Name, elapsed))
			else
				annotater.Error(string.format("Player.Remove.%s FAILED %s after %.3fs: %s", 
					storedFunc.name, player.Name, elapsed, tostring(err)))
			end
		end)
	end
end

local function preloadFinds(player: Player)
	local start = tick()
	playerData2.HasUserFoundSign(player.UserId, 1)
	_annotate(string.format("preloadFinds DONE for %s (%.3fs)", player.Name, tick() - start))
	return nil
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
	table.insert(playerAddFuncs, { func = joiningServer.PostJoinToJoinsImmediate, name = "PostJoinToJoins" })

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
	table.insert(playerRemovingFuncs, { func = joiningServer.PostLeaveToJoinsImmediate, name = "PostLeaveToJoins" })

	PlayersService.PlayerRemoving:Connect(applyPlayerRemovingFuncs)

	--players 100% gone by this point but whatever.
	game:BindToClose(function()
		for _, player in pairs(PlayersService:GetPlayers()) do
			for _, func in ipairs(playerRemovingFuncs) do
				_annotate("calling final server close: " .. func.name .. " on " .. player.Name)
				func.func(player)
			end
		end
	end)
end

_annotate("end")
return module
