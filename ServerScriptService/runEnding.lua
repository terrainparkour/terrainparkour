--!strict

-- runEnding.server.lua listens for race end events sent from the client and just trusts them.
-- I have total control on the db side anyway

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local PlayersService = game:GetService("Players")
local playerData2 = require(game.ServerScriptService.playerData2)
local tt = require(game.ReplicatedStorage.types.gametypes)
local enums = require(game.ReplicatedStorage.util.enums)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
-- local signInfo = require(game.ReplicatedStorage.signInfo)
local rdb = require(game.ServerScriptService.rdb)
local banning = require(game.ServerScriptService.banning)
local notify = require(game.ReplicatedStorage.notify)
local tpPlacementLogic = require(game.ReplicatedStorage.product.tpPlacementLogic)

local lbUpdaterServer = require(game.ServerScriptService.lbUpdaterServer)
local badgeCheckers = require(game.ServerScriptService.badgeCheckersSecret)
local remotes = require(game.ReplicatedStorage.util.remotes)
-- local notify = require(game.ReplicatedStorage.notify)
local runResultsCommand = require(game.ReplicatedStorage.commands.runResultsCommand)

local PlayerService = game:GetService("Players")

local ServerEventBindableEvent = remotes.getBindableEvent("ServerEventBindableEvent")

local NEW = 1
local BETTER = 2
local WORSE = 3

-- calculate a ton of text strings and send them eventually to a user localscript for display there.
-- TODO 2022 3 19 massive refactor to make this dumb and dependent on python only.
module.showBestTimes = function(
	player: Player,
	startSignId: number,
	endSignId: number,
	userFinishedRunResponse: tt.userFinishedRunResponse
): tt.userFinishedRunResponse
	local racerUserId = player.UserId
	local racerUsername = player.Name
	local startSignName = tpUtil.signId2signName(startSignId)
	local endSignName = tpUtil.signId2signName(endSignId)
	local raceName = string.format("%s-%s", startSignName, endSignName)

	local jsonBestRuns: { tt.jsonBestRun } = userFinishedRunResponse.raceBestRuns or {}
	local legitEntries: { tt.jsonBestRun } = {}
	for _, el in ipairs(jsonBestRuns) do
		if el.place ~= 0 then
			table.insert(legitEntries, el)
		end
	end

	-- the "just run" fake bestrun basically. it didn't actually geet to be a bestRun because it didn't beat that user's past time.
	local thisRun: tt.jsonBestRun = nil
	if userFinishedRunResponse.extraBestRuns then
		for _, br in ipairs(userFinishedRunResponse.extraBestRuns) do
			if br.userId == racerUserId then
				thisRun = br
			end
		end
	end

	-- if we are in extra, then it means that we just ran a race that didn't beat our past best.

	-- the user's past time.
	local pastRun: tt.jsonBestRun = nil
	for _, br in ipairs(jsonBestRuns) do
		if br.userId == racerUserId then
			pastRun = br
		end
	end

	if userFinishedRunResponse.runUserJustDid then
		if false and true then
			local fakePlaces: { tt.DynamicPlace } = {}
			for _, thePriorBestRun: tt.jsonBestRun in ipairs(userFinishedRunResponse.raceBestRuns) do
				local fakePlace: tt.DynamicPlace = {
					place = thePriorBestRun.place,
					timeMs = thePriorBestRun.runMilliseconds,
					userId = thePriorBestRun.userId,
					username = thePriorBestRun.username,
				}
				-- the interleaving method we are about to use was
				-- designed for dynamc running where the carryalong "your current run" stuff
				-- wasn't saved yet (since the user is playing at the time deciding where to go!)
				-- so to use it here, where actually the run is already over, and the user's past is in history,
				-- how can we safely make it work?

				-- ugh we can't just nuke it because they may have had even more prior runs before that.
				if thePriorBestRun.runAgeSeconds < 1 then
					continue
				end
				table.insert(fakePlaces, fakePlace)
			end
			local myPriorPlace: tt.DynamicPlace = {
				place = userFinishedRunResponse.runUserJustDid.place,
				username = userFinishedRunResponse.runUserJustDid.username,
				userId = userFinishedRunResponse.runUserJustDid.userId,
				timeMs = userFinishedRunResponse.runUserJustDid.runMilliseconds,
			}

			local fakeDynamics: tt.DynamicRunFrame = {
				places = fakePlaces,
				myPriorPlace = myPriorPlace,
				myfound = true,
				targetSignId = userFinishedRunResponse.raceInfo.endSignId,
				targetSignName = endSignName,
			}
			local placementAmongRuns = tpPlacementLogic.GetPlacementAmongRuns(
				fakeDynamics,
				racerUserId,
				userFinishedRunResponse.runUserJustDid.runMilliseconds
			)

			userFinishedRunResponse.runUserJustDid.place = placementAmongRuns.newPlace
			local yourTextActual, yourColor = tpPlacementLogic.InterleavedToText(placementAmongRuns)

			userFinishedRunResponse.runUserJustDid.yourText = yourTextActual
			userFinishedRunResponse.runUserJustDid.yourColor = yourColor
		end
	end

	return userFinishedRunResponse
end

module.DoRunEnd = function(player: Player, data: tt.runEndingDataFromClient)
	if banning.getBanLevel(player.UserId) > 0 then
		_annotate(
			string.format("ban level > 0, not saving run for userName=%s, userId: %d", player.Name, player.UserId)
		)
		return
	end

	local startSignName = data.startSignName
	local endSignName = data.endSignName
	local runMilliseconds = data.runMilliseconds
	local floorSeenCount = data.floorSeenCount
	local userId: number = player.UserId
	local startSignId: number = enums.namelower2signId[startSignName:lower()]
	local endSignId: number = enums.namelower2signId[endSignName:lower()]

	local rawUserIdsInServer: { number } = tpUtil.GetUserIdsInServer()
	local userIds: string = table.concat(rawUserIdsInServer, ",")

	--this is where we save the time to db, and then continue to display runresults.
	task.spawn(function()
		local userFinishedRunOptions: tt.userFinishedRunOptions = {
			userId = userId,
			startSignId = startSignId,
			endSignId = endSignId,
			runMilliseconds = runMilliseconds,
			allPlayerUserIds = userIds,
		}
		local request: tt.postRequest = {
			remoteActionName = "userFinishedRun",
			data = userFinishedRunOptions,
		}
		local finishedRunResponse: tt.userFinishedRunResponse = rdb.MakePostRequest(request)

		badgeCheckers.CheckBadgeGrantingAfterRun(userId, finishedRunResponse, startSignId, endSignId, floorSeenCount)

		finishedRunResponse = module.showBestTimes(player, startSignId, endSignId, finishedRunResponse)

		runResultsCommand.SendRunResults(player, startSignId, endSignId, finishedRunResponse)

		for _, anyPlayer in ipairs(PlayerService:GetPlayers()) do
			lbUpdaterServer.SendUpdateToPlayer(anyPlayer, finishedRunResponse.lbUserStats)
		end
	end)

	-- this is for tracking server event scores too. weird we do it here.
	local serverEventUpdateData: tt.serverFinishRunNotifierType = {
		startSignId = startSignId,
		endSignId = endSignId,
		timeMs = runMilliseconds,
		userId = userId,
		username = playerData2.GetUsernameByUserId(userId),
	}
	ServerEventBindableEvent:Fire(serverEventUpdateData)
end

module.Init = function() end

_annotate("end")
return module
