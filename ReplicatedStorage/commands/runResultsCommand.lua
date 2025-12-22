--!strict

-- runResultsCommand.lua :: ReplicatedStorage.commands.runResultsCommand
-- SERVER-ONLY: Construct and send discipline result notifications to clients.
-- Handles both race results and marathon results via the unified disciplineResultsNotification type.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local remotes = require(game.ReplicatedStorage.util.remotes)
local tpUtil: typeof(require(game.ReplicatedStorage.util.tpUtil)) = require(game.ReplicatedStorage.util.tpUtil)
local tt = require(game.ReplicatedStorage.types.gametypes)
local rdb = require(game.ServerScriptService.rdb)

local ServerToClientEvent = remotes.getRemoteEvent("ServerToClientEvent")

export type SendRunResultsResult = {
	success: boolean,
	raceNotFound: boolean?,
}

type Module = {
	SendRunResults: (
		player: Player,
		signId1: number,
		signId2: number,
		finishedRunResponse: tt.userFinishedRunResponse?
	) -> SendRunResultsResult,
	SendDisciplineResults: (
		player: Player,
		kind: "raceResults" | "marathonResults",
		response: tt.userFinishedRunResponse
	) -> (),
}

local module: Module = {} :: Module

-- Shared helper to construct and send discipline result notifications.
-- Used by both race completion (runEnding) and marathon completion (marathon.lua).
local function sendDisciplineNotification(player: Player, kind: "raceResults" | "marathonResults", response: tt.userFinishedRunResponse)
	local notification: tt.disciplineResultsNotification = {
		kind = kind,
		userId = response.userId,
		username = response.username,
		raceInfo = response.raceInfo,
		runUserJustDid = response.runUserJustDid,
		raceBestRuns = response.raceBestRuns,
		extraBestRuns = response.extraBestRuns,
		userRaceStats = response.userRaceStats,
		lbUserStats = response.lbUserStats,
		actionResults = response.actionResults,
		raceHistoryData = response.raceHistoryData,
		isMarathon = response.isMarathon,
		isFavoriteRace = response.isFavoriteRace,
	}
	ServerToClientEvent:FireClient(player, notification)
end

-- Public API for marathon.lua and other callers that have a response ready
module.SendDisciplineResults = function(player: Player, kind: "raceResults" | "marathonResults", response: tt.userFinishedRunResponse)
	sendDisciplineNotification(player, kind, response)
end

module.SendRunResults = function(
	player: Player,
	signId1: number,
	signId2: number,
	finishedRunResponse: tt.userFinishedRunResponse?
): SendRunResultsResult
	-- If response was provided (e.g., from runEnding after completing a run), use it directly
	if finishedRunResponse then
		sendDisciplineNotification(player, "raceResults", finishedRunResponse)
		return { success = true }
	end

	-- Otherwise, fetch from backend (e.g., /res command or reverse race button)
	local rawUserIdsInServer: { number } = tpUtil.GetUserIdsInServer()
	local allPlayerUserIds: string = table.concat(rawUserIdsInServer, ",")
	local userFinishedRunOptions: tt.raceDataQuery = {
		userId = player.UserId,
		startSignId = signId1,
		endSignId = signId2,
		allPlayerUserIds = allPlayerUserIds,
	}
	local request: tt.postRequest = {
		remoteActionName = "userFinishedRunGetDataOnly",
		data = userFinishedRunOptions,
	}
	local rawResponse: any = rdb.MakePostRequest(request)

	if not rawResponse then
		annotater.Error("SendRunResults: nil response from backend", {
			userId = player.UserId,
			signId1 = signId1,
			signId2 = signId2,
		})
		return { success = false }
	end

	-- Handle "Race not found" - no one has run this race yet
	if rawResponse.error == "Race not found" then
		return { success = false, raceNotFound = true }
	end

	if rawResponse.error then
		annotater.Error(string.format("SendRunResults: backend returned error=%s", tostring(rawResponse.error)), {
			userId = player.UserId,
			signId1 = signId1,
			signId2 = signId2,
			error = rawResponse.error,
			message = rawResponse.message,
		})
		return { success = false }
	end

	local response: tt.userFinishedRunResponse = rawResponse :: tt.userFinishedRunResponse
	sendDisciplineNotification(player, "raceResults", response)
	return { success = true }
end

_annotate("end")
return module
