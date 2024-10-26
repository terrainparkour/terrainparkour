--!strict

--enums for usersetting domain and setting names.  gradually expand this.
-- this is the shareable replicateStorage version. client's cant directly require the actual server module userSettings.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local tt = require(game.ReplicatedStorage.types.gametypes)

local module = {}

-- leaderboard settings: portrait, username, awards, tix, finds,
--rank, cwrs, cwrTop10s, wrs, top10s, races, runs, badges

local settingDomains: { [string]: string } = {
	SURVEYS = "Surveys",
	MARATHONS = "Marathons",
	USERSETTINGS = "UserSettings",
	LEADERBOARD = "Leaderboard",
}

module.settingDomains = settingDomains

local settingKinds: { [string]: string } = { BOOLEAN = "boolean", STRING = "string", LUA = "lua" }

module.settingKinds = settingKinds

module.SETTING_EDITOR_NAMES = {
	BOOLEAN_TOGGLER = "Boolean Toggler", --the default?
	RACE_PICKER = "Race Picker",
	LEADERBOARD_SORT_KEY_PICKER = "Leaderboard Sort Picker",
	LEADERBOARD_SORTDIRECTION_PICKER = "Leaderboard Sort Direction Picker",
	SCREEN_POSITION_SCALAR_PICKER = "Screen Position Scalar Picker",
}

