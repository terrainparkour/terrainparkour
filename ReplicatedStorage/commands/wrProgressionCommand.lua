--!strict

-- wrProgressionCommand.lua :: ReplicatedStorage.commands.wrProgressionCommand
-- SERVER-ONLY: Fetch world record progression data and send to client for display.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local remotes = require(game.ReplicatedStorage.util.remotes)
local tt = require(game.ReplicatedStorage.types.gametypes)
local rdb = require(game.ServerScriptService.rdb)

local GenericClientUIEvent = remotes.getRemoteEvent("GenericClientUIEvent")

type Module = {
	GetWRProgression: (player: Player, signId1: number, signId2: number) -> boolean,
}

local module: Module = {} :: Module

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
