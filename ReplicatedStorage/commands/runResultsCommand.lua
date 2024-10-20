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

-- called on the server either by commandParsing where there will be an incomplete dcRunResponse, or by runEnding as a result of the user actually just doing a run.
module.SendRunResults = function(
	player: Player,
	signId1: number,
	signId2: number,
	dcRunResponse: tt.dcRunResponse?
): boolean
	-- it's not a live request, so look up the basics to prepare the DC.
	if dcRunResponse == nil then
		local lbUserStats = playerData2.GetStatsByUserId(player.UserId, "user-command originated SendRunResults")
		local request: tt.postRequest = {
			remoteActionName = "getBestTimesByRace",
			data = {
				startSignId = signId1,
				endSignId = signId2,
				userIdsCsv = "",
			},
		}

		local runEntries: { tt.JsonRun } = rdb.MakePostRequest(request)
		local convertedRunEntries: { tt.runEntry } = {}
		for _, runEntry in pairs(runEntries) do
			local theNewGuy: tt.runEntry = {
				kind = "race",
				userId = runEntry.userId,
				runMilliseconds = runEntry.runMilliseconds,
				username = runEntry.username,
				place = runEntry.place,
				virtualPlace = 0,
				runAgeSeconds = runEntry.runAgeSeconds,
			}
			table.insert(convertedRunEntries, theNewGuy)
		end

		local startSignName = tpUtil.signId2signName(signId1)
		local endSignName = tpUtil.signId2signName(signId2)
		local raceName = string.format("%s-%s", startSignName, endSignName)
		local newDcRunResponse: tt.dcRunResponse = {
			runEntries = convertedRunEntries,
			actionResults = {},
			createdMarathon = false,
			createdRace = true,
			distance = 666.6,
			endSignId = signId2,
			kind = "race",
			lbUserStats = lbUserStats,
			mode = 0,
			newFind = false,
			raceIsCompetitive = false,
			raceName = raceName,
			raceTotalHistoryText = "",
			runMilliseconds = 123456,
			speed = 100,
			startSignId = signId1,
			thisRunImprovedPlace = false,
			thisRunPlace = 0,
			totalRacersOfThisRaceCount = 10,
			totalRunsOfThisRaceCount = 50,
			userId = player.UserId,
			username = player.Name,
			yourText = "Looking at past race top10",
			userRaceRunCount = 3,
		}
		dcRunResponse = newDcRunResponse
	end
	local data = {
		startSignId = signId1,
		endSignId = signId2,
		userId = player.UserId,
		dcRunResponse = dcRunResponse,
	}

	GenericClientUIEvent:FireClient(player, {
		command = "runResultsDelivery",
		data = data,
	})
	return true
end

_annotate("end")
return module