local settingDefinitions: { [string]: tt.userSettingValue } = {
	LEADERBOARD_CONFIGURATION = {
		name = "leaderboard configuration",
		domain = settingDomains.LEADERBOARD,
		kind = settingKinds.LUA,
		defaultLuaValue = {
			position = UDim2.new(0.5, 0, 0.08, 0),
			size = UDim2.new(0.44, 0, 0.35, 0),
			minimized = false,
			sortDirection = "descending",
			sortColumn = "userTix",
		},
		editorName = "",
	},
	ACTIVE_RUN_CONFIGURATION = { --the position (and maybe details?) of the active run ui like source, distance etc.
		name = "active run configuration",
		domain = settingDomains.USERSETTINGS,
		kind = settingKinds.LUA,
		defaultLuaValue = { -- tt.currentRunUIConfiguration
			showDistance = true,
			position = UDim2.new(0.3, 0, 0.70, 0),
			size = UDim2.new(0.0, 200, 0.20, 0),
			digitsInTime = 2,
			transparency = 0.6,
		},
		editorName = "",
	},
	ALLOW_WARP = {
		name = "allow warping at all. If you set this, warping will not work although buttons will still appear. This is useful if you are doing long marathons, for example.",
		domain = settingDomains.USERSETTINGS,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	SHOW_RUN_RESULT_POPUPS = {
		name = "show run result popups",
		domain = settingDomains.USERSETTINGS,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	SHRINK_RUN_RESULT_POPUPS = {
		name = "shrink run result popups",
		domain = settingDomains.USERSETTINGS,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = false,
	},
	ONLY_HAVE_ONE_RUN_RESULT_POPUP_AT_A_TIME = {
		name = "only have one run result popup at a time - if another one comes up, the existing one will be closed.",
		domain = settingDomains.USERSETTINGS,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = false,
	},
	ROTATE_PLAYER_ON_WARP_WHEN_DESTINATION = {
		name = "when you're warping with an implied destination, rotate your avatar and camera to face the direction",
		domain = settingDomains.USERSETTINGS,
		defaultBooleanValue = true,
		kind = settingKinds.BOOLEAN,
	},
	HIDE_LEADERBOARD = {
		name = "hide leaderboard",
		domain = settingDomains.USERSETTINGS,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = false,
	},
	SHOW_PARTICLES = {
		name = "show particles",
		domain = settingDomains.USERSETTINGS,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	SHORTEN_CONTEST_DIGIT_DISPLAY = {
		name = "shorten contest digit display",
		domain = settingDomains.USERSETTINGS,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	ENABLE_DYNAMIC_RUNNING = {
		name = "enable dynamic running",
		domain = settingDomains.USERSETTINGS,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	X_BUTTON_IGNORES_CHAT = {
		name = "x button ignores chat",
		domain = settingDomains.USERSETTINGS,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	HIGHLIGHT_ON_RUN_COMPLETE_WARP = {
		name = "do sign highlight when you click warp on a complete run",
		domain = settingDomains.USERSETTINGS,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	HIGHLIGHT_ON_KEYBOARD_1_TO_WARP = {
		name = "do sign highlight when you hit 1 to warp to the completed run",
		domain = settingDomains.USERSETTINGS,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	HIGHLIGHT_AT_ALL = {
		name = "do any sign highlighting at all, for example when warping to a server event run",
		domain = settingDomains.USERSETTINGS,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_FAVORITES = {
		name = "show favorites",
		domain = settingDomains.LEADERBOARD,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_PORTRAIT = {
		name = "show portrait",
		domain = settingDomains.LEADERBOARD,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_USERNAME = {
		name = "show username",
		domain = settingDomains.LEADERBOARD,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_AWARDS = {
		name = "show awards",
		domain = settingDomains.LEADERBOARD,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_TIX = {
		name = "show tix",
		domain = settingDomains.LEADERBOARD,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_FINDS = {
		name = "show finds",
		domain = settingDomains.LEADERBOARD,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_FINDRANK = {
		name = "show find rank",
		domain = settingDomains.LEADERBOARD,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_WRRANK = {
		name = "show wr rank",
		domain = settingDomains.LEADERBOARD,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_CWRS = {
		name = "show cwrs",
		domain = settingDomains.LEADERBOARD,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_WRS = {
		name = "show wrs",
		domain = settingDomains.LEADERBOARD,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_CWRTOP10S = {
		name = "show cwrTop10s",
		domain = settingDomains.LEADERBOARD,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_TOP10S = {
		name = "show top10s",
		domain = settingDomains.LEADERBOARD,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_CWRANK = {
		name = "show cwr rank",
		domain = settingDomains.LEADERBOARD,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_RACES = {
		name = "show races",
		domain = settingDomains.LEADERBOARD,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_RUNS = {
		name = "show runs",
		domain = settingDomains.LEADERBOARD,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_BADGES = {
		name = "show badges",
		domain = settingDomains.LEADERBOARD,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	-- {
	-- 	name = LEADERBOARD_ENABLE_WARPTO_COLUMN,
	-- 	domain = settingDomains.LEADERBOARD,
	-- 	kind = settingTypes.BOOLEAN, defaultBooleanValue =true,
	-- },
	-- {
	-- 	name = LEADERBOARD_ENABLE_LASTRACE_COLUMN,
	-- 	domain = settingDomains.LEADERBOARD,
	-- 	kind = settingTypes.BOOLEAN, defaultBooleanValue =true,
	-- },
	LEADERBOARD_ENABLE_DAYSINGAME_COLUMN = {
		name = "show days in game",
		domain = settingDomains.LEADERBOARD,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_WRSTODAY_COLUMN = {
		name = "show wrs today",
		domain = settingDomains.LEADERBOARD,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_CWRSTODAY_COLUMN = {
		name = "show cwrs today",
		domain = settingDomains.LEADERBOARD,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_RUNSTODAY_COLUMN = {
		name = "show runs today",
		domain = settingDomains.LEADERBOARD,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_PINNED_RACE_COLUMN = {
		name = "show pinned race",
		domain = settingDomains.LEADERBOARD,
		kind = settingKinds.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_PINNED_RACE = {
		name = "pinned race",
		domain = settingDomains.LEADERBOARD,
		kind = settingKinds.STRING,
		defaultStringValue = "",
		editorName = module.SETTING_EDITOR_NAMES.RACE_PICKER,
	},

	-- MARATHON SETTINGS
	ENABLE_ALPHAFREE = { name = "enable alphafree", kind = settingKinds.BOOLEAN, domain = settingDomains.MARATHONS },
	ENABLE_ALPHAORDERED = {
		name = "enable alpha ordered",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_ALPHAREVERSE = {
		name = "enable alpha reverse",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_ALPHABETICALALLLETTERS = {
		name = "enable alphabetical all letters",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_FIND4 = { name = "enable find4", kind = settingKinds.BOOLEAN, domain = settingDomains.MARATHONS },
	ENABLE_FIND10 = { name = "enable find10", kind = settingKinds.BOOLEAN, domain = settingDomains.MARATHONS },
	ENABLE_FIND20 = { name = "enable find20", kind = settingKinds.BOOLEAN, domain = settingDomains.MARATHONS },
	ENABLE_FIND40 = { name = "enable find40", kind = settingKinds.BOOLEAN, domain = settingDomains.MARATHONS },
	ENABLE_FIND100 = { name = "enable find100", kind = settingKinds.BOOLEAN, domain = settingDomains.MARATHONS },
	ENABLE_FIND200 = { name = "enable find200", kind = settingKinds.BOOLEAN, domain = settingDomains.MARATHONS },
	ENABLE_FIND300 = { name = "enable find300", kind = settingKinds.BOOLEAN, domain = settingDomains.MARATHONS },
	ENABLE_FIND380 = { name = "enable find380", kind = settingKinds.BOOLEAN, domain = settingDomains.MARATHONS },
	ENABLE_FIND500 = { name = "enable find500", kind = settingKinds.BOOLEAN, domain = settingDomains.MARATHONS },
	ENABLE_FIND10S = { name = "enable find10s", kind = settingKinds.BOOLEAN, domain = settingDomains.MARATHONS },
	ENABLE_FIND10T = { name = "enable find10t", kind = settingKinds.BOOLEAN, domain = settingDomains.MARATHONS },
	ENABLE_FIND40LETTERS = {
		name = "enable exactly 40letters",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_FIND100LETTERS = {
		name = "enable exactly 100letters",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_FIND200LETTERS = {
		name = "enable exactly 200 letters",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_FIND500LETTERS = {
		name = "enable exactly500letters",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_FIND1000LETTERS = {
		name = "enable exactly 1000 letters",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_SIGNSOFEEVERYLENGTH = {
		name = "enable signs of every length",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_FINDSET_EVOLUTION = {
		name = "enable evolution",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_FINDSET_SINGLELETTER = {
		name = "enable single letter",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_FINDSET_FIRSTCONTEST = {
		name = "enable first contest",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_FINDSET_LEGACY = {
		name = "enable legacy",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_FINDSET_CAVE = {
		name = "enable cave",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	-- ENABLE_FINDSET_HYPER = {
	-- 	name = "enable hyper",
	-- 	kind = settingKinds.BOOLEAN,
	-- 	domain = settingDomains.MARATHONS,
	-- },
	ENABLE_FINDSET_AOFB = {
		name = "enable a of b",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_FINDSET_THREELETTER = {
		name = "enable three letter",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},

	SURVEY_TRACKMANIA = {
		name = "have you played trackmania",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_ROBLOX = {
		name = "have you played roblox for more than 5 years",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_BADGES = {
		name = "should the game have more badges",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_CHOMIK = { name = "have you found the chomik", kind = settingKinds.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_MORESIGNS = {
		name = "should the game have more signs",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_MOREICE = {
		name = "should the game have more ice",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_FEWERSIGNS = {
		name = "should the game have fewer signs",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_MORENEWAREAS = {
		name = "should the game have more new areas",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_MOREMARATHONS = {
		name = "should the game have more marathons",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_MOREWATERAREAS = {
		name = "should the game have more water areas",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_MORESURVEYS = {
		name = "should the game have more surveys",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_MORESYSTEMSETTINGS = {
		name = "should the game have more settings",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_DISABLEPOPUPS = {
		name = "should the game disable popups of other user activity",
		domain = settingDomains.SURVEYS,
		kind = settingKinds.BOOLEAN,
	},
	SURVEY_CHOMIKS = {
		name = "do you play find the chomiks",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_JTOH = { name = "do you play jtoh", kind = settingKinds.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_SHEDLETTSKY = {
		name = "do you know who shedletsky is",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_BLAMEJOHN = { name = "blame john", kind = settingKinds.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_BIRB = { name = "birb", kind = settingKinds.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_COLDMOLD = {
		name = "cold mold on a slate plate",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_YEAR = {
		name = "have you played for more than a year",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_AMONGUS = { name = "have you played among us", kind = settingKinds.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_FACTORIO = {
		name = "have you played factorio",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_BEATFACTORIO = {
		name = "have you beaten factorio",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_SLYTHERE = {
		name = "have you played slay the spire",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_BEATSLYTHERE = {
		name = "have you beaten slay the spire ascension 20",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_SPECIALSIGNS = { name = "more special signs", kind = settingKinds.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_LIMITEDSIGNS = { name = "more limited signs", kind = settingKinds.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_MOVABLESIGNS = { name = "moveable signs", kind = settingKinds.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_LAVA = { name = "more lava", kind = settingKinds.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_ICE = { name = "more ice", kind = settingKinds.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_PLAYERS = { name = "more players", kind = settingKinds.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_ADS = { name = "more advertisements", kind = settingKinds.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_SOUNDS = { name = "more sounds", kind = settingKinds.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_MUSIC = { name = "more music", kind = settingKinds.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_CONFIGURATION = {
		name = "more configuration options",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_UI = { name = "more UIs", kind = settingKinds.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_COMMANDS = { name = "more commands", kind = settingKinds.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_UGC = { name = "more user generated content", kind = settingKinds.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_VERBETTER = { name = "Verv will get better", kind = settingKinds.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_AI = { name = "you like ai", kind = settingKinds.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_MIDJOURNEY = {
		name = "you have tried midjourney",
		kind = settingKinds.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_CHATGPT = { name = "you have used chatGPT", kind = settingKinds.BOOLEAN, domain = settingDomains.SURVEYS },
}

-- VERY important to do this, so you can look them up easily later.
for k, v in pairs(settingDefinitions) do
	v.codeName = k
end

module.settingDefinitions = settingDefinitions

export type settingRequest = { domain: string?, settingName: string?, kind: string? }

_annotate("end")
return module
