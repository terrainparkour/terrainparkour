--!strict
local KeyboardService = game:GetService("KeyboardService")

-- runResultCommand on server
-- historically this only happened when you ran a race.
-- but then I made wrprogression which could be triggered by a button (from clieent) but ALSO a command and that had a simple wya.
-- so now this is taking overa s the future serverVersion of how tos end this event to users.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local playerData2 = require(game.ServerScriptService.playerData2)
local rdb = require(game.ServerScriptService.rdb)
local tt = require(game.ReplicatedStorage.types.gametypes)
local remotes = require(game.ReplicatedStorage.util.remotes)
local GenericClientUIEvent = remotes.getRemoteEvent("GenericClientUIEvent")

local module = {}

-- called on the server either by commandParsing where there will be an incomplete userFinishedRunResponse, or by runEnding as a result of the user actually just doing a run.
module.SendRunResults = function(
	player: Player,
	signId1: number,
	signId2: number,
	finishedRunResponse: tt.userFinishedRunResponse?
): boolean
	-- it's not a live request, so hit this endpoint to get the relevant info.
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
