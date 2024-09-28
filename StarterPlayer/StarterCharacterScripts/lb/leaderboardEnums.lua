--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local lt = require(game.StarterPlayer.StarterCharacterScripts.lb.leaderboardTypes)

local module = {}

local LbColumnDescriptors: { [string]: lt.lbColumnDescriptor } = {
	portrait = { name = "portrait", num = 1, widthScaleImportance = 14, userFacingName = "portrait", tooltip = "" },
	username = { name = "username", num = 3, widthScaleImportance = 25, userFacingName = "username", tooltip = "" },
	awardCount = {
		name = "awardCount",
		num = 5,
		widthScaleImportance = 15,
		userFacingName = "awards",
		tooltip = "",
	},
	userTix = {
		name = "userTix",
		num = 7,
		widthScaleImportance = 18,
		userFacingName = "tix",
		tooltip = "",
	},
	findCount = {
		name = "findCount",
		num = 9,
		widthScaleImportance = 10,
		userFacingName = "finds",
		tooltip = "",
	},
	findRank = {
		name = "findRank",
		num = 11,
		widthScaleImportance = 8,
		userFacingName = "find rank",
		tooltip = "",
	},
	cwrs = {
		name = "cwrs",
		num = 13,
		widthScaleImportance = 12,
		userFacingName = "cwrs",
		tooltip = "",
	},
	cwrsToday = {
		name = "cwrsToday",
		num = 15,
		widthScaleImportance = 12,
		userFacingName = "cwrs today",
		tooltip = "",
	},
	cwrRank = {
		name = "cwrRank",
		num = 17,
		widthScaleImportance = 12,
		userFacingName = "cwr rank",
		tooltip = "",
	},
	cwrTop10s = {
		name = "cwrTop10s",
		num = 20,
		widthScaleImportance = 11,
		userFacingName = "cwr top10s",
		tooltip = "",
	},
	wrCount = {
		name = "wrCount",
		num = 25,
		widthScaleImportance = 10,
		userFacingName = "wrs",
		tooltip = "",
	},

	wrsToday = {
		name = "wrsToday",
		num = 27,
		widthScaleImportance = 10,
		userFacingName = "wrs today",
		tooltip = "",
	},
	wrRank = {
		name = "wrRank",
		num = 30,
		widthScaleImportance = 8,
		userFacingName = "wr rank",
		tooltip = "",
	},
	top10s = {
		name = "top10s",
		num = 35,
		widthScaleImportance = 8,
		userFacingName = "top10s",
		tooltip = "",
	},

	userTotalRaceCount = {
		name = "userTotalRaceCount",
		num = 40,
		widthScaleImportance = 9,
		userFacingName = "races",
		tooltip = "",
	},
	userTotalRunCount = {
		name = "userTotalRunCount",
		num = 45,
		widthScaleImportance = 6,
		userFacingName = "runs",
		tooltip = "",
	},
	runsToday = {
		name = "runsToday",
		num = 47,
		widthScaleImportance = 10,
		userFacingName = "runs today",
		tooltip = "",
	},
	badgeCount = {
		name = "badgeCount",
		num = 50,
		widthScaleImportance = 10,
		userFacingName = "badges",
		tooltip = "",
	},
	-- warpTo = {
	-- 	name = "warpTo",
	-- 	num = 35,
	-- 	widthScaleImportance = 10,
	-- 	userFacingName = "warp to",
	-- 	tooltip = "",
	-- },
	-- lastRace = {
	-- 	name = "lastRace",
	-- 	num = 38,
	-- 	widthScaleImportance = 10,
	-- 	userFacingName = "last race",
	-- 	tooltip = "",
	-- },
	daysInGame = {
		name = "daysInGame",
		num = 55,
		widthScaleImportance = 10,
		userFacingName = "game days",
		tooltip = "",
	},
	pinnedRace = {
		name = "pinnedRace",
		num = 60,
		widthScaleImportance = 55,
		userFacingName = "pinned",
		tooltip = "use /pin or /unpin to set/remove this. It'll be warpable by other players, too, soon.",
	},
}

module.LbColumnDescriptors = LbColumnDescriptors

_annotate("end")

return module
