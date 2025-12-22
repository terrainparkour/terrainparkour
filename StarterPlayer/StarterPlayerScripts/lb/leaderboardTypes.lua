--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

-- Column rendering kinds:
-- "standard" (default/nil): TextLabel, direct server value display, automatic green flash on change
-- "computed": Frame, value calculated locally from cached data (e.g., findPercent = findCount/totalSigns)
-- "interactive": Frame, has buttons or click handlers (e.g., warpTo button, pinnedRace warper)
export type lbColumnKind = "standard" | "computed" | "interactive"

export type lbColumnDescriptor = {
	name: string,
	num: number,
	widthScaleImportance: number,
	userFacingName: string,
	tooltip: string,
	doWrapping: boolean,
	-- Column rendering kind - determines how the column is created and updated
	-- nil defaults to "standard" (simple TextLabel with automatic green flash)
	columnKind: lbColumnKind?,
	-- For non-standard columns: name of the Draw function in leaderboardGui
	-- e.g., "DrawFindPercentCell", "DrawRaceWarper"
	drawFunctionName: string?,
	-- If true, column uses custom rendering (e.g. images) and skips text holder creation
	-- No green flash, draw function handles all content creation
	customRendering: boolean?,
}

_annotate("end")
return module
