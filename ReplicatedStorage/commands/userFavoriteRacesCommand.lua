--!strict

--

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local rdb = require(game.ServerScriptService.rdb)
local tt = require(game.ReplicatedStorage.types.gametypes)

local module = {}

-- called on the server either by commandParsing,
-- or by the user clicking on something on the client which is relayed through clientCommands!
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

	_annotate("getting wr progression")
	rdb.MakePostRequest(req)
	return true
end

module.GetFavoriteRaces = function(
	requestingPlayer: Player,
	targetUserId: number,
	requestingUserId: number,
	otherUserIds: { number }
)
	local req = {
		remoteActionName = "favoriteRacesRequest",
		data = { targetUserId = targetUserId, otherUserIds = otherUserIds, requestingUserId = requestingUserId },
	}
	local theInfo: tt.serverFavoriteRacesResponse = rdb.MakePostRequest(req)

	return theInfo
end

_annotate("end")
return module
