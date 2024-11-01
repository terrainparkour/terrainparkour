--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

export type createEphemeralMarathonResponse = { result: string }

export type ephemeralMarathonBestRun = {
	userId: number,
	timeMs: number,
	rank: number,
	userRunCount: number,
}

export type ephemeralMarathon = {
	signNames: { string },
	count: number,
	marathonId: number,
	start: number,
	duration: number,
	bestRuns: { ephemeralMarathonBestRun },
}

export type lbUpdateFromEphemeralMarathonRun = {
	em: ephemeralMarathon,
	userId: number,
	marathonId: number,
	timeMs: number,
}

export type emRunResults = {
	userId: number,
	formattedRunMilliseconds: string,
	kind: string,
	raceName: string,
	yourText: string,
	yourColor: Color3,
	-- personalRaceHistoryText: string,
	runEntries: { ephemeralMarathonBestRun },
	afterRunData: {},
	username: string,
	actionResults: {},
	run: lbUpdateFromEphemeralMarathonRun,
}

_annotate("end")
return {}
