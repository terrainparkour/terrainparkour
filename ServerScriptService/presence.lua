--!strict
--serversign player joining setup - subbing to events, etc.

local leaderboardEvents = require(game.ServerScriptService.leaderboardEvents)
local leaderboardBadgeEvents = require(game.ServerScriptService.leaderboardBadgeEvents)
local playerMonitoring = require(game.ServerScriptService.playerStateMonitoringFuncs)
local badgeCheckers = require(game.ServerScriptService.badgeCheckersSecret)
local nomesh = require(game.ServerScriptService.noMesh)

local PlayersService = game:GetService("Players")

local module = {}
type storedFunc = { func: (player: Player) -> nil, name: string }

local playerAddFuncs: { storedFunc } = {}
local playerRemovingFuncs: { storedFunc } = {}

local doAnnotation = false
-- doAnnotation = true
local annotationStart = tick()
local function annotate(s: string)
	if doAnnotation then
		print("joinSetup: " .. string.format("%.2f", tick() - annotationStart) .. " : " .. s)
	end
end

local function applyPlayerAddFuncs(player: Player)
	for _, storedFunc: storedFunc in pairs(playerAddFuncs) do
		spawn(function()
			annotate("running.Add " .. storedFunc.name .. " on " .. player.Name)
			storedFunc.func(player)
		end)
	end
end

local function applyPlayerRemovingFuncs(player: Player)
	for _, storedFunc in pairs(playerRemovingFuncs) do
		annotate("running.Removing " .. storedFunc.name .. " on " .. player.Name)
		spawn(function()
			storedFunc.func(player)
		end)
	end
end

module.init = function()
	table.insert(playerAddFuncs, { func = playerMonitoring.PreloadFinds, name = "preloadFinds" })
	table.insert(playerAddFuncs, { func = playerMonitoring.LogJoin, name = "logJoin" })
	table.insert(playerAddFuncs, { func = playerMonitoring.BackfillBadges, name = "BackfillBadges" })
	table.insert(playerAddFuncs, { func = nomesh.StandardizeCharacter, name = "NoMesh" })
	table.insert(playerAddFuncs, { func = badgeCheckers.MetCreatorChecker, name = "setupMetCreatorChecker" })
	table.insert(playerAddFuncs, { func = badgeCheckers.BumpedCreatorChecker, name = "setupBumpedCreatorChecker" })
	table.insert(playerAddFuncs, { func = badgeCheckers.CrowdedHouseChecker, name = "setupCrowdedHouseChecker" })
	table.insert(playerAddFuncs, { func = playerMonitoring.LogLocationOnDeath, name = "logLocationOnDeath" })
	table.insert(
		playerAddFuncs,
		{ func = leaderboardEvents.UpdateOthersAboutJoinerLb, name = "UpdateOthersAboutJoinerLb" }
	)
	table.insert(playerAddFuncs, { func = leaderboardEvents.SetPlayerToReceiveUpdates, name = "UpdateOwnLeaderboard" })
	table.insert(
		playerAddFuncs,
		{ func = leaderboardBadgeEvents.TellPlayerAboutAllOthersBadges, name = "TellAllAboutMeBadges" }
	)
	table.insert(playerAddFuncs, { func = leaderboardBadgeEvents.TellMeAboutOBadges, name = "TellMeAboutOBadges" })
	table.insert(playerAddFuncs, { func = leaderboardEvents.PostJoinToRacersImmediate, name = "PostJoinToRacers" })

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
		{ func = leaderboardEvents.RemoveFromLeaderboardImmediate, name = "RemoveFromLeaderboard" }
	)
	table.insert(
		playerRemovingFuncs,
		{ func = leaderboardEvents.PostLeaveToRacersImmediate, name = "PostLeaveToRacers" }
	)

	PlayersService.PlayerRemoving:Connect(applyPlayerRemovingFuncs)

	--players 100% gone by this point but whatever.
	game:BindToClose(function()
		for _, player in pairs(game.Players:GetPlayers()) do
			for _, func in ipairs(playerRemovingFuncs) do
				print("calling final server close: " .. func.name .. " on " .. player.Name)
				func.func(player)
			end
		end
	end)
end

return module
