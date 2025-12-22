--!strict
-- widgetComposer.lua (ReplicatedStorage/gui/activeRunWidgets/widgetComposer.lua)
-- Central orchestrator for the modular widget system.
-- Manages widget lifecycle, data routing, and configuration.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local _TweenService = game:GetService("TweenService")

local colors = require(game.ReplicatedStorage.util.colors)
local dragUtil = require(game.ReplicatedStorage.gui.activeRunWidgets.dragUtil)
local highlightUtils = require(game.ReplicatedStorage.gui.activeRunWidgets.highlightUtils)
local runStats = require(game.ReplicatedStorage.gui.activeRunWidgets.runStats)
local settings = require(game.ReplicatedStorage.settings)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local widgetTypes = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetTypes)

local localPlayer = Players.LocalPlayer

-- Speed reason colors (for chart markers)
-- These are game-specific colors for different movement abilities/states
local SPEED_REASON_COLORS: { [string]: Color3 } = {
	Walking = colors.defaultGrey,
	Swimming = colors.hudCyan,
	Lava = colors.orangeAccent,
	Prefontaine = colors.lightGreen,
	Bolt = Color3.fromRGB(255, 215, 0), -- Gold
	Lavaslug = colors.orangeAccent,
	["Cold Mold"] = Color3.fromRGB(100, 150, 200), -- Cold blue
	["Cold Mold (water)"] = Color3.fromRGB(100, 180, 220),
	["Cold Mold (lava)"] = Color3.fromRGB(180, 100, 80),
	Fosbury = colors.lightGreen,
	Salekhard = Color3.fromRGB(180, 200, 220), -- Ice
	Hypergravity = Color3.fromRGB(150, 50, 150), -- Purple
	Zoom = Color3.fromRGB(50, 200, 50), -- Bright green
}

type WidgetFactory = () -> widgetTypes.Widget

local module = {}

-- Registry of widget factories by category and style
local widgetRegistry: { [string]: { [string]: WidgetFactory } } = {}

-- Currently active widgets (using `any` to avoid complex type inference with pairs())
local activeWidgets: { [string]: any } = {}
local widgetFrames: { [string]: Frame } = {}
local activeStyles: { [string]: string } = {} -- Track what style each category is currently showing
local dragCleanups: { () -> () } = {}

-- Main screen gui and container
local screenGui: ScreenGui? = nil
local containerFrame: Frame? = nil

-- Container widget and its frame (special handling for container-as-parent)
local containerWidget: any = nil
local containerWidgetFrame: Frame? = nil

-- Run state
local isRunning: boolean = false
local currentStartTick: number = 0
local currentSignName: string = ""
local currentSignPosition: Vector3 = Vector3.new(0, 0, 0)
local renderConnection: RBXScriptConnection? = nil

-- Event tracking indices (for incremental event processing)
local lastAvatarEventIndex: number = 0
local lastTerrainEventIndex: number = 0
local activeSpeedReasons: { [string]: boolean } = {} -- Track currently active reasons

-- Position storage key prefix
local POSITION_PREFIX = "widget_pos_"
local SIZE_PREFIX = "widget_size_"

-- Register a widget factory for a category/style combination
function module.RegisterWidget(category: string, style: string, factory: WidgetFactory)
	if not widgetRegistry[category] then
		widgetRegistry[category] = {}
	end
	widgetRegistry[category][style] = factory
	_annotate(string.format("Registered widget: %s/%s", category, style))
end

-- Style migrations: old style names → new style names
-- Add entries here when renaming styles to preserve user preferences
local STYLE_MIGRATIONS: { [string]: string } = {
	["pulse-10s"] = "run-chart-10s",
	["pulse-full"] = "run-chart-full",
}

-- Get the current widget configuration from settings
-- Validates that required categories (Timer, RunInfo) have non-"none" values
function module.GetConfiguration(): { [string]: string }
	local configSetting = settings.GetSettingByName(settingEnums.settingDefinitions.WIDGET_CONFIG.name)
	local config: { [string]: string }
	if configSetting and configSetting.luaValue then
		config = configSetting.luaValue :: { [string]: string }
	else
		config = widgetTypes.DEFAULT_CONFIG
	end

	local needsSave = false

	-- Migrate renamed styles to preserve user preferences
	for category, style in pairs(config) do
		local newStyle = STYLE_MIGRATIONS[style]
		if newStyle then
			_annotate(string.format("Migrating style '%s' → '%s' in category '%s'", style, newStyle, category))
			config[category] = newStyle
			needsSave = true
		end
	end

	-- Validate required categories - fix legacy "none" values
	for category, isRequired in pairs(widgetTypes.REQUIRED_CATEGORIES) do
		if isRequired and (config[category] == "none" or config[category] == nil) then
			-- Get first available style for this category
			local defaultStyle = widgetTypes.DEFAULT_CONFIG[category]
			if defaultStyle and defaultStyle ~= "none" then
				_annotate(string.format("Fixing required category '%s': was '%s', now '%s'", category, tostring(config[category]), defaultStyle))
				config[category] = defaultStyle
				needsSave = true
			end
		end
	end

	-- Save corrected config if we fixed any legacy values
	if needsSave then
		module.SaveConfiguration(config)
	end

	return config
end

-- Save widget configuration to settings
function module.SaveConfiguration(config: { [string]: string })
	-- Log configuration being saved
	local configSummary = {}
	for category, style in pairs(config) do
		table.insert(configSummary, string.format("%s=%s", category, style))
	end
	_annotate(string.format("Saving widget config: {%s}", table.concat(configSummary, ", ")))

	local setting = {
		name = settingEnums.settingDefinitions.WIDGET_CONFIG.name,
		domain = settingEnums.settingDomains.USERSETTINGS,
		kind = settingEnums.settingKinds.LUA,
		luaValue = config,
	}
	settings.SetSetting(setting)
end

-- Hover state tracking - highlight persists while mouse is over EITHER widget OR card
local cardHoverState: { [string]: boolean } = {} -- Is the picker card being hovered?
local widgetHoverState: { [string]: boolean } = {} -- Is the widget being hovered?

-- Callback for reverse highlighting (widget hover -> picker card highlight)
local onWidgetHoverCallback: ((category: string, isHovering: boolean) -> ())? = nil

function module.SetWidgetHoverCallback(callback: ((category: string, isHovering: boolean) -> ())?)
	local wasOpen = onWidgetHoverCallback ~= nil
	local isNowOpen = callback ~= nil

	onWidgetHoverCallback = callback

	-- Create ghost placeholders when picker opens
	if not wasOpen and isNowOpen then
		module.CreateGhostPlaceholders()
		-- Trigger hover check for all widgets in case mouse is already over one
		task.defer(function()
			module.CheckAllWidgetHovers()
		end)
	-- Destroy ghosts when picker closes
	elseif wasOpen and not isNowOpen then
		module.DestroyGhostPlaceholders()
	end
end

-- Check if picker is open (for efficiency - skip hover detection when closed)
function module.IsPickerOpen(): boolean
	return onWidgetHoverCallback ~= nil
end

-- Check if either card or widget is hovered for a category
function module.IsEitherHovered(category: string): boolean
	return cardHoverState[category] == true or widgetHoverState[category] == true
end

-- Update card hover state (called from run widget picker)
function module.SetCardHover(category: string, isHovering: boolean)
	cardHoverState[category] = isHovering
