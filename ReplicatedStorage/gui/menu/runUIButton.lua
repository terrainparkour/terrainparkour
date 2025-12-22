--!strict
-- runUIButton.lua (ReplicatedStorage/gui/menu/runUIButton.lua)
-- Button for opening the active run UI run widget picker from the leaderboard.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local runWidgetPicker = require(game.ReplicatedStorage.gui.activeRunWidgets.runWidgetPicker)
local widgetComposer = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetComposer)

local module = {}

module.Click = function(_userIds: { number }): ScreenGui
	-- Ensure widget system is initialized (in case it wasn't via movement.lua yet)
	widgetComposer.Init()
	runWidgetPicker.Toggle()
	return Instance.new("ScreenGui")
end

module.HoverHint = "Configure active run UI widgets"
module.Name = "Run UI ⚙"

_annotate("end")
return module

