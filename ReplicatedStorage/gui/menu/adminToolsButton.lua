--!strict

-- adminToolsButton.lua :: ReplicatedStorage.gui.menu.adminToolsButton
-- Button for the hamburger menu that re-opens the admin tools panel (Studio only, TerrainParkour only).

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local gt = require(game.ReplicatedStorage.gui.guiTypes)
local adminHelpTools = require(game.StarterPlayer.StarterCharacterScripts.client.adminHelpTools)

local module = {}

local function getAdminToolsModal(_localPlayer: Player): ScreenGui
	adminHelpTools.Show()
	-- Return empty ScreenGui since the admin panel manages its own GUI
	local dummyGui = Instance.new("ScreenGui")
	dummyGui.Name = "AdminToolsDummy"
	dummyGui.Enabled = false
	return dummyGui
end

local adminToolsButton: gt.button = {
	name = "Admin Tools",
	contentsGetter = getAdminToolsModal,
}

module.adminToolsButton = adminToolsButton

_annotate("end")
return module












