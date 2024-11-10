--!strict

-- World Record Progression Command on the server

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local rdb = require(game.ServerScriptService.rdb)
local tt = require(game.ReplicatedStorage.types.gametypes)

local remotes = require(game.ReplicatedStorage.util.remotes)
local GenericClientUIEvent = remotes.getRemoteEvent("GenericClientUIEvent")

local module = {}

-- Request the world record progression for a given player and sign IDs
module.GetWRProgression = function(player: Player, signId1: number, signId2: number): boolean
	local req = {
		remoteActionName = "wrProgressionRequest",
		data = {
			startSignId = signId1,
			endSignId = signId2,
			userId = player.UserId,
		},
	}

	_annotate("Requesting WR progression")
	local data: tt.WRProgressionEndpointResponse = rdb.MakePostRequest(req)

	if data then
		_annotate("Received WR progression data: ", data)

		-- Fire the result to the client
		GenericClientUIEvent:FireClient(player, {
			command = "wrProgressionRequest",
			data = data,
		})
		return true
	else
		_annotate("Failed to retrieve WR progression data")
		GenericClientUIEvent:FireClient(player, {
			command = "wrProgressionRequest",
			error = "Failed to retrieve WR progression data. Please try again later.",
		})
		return false
	end
end

_annotate("end")
return module