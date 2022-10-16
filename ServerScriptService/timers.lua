--!strict

--timers is about: starting and stopping races, AND also generating very complex text to describe the results
--to the runner and to others.
--eval 9.25.22

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

--the gap before client allows retouch when you finish a run.
local NO_RETOUCH_GAP = 0.8
-- NO_RETOUCH_GAP = 0.0

local module = {}

--map of player:runningRaceStartSignId?
--this is super legacy but does work. single server-side in-memory object tracking currently running races.
--2022.04 refactoring
-- map of the player's currently running race and start time. canonical but also let client know when it changes, so UI there can update.
-- local playerStatuses: { [number]: { st: number, signId: number } } = {}

local PlayerService = game:GetService("Players")

--for sending messages to the client.
local clientControlledRunEndEvent = remotes.getRemoteEvent("ClientControlledRunEndEvent")

-- tell marathon client that the user really hit a sign.
-- local hitSignEvent = remotes.getRemoteEvent("HitSignEvent")

--userId:tick for absolute protection from doing any notifyHit within 1s of warping.
local lastWarpTimes: { [number]: number } = {}

local endingDebouncers: { [number]: boolean } = {}
local doAnnotation = false
local annotationStart = tick()
local function annotate(s: string)
	if doAnnotation then
		print("server.timers. " .. string.format("%.3f", tick() - annotationStart) .. " : " .. s)
	end
end

-- cancelRunRemoteFunction.OnServerInvoke = function(player: Player)
-- 	return module.cancelRun(player, "cancelRunEvent")
-- end

--in new trust the client code, just call this directly with the actual details.
--note: it would be nice to retain server-side timing to detect hackers. nearly every one would give themselves away.
local function serverEndRunPromptedByClient(
	player: Player,
	startSignName: string,
	endSignName: string,
	newFind: boolean,
	runMilliseconds: number,
	floorSeenCount: number
)
	if banning.getBanLevel(player.UserId) > 0 then
		return
	end

	local userId = player.UserId
	local startSignId = enums.namelower2signId[startSignName:lower()]
	local endSignId = enums.namelower2signId[endSignName:lower()]
	local startSignPosition = signInfo.getSignPosition(startSignId)
	local endSignPosition = signInfo.getSignPosition(endSignId)
	local distance = (startSignPosition - endSignPosition).magnitude
	local speed = distance / runMilliseconds

	local raceName = startSignName .. " to " .. endSignName
	local spd = math.ceil(speed * 100) / 100

	local userIds = tpUtil.GetUserIdsInServer()

	userIds = table.concat(userIds, ",")

	--this is where we save the time to db, and then continue to display runresults.
	spawn(function()
		local userFinishedRunOptions: tt.userFinishedRunOptions = {
			userId = userId,
			startId = startSignId,
			endId = endSignId,
			runMilliseconds = runMilliseconds,
			otherPlayerUserIds = userIds,
			remoteActionName = "userFinishedRun",
		}
		local userFinishedRunResponse: tt.pyUserFinishedRunResponse = rdb.userFinishedRun(userFinishedRunOptions)
		-- annotate("spawn - before check badge: " .. tostring(userId))

		spawn(function()
			badgeCheckers.checkBadgeGrantingAfterRun(userId, userFinishedRunResponse, startSignId, endSignId, floorSeenCount)
		end)

		-- annotate("spawn - showbesttimes for: " .. tostring(userId))
		raceCompleteData.showBestTimes(player, raceName, startSignId, endSignId, spd, newFind, userFinishedRunResponse)
		-- annotate("spawn - preparing datatosend to otherPlayer LB.")
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
	local serverEventBindableEvent = remotes.getBindableEvent("ServerEventBindableEvent")
	local data: tt.serverFinishRunNotifierType = {
		startSignId = startSignId,
		endSignId = endSignId,
		timeMs = runMilliseconds,
		userId = userId,
		username = rdb.getUsernameByUserId(userId),
	}
	serverEventBindableEvent:Fire(data)
end

clientControlledRunEndEvent.OnServerEvent:Connect(
	function(player: Player, startSignName: string, endSignName: string, clientSideTimeMs: number, floorSeenCount: number): any
		serverEndRunPromptedByClient(player, startSignName, endSignName, false, clientSideTimeMs, floorSeenCount)
	end
)

return module
