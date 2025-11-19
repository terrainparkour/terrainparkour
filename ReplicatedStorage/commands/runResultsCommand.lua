--!strict

-- runResultsCommand.lua :: ReplicatedStorage.commands.runResultsCommand
-- SERVER-ONLY: Fetch run results for a race and deliver to client for display.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local remotes = require(game.ReplicatedStorage.util.remotes)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local tt = require(game.ReplicatedStorage.types.gametypes)
local rdb = require(game.ServerScriptService.rdb)

local GenericClientUIEvent = remotes.getRemoteEvent("GenericClientUIEvent")

type Module = {
	SendRunResults: (
		player: Player,
		signId1: number,
		signId2: number,
		finishedRunResponse: tt.userFinishedRunResponse?
	) -> boolean,
}

local module: Module = {} :: Module

module.SendRunResults = function(
	player: Player,
	signId1: number,
	signId2: number,
	finishedRunResponse: tt.userFinishedRunResponse?
): boolean
	if finishedRunResponse == nil then
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
		finishedRunResponse = rdb.MakePostRequest(request)
	end

	local data = {
		startSignId = signId1,
		endSignId = signId2,
		userId = player.UserId,
		userFinishedRunResponse = finishedRunResponse,
	}

	GenericClientUIEvent:FireClient(player, {
		command = "runResultsDelivery",
		data = data,
	})
	return true
end

_annotate("end")
return module
