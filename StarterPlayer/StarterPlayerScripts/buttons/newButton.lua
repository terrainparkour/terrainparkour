--!strict

-- newButton.lua
-- Button that opens the New Runs modal.
-- Uses the unified runsListModal for the actual modal display.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local gt = require(game.ReplicatedStorage.gui.guiTypes)
local runsListModal = require(game.StarterPlayer.StarterPlayerScripts.buttons.runsListModal)

local module = {}

local function getNewContents(_player: Player, userIds: { number }): ScreenGui
	return runsListModal.createRunsListModal("new", userIds)
end

local newButton: gt.actionButton = {
	name = "New Button",
	contentsGetter = getNewContents,
	hoverHint = "Show new races found today",
	shortName = "New",
	getActive = function()
		return true
	end,
	widthXScale = 0.25,
}

module.newButton = newButton

_annotate("end")
return module
