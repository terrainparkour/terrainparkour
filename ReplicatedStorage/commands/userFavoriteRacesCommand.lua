--!strict

-- userFavoriteRacesCommand.lua :: ReplicatedStorage.commands.userFavoriteRacesCommand
-- SERVER-ONLY: Mark or unmark races as favorites and fetch favorite race lists for users.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local tt = require(game.ReplicatedStorage.types.gametypes)
local rdb = require(game.ServerScriptService.rdb)

export type AdjustFavoriteRaceResult = {
	success: boolean,
	raceNotFound: boolean?,
	error: string?,
}

type Module = {
	AdjustFavoriteRace: (
		requestingPlayer: Player,
		signId1: number,
		signId2: number,
		favoriteStatus: boolean
	) -> AdjustFavoriteRaceResult,
	GetFavoriteRaces: (
		requestingPlayer: Player,
		targetUserId: number,
		requestingUserId: number,
		otherUserIds: { number }
	) -> tt.serverFavoriteRacesResponse,
}

local module: Module = {} :: Module

module.AdjustFavoriteRace = function(
	requestingPlayer: Player,
	signId1: number,
	signId2: number,
	favoriteStatus: boolean
): AdjustFavoriteRaceResult
	local req = {
		remoteActionName = "adjustFavoriteRace",
		data = {
			startSignId = signId1,
			endSignId = signId2,
			userId = requestingPlayer.UserId,
			favoriteStatus = favoriteStatus,
		},
	}

	_annotate("adjusting favorite race")
	local rawResponse: any = rdb.MakePostRequest(req)

	if rawResponse.raceNotFound then
		return { success = false, raceNotFound = true }
	end

	if rawResponse.error then
		return { success = false, error = rawResponse.error }
	end

	return { success = true }
end

module.GetFavoriteRaces = function(
	requestingPlayer: Player,
	targetUserId: number,
	requestingUserId: number,
	otherUserIds: { number }
): tt.serverFavoriteRacesResponse
	local req = {
		remoteActionName = "favoriteRacesRequest",
		data = { targetUserId = targetUserId, otherUserIds = otherUserIds, requestingUserId = requestingUserId },
	}
	local rawResponse: any = rdb.MakePostRequest(req)

	if rawResponse and rawResponse.error then
		return {
			success = false,
			error = rawResponse.error,
			message = rawResponse.message,
			targetUserId = targetUserId,
			requestingUserId = requestingUserId,
			otherUserIds = otherUserIds,
		}
	end

	-- Backend security failures return { error=true, message="failure" } (bool, not string).
	if rawResponse and typeof(rawResponse.error) == "boolean" then
		return {
			success = false,
			error = "backend_security_failure",
			message = rawResponse.message,
			targetUserId = targetUserId,
			requestingUserId = requestingUserId,
			otherUserIds = otherUserIds,
		}
	end

	local theInfo: tt.serverFavoriteRacesResponse = rawResponse
	theInfo.success = true
	return theInfo
end

_annotate("end")
return module
