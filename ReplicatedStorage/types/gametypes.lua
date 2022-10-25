--!strict

--dumping ground for general response types
--TODO: synchronize this with python return types too!
--eval 9.21

export type warperWrapper = { requestWarpToSign: (signId: number) -> nil }

export type signFindOptions = {
	kind: string,
	userId: number, --the user this find is in relation to.
	lastFinderUserId: number,
	lastFinderUsername: string,
	signName: string,
	totalSignsInGame: number,
	userTotalFindCount: number,
	signTotalFinds: number,
	findRank: number,
}

export type pyUserFoundSign = {
	kind: string,
	userId: number,
	lastFinderUserId: number,
	lastFinderUsername: string,
	foundNew: boolean,
	success: string,
	created: boolean,
	actionResults: { actionResult },
	userTotalFindCount: number,
	findRank: number,
	signTotalFinds: number,
	totalSignsInGame: number,
}

export type leaveOptions = {
	kind: string,
	userId: number,
}

export type pyUserBadgeGrant = {
	userId: number,
	badgeAssetId: number,
	badgeName: string,
	badgeTotalGrantCount: number,
}

-- equivalent to dcRunResponse:
export type pyUserFinishedRunResponse = {
	thisRunPlace: number,
	thisRunMilliseconds: number,
	thisRunImprovedPlace: boolean,
	startSignId: number,
	endSignId: number,
	mode: number,
	winGap: number,
	tied: boolean,
	distance: number,
	speed: number,
	raceName: string,
	raceIsCompetitive: boolean,

	--relations
	runEntries: { runEntry },
	actionResults: { actionResult },

	--metadata
	kind: string,
	userId: number,
	username: string,
	newFind: boolean,
	createdRace: boolean,
	createdMarathon: boolean,

	--stats
	userTotalRaceCount: number,
	userTotalRunCount: number,
	userMarathonRunCount: number,
	userCompetitiveWRCount: number,
	userTotalWRCount: number,
	totalRunsOfThisRaceCount: number,
	userTix: number,
	userTotalTop10Count: number,
	awardCount: number,

	totalRacersOfThisRaceCount: number,

	userRaceRunCount: number,
	userTotalFindCount: number,

	--for display options
	raceName: string,
	yourText: string,
	raceTotalHistoryText: string,
}

export type ephemeralNotificationOptions = {
	userId: number,
	text: string,
	kind: string,
	warpToSignId: number,
}

export type userFinishedRunOptions = {
	userId: number,
	startId: number,
	endId: number,
	runMilliseconds: number,
	otherPlayerUserIds: string,
	remoteActionName: string,
}

--in runresult, describe a prior best result.  TODO: does or does not include the last run / the old prior best of subject user?
export type runEntry = {
	kind: string,
	userId: number,
	runMilliseconds: number,
	username: string,
	place: number, --1-10 mean normal. 0 means "insert visually in the order it appears in list"
	virtualPlace: number, --the
}

--specifier for a simple python-formatted message.
--to be replaced by fuller more detailed specific message  responses (such as RunResults format)
export type actionResult = {
	message: string,
	kind: string,
	userId: number, --the subject of the message
	notifyAllExcept: boolean, --whether we should tell everyone else, or the target userId
	warpToSignId: number,
}

--add-on information when I talk to the server.  quite volatile.
export type afterdata = {
	kind: string,
	userId: number,
	banned: boolean?,
	actionResults: { actionResult },
	firstTimeJoining: boolean, --check if this still shows up.
	success: boolean,
	foundNew: boolean,
	pyUserFinishedRunResponse: pyUserFinishedRunResponse?,
}

export type badgeUpdate = { kind: string, userId: number, badgeCount: number }

export type getNonTop10RacesByUser = {
	kind: string,
	userId: number,
	raceDescriptions: { string },
}

export type afterData_getStatsByUser = {
	kind: string,
	userId: number,
	runs: number,
	userTotalFindCount: number,
	findRank: number,
	top10s: number,
	races: number,
	userTix: number,
	userCompetitiveWRCount: number,
	userTotalWRCount: number,
	wrRank: number,
	totalSignCount: number,
	awardCount: number,
}

--every time a run happens, update everyone about this user's changed scoreboard.
export type lbUpdateFromRun = {
	kind: string,
	userId: number,
	userTix: number,
	top10s: number,
	races: number,
	runs: number,
	userCompetitiveWRCount: number,
	userTotalWRCount: number,
	awardCount: number,
}

export type lbUserStats = {
	kind: string,
	userId: number,
	userTix: number,
	top10s: number,
	races: number,
	runs: number,
	userCompetitiveWRCount: number,
	userTotalWRCount: number,
	awardCount: number,
}

export type lbUpdateFromFind = {
	kind: string,
	userId: number,
	userTotalFindCount: number,
	userTix: number,
	findRank: number,
}

export type badgeDescriptor = {
	name: string,
	assetId: number,
	badgeClass: string,
	baseNumber: number?,
	hint: string?,
	order: number?,
}

export type badgeAttainment = {
	badge: badgeDescriptor,
	got: boolean,
	progress: number,
	baseNumber: number,
}

export type badgeOptions = {
	text: string,
	kind: string,
	userId: number,
}

export type userSettingValue = { name: string, domain: string, value: boolean? }
export type userSettingValuesWithDistributions = { name: string, domain: string, value: boolean?, percentage: number }

--for the left side of a sign popup.
export type signWrStatus = { userId: number, count: number }

--for big ordered lists coming from server
export type userRankedOrderItem = { userId: number, username: string, rank: number, count: number }

-- the generic version of this, which also contains a string description, for example for displaying top long runs of the day.
-- export type genericRankedOrderItem = { userId: number, username: string, desc: string, rank: number, count: number }

export type missingRunRequestParams = { userId: number, kind: string, signId: number }

export type userAward = { userId: number, contestName: string, awardName: string }

-- on the wire from python backend types
export type DynamicPlace = { place: number, username: string, userId: number, timeMs: number }

--contextual summary data for this user, current run, and this target.
--later: add myfound too, so we can green highlight target more easily.
export type DynamicRunFrame = {
	targetSignId: number,
	targetSignName: string,
	places: { DynamicPlace },
	myplace: DynamicPlace?, --requesting user's place
	myfound: boolean,
}
export type dynamicRunFromData = { kind: string, fromSignName: string, frames: { DynamicRunFrame } }

--for dynamic running event communication localscript to server
export type dynamicRunningControlType = { action: string, fromSignId: number, userId: number }

--SERVEREVENTS
export type runningServerEventUserBest = { userId: number, username: string, timeMs: number, runCount: number }

export type runningServerEvent = {
	name: string,
	serverEventNumber: number,
	startedTick: number,
	remainingTick: number,
	startSignId: number,
	endSignId: number,
	userBests: { [number]: runningServerEventUserBest },
	tixValue: number,
	distance: number,
}

export type serverEventUpdateType = string

export type serverEventUpdates = { { serverEvent: runningServerEvent, updateType: serverEventUpdateType } }

--used from localtimer => server consumers who want to know when runs complete.
export type serverFinishRunNotifierType = {
	startSignId: number,
	endSignId: number,
	timeMs: number,
	userId: number,
	username: string,
}

export type serverEventTixAllocation = { userId: number, username: string, tixallocation: number, eventPlace: number }

export type playerProfileData={}

return {}
