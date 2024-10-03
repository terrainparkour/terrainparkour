--!strict

--excluded from source control

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local tt = require(game.ReplicatedStorage.types.gametypes)

-- Create an enum for badge classes
local badgeClasses: { [string]: string } = {
	RACE_RUNNER = "race runner",
	RACE_RUNS = "race runs",
	PLAY = "play",
	GRINDING = "grinding",
	WEIRD = "weird",
	FINDS = "finds",
	TIME = "time",
	LONG_RUN = "long run",
	ELITE = "elite",
	CWRS = "cwrs",
	CWRTOP10S = "cwrTop10s",
	TIX = "tix",
	SIGN_WRS = "sign wrs",
	MARATHON = "marathon",
	TOP10S = "top10s",
	WRS = "wrs",
	RACES = "races",
	RUNS = "runs",
	SERVER_EVENTS = "server events",
	SPECIAL_SIGN = "special sign",
	SPECIAL = "special",
	META = "meta",
	CONTRIBUTION = "contribution",
}

local badges: { [string]: tt.badgeDescriptor } = {
	RaceRunner10 = { name = "Race Runner 10", assetId = 2125857719, badgeClass = badgeClasses.RACE_RUNNER, order = 10 },
	RaceRunner40 = { name = "Race Runner 40", assetId = 2125857721, badgeClass = badgeClasses.RACE_RUNNER, order = 40 },
	RaceRunner100 = {
		name = "Race Runner 100",
		assetId = 2126074526,
		badgeClass = badgeClasses.RACE_RUNNER,
		order = 100,
	},
	RaceRunner200 = {
		name = "Race Runner 200",
		assetId = 2126074528,
		badgeClass = badgeClasses.RACE_RUNNER,
		order = 200,
	},
	RaceRunner500 = {
		name = "Race Runner 500",
		assetId = 2126074529,
		badgeClass = badgeClasses.RACE_RUNNER,
		order = 500,
	},
	RaceRunner1000 = {
		name = "Race Runner 1000",
		assetId = 2126074530,
		badgeClass = badgeClasses.RACE_RUNNER,
		order = 1000,
	},
	RaceRunner2000 = {
		name = "Race Runner 2000",
		assetId = 2126074531,
		badgeClass = badgeClasses.RACE_RUNNER,
		order = 2000,
	},

	RaceRuns10 = { name = "Race Runs 10", assetId = 2126075950, badgeClass = badgeClasses.RACE_RUNS, order = 10 },
	RaceRuns40 = { name = "Race Runs 40", assetId = 2125857724, badgeClass = badgeClasses.RACE_RUNS, order = 40 },
	RaceRuns100 = { name = "Race Runs 100", assetId = 2126075994, badgeClass = badgeClasses.RACE_RUNS, order = 100 },
	RaceRuns200 = { name = "Race Runs 200", assetId = 2126075990, badgeClass = badgeClasses.RACE_RUNS, order = 200 },
	RaceRuns500 = { name = "Race Runs 500", assetId = 2126075996, badgeClass = badgeClasses.RACE_RUNS, order = 500 },
	RaceRuns1000 = { name = "Race Runs 1000", assetId = 2126158368, badgeClass = badgeClasses.RACE_RUNS, order = 1000 },
	RaceRuns2000 = { name = "Race Runs 2000", assetId = 2126158369, badgeClass = badgeClasses.RACE_RUNS, order = 2000 },

	DethroneCreator = { name = "Dethrone Creator", assetId = 2126338119, badgeClass = badgeClasses.PLAY },

	PushDownCreator = { name = "Push Down Creator", assetId = 2126338122, badgeClass = badgeClasses.PLAY },
	KnockedOutCreator = { name = "Knocked Out Creator", assetId = 2126338123, badgeClass = badgeClasses.PLAY },
	KnockedSomeoneOut = { name = "Knocked Someone Out", assetId = 2126338125, badgeClass = badgeClasses.PLAY },

	RepeatRun = { name = "Pete and Repeat", assetId = 2125501802, badgeClass = badgeClasses.GRINDING },
	SpecializeRun = { name = "Specializing Runner", assetId = 2125501804, badgeClass = badgeClasses.GRINDING },
	GrindRun = { name = "Grinder", assetId = 2125501805, badgeClass = badgeClasses.GRINDING },
	GuruRun = {
		name = "Run Guru",
		assetId = 2125647283,
		badgeClass = badgeClasses.GRINDING,
		hint = "Be like Henry Sugar.",
	},
	FocusRun = { name = "Focus Run", assetId = 2125501815, badgeClass = badgeClasses.GRINDING },
	CrazyRun = { name = "Crazy Runner", assetId = 2125501810, badgeClass = badgeClasses.GRINDING },
	IronMan = {
		name = "Iron Man Runner",
		assetId = 2125470138,
		badgeClass = badgeClasses.GRINDING,
		hint = "Only a mad lad would run this long, so many times",
	},
	Triathlon = {
		name = "Triathlon",
		assetId = 2125647287,
		badgeClass = badgeClasses.GRINDING,
	},
	Poggod = {
		name = "Found POGGOD!",
		assetId = 2124935169,
		badgeClass = badgeClasses.WEIRD,
		hint = "You always knew you were special",
	},
	Chomik = { name = "Chomik", assetId = 2125445524, badgeClass = badgeClasses.WEIRD, hint = "Find me: /chomik" },
	Hurdle = { name = "Run the hurdles!", assetId = 2142445246, badgeClass = badgeClasses.WEIRD },
	TerrainObby = {
		name = "Terrain Obby",
		assetId = 2125786190,
		badgeClass = badgeClasses.WEIRD,
		hint = "Find the Obbys",
	},
	FirstEmpire = {
		name = "First Empire",
		assetId = 2126158377,
		badgeClass = badgeClasses.WEIRD,
		hint = "He crowned himself",
	},
	TrainParkour = {
		name = "TrainParkour",
		assetId = 2126162027,
		badgeClass = badgeClasses.WEIRD,
		hint = "Terrain Parklore",
	},
	CrowdedHouse = {
		name = "Crowded House",
		assetId = 2126471608,
		badgeClass = badgeClasses.SERVER_EVENTS,
		hint = "You can't do it alone",
	},
	AncientHouse = {
		name = "Ancient House",
		assetId = 2126639210,
		badgeClass = badgeClasses.SERVER_EVENTS,
		hint = "time",
	},
	ThisOldHouse = {
		name = "This Old House",
		assetId = 2126491241,
		badgeClass = badgeClasses.SERVER_EVENTS,
		hint = "time",
	},
	MegaHouse = {
		name = "Mega House",
		assetId = 2126491228,
		badgeClass = badgeClasses.SERVER_EVENTS,
		hint = "You really can't do it alone",
	},
	GoldContest = {
		name = "Gold Contest Winner",
		assetId = 2126471605,
		badgeClass = badgeClasses.SPECIAL,
		hint = "Won a special contest! Congratulations to you. This is also worth 1111 tix.",
		order = 2,
	},
	SilverContest = {
		name = "Silver Contest Winner",
		assetId = 2126471601,
		badgeClass = badgeClasses.SPECIAL,
		hint = "got 2nd prize in one of the weekly contests. Also worth 555 tix.",
		order = 1,
	},
	SignOriginLoreResearcher = {
		name = "Sign Origin Lore Researcher",
		assetId = 2129066972,
		badgeClass = badgeClasses.SPECIAL,
		hint = "Delving into sign lore",
	},
	BronzeContest = {
		name = "Bronze Contest Winner",
		assetId = 2126471599,
		badgeClass = badgeClasses.SPECIAL,
		hint = "got 3rd prize in one of the weekly contests. Also worth 333 tix.",
		order = 0,
	},
	FirstContestParticipation = {
		name = "First Contest Participation",
		assetId = 2126471603,
		badgeClass = badgeClasses.SPECIAL,
		hint = "Participated in the first contest, May 21 2022. Worth 111 tix.",
		order = 5,
	},
	SecondContestParticipation = {
		name = "Second Contest Participation",
		assetId = 2126713768,
		badgeClass = badgeClasses.SPECIAL,
		hint = "Participated in the Second contest, June 11 2022. Worth 111 tix.",
		order = 6,
	},

	--participated in any contest by completing all runs
	ContestParticipation = {
		name = "Contest Participation",
		assetId = 2126491230,
		badgeClass = badgeClasses.SPECIAL,
		hint = "Participated in an contest. Worth 111 tix.",
		order = 7,
	},

	--be in the "best" slot for a contest
	LeadContest = {
		name = "Has led a running contest",
		assetId = 2126491237,
		badgeClass = badgeClasses.SPECIAL,
		hint = "Participated in an contest. Worth 111 tix.",
		order = 9,
	},
	Hieroglyph = {
		name = "Hieroglyph",
		assetId = 2126491233,
		badgeClass = badgeClasses.WEIRD,
	},
	Arrow = {
		name = "Arrow",
		assetId = 1078508107638959,
		badgeClass = badgeClasses.WEIRD,
	},
	ScottishNoah = {
		name = "Scottish Noah",
		assetId = 2125857717,
		badgeClass = badgeClasses.WEIRD,
	},
	LandscapeAcrobatics = {
		name = "Landscape Acrobatics",
		assetId = 2126801968,
		badgeClass = badgeClasses.WEIRD,
	},
	Royalty = {
		name = "Royalty",
		assetId = 2126743612,
		badgeClass = badgeClasses.WEIRD,
	},
	Orthography = {
		name = "Orthography",
		assetId = 2126338129,
		badgeClass = badgeClasses.WEIRD,
		hint = "Run between any two SPECIAL signs.",
	},
	RobloxStudio = {
		name = "Roblox Studio",
		assetId = 2126338127,
		badgeClass = badgeClasses.WEIRD,
	},
	Unicode = {
		name = "Unicode",
		assetId = 2126158374,
		badgeClass = badgeClasses.WEIRD,
		hint = "Run between the first two unicode signs.",
	},
	MaxFind = {
		name = "Max Finds",
		assetId = 2125786178,
		badgeClass = badgeClasses.FINDS,
		hint = "Have found all signs.",
	},
	HalfFind = {
		name = "Half Find",
		assetId = 2125786184,
		badgeClass = badgeClasses.FINDS,
		hint = "have found half of all available signs.",
	},
	UnoFind = {
		name = "UnoFind",
		assetId = 2125786187,
		badgeClass = badgeClasses.FINDS,
		hint = "have found all but one signs.",
	},
	FindLeader = {
		name = "Find Leader",
		assetId = 2125786189,
		badgeClass = badgeClasses.FINDS,
		hint = "have the most finds of anybody.",
	},
	PiDayRun = {
		name = "Pie Run",
		assetId = 2142445256,
		badgeClass = badgeClasses.TIME,
		hint = "Loops",
	},
	SuperLow = {
		name = "Super Low",
		assetId = 2142445252,
		badgeClass = badgeClasses.SPECIAL_SIGN,
	},
	YearRun = {
		name = "Year Run",
		assetId = 2125812044,
		badgeClass = badgeClasses.TIME,
		hint = "How long is a year?",
	},

	YearRunMilliseconds = {
		name = "Year Milliseconds Run",
		assetId = 2142445262,
		badgeClass = badgeClasses.TIME,
		hint = "How long is a year in milliseconds?",
	},
	LunaFecha = {
		name = "Luna Fecha",
		assetId = 2126239398,
		badgeClass = badgeClasses.TIME,
		hint = "Concordance of day and month",
	},
	TripleContemporaneous = {
		name = "Triple Contemporaneous",
		assetId = 2129122989,
		badgeClass = badgeClasses.TIME,
		hint = "Ternary Identity",
	},
	Midnight = {
		name = "Midnight",
		assetId = 2125812045,
		badgeClass = badgeClasses.TIME,
		hint = "Dangerous to be alone at midnight",
	},

	FiftyNine = {
		name = "Fifty Nine",
		assetId = 2126239392,
		badgeClass = badgeClasses.TIME,
	},
	SpecialTime = {
		name = "Run at a Special Time",
		assetId = 2126239389,
		badgeClass = badgeClasses.TIME,
		hint = "Some things make you do a double take",
	},
	Minute = {
		name = "Minute",
		assetId = 2126239384,
		badgeClass = badgeClasses.TIME,
	},
	TimeAndSpace = {
		name = "Time and Space",
		assetId = 2125579606,
		badgeClass = badgeClasses.TIME,
		hint = "Matter, distance, time, energy - all forms of the same thing.",
	},
	TimeAndSpaceLargeScale = {
		name = "Time and Space Large Scale Equality",
		assetId = 2125579605,
		badgeClass = badgeClasses.TIME,
		hint = "And everybody was finally equal.",
	},
	SciFiRun = {
		name = "Science Fiction Run!",
		assetId = 2125445664,
		badgeClass = badgeClasses.WEIRD,
		hint = "This mission is too important for me to allow you to jeopardize it.",
	},
	SuperSlowRun = { name = "Super Slow Run!", assetId = 2125445673, badgeClass = badgeClasses.WEIRD },
	LongFall = { name = "Long Fall!", assetId = 2125445695, badgeClass = badgeClasses.LONG_RUN, order = 10 },
	LongClimb = { name = "Long Climb!", assetId = 2125445694, badgeClass = badgeClasses.LONG_RUN, order = 20 },
	LongRun = { name = "Long Run!", assetId = 2125445527, badgeClass = badgeClasses.LONG_RUN, order = 30 },
	VeryLongRun = { name = "Very Long Run!", assetId = 2125445674, badgeClass = badgeClasses.LONG_RUN, order = 40 },
	HyperLongRun = {
		name = "Hyper Long Run!",
		assetId = 2125445676,
		badgeClass = badgeClasses.LONG_RUN,
		hint = "definitely unpossible",
		order = 50,
	},
	MegaLongRun = {
		name = "Mega Long Run!",
		assetId = 2125445690,
		badgeClass = badgeClasses.LONG_RUN,
		hint = "possible-ish",
		order = 80,
	},
	ExtremeLongRun = {
		name = "Extreme Long Run!",
		assetId = 2125445691,
		badgeClass = badgeClasses.LONG_RUN,
		hint = "Not possible, never possible",
		order = 100,
	},
	CompetitiveLongRun = {
		name = "Run Competitive Long Run!",
		assetId = 2125445668,
		badgeClass = badgeClasses.LONG_RUN,
		order = 105,
	},
	WinCompetitiveLongRun = {
		name = "Win Competitive Long Run!",
		assetId = 2125445670,
		badgeClass = badgeClasses.LONG_RUN,
		order = 110,
	},
	Run333 = {
		name = "Do a .333 run!",
		assetId = 2125647289,
		badgeClass = badgeClasses.TIME,
		hint = "because you asked",
		order = 10,
	},
	Run555 = { name = "Do a .555 run!", assetId = 2124922253, badgeClass = badgeClasses.TIME, order = 20 },
	Run777 = { name = "Do a .777 run!", assetId = 2124922252, badgeClass = badgeClasses.TIME, order = 30 },
	Run999 = { name = "Do a .999 run!", assetId = 2125445692, badgeClass = badgeClasses.TIME, order = 40 },
	CountVonCount = {
		name = "Count Von Count",
		assetId = 2126075995,
		badgeClass = badgeClasses.TIME,
		hint = "Ah-Ah-Ah!",
	},

	RoundRun = { name = "Do a round run!", assetId = 2124922251, badgeClass = badgeClasses.WEIRD },
	LoseBy001 = { name = "Lose by 0.001s!", assetId = 2124935509, badgeClass = badgeClasses.WEIRD },
	WinBy001 = { name = "Win by 0.001s!", assetId = 2124922216, badgeClass = badgeClasses.WEIRD },
	TieForFirst = { name = "Tie For First! Sorry!", assetId = 2124922217, badgeClass = badgeClasses.WEIRD },
	WinstonSmith = { name = "Winston S####", assetId = 2126158371, badgeClass = badgeClasses.WEIRD },

	CmdLine = { name = "Used Cmd Line!", assetId = 872955307, badgeClass = badgeClasses.META, hint = "true power." },
	Secret = {
		name = "Secret!",
		assetId = 872952358,
		badgeClass = badgeClasses.META,
		hint = "can you command the secret?",
	},
	UndocumentedCommand = {
		name = "Undocumented Command",
		assetId = 2126239401,
		badgeClass = badgeClasses.META,
		hint = "Hacker!",
	},
	MetCreator = { name = "Met the Creator", assetId = 872951054, badgeClass = badgeClasses.META },
	Friendship = { name = "Friendship", assetId = 179125274571469, badgeClass = badgeClasses.META },
	BadgeFor100Badges = { name = "Got 100 Badges", assetId = 2126075986, badgeClass = badgeClasses.META },
	BumpedCreator = {
		name = "Bumped into the Creator!",
		assetId = 872962949,
		badgeClass = badgeClasses.META,
		hint = "not working. hmm.",
	},

	EliteRun = {
		name = "Elite Run!",
		assetId = 2125445666,
		badgeClass = badgeClasses.ELITE,
		hint = "are you 1337 enough?",
		order = 10,
	},
	DoubleEliteRun = { name = "Double Elite Run!", assetId = 2129122990, badgeClass = badgeClasses.ELITE, order = 20 },
	WinEliteRun = { name = "Win Elite Run!", assetId = 2125445675, badgeClass = badgeClasses.ELITE, order = 30 },

	WinCompetitiveRun = {
		name = "Win Competitive Run!",
		assetId = 2125445672,
		badgeClass = badgeClasses.CWRS,
		hint = "A sign which has at least 10 runners.",
		order = 20,
	},

	ThreeHundredTix = {
		name = "Earned 300 Tix!",
		assetId = 2125246193,
		badgeClass = badgeClasses.TIX,
		baseNumber = 300,
	},
	ThousandTix = { name = "Earned 1000 Tix!", assetId = 2124922226, badgeClass = badgeClasses.TIX, baseNumber = 1000 },
	ThreeThousandTix = {
		name = "Earned 3000 Tix!",
		assetId = 2125246197,
		badgeClass = badgeClasses.TIX,
		baseNumber = 3000,
	},
	SevenThousandTix = {
		name = "Earned 7000 Tix!",
		assetId = 2125246199,
		badgeClass = badgeClasses.TIX,
		baseNumber = 7000,
	},
	Tix14k = { name = "Earned 14000 Tix!", assetId = 2125812043, badgeClass = badgeClasses.TIX, baseNumber = 14000 },
	Tix25k = { name = "Earned 25000 Tix!", assetId = 2125812049, badgeClass = badgeClasses.TIX, baseNumber = 25000 },
	Tix49k = { name = "Earned 49000 Tix!", assetId = 2125812050, badgeClass = badgeClasses.TIX, baseNumber = 49000 },
	Tix99k = { name = "Earned 99999 Tix!", assetId = 2129122995, badgeClass = badgeClasses.TIX, baseNumber = 99999 },

	NewRace = { name = "Found Race!", assetId = 872951314, badgeClass = badgeClasses.PLAY },
	LeadSign = { name = "Lead a sign!", assetId = 2124940185, badgeClass = badgeClasses.PLAY },
	LeadCompetitiveSign = { name = "Lead a competitive sign!", assetId = 2124940186, badgeClass = badgeClasses.PLAY },

	LeadCompetitiveRace = {
		name = "Lead a competitive race!",
		assetId = 2128372871,
		badgeClass = badgeClasses.CWRS,
		baseNumber = 1,
	},
	Lead10CompetitiveRace = {
		name = "Lead 10 competitive races!",
		assetId = 2128372874,
		badgeClass = badgeClasses.CWRS,
		baseNumber = 10,
	},
	Lead50CompetitiveRace = {
		name = "Lead 50 competitive races!",
		assetId = 2128372867,
		badgeClass = badgeClasses.CWRS,
		baseNumber = 50,
	},
	Lead250CompetitiveRace = {
		name = "Lead 250 competitive races!",
		assetId = 2128372866,
		badgeClass = badgeClasses.CWRS,
		baseNumber = 250,
	},
	Lead1000CompetitiveRace = {
		name = "Lead 1000 competitive races!",
		assetId = 2126743610,
		badgeClass = badgeClasses.CWRS,
		baseNumber = 1000,
	},

	SignWrs5 = { name = "5 sign WRs!", assetId = 2124940187, badgeClass = badgeClasses.SIGN_WRS, order = 1 },
	SignWrs10 = { name = "10 sign WRs!", assetId = 2124940188, badgeClass = badgeClasses.SIGN_WRS, order = 20 },
	SignWrs20 = { name = "20 sign WRs!", assetId = 2124940189, badgeClass = badgeClasses.SIGN_WRS, order = 30 },
	SignWrs50 = { name = "50 sign WRs!", assetId = 2124940190, badgeClass = badgeClasses.SIGN_WRS, order = 40 },
	SignWrs100 = { name = "100 sign WRs!", assetId = 2124940191, badgeClass = badgeClasses.SIGN_WRS, order = 50 },
	SignWrs200 = { name = "200 sign WRs!", assetId = 2124940192, badgeClass = badgeClasses.SIGN_WRS, order = 60 },
	SignWrs300 = { name = "300 sign WRs!", assetId = 2124940193, badgeClass = badgeClasses.SIGN_WRS, order = 70 },
	SignWrs500 = { name = "500 sign WRs!", assetId = 2124940194, badgeClass = badgeClasses.SIGN_WRS, order = 80 },
	SignWrsFeo = { name = "Feo sign WRs!", assetId = 2124940497, badgeClass = badgeClasses.SIGN_WRS, order = 90 },
	SignWrs800 = { name = "800 sign WRs!", assetId = 2125857715, badgeClass = badgeClasses.SIGN_WRS, order = 100 },
	SignWrs900 = { name = "900 sign WRs!", assetId = 2129066975, badgeClass = badgeClasses.SIGN_WRS, order = 110 },
	SignWrs1000 = {
		name = "1000 sign WRs! Hyper memorial",
		assetId = 2129037605,
		badgeClass = badgeClasses.SIGN_WRS,
		order = 120,
	},
	SignWrs1200 = { name = "1200 sign WRs!", assetId = 2129066971, badgeClass = badgeClasses.SIGN_WRS, order = 130 },
	SignWrs1500 = { name = "1500 sign WRs!", assetId = 2129066970, badgeClass = badgeClasses.SIGN_WRS, order = 140 },
	Olympics = { name = "Olympics!", assetId = 2128933898, badgeClass = badgeClasses.WEIRD },

	MarathonCompletionAlphaLetters = {
		name = "Complete Alpha all letter Marathon!",
		assetId = 2125027162,
		badgeClass = badgeClasses.MARATHON,
	},
	MarathonCompletionAlphaReverse = {
		name = "Complete Alpha reverse Marathon!",
		assetId = 2125027166,
		badgeClass = badgeClasses.MARATHON,
	},
	MarathonCompletionAlphaOrdered = {
		name = "Complete Alpha fixed Marathon!",
		assetId = 2125027171,
		badgeClass = badgeClasses.MARATHON,
	},
	MarathonCompletionAlphaFree = {
		name = "Complete Alpha free order Marathon!",
		assetId = 2125027175,
		badgeClass = badgeClasses.MARATHON,
	},
	MarathonCompletionFindEveryLength = {
		name = "Complete Find signs by length Marathon!",
		assetId = 2125501806,
		badgeClass = badgeClasses.MARATHON,
	},
	MarathonCompletionEvolution = {
		name = "Complete Evolution Marathon!",
		assetId = 2125579602,
		badgeClass = badgeClasses.MARATHON,
	},
	MarathonCompletionLegacy = {
		name = "Complete Legacy Marathon!",
		assetId = 2125647286,
		badgeClass = badgeClasses.MARATHON,
	},
	MarathonCompletionCave = {
		name = "Complete Cave Marathon!",
		assetId = 2125579603,
		badgeClass = badgeClasses.MARATHON,
	},
	MarathonCompletionThreeLetter = {
		name = "Complete Three Letter Marathon!",
		assetId = 2129133096,
		badgeClass = badgeClasses.MARATHON,
	},
	MarathonCompletionAOfB = {
		name = "Complete AOfB Marathon!",
		assetId = 2125579604,
		badgeClass = badgeClasses.MARATHON,
	},
	MarathonCompletionSingleLetter = {
		name = "Complete Single Letter Marathon!",
		assetId = 2125647282,
		badgeClass = badgeClasses.MARATHON,
	},
	MarathonCompletionFind10 = {
		name = "Complete Find 10 sign Marathon!",
		assetId = 2125027207,
		badgeClass = badgeClasses.MARATHON,
		order = 10,
	},
	MarathonCompletionFind20 = {
		name = "Complete Find 20 sign Marathon!",
		assetId = 2125027201,
		badgeClass = badgeClasses.MARATHON,
		order = 20,
	},
	MarathonCompletionFind40 = {
		name = "Complete Find 40 sign Marathon!",
		assetId = 2125027198,
		badgeClass = badgeClasses.MARATHON,
		order = 40,
	},
	MarathonCompletionFind100 = {
		name = "Complete Find 100 sign Marathon!",
		assetId = 2125027190,
		badgeClass = badgeClasses.MARATHON,
		order = 100,
	},
	MarathonCompletionFind200 = {
		name = "Complete Find 200 sign Marathon!",
		assetId = 2125027186,
		badgeClass = badgeClasses.MARATHON,
		order = 200,
	},
	MarathonCompletionFind300 = {
		name = "Complete Find 300 sign Marathon!",
		assetId = 2125501812,
		badgeClass = badgeClasses.MARATHON,
		order = 300,
	},
	MarathonCompletionFind380 = {
		name = "Complete Find 380 sign Marathon!",
		assetId = 2125501813,
		badgeClass = badgeClasses.MARATHON,
		order = 380,
	},
	MarathonCompletionFind500 = {
		name = "Complete Find 500 sign Marathon!",
		assetId = 2129122996,
		badgeClass = badgeClasses.MARATHON,
		order = 500,
	},
	MarathonCompletionFind10T = {
		name = "Complete Find 10 T* Marathon!",
		assetId = 2125027178,
		badgeClass = badgeClasses.MARATHON,
		order = 1000,
	},
	MarathonCompletionFind10S = {
		name = "Complete Find 10 S* Marathon!",
		assetId = 2125027183,
		badgeClass = badgeClasses.MARATHON,
		order = 1010,
	},
	MarathonCompletionExactly40 = {
		name = "Complete Exactly 40 Marathon!",
		assetId = 2125579608,
		badgeClass = badgeClasses.MARATHON,
		order = 1040,
	},
	MarathonCompletionExactly100 = {
		name = "Complete Exactly 100 Marathon!",
		assetId = 2125579610,
		badgeClass = badgeClasses.MARATHON,
		order = 1100,
	},
	MarathonCompletionExactly200 = {
		name = "Complete Exactly 200 Marathon!",
		assetId = 2125579611,
		badgeClass = badgeClasses.MARATHON,
		order = 1100,
	},
	MarathonCompletionExactly500 = {
		name = "Complete Exactly 500 Marathon!",
		assetId = 2125579613,
		badgeClass = badgeClasses.MARATHON,
		order = 1500,
	},
	MarathonCompletionExactly1000 = {
		name = "Complete Exactly 1000 Marathon!",
		assetId = 2125579614,
		badgeClass = badgeClasses.MARATHON,
		order = 2000,
	},

	FoundThree = { name = "Found Three Signs!", assetId = 872955550, badgeClass = badgeClasses.FINDS, baseNumber = 3 },
	FoundNine = { name = "Found Nine Signs!", assetId = 872955722, badgeClass = badgeClasses.FINDS, baseNumber = 9 },
	FoundEighteen = {
		name = "Found Eighteen Signs!",
		assetId = 872961733,
		badgeClass = badgeClasses.FINDS,
		baseNumber = 18,
	},
	FoundTwentySeven = {
		name = "Found Twenty-seven!",
		assetId = 872955855,
		badgeClass = badgeClasses.FINDS,
		baseNumber = 27,
	},
	FoundThirtySix = {
		name = "Found Thirty-six Signs!",
		assetId = 872956177,
		badgeClass = badgeClasses.FINDS,
		baseNumber = 36,
	},
	FoundFifty = { name = "Found Fifty Signs!", assetId = 872962526, badgeClass = badgeClasses.FINDS, baseNumber = 50 },
	FoundSeventy = {
		name = "Found Seventy Signs!",
		assetId = 872956331,
		badgeClass = badgeClasses.FINDS,
		baseNumber = 70,
	},
	FoundNinetyNine = {
		name = "Found 99 Signs!",
		assetId = 872956479,
		badgeClass = badgeClasses.FINDS,
		baseNumber = 99,
	},
	FoundHundredTwenty = {
		name = "Found 120 Signs!",
		assetId = 1516513278,
		badgeClass = badgeClasses.FINDS,
		baseNumber = 120,
	},
	FoundHundredForty = {
		name = "Found 140 Signs!",
		assetId = 1516513910,
		badgeClass = badgeClasses.FINDS,
		baseNumber = 140,
	},
	FoundTwoHundred = {
		name = "Found 200 Signs!",
		assetId = 2124922227,
		badgeClass = badgeClasses.FINDS,
		baseNumber = 200,
	},
	FoundThreeHundred = {
		name = "Found 300 Signs!",
		assetId = 2124922228,
		badgeClass = badgeClasses.FINDS,
		baseNumber = 300,
	},
	FoundFourHundred = {
		name = "Found 400 Signs!",
		assetId = 2125246190,
		badgeClass = badgeClasses.FINDS,
		baseNumber = 400,
		hint = "Take time to deliberate, but when the time for action has arrived, stop thinking and go in.",
	},
	FoundFourHundredFifty = {
		name = "Found 450 Signs!",
		assetId = 2126713767,
		badgeClass = badgeClasses.FINDS,
		baseNumber = 450,
		hint = "",
	},
	FoundFiveHundred = {
		name = "Found 500 Signs!",
		assetId = 2126713764,
		badgeClass = badgeClasses.FINDS,
		baseNumber = 500,
		hint = "",
	},
	FoundFiveHundredFifty = {
		name = "Found 550 Signs!",
		assetId = 2126713765,
		badgeClass = badgeClasses.FINDS,
		baseNumber = 550,
		hint = "",
	},

	TenTop10s = {
		name = "You Got Ten Top Ten Finishes!",
		assetId = 872953049,
		badgeClass = badgeClasses.TOP10S,
		baseNumber = 10,
	},
	HundredTop10s = {
		name = "You Got 100 Top Ten Finishes!",
		assetId = 872953669,
		badgeClass = badgeClasses.TOP10S,
		baseNumber = 100,
	},
	ThousandTop10s = {
		name = "You Got 1000 Top Ten Finishes!",
		assetId = 2124922231,
		badgeClass = badgeClasses.TOP10S,
		baseNumber = 1000,
	},
	TenkTop10s = {
		name = "You Got 10k Top Ten Finishes!",
		assetId = 2129122994,
		badgeClass = badgeClasses.TOP10S,
		baseNumber = 10000,
	},

	FirstFinderOfSign = {
		name = "First Finder of Sign",
		assetId = 2126075987,
		badgeClass = badgeClasses.FINDS,
		order = 1000,
	},
	FifthFinderOfSign = {
		name = "Fifth Finder of Sign",
		assetId = 2126083209,
		badgeClass = badgeClasses.FINDS,
		order = 1100,
	},
	HundredthFinderOfSign = {
		name = "Hundredth Finder of Sign",
		assetId = 2126639209,
		badgeClass = badgeClasses.FINDS,
		order = 1200,
	},

	FiveWrs = { name = "Five World Records!", assetId = 872951844, badgeClass = badgeClasses.WRS, baseNumber = 5 },
	TwentyFiveWrs = {
		name = "Twenty Five World Records!",
		assetId = 872952726,
		badgeClass = badgeClasses.WRS,
		baseNumber = 25,
	},
	FiftyWrs = { name = "Fifty World Records!", assetId = 872954197, badgeClass = badgeClasses.WRS, baseNumber = 50 },
	NinetyNineWrs = { name = "99 World Records!", assetId = 872954653, badgeClass = badgeClasses.WRS, baseNumber = 99 },
	TwoHundredFiftyWrs = {
		name = "Two Hundred and Fifty World Records!",
		assetId = 872954976,
		badgeClass = badgeClasses.WRS,
		baseNumber = 250,
		hint = "The first virtue in a soldier is endurance of fatigue; courage is only the second virtue.",
	},
	FiveHundredWrs = {
		name = "Five Hundred World Records!",
		assetId = 2124922229,
		badgeClass = badgeClasses.WRS,
		baseNumber = 500,
		hint = "There is only one step from the sublime to the ridiculous.",
	},
	ThousandWrs = {
		name = "A thousand World Records!",
		assetId = 2124922230,
		badgeClass = badgeClasses.WRS,
		baseNumber = 1000,
		hint = "Impossible is a word to be found only in the dictionary of fools.",
	},
	TwokWrs = {
		name = "2k World Records!",
		assetId = 2125445445,
		badgeClass = badgeClasses.WRS,
		baseNumber = 2000,
		hint = "The human race is governed by its imagination.",
	},
	FourkWrs = {
		name = "4k World Records!",
		assetId = 2125445446,
		badgeClass = badgeClasses.WRS,
		baseNumber = 4000,
		hint = "Ability has nothing to do with opportunity.",
	},
	EightkWrs = {
		name = "8k World Records!",
		assetId = 2125445450,
		badgeClass = badgeClasses.WRS,
		baseNumber = 8000,
		hint = "Death is nothing, but to live defeated and inglorious is to die daily.",
	},
	SixteenkWrs = {
		name = "16k World Records!",
		assetId = 2125445477,
		badgeClass = badgeClasses.WRS,
		baseNumber = 16000,
		hint = "A soldier will fight long and hard for a bit of colored ribbon.",
	},
	ThirtyTwokWrs = {
		name = "32k World Records!",
		assetId = 2125445479,
		badgeClass = badgeClasses.WRS,
		baseNumber = 32000,
		hint = "Thou shalt not make a machine in the likeness of a man's mind",
	},

	TotalRaceCount1 = {
		name = "Total Races Found: 3",
		assetId = 1502433607,
		badgeClass = badgeClasses.RACES,
		baseNumber = 3,
	},
	TotalRaceCount2 = {
		name = "Total Races Found: 13",
		assetId = 1502481555,
		badgeClass = badgeClasses.RACES,
		baseNumber = 13,
	},
	TotalRaceCount3 = {
		name = "Total Races Found: 31",
		assetId = 1502481796,
		badgeClass = badgeClasses.RACES,
		baseNumber = 31,
	},
	TotalRaceCount4 = {
		name = "Total Races Found: 113",
		assetId = 1502482584,
		badgeClass = badgeClasses.RACES,
		baseNumber = 113,
	},
	TotalRaceCount5 = {
		name = "Total Races Found: 311",
		assetId = 1502482832,
		badgeClass = badgeClasses.RACES,
		baseNumber = 311,
	},
	TotalRaceCount6 = {
		name = "Total Races Found: 1331",
		assetId = 1502483091,
		badgeClass = badgeClasses.RACES,
		baseNumber = 1331,
	},
	TotalRaceCount7 = {
		name = "Total Races Found: 3113",
		assetId = 1502483375,
		badgeClass = badgeClasses.RACES,
		baseNumber = 3113,
	},
	TotalRaceCount8 = {
		name = "Total Races Found: 13131",
		assetId = 1502483632,
		badgeClass = badgeClasses.RACES,
		baseNumber = 13131,
	},
	TotalRaceCount9 = {
		name = "Total Races Found: 33333",
		assetId = 1502483910,
		badgeClass = badgeClasses.RACES,
		baseNumber = 33333,
	},
	TotalRaceCount10 = {
		name = "Total Races Found: 131313",
		assetId = 2125445482,
		badgeClass = badgeClasses.RACES,
		baseNumber = 131313,
	},

	TotalRunCount1 = {
		name = "Total Run Count: 2",
		assetId = 1502414005,
		badgeClass = badgeClasses.RUNS,
		baseNumber = 2,
	},
	TotalRunCount2 = {
		name = "Total Run Count: 6",
		assetId = 1502414485,
		badgeClass = badgeClasses.RUNS,
		baseNumber = 6,
	},
	TotalRunCount3 = {
		name = "Total Run Count: 26",
		assetId = 1502415066,
		badgeClass = badgeClasses.RUNS,
		baseNumber = 26,
	},
	TotalRunCount4 = {
		name = "Total Run Count: 62",
		assetId = 1502415483,
		badgeClass = badgeClasses.RUNS,
		baseNumber = 62,
	},
	TotalRunCount5 = {
		name = "Total Run Count: 226",
		assetId = 1502415976,
		badgeClass = badgeClasses.RUNS,
		baseNumber = 226,
	},
	TotalRunCount6 = {
		name = "Total Run Count: 622",
		assetId = 1502416881,
		badgeClass = badgeClasses.RUNS,
		baseNumber = 622,
	},
	TotalRunCount7 = {
		name = "Total Run Count: 2226",
		assetId = 1502417194,
		badgeClass = badgeClasses.RUNS,
		baseNumber = 2226,
	},
	TotalRunCount8 = {
		name = "Total Run Count: 6222",
		assetId = 1502417840,
		badgeClass = badgeClasses.RUNS,
		baseNumber = 6222,
		hint = "Victory belongs to the most persevering.",
	},
	TotalRunCount9 = {
		name = "Total Run Count: 22666",
		assetId = 1502418992,
		badgeClass = badgeClasses.RUNS,
		baseNumber = 22666,
		hint = "History is a set of lies agreed upon.",
	},
	TotalRunCount10 = {
		name = "Total Run Count: 66222",
		assetId = 2125246373,
		badgeClass = badgeClasses.RUNS,
		baseNumber = 66222,
		hint = "Glory is fleeting, but obscurity is forever.",
	},
	TotalRunCount11 = {
		name = "Total Run Count: 222666",
		assetId = 2125445441,
		badgeClass = badgeClasses.RUNS,
		baseNumber = 222666,
		hint = "If you want a thing done well, do it yourself.",
	},
	PlacedInServerEvent = {
		name = "Placed In Server Event",
		assetId = 2126801969,
		badgeClass = badgeClasses.SERVER_EVENTS,
		order = 10,
	},
	PrizeInServerEvent = {
		name = "Prize In Server Event",
		assetId = 2126801967,
		badgeClass = badgeClasses.SERVER_EVENTS,
		order = 20,
	},
	BigPrizeInServerEvent = {
		name = "Big Prize In Server Event",
		assetId = 2126801966,
		badgeClass = badgeClasses.SERVER_EVENTS,
		order = 30,
	},
	HugePrizeInServerEvent = {
		name = "Huge Prize In Server Event",
		assetId = 2126801965,
		badgeClass = badgeClasses.SERVER_EVENTS,
		order = 40,
	},
	MegaPrizeInServerEvent = {
		name = "Mega Prize In Server Event",
		assetId = 2126743614,
		badgeClass = badgeClasses.SERVER_EVENTS,
		order = 50,
	},
	ExceptionalPrizeInServerEvent = {
		name = "Exceptional Prize In Server Event",
		assetId = 2142445237,
		badgeClass = badgeClasses.SERVER_EVENTS,
		order = 100,
	},

	CompeteInCompetitiveServerEvent = {
		name = "Compete In Competitive Server Event",
		assetId = 2126743613,
		badgeClass = badgeClasses.SERVER_EVENTS,
		order = 150,
	},
	CompeteInLongCompetitiveServerEvent = {
		name = "Compete In Long Competitive Server Event",
		assetId = 2126639211,
		badgeClass = badgeClasses.SERVER_EVENTS,
		order = 160,
	},
	WinCompetitiveServerEvent = {
		name = "Win Competitive Server Event",
		assetId = 2126743611,
		badgeClass = badgeClasses.SERVER_EVENTS,
		order = 170,
	},
	WinLongCompetitiveServerEvent = {
		name = "Win Long Competitive Server Event",
		assetId = 2126639215,
		badgeClass = badgeClasses.SERVER_EVENTS,
		order = 180,
	},
	Heinlein = {
		name = "Robert H",
		assetId = 2128983603,
		badgeClass = badgeClasses.WEIRD,
		hint = "Starship T",
	},
	MetricSystem = {
		name = "Metric System",
		assetId = 2128933909,
		badgeClass = badgeClasses.WEIRD,
		hint = "unification",
	},
	Multiple = {
		name = "Multiple",
		assetId = 2129020813,
		badgeClass = badgeClasses.WEIRD,
		order = 10,
		hint = "special sign",
	},
	LeadFromTriple = {
		name = "Lead From Triple",
		assetId = 2129020814,
		badgeClass = badgeClasses.SPECIAL_SIGN,
		order = 20,
	},
	LeadFromQuadruple = {
		name = "Lead From Quadruple",
		assetId = 2129020815,
		badgeClass = badgeClasses.SPECIAL_SIGN,
		order = 30,
	},
	LeadFromHypergravity = {
		name = "Lead From Hypergravity",
		assetId = 2128983641,
		badgeClass = badgeClasses.SPECIAL_SIGN,
		order = 40,
	},
	LeadFromKeepOffTheGrass = {
		name = "Lead From Keep Off the Grass",
		assetId = 2128932827,
		badgeClass = badgeClasses.SPECIAL_SIGN,
		hint = "Touchdown avoiding the grass",
		order = 50,
	},

	LeadCwrFromTriple = {
		name = "Lead CWR From Triple",
		assetId = 2129133095,
		badgeClass = badgeClasses.SPECIAL_SIGN,
		order = 20,
	},
	LeadCwrFromQuadruple = {
		name = "Lead CWR From Quadruple",
		assetId = 2129133094,
		badgeClass = badgeClasses.SPECIAL_SIGN,
		order = 30,
	},
	LeadCwrFromHypergravity = {
		name = "Lead CWR From Hypergravity",
		assetId = 2129133093,
		badgeClass = badgeClasses.SPECIAL_SIGN,
		order = 40,
	},
	LeadCwrFromKeepOffTheGrass = {
		name = "Lead CWR From Keep Off the Grass",
		assetId = 2129133089,
		badgeClass = badgeClasses.SPECIAL_SIGN,
		hint = "Touchdown avoiding the grass",
		order = 50,
	},

	FloorExplorer = {
		name = "Floor Explorer",
		assetId = 2129020809,
		badgeClass = badgeClasses.WEIRD,
		order = 50,
	},
	MegaFloorExplorer = {
		name = "Mega Floor Explorer",
		assetId = 2128983661,
		badgeClass = badgeClasses.WEIRD,
		order = 60,
	},
	MegaFloorExplorerWinner = {
		name = "Mega Floor Explorer Winner",
		assetId = 2128932825,
		badgeClass = badgeClasses.WEIRD,
		order = 80,
	},
	TakeSurvey = {
		name = "Take Survey",
		assetId = 2128983659,
		badgeClass = badgeClasses.WEIRD,
		hint = "We're up in a balloon\nwith so many beliefs to be shattered\nour voices quaver",
	},
	SurveyKing = {
		name = "Survey King",
		assetId = 2128983652,
		badgeClass = badgeClasses.WEIRD,
	},
	Beckoner = {
		name = "Beckoner",
		assetId = 2128372864,
		badgeClass = badgeClasses.SPECIAL,
		hint = "Something like a drifting swarm of bees.",
	},
	HideSeek = {
		name = "Olly olly oxen free",
		assetId = 2129037622,
		badgeClass = badgeClasses.WEIRD,
		hint = "",
	},
	FirstBadgeWinner = {
		name = "First badge winner badge",
		assetId = 2129037608,
		badgeClass = badgeClasses.WEIRD,
		hint = "",
	},
	NorthernVillages = {
		name = "Northern Villages",
		assetId = 2129037607,
		badgeClass = badgeClasses.WEIRD,
		hint = "",
	},
	Contributor = {
		name = "Contributor",
		assetId = 2947742699597213,
		badgeClass = badgeClasses.CONTRIBUTION,
		hint = "",
	},
	NinjaParkour = {
		name = "Ninja Parkour",
		assetId = 3207146526819510,
		badgeClass = badgeClasses.META,
		hint = "",
	},
	MaxHarmsBadge = {
		name = "Max Harms",
		assetId = 1882550611928475,
		badgeClass = badgeClasses.WEIRD,
		hint = "",
	},
	-- Unused3 = {
	-- 	name = "C",
	-- 	assetId = 1007417965641417,
	-- 	badgeClass = badgeClasses.CONTRIBUTION,
	-- 	hint = "",
	-- },
	-- Unused4 = {
	-- 	name = "D",
	-- 	assetId = 2804500950092806,
	-- 	badgeClass = badgeClasses.CONTRIBUTION,
	-- 	hint = "",
	-- },
	-- Unused5 = {
	-- 	name = "E",
	-- 	assetId = 2024605262725247,
	-- 	badgeClass = badgeClasses.CONTRIBUTION,
	-- 	hint = "",
	-- }, 403420218226961 1512490259388669 1727264501522954 179125274571469
}

module.badges = badges
module.badgeClasses = badgeClasses

_annotate("end")
return module
