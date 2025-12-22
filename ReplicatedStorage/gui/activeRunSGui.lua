--!strict
-- activeRunSGui.lua (ReplicatedStorage/gui/activeRunSGui.lua)
-- Facade for active run UI - delegates to the modular widget system.
-- Maintains backward compatibility: all existing code can continue to require this module.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

-- Import the widget composer which handles the modular widget system
local widgetComposer = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetComposer)

-- Re-export all composer methods for backward compatibility
-- Existing code calls activeRunSGui.UpdateSpeed(), this forwards to the widget system

local module = {}

module.Init = widgetComposer.Init
module.CreateGui = widgetComposer.CreateGui
module.DestroyGui = widgetComposer.DestroyGui

-- Start/end run methods (with legacy name support)
module.StartActiveRunGui = widgetComposer.StartRun
module.StartActiveRun = widgetComposer.StartRun
module.KillActiveRun = widgetComposer.EndRun

-- Update methods called by movement.lua
module.UpdateStartTime = widgetComposer.UpdateStartTime
module.UpdateSpeed = widgetComposer.UpdateSpeed
module.UpdateAcceleration = widgetComposer.UpdateAcceleration
module.UpdateSpeedReason = widgetComposer.UpdateSpeedReason
module.UpdateExtraRaceDescription = widgetComposer.UpdateDescription
module.UpdateMovementDetails = widgetComposer.UpdateMovementDetails

-- Restart run when user retouches the start sign (resets stateful widgets)
module.RestartRun = widgetComposer.RestartRun

-- Utility methods
module.IsRunActive = widgetComposer.IsRunActive
module.ApplyConfiguration = widgetComposer.ApplyConfiguration

_annotate("end")
return module
