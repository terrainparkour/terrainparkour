--!strict

-- wrProgressionCommand on server

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local rdb = require(game.ServerScriptService.rdb)
local tt = require(game.ReplicatedStorage.types.gametypes)

local remotes = require(game.ReplicatedStorage.util.remotes)
local GenericClientUIEvent = remotes.getRemoteEvent("GenericClientUIEvent")

local module = {}

-- called on the server either by commandParsing, or by the user clicking on something on the client which is relayed through clientCommands.
module.GetWRProgression = function(player: Player, signId1: number, signId2: number): boolean
	local req = {
		remoteActionName = "wrProgressionRequest",
		data = {
			startSignId = signId1,
			endSignId = signId2,
			userId = player.UserId,
		},
	}

	_annotate("getting wr progression")
	local data = rdb.MakePostRequest(req) :: tt.WRProgressionEndpointResponse
	_annotate("got wr progression data; ", data)

	GenericClientUIEvent:FireClient(player, {
		command = "wrProgressionRequest",
		data = data,
	})
	return true
end

_annotate("end")
return module