end

-- Update widget hover state (called internally)
function module.SetWidgetHover(category: string, isHovering: boolean)
	widgetHoverState[category] = isHovering
end

-- Get current hover states (for debugging/external use)
function module.GetHoverStates(): ({ [string]: boolean }, { [string]: boolean })
	return cardHoverState, widgetHoverState
end

-- Reset all hover states (called when picker closes)
function module.ResetHoverStates()
	cardHoverState = {}
	widgetHoverState = {}
end

-- Registry of hover check functions for each widget category
-- Used to trigger a batch check when picker opens (mouse may already be over a widget)
local widgetHoverChecks: { [string]: () -> () } = {}

function module.RegisterWidgetHoverCheck(category: string, checkFn: () -> ())
	widgetHoverChecks[category] = checkFn
end

function module.UnregisterWidgetHoverCheck(category: string)
	widgetHoverChecks[category] = nil
end

-- Trigger all widget hover checks (called when picker opens)
function module.CheckAllWidgetHovers()
	for _, checkFn in pairs(widgetHoverChecks) do
		checkFn()
	end
end

-- Ghost placeholder frames - shown when picker is open but widget doesn't exist
-- These help users see where widgets *would* appear when configuring outside a run
local ghostFrames: { [string]: Frame } = {}

-- Default sizes for ghost placeholders (approximate typical widget sizes)
local GHOST_DEFAULT_SIZES: { [string]: Vector2 } = {
	[widgetTypes.CATEGORIES.TIMER] = Vector2.new(180, 50),
	[widgetTypes.CATEGORIES.SPEED] = Vector2.new(100, 40),
	[widgetTypes.CATEGORIES.VELOCITY] = Vector2.new(100, 40),
	[widgetTypes.CATEGORIES.SPEED_CHART] = Vector2.new(200, 120),
	[widgetTypes.CATEGORIES.ALTITUDE] = Vector2.new(100, 40),
	[widgetTypes.CATEGORIES.DISTANCE] = Vector2.new(120, 30),
	[widgetTypes.CATEGORIES.STATS] = Vector2.new(150, 60),
	[widgetTypes.CATEGORIES.TERRAIN] = Vector2.new(80, 80),
	[widgetTypes.CATEGORIES.COMPASS] = Vector2.new(60, 60),
	[widgetTypes.CATEGORIES.MAPS] = Vector2.new(150, 150),
	[widgetTypes.CATEGORIES.ACCELERATION] = Vector2.new(80, 40),
	[widgetTypes.CATEGORIES.RUN_INFO] = Vector2.new(200, 40),
}

local function getGhostSize(category: string): Vector2
	return GHOST_DEFAULT_SIZES[category] or Vector2.new(100, 50)
end

-- Create a ghost marker for a category (invisible until highlighted)
local function createGhostFrame(category: string, parent: Instance): Frame?
	-- Skip categories that don't make sense as placeholders
	if category == widgetTypes.CATEGORIES.FULL_UI or category == widgetTypes.CATEGORIES.CONTAINER then
		return nil
	end

	-- Get position (saved or default)
	local positions = {}
	local posSetting = settings.GetSettingByName(settingEnums.settingDefinitions.ACTIVE_RUN_WIDGET_POSITIONS.name)
	if posSetting and posSetting.luaValue then
		positions = posSetting.luaValue :: { [string]: any }
	end
	local posKey = "widget_pos_" .. category
	local position: UDim2 = positions[posKey] :: UDim2?
		or ({
			[widgetTypes.CATEGORIES.TIMER] = UDim2.fromScale(0.5, 0.15),
			[widgetTypes.CATEGORIES.SPEED] = UDim2.fromScale(0.9, 0.6),
			[widgetTypes.CATEGORIES.VELOCITY] = UDim2.fromScale(0.1, 0.6),
			[widgetTypes.CATEGORIES.SPEED_CHART] = UDim2.fromScale(0.85, 0.5),
			[widgetTypes.CATEGORIES.ALTITUDE] = UDim2.fromScale(0.1, 0.5),
			[widgetTypes.CATEGORIES.DISTANCE] = UDim2.fromScale(0.5, 0.88),
			[widgetTypes.CATEGORIES.STATS] = UDim2.fromScale(0.1, 0.35),
			[widgetTypes.CATEGORIES.TERRAIN] = UDim2.fromScale(0.88, 0.35),
			[widgetTypes.CATEGORIES.COMPASS] = UDim2.fromScale(0.06, 0.25),
			[widgetTypes.CATEGORIES.MAPS] = UDim2.fromScale(0.12, 0.55),
			[widgetTypes.CATEGORIES.ACCELERATION] = UDim2.fromScale(0.92, 0.5),
			[widgetTypes.CATEGORIES.RUN_INFO] = UDim2.fromScale(0.5, 0.18),
		})[category]
		or UDim2.fromScale(0.5, 0.5)

	local size = getGhostSize(category)

	-- Completely invisible frame - only shows when highlighted
	local ghost = Instance.new("Frame")
	ghost.Name = "Ghost_" .. category
	ghost.Size = UDim2.fromOffset(size.X, size.Y)
	ghost.Position = position
	ghost.AnchorPoint = Vector2.new(0.5, 0)
	ghost.BackgroundTransparency = 1
	ghost.BorderSizePixel = 0
	ghost.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = ghost

	return ghost
end

-- Create ghost placeholders for all categories that don't have visible active widgets
function module.CreateGhostPlaceholders()
	-- Need the screen gui to parent ghosts
	if not screenGui then
		return
	end

	-- Find the widget parent (similar to widget creation)
	local widgetParent: Instance = screenGui
	if containerWidgetFrame then
		widgetParent = containerWidgetFrame
	end

	-- Create ghosts for categories without visible active widgets
	for _, catInfo in ipairs(widgetTypes.CATEGORY_INFO) do
		local category = catInfo.id
		-- Skip full UI and container
		if category == widgetTypes.CATEGORIES.FULL_UI or category == widgetTypes.CATEGORIES.CONTAINER then
			continue
		end

		-- Check if widget exists AND is visible - if so, no ghost needed
		local frame = widgetFrames[category]
		if frame and frame.Parent and frame.Visible then
			continue
		end

		-- If widget exists but is hidden, use its position for the ghost
		local ghost: Frame?
		if frame and frame.Parent then
			-- Widget exists but is hidden - create ghost at widget's position
			local ghostFrame = Instance.new("Frame")
			ghostFrame.Name = "Ghost_" .. category
			ghostFrame.Size = frame.Size
			ghostFrame.Position = frame.Position
			ghostFrame.AnchorPoint = frame.AnchorPoint
			ghostFrame.BackgroundTransparency = 1
			ghostFrame.BorderSizePixel = 0
			ghostFrame.Parent = widgetParent

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = ghostFrame

			ghost = ghostFrame
		else
			-- No widget exists - use default ghost creation
			ghost = createGhostFrame(category, widgetParent)
		end

		if ghost then
			ghostFrames[category] = ghost
		end
	end

	-- Count ghosts (dictionary, not array)
	local ghostCount = 0
	for _ in pairs(ghostFrames) do
		ghostCount = ghostCount + 1
	end
	_annotate(string.format("Created %d ghost placeholders", ghostCount))
end

