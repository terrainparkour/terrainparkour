-- generate a series of N fake run results, where place 1 is userid 261 and takes 1s. place 2 is userid 262 and takes 2s. etc.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local tt = require(game.ReplicatedStorage.types.gametypes)
local tpPlacementLogic = require(game.ReplicatedStorage.product.tpPlacementLogic)

local function GetNSampleRunResultDynamicPlaces(n): { tt.DynamicPlace }
	local ii = 0
	local res: { tt.DynamicPlace } = {}
	while ii < n do
		local theGuy: tt.DynamicPlace = {
			place = ii + 1,
			timeMs = 1000 + ii * 1000,
			userId = 261 + ii,
			username = string.format("userId_%d", 261 + ii),
		}
		table.insert(res, theGuy)
		ii += 1
	end
	return res
end

local function testBeatingPriorFirstPlaceTime()
	local normal20s = GetNSampleRunResultDynamicPlaces(20)
	local myPriorPlace = nil
	for _, place in normal20s do
		if place.userId == 261 then
			myPriorPlace = place
			break
		end
	end

	local frame: tt.DynamicRunFrame = {
		places = normal20s,
		myPriorPlace = myPriorPlace,
		myfound = true,
		targetSignId = 1,
		targetSignName = "test",
	}

	local res = tpPlacementLogic.GetPlacementAmongRuns(frame, 261, 10)
	assert(res.newPlace == 1, "newPlace is not 1")
	assert(res.newRun == false, "newRun is not false")
	assert(res.newRace == false, "newRace is not false")
	assert(res.priorPlace == 1, "priorPlace is not 1")
	assert(res.priorTimeMs == 1000, "priorTimeMs is not 100")
	assert(res.beatNextPlaceByMs == 990, "beatNextPlaceByMs is not 990")
	assert(res.missedNextPlaceByMs == 0, "missedNextPlaceByMs is not 0")
	assert(res.missedImprovementByMs == 0, "missedImprovementByMs is not 0")
end

local function testTyingPriorFirstPlaceTime()
	local normal20s = GetNSampleRunResultDynamicPlaces(20)
	local myPriorPlace = nil
	for _, place in normal20s do
		if place.userId == 261 then
			myPriorPlace = place
			break
		end
	end

	local frame: tt.DynamicRunFrame = {
		places = normal20s,
		myPriorPlace = myPriorPlace,
		myfound = true,
		targetSignId = 1,
		targetSignName = "test",
	}

	local res = tpPlacementLogic.GetPlacementAmongRuns(frame, 261, 1000)
	assert(res.newPlace == 0, "newPlace is not 0")
	assert(res.newRun == false, "newRun is not false")
	assert(res.newRace == false, "newRace is not false")
	assert(res.priorPlace == 1, "priorPlace is not 1")
	assert(res.priorTimeMs == 1000, "priorTimeMs is not 100")
	assert(res.beatNextPlaceByMs == 0, "beatNextPlaceByMs is not 990")
	assert(res.missedNextPlaceByMs == 1, "missedNextPlaceByMs is not 0")
	assert(res.missedImprovementByMs == 1, "missedImprovementByMs is not 0")
end

local function testTyingPriorThirdPlaceTime()
	local normal20s = GetNSampleRunResultDynamicPlaces(20)
	local myPriorPlace = nil
	for _, place in normal20s do
		if place.userId == 263 then
			myPriorPlace = place
			break
		end
	end

	local frame: tt.DynamicRunFrame = {
		places = normal20s,
		myPriorPlace = myPriorPlace,
		myfound = true,
		targetSignId = 1,
		targetSignName = "test",
	}

	local res = tpPlacementLogic.GetPlacementAmongRuns(frame, 263, 3000)
	assert(res.newPlace == 0, "newPlace is not 1")
	assert(res.newRun == false, "newRun is not false")
	assert(res.newRace == false, "newRace is not false")
	assert(res.priorPlace == 3, "priorPlace is not 1")
	assert(res.priorTimeMs == 3000, "priorTimeMs is not 100")
	assert(res.beatNextPlaceByMs == 0, "beatNextPlaceByMs is not 0")
	assert(res.missedNextPlaceByMs == 1, "missedNextPlaceByMs is not 0")
	assert(res.missedImprovementByMs == 1, "missedImprovementByMs is not 0")
