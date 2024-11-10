--!strict
local KeyboardService = game:GetService("KeyboardService")

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local playerData2 = require(game.ServerScriptService.playerData2)
local rdb = require(game.ServerScriptService.rdb)
local tt = require(game.ReplicatedStorage.types.gametypes)
local remotes = require(game.ReplicatedStorage.util.remotes)
local GenericClientUIEvent = remotes.getRemoteEvent("GenericClientUIEvent")

local RunResults = {}

-- SendRunResults function that encapsulates the logic you provided
function RunResults.SendRunResults(
	player: Player,
	signId1: number,
	signId2: number,
	finishedRunResponse: tt.userFinishedRunResponse?
): boolean
	-- If no finishedRunResponse is provided, make a post request to fetch data.
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

	-- Prepare data to send to client
	local data = {
		startSignId = signId1,
		endSignId = signId2,
		userId = player.UserId,
		userFinishedRunResponse = finishedRunResponse,
	}

	-- Fire client event with the results
	GenericClientUIEvent:FireClient(player, {
		command = "runResultsDelivery",
		data = data,
	})
	return true
end

-- Execute command handler (to be called from CommandService)
function RunResults.Execute(player, signId1: number, signId2: number)
	local success = RunResults.SendRunResults(player, signId1, signId2)

	if success then
		return "Run results have been successfully sent!"
	else
		return "Failed to send run results."
	end
end

_annotate("end")
return RunResults