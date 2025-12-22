--!strict
-- widgetTypes.lua (ReplicatedStorage/gui/activeRunWidgets/widgetTypes.lua)
-- Defines categories, styles, and types for the modular active run widget system.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

-- Category info structure
-- styles uses { [string]: string } as a common indexer type for all style enums.
export type CategoryInfoEntry = {
	id: string,
	name: string,
	description: string,
	styles: { [string]: string },
}

-- Preset configuration entry
export type PresetEntry = {
	name: string,
	description: string,
	config: { [string]: string },
}

-- Saved size info passed to resizable widgets
export type SavedSize = {
	width: number,
	height: number,
}

-- Context passed to widget Create for initialization
export type WidgetCreateContext = {
	-- Saved size from previous session (nil if no saved size)
	savedSize: SavedSize?,
	-- Callback to save size when user resizes widget (must be called on resize end)
	onSaveSize: ((width: number, height: number) -> ())?,
	-- Saved widget-specific state from previous session (nil if no saved state)
	savedState: { [string]: any }?,
	-- Callback to save widget-specific state (e.g., filter toggles)
	onSaveState: ((state: { [string]: any }) -> ())?,
}

-- Widget interface that all widgets must implement
-- IMPORTANT: All methods are REQUIRED. Use empty functions for unused data updates.
export type Widget = {
	-- Lifecycle
	-- position: optional initial position
	-- context: optional context with saved size and save callback (for resizable widgets)
	Create: (parent: Frame, position: UDim2?, context: WidgetCreateContext?) -> Frame?,
	Destroy: () -> (),
	SetVisible: (visible: boolean) -> (),
	IsVisible: () -> boolean,
	GetFrame: () -> Frame?,

	-- Run lifecycle
	OnRunStart: (startTick: number, signName: string, signPosition: Vector3) -> (),
	OnRunEnd: () -> (),

	-- Data updates (ALL required - use empty function if not needed)
	UpdateSpeed: (speed: number) -> (),
	UpdateVelocity: (horizontal: number, vertical: number, total: number) -> (),
	UpdateAcceleration: (rate: number) -> (),
	UpdateAltitude: (altitude: number, verticalVelocity: number) -> (),
	UpdateDistance: (fromStart: number, total: number) -> (),
	UpdateJumpCount: (count: number) -> (),
	UpdateSpinCount: (clockwise: number, counterClockwise: number) -> (),
	UpdateTerrain: (terrainName: string) -> (),
	UpdateDescription: (description: string) -> (),
	UpdateFacing: (degrees: number) -> (),

	-- Event-based updates (for charts that render markers)
	-- category: "avatar" (jumps, swims, speed reasons) or "terrain" (terrain changes)
	OnMarkerEvent: (category: string, timestamp: number, label: string, color: Color3) -> (),
}

-- Factory function type for widget creators
export type WidgetFactory = () -> Widget

-- Type enforcement helper: forces compile-time type checking when returning a widget.
-- The type annotation (widget: Widget) causes Luau to verify all required fields are present.
-- Usage: return widgetTypes.asWidget(widget)
-- If a method is missing, Luau's type checker will report the error in Studio or luau-lsp.
function module.asWidget(widget: Widget): Widget
	return widget
end

-- Partial widget definition - only the methods you want to override
-- All fields are optional; createWidget fills in defaults for missing methods
export type WidgetOverrides = {
	-- Lifecycle (Create is required, others optional)
	Create: (parent: Frame, position: UDim2?, context: WidgetCreateContext?) -> Frame?,
	Destroy: (() -> ())?,
	SetVisible: ((visible: boolean) -> ())?,
	IsVisible: (() -> boolean)?,
	GetFrame: (() -> Frame?)?,

	-- Run lifecycle (optional)
	OnRunStart: ((startTick: number, signName: string, signPosition: Vector3) -> ())?,
	OnRunEnd: (() -> ())?,

	-- Data updates (all optional - defaults are no-ops)
	UpdateSpeed: ((speed: number) -> ())?,
	UpdateVelocity: ((horizontal: number, vertical: number, total: number) -> ())?,
	UpdateAcceleration: ((rate: number) -> ())?,
	UpdateAltitude: ((altitude: number, verticalVelocity: number) -> ())?,
	UpdateDistance: ((fromStart: number, total: number) -> ())?,
	UpdateJumpCount: ((count: number) -> ())?,
	UpdateSpinCount: ((clockwise: number, counterClockwise: number) -> ())?,
	UpdateTerrain: ((terrainName: string) -> ())?,
	UpdateDescription: ((description: string) -> ())?,
	UpdateFacing: ((degrees: number) -> ())?,

	-- Event-based updates (optional)
	OnMarkerEvent: ((category: string, timestamp: number, label: string, color: Color3) -> ())?,
}

-- Default no-op function for widget methods
local function noop() end

-- Create a complete Widget from partial overrides.
-- Provide only the methods you need; defaults are no-ops.
-- Usage:
--   local widget = widgetTypes.createWidget({
--       Create = function(parent, position) ... return frame end,
--       UpdateSpeed = function(speed) label.Text = tostring(speed) end,
--   })
function module.createWidget(overrides: WidgetOverrides): Widget
	-- Track container and visibility for default implementations
	local container: Frame? = nil
	local visible: boolean = true

	-- Wrap Create to capture container reference for default GetFrame
	local originalCreate = overrides.Create
	local wrappedCreate = function(parent: Frame, position: UDim2?, context: WidgetCreateContext?): Frame?
		container = originalCreate(parent, position, context)
		return container
	end

	-- Default SetVisible uses captured container
	local defaultSetVisible = function(vis: boolean)
		visible = vis
		if container then
			container.Visible = vis
		end
	end

	-- Default IsVisible returns tracked state
	local defaultIsVisible = function(): boolean
		return visible
	end

	-- Default GetFrame returns captured container
	local defaultGetFrame = function(): Frame?
		return container
	end

	local widget: Widget = {
		-- Lifecycle
		Create = wrappedCreate,
		Destroy = overrides.Destroy or noop,
		SetVisible = overrides.SetVisible or defaultSetVisible,
		IsVisible = overrides.IsVisible or defaultIsVisible,
		GetFrame = overrides.GetFrame or defaultGetFrame,

		-- Run lifecycle
		OnRunStart = overrides.OnRunStart or noop :: any,
		OnRunEnd = overrides.OnRunEnd or noop,

		-- Data updates (all default to no-ops)
		UpdateSpeed = overrides.UpdateSpeed or noop :: any,
		UpdateVelocity = overrides.UpdateVelocity or noop :: any,
		UpdateAcceleration = overrides.UpdateAcceleration or noop :: any,
		UpdateAltitude = overrides.UpdateAltitude or noop :: any,
		UpdateDistance = overrides.UpdateDistance or noop :: any,
		UpdateJumpCount = overrides.UpdateJumpCount or noop :: any,
		UpdateSpinCount = overrides.UpdateSpinCount or noop :: any,
		UpdateTerrain = overrides.UpdateTerrain or noop :: any,
		UpdateDescription = overrides.UpdateDescription or noop :: any,
		UpdateFacing = overrides.UpdateFacing or noop :: any,

		-- Event-based updates
		OnMarkerEvent = overrides.OnMarkerEvent or noop :: any,
	}

	return widget
end

-- Category definitions
module.CATEGORIES = {
	FULL_UI = "FullUI", -- Complete UI takeover (Classic mode)
	TIMER = "Timer",
	SPEED = "Speed",
	VELOCITY = "Velocity", -- Actual physics velocity (always on, independent of runs)
	SPEED_CHART = "SpeedChart",
	ALTITUDE = "Altitude",
	DISTANCE = "Distance",
	STATS = "Stats",
	TERRAIN = "Terrain",
	COMPASS = "Compass",
	MAPS = "Maps",
	ACCELERATION = "Acceleration",
	RUN_INFO = "RunInfo",
	CONTAINER = "Container",
}

-- Required categories: no "off" option, must always have a style selected
module.REQUIRED_CATEGORIES = {
	[module.CATEGORIES.TIMER] = true,
	[module.CATEGORIES.RUN_INFO] = true,
}

-- Style options per category (including "none")

