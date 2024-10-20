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

local function setYourText(val: string, existingYourText: string, marker: string)
	if existingYourText ~= "" and existingYourText ~= nil then
		warn("resetting yt from '" .. existingYourText .. "' to '" .. val .. "'" .. " \tMarker: " .. marker)
	end
	return val
end

-- calculate a ton of text strings and send them eventually to a user localscript for display there.
-- TODO 2022 3 19 massive refactor to make this dumb and dependent on python only.
module.showBestTimes = function(
	player: Player,
	startSignId: number,
	endSignId: number,
	dcRunResponse: tt.dcRunResponse
): tt.dcRunResponse
	local racerUserId = player.UserId
	local racerUsername = player.Name
	local startSignName = tpUtil.signId2signName(startSignId)
	local endSignName = tpUtil.signId2signName(endSignId)
	local raceName = string.format("%s-%s", startSignName, endSignName)

	local runEntries: { tt.runEntry } = dcRunResponse.runEntries or {}
	local legitEntries: { tt.runEntry } = {}
	for _, el in ipairs(runEntries) do
		if el.place ~= 0 then
			table.insert(legitEntries, el)
		end
	end

	local thisRun: tt.runEntry
	local pastRun: tt.runEntry

	local otherRunnerCount = 0
	--figure out their past place and the current run's place too.

	for _, thing: tt.runEntry in ipairs(runEntries) do
		if racerUserId ~= thing.userId then
			otherRunnerCount += 1
		end
		if racerUserId == thing.userId then
			if thing.kind == "past run" then
				pastRun = thing
			end
			if thing.kind == "this run" then
				thisRun = thing
			end
		end
	end

	--now we have set the user's yourPlace representing thei

	local placeText = tpUtil.getPlaceText(thisRun.place)

	local yourText = "" --summary of the race, time, speed, results from racer's POV
	local otherText = "" --same from other's POV
	local otherKind = ""
	local knockoutText = "" --description of knockout "X was knocked out of top 10"

	--TODO fix
	-- if otherRunnerCount == 0 then
	-- 	grantBadge.GrantBadge(racerUserId, badgeEnums.badges.NewRace)
	-- end

	--- if this is a contextual display (i.e. we show a run which just happened to the user.)

	if dcRunResponse.totalRunsOfThisRaceCount == 1 then
		yourText = setYourText("Found a new race", yourText, "a")
		otherText = string.format("%s ran the race %s for the first time", racerUsername, raceName)
		otherKind = "first time WR"
	else
		if dcRunResponse.mode == NEW then
			if thisRun.place == 1 then --you got WR
				yourText = setYourText("First time WR!", yourText, "b")
				otherText = racerUsername .. " got a WR on his or her first run of " .. raceName
				otherKind = "first time WR"
			elseif thisRun.place > 0 and thisRun.place < 11 then
				if thisRun.place == 1 then
					yourText = setYourText("You got a World Record!", yourText, "c")
					otherText = string.format("%s got a WR in %s!", racerUsername, raceName)
				else
					yourText = setYourText("You finished " .. placeText .. "! Very nice!", yourText, "d")
					otherText = string.format("%s got %s in %s!", racerUsername, placeText, raceName)
				end

				otherKind = "got place"
			end
			if thisRun.place > 10 or thisRun.place == 0 then
				local yt = "You didn't finish in the top 10. You missed tenth place by "
					.. tpUtil.fmt(thisRun.runMilliseconds - legitEntries[10].runMilliseconds)
					.. "! Don't give up!"
				yourText = setYourText(yt, yourText, "e")
			end
		end
	end

	if dcRunResponse.mode == BETTER then
		local improvementMilliseconds = pastRun.runMilliseconds - thisRun.runMilliseconds
		if thisRun.place == 1 then
			if pastRun.virtualPlace == 1 then --had WR before
				yourText = setYourText(
					"Better world record! Your time was " .. tpUtil.fmt(improvementMilliseconds) .. " better!",
					yourText,
					"f"
				)
				otherText = racerUsername
					.. " improved their world record in the race from "
					.. raceName
					.. " by "
					.. tpUtil.fmt(improvementMilliseconds)
				otherKind = "improved WR"
			else --didn't have WR before but had run beforex
				local yt = "World record! Amazing! Your time was "
					.. tpUtil.fmt(improvementMilliseconds)
					.. " faster, improving your prior "
					.. tpUtil.getCardinalEmoji(pastRun.virtualPlace - 1)
					.. ", and you took the WR from "
					.. legitEntries[2].username
					.. "!"
				yourText = setYourText(yt, yourText, "g")

				otherText = racerUsername
					.. " took the world record away from "
					.. legitEntries[2].username
					.. " in the race from "
					.. raceName
					.. "! (by "
					.. tpUtil.fmt(improvementMilliseconds)
					.. ")"
				otherKind = "took WR"
			end
		end
		if thisRun.place < 11 and thisRun.place > 1 and pastRun ~= nil then
			--finished in a place for the first time
			if thisRun.place == pastRun.virtualPlace then --same place, slight improvement
				local yt = "You got another "
					.. tpUtil.getCardinalEmoji(thisRun.place)
					.. ", and improved your time by "
					.. tpUtil.fmt(pastRun.runMilliseconds - thisRun.runMilliseconds)
				yourText = setYourText(yt, yourText, "h")

				otherText = racerUsername
					.. " improved their "
					.. tpUtil.getCardinalEmoji(thisRun.place)
					.. " time in the race from "
					.. raceName
					.. " by "
					.. tpUtil.fmt(pastRun.runMilliseconds - thisRun.runMilliseconds)
				otherKind = "improved time"
			end
			if thisRun.place < pastRun.virtualPlace then --beat past place
				local yt = "You finished in "
					.. tpUtil.getCardinalEmoji(thisRun.place)
					.. ", better than your previous best of "
					.. tpUtil.getCardinalEmoji(pastRun.virtualPlace)
					.. "! Your time improved by "
					.. tpUtil.fmt(pastRun.runMilliseconds - thisRun.runMilliseconds)
					.. "!"
				yourText = setYourText(yt, yourText, "i")
				otherText = racerUsername
					.. " got "
					.. tpUtil.getCardinalEmoji(thisRun.place)
					.. " place in the race from "
					.. raceName
					.. "!  (previously "
					.. tpUtil.getCardinalEmoji(pastRun.virtualPlace)
					.. ")"
				otherKind = "improved place"
			end
		end
		if thisRun.place > 10 or thisRun.place == 0 then
			local yt = "You didn't finish in the top 10. You missed tenth place by "
				.. tpUtil.fmt(thisRun.runMilliseconds - legitEntries[10].runMilliseconds)
				.. "! Don't give up!"
			yourText = setYourText(yt, yourText, "j")
		end
	end

	if dcRunResponse.mode == WORSE then
		if (thisRun.place < 11 and thisRun.place > 1) or (thisRun.virtualPlace > 0) then
			if thisRun.virtualPlace == nil then
				warn("weirdly nil virtualrun.")
			else
				-- same vp == place but time worse.
				if thisRun.virtualPlace == pastRun.place and thisRun.place < 11 and thisRun.place > 1 then
					local yt = "You got another "
						.. tpUtil.getCardinalEmoji(thisRun.virtualPlace)
						.. ", with a worse time by "
						.. tpUtil.fmt(thisRun.runMilliseconds - pastRun.runMilliseconds)
					yourText = setYourText(yt, yourText, "k")
					-- vp is worse than p, still top 10
				elseif thisRun.virtualPlace < 11 then --you were 2-10th
					local yt = "You finished in "
						.. tpUtil.getCardinalEmoji(thisRun.virtualPlace)
						.. " which didn't beat your previous best of "
						.. tpUtil.getCardinalEmoji(pastRun.place)
						.. ". Your time was worse by "
						.. tpUtil.fmt(thisRun.runMilliseconds - pastRun.runMilliseconds)
						.. "."
					yourText = setYourText(yt, yourText, "l")
				elseif thisRun.virtualPlace > 10 or thisRun.virtualPlace == 0 then
					local yt = "You didn't finish in the top 10. You missed tenth place by "
						.. tpUtil.fmt(thisRun.runMilliseconds - legitEntries[10].runMilliseconds)
						.. "and you missed beating your best time by "
						.. tpUtil.fmt(thisRun.runMilliseconds - pastRun.runMilliseconds)
						.. "! Don't give up!"
					yourText = setYourText(yt, yourText, "m")
				end
			end
		end
	end

	--todo also think about specific text for the recipient. i.e. "YOU were knocked out by X".
	if #legitEntries >= 11 then
		knockoutText = string.format("%s was knocked out of the top 10 on %s!", legitEntries[11].username, raceName)
	end

	if otherText ~= "" then
		for _, op in ipairs(PlayersService:GetPlayers()) do
			if player.UserId == op.UserId then
				continue
			end

			--TODO inline import this, not really valid at top due to conflicts.

			local useWarpToSignId = (
				startSignId
				and playerData2.HasUserFoundSign(op.UserId, startSignId)
				and not enums.SignIdIsExcludedFromStart[startSignId]
				and startSignId
			) or 0

			local useHighlightTargetSignId = endSignId
			if enums.SignIdIsExcludedFromStart[endSignId] or not playerData2.HasUserFoundSign(op.UserId, endSignId) then
				useHighlightTargetSignId = nil
			end
			if knockoutText ~= "" then
				notify.notifyPlayerAboutActionResult(op, {
					userId = player.UserId,
					text = knockoutText,
					kind = "knockout notification",
					warpToSignId = useWarpToSignId,
				})
			end

			--notify otherplayer OP about user's race to startSignId
			notify.notifyPlayerAboutActionResult(op, {
				userId = player.UserId,
				text = otherText,
				kind = otherKind,
				warpToSignId = useWarpToSignId,
				highlightSignId = useHighlightTargetSignId,
			})
		end
	end

	dcRunResponse.kind = "race results"
	dcRunResponse.startSignId = startSignId
	dcRunResponse.endSignId = endSignId
	dcRunResponse.raceName = raceName
	dcRunResponse.yourText = yourText
	return dcRunResponse
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
		local dcRunResponse: tt.dcRunResponse = rdb.MakePostRequest(request)

		task.spawn(function()
			badgeCheckers.CheckBadgeGrantingAfterRun(userId, dcRunResponse, startSignId, endSignId, floorSeenCount)
		end)

		dcRunResponse = module.showBestTimes(player, startSignId, endSignId, dcRunResponse)

		runResultsCommand.SendRunResults(player, startSignId, endSignId, dcRunResponse)

		for _, anyPlayer in ipairs(PlayerService:GetPlayers()) do
			lbUpdaterServer.SendUpdateToPlayer(anyPlayer, dcRunResponse.lbUserStats)
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