-- Destroy all ghost placeholders
function module.DestroyGhostPlaceholders()
	for _, ghost in pairs(ghostFrames) do
		-- Clear highlight (highlightUtils handles cleanup)
		highlightUtils.ClearHighlight(ghost, true)
		-- Destroy frame
		if ghost and ghost.Parent then
			ghost:Destroy()
		end
	end
	ghostFrames = {}
	_annotate("Destroyed ghost placeholders")
end

-- Highlight a ghost placeholder (delegates to highlightUtils)
local function highlightGhost(category: string, aggressive: boolean?)
	local ghost = ghostFrames[category]
	if not ghost or not ghost.Parent then
		return
	end
	local mode: highlightUtils.HighlightMode = if aggressive then "aggressive" else "normal"
	highlightUtils.Highlight(ghost, mode)
end

-- Clear ghost highlight (delegates to highlightUtils)
local function clearGhostHighlight(category: string, immediate: boolean?)
	local ghost = ghostFrames[category]
	if ghost then
		highlightUtils.ClearHighlight(ghost, immediate)
	end
end

function module.HighlightWidget(category: string, aggressive: boolean?)
	local frame = widgetFrames[category]
	-- If no real widget or widget is not visible, try ghost placeholder
	if not frame or not frame.Parent or not frame.Visible then
		highlightGhost(category, aggressive)
		return
	end

	local mode: highlightUtils.HighlightMode = if aggressive then "aggressive" else "normal"
	highlightUtils.Highlight(frame, mode)
end

function module.ClearHighlight(category: string, immediate: boolean?)
	-- Clear ghost highlight if present
	clearGhostHighlight(category, immediate)

	-- Clear widget highlight if present
	local frame = widgetFrames[category]
	if frame then
		highlightUtils.ClearHighlight(frame, immediate)
	end
end

function module.ClearAllHighlights()
	-- Clear all widget highlights
	for _, frame in pairs(widgetFrames) do
		highlightUtils.ClearHighlight(frame, true)
	end
	-- Clear all ghost highlights
	for category, _ in pairs(ghostFrames) do
		clearGhostHighlight(category, true)
	end
end

-- Flash highlight (for toggle events) - pulses then fades
function module.FlashHighlight(category: string)
	local frame = widgetFrames[category]
	if not frame or not frame.Parent then
		return
	end
	highlightUtils.FlashHighlight(frame)
end

-- Get widget frame by category (for external hover detection setup)
function module.GetWidgetFrame(category: string): Frame?
	return widgetFrames[category]
end

-- Notify that a widget is being hovered (called from widget frames)
-- Only triggers highlighting when the picker is open (callback is set)
function module.NotifyWidgetHover(category: string, isHovering: boolean)
	-- Update widget hover state
	widgetHoverState[category] = isHovering

	-- Only do highlighting when picker is open
	if not onWidgetHoverCallback then
		return
	end

	-- Highlight/clear the widget itself (bidirectional highlighting)
	if isHovering then
		module.HighlightWidget(category)
	elseif not module.IsEitherHovered(category) then
		module.ClearHighlight(category, false)
	end

	-- Notify the picker to highlight/clear the card
	onWidgetHoverCallback(category, isHovering)
end

-- Get saved widget positions and sizes (mixed table - positions are UDim2, sizes are {width,height})
local function getPositions(): { [string]: any }
	local posSetting = settings.GetSettingByName(settingEnums.settingDefinitions.ACTIVE_RUN_WIDGET_POSITIONS.name)
	if posSetting and posSetting.luaValue then
		local positions = posSetting.luaValue :: { [string]: any }
		local widgetPosCount = 0
		local otherCount = 0
		for key, value in pairs(positions) do
			if string.find(key, "widget_pos_") then
				widgetPosCount = widgetPosCount + 1
				-- Log actual position values for widget positions (now scale-based)
				local posStr = "?"
				if typeof(value) == "UDim2" then
					posStr = string.format("scale(%.3f,%.3f)", value.X.Scale, value.Y.Scale)
				end
				_annotate(string.format("LOAD POSITION: %s = %s", key, posStr))
			else
				otherCount = otherCount + 1
			end
		end
		_annotate(string.format("getPositions: loaded %d widget positions, %d other entries", widgetPosCount, otherCount))
		return positions
	end
	_annotate("getPositions: NO SAVED POSITIONS FOUND - using defaults")
	return {}
end

-- Format UDim2 for logging (shows both scale and offset)
local function formatUDim2(pos: UDim2): string
	if pos.X.Scale ~= 0 or pos.Y.Scale ~= 0 then
		return string.format("scale(%.3f, %.3f)", pos.X.Scale, pos.Y.Scale)
	else
		return string.format("offset(%.0f, %.0f)", pos.X.Offset, pos.Y.Offset)
	end
end

-- Minimum visible portion of widget that must be on screen (pixels)
local MIN_VISIBLE_PIXELS = 50

-- Clamp a saved position to ensure the widget is visible on the current screen.
-- This handles cases where positions were saved on a larger monitor.
-- Takes the widget's expected size to ensure at least MIN_VISIBLE_PIXELS are visible.
local function clampPositionToScreen(pos: UDim2, widgetSize: Vector2?): UDim2
	local camera = workspace.CurrentCamera
	if not camera then
		return pos
	end

	local viewportSize = camera.ViewportSize
	local size = widgetSize or Vector2.new(200, 100) -- Conservative default if size unknown

	-- Convert UDim2 to absolute position
	local absoluteX = pos.X.Scale * viewportSize.X + pos.X.Offset
	local absoluteY = pos.Y.Scale * viewportSize.Y + pos.Y.Offset

	-- Calculate bounds that keep at least MIN_VISIBLE_PIXELS of the widget on screen
	-- Widget can go negative (off left/top) but must have some portion visible
	local minX = -(size.X - MIN_VISIBLE_PIXELS)
	local minY = -(size.Y - MIN_VISIBLE_PIXELS)
	local maxX = viewportSize.X - MIN_VISIBLE_PIXELS
	local maxY = viewportSize.Y - MIN_VISIBLE_PIXELS

	local clampedX = math.clamp(absoluteX, minX, maxX)
	local clampedY = math.clamp(absoluteY, minY, maxY)

	-- Only return a new UDim2 if clamping actually changed the position
	if clampedX ~= absoluteX or clampedY ~= absoluteY then
		_annotate(string.format("CLAMPED offscreen position: (%.0f,%.0f) -> (%.0f,%.0f) viewport=%.0fx%.0f", absoluteX, absoluteY, clampedX, clampedY, viewportSize.X, viewportSize.Y))
		return UDim2.fromOffset(clampedX, clampedY)
	end

	return pos
end

-- Check if a position is offset-based (old format) rather than scale-based
-- Offset-based: has non-zero offset and zero scale (e.g., UDim2.fromOffset(500, 200))
-- Scale-based: has non-zero scale and zero offset (e.g., UDim2.new(0.5, 0, 0.2, 0))
local function isOffsetBasedPosition(pos: UDim2): boolean
	local hasOffset = pos.X.Offset ~= 0 or pos.Y.Offset ~= 0
	local hasScale = pos.X.Scale ~= 0 or pos.Y.Scale ~= 0
	return hasOffset and not hasScale
end