-- Full UI: complete takeover modes (Classic is the original experience)
module.FULL_UI_STYLES = {
	NONE = "none", -- Use modular widgets below
	CLASSIC = "classic", -- Original full-featured UI
}

-- Timer is required: no "none" option. Users must always have a timer style.
module.TIMER_STYLES = {
	TRANSPARENT_LARGE = "transparent-large",
	TRANSPARENT_SMALL = "transparent-small",
	BLACK_BACKGROUND_LARGE = "black-background-large",
	TRANSPARENT_VERY_LARGE = "transparent-very-large",
	CONDENSER = "condenser",
	STRATA = "strata",
}

module.SPEED_STYLES = {
	NONE = "none",
	NUMERIC = "numeric",
	SPEED_TRANSPARENT_LARGE = "speed-transparent-large",
	SPEED_TRANSPARENT_SMALL = "speed-transparent-small",
	SPEED_BLACK_SMALL = "speed-black-small",
	ANALOG_GAUGE = "analog-gauge",
	HORIZONTAL_BAR = "horizontal-bar",
}

-- Velocity: actual physics velocity from HumanoidRootPart.AssemblyLinearVelocity
-- Unlike Speed (WalkSpeed), this shows real instantaneous movement including gravity effects
-- Velocity widgets are always on, not just during runs
module.VELOCITY_STYLES = {
	NONE = "none",
	NUMBER = "velocity-number", -- Current velocity as numeric display
	LARGE = "velocity-large", -- Large transparent text
	SMALL = "velocity-small", -- Small transparent text
	COMPACT = "velocity-compact", -- Small with dark background
	BAR = "velocity-bar", -- Horizontal bar gauge with vertical indicator
}

module.SPEED_CHART_STYLES = {
	NONE = "none",
	RUN_CHART_10S = "run-chart-10s",
	RUN_CHART_FULL = "run-chart-full",
}

module.ALTITUDE_STYLES = {
	NONE = "none",
	NUMERIC_LARGE = "numeric-large",
	NUMERIC_SMALL = "numeric-small",
	NUMERIC_BLACK = "numeric-black",
	STATS = "stats",
}

module.DISTANCE_STYLES = {
	NONE = "none",
	FROM_START = "from-start",
	TOTAL = "total",
	COMBINED = "combined",
}

module.STATS_STYLES = {
	NONE = "none",
	COMPACT_LINE = "compact-line",
	DETAILED_PANEL = "detailed-panel",
}

module.TERRAIN_STYLES = {
	NONE = "none",
	LEGEND_LIST = "legend-list",
	TERRAIN_INFO = "info",
}

-- Compass shows direction of movement and/or camera facing
module.COMPASS_STYLES = {
	NONE = "none",
	MOVEMENT = "movement", -- Direction player is moving
	CAMERA = "camera", -- Direction camera is facing
	BOTH = "both", -- Both movement and camera direction
}

-- Maps category (journey visualization)
module.MAPS_STYLES = {
	NONE = "none",
	JOURNEY_MAP = "journey-map",
}

module.ACCELERATION_STYLES = {
	NONE = "none",
	COLOR_BAR = "color-bar",
	MOMENTUM_PANEL = "momentum-panel",
}

-- RunInfo is required: no "none" option. Users must always have run info.
-- ALL styles include the expandable description area - variations are in sign name display.
module.RUN_INFO_STYLES = {
	VIEWPORT = "viewport", -- 3D red granite sign (authentic game look)
	CLASSIC = "classic", -- Red background bar with white text
	WHITE_L = "white-l", -- Large white text, transparent
	WHITE_S = "white-s", -- Small white text, transparent
	YELLOW_L = "yellow-l", -- Large yellow text (meColor), transparent
	YELLOW_S = "yellow-s", -- Small yellow text, transparent
}

module.CONTAINER_STYLES = {
	NONE = "none", -- Fully independent positioning
	MINIMAL_PANEL = "minimal-panel",
	DASHBOARD_BAR = "dashboard-bar",
	HUD_FRAME = "hud-frame",
	RETRO_ARCADE = "retro-arcade",
}

