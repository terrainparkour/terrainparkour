--!strict

-- userFavoriteRacesCommand.lua :: ReplicatedStorage.commands.userFavoriteRacesCommand
-- SERVER-ONLY: Mark or unmark races as favorites and fetch favorite race lists for users.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local tt = require(game.ReplicatedStorage.types.gametypes)
local rdb = require(game.ServerScriptService.rdb)

type Module = {
	AdjustFavoriteRace: (
		requestingPlayer: Player,
		signId1: number,
		signId2: number,
		favoriteStatus: boolean
	) -> boolean,
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
): boolean
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
	rdb.MakePostRequest(req)
	return true
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
	local theInfo: tt.serverFavoriteRacesResponse = rdb.MakePostRequest(req)

	return theInfo
end

_annotate("end")
return module
