--!strict
-- classicWidget.lua (ReplicatedStorage/gui/activeRunWidgets/classicWidget.lua)
-- Widget wrapper for the Classic full-featured active run UI.
-- This delegates to classicVariant.lua to provide the original user experience.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local classicVariant = require(game.ReplicatedStorage.gui.activeRunWidgets.classicVariant)
local widgetTypes = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetTypes)

local module = {}

-- The classic widget is a complete UI takeover - it doesn't fit inside a container frame.
-- Instead, it creates its own ScreenGui and manages its own lifecycle.
-- This factory creates a widget interface that delegates to classicVariant.
local function createClassicWidget(): widgetTypes.Widget
	local isVisible: boolean = true
	local isCreated: boolean = false

	return widgetTypes.createWidget({
		-- Create initializes the classic UI (parent frame is ignored - classic manages its own ScreenGui)
		Create = function(_parent: Frame, _position: UDim2?): Frame?
			if isCreated then
				return nil
			end
			classicVariant.Init()
			classicVariant.CreateGui()
			isCreated = true
			_annotate("Classic widget created")
			-- Return nil because classic manages its own ScreenGui, not a child frame
			return nil
		end,

		Destroy = function()
			if isCreated then
				classicVariant.DestroyGui()
				isCreated = false
				_annotate("Classic widget destroyed")
			end
		end,

		-- Classic manages its own visibility through the widget system
		SetVisible = function(visible: boolean)
			isVisible = visible
		end,

		IsVisible = function(): boolean
			return isVisible
		end,

		-- Classic manages its own ScreenGui, no frame to return
		GetFrame = function(): Frame?
			return nil
		end,

		-- Run lifecycle - delegate to classicVariant
		OnRunStart = function(startTick: number, signName: string, signPosition: Vector3)
			classicVariant.StartActiveRun(startTick, signName, signPosition)
		end,

		OnRunEnd = function()
			classicVariant.KillActiveRun()
		end,

		-- Data updates - only override the ones classicVariant uses
		UpdateSpeed = function(speed: number)
			classicVariant.UpdateSpeed(speed)
		end,

		UpdateSpeedReason = function(reason: string)
			classicVariant.UpdateSpeedReason(reason)
		end,

		UpdateAcceleration = function(rate: number)
			classicVariant.UpdateAcceleration(rate)
		end,

		UpdateDescription = function(description: string)
			classicVariant.UpdateExtraRaceDescription(description)
		end,
		-- All other Update* methods use default no-ops from createWidget
	})
end

function module.Register(composer: { RegisterWidget: (string, string, () -> any) -> () })
	local category = widgetTypes.CATEGORIES.FULL_UI
	composer.RegisterWidget(category, widgetTypes.FULL_UI_STYLES.CLASSIC, createClassicWidget)
	_annotate("Registered classic widget")
end

_annotate("end")
return module