-- Custom display order for styles within categories (overrides alphabetical sort)
-- Only categories that need custom order are listed; others use alphabetical
module.STYLE_ORDER = {
	-- Timer: L, S, XL, L Opaque, Condenser, Strata
	[module.CATEGORIES.TIMER] = {
		"transparent-large",
		"transparent-small",
		"transparent-very-large",
		"black-background-large",
		"condenser",
		"strata",
	},
	-- Speed: S, M, L, then other styles
	[module.CATEGORIES.SPEED] = {
		"speed-transparent-small",
		"numeric",
		"speed-transparent-large",
		"speed-black-small",
		"analog-gauge",
		"horizontal-bar",
	},
}

-- Human-readable names for styles
-- Naming conventions for text displays:
--   Size: XL (extra large), L (large), M (medium), S (small)
--   Background: omit = transparent (default), Opaque = dark background
--   Format: "[Size]" or "[Size] Opaque"
module.STYLE_NAMES = {
	-- Full UI
	["none"] = "None",
	["classic"] = "Classic",

	-- Timer (text displays)
	["transparent-large"] = "L",
	["transparent-small"] = "S",
	["black-background-large"] = "L Opaque",
	["transparent-very-large"] = "XL",
	["condenser"] = "Condenser",
	["strata"] = "Strata",

	-- Speed (current value displays)
	["numeric"] = "M",
	["speed-transparent-large"] = "L",
	["speed-transparent-small"] = "S",
	["speed-black-small"] = "S Opaque",
	["analog-gauge"] = "Gauge",
	["horizontal-bar"] = "Bar",

	-- Velocity (text displays + charts)
	["velocity-number"] = "M",
	["velocity-large"] = "L",
	["velocity-small"] = "S",
	["velocity-compact"] = "S Opaque",
	["velocity-bar"] = "Bar",

	-- Speed Chart (time-series charts)
	["run-chart-10s"] = "Last 10s",
	["run-chart-full"] = "Full Run",

	-- Altitude (text displays + charts)
	["numeric-large"] = "L",
	["numeric-small"] = "S",
	["numeric-black"] = "M Opaque",
	["stats"] = "Stats",

	-- Distance
	["from-start"] = "From Start",
	["total"] = "Total",
	["combined"] = "Both",

	-- Stats
	["compact-line"] = "Compact",
	["detailed-panel"] = "Detailed",

	-- Terrain
	["legend-list"] = "Seen",
	["info"] = "Info",

	-- Compass
	["movement"] = "Movement",
	["camera"] = "Camera",
	["both"] = "Both",

	-- Maps
	["journey-map"] = "Journey",

	-- Acceleration
	["color-bar"] = "Bar",
	["momentum-panel"] = "Panel",

	-- Run Info (all include description area, show "from <signname>")
	-- Note: "classic" is already defined for Full UI above with same value
	["viewport"] = "Sign",
	["white-l"] = "White L",
	["white-s"] = "White S",
	["yellow-l"] = "Yellow L",
	["yellow-s"] = "Yellow S",

	-- Container
	["minimal-panel"] = "Minimal",
	["dashboard-bar"] = "Dashboard",
	["hud-frame"] = "HUD",
	["retro-arcade"] = "Retro",
}

