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

-- equivalent to dcRunResponse:
export type dcRunResponse = {
	thisRunPlace: number,
	runMilliseconds: number,
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

	userRaceRunCount: number,

	-- info on the race or run.
	totalRunsOfThisRaceCount: number,
	totalRacersOfThisRaceCount: number,

	lbUserStats: lbUserStats,

	--relations, must be last to avoid dumb python typing
	runEntries: { runEntry },
	actionResults: { actionResult },
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

export type userFinishedRunOptions = {
	userId: number,
	startSignId: number,
	endSignId: number,
	runMilliseconds: number,
	allPlayerUserIds: string,
}

--in runresult, describe a prior best result.
export type runEntry = {
	kind: string,
	userId: number,
	runMilliseconds: number,
	username: string,
	place: number, --1-10 mean normal. 0 means "insert visually in the order it appears in list"
	virtualPlace: number,
	runAgeSeconds: number, -- Add this new field
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
	pyUserFinishedRunResponse: dcRunResponse?,
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
	myplace: DynamicPlace?, --requesting user's place
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
	data: table, --any table, even a lua table with complex objects.
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
	signname1: string,
	signname2: string,
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

export type JsonUserBooleanSetting = {
	name: string,
	booleanValue: boolean,
	domain: string,
	kind: "boolean",
}

export type JsonUserStringSetting = {
	name: string,
	stringValue: string,
	domain: string,
	kind: "string",
}

export type JsonUserLuaSetting = {
	name: string,
	luaValue: any,
	domain: string,
	kind: "lua",
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

export type JsonUser = {
	username: string,
	userId: number,
}

export type JsonBadgeStatus = {
	hasBadge: boolean,
	badgeName: string,
	userId: number,
	badgeAssetId: number,
	badgeTotalGrantCount: number,
}

export type JsonWr = {
	username: string,
	count: number,
	userId: number,
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

-- when reporting a WR progression, we also throw in the user's fastest run ever. WE display it if it was never a WR.
export type userFastestRun = {
	gameVersion: string,
	hasData: boolean,
	runId: number,
	raceId: number,
	runTime: number,
	runMilliseconds: number,
	userId: number,
	username: string,
	contemporaneousPlace: number,
}

export type raceHistoryData = {
	raceId: number,
	raceCreatedTime: number,
	raceStartName: string,
	raceEndName: string,
	raceStartSignId: number,
	raceEndSignId: number,
	raceRunCount: number,
	raceRunnerCount: number,
	raceLength: number,
	raceFirstRun: JsonRun,
	userRunCount: number,
	firstRunnerUsername: string,
	firstRunnerUserId: number,
	userFastestRun: userFastestRun,
}

export type JsonRun = {
	runMilliseconds: number,
	username: string,
	userId: number,
	place: number,
	runAgeSeconds: number,
}

export type headerDefinition = {
	text: string,
	TextXAlignment: Enum.TextXAlignment,
	width: number,
	order: number,
	isMonospaced: boolean,
}

export type WRProgressionEndpointResponse = {
	wrProgression: { wrProgressionEntry },
	raceHistoryData: raceHistoryData,
	raceExists: boolean,
	headers: { headerDefinition },
	userFastestRunObject: wrProgressionEntry,
}

-- a simple object for adding chips to a row
export type runChip = {
	text: string,
	bgcolor: Color3,
}

export type warpResult = {
	didWarp: boolean,
}

export type lbConfig = {
	position: UDim2,
	size: UDim2,
	minimized: boolean,
	sortDirection: "ascending" | "descending",
	sortColumn: string,
}

return {}
