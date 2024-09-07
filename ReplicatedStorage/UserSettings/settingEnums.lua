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

local settingTypes: { [string]: string } = { BOOLEAN = "boolean", STRING = "string" }

--it'd be nice to not have that separate.
local settingDefinitions: { [string]: tt.userSettingValue } = {
	ROTATE_PLAYER_ON_WARP_WHEN_DESTINATION = {
		name = "when you're warping with an implied destination, rotate your avatar and camera to face the direction",
		domain = settingDomains.USERSETTINGS,
		defaultBooleanValue = true,
		kind = settingTypes.BOOLEAN,
	},
	HIDE_LEADERBOARD = {
		name = "hide leaderboard",
		domain = settingDomains.USERSETTINGS,
		kind = settingTypes.BOOLEAN,
		defaultBooleanValue = false,
	},
	SHOW_PARTICLES = {
		name = "show particles",
		domain = settingDomains.USERSETTINGS,
		kind = settingTypes.BOOLEAN,
		defaultBooleanValue = true,
	},
	SHORTEN_CONTEST_DIGIT_DISPLAY = {
		name = "shorten contest digit display",
		domain = settingDomains.USERSETTINGS,
		kind = settingTypes.BOOLEAN,
		defaultBooleanValue = true,
	},
	ENABLE_DYNAMIC_RUNNING = {
		name = "enable dynamic running",
		domain = settingDomains.USERSETTINGS,
		kind = settingTypes.BOOLEAN,
		defaultBooleanValue = true,
	},
	X_BUTTON_IGNORES_CHAT = {
		name = "x button ignores chat",
		domain = settingDomains.USERSETTINGS,
		kind = settingTypes.BOOLEAN,
		defaultBooleanValue = true,
	},
	HIGHLIGHT_ON_RUN_COMPLETE_WARP = {
		name = "do sign highlight when you click warp on a complete run",
		domain = settingDomains.USERSETTINGS,
		kind = settingTypes.BOOLEAN,
		defaultBooleanValue = true,
	},
	HIGHLIGHT_ON_KEYBOARD_1_TO_WARP = {
		name = "do sign highlight when you hit 1 to warp to the completed run",
		domain = settingDomains.USERSETTINGS,
		kind = settingTypes.BOOLEAN,
		defaultBooleanValue = true,
	},
	HIGHLIGHT_AT_ALL = {
		name = "do any sign highlighting at all, for example when warping to a server event run",
		domain = settingDomains.USERSETTINGS,
		kind = settingTypes.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_PORTRAIT = {
		name = "show portrait",
		domain = settingDomains.LEADERBOARD,
		kind = settingTypes.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_USERNAME = {
		name = "show username",
		domain = settingDomains.LEADERBOARD,
		kind = settingTypes.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_AWARDS = {
		name = "show awards",
		domain = settingDomains.LEADERBOARD,
		kind = settingTypes.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_TIX = {
		name = "show tix",
		domain = settingDomains.LEADERBOARD,
		kind = settingTypes.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_FINDS = {
		name = "show finds",
		domain = settingDomains.LEADERBOARD,
		kind = settingTypes.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_FINDRANK = {
		name = "show find rank",
		domain = settingDomains.LEADERBOARD,
		kind = settingTypes.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_WRRANK = {
		name = "show wr rank",
		domain = settingDomains.LEADERBOARD,
		kind = settingTypes.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_CWRS = {
		name = "show cwrs",
		domain = settingDomains.LEADERBOARD,
		kind = settingTypes.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_WRS = {
		name = "show wrs",
		domain = settingDomains.LEADERBOARD,
		kind = settingTypes.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_CWRTOP10S = {
		name = "show cwrTop10s",
		domain = settingDomains.LEADERBOARD,
		kind = settingTypes.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_TOP10S = {
		name = "show top10s",
		domain = settingDomains.LEADERBOARD,
		kind = settingTypes.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_CWRANK = {
		name = "show cwr rank",
		domain = settingDomains.LEADERBOARD,
		kind = settingTypes.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_RACES = {
		name = "show races",
		domain = settingDomains.LEADERBOARD,
		kind = settingTypes.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_RUNS = {
		name = "show runs",
		domain = settingDomains.LEADERBOARD,
		kind = settingTypes.BOOLEAN,
		defaultBooleanValue = true,
	},
	LEADERBOARD_ENABLE_BADGES = {
		name = "show badges",
		domain = settingDomains.LEADERBOARD,
		kind = settingTypes.BOOLEAN,
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
		kind = settingTypes.BOOLEAN,
		defaultBooleanValue = true,
	},
	-- LEADERBOARD_ENABLE_PINNED_RACE = {
	-- 	name = "enable pinned race",
	-- 	domain = settingDomains.LEADERBOARD,
	-- 	kind = settingTypes.BOOLEAN,
	-- 	defaultBooleanValue = true,
	-- },
	-- LEADERBOARD_PINNED_RACE_VALUE = {
	-- 	name = "pinned race",
	-- 	domain = settingDomains.LEADERBOARD,
	-- 	kind = settingTypes.STRING,
	-- 	defaultStringValue = "",
	-- },

	-- MARATHON SETTINGS
	ENABLE_ALPHAFREE = { name = "enable alphafree", kind = settingTypes.BOOLEAN, domain = settingDomains.MARATHONS },
	ENABLE_ALPHAORDERED = {
		name = "enable alphaordered",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_ALPHAREVERSE = {
		name = "enable alphareverse",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_ALPHABETICALALLLETTERS = {
		name = "enable alphabeticalallletters",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_FIND4 = { name = "enable find4", kind = settingTypes.BOOLEAN, domain = settingDomains.MARATHONS },
	ENABLE_FIND10 = { name = "enable find10", kind = settingTypes.BOOLEAN, domain = settingDomains.MARATHONS },
	ENABLE_FIND20 = { name = "enable find20", kind = settingTypes.BOOLEAN, domain = settingDomains.MARATHONS },
	ENABLE_FIND40 = { name = "enable find40", kind = settingTypes.BOOLEAN, domain = settingDomains.MARATHONS },
	ENABLE_FIND100 = { name = "enable find100", kind = settingTypes.BOOLEAN, domain = settingDomains.MARATHONS },
	ENABLE_FIND200 = { name = "enable find200", kind = settingTypes.BOOLEAN, domain = settingDomains.MARATHONS },
	ENABLE_FIND300 = { name = "enable find300", kind = settingTypes.BOOLEAN, domain = settingDomains.MARATHONS },
	ENABLE_FIND380 = { name = "enable find380", kind = settingTypes.BOOLEAN, domain = settingDomains.MARATHONS },
	ENABLE_FIND500 = { name = "enable find500", kind = settingTypes.BOOLEAN, domain = settingDomains.MARATHONS },
	ENABLE_FIND10S = { name = "enable find10s", kind = settingTypes.BOOLEAN, domain = settingDomains.MARATHONS },
	ENABLE_FIND10T = { name = "enable find10t", kind = settingTypes.BOOLEAN, domain = settingDomains.MARATHONS },
	ENABLE_FIND40LETTERS = {
		name = "enable exactly40letters",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_FIND100LETTERS = {
		name = "enable exactly100letters",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_FIND200LETTERS = {
		name = "enable exactly200letters",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_FIND500LETTERS = {
		name = "enable exactly500letters",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_FIND1000LETTERS = {
		name = "enable exactly1000letters",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_SIGNSOFEEVERYLENGTH = {
		name = "enable signsofeverylength",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_FINDSET_EVOLUTION = {
		name = "enable findsetevolution",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_FINDSET_SINGLELETTER = {
		name = "enable findsetsingleletter",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_FINDSET_FIRSTCONTEST = {
		name = "enable findsetfirstcontest",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_FINDSET_LEGACY = {
		name = "enable findsetlegacy",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_FINDSET_CAVE = {
		name = "enable findsetcave",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_FINDSET_AOFB = {
		name = "enable findsetaofb",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},
	ENABLE_FINDSET_THREELETTER = {
		name = "enable findsetthreeletter",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.MARATHONS,
	},

	SURVEY_TRACKMANIA = {
		name = "have you played trackmania",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_ROBLOX = {
		name = "have you played roblox for more than 5 years",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_BADGES = {
		name = "should the game have more badges",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_CHOMIK = { name = "have you found the chomik", kind = settingTypes.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_MORESIGNS = {
		name = "should the game have more signs",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_MOREICE = {
		name = "should the game have more ice",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_FEWERSIGNS = {
		name = "should the game have fewer signs",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_MORENEWAREAS = {
		name = "should the game have more new areas",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_MOREMARATHONS = {
		name = "should the game have more marathons",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_MOREWATERAREAS = {
		name = "should the game have more water areas",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_MORESURVEYS = {
		name = "should the game have more surveys",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_MORESYSTEMSETTINGS = {
		name = "should the game have more settings",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_DISABLEPOPUPS = {
		name = "should the game disable popups of other user activity",
		domain = settingDomains.SURVEYS,
		kind = settingTypes.BOOLEAN,
	},
	SURVEY_CHOMIKS = {
		name = "do you play find the chomiks",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_JTOH = { name = "do you play jtoh", kind = settingTypes.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_SHEDLETTSKY = {
		name = "do you know who shedletsky is",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_BLAMEJOHN = { name = "blame john", kind = settingTypes.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_BIRB = { name = "birb", kind = settingTypes.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_COLDMOLD = {
		name = "cold mold on a slate plate",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_YEAR = {
		name = "have you played for more than a year",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_AMONGUS = { name = "have you played among us", kind = settingTypes.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_FACTORIO = {
		name = "have you played factorio",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_BEATFACTORIO = {
		name = "have you beaten factorio",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_SLYTHERE = {
		name = "have you played slay the spire",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_BEATSLYTHERE = {
		name = "have you beaten slay the spire ascension 20",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_SPECIALSIGNS = { name = "more special signs", kind = settingTypes.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_LIMITEDSIGNS = { name = "more limited signs", kind = settingTypes.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_MOVABLESIGNS = { name = "moveable signs", kind = settingTypes.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_LAVA = { name = "more lava", kind = settingTypes.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_ICE = { name = "more ice", kind = settingTypes.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_PLAYERS = { name = "more players", kind = settingTypes.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_ADS = { name = "more advertisements", kind = settingTypes.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_SOUNDS = { name = "more sounds", kind = settingTypes.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_MUSIC = { name = "more music", kind = settingTypes.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_CONFIGURATION = {
		name = "more configuration options",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_UI = { name = "more UIs", kind = settingTypes.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_COMMANDS = { name = "more commands", kind = settingTypes.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_UGC = { name = "more user generated content", kind = settingTypes.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_VERBETTER = { name = "Verv will get better", kind = settingTypes.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_AI = { name = "you like ai", kind = settingTypes.BOOLEAN, domain = settingDomains.SURVEYS },
	SURVEY_MIDJOURNEY = {
		name = "you have tried midjourney",
		kind = settingTypes.BOOLEAN,
		domain = settingDomains.SURVEYS,
	},
	SURVEY_CHATGPT = { name = "you have used chatGPT", kind = settingTypes.BOOLEAN, domain = settingDomains.SURVEYS },
}

-- VERY important to do this, so you can look them up easily later.
for k, v in pairs(settingDefinitions) do
	v.codeName = k
end

module.settingDefinitions = settingDefinitions

--this system fails when i add one here but don't create the userSetting in the db.
-- I should have a way to automatically at least do a getOrCreate there, like I do with signs.

export type settingRequest = { domain: string?, settingName: string? }

_annotate("end")
return module
