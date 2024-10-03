--!strict

-- runEnding.server.lua listens for race end events sent from the client and just trusts them.
-- I have total control on the db side anyway

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local playerData2 = require(game.ServerScriptService.playerData2)
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
local notify = require(game.ReplicatedStorage.notify)

local PlayerService = game:GetService("Players")

local ClientToServerRemoteFunction = remotes.getRemoteFunction("ClientToServerRemoteFunction")
local ServerEventBindableEvent = remotes.getBindableEvent("ServerEventBindableEvent")

--in this new(ish) trust the client code, just call this directly with the actual details.
--note: it would be nice to retain server-side timing to detect hackers. nearly every one would give themselves away.

local function userFinishedRun(data: tt.userFinishedRunOptions): tt.dcRunResponse
	local request: tt.postRequest = {
		remoteActionName = "userFinishedRun",
		data = data,
	}
	local res: tt.dcRunResponse = rdb.MakePostRequest(request)
	return res
end

local function receiveClientMessageAboutRunEnding(player: Player, data: tt.runEndingData)
	local startSignName = data.startSignName
	local endSignName = data.endSignName
	local runMilliseconds = data.runMilliseconds
	local useThisRunMilliseconds = data.useThisRunMilliseconds
	local floorSeenCount = data.floorSeenCount
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
			runMilliseconds = useThisRunMilliseconds,
			allPlayerUserIds = userIds,
		}
		local dcRunResponse: tt.dcRunResponse = userFinishedRun(userFinishedRunOptions)

		task.spawn(function()
			badgeCheckers.CheckBadgeGrantingAfterRun(userId, dcRunResponse, startSignId, endSignId, floorSeenCount)
		end)

		_annotate("showbesttimes for: " .. tostring(userId))
		raceCompleteData.showBestTimes(player, raceName, startSignId, endSignId, speed, dcRunResponse)

		_annotate("preparing data to send to update everyone's LBs")
		for _, anyPlayer in ipairs(PlayerService:GetPlayers()) do
			lbUpdaterServer.SendUpdateToPlayer(anyPlayer, dcRunResponse.lbUserStats)
		end
	end)

	-- this is for tracking server event scores too. weird we do it here.
	local data: tt.serverFinishRunNotifierType = {
		startSignId = startSignId,
		endSignId = endSignId,
		timeMs = useThisRunMilliseconds,
		userId = userId,
		username = playerData2.GetUsernameByUserId(userId),
	}
	ServerEventBindableEvent:Fire(data)
end

module.Init = function()
	ClientToServerRemoteFunction.OnServerInvoke = function(player: Player, event: tt.clientToServerRemoteEvent)
		_annotate("server received event", event.kind)
		if event.eventKind == "runEnding" then
			_annotate("server received runEnding event", event.data)
			receiveClientMessageAboutRunEnding(player, event.data)
		end
	end
end

_annotate("end")
return module
