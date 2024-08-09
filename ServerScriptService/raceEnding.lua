--!strict

--very simple

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local tt = require(game.ReplicatedStorage.types.gametypes)
local enums = require(game.ReplicatedStorage.util.enums)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local signInfo = require(game.ReplicatedStorage.signInfo)
local rdb = require(game.ServerScriptService.rdb)
local banning = require(game.ServerScriptService.banning)
local raceCompleteData = require(game.ServerScriptService.raceCompleteData)
local lbupdater = require(game.ServerScriptService.lbupdater)
local badgeCheckers = require(game.ServerScriptService.badgeCheckersSecret)
local remotes = require(game.ReplicatedStorage.util.remotes)

local module = {}

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
		return
	end

	local userId: number = player.UserId
	local startSignId: number = enums.namelower2signId[startSignName:lower()]
	local endSignId: number = enums.namelower2signId[endSignName:lower()]
	local startSignPosition: Vector3 = signInfo.getSignPosition(startSignId)
	local endSignPosition: Vector3 = signInfo.getSignPosition(endSignId)
	local distance: number = (startSignPosition - endSignPosition).Magnitude
	local speed: number = distance / runMilliseconds

	local raceName: string = startSignName .. " to " .. endSignName
	local spd: number = math.ceil(speed * 100) / 100

	local rawUserIds: { number } = tpUtil.GetUserIdsInServer()

	local userIds: string = table.concat(rawUserIds, ",")

	--this is where we save the time to db, and then continue to display runresults.
	task.spawn(function()
		local userFinishedRunOptions: tt.userFinishedRunOptions = {
			userId = userId,
			startId = startSignId,
			endId = endSignId,
			runMilliseconds = runMilliseconds,
			allPlayerUserIds = userIds,
			remoteActionName = "userFinishedRun",
		}
		local userFinishedRunResponse: tt.pyUserFinishedRunResponse = rdb.userFinishedRun(userFinishedRunOptions)

		task.spawn(function()
			badgeCheckers.checkBadgeGrantingAfterRun(
				userId,
				userFinishedRunResponse,
				startSignId,
				endSignId,
				floorSeenCount
			)
		end)

		_annotate("spawn - showbesttimes for: " .. tostring(userId))
		raceCompleteData.showBestTimes(player, raceName, startSignId, endSignId, spd, false, userFinishedRunResponse)
		_annotate("spawn - preparing datatosend to otherPlayer LB.")
		local lbRunUpdate: tt.lbUpdateFromRun = {
			kind = "lbUpdate from run",
			userId = userId,
			userTix = userFinishedRunResponse.userTix,
			top10s = userFinishedRunResponse.userTotalTop10Count,
			races = userFinishedRunResponse.userTotalRaceCount,
			runs = userFinishedRunResponse.userTotalRunCount,
			userCompetitiveWRCount = userFinishedRunResponse.userCompetitiveWRCount,
			userTotalWRCount = userFinishedRunResponse.userTotalWRCount,
			awardCount = userFinishedRunResponse.awardCount,
		}

		for _, otherPlayer in ipairs(PlayerService:GetPlayers()) do
			lbupdater.updateLeaderboardForRun(otherPlayer, lbRunUpdate)
		end
	end)

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
