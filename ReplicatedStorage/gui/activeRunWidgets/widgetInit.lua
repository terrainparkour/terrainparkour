--!strict
-- widgetInit.lua (ReplicatedStorage/gui/activeRunWidgets/widgetInit.lua)
-- Entry point for initializing the modular widget system.
-- Now delegates to widgetComposer which handles all registration.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local widgetComposer = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetComposer)

local module = {}

local initialized = false

function module.Init()
	if initialized then
		return
	end
	initialized = true

	-- Widget composer handles registration and initialization
	widgetComposer.Init()

	_annotate("Widget system initialized")
end

_annotate("end")
return module