end

local function testNotBeatingPriorWinningRun()
	local normal20s = GetNSampleRunResultDynamicPlaces(20)
	local myPriorPlace = nil
	for _, place in normal20s do
		if place.userId == 261 then
			myPriorPlace = place
			break
		end
	end

	local frame: tt.DynamicRunFrame = {
		places = normal20s,
		myPriorPlace = myPriorPlace,
		myfound = true,
		targetSignId = 1,
		targetSignName = "test",
	}

	local res = tpPlacementLogic.GetPlacementAmongRuns(frame, 261, 1500)
	assert(res.newPlace == 0, "newPlace is not 0")
	assert(res.newRun == false, "newRun is not false")
	assert(res.newRace == false, "newRace is not false")
	assert(res.priorPlace == 1, "priorPlace is not 1")
	assert(res.priorTimeMs == 1000, "priorTimeMs is not 1000")
	assert(res.missedNextPlaceByMs == 501, "missedNextPlaceByMs is not 0")
	assert(res.beatNextPlaceByMs == 0, "beatNextPlaceByMs is not 0")
	assert(res.missedImprovementByMs == 501, "missedImprovementByMs is not 501")
end

local function TextNewRun2ndPlace()
	local normal20s = GetNSampleRunResultDynamicPlaces(20)
	local myPriorPlace = nil

	local frame: tt.DynamicRunFrame = {
		places = normal20s,
		myPriorPlace = myPriorPlace,
		myfound = true,
		targetSignId = 1,
		targetSignName = "test",
	}

	local res = tpPlacementLogic.GetPlacementAmongRuns(frame, 1, 1500)
	assert(res.newPlace == 2, "newPlace is not 0")
	assert(res.newRun == true, "newRun is not false")
	assert(res.newRace == false, "newRace is not false")
	assert(res.priorPlace == 0, "priorPlace is not 1")
	assert(res.priorTimeMs == 0, "priorTimeMs is not 100")
	assert(res.missedNextPlaceByMs == 501, "missedNextPlaceByMs is not 0")
	assert(res.beatNextPlaceByMs == 500, "beatNextPlaceByMs is not 0")
	assert(res.missedImprovementByMs == 501, "missedImprovementByMs is not 0")
end

local function TextNewRun1stPlace()
	local normal20s = GetNSampleRunResultDynamicPlaces(20)
	local myPriorPlace = nil

	local frame: tt.DynamicRunFrame = {
		places = normal20s,
		myPriorPlace = myPriorPlace,
		myfound = true,
		targetSignId = 1,
		targetSignName = "test",
	}

	local res = tpPlacementLogic.GetPlacementAmongRuns(frame, 1, 200)
	assert(res.newPlace == 1, "newPlace is not 0")
	assert(res.newRun == true, "newRun is not false")
	assert(res.newRace == false, "newRace is not false")
	assert(res.priorPlace == 0, "priorPlace is not 1")
	assert(res.priorTimeMs == 0, "priorTimeMs is not 100")
	assert(res.missedNextPlaceByMs == 0, "missedNextPlaceByMs is not 0")
	assert(res.beatNextPlaceByMs == 800, "beatNextPlaceByMs is not 0")
	assert(res.missedImprovementByMs == 0, "missedImprovementByMs is not 0")
end

