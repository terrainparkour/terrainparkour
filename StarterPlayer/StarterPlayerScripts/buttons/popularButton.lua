--!strict

-- popularButton.lua
-- Button that opens the Popular Runs modal.
-- Uses the unified runsListModal for the actual modal display.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local gt = require(game.ReplicatedStorage.gui.guiTypes)
local runsListModal = require(game.StarterPlayer.StarterPlayerScripts.buttons.runsListModal)

local module = {}

local function getPopularContents(_player: Player, userIds: { number }): ScreenGui
	return runsListModal.createRunsListModal("popular", userIds)
end

local popularButton: gt.actionButton = {
	name = "Popular Button",
	contentsGetter = getPopularContents,
	hoverHint = "Show top popular runs",
	shortName = "Popular",
	getActive = function()
		return true
	end,
	widthXScale = 0.25,
}

module.popularButton = popularButton

_annotate("end")
return module