-- Category display order and info
-- FULL_UI is the top-level choice: Classic = original experience, None = modular widgets.
-- Container is a meta-choice: when selected, other widgets parent inside it.
-- When Container = None, each widget is independently positioned on screen.
-- Timer and RunInfo are REQUIRED (no "off" option) and appear first in the grid.
-- Order: Required first, then common metrics, then exploration, then advanced
module.CATEGORY_INFO = {
	{
		id = module.CATEGORIES.FULL_UI,
		name = "Full UI",
		description = "Classic = original complete UI. None = pick individual widgets below.",
		styles = module.FULL_UI_STYLES,
	},
	{
		id = module.CATEGORIES.CONTAINER,
		name = "Container",
		description = "Meta-choice: widgets go inside the container. None = free positioning.",
		styles = module.CONTAINER_STYLES,
	},
	-- REQUIRED categories (no "off" option) - Row 1
	{
		id = module.CATEGORIES.TIMER,
		name = "Timer",
		description = "Elapsed time display (required)",
		styles = module.TIMER_STYLES,
	},
	{
		id = module.CATEGORIES.RUN_INFO,
		name = "Run Info",
		description = "Sign name and description (required)",
		styles = module.RUN_INFO_STYLES,
	},
	-- Common metrics - Row 1 continued
	{
		id = module.CATEGORIES.SPEED,
		name = "Speed",
		description = "Current speed display",
		styles = module.SPEED_STYLES,
	},
	{
		id = module.CATEGORIES.DISTANCE,
		name = "Distance",
		description = "Distance traveled",
		styles = module.DISTANCE_STYLES,
	},
	-- Row 2: Stats and positioning
	{
		id = module.CATEGORIES.STATS,
		name = "Stats",
		description = "Jump count, spins, averages",
		styles = module.STATS_STYLES,
	},
	{
		id = module.CATEGORIES.ALTITUDE,
		name = "Altitude",
		description = "Height and vertical movement",
		styles = module.ALTITUDE_STYLES,
	},
	{
		id = module.CATEGORIES.COMPASS,
		name = "Compass",
		description = "Movement and camera direction indicators",
		styles = module.COMPASS_STYLES,
	},
	{
		id = module.CATEGORIES.MAPS,
		name = "Maps",
		description = "Journey path visualization",
		styles = module.MAPS_STYLES,
	},
	-- Row 3: Terrain and advanced
	{
		id = module.CATEGORIES.TERRAIN,
		name = "Terrain",
		description = "Terrain breakdown",
		styles = module.TERRAIN_STYLES,
	},
	{
		id = module.CATEGORIES.VELOCITY,
		name = "Velocity",
		description = "Actual physics velocity (always on, shows gravity effects)",
		styles = module.VELOCITY_STYLES,
	},
	{
		id = module.CATEGORIES.SPEED_CHART,
		name = "Run Charts",
		description = "Speed history over time",
		styles = module.SPEED_CHART_STYLES,
	},
	{
		id = module.CATEGORIES.ACCELERATION,
		name = "Acceleration",
		description = "Speed change indicator",
		styles = module.ACCELERATION_STYLES,
	},
} :: { CategoryInfoEntry }

-- Default configuration: Classic mode (original full-featured UI)
-- When FULL_UI = "classic", all other widgets are hidden and Classic takes over.
-- When FULL_UI = "none", the modular widgets below are used.
-- Timer and RunInfo are required and must have non-none defaults.
module.DEFAULT_CONFIG = {
	[module.CATEGORIES.FULL_UI] = module.FULL_UI_STYLES.CLASSIC,
	[module.CATEGORIES.CONTAINER] = module.CONTAINER_STYLES.NONE,
	[module.CATEGORIES.TIMER] = module.TIMER_STYLES.TRANSPARENT_LARGE, -- Required
	[module.CATEGORIES.RUN_INFO] = module.RUN_INFO_STYLES.VIEWPORT, -- Required
	[module.CATEGORIES.SPEED] = module.SPEED_STYLES.NONE,
	[module.CATEGORIES.VELOCITY] = module.VELOCITY_STYLES.NONE,
	[module.CATEGORIES.SPEED_CHART] = module.SPEED_CHART_STYLES.NONE,
	[module.CATEGORIES.ALTITUDE] = module.ALTITUDE_STYLES.NONE,
	[module.CATEGORIES.DISTANCE] = module.DISTANCE_STYLES.NONE,
	[module.CATEGORIES.STATS] = module.STATS_STYLES.NONE,
	[module.CATEGORIES.TERRAIN] = module.TERRAIN_STYLES.NONE,
	[module.CATEGORIES.COMPASS] = module.COMPASS_STYLES.NONE,
	[module.CATEGORIES.MAPS] = module.MAPS_STYLES.NONE,
	[module.CATEGORIES.ACCELERATION] = module.ACCELERATION_STYLES.NONE,
}