-- Convert absolute position to scale-based UDim2 for monitor-independent saving
local function absoluteToScale(position: UDim2): UDim2
	local camera = workspace.CurrentCamera
	if not camera then
		return position
	end
	local viewportSize = camera.ViewportSize
	-- Convert to absolute first (handles both scale and offset)
	local absoluteX = position.X.Scale * viewportSize.X + position.X.Offset
	local absoluteY = position.Y.Scale * viewportSize.Y + position.Y.Offset
	-- Then to pure scale
	local scaleX = absoluteX / viewportSize.X
	local scaleY = absoluteY / viewportSize.Y
	return UDim2.fromScale(scaleX, scaleY)
end

-- Save a widget position (converts to scale-based for monitor independence)
local function savePosition(widgetKey: string, position: UDim2)
	local fullKey = POSITION_PREFIX .. widgetKey
	-- Convert incoming position (often offset-based from drag) to scale
	local scalePosition = absoluteToScale(position)
	_annotate(string.format("Saving position for %s: scale(%.3f, %.3f)", fullKey, scalePosition.X.Scale, scalePosition.Y.Scale))

	local positions = getPositions()
	positions[fullKey] = scalePosition
	local setting = {
		name = settingEnums.settingDefinitions.ACTIVE_RUN_WIDGET_POSITIONS.name,
		domain = settingEnums.settingDomains.USERSETTINGS,
		kind = settingEnums.settingKinds.LUA,
		luaValue = positions,
	}
	local result = settings.SetSetting(setting)
	if result then
		_annotate(string.format("Position saved successfully for %s", fullKey))
	else
		_annotate(string.format("Position save FAILED for %s", fullKey))
	end
end

-- Size saved format (scale-based for monitor independence)
type SavedSizeScale = { widthScale: number, heightScale: number }

-- Get saved widget sizes (stored alongside positions for simplicity)
-- Returns scale-based sizes only - rejects old pixel-based format
local function getSizes(): { [string]: SavedSizeScale }
	local posSetting = settings.GetSettingByName(settingEnums.settingDefinitions.ACTIVE_RUN_WIDGET_POSITIONS.name)
	if posSetting and posSetting.luaValue then
		-- Sizes are stored in the same table with SIZE_PREFIX
		local all = posSetting.luaValue :: { [string]: any }
		local sizes: { [string]: SavedSizeScale } = {}
		for key, value in pairs(all) do
			if string.find(key, SIZE_PREFIX) then
				local savedValue = value :: { [string]: number }
				if savedValue.widthScale then
					-- Valid scale-based format
					sizes[key] = savedValue :: SavedSizeScale
				else
					-- Old pixel-based format {width, height} - reject it
					_annotate(string.format("REJECTED offset-based size for %s - will use default", key))
				end
			end
		end
		return sizes
	end
	return {}
end

-- Convert absolute size to scale-based for monitor-independent saving
local function sizeToScale(width: number, height: number): { widthScale: number, heightScale: number }
	local camera = workspace.CurrentCamera
	if not camera then
		return { widthScale = 0, heightScale = 0 }
	end
	local viewportSize = camera.ViewportSize
	return {
		widthScale = width / viewportSize.X,
		heightScale = height / viewportSize.Y,
	}
end

-- Save a widget size (converts to scale-based for monitor independence)
local function saveSize(widgetKey: string, width: number, height: number)
	local positions = getPositions() -- Get all settings (positions + sizes share table)
	-- Convert to scale-based for monitor independence
	local scaleSize = sizeToScale(width, height)
	positions[SIZE_PREFIX .. widgetKey] = scaleSize
	local setting = {
		name = settingEnums.settingDefinitions.ACTIVE_RUN_WIDGET_POSITIONS.name,
		domain = settingEnums.settingDomains.USERSETTINGS,
		kind = settingEnums.settingKinds.LUA,
		luaValue = positions,
	}
	settings.SetSetting(setting)
	_annotate(string.format("Saved size for %s: scale(%.3f, %.3f)", widgetKey, scaleSize.widthScale, scaleSize.heightScale))
end

-- Get saved size for a widget (returns absolute pixels, converting from saved scale)
function module.GetSavedSize(category: string, style: string): { width: number, height: number }?
	local sizes = getSizes()
	local key = SIZE_PREFIX .. category .. "_" .. style
	local scaleSize = sizes[key]
	if not scaleSize then
		return nil
	end
	-- Convert from scale back to absolute pixels for current viewport
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local viewportSize = camera.ViewportSize
	return {
		width = scaleSize.widthScale * viewportSize.X,
		height = scaleSize.heightScale * viewportSize.Y,
	}
end

-- Save size for a widget (exposed for widgets that handle their own resizing)
function module.SaveSize(category: string, style: string, width: number, height: number)
	saveSize(category .. "_" .. style, width, height)
end

-- Use widget_size_ prefix because server only persists widget_pos_ and widget_size_ keys
-- We encode filter state as a fake "size" entry with special structure
local STATE_PREFIX = "widget_size_filter_"

-- Get saved state for a widget
function module.GetSavedState(category: string, style: string): { [string]: any }?
	local positions = getPositions() -- Reuse the same storage mechanism
	local key = STATE_PREFIX .. category .. "_" .. style

	-- Debug: only log for SpeedChart
	local isSpeedChart = (category == "SpeedChart")
	if isSpeedChart then
		-- Log the FULL positions table being loaded
		_annotate("GetSavedState: FULL POSITIONS TABLE LOADED:")
		for posKey, posVal in pairs(positions) do
			if typeof(posVal) == "table" then
				local tableStr = ""
				for tk, tv in pairs(posVal) do
					tableStr = tableStr .. string.format("%s=%s ", tostring(tk), tostring(tv))
				end
				_annotate(string.format("  %s = {%s}", posKey, tableStr))
			else
				_annotate(string.format("  %s = %s", posKey, tostring(posVal)))
			end
		end

		local stateKeyCount = 0
		for k, _ in pairs(positions) do
			if string.find(k, STATE_PREFIX) then
				stateKeyCount = stateKeyCount + 1
				_annotate(string.format("GetSavedState: positions has key=%s", k))
			end
		end
		_annotate(string.format("GetSavedState: found %d '%s*' keys total", stateKeyCount, STATE_PREFIX))
	end

	local state = positions[key]
	if isSpeedChart then
		if state then
			local dataStr = ""
			for k, v in pairs(state) do
				dataStr = dataStr .. string.format("%s=%s ", k, tostring(v))
			end
			_annotate(string.format("GetSavedState: FOUND key=%s data={%s}", key, dataStr))
		else
			_annotate(string.format("GetSavedState: NO state for key=%s", key))
		end
	end
	return state
end

