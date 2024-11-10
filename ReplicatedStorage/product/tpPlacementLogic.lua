--!strict

-- no imports allowed except types this just contains game logic like finding your place among a series of runs, etc.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}
local tt = require(game.ReplicatedStorage.types.gametypes)
local colors = require(game.ReplicatedStorage.util.colors)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)

-- a generic type that takes in information about a run we are evaluating, and the current top list for a race, and then returns human-scoped informational values
-- which describe how the person did generally on this run.
-- place 0 means did NOT place in any meaningful way. That is, you finished worse in time than your prior run.

-- this is cipmlex since you can improve place+time, just improve time, or neither. and you can also newrun.

local function ValidateAndReturnInterleaved(ir: tt.interleavedResult): tt.interleavedResult
	if ir.newRace == nil then
		error("unset newRace")
	end
	if ir.newRun == nil then
		error("unset newRun")
	end
	if ir.newPlace == -1 then
		error("unset newPlace")
	end
	if ir.newRace == nil then
		error("unset newRace")
	end
	if ir.priorPlace == -1 and ir.newRun ~= true then
		error("priorPlace is -1")
	end

	if ir.priorTimeMs == -1 and ir.newRun ~= true then
		error("unset priorTimeMs")
	end
	if ir.newTimeMs == -1 then
		error("unset newTimeMs")
	end
	if ir.missedNextPlaceByMs == -1 then
		error("unset missedNextPlaceByMs")
	end
	if ir.beatNextPlaceByMs == -1 then
		error("unset beatNextPlaceByMs")
	end
	if ir.beatNextPlaceByMs < 0 then
		error("unset beatNextPlaceByMs")
	end
	if ir.missedImprovementByMs < 0 then
		error("unset missedImprovementByMs")
	end
	if ir.missedNextPlaceByMs < 0 then
		error("unset missedNextPlaceByMs")
	end
	if ir.newTimeMs <= 0 then
		error("unset newTimeMs")
	end
	-- if ir.priorTimeMs <= 0 then
	-- 	error("priorTimeMs is less than or equal to 0")
	-- end

	return ir
end

