--!strict

-- runEnding.server.lua listens for race end events sent from the client and just trusts them.
-- I have total control on the db side anyway

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local tt = require(game.ReplicatedStorage.types.gametypes)
local enums = require(game.ReplicatedStorage.util.enums)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local signInfo = require(game.ReplicatedStorage.signInfo)
local rdb = require(game.ServerScriptService.rdb)
local banning = require(game.ServerScriptService.banning)
local raceCompleteData = require(game.ServerScriptService.raceCompleteData)
local lbUpdaterServer = require(game.ServerScriptService.lbUpdaterServer)
local badgeCheckers = require(game.ServerScriptService.badgeCheckersSecret)
local remotes = require(game.ReplicatedStorage.util.remotes)

local PlayerService = game:GetService("Players")
local TellServerRunEndedRemoteEvent = remotes.getRemoteEvent("TellServerRunEndedRemoteEvent")
local ServerEventBindableEvent = remotes.getBindableEvent("ServerEventBindableEvent")

--in new trust the client code, just call this directly with the actual details.
--note: it would be nice to retain server-side timing to detect hackers. nearly every one would give themselves away.
local function receiveClientMessageAboutRunEnding(
	player: Player,
	startSignName: string,
	endSignName: string,
	runMilliseconds: number,
	floorSeenCount: number
)
	if banning.getBanLevel(player.UserId) > 0 then
		_annotate(
			string.format("ban level > 0, not saving run for userName=%s, userId: %d", player.Name, player.UserId)
		)
		return
	end

	local userId: number = player.UserId
	local startSignId: number = enums.namelower2signId[startSignName:lower()]
	local endSignId: number = enums.namelower2signId[endSignName:lower()]
	local startSignPosition: Vector3 = signInfo.getSignPosition(startSignId)
	local endSignPosition: Vector3 = signInfo.getSignPosition(endSignId)
	local distance: number = (startSignPosition - endSignPosition).Magnitude
	local raceName: string = startSignName .. " to " .. endSignName
	local speed: number = math.ceil(distance / runMilliseconds * 100) / 100

	local rawUserIdsInServer: { number } = tpUtil.GetUserIdsInServer()

	local userIds: string = table.concat(rawUserIdsInServer, ",")

	--this is where we save the time to db, and then continue to display runresults.
	task.spawn(function()
		local userFinishedRunOptions: tt.userFinishedRunOptions = {
			userId = userId,
			startSignId = startSignId,
			endSignId = endSignId,
			runMilliseconds = runMilliseconds,
			allPlayerUserIds = userIds,
			remoteActionName = "userFinishedRun",
		}
		local userFinishedRunResponse: tt.pyUserFinishedRunResponse = rdb.userFinishedRun(userFinishedRunOptions)

		task.spawn(function()
			badgeCheckers.CheckBadgeGrantingAfterRun(
				userId,
				userFinishedRunResponse,
				startSignId,
				endSignId,
				floorSeenCount
			)
		end)

		_annotate("showbesttimes for: " .. tostring(userId))
		raceCompleteData.showBestTimes(player, raceName, startSignId, endSignId, speed, false, userFinishedRunResponse)

		_annotate("preparing data to send to update everyone's LBs")

		-- okay, we simplify the full run response data into just the stuff the LB needs and send that on.
		-- name juggling here has definitely caused problems.
		local lbRunUpdate: tt.lbUpdateFromRun = {
			kind = "lbUpdate from run",
			userId = userId,
			userTix = userFinishedRunResponse.userTix,
			cwrs = userFinishedRunResponse.cwrs,
			cwrTop10s = userFinishedRunResponse.cwrTop10s,
			top10s = userFinishedRunResponse.top10s,
			userTotalRaceCount = userFinishedRunResponse.userTotalRaceCount,
			userTotalRunCount = userFinishedRunResponse.userTotalRunCount,
			wrCount = userFinishedRunResponse.wrCount,
			wrRank = userFinishedRunResponse.wrRank,
			daysInGame = userFinishedRunResponse.daysInGame,
			awardCount = userFinishedRunResponse.awardCount,
		}

		for _, anyPlayer in ipairs(PlayerService:GetPlayers()) do
			lbUpdaterServer.updateLeaderboardForRun(anyPlayer, lbRunUpdate)
		end
	end)

	-- this is for tracking server event scores too. weird we do it here.
	local data: tt.serverFinishRunNotifierType = {
		startSignId = startSignId,
		endSignId = endSignId,
		timeMs = runMilliseconds,
		userId = userId,
		username = rdb.getUsernameByUserId(userId),
	}
	ServerEventBindableEvent:Fire(data)
end

TellServerRunEndedRemoteEvent.OnServerEvent:Connect(receiveClientMessageAboutRunEnding)

module.Init = function() end

_annotate("end")
return module
