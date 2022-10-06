--!strict

--eval 9.25.22
--calculating raceComplete GUI stuff like text descriptions of your relative placed, etc.
--split out 2021
--2022 TODO is this all used? or is this in python now.  likely here.

local tt = require(game.ReplicatedStorage.types.gametypes)
local PlayersService = game:GetService("Players")
local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local notify = require(game.ReplicatedStorage.notify)
local enums = require(game.ReplicatedStorage.util.enums)

local grantBadge = require(game.ServerScriptService.grantBadge)

local module = {}

local doAnnotation = false

local function annotate(s: string)
	if doAnnotation then
		print("server: " .. string.format("%.0f", tick()) .. " : " .. s)
	end
end

local NEW = 1
local BETTER = 2
local WORSE = 3

-- calculate a ton of text strings and send them eventually to a user localscript for display there.
-- TODO 2022 3 19 massive refactor to make this dumb and dependent on python only.
module.showBestTimes = function(
	player: Player,
	raceName: string,
	startSignId: number,
	endSignId: number,
	spd: number,
	newFind: boolean,
	pyUserFinishedRunResponse: tt.pyUserFinishedRunResponse
)
	local formattedRunMilliseconds = tpUtil.fmt(pyUserFinishedRunResponse.thisRunMilliseconds)
	--res is the new object with stats in it
	--pull out metas
	local racerUserId = player.UserId
	local racerUsername = player.Name

	local runEntries: { tt.runEntry } = pyUserFinishedRunResponse.runEntries
	local legitEntries: { tt.runEntry } = {}
	for _, el in ipairs(runEntries) do
		if el.place ~= 0 then
			table.insert(legitEntries, el)
		end
	end

	local startSign: Part = game.Workspace:FindFirstChild("Signs"):FindFirstChild(enums.signId2name[startSignId])
	local endSign: Part = game.Workspace:FindFirstChild("Signs"):FindFirstChild(enums.signId2name[endSignId])
	local distance = tpUtil.getDist(startSign.Position, endSign.Position)

	local thisRun: tt.runEntry
	local pastRun: tt.runEntry

	local otherRunnerCount = 0
	--figure out their past place and the current run's place too.

	for ii, thing: tt.runEntry in ipairs(runEntries) do
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
	local virtualPlaceText = tpUtil.getPlaceText(thisRun.virtualPlace)
	local pastPlaceText = ""
	if pastRun then
		pastPlaceText = tpUtil.getPlaceText(pastRun.place)
	end

	local playerText = raceName .. ": " .. formattedRunMilliseconds
	local yourText = "" --summary of the race, time, speed, results from racer's POV
	local otherText = "" --same from other's POV
	local otherKind = ""
	local knockoutText = "" --description of knockout "X was knocked out of top 10"
	local lossText = "" -- "You missed top10 by X seconds"

	if otherRunnerCount == 0 then
		grantBadge.GrantBadge(racerUserId, badgeEnums.badges.NewRace)
	end

	if pyUserFinishedRunResponse.totalRunsOfThisRaceCount == 1 then
		yourText = "Ran a race for the first time!"
		otherText = racerUsername .. " ran a race for the first time: " .. raceName
		otherKind = "first time WR"
	else
		if pyUserFinishedRunResponse.mode == NEW then
			if thisRun.place == 1 then --you got WR
				yourText = "First time WR!"
				otherText = racerUsername .. " got a first time WR on " .. raceName
				otherKind = "first time WR"
			end
			if thisRun.place > 0 and thisRun.place < 11 then
				yourText = "You finished " .. placeText .. "! Very nice!"
				otherText = racerUsername .. " got " .. placeText .. " in the race " .. raceName .. "!"
				otherKind = "got place"
			end
			if thisRun.place > 10 or thisRun.place == 0 then
				lossText = "You didn't finish in the top 10. You missed tenth place by "
					.. tpUtil.fmt(thisRun.runMilliseconds - legitEntries[10].runMilliseconds)
					.. "! Don't give up!"
			end
		end
	end

	if pyUserFinishedRunResponse.mode == BETTER then
		local improvementMilliseconds = pastRun.runMilliseconds - thisRun.runMilliseconds
		if thisRun.place == 1 then
			if pastRun.virtualPlace == 1 then --had WR before
				yourText = "Better world record! Your time was " .. tpUtil.fmt(improvementMilliseconds) .. " better!"
				otherText = racerUsername
					.. " improved their world record in the race from "
					.. raceName
					.. " by "
					.. tpUtil.fmt(improvementMilliseconds)
				otherKind = "improved WR"
			else --didn't have WR before but had run before
				yourText = "World record! Amazing! Your time was "
					.. tpUtil.fmt(improvementMilliseconds)
					.. " faster, improving your prior "
					.. tpUtil.getCardinal(pastRun.virtualPlace - 1)
					.. ", and you took the WR from "
					.. legitEntries[2].username
					.. "!"

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
		if thisRun.place < 11 and thisRun.place > 1 then
			if pastRun == nil then --finished in a place for the first time
			else --have run before
				if thisRun.place == pastRun.virtualPlace then --same place, slight improvement
					yourText = "You got another "
						.. tpUtil.getCardinal(thisRun.place)
						.. ", and improved your time by "
						.. tpUtil.fmt(pastRun.runMilliseconds - thisRun.runMilliseconds)
					otherText = racerUsername
						.. " improved their "
						.. tpUtil.getCardinal(thisRun.place)
						.. " time in the race from "
						.. raceName
						.. " by "
						.. tpUtil.fmt(pastRun.runMilliseconds - thisRun.runMilliseconds)
					otherKind = "improved time"
				end
				if thisRun.place < pastRun.virtualPlace then --beat past place
					yourText = "You finished in "
						.. tpUtil.getCardinal(thisRun.place)
						.. ", better than your previous best of "
						.. tpUtil.getCardinal(pastRun.virtualPlace)
						.. "! Your time improved by "
						.. tpUtil.fmt(pastRun.runMilliseconds - thisRun.runMilliseconds)
						.. "!"
					otherText = racerUsername
						.. " got "
						.. virtualPlaceText
						.. " place in the race from "
						.. raceName
						.. "!  (previously "
						.. pastPlaceText
						.. ")"
					otherKind = "improved place"
				end
			end
		end
		if thisRun.place > 10 or thisRun.place == 0 then
			lossText = "You didn't finish in the top 10. You missed tenth place by "
				.. tpUtil.fmt(thisRun.runMilliseconds - legitEntries[10].runMilliseconds)
				.. "! Don't give up!"
		end
	end

	if pyUserFinishedRunResponse.mode == WORSE then
		if (thisRun.place < 11 and thisRun.place > 1) or (thisRun.virtualPlace > 0) then
			if thisRun.virtualPlace == nil then
				print("weirdly nil virtualrun.")
			else
				if thisRun.virtualPlace == pastRun.place then --same place, slight improvement
					yourText = "You got another "
						.. tpUtil.getCardinal(thisRun.virtualPlace)
						.. ", with a worse time by "
						.. tpUtil.fmt(thisRun.runMilliseconds - pastRun.runMilliseconds)
				end

				if thisRun.virtualPlace < 11 then --you were 2-10th
					yourText = "You finished in "
						.. tpUtil.getCardinal(thisRun.virtualPlace)
						.. " which didn't beat your previous best of "
						.. tpUtil.getCardinal(pastRun.place)
						.. ". Your time was worse by "
						.. tpUtil.fmt(thisRun.runMilliseconds - pastRun.runMilliseconds)
						.. "."
				end
				if thisRun.virtualPlace > 10 or thisRun.virtualPlace == 0 then
					lossText = "You didn't finish in the top 10. You missed tenth place by "
						.. tpUtil.fmt(thisRun.runMilliseconds - legitEntries[10].runMilliseconds)
						.. "! Don't give up!"
				end
			end
		end
	end

	--todo also think about specific text for the recipient. i.e. "YOU were knocked out by X".
	if #legitEntries >= 11 then
		knockoutText = string.format("%s was knocked out of the top ten on %s!", legitEntries[11].username, raceName)
	end

	if otherText ~= "" then
		for _, op in ipairs(PlayersService:GetPlayers()) do
			if player.UserId == op.UserId then
				continue
			end

			--TODO inline import this, not really valid at top due to conflicts.
			local rdb = require(game.ServerScriptService.rdb)
			local useWarpToSignId = (
				startSignId
				and rdb.hasUserFoundSign(op.UserId, startSignId)
				and not enums.SignIdIsExcludedFromStart[startSignId]
				and startSignId
			) or 0

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
			})
		end
	end

	local personalRaceHistoryText = ""

	local ofDistance = string.format("of distance %0.1fd", distance)
	if pyUserFinishedRunResponse.createdRace then
		personalRaceHistoryText = "Nobody has run this race " .. ofDistance .. " before you!"
	else
		if pyUserFinishedRunResponse.userRaceRunCount == 1 then
			personalRaceHistoryText = "Your first time running this race " .. ofDistance .. "!"
		else
			personalRaceHistoryText = "You have run this race "
				.. ofDistance
				.. " "
				.. tostring(pyUserFinishedRunResponse.userRaceRunCount)
				.. " times"
		end
	end

	-- show other racer counts.
	local raceTotalHistoryText = ""

	if not pyUserFinishedRunResponse.createdRace then
		local totalRacersOfThisRaceCount = pyUserFinishedRunResponse.totalRacersOfThisRaceCount
		if totalRacersOfThisRaceCount == 1 then --one total racer.
			--you are the only runner
			if pyUserFinishedRunResponse.createdRace == false then --if i just created it, do nothing
				raceTotalHistoryText = "You are the only runner." --this is my Nth try
			end
		else
			raceTotalHistoryText = tostring(totalRacersOfThisRaceCount)
				.. " racers have run this race, "
				.. tostring(pyUserFinishedRunResponse.totalRunsOfThisRaceCount)
				.. " times."
		end
	end

	--pull out my ARs and include them for extra rows on the end

	pyUserFinishedRunResponse.kind = "race results"
	pyUserFinishedRunResponse.speed = spd
	pyUserFinishedRunResponse.startSignId = startSignId
	pyUserFinishedRunResponse.endSignId = endSignId
	pyUserFinishedRunResponse.playerText = playerText
	pyUserFinishedRunResponse.yourText = yourText
	pyUserFinishedRunResponse.lossText = lossText
	pyUserFinishedRunResponse.personalRaceHistoryText = personalRaceHistoryText
	pyUserFinishedRunResponse.raceTotalHistoryText = raceTotalHistoryText

	-- print("handoff optitons and future")
	-- print(options)
	-- print(userFinishedRunResponse)

	-- annotate("Notifying " .. tostring(racerUserId) .. "," .. racerUsername)
	notify.notifyPlayerOfRunResults(player, pyUserFinishedRunResponse)
end

return module