module.GetPlacementAmongRuns = function(
	frame: tt.DynamicRunFrame,
	myUserId: number,
	myTimeMs: number
): tt.interleavedResult
	local holder: any = {
		newRace = nil,
		newRun = nil,
		newPlace = -1, --0 means "this run did not occupy a place in the final topX list". >0 means we DID occupy a place.
		newTimeMs = -1,

		priorPlace = -1,
		priorTimeMs = -1,

		missedNextPlaceByMs = -1,
		beatNextPlaceByMs = -1,
		missedImprovementByMs = -1, --how much it would have taken to improve in any way such that I would have had a real "place"
	}

	holder.newTimeMs = myTimeMs
	if #frame.places == 0 then
		holder.newRace = true
	else
		holder.newRace = false
	end

	if frame.myPriorPlace then
		holder.newRun = false
	else
		holder.newRun = true
	end

	local myPastPlace: number = -1
	local myPastTimeMs: number = -1
	if frame.myPriorPlace then
		myPastPlace = frame.myPriorPlace.place
		myPastTimeMs = frame.myPriorPlace.timeMs
	else
		myPastPlace = 0
		myPastTimeMs = 0
	end

	holder.priorPlace = myPastPlace
	holder.priorTimeMs = myPastTimeMs

	-- this object is the one before the currente run.
	-- note that if we are already slower than our past run, it will barely be used.
	local immediatelyPrecedingThisRunNonSelfGuy: tt.DynamicPlace? = nil
	for _, existingPlace in ipairs(frame.places) do
		if existingPlace.userId == myUserId then -- nonself so we can't include this guy.
			continue
		elseif myTimeMs < existingPlace.timeMs then -- if the guy is slower then he's not preceding
			break
		else
			immediatelyPrecedingThisRunNonSelfGuy = existingPlace
		end
	end

	local anyImmediatelyPrecedingGuyThanThisRun: tt.DynamicPlace? = nil
	for _, existingPlace in ipairs(frame.places) do
		if myTimeMs < existingPlace.timeMs then
			break
		end
		anyImmediatelyPrecedingGuyThanThisRun = existingPlace
	end

	-- will only hit if I'm leading any of my prior runs.
	local anyImmediatelyFollowingGuyAfterThisRun: tt.DynamicPlace? = nil
	for _, existingPlace in ipairs(frame.places) do
		if myTimeMs < existingPlace.timeMs then
			anyImmediatelyFollowingGuyAfterThisRun = existingPlace
			break
		end
	end

	if immediatelyPrecedingThisRunNonSelfGuy then
		assert(immediatelyPrecedingThisRunNonSelfGuy.timeMs <= myTimeMs, "bad")
	end
	if anyImmediatelyPrecedingGuyThanThisRun then
		assert(anyImmediatelyPrecedingGuyThanThisRun.timeMs <= myTimeMs, "bad")
	end
	if anyImmediatelyFollowingGuyAfterThisRun then
		assert(anyImmediatelyFollowingGuyAfterThisRun.timeMs > myTimeMs, "bad")
	end

	-- let's find my current place then.

	-- main cases:
	-- if i've run it before,
	---- as long as I beat myhmy past time, then ill either be in that place or better.
	---- if i didn't beat my last time, this place is 0
	-- if i haven't run it before,
	---- i'm in the place immediately after the guy before me, or 1st if he doesn't exist.

	if holder.priorPlace == 0 then -- I haven't run it before.
		if anyImmediatelyPrecedingGuyThanThisRun then -- I'm just behind this guy who ran faster than me
			holder.newPlace = anyImmediatelyPrecedingGuyThanThisRun.place + 1
			holder.missedNextPlaceByMs = myTimeMs - anyImmediatelyPrecedingGuyThanThisRun.timeMs + 1
			holder.missedImprovementByMs = myTimeMs - anyImmediatelyPrecedingGuyThanThisRun.timeMs + 1
		else -- I ran fastest in a new race
			holder.newPlace = 1
			holder.missedNextPlaceByMs = 0
			holder.missedImprovementByMs = 0
		end
		if anyImmediatelyFollowingGuyAfterThisRun then
			holder.beatNextPlaceByMs = anyImmediatelyFollowingGuyAfterThisRun.timeMs - myTimeMs
		else
			holder.beatNextPlaceByMs = 0
		end
	else -- we've run this race before.
		if holder.newTimeMs < holder.priorTimeMs then -- and we beat our past time
			if anyImmediatelyPrecedingGuyThanThisRun then
				holder.newPlace = anyImmediatelyPrecedingGuyThanThisRun.place + 1
				holder.missedNextPlaceByMs = myTimeMs - anyImmediatelyPrecedingGuyThanThisRun.timeMs + 1
				holder.missedImprovementByMs = myTimeMs - anyImmediatelyPrecedingGuyThanThisRun.timeMs + 1
			else
				holder.newPlace = 1
				holder.missedNextPlaceByMs = 0
				holder.missedImprovementByMs = 0
			end
			if anyImmediatelyFollowingGuyAfterThisRun then
				holder.beatNextPlaceByMs = anyImmediatelyFollowingGuyAfterThisRun.timeMs - myTimeMs
			else
				holder.beatNextPlaceByMs = 0
			end
		else -- and we didn't beat our past time
			holder.newPlace = 0
			holder.missedNextPlaceByMs = holder.newTimeMs - holder.priorTimeMs + 1
			holder.beatNextPlaceByMs = 0
			holder.missedImprovementByMs = holder.newTimeMs - holder.priorTimeMs + 1
		end
	end

	local guy = holder :: tt.interleavedResult
	return ValidateAndReturnInterleaved(guy)
end

