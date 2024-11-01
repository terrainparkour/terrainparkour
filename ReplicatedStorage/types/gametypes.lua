--!strict

--dumping ground for general response types
--TODO: synchronize this with python return types too!

export type avatarMorphData = {
	scale: number | nil,
	transparency: number | nil,
}

export type clientToServerRemoteEventOrFunction = {
	eventKind: string,
	data: any,
}

export type runEndingDataFromClient = {
	startSignName: string,
	endSignName: string,
	runMilliseconds: number, -- this is the 'actually use' time including penalties so don't rely on it for starting time calculations. re: signs which have penalties, there is only one now (10/2024)
	floorSeenCount: number,
}

export type dcFindResponse = {
	signName: string,
	signId: number,
	userId: number, --the user this find is in relation to.
	userFindCount: number,
	lastFinderUserId: number,
	lastFinderUsername: string,
	foundNew: boolean,
	userFindRank: number,
	signTotalFinds: number,
	totalSignsInGame: number,
	lastFindAgoSeconds: number,
	kind: string, -- the only non-default one in lua side.
}

export type jsonBadgeStatus = {
	userId: number,
	badgeAssetId: number,
	badgeName: string,
	badgeTotalGrantCount: number,
	hasBadge: boolean,
}

export type raceInfo = {
	startSignId: number,
	endSignId: number,
	distance: number,
	raceName: string,
	raceIsCompetitive: boolean,
}

export type userFinishedRunOptions = {
	userId: number,
	startSignId: number,
	endSignId: number,
	runMilliseconds: number,
	allPlayerUserIds: string,
}

-- generally you likely want to use jsonBestRun. But if you are displaying a run the user JUST RAN
-- which may not have actually placed, then you sometimes want this.
export type JsonRun = {
	runId: number,
	username: string,
	userId: number,
	runMilliseconds: number,
	place: number, --0 means didn't end up part of the topX
	mode: number,
	kind: string,
	tied: boolean,
	isRun: boolean,
	yourText: string,
	yourColor: Color3,
	winGap: number?,
	runAgeSeconds: number,
}

-- a bestrun entry, including info which should be linked from the db directly but actually we have to look up the run to get it.
export type jsonBestRun = {
	runMilliseconds: number,
	username: string,
	userId: number,
	place: number,
	runAgeSeconds: number,
	runTime: number,
	raceId: number,
	runId: number,
	hasData: boolean,
	gameVersion: string,
}

export type userRaceStats = {
	userRaceRunCount: number,
	totalRunsOfThisRaceCount: number,
	totalRacersOfThisRaceCount: number,
}

export type userFinishedRunResponse = {
	userId: number,
	username: string,
	raceInfo: raceInfo,
	runUserJustDid: JsonRun?, -- this can be null, for example if we're more generally querying what the top10 for a race is.  We should rename this type though, something like runLeaders.
	raceBestRuns: { jsonBestRun },
	extraBestRuns: { jsonBestRun },
	userRaceStats: userRaceStats,
	lbUserStats: lbUserStats,
	actionResults: { actionResult },
	raceHistoryData: raceHistoryData,
	isMarathon: boolean,
	isFavoriteRace: boolean,
}
-- okay, now updates are just general and cover all possible lb stats.
-- keep doing this til the db dies.
export type lbUserStats = {
	kind: string,
	userId: number,
	username: string,
	userTix: number,
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
	daysInGame: number,
	awardCount: number,
	badgeCount: number,
	serverPatchedInTotalSignCount: number,
	cwrsToday: number,
	wrsToday: number,
	runsToday: number,
	pinnedRace: string,
	userFavoriteRaceCount: number,
}

export type genericLeaderboardUpdateDataType = {
	kind: string,
	lbUserStats: lbUserStats,
	userId: number,
}

export type ephemeralNotificationOptions = {
	userId: number,
	text: string,
	kind: string,
	warpToSignId: number,
	highlightSignId: number?,
}

