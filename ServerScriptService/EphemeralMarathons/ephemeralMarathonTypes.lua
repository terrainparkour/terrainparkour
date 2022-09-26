--!strict
--1.020 feb 25 22
--eval 9.24.22

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
	playerText: string,
	yourText: string,
	personalRaceHistoryText: string,
	raceTotalHistoryText: string,
	runEntries: { ephemeralMarathonBestRun },
	afterRunData: {},
	username: string,
	actionResults: {},
	run: lbUpdateFromEphemeralMarathonRun,
}

return {}