local function TextNewRunLastPlace()
	local normal20s = GetNSampleRunResultDynamicPlaces(20)
	local myPriorPlace = nil

	local frame: tt.DynamicRunFrame = {
		places = normal20s,
		myPriorPlace = myPriorPlace,
		myfound = true,
		targetSignId = 1,
		targetSignName = "test",
	}

	local res = tpPlacementLogic.GetPlacementAmongRuns(frame, 1, 20001)
	assert(res.newPlace == 21, "newPlace is not 0")
	assert(res.newRun == true, "newRun is not false")
	assert(res.newRace == false, "newRace is not false")
	assert(res.priorPlace == 0, "priorPlace is not 1")
	assert(res.priorTimeMs == 0, "priorTimeMs is not 100")
	assert(res.missedNextPlaceByMs == 2, "missedNextPlaceByMs is not 0")
	assert(res.beatNextPlaceByMs == 0, "beatNextPlaceByMs is not 0")
	assert(res.missedImprovementByMs == 2, "missedImprovementByMs is not 0")
end

local function TestNewRunForYouBeatFirst()
	local normal20s = GetNSampleRunResultDynamicPlaces(20)
	local myPriorPlace = nil

	local frame: tt.DynamicRunFrame = {
		places = normal20s,
		myPriorPlace = myPriorPlace,
		myfound = true,
		targetSignId = 1,
		targetSignName = "test",
	}

	local res = tpPlacementLogic.GetPlacementAmongRuns(frame, 1, 400)
	assert(res.newPlace == 1, "newPlace is not 0")
	assert(res.newRun == true, "newRun is not false")
	assert(res.newRace == false, "newRace is not false")
	assert(res.priorPlace == 0, "priorPlace is not 1")
	assert(res.priorTimeMs == 0, "priorTimeMs is not 100")
	assert(res.missedNextPlaceByMs == 0, "missedNextPlaceByMs is not 0")
	assert(res.beatNextPlaceByMs == 600, "beatNextPlaceByMs is not 0")
	assert(res.missedImprovementByMs == 0, "missedImprovementByMs is not 0")
end

local function TestNewRunForYouGetSecond()
	local normal20s = GetNSampleRunResultDynamicPlaces(20)
	local myPriorPlace = nil

	local frame: tt.DynamicRunFrame = {
		places = normal20s,
		myPriorPlace = myPriorPlace,
		myfound = true,
		targetSignId = 1,
		targetSignName = "test",
	}

	local res = tpPlacementLogic.GetPlacementAmongRuns(frame, 1, 1900)
	assert(res.newPlace == 2, "newPlace is not 0")
	assert(res.newRun == true, "newRun is not false")
	assert(res.newRace == false, "newRace is not false")
	assert(res.priorPlace == 0, "priorPlace is not 1")
	assert(res.priorTimeMs == 0, "priorTimeMs is not 100")
	assert(res.missedNextPlaceByMs == 901, "missedNextPlaceByMs is not 901")
	assert(res.beatNextPlaceByMs == 100, "beatNextPlaceByMs is not 0")
	assert(res.missedImprovementByMs == 901, "missedImprovementByMs is not 0")
end

local function TestNewRunForYouTieFourth()
	local normal20s = GetNSampleRunResultDynamicPlaces(20)
	local myPriorPlace = nil

	local frame: tt.DynamicRunFrame = {
		places = normal20s,
		myPriorPlace = myPriorPlace,
		myfound = true,
		targetSignId = 1,
		targetSignName = "test",
	}

	local res = tpPlacementLogic.GetPlacementAmongRuns(frame, 1, 3003)
	assert(res.newPlace == 4, "newPlace is not 0")
	assert(res.newRun == true, "newRun is not false")
	assert(res.newRace == false, "newRace is not false")
	assert(res.priorPlace == 0, "priorPlace is not 1")
	assert(res.priorTimeMs == 0, "priorTimeMs is not 100")
	assert(res.missedNextPlaceByMs == 4, "missedNextPlaceByMs is not 0")
	assert(res.beatNextPlaceByMs == 997, "beatNextPlaceByMs is not 0")
	assert(res.missedImprovementByMs == 4, "missedImprovementByMs is not 0")
end