export type raceDataQuery = {
	userId: number,
	allPlayerUserIds: string,
	startSignId: number,
	endSignId: number,
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

export type getNonTop10RacesByUser = {
	kind: string,
	userId: number,
	raceDescriptions: { string },
}

export type badgeDescriptor = {
	name: string,
	assetId: number,
	badgeClass: string,
	baseNumber: number?,
	hint: string?,
	order: number?,
}

export type badgeProgress = {
	badge: badgeDescriptor,
	got: boolean,
	progress: number?, -- some badges don't have progress since they have baseNumber.
	baseNumber: number?,
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
	kind: string, -- either a boolean or a string
	defaultBooleanValue: boolean?,
	defaultStringValue: string | nil,
	defaultLuaValue: any | nil,
	booleanValue: boolean | nil,
	stringValue: string | nil,
	luaValue: any | nil, --which will be stringified and then stored remote, then unstringified (restoring lua classes, etc) before being served out again.
	editorName: string | nil, --if this is present, do not show it in the default UI unless you opt in.
	-- for example, pinnedRace can only store specific data types so you can't just use the default boolean editor
	-- on it.
}

export type userSettingValuesWithDistributions = {
	name: string,
	domain: string,
	value: boolean?,
	percentage: number,
}

--for the left side of a sign popup.
export type signWrStatus = {
	userId: number,
	count: number,
}

--for big ordered lists coming from server
export type userRankedOrderItem = {
	userId: number,
	username: string,
	rank: number,
	count: number,
}

-- the generic version of this, which also contains a string description, for example for displaying top long runs of the day.
-- export type genericRankedOrderItem = { userId: number, username: string, desc: string, rank: number, count: number }

export type missingRunRequestParams = {
	userId: number,
	kind: string,
	signId: number,
}

export type userAward = {
	userId: number,
	contestName: string,
	awardName: string,
}

-- on the wire from python backend types
export type DynamicPlace = {
	place: number,
	username: string,
	userId: number,
	timeMs: number,
}

--contextual summary data for this user, current run, and this target.
--later: add myfound too, so we can green highlight target more easily.
export type DynamicRunFrame = {
	targetSignId: number,
	targetSignName: string,
	places: { DynamicPlace },
	myPriorPlace: DynamicPlace, --requesting user's place
	myfound: boolean,
}

export type dynamicRunFromData = {
	kind: string,
	fromSignName: string,
	frames: { DynamicRunFrame },
}

--for dynamic running event communication localscript to server
export type dynamicRunningControlType = {
	action: string,
	fromSignId: number,
	userId: number,
}

--SERVEREVENTS
export type runningServerEventUserBest = {
	userId: number,
	username: string,
	timeMs: number,
	runCount: number,
}

--when reporting (either from server or client)
--also, userId is optional; when sending from client, why not include it!
export type robloxServerError = {
	version: string,
	code: string,
	data: any,
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

export type serverEventTixAllocation = {
	userId: number,
	username: string,
	tixallocation: number,
	eventPlace: number,
}

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
	hasFoundFirstSign: boolean,
}

export type relatedRace = {
	totalRunnerCount: number,
	signId: number,
	signName: string,
	hasFoundSign: boolean,
}

export type playerSignProfileData = {
	signName: string,
	signId: number,
	relationships: { userSignSignRelationship },
	unrunCwrs: { relatedRace }, --limited selection. This is the signNames followed by parentheticals with the number of times they've been run total
	unrunRaces: { relatedRace }, --EXCLUDES unrunCwrs. like, 'Wilson (10)'
	-- globalUnrunRaces: { relatedRace }, -- races which nobody has ever run --this overlaps with neverRunSignIds.
	-- TODO actually we should really combine this with related race. that is, there doesn't need to be two types here.
	-- just one type scoped to: user, source signId and every single one is like: targetSignId, place, anyone has ever run, isCwr, cause the code that progressively prepares the data here is too multilayer.
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

export type movementHistoryQueueItem = {
	action: number,
	time: number,
}

------------------------ LEADERBOARD ------------------------
export type leaderboardUserDataChange = {
	key: string,
	oldValue: number | string,
	newValue: number | string,
	userId: number,
}

-- details on a server initiated server warp request
export type serverWarpRequest = {
	kind: string,
	signId: number?,
	highlightSignId: number?,
	position: Vector3 | nil,
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

-- when parsing X-Y
export type RaceParseResult = {
	signId1: number,
	signId2: number,
	signName1: string,
	signName2: string,
	error: string, -- if non"" then it's an error.
}

export type setSettingResponse = { res: boolean, error: string }

export type channelDefinition = {
	Name: string,
	AutoJoin: boolean,
	WelcomeMessage: string,
	adminFunc: any,
	noTalkingInChannel: boolean,
}

-- the UI for the configuration object of a runSGui
export type currentRunUIConfiguration = {
	showDistance: boolean,
	size: UDim2,
	position: UDim2,
	digitsInTime: number,
	transparency: number,
}

export type postRequest = {
	remoteActionName: string,
	data: any,
}

-- to make UGS signs work better.
export type SpecialSignInterface = {
	InformRunEnded: () -> (),
	InformRunStarting: () -> (),
	InformRetouch: (() -> ())?,
	InformSawFloorDuringRunFrom: (floorMaterial: Enum.Material) -> (),
	CanRunEnd: () -> runEndExtraDataForRacing,
	GetName: () -> string,
}

-- racing module will consult the active special sign and do what it says based on this info transfer system.
export type runEndExtraDataForRacing = {
	canRunEndNow: boolean,
	extraTimeS: number?, -- extra time to add to the end of the run
}

--------- These are for future use. They're the luau versions of the python serializers. ----------------

export type JsonUserAward = {
	contestName: string,
	userId: number,
	awardName: string,
}

export type JsonRace = {
	id: number,
	name: string,
	runcount: number,
	distance: number,
}

export type JsonMarathonRun = {
	runMilliseconds: number,
	username: string,
	userId: number,
	place: number,
}

export type JsonMarathonKindRun = {
	runMilliseconds: number,
	username: string,
	userId: number,
	place: number,
}

export type JsonBadgeStatus = {
	hasBadge: boolean,
	badgeName: string,
	userId: number,
	badgeAssetId: number,
	badgeTotalGrantCount: number,
}

export type JsonEvent = {
	id: number,
	start: string,
	["end"]: string,
	badgeAssetId: number,
	badgeId: string | number,
	badgeName: string,
	startsignId: number,
	endsignId: number,
	startSignName: string,
	endSignName: string,
	distance: number,
	name: string,
	ephemeral: boolean,
	eventDescription: string,
}

export type wrProgressionEntry = {
	gameVersion: string,
	hasData: boolean,
	runId: number,
	improvementMs: number, -- '-1' means skip/no improvement
	raceId: number,
	runTime: number,
	runMilliseconds: number,
	userId: number,
	username: string,
	recordStood: number,
}

-- metadta about a race, not including best run info.
export type raceHistoryData = {
	raceId: number,
	raceCreatedTime: number,
	raceStartName: string,
	raceStartSignId: number,
	raceEndName: string,
	raceEndSignId: number,
	raceRunCount: number,
	raceRunnerCount: number,
	raceLength: number,
	raceIsCompetitive: boolean,
	raceFirstRun: JsonRun?,
	firstRunnerUsername: string?,
	firstRunnerUserId: number?,
}

export type userRaceInfo = {
	userRunCount: number,
	userFastestRun: jsonBestRun?,
}

export type WRProgressionEndpointResponse = {
	wrProgression: { wrProgressionEntry },
	raceHistoryData: raceHistoryData,
	raceExists: boolean,
	userRaceInfo: userRaceInfo,
}

-- a simple object for adding chips to a row
export type runChip = {
	text: string,
	bgcolor: Color3,
}

export type warpResult = {
	didWarp: boolean,
	reason: string,
}

export type lbConfig = {
	position: UDim2,
	size: UDim2,
	minimized: boolean,
	sortDirection: "ascending" | "descending",
	sortColumn: string,
}

export type JsonUserFavoriteRace = {
	raceId: number,
	raceName: string,
	startSignId: number,
	endSignId: number,
	userId: number,
	username: string,
	favoriteTime: number,
	userTimesAndPlaces: { simpleJsonRun },
	-- depending, we just throw in a bunch of user times and places so that
	-- you can show them in the UI
}

-- probably should just get this globally? or use a shared object which already exists? but this is so simple...
export type simpleJsonRun = {
	raceName: string,
	userId: number,
	username: string,
	runMilliseconds: number,
	place: number,
}

-- we don't just want to list the favorites if you query about someonee else, we also want to know your best runs too.
export type serverFavoriteRacesResponse = {
	targetUserId: number,
	requestingUserId: number,
	otherUserIds: { number },
	racesAndInfo: { { theRace: JsonUserFavoriteRace, theResults: { simpleJsonRun } } },
}

export type interleavedResult = {
	priorTimeMs: number, -- 0 if no prior run
	newTimeMs: number,
	priorPlace: number, -- 0 if no prior run
	newPlace: number, -- if this is >1 then we definitely improved time. so really, this means whether the run is included in the new topX
	newRun: boolean, -- for this user
	newRace: boolean, -- for anyone, nobody has run this race ever.
	missedNextPlaceByMs: number, --how many ms faster you'd have to be to have the next place (if not already 1st. logically takes into account self-ties etc.)
	beatNextPlaceByMs: number, --if you improvedPlace, how much did you improve by? self-tie places which improve time must be zero here.
	missedImprovementByMs: number, --how many ms slower you'd have to be to have not improved.  this is distinguished from missedNextPlaceByMs because this is about raw ms improvement including place self-ties which can still be improved.
}

return {}