module.InterleavedToText = function(interleavedResult: tt.interleavedResult): (string, Color3)
	if interleavedResult.newRace then
		return "New Race", colors.lightGreen
	end

	-- totally not found, new race taken care of.
	-- now, we generally don't care much about newRun. since you're still basically going to get a new placement.

	if interleavedResult.newRun then
		if interleavedResult.newPlace == 1 then
			return string.format("WR Pace! by %0.1fs!", interleavedResult.beatNextPlaceByMs / 1000), colors.lightGreen
		elseif interleavedResult.newPlace > 0 and interleavedResult.newPlace <= 10 then
			return string.format(
				"New %s place, leading by %0.1fs",
				tpUtil.getCardinal(interleavedResult.newPlace),
				interleavedResult.beatNextPlaceByMs / 1000
			),
				colors.warpColor
		elseif interleavedResult.newPlace > 10 then
			return string.format(
				"New %s place by %0.1fs",
				tpUtil.getCardinal(interleavedResult.newPlace),
				interleavedResult.beatNextPlaceByMs / 1000
			),
				colors.warpColor
		else
			--should never happen.
			return "unknown case", colors.lightGreen
		end
	end

	-- it's NOT a new run.

	if interleavedResult.newPlace == 1 then
		if interleavedResult.priorPlace == interleavedResult.newPlace then
			return string.format("Improve your WR by %0.1fs", interleavedResult.beatNextPlaceByMs / 1000),
				colors.greenGo
		else
			return string.format(
				"Take the WR! by %0.1fs. Previously %s",
				interleavedResult.beatNextPlaceByMs / 1000,
				tpUtil.getCardinal(interleavedResult.priorPlace)
			),
				colors.greenGo
		end
	end

	if interleavedResult.newPlace == 0 then
		if interleavedResult.priorPlace == 0 then
			if interleavedResult.missedNextPlaceByMs == 0 then
				return string.format("You wouldn't place at all.! %s", ""), colors.warpColor
			else
				return string.format("You wouldn't place, by %0.1fs", interleavedResult.missedNextPlaceByMs / 1000),
					colors.lightRed
			end
		else
			if interleavedResult.missedImprovementByMs == 0 then
				return "error case.", colors.warpColor
			else
				return string.format(
					"Fail to beat prior %s by %0.1fs",
					tpUtil.getCardinal(interleavedResult.priorPlace),
					interleavedResult.missedImprovementByMs / 1000
				),
					colors.lightRed
			end
		end
	end

	if interleavedResult.newPlace > 0 then -- we placed
		if interleavedResult.newPlace <= 10 then --we were top10
			if interleavedResult.priorPlace == interleavedResult.newPlace then --we tied plast place but still bveat them.
				return string.format(
					"Improve your %s place by %0.1fs",
					tpUtil.getCardinal(interleavedResult.newPlace),
					interleavedResult.beatNextPlaceByMs / 1000
				),
					colors.warpColor
			elseif interleavedResult.newPlace < interleavedResult.priorPlace then -- we beat someone else and at least moved up in place
				return string.format(
					"On pace for %s, behind by by %0.1fs, improving your %s",
					tpUtil.getCardinal(interleavedResult.newPlace),
					interleavedResult.beatNextPlaceByMs / 1000,
					tpUtil.getCardinal(interleavedResult.priorPlace)
				),
					colors.greenGo
			else
				return string.format(
					"Behind you previous %s, behind by %0.1fs",
					tpUtil.getCardinal(interleavedResult.priorPlace),
					interleavedResult.missedNextPlaceByMs / 1000
				),
					colors.redSlowDown
			end
		else --we placed <100 but not top10
			if interleavedResult.priorPlace == interleavedResult.newPlace then
				return string.format(
					"Improve your %s place by %0.1fs",
					tpUtil.getCardinal(interleavedResult.newPlace),
					interleavedResult.missedNextPlaceByMs / 1000
				),
					colors.warpColor
			elseif interleavedResult.newPlace < interleavedResult.priorPlace then
				return string.format(
					"Would place %s, better than your previous %s, ahead of next place by %0.1fs",
					tpUtil.getCardinal(interleavedResult.newPlace),
					tpUtil.getCardinal(interleavedResult.priorPlace),
					interleavedResult.beatNextPlaceByMs / 1000
				),
					colors.greenGo
			else
				return string.format(
					"Behind your previous %s by %0.1fs",
					tpUtil.getCardinal(interleavedResult.priorPlace),
					interleavedResult.missedNextPlaceByMs / 1000
				),
					colors.redSlowDown
			end
		end
	end

	return "unknown case", colors.lightGreen
end

_annotate("end")
return module
