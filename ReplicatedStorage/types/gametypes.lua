--!strict

--dumping ground for general response types
--TODO: synchronize this with python return types too!

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

export type signFindOptions = {
	kind: string,
	userId: number, --the user this find is in relation to.
	lastFinderUserId: number,
	lastFinderUsername: string,
	signName: string,
	totalSignsInGame: number,
	findCount: number,
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
	findCount: number,
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
	winGap: number?,
	tied: boolean?,
	distance: number,
	speed: number,
	raceName: string,
	raceIsCompetitive: boolean,
	yourText: string,
	raceTotalHistoryText: string,

	--metadata
	kind: string,
	userId: number,
	username: string,
	newFind: boolean,
	createdRace: boolean,
	createdMarathon: boolean,

	--user stats
	userTix: number,
	cwrs: number,
	cwrTop10s: number,
	cwrRank: number,
	wrCount: number,
	wrRank: number,
	top10s: number,

	userRaceRunCount: number,
	userTotalRaceCount: number,
	userTotalRunCount: number,

	daysInGame: number,
	awardCount: number,

	findCount: number,
	findRank: number,

	-- info on the race or run.
	userMarathonRunCount: number,
	totalRunsOfThisRaceCount: number,
	totalRacersOfThisRaceCount: number,

	--relations, must be last to avoid dumb python typing
	runEntries: { runEntry },
	actionResults: { actionResult },
}

export type ephemeralNotificationOptions = {
	userId: number,
	text: string,
	kind: string,
	warpToSignId: number,
	highlightSignId: number?,
}

export type userFinishedRunOptions = {
	userId: number,
	startSignId: number,
	endSignId: number,
	runMilliseconds: number,
	allPlayerUserIds: string,
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
	findCount: number,
	findRank: number,
	cwrs: number,
	cwrRank: number,
	cwrTop10s: number,
	wrCount: number,
	wrRank: number,
	top10s: number,
	userTotalRunCount: number,
	userTotalRaceCount: number,
	userTix: number,
	serverPatchedInTotalSignCount: number, --this is patched in from the server. do NOT get it from the remote DB and do NOT get it from the client (becaues of replication stuff)
	awardCount: number,
	--I believe badges come later, via another async process
	daysInGame: number,
}

--every time a run happens, update everyone about this user's changed scoreboard.
export type lbUpdateFromRun = {
	kind: string,
	userId: number,
	userTix: number,
	cwrs: number,
	cwrTop10s: number,
	top10s: number,
	userTotalRaceCount: number,
	userTotalRunCount: number,
	wrCount: number,
	wrRank: number,
	daysInGame: number,
	awardCount: number,
}

export type lbUserStats = {
	kind: string,
	userId: number,
	userTix: number,
	top10s: number,
	races: number,
	runs: number,
	cwrs: number,
	wrCount: number,
	awardCount: number,
}

export type lbUpdateFromFind = {
	kind: string,
	userId: number,
	findCount: number,
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

-- note that these don't have the user on them.
-- thats' because we are typically in a situaiton where we both know the user,
-- this also enables us to have userSettings.lua on the server which just stores them all plus defaults
-- note that this is currently generic on the lua side but on thep ython side it's either a boolean or a string. (maybe more in future?)

export type userSettingValue = {
	codeName: string?,
	name: string,
	domain: string,
	kind: string,
	defaultBooleanValue: boolean?,
	defaultStringValue: string?,
	booleanValue: boolean?,
	stringValue: string?,
}

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

--when reporting (either from server or client)
--also, userId is optional; when sending from client, why not include it!
export type robloxServerError = {
	version: string,
	code: string,
	data: string,
	message: string,
	userId: number?,
}

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

export type ServerEventCreateType = { userId: number }

--used from raceRunner => server consumers who want to know when runs complete.
export type serverFinishRunNotifierType = {
	startSignId: number,
	endSignId: number,
	timeMs: number,
	userId: number,
	username: string,
}

export type serverEventTixAllocation = { userId: number, username: string, tixallocation: number, eventPlace: number }

export type playerProfileData = {}

export type userSignSignRelationship = {
	startSignId: number,
	endSignId: number,
	endSignName: string,
	runCount: number, --user+sig?
	bestPlace: number?,
	bestTimeMs: number,
	dist: number,
	isCwr: boolean,
}

export type relatedRace = { totalRunnerCount: number, signId: number, signName: string }

export type playerSignProfileData = {
	signName: string,
	signId: number,
	relationships: { userSignSignRelationship },
	unrunCwrs: { relatedRace }, --limited selection. This is the signNames followed by parentheticals with the number of times they've been run total
	unrunRaces: { relatedRace }, --EXCLUDES unrunCwrs. like, 'Wilson (10)'
	username: string,
	userId: number, --the SUBJECT userid.
	neverRunSignIds: { number },
}

--local sign clickability - left and right clicks do diff things.
export type signClickMessage = {
	leftClick: boolean,
	signId: number,
	userId: number,
}

--a chip that appears in a row for a placement level, DNP or unrun, for cwr races/noncwr races on sign profiles.
export type signProfileChipType = {
	text: string,
	clicker: TextButton?,
	widthWeight: number?,
	bgcolor: Color3?,
}

export type rowDescriptor = (playerSignProfileData) -> { signProfileChipType }

export type movementHistoryQueueItem = { action: number, time: number }

------------------------ LEADERBOARD ------------------------
export type leaderboardUserDataChange = { key: string, oldValue: number, newValue: number }

-- details on a server initiated server warp request
export type serverWarpRequest = {
	kind: string,
	signId: number?,
	highlightSignId: number?,
	position: Vector3?,
}

--------------- PARTICLES -------------
-- each one has a specific use case, and the other particle aspects to it.
export type particleDescriptor = {
	acceleration: Vector3,
	brightness: number,
	color: ColorSequence | Color3,
	direction: Enum.NormalId,
	drag: number,
	durationMETA: number,
	emissionDirection: Enum.NormalId,
	-- duration: number,
	-- falloff: number,
	lifetime: NumberRange,
	name: string,
	orientation: Enum.ParticleOrientation,
	rate: number,
	rotation: NumberRange,
	rotSpeed: NumberRange,
	shape: Enum.ParticleEmitterShape?,
	-- shapeColor: Color3?,
	shapeInOut: Enum.ParticleEmitterShapeInOut?,
	shapeStyle: Enum.ParticleEmitterShapeStyle?,
	size: NumberSequence,
	speed: NumberRange,
	spreadAngle: Vector2,
	squash: NumberSequence?,
	texture: string?,
	transparency: NumberSequence,
	velocityInheritance: number,
	zOffset: number,
	lightEmission: number,
}

_annotate("end")
return {}