-- Save state for a widget
function module.SaveState(category: string, style: string, widgetState: { [string]: any })
	local positions = getPositions()
	local key = STATE_PREFIX .. category .. "_" .. style
	positions[key] = widgetState

	-- Debug: only log for SpeedChart
	local isSpeedChart = (category == "SpeedChart")
	if isSpeedChart then
		-- Log the actual data being saved
		local dataStr = ""
		for k, v in pairs(widgetState) do
			dataStr = dataStr .. string.format("%s=%s ", k, tostring(v))
		end
		_annotate(string.format("SaveState: key=%s data={%s}", key, dataStr))

		-- Log the FULL positions table being saved
		_annotate("SaveState: FULL POSITIONS TABLE BEING SAVED:")
		for posKey, posVal in pairs(positions) do
			if typeof(posVal) == "table" then
				local tableStr = ""
				for tk, tv in pairs(posVal) do
					tableStr = tableStr .. string.format("%s=%s ", tostring(tk), tostring(tv))
				end
				_annotate(string.format("  %s = {%s}", posKey, tableStr))
			else
				_annotate(string.format("  %s = %s", posKey, tostring(posVal)))
			end
		end
	end

	-- Count state entries for logging (defined outside if blocks for scope)
	local stateCount = 0
	if isSpeedChart then
		local verifyEntry = positions[key]
		if verifyEntry then
			_annotate("SaveState: VERIFIED entry exists in positions table before save")
		else
			_annotate("SaveState: ERROR - entry NOT in positions table!")
		end
		for k, _ in pairs(positions) do
			if string.find(k, STATE_PREFIX) then
				stateCount = stateCount + 1
			end
		end
		_annotate(string.format("SaveState: positions has %d '%s*' entries before SetSetting", stateCount, STATE_PREFIX))
	end

	local setting = {
		name = settingEnums.settingDefinitions.ACTIVE_RUN_WIDGET_POSITIONS.name,
		domain = settingEnums.settingDomains.USERSETTINGS,
		kind = settingEnums.settingKinds.LUA,
		luaValue = positions,
	}
	local result = settings.SetSetting(setting)
	if isSpeedChart then
		if result then
			_annotate(string.format("SaveState: SetSetting success (stateEntries=%d)", stateCount))
			-- Verify the data actually persisted by re-fetching
			task.defer(function()
				local verifyPositions = getPositions()
				local verifyEntry = verifyPositions[key]
				if verifyEntry then
					_annotate("SaveState: VERIFIED data persisted after save")
				else
					-- Data didn't persist - server may be filtering this key pattern
					annotater.Error(string.format("SaveState: DATA LOSS - saved key '%s' but it did not persist! Server may be filtering this key pattern.", key), { key = key })
				end
			end)
		else
			annotater.Error("SaveState: SetSetting returned failure!", { key = key })
		end
	end
end

-- Get default position for a category
-- Note: With top-center anchoring (0.5, 0), Y position is where the TOP of the widget goes
local function getDefaultPosition(category: string): UDim2
	local defaults: { [string]: UDim2 } = {
		[widgetTypes.CATEGORIES.TIMER] = UDim2.fromScale(0.5, 0.15),
		[widgetTypes.CATEGORIES.SPEED] = UDim2.fromScale(0.9, 0.6),
		[widgetTypes.CATEGORIES.VELOCITY] = UDim2.fromScale(0.1, 0.6),
		[widgetTypes.CATEGORIES.SPEED_CHART] = UDim2.fromScale(0.85, 0.5),
		[widgetTypes.CATEGORIES.ALTITUDE] = UDim2.fromScale(0.1, 0.5),
		[widgetTypes.CATEGORIES.DISTANCE] = UDim2.fromScale(0.5, 0.88),
		[widgetTypes.CATEGORIES.STATS] = UDim2.fromScale(0.1, 0.35),
		[widgetTypes.CATEGORIES.TERRAIN] = UDim2.fromScale(0.88, 0.35),
		[widgetTypes.CATEGORIES.COMPASS] = UDim2.fromScale(0.06, 0.25),
		[widgetTypes.CATEGORIES.MAPS] = UDim2.fromScale(0.12, 0.55),
		[widgetTypes.CATEGORIES.ACCELERATION] = UDim2.fromScale(0.92, 0.5),
		-- RUN_INFO: Must be BELOW leaderboard area - 0.18 gives clearance
		[widgetTypes.CATEGORIES.RUN_INFO] = UDim2.fromScale(0.5, 0.18),
		[widgetTypes.CATEGORIES.CONTAINER] = UDim2.fromScale(0.5, 0.2),
	}
	return defaults[category] or UDim2.fromScale(0.5, 0.5)
end

-- Check if a container style is anchored (fixed position, not draggable)
local function isAnchoredContainer(containerStyle: string): boolean
	-- Dashboard bar is anchored to bottom edge, not draggable
	return containerStyle == widgetTypes.CONTAINER_STYLES.DASHBOARD_BAR
end

-- Create a widget for a category with the specified style
local function createWidget(category: string, style: string): widgetTypes.Widget?
	if style == "none" then
		return nil
	end

	local categoryRegistry = widgetRegistry[category]
	if not categoryRegistry then
		_annotate(string.format("No registry for category: %s", category))
		return nil
	end

	local factory = categoryRegistry[style]
	if not factory then
		_annotate(string.format("No factory for style: %s/%s", category, style))
		return nil
	end

	return factory()
end

-- Destroy all active widgets (including container)
local function destroyAllWidgets()
	for _, cleanup in ipairs(dragCleanups) do
		cleanup()
	end
	dragCleanups = {}

	-- Destroy all non-container widgets first
	for category, widget in pairs(activeWidgets) do
		if category ~= widgetTypes.CATEGORIES.CONTAINER then
			widget.Destroy()
		end
	end

	-- Then destroy container widget
	if containerWidget then
		containerWidget.Destroy()
		containerWidget = nil
		containerWidgetFrame = nil
	end

	activeWidgets = {}
	widgetFrames = {}
	activeStyles = {} -- Reset style tracking so next ApplyConfiguration starts fresh
end

-- Create the main screen gui
function module.CreateGui()
	if screenGui then
		return
	end

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

	local existing = playerGui:FindFirstChild("WidgetComposerGui")
	if existing then
		existing:Destroy()
	end

	local newGui = Instance.new("ScreenGui")
	newGui.Name = "WidgetComposerGui"
	newGui.IgnoreGuiInset = true
	newGui.DisplayOrder = 5
	newGui.Parent = playerGui
	screenGui = newGui

	-- Container frame (full screen, for independent widgets)
	local container = Instance.new("Frame")
	container.Name = "WidgetContainer"
	container.Size = UDim2.fromScale(1, 1)
	container.Position = UDim2.fromScale(0, 0)
	container.BackgroundTransparency = 1
	container.Parent = newGui
	containerFrame = container

	_annotate("Created widget composer GUI")
end

-- Destroy the main screen gui
function module.DestroyGui()
	destroyAllWidgets()

	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end

	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end

	containerFrame = nil
	isRunning = false
end

