--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

--a report of a
export type Runner = {
	place: number, --1,2,3, or N, with "you" interleaved
	userId: number,
	username: string,
	timeMs: number,
}

--a single race in the contest
export type ContestRace = {
	raceNumber: number, --number in the contest for ordering.
	raceId: number,
	startSignName: string,
	endSignName: string,
	dist: number,
	user: Runner,
	best: Runner,
	runners: { Runner },
}

export type Contest = {
	contestid: number,
	conteststart: string,
	contestend: string,
	contestremaining: number,
	active: boolean,
	name: string,
	races: { ContestRace },
	leaders: { [string]: Runner }, --string cause of deserialization
	user: Runner,
}

-- Summary of a contest for list display (lightweight, used for picking which to view)
-- Same logical entity as Contest, just with minimal fields for the list UI
export type ArchivedContest = {
	contestId: number,
	name: string,
	startDate: string,
	endDate: string,
	raceCount: number,
	active: boolean,
}

_annotate("end")
return module
