--!strict
--eval 9.25.22

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
local annotationStart = tick()
local function annotate(s: string)
	if doAnnotation then
		print("presence.func: " .. string.format("%.3f", tick() - annotationStart) .. " : " .. s)
	end
end

local function applyPlayerJoiningFuncs(player: Player?)
	if player == nil then
		warn("nil player.join")
		return
	end
	assert(player)
	for _, storedFunc: storedFunc in pairs(playerAddFuncs) do
		spawn(function()
			annotate("running.Join " .. storedFunc.name .. " on " .. player.Name)
			storedFunc.func(player)
		end)
	end
end

local function applyPlayerRemovingFuncs(player)
	if player == nil then
		warn("nil player.removing")
		return
	end
	for _, storedFunc in pairs(playerRemovingFuncs) do
		spawn(function()
			annotate("running.Leave " .. storedFunc.name .. " on " .. player.Name)
			storedFunc.func(player)
		end)
	end
end

module.init = function()
	--initial lookup of web data.

	--the action may take place anytime - but we set it up when they join.
	-- (maybe because it has to actually be set up on their character, etc.)
	table.insert(playerAddFuncs, { func = playerMonitoring.PreloadFinds, name = "preloadFinds" })
	table.insert(playerAddFuncs, { func = playerMonitoring.LogJoin, name = "logJoin" })
	table.insert(playerAddFuncs, { func = playerMonitoring.BackfillBadges, name = "BackfillBadges" })
	table.insert(playerAddFuncs, { func = nomesh.StandardizeCharacter, name = "NoMesh" })
	table.insert(playerAddFuncs, { func = badgeCheckers.MetCreatorChecker, name = "setupMetCreatorChecker" })
	table.insert(playerAddFuncs, { func = badgeCheckers.BumpedCreatorChecker, name = "setupBumpedCreatorChecker" })
	table.insert(playerAddFuncs, { func = badgeCheckers.CrowdedHouseChecker, name = "setupCrowdedHouseChecker" })
	-- table.insert(playerAddFuncs, { func = playerMonitoring.CancelRunOnDeath, name = "cancelOnDeath" })
	table.insert(playerAddFuncs, { func = playerMonitoring.LogLocationOnDeath, name = "logLocationOnDeath" })
	table.insert(
		playerAddFuncs,
		{ func = leaderboardEvents.UpdateOthersAboutJoinerLb, name = "UpdateOthersAboutJoinerLb" }
	)
	table.insert(playerAddFuncs, { func = leaderboardEvents.UpdateOwnLeaderboard, name = "UpdateOwnLeaderboard" })
	table.insert(playerAddFuncs, { func = leaderboardBadgeEvents.TellAllAboutMeBadges, name = "TellAllAboutMeBadges" })
	table.insert(playerAddFuncs, { func = leaderboardBadgeEvents.TellMeAboutOBadges, name = "TellMeAboutOBadges" })
	table.insert(playerAddFuncs, { func = leaderboardEvents.PostJoinToRacers, name = "PostJoinToRacers" })

	table.insert(playerRemovingFuncs, { func = playerMonitoring.LogQuit, name = "LogQuit" })
	-- table.insert(
	-- 	playerRemovingFuncs,
	-- 	{ func = playerMonitoring.CancelRunOnPlayerRemove, name = "CancelRunOnPlayerRemove" }
	-- )
	table.insert(playerRemovingFuncs, { func = playerMonitoring.LogPlayerLeft, name = "LogPlayerLeft" })
	table.insert(
		playerRemovingFuncs,
		{ func = leaderboardEvents.RemoveFromLeaderboard, name = "RemoveFromLeaderboard" }
	)
	table.insert(playerRemovingFuncs, { func = leaderboardEvents.PostLeaveToRacers, name = "PostLeaveToRacers" })

	--players joining here will not have any joinfunc run.
	PlayersService.PlayerAdded:Connect(applyPlayerJoiningFuncs)
	PlayersService.PlayerRemoving:Connect(applyPlayerRemovingFuncs)
	-- PlayersService.PlayerDisconnecting:Connect(applyPlayerRemovingFuncs)

	--backfill.
	for _, player: Player in ipairs(PlayersService:GetPlayers()) do
		--"retroactive" re-simulate them joining.
		applyPlayerJoiningFuncs(player)
	end
end

return module