-- Preset configurations for quick setup
-- Timer and RunInfo are required in all presets (no NONE option exists for them)
module.PRESETS = {
	-- RESET_ALL is an action, not a selectable preset - resets to standard defaults
	RESET_ALL = {
		name = "Reset",
		description = "Reset to standard: timer L, sign, speed L",
		config = {
			[module.CATEGORIES.FULL_UI] = module.FULL_UI_STYLES.NONE,
			[module.CATEGORIES.CONTAINER] = module.CONTAINER_STYLES.NONE,
			[module.CATEGORIES.TIMER] = module.TIMER_STYLES.TRANSPARENT_LARGE,
			[module.CATEGORIES.RUN_INFO] = module.RUN_INFO_STYLES.VIEWPORT,
			[module.CATEGORIES.SPEED] = module.SPEED_STYLES.SPEED_TRANSPARENT_LARGE,
			[module.CATEGORIES.VELOCITY] = module.VELOCITY_STYLES.NONE,
			[module.CATEGORIES.SPEED_CHART] = module.SPEED_CHART_STYLES.NONE,
			[module.CATEGORIES.ALTITUDE] = module.ALTITUDE_STYLES.NONE,
			[module.CATEGORIES.DISTANCE] = module.DISTANCE_STYLES.NONE,
			[module.CATEGORIES.STATS] = module.STATS_STYLES.NONE,
			[module.CATEGORIES.TERRAIN] = module.TERRAIN_STYLES.NONE,
			[module.CATEGORIES.COMPASS] = module.COMPASS_STYLES.NONE,
			[module.CATEGORIES.MAPS] = module.MAPS_STYLES.NONE,
			[module.CATEGORIES.ACCELERATION] = module.ACCELERATION_STYLES.NONE,
		},
	},
	-- Selectable presets below
	BALANCED = {
		name = "Balanced",
		description = "Good mix of info without clutter",
		config = {
			[module.CATEGORIES.FULL_UI] = module.FULL_UI_STYLES.NONE,
			[module.CATEGORIES.CONTAINER] = module.CONTAINER_STYLES.NONE,
			[module.CATEGORIES.TIMER] = module.TIMER_STYLES.TRANSPARENT_LARGE,
			[module.CATEGORIES.RUN_INFO] = module.RUN_INFO_STYLES.VIEWPORT,
			[module.CATEGORIES.SPEED] = module.SPEED_STYLES.NUMERIC,
			[module.CATEGORIES.VELOCITY] = module.VELOCITY_STYLES.NONE,
			[module.CATEGORIES.SPEED_CHART] = module.SPEED_CHART_STYLES.NONE,
			[module.CATEGORIES.ALTITUDE] = module.ALTITUDE_STYLES.NUMERIC_SMALL,
			[module.CATEGORIES.DISTANCE] = module.DISTANCE_STYLES.FROM_START,
			[module.CATEGORIES.STATS] = module.STATS_STYLES.COMPACT_LINE,
			[module.CATEGORIES.TERRAIN] = module.TERRAIN_STYLES.NONE,
			[module.CATEGORIES.COMPASS] = module.COMPASS_STYLES.MOVEMENT,
			[module.CATEGORIES.MAPS] = module.MAPS_STYLES.NONE,
			[module.CATEGORIES.ACCELERATION] = module.ACCELERATION_STYLES.NONE,
		},
	},
	MAPPERS = {
		name = "Mappers",
		description = "For exploration: maps, terrain, compass",
		config = {
			[module.CATEGORIES.FULL_UI] = module.FULL_UI_STYLES.NONE,
			[module.CATEGORIES.CONTAINER] = module.CONTAINER_STYLES.NONE,
			[module.CATEGORIES.TIMER] = module.TIMER_STYLES.TRANSPARENT_SMALL,
			[module.CATEGORIES.RUN_INFO] = module.RUN_INFO_STYLES.WHITE_S,
			[module.CATEGORIES.SPEED] = module.SPEED_STYLES.NUMERIC,
			[module.CATEGORIES.VELOCITY] = module.VELOCITY_STYLES.NONE,
			[module.CATEGORIES.SPEED_CHART] = module.SPEED_CHART_STYLES.NONE,
			[module.CATEGORIES.ALTITUDE] = module.ALTITUDE_STYLES.NUMERIC_SMALL,
			[module.CATEGORIES.DISTANCE] = module.DISTANCE_STYLES.COMBINED,
			[module.CATEGORIES.STATS] = module.STATS_STYLES.NONE,
			[module.CATEGORIES.TERRAIN] = module.TERRAIN_STYLES.LEGEND_LIST,
			[module.CATEGORIES.COMPASS] = module.COMPASS_STYLES.BOTH,
			[module.CATEGORIES.MAPS] = module.MAPS_STYLES.JOURNEY_MAP,
			[module.CATEGORIES.ACCELERATION] = module.ACCELERATION_STYLES.NONE,
		},
	},
	RACING = {
		name = "Racing",
		description = "Minimal distractions, focus on time",
		config = {
			[module.CATEGORIES.FULL_UI] = module.FULL_UI_STYLES.NONE,
			[module.CATEGORIES.CONTAINER] = module.CONTAINER_STYLES.NONE,
			[module.CATEGORIES.TIMER] = module.TIMER_STYLES.TRANSPARENT_VERY_LARGE,
			[module.CATEGORIES.RUN_INFO] = module.RUN_INFO_STYLES.YELLOW_L,
			[module.CATEGORIES.SPEED] = module.SPEED_STYLES.NONE,
			[module.CATEGORIES.VELOCITY] = module.VELOCITY_STYLES.NONE,
			[module.CATEGORIES.SPEED_CHART] = module.SPEED_CHART_STYLES.NONE,
			[module.CATEGORIES.ALTITUDE] = module.ALTITUDE_STYLES.NONE,
			[module.CATEGORIES.DISTANCE] = module.DISTANCE_STYLES.NONE,
			[module.CATEGORIES.STATS] = module.STATS_STYLES.NONE,
			[module.CATEGORIES.TERRAIN] = module.TERRAIN_STYLES.NONE,
			[module.CATEGORIES.COMPASS] = module.COMPASS_STYLES.NONE,
			[module.CATEGORIES.MAPS] = module.MAPS_STYLES.NONE,
			[module.CATEGORIES.ACCELERATION] = module.ACCELERATION_STYLES.NONE,
		},
	},
	CLASSIC = {
		name = "Classic",
		description = "Original full-featured UI",
		config = {
			[module.CATEGORIES.FULL_UI] = module.FULL_UI_STYLES.CLASSIC,
			[module.CATEGORIES.CONTAINER] = module.CONTAINER_STYLES.NONE,
			[module.CATEGORIES.TIMER] = module.TIMER_STYLES.TRANSPARENT_LARGE,
			[module.CATEGORIES.RUN_INFO] = module.RUN_INFO_STYLES.VIEWPORT,
			[module.CATEGORIES.SPEED] = module.SPEED_STYLES.NONE,
			[module.CATEGORIES.VELOCITY] = module.VELOCITY_STYLES.NONE,
			[module.CATEGORIES.SPEED_CHART] = module.SPEED_CHART_STYLES.NONE,
			[module.CATEGORIES.ALTITUDE] = module.ALTITUDE_STYLES.NONE,
			[module.CATEGORIES.DISTANCE] = module.DISTANCE_STYLES.NONE,
			[module.CATEGORIES.STATS] = module.STATS_STYLES.NONE,
			[module.CATEGORIES.TERRAIN] = module.TERRAIN_STYLES.NONE,
			[module.CATEGORIES.COMPASS] = module.COMPASS_STYLES.NONE,
			[module.CATEGORIES.MAPS] = module.MAPS_STYLES.NONE,
			[module.CATEGORIES.ACCELERATION] = module.ACCELERATION_STYLES.NONE,
		},
	},
} :: { [string]: PresetEntry }

-- Selectable presets shown in the picker UI (RESET_ALL is an action button, not here)
module.PICKER_PRESETS = { "BALANCED", "MAPPERS", "RACING" }

-- Check if a config matches a preset exactly
function module.GetMatchingPreset(config: { [string]: string }): string?
	for presetKey, preset in pairs(module.PRESETS) do
		local matches = true
		for category, style in pairs(preset.config) do
			if config[category] ~= style then
				matches = false
				break
			end
		end
		-- Also check that config has no extra categories beyond the preset
		if matches then
			for category, style in pairs(config) do
				if preset.config[category] ~= style then
					matches = false
					break
				end
			end
		end
		if matches then
			return presetKey
		end
	end
	return nil
end

_annotate("end")
return module