-- Apply configuration and create/destroy widgets as needed
-- Container-as-parent architecture:
-- - If Container = "none": widgets parent to screen, independently positionable
-- - If Container != "none": container widget is created first, other widgets parent inside it
-- Full UI mode:
-- - If FullUI != "none": Classic widget takes over, all modular widgets hidden
function module.ApplyConfiguration(config: { [string]: string }?)
	local useConfig = config or module.GetConfiguration()

	-- Get saved positions
	local positions = getPositions()

	-- PHASE 0: Check for Full UI mode (Classic takes over)
	local fullUICategory = widgetTypes.CATEGORIES.FULL_UI
	local fullUIStyle = useConfig[fullUICategory] or "none"
	local currentFullUIStyle = activeStyles[fullUICategory] or "none"
	local isFullUIMode = fullUIStyle ~= "none"

	-- Handle Full UI mode transitions
	if fullUIStyle ~= currentFullUIStyle then
		-- Style is changing
		if currentFullUIStyle ~= "none" then
			-- Destroy existing full UI widget
			local currentFullUI = activeWidgets[fullUICategory]
			if currentFullUI then
				currentFullUI.Destroy()
				activeWidgets[fullUICategory] = nil
				widgetFrames[fullUICategory] = nil
				_annotate(string.format("Destroyed Full UI widget: %s", currentFullUIStyle))
			end
		end

		activeStyles[fullUICategory] = fullUIStyle

		if fullUIStyle ~= "none" then
			-- Entering Full UI mode - destroy all modular widgets first
			_annotate(string.format("Entering Full UI mode: %s - destroying modular widgets", fullUIStyle))
			destroyAllWidgets()
			activeStyles[fullUICategory] = fullUIStyle -- Restore after destroyAllWidgets clears it

			-- Create the Full UI widget (it manages its own ScreenGui)
			local fullUIWidget = createWidget(fullUICategory, fullUIStyle)
			if fullUIWidget then
				-- Full UI widgets don't need a parent frame - they create their own ScreenGui
				-- Pass nil for parent, the widget will create its own
				local dummyFrame = Instance.new("Frame") -- Temporary frame, won't be used
				dummyFrame.Name = "FullUIPlaceholder"
				fullUIWidget.Create(dummyFrame, nil)
				dummyFrame:Destroy()

				activeWidgets[fullUICategory] = fullUIWidget
				-- No frame to store since Full UI manages its own ScreenGui

				if isRunning then
					fullUIWidget.OnRunStart(currentStartTick, currentSignName, currentSignPosition)
				end

				_annotate(string.format("Created Full UI widget: %s", fullUIStyle))
			end
			return -- In Full UI mode, skip all modular widget handling
		end
	end

	-- If we're in Full UI mode, skip modular widget handling
	if isFullUIMode then
		return
	end

	local screenContainer = containerFrame

	if not screenContainer then
		module.CreateGui()
		screenContainer = containerFrame
	end

	if not screenContainer then
		return
	end

	-- Determine container mode
	local containerStyle = useConfig[widgetTypes.CATEGORIES.CONTAINER] or "none"
	local isContainerMode = containerStyle ~= "none"

	-- PHASE 1: Handle container widget first (it's special - always parents to screen)
	local containerCategory = widgetTypes.CATEGORIES.CONTAINER
	local currentContainerStyle = activeStyles[containerCategory] or "none"
	local containerNeedsChange = containerStyle ~= currentContainerStyle

	if containerNeedsChange then
		-- Destroy existing container and ALL widgets inside it
		if containerWidget then
			_annotate(string.format("Container changing from %s to %s - destroying all widgets", currentContainerStyle, containerStyle))
			-- First destroy all non-container widgets (they're children of the container)
			for category, widget in pairs(activeWidgets) do
				if category ~= containerCategory then
					widget.Destroy()
					activeWidgets[category] = nil
					widgetFrames[category] = nil
					activeStyles[category] = "none" -- Reset so they get recreated
				end
			end
			-- Clear drag cleanups
			for _, cleanup in ipairs(dragCleanups) do
				cleanup()
			end
			dragCleanups = {}
			-- Now destroy container
			containerWidget.Destroy()
			containerWidget = nil
			containerWidgetFrame = nil
			activeWidgets[containerCategory] = nil
			widgetFrames[containerCategory] = nil
		end

		activeStyles[containerCategory] = containerStyle

		-- Create new container if not "none"
		if containerStyle ~= "none" then
			local newContainer = createWidget(containerCategory, containerStyle)
			if newContainer then
				-- Positions are stored per category, not per style
				local posKey = POSITION_PREFIX .. containerCategory
				local savedPos = positions[posKey]
				local position: UDim2
				-- Reject offset-based positions (old format) - reset to default
				if savedPos and not isOffsetBasedPosition(savedPos) then
					position = savedPos
				else
					if savedPos then
						_annotate(string.format("REJECTED offset-based position for %s - resetting to default", containerCategory))
					end
					position = getDefaultPosition(containerCategory)
				end
				local frame = newContainer.Create(screenContainer, position)
				if frame then
					containerWidget = newContainer
					containerWidgetFrame = frame
					activeWidgets[containerCategory] = newContainer
					widgetFrames[containerCategory] = frame

					-- Only make draggable if not an anchored container (dashboard bar stays at bottom)
					if not isAnchoredContainer(containerStyle) then
						-- Entire container surface is draggable
						local cleanup = dragUtil.makeDraggable({
							frame = frame,
							dragHandle = frame,
							onDragEnd = function(pos)
								-- Save position by category only - all styles in a category share position
								savePosition(containerCategory, pos)
							end,
						})
						table.insert(dragCleanups, cleanup)
					end

					if isRunning then
						newContainer.OnRunStart(currentStartTick, currentSignName, currentSignPosition)
					end
					_annotate(string.format("Created container widget: %s (anchored=%s)", containerStyle, tostring(isAnchoredContainer(containerStyle))))
				end
			end
		end
	end

	-- PHASE 2: Determine parent for other widgets
	-- If container mode: widgets go inside the container widget frame
	-- If no container: widgets go directly to screen container
	local widgetParent: Frame
	if isContainerMode and containerWidgetFrame then
		widgetParent = containerWidgetFrame
	else
		widgetParent = screenContainer
	end

	-- PHASE 3: Handle all other (non-container, non-full-UI) widgets
	for _, categoryInfo in ipairs(widgetTypes.CATEGORY_INFO) do
		local category = categoryInfo.id

		-- Skip container - already handled above
		if category == containerCategory then
			continue
		end

		-- Skip FULL_UI - handled in Phase 0
		if category == fullUICategory then
			continue
		end

		local desiredStyle = useConfig[category] or "none"
		local currentStyle = activeStyles[category] or "none"
		local currentWidget = activeWidgets[category]
		local needsChange = (desiredStyle ~= currentStyle)

		_annotate(string.format("Category %s: current=%s desired=%s change=%s", category, currentStyle, desiredStyle, tostring(needsChange)))

		if needsChange then
			-- Capture outgoing widget's size before destroying (for size continuity when switching styles)
			local outgoingSize: { width: number, height: number }? = nil
			local currentFrame = widgetFrames[category]
			if currentFrame then
				local frameWidth = currentFrame.Size.X.Offset
				local frameHeight = currentFrame.Size.Y.Offset
				-- Only use if it's a valid size (offset-based, not scale-based)
				if frameWidth > 0 and frameHeight > 0 then
					outgoingSize = {
						width = frameWidth,
						height = frameHeight,
					}
				end
			end

			-- Destroy existing widget if any
			if currentWidget then
				_annotate(string.format("Destroying widget for category: %s (was style: %s)", category, currentStyle))
				currentWidget.Destroy()
				activeWidgets[category] = nil
				widgetFrames[category] = nil
			end

			activeStyles[category] = desiredStyle

			-- Create new widget if style is not "none"
			if desiredStyle ~= "none" then
				local newWidget = createWidget(category, desiredStyle)
				if newWidget then
					-- Positions are stored per category - all styles in a category share one position
					local posKey = POSITION_PREFIX .. category
					local position: UDim2?

					if isContainerMode then
						-- In container mode, use relative positions within container
						position = nil
					else
						-- Use saved position for this category, or default
						local savedPos = positions[posKey]
						-- Reject offset-based positions (old format) - reset to default
						if savedPos and not isOffsetBasedPosition(savedPos) then
							-- Clamp saved position to current screen bounds to prevent offscreen widgets
							local clampedPos = clampPositionToScreen(savedPos, nil)
							position = clampedPos
							_annotate(string.format("Using saved position for %s: %s", category, formatUDim2(clampedPos)))
						else
							if savedPos then
								_annotate(string.format("REJECTED offset-based position for %s - resetting to default", category))
							end
							local defaultPos = getDefaultPosition(category)
							position = defaultPos
							_annotate(string.format("Using default position for %s: %s", category, formatUDim2(defaultPos)))
						end
					end

					-- Build context for widget creation
					-- Priority for size: outgoing widget size > saved size for this style > widget default
					local sizeToUse = outgoingSize or module.GetSavedSize(category, desiredStyle)
					if outgoingSize then
						_annotate(string.format("Using outgoing widget size for %s: %dx%d", category, outgoingSize.width, outgoingSize.height))
					end
					local capturedCatForSize = category
					local capturedStyleForSize = desiredStyle
					local isSpeedChart = (category == "SpeedChart")
					if isSpeedChart then
						_annotate(string.format("Creating context for category=%s style=%s", category, desiredStyle))
					end
					local savedState = module.GetSavedState(category, desiredStyle)
					if isSpeedChart then
						_annotate(string.format("GetSavedState returned: %s", savedState and "TABLE" or "nil"))
					end
					local createContext: widgetTypes.WidgetCreateContext = {
						savedSize = sizeToUse,
						onSaveSize = function(width: number, height: number)
							module.SaveSize(capturedCatForSize, capturedStyleForSize, width, height)
						end,
						savedState = savedState,
						onSaveState = function(state: { [string]: any })
							module.SaveState(capturedCatForSize, capturedStyleForSize, state)
						end,
					}

					local frame = newWidget.Create(widgetParent, position, createContext)
					if frame then
						activeWidgets[category] = newWidget
						widgetFrames[category] = frame

						-- Make widget sink input to prevent click-through to elements below
						dragUtil.makeInputSink(frame)

						-- Add hover handlers for reverse highlighting (widget -> picker card)
						-- Skip for FullUI and Container - they don't need hover effects
						local skipHover = category == widgetTypes.CATEGORIES.FULL_UI or category == widgetTypes.CATEGORIES.CONTAINER
						if not skipHover then
							-- Use MouseEnter/MouseLeave - these work on the frame bounds regardless of
							-- transparency and bubble up from child elements automatically
							local capturedCategory = category
							local capturedFrame = frame
							local isHovering = false

							-- Notify hover state change (only when picker is open)
							local function notifyHover(hovering: boolean)
								if hovering == isHovering then
									return
								end
								isHovering = hovering
								if module.IsPickerOpen() then
									module.NotifyWidgetHover(capturedCategory, hovering)
								end
							end

							-- Register check function for when picker opens (mouse may already be over)
							local function checkInitialHover()
								if isHovering and module.IsPickerOpen() then
									module.NotifyWidgetHover(capturedCategory, true)
								end
							end
							module.RegisterWidgetHoverCheck(capturedCategory, checkInitialHover)

							-- MouseEnter fires when mouse enters frame bounds (works for transparent frames)
							capturedFrame.MouseEnter:Connect(function()
								notifyHover(true)
							end)

							-- MouseLeave fires when mouse leaves frame bounds
							capturedFrame.MouseLeave:Connect(function()
								notifyHover(false)
							end)

							-- Cleanup when frame is destroyed
							capturedFrame.Destroying:Connect(function()
								module.UnregisterWidgetHoverCheck(capturedCategory)
								if isHovering then
									isHovering = false
									module.NotifyWidgetHover(capturedCategory, false)
								end
							end)
						end

						-- Only make draggable in free positioning mode (container = none)
						if not isContainerMode then
							_annotate(string.format("Making widget draggable: %s/%s", category, desiredStyle))

							-- Entire widget surface is draggable (frame itself is the handle)
							-- Capture category for closure
							local capturedCategoryForDrag = category
							local cleanup = dragUtil.makeDraggable({
								frame = frame,
								dragHandle = frame, -- Drag from anywhere on the widget
								onDragEnd = function(pos)
									-- Save position by category only - all styles in a category share position
									_annotate(string.format("Drag ended for %s, saving position", capturedCategoryForDrag))
									savePosition(capturedCategoryForDrag, pos)
								end,
							})
							table.insert(dragCleanups, cleanup)
						else
							_annotate(string.format("Widget NOT draggable (container mode): %s/%s", category, desiredStyle))
						end

						if isRunning then
							newWidget.OnRunStart(currentStartTick, currentSignName, currentSignPosition)
						end

						_annotate(string.format("Created widget: %s/%s parent=%s savedSize=%s", category, desiredStyle, if isContainerMode then "container" else "screen", if sizeToUse then string.format("%dx%d", sizeToUse.width, sizeToUse.height) else "none"))
					end
				else
					_annotate(string.format("Failed to create widget: %s/%s", category, desiredStyle))
				end
			end
		end
	end

	_annotate("Applied widget configuration")
end

-- Start a run
function module.StartRun(startTick: number, signName: string, signPosition: Vector3)
	isRunning = true
	currentStartTick = startTick
	currentSignName = signName
	currentSignPosition = signPosition

	-- Reset event tracking indices
	lastAvatarEventIndex = 0
	lastTerrainEventIndex = 0
	activeSpeedReasons = {}

	if not screenGui then
		module.CreateGui()
		module.ApplyConfiguration()
	end

	-- Start tracking stats
	runStats.StartTracking(signName, startTick, signPosition)

	-- Notify all widgets
	for _, widget in pairs(activeWidgets) do
		widget.OnRunStart(startTick, signName, signPosition)
	end

	-- Initialize speed widgets with current WalkSpeed (shows 68 even when standing still)
	local character = localPlayer.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
		if humanoid then
			module.UpdateSpeed(humanoid.WalkSpeed)
		end
	end

	-- Start render loop for updates
	if renderConnection then
		renderConnection:Disconnect()
	end

	local lastLogTime = 0

	renderConnection = RunService.RenderStepped:Connect(function()
		local stats = runStats.GetCurrentStats()
		if not stats then
			return
		end

		-- Debug log every 2 seconds
		local now = tick()
		if now - lastLogTime > 2 then
			lastLogTime = now
			_annotate(string.format("Stats update: jumps=%d, cwSpins=%d, ccwSpins=%d, speed=%.1f", stats.jumpCount, stats.clockwiseSpins, stats.counterClockwiseSpins, stats.currentSpeed))
		end

		-- Route data to all widgets
		-- Note: UpdateSpeed is NOT sent here - movement.lua sends it via activeRunSGui.UpdateSpeed
		-- which provides WalkSpeed (shows 68 even when standing still) for text displays.
		-- UpdateVelocity provides physics velocity for charts that need continuous data points.
		local horizontal = stats.currentSpeed
		local vertical = stats.verticalVelocity
		local total = math.sqrt(horizontal * horizontal + vertical * vertical)

		-- Get new marker events from runStats
		local newAvatarEvents, newAvatarIndex = runStats.GetAvatarEventsSince(lastAvatarEventIndex)
		local newTerrainEvents, newTerrainIndex = runStats.GetTerrainEventsSince(lastTerrainEventIndex)
		lastAvatarEventIndex = newAvatarIndex
		lastTerrainEventIndex = newTerrainIndex

		for _, widget in pairs(activeWidgets) do
			-- Continuous data updates (for widgets that display values)
			widget.UpdateVelocity(horizontal, vertical, total)
			widget.UpdateAltitude(stats.currentAltitude, stats.verticalVelocity)
			widget.UpdateDistance(stats.distanceFromStart, stats.totalDistance)
			widget.UpdateJumpCount(stats.jumpCount)
			widget.UpdateSpinCount(stats.clockwiseSpins, stats.counterClockwiseSpins)
			widget.UpdateTerrain(stats.currentTerrain)
			widget.UpdateFacing(stats.currentFacing)

			-- Event-based marker updates (for charts)
			-- Charts should use OnMarkerEvent rather than deriving events from UpdateJumpCount/UpdateTerrain
			for _, event in ipairs(newAvatarEvents) do
				widget.OnMarkerEvent("avatar", event.time, event.label or "", event.color)
			end
			for _, event in ipairs(newTerrainEvents) do
				widget.OnMarkerEvent("terrain", event.time, event.label or "", event.color)
			end
		end
	end)
end

-- End a run
function module.EndRun()
	isRunning = false

	runStats.StopTracking()

	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end

	-- Notify all widgets
	for _, widget in pairs(activeWidgets) do
		widget.OnRunEnd()
	end

	currentStartTick = 0
	currentSignName = ""
end

-- Update description for all widgets
function module.UpdateDescription(description: string)
	for _, widget in pairs(activeWidgets) do
		widget.UpdateDescription(description)
	end
end

-- Direct update methods (called from movement.lua through activeRunSGui)
-- These override values from runStats to ensure game-accurate data

function module.UpdateSpeed(speed: number)
	for _, widget in pairs(activeWidgets) do
		widget.UpdateSpeed(speed)
	end
end

function module.UpdateVelocity(horizontal: number, vertical: number, total: number)
	for _, widget in pairs(activeWidgets) do
		widget.UpdateVelocity(horizontal, vertical, total)
	end
end

function module.UpdateAcceleration(rate: number)
	for _, widget in pairs(activeWidgets) do
		widget.UpdateAcceleration(rate)
	end
end

-- Parse speed reason string and generate marker events for new reasons
-- The reason string contains newline-separated active reasons
function module.UpdateSpeedReason(reason: string)
	-- Parse current reasons from newline-separated string
	local currentReasons: { [string]: boolean } = {}
	for line in string.gmatch(reason, "[^\n]+") do
		-- Normalize "Jump X" to just "Jump" (the X is the count)
		local reasonName = line:match("^Jump") and "Jump" or line
		currentReasons[reasonName] = true

		-- If this is a new reason (not previously active), add event
		if not activeSpeedReasons[reasonName] then
			local reasonColor = SPEED_REASON_COLORS[reasonName] or colors.yellow
			runStats.AddSpeedReasonEvent(reasonName, reasonColor)
		end
	end

	-- Update active reasons for next comparison
	activeSpeedReasons = currentReasons
end

function module.UpdateStartTime(newStartTick: number)
	currentStartTick = newStartTick
	-- Widgets with timers will pick this up in their render loop
end

-- RestartRun: Called when user retouches the start sign
-- This resets all stateful widgets (charts, maps, stats) while keeping them visible
function module.RestartRun(newStartTick: number, signName: string, signPosition: Vector3)
	currentStartTick = newStartTick
	currentSignName = signName
	currentSignPosition = signPosition

	-- Tell each active widget to restart with fresh state
	for category, widget in pairs(activeWidgets) do
		_annotate(string.format("Restarting widget: %s", category))
		-- OnRunStart clears internal state and reinitializes
		widget.OnRunStart(newStartTick, signName, signPosition)
	end

	-- Also reset runStats
	local runStatsModule = require(game.ReplicatedStorage.gui.activeRunWidgets.runStats)
	runStatsModule.StartTracking(signName, newStartTick, signPosition)
end

function module.UpdateMovementDetails(_details: any): boolean
	-- Future expansion for detailed movement data
	-- Returns true if run GUI is active (for backward compatibility with classicVariant)
	return isRunning
end

-- Check if a run is active
function module.IsRunActive(): boolean
	return isRunning
end

-- Get current run info
function module.GetCurrentRunInfo(): (number, string, Vector3)
	return currentStartTick, currentSignName, currentSignPosition
end

-- Flag to track if widget factories have been registered
local factoriesRegistered = false

-- Register all widget factories (called once)
function module.RegisterAllWidgets()
	if factoriesRegistered then
		return
	end
	factoriesRegistered = true

	-- Import and register all widget modules
	local classicWidget = require(game.ReplicatedStorage.gui.activeRunWidgets.classicWidget)
	local timerWidgets = require(game.ReplicatedStorage.gui.activeRunWidgets.timerWidgets)
	local speedWidgets = require(game.ReplicatedStorage.gui.activeRunWidgets.speedWidgets)
	local distanceWidgets = require(game.ReplicatedStorage.gui.activeRunWidgets.distanceWidgets)
	local statsWidgets = require(game.ReplicatedStorage.gui.activeRunWidgets.statsWidgets)
	local runInfoWidgets = require(game.ReplicatedStorage.gui.activeRunWidgets.runInfoWidgets)
	local accelerationWidgets = require(game.ReplicatedStorage.gui.activeRunWidgets.accelerationWidgets)
	local altitudeWidgets = require(game.ReplicatedStorage.gui.activeRunWidgets.altitudeWidgets)
	local terrainWidgets = require(game.ReplicatedStorage.gui.activeRunWidgets.terrainWidgets)
	local compassWidgets = require(game.ReplicatedStorage.gui.activeRunWidgets.compassWidgets)
	local mapsWidgets = require(game.ReplicatedStorage.gui.activeRunWidgets.mapsWidgets)
	local speedChartWidgets = require(game.ReplicatedStorage.gui.activeRunWidgets.speedChartWidgets)
	local containerWidgets = require(game.ReplicatedStorage.gui.activeRunWidgets.containerWidgets)
	local velocityWidgets = require(game.ReplicatedStorage.gui.activeRunWidgets.velocityWidgets)

	-- Register Full UI widgets first (Classic takes over when enabled)
	classicWidget.Register(module)

	-- Register modular widgets
	timerWidgets.Register(module)
	speedWidgets.Register(module)
	velocityWidgets.Register(module)
	distanceWidgets.Register(module)
	statsWidgets.Register(module)
	runInfoWidgets.Register(module)
	accelerationWidgets.Register(module)
	altitudeWidgets.Register(module)
	terrainWidgets.Register(module)
	compassWidgets.Register(module)
	mapsWidgets.Register(module)
	speedChartWidgets.Register(module)
	containerWidgets.Register(module)

	_annotate("All widget factories registered")
end

-- Initialize the system
function module.Init()
	-- Register widget factories if not done
	module.RegisterAllWidgets()

	-- Create GUI and apply configuration on first call
	if not screenGui then
		module.CreateGui()
		module.ApplyConfiguration()
	end
	_annotate("Widget composer initialized")
end

_annotate("end")
return module
