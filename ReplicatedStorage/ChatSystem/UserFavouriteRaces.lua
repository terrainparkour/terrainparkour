--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local rdb = require(game.ServerScriptService.rdb)
local tt = require(game.ReplicatedStorage.types.gametypes)

local UserFavouriteRacesCommand = {}

-- Adjust the favorite race status for a specific sign and player.
function UserFavouriteRacesCommand.AdjustFavoriteRace(
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

	_annotate("Adjusting favorite race status")
	local success = rdb.MakePostRequest(req)
	return success -- Assuming the post request returns a success status
end

-- Retrieve favorite races for a specific user.
function UserFavouriteRacesCommand.GetFavoriteRaces(
	requestingPlayer: Player,
	targetUserId: number,
	requestingUserId: number,
	otherUserIds: { number }
)
	local req = {
		remoteActionName = "favoriteRacesRequest",
		data = { targetUserId = targetUserId, otherUserIds = otherUserIds, requestingUserId = requestingUserId },
	}

	_annotate("Fetching favorite races information")
	local theInfo: tt.serverFavoriteRacesResponse = rdb.MakePostRequest(req)

	if theInfo then
		return theInfo
	else
		return {} -- Return an empty table if no information is received
	end
end

-- Function to execute the AdjustFavoriteRace command (to be called from CommandService)
function UserFavouriteRacesCommand.ExecuteAdjustFavoriteRace(
	player: Player,
	signId1: number,
	signId2: number,
	favoriteStatus: boolean
)
	local success = UserFavouriteRacesCommand.AdjustFavoriteRace(player, signId1, signId2, favoriteStatus)
	if success then
		return "Favorite race status adjusted successfully."
	else
		return "Failed to adjust favorite race status."
	end
end

-- Function to execute the GetFavoriteRaces command (to be called from CommandService)
function UserFavouriteRacesCommand.ExecuteGetFavoriteRaces(
	player: Player,
	targetUserId: number,
	requestingUserId: number,
	otherUserIds: { number }
)
	local favoriteRaces = UserFavouriteRacesCommand.GetFavoriteRaces(player, targetUserId, requestingUserId, otherUserIds)
	return favoriteRaces
end

_annotate("end")
return UserFavouriteRacesCommand