--!strict

-- leaderboardUtil
-- constants and stuff for leaderboard.

local leaderboardUtils = {}
local module = {}

-- forbidden from removing this; remember it is necessary to sometimes convert various input types to your right type.
function leaderboardUtils.calculateVector2deltaFromVector3andVector2(input: Vector3, start: Vector2): Vector2
	local delta = input - Vector3.new(start.X, start.Y, 0)
	return Vector2.new(delta.X, delta.Y)
end

function leaderboardUtils.triggerSpuriousResize(containerFrame, resetLbHeight)
	task.delay(0.5, function()
		local currentSize = containerFrame.Size
		local newSize =
			UDim2.new(currentSize.X.Scale, currentSize.X.Offset + 1, currentSize.Y.Scale, currentSize.Y.Offset)
		containerFrame.Size = newSize
		task.wait(0.05)
		containerFrame.Size = currentSize
		resetLbHeight()
	end)
end

export type lbUserCell = {
	name: string,
	num: number,
	widthScaleImportance: number,
	userFacingName: string,
	tooltip: string,
}

local lbUserCellDescriptors: { [string]: lbUserCell } = {
	portrait = { name = "portrait", num = 1, widthScaleImportance = 10, userFacingName = "", tooltip = "" },
	username = { name = "username", num = 3, widthScaleImportance = 25, userFacingName = "", tooltip = "" },
	awardCount = {
		name = "awardCount",
		num = 5,
		widthScaleImportance = 7,
		userFacingName = "awards",
		tooltip = "How many special awards you've earned from contests or other achievements.",
	},
	userTix = {
		name = "userTix",
		num = 7,
		widthScaleImportance = 18,
		userFacingName = "tix",
		tooltip = "How many tix you've earned from your runs and finds and records.",
	},
	userTotalFindCount = {
		name = "userTotalFindCount",
		num = 9,
		widthScaleImportance = 10,
		userFacingName = "finds",
		tooltip = "How many signs you've found!",
	},
	findRank = {
		name = "findRank",
		num = 11,
		widthScaleImportance = 8,
		userFacingName = "rank",
		tooltip = "Your rank of how many signs you've found.",
	},
	userCompetitiveWRCount = {
		name = "userCompetitiveWRCount",
		num = 13,
		widthScaleImportance = 12,
		userFacingName = "cwrs",
		tooltip = "How many World Records you hold in competitive races!",
	},
	userTotalWRCount = {
		name = "userTotalWRCount",
		num = 15,
		widthScaleImportance = 10,
		userFacingName = "wrs",
		tooltip = "How many World Records you hold right now.",
	},
	top10s = {
		name = "top10s",
		num = 18,
		widthScaleImportance = 8,
		userFacingName = "top10s",
		tooltip = "How many of your runs are still in the top10.",
	},
	races = {
		name = "races",
		num = 23,
		widthScaleImportance = 6,
		userFacingName = "races",
		tooltip = "How many distinct runs you've done.",
	},
	runs = {
		name = "runs",
		num = 26,
		widthScaleImportance = 6,
		userFacingName = "runs",
		tooltip = "How many runs you've done in total.",
	},
	badgeCount = {
		name = "badgeCount",
		num = 31,
		widthScaleImportance = 10,
		userFacingName = "badges",
		tooltip = "Total game badges you have won.",
	},
}

module.LbUserCellDescriptors = lbUserCellDescriptors
return module