local function TestJustBarelyNotImprovingYourSecond()
	local normal20s = GetNSampleRunResultDynamicPlaces(20)
	local myPriorPlace = nil

	for _, place in normal20s do
		if place.userId == 262 then
			myPriorPlace = place
			break
		end
	end

	local frame: tt.DynamicRunFrame = {
		places = normal20s,
		myPriorPlace = myPriorPlace,
		myfound = true,
		targetSignId = 1,
		targetSignName = "test",
	}

	local res = tpPlacementLogic.GetPlacementAmongRuns(frame, 262, 2002)
	assert(res.newPlace == 0, "newPlace is not 0")
	assert(res.newRun == false, "newRun is not false")
	assert(res.newRace == false, "newRace is not false")
	assert(res.priorPlace == 2, "priorPlace is not 2")
	assert(res.priorTimeMs == 2000, "priorTimeMs is not 2000")
	assert(res.missedNextPlaceByMs == 3, "missedNextPlaceByMs is not 1003")
	assert(res.beatNextPlaceByMs == 0, "beatNextPlaceByMs is not 0")
	assert(res.missedImprovementByMs == 3, "missedImprovementByMs is not 3")
end

local function TestJustBarelyImprovingYourSecond()
	local normal20s = GetNSampleRunResultDynamicPlaces(20)
	local myPriorPlace = nil
	for _, place in normal20s do
		if place.userId == 262 then
			myPriorPlace = place
			break
		end
	end

	local frame: tt.DynamicRunFrame = {
		places = normal20s,
		myPriorPlace = myPriorPlace,
		myfound = true,
		targetSignId = 1,
		targetSignName = "test",
	}

	local res = tpPlacementLogic.GetPlacementAmongRuns(frame, 262, 1997)
	assert(res.newPlace == 2, "newPlace is not 0")
	assert(res.newRun == false, "newRun is not false")
	assert(res.newRace == false, "newRace is not false")
	assert(res.priorPlace == 2, "priorPlace is not 1")
	assert(res.priorTimeMs == 2000, "priorTimeMs is not 100")
	assert(res.missedNextPlaceByMs == 998, "missedNextPlaceByMs is not 0")
	assert(res.beatNextPlaceByMs == 3, "beatNextPlaceByMs is not 0")
	assert(res.missedImprovementByMs == 998, "missedImprovementByMs is not 0")
end

local function TestTotallyNewRace()
	local normal20s = {}
	local myPriorPlace = nil

	local frame: tt.DynamicRunFrame = {
		places = normal20s,
		myPriorPlace = myPriorPlace,
		myfound = true,
		targetSignId = 1,
		targetSignName = "test",
	}

	local res = tpPlacementLogic.GetPlacementAmongRuns(frame, 1, 5500)
	assert(res.newPlace == 1, "newPlace is not 0")
	assert(res.newRun == true, "newRun is not false")
	assert(res.newRace == true, "newRace is not false")
	assert(res.priorPlace == 0, "priorPlace is not 1")
	assert(res.priorTimeMs == 0, "priorTimeMs is not 100")
	assert(res.missedNextPlaceByMs == 0, "missedNextPlaceByMs is not 0")
	assert(res.beatNextPlaceByMs == 0, "beatNextPlaceByMs is not 0")
	assert(res.missedImprovementByMs == 0, "missedImprovementByMs is not 0")
end

module.TestAll = function()
	testBeatingPriorFirstPlaceTime()
	testNotBeatingPriorWinningRun()
	testTyingPriorFirstPlaceTime()
	testTyingPriorThirdPlaceTime()
	TextNewRun2ndPlace()
	TextNewRun1stPlace()
	TestNewRunForYouBeatFirst()
	TestTotallyNewRace()
	TextNewRunLastPlace()
	TestNewRunForYouGetSecond()
	TestNewRunForYouTieFourth()
	TestJustBarelyNotImprovingYourSecond()
	TestJustBarelyImprovingYourSecond()
end

_annotate("end")
return module
