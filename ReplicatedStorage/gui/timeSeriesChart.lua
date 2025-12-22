--!strict
-- timeSeriesChart.lua (ReplicatedStorage/gui/timeSeriesChart.lua)
-- Generic time-series chart library for bar/point/line visualizations.
-- Domain-agnostic: callers define what data means, library renders it.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local colors = require(game.ReplicatedStorage.util.colors)
local fonts = require(game.StarterPlayer.StarterPlayerScripts.guis.fonts)

local module = {}

--------------------------------------------------------------------------------
-- Type Definitions
--------------------------------------------------------------------------------

-- Data point with timestamp and value
export type DataPoint = {
	time: number,
	value: number,
}

-- Compression region for non-linear Y axis mapping
-- E.g., compress 0-60 range to 25% of height, expand 60-105 to 75%
export type CompressionRegion = {
	rangeStart: number,
	rangeEnd: number,
	heightPercent: number, -- Portion of chart height (0-1, all regions should sum to 1)
}

-- Color threshold for value-based coloring (checked highest to lowest)
export type ColorThreshold = {
	value: number,
	color: Color3,
}

-- Event marker annotation (generic - caller defines what the event is)
export type EventMarker = {
	time: number,
	color: Color3?,
	label: string?,
}

-- Typed event marker with explicit event type and color
export type TypedEventMarker = {
	time: number,
	eventType: string, -- "jump", "terrain", etc.
	color: Color3,
	label: string?,
}

-- Bucket for time-series data (uniform resolution) - legacy single-series
export type DataBucket = {
	startTime: number,
	value: number,
}

-- Accumulator for current incomplete bucket - legacy single-series
export type BucketAccumulator = {
	startTime: number,
	values: { number },
}

-- Unified time bucket: one bucket holds values for ALL series at a given time
export type UnifiedTimeBucket = {
	time: number, -- Midpoint time of this bucket
	values: { [string]: number }, -- seriesName -> aggregated value
}

-- Accumulator for current incomplete unified bucket
export type UnifiedBucketAccumulator = {
	startTime: number,
	seriesValues: { [string]: { number } }, -- seriesName -> list of raw values
}

--------------------------------------------------------------------------------
-- Unified Series Types
--------------------------------------------------------------------------------

-- Series configuration for registration
-- Both lines and markers are "series" — they differ in how Y position is determined
export type SeriesConfig = {
	type: "line" | "marker",
	color: Color3,
	-- Line-specific: Y position from value mapping
	autoScale: boolean?, -- Auto-scale Y-axis to fit visible data
	strategy: ("average" | "min" | "max")?, -- How to aggregate values in buckets
	-- Marker-specific: Y position from fixed row band
	row: number?, -- Row from top (1 = topmost, 2 = second, etc.) Default: 1
}

-- Data point input for addDataPoint
export type DataPointInput = {
	value: number?, -- Required for lines, ignored for markers
	label: string?, -- Optional label (markers show this)
	color: Color3?, -- Optional per-point color override
}

-- Internal state for a unified series
export type SeriesState = {
	name: string,
	seriesType: "line" | "marker", -- "type" is reserved
	color: Color3,
	visible: boolean,
	-- Line-specific
	autoScale: boolean,
	condensationStrategy: "average" | "min" | "max",
	-- Marker-specific
	row: number,
	markers: { TypedEventMarker }, -- Marker data points
	-- Rendering
	elements: { Frame },
}

-- Legacy types for backward compatibility (deprecated)
-- Data series for multi-series charts (rendering config only, data stored in unified buckets)
export type DataSeriesState = {
	name: string,
	color: Color3,
	visible: boolean,
	autoScale: boolean, -- If true, Y-axis auto-scales to fill full height based on visible data
	condensationStrategy: "average" | "min" | "max", -- How to combine values in a bucket
	elements: { Frame }, -- Render elements for this series
}

-- Marker category for grouped event markers
export type MarkerCategoryState = {
	name: string,
	color: Color3,
	visible: boolean,
	row: number, -- Row position from top (1 = topmost, 2 = below, etc.)
	markers: { TypedEventMarker },
	elements: { Frame }, -- Render elements for this category
}

-- Time marker state (for sticky markers that slide left)
export type TimeMarkerState = {
	label: TextLabel,
	anchorTime: number,
	seconds: number,
}

--------------------------------------------------------------------------------
-- Configuration Types
--------------------------------------------------------------------------------

export type DataConfig = {
	maxSamples: number, -- Max raw samples before condensing
	condensationStrategy: "average" | "min" | "max", -- How to condense
	retentionDuration: number?, -- Seconds to retain (nil = unlimited)
}

export type WindowConfig = {
	mode: "sliding" | "all", -- sliding = last N seconds, all = from start to now
	windowDuration: number?, -- For sliding mode: seconds shown
}

export type BucketConfig = {
	mode: "dynamic" | "fixed",
	targetPixelWidth: number?, -- For dynamic: target width per bucket
	minBuckets: number?, -- For dynamic: minimum bucket count
	fixedCount: number?, -- For fixed: exact bucket count
	aggregation: "max" | "min" | "average" | "last",
}

export type VisualizationConfig = {
	mode: "bar" | "point" | "line",
	barGap: number?, -- For bar: gap between bars (0 = no gap, prevents moiré)
	pointSize: number?, -- For point: diameter in pixels
	connectPoints: boolean?, -- For point: draw lines between points
	lineThickness: number?, -- Line thickness for point connections or line mode
	renderDirect: boolean?, -- For point: render actual data points instead of bucketing (prevents flickering)
}

export type YAxisLabelConfig = {
	values: { number }?, -- Explicit values to label
	autoCount: number?, -- OR auto-generate N evenly spaced labels
	fontSize: number?,
	color: Color3?,
	boldValues: { number }?, -- Values to render bold
	colorOverrides: { [number]: Color3 }?, -- Per-value color overrides
}

export type YAxisGridConfig = {
	values: { number }?, -- Explicit values for grid lines
	autoCount: number?, -- OR auto-generate N evenly spaced lines
	color: Color3?,
	transparency: number?,
}

export type YAxisConfig = {
	rangeMode: "auto" | "fixed" | "autoWithZero",
	fixedMin: number?, -- For fixed mode
	fixedMax: number?, -- For fixed mode
	autoFlexible: ("top" | "bottom" | "both" | "neither")?, -- For auto mode
	padding: { above: number?, below: number? }?,
	minRange: number?, -- Minimum range to prevent division issues

	-- Compression (non-linear mapping)
	compressionRegions: { CompressionRegion }?,
	customMapping: ((value: number, chartHeight: number, rangeMin: number, rangeMax: number) -> number)?,

	-- Labels and grid
	labels: YAxisLabelConfig?,
	gridLines: YAxisGridConfig?,

	-- Visual
	width: number?,
	unitSymbol: string?,
}

export type XAxisGridConfig = {
	enabled: boolean?,
	targetCount: number?, -- Target number of vertical lines (2-3 typical)
	intervalSeconds: number?, -- Fixed interval (overrides targetCount if set)
	color: Color3?,
	transparency: number?,
}

export type XAxisConfig = {
	-- sticky: markers anchor at absolute times and slide left (for "all" mode)
	-- fixed: markers at fixed relative positions "now", "5s", "10s" (for sliding windows)
	-- recalculated: legacy mode, avoid using
	markerMode: "sticky" | "fixed" | "recalculated",
	labelInterval: number?, -- Seconds between labels (nil = auto)
	minSpacingPixels: number?, -- Minimum pixels between markers
	showNowLabel: boolean?,
	gridLines: XAxisGridConfig?,
	height: number?,
	fontSize: number?,
}

export type ColorConfig = {
	mode: "single" | "threshold" | "gradient" | "custom",
	color: Color3?, -- For single mode
	thresholds: { ColorThreshold }?, -- For threshold mode
	defaultColor: Color3?, -- Below all thresholds
	gradientStart: Color3?, -- For gradient mode
	gradientEnd: Color3?,
	gradientRange: { min: number, max: number }?,
	colorFunction: ((value: number, time: number, index: number) -> Color3)?,
}

export type CurrentValueConfig = {
	enabled: boolean,
	color: Color3?,
	fontSize: number?,
	formatString: string?, -- e.g., "%.1f↕"
	showConnector: boolean?,
}

-- Event markers configuration (generic - caller defines what events mean)
export type EventMarkersConfig = {
	enabled: boolean,
	color: Color3?,
	width: number?,
	showTip: boolean?,
}

export type AnnotationConfig = {
	eventMarkers: EventMarkersConfig?,
	customMarkers: { EventMarker }?,
}

export type ResizeConfig = {
	enabled: boolean,
	handlePosition: "bottomRight" | "right" | "left" | "none",
	minWidth: number,
	maxWidth: number?,
	minHeight: number,
	maxHeight: number?,
	lockAspectRatio: boolean?,
	aspectRatio: number?,
}

export type TitleConfig = {
	text: string,
	symbol: string?,
	backgroundColor: Color3?,
	textColor: Color3?,
	height: number?,
	minimize: {
		enabled: boolean,
		onToggle: ((minimized: boolean) -> ())?,
		defaultMinimized: boolean?,
	}?,
}

export type BackgroundConfig = {
	color: Color3?,
	transparency: number?,
}

-- Main configuration
export type ChartConfig = {
	title: TitleConfig,
	data: DataConfig,
	window: WindowConfig,
	buckets: BucketConfig,
	visualization: VisualizationConfig,
	yAxis: YAxisConfig,
	xAxis: XAxisConfig,
	color: ColorConfig,
	currentValue: CurrentValueConfig?,
	annotations: AnnotationConfig?,
	resize: ResizeConfig?,
	background: BackgroundConfig?,
}

--------------------------------------------------------------------------------
-- Chart State
--------------------------------------------------------------------------------

export type ChartState = {
	-- DOM elements
	container: Frame,
	chartFrame: Frame,
	elements: { Frame }, -- Bars, points, or line segments
	yAxisFrame: Frame,
	yAxisLabels: { TextLabel },
	gridLines: { Frame },
	verticalGridLines: { Frame }, -- Vertical lines for X-axis divisions
	timeMarkers: { TimeMarkerState },
	xAxisFrame: Frame,
	currentValueLabel: TextLabel?,
	bucketInfoLabel: TextLabel?,
	eventMarkerFrames: { Frame },

	-- Configuration
	config: ChartConfig,

	-- Dimensions
	chartWidth: number,
	chartHeight: number,

	-- Data (single-series mode, backwards compatible)
	dataPoints: { DataPoint },
	eventTimestamps: { number },
	typedEventMarkers: { TypedEventMarker },
	windowStartTick: number,
	currentValue: number?,

	-- Multi-series mode
	dataSeries: { [string]: DataSeriesState },
	markerCategories: { [string]: MarkerCategoryState },
	series: { [string]: SeriesState }, -- Unified series storage
	isMultiSeriesMode: boolean,
	latestDataTime: number, -- Track latest data timestamp for sliding window when frozen

	-- Unified bucket storage (shared across all series)
	timeBuckets: { UnifiedTimeBucket }, -- Finalized buckets with all series values
	currentTimeBucket: UnifiedBucketAccumulator?, -- In-progress bucket accumulator
	bucketDuration: number, -- Current bucket width in seconds (shared by all series)

	-- Resize state
	resizeCleanup: (() -> ())?,
	fillParentConnection: RBXScriptConnection?, -- AbsoluteSize listener for fill-parent mode

	-- Frame update batching (prevents multiple updateChart calls per frame)
	needsUpdate: boolean,
	renderConnection: RBXScriptConnection?,

	-- Minimize state
	isMinimized: boolean,
	minimizeButton: TextButton?,
	titleBar: Frame?,

	-- Rendering state
	-- NOTE: We intentionally do not use position caches or "skip render" caches.

	-- Paused state: when true, uses latestDataTime instead of tick() for window calculations
	-- This "freezes" the X-axis so historical data doesn't slide off when no new data arrives
	isPaused: boolean,
}

--------------------------------------------------------------------------------
-- Chart Handle (returned to caller)
--------------------------------------------------------------------------------

export type ChartHandle = {
	-- Single-series mode (backwards compatible, deprecated)
	addDataPoint: (time: number, value: number) -> (),
	setEventMarkers: (timestamps: { number }) -> (),
	setTypedEventMarkers: (markers: { TypedEventMarker }) -> (),

	-- Unified series API (preferred)
	-- Register any series (line or marker) with configuration
	register: (name: string, config: SeriesConfig) -> (),
	-- Add data to any series
	add: (seriesName: string, time: number, data: DataPointInput?) -> (),
	-- Set visibility for any series
	setVisible: (seriesName: string, visible: boolean) -> (),

	-- Legacy multi-series mode (deprecated, use unified API)
	registerSeries: (name: string, color: Color3, config: { autoScale: boolean?, strategy: ("average" | "min" | "max")? }?) -> (),
	addSeriesDataPoint: (seriesName: string, time: number, value: number) -> (),
	setSeriesVisible: (seriesName: string, visible: boolean) -> (),
	registerMarkerCategory: (name: string, color: Color3, row: number?) -> (),
	addCategoryMarker: (category: string, time: number, label: string?, markerColor: Color3?) -> (),
	setMarkerCategoryVisible: (category: string, visible: boolean) -> (),

	-- Common
	clearData: () -> (),
	setWindowStart: (startTick: number) -> (),
	setWindowDuration: (seconds: number) -> (),
	setWindowMode: (mode: "sliding" | "all", duration: number?) -> (),
	setSize: (width: number, height: number) -> (), -- Resize the chart
	update: () -> (),
	setChartVisible: (visible: boolean) -> (), -- Renamed from setVisible to avoid conflict
	destroy: () -> (),
	getFrame: () -> Frame?,
	getSize: () -> (number, number),
	onSizeChanged: ((width: number, height: number) -> ())?,

	-- Minimize
	setMinimized: (minimized: boolean) -> (),
	isMinimized: () -> boolean,

	-- Pause/Resume: freezes the X-axis at latest data time (for post-run viewing)
	pause: () -> (),
	resume: () -> (),
}

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local DEFAULT_TITLE_HEIGHT = 20
local DEFAULT_Y_AXIS_WIDTH = 45
local DEFAULT_X_AXIS_HEIGHT = 16
local DEFAULT_Y_AXIS_FONT_SIZE = 11
local DEFAULT_X_AXIS_FONT_SIZE = 10
local DEFAULT_TARGET_BUCKET_PIXELS = 4
local DEFAULT_MIN_BUCKETS = 10
local DEFAULT_MIN_RANGE = 10
local DEFAULT_PADDING = 5
local DEFAULT_POINT_SIZE = 3
local DEFAULT_LINE_THICKNESS = 2
local MIN_MARKER_SPACING_PIXELS = 40
local MARKER_INTERVALS = { 1, 2, 5, 10, 15, 20, 30, 60, 120, 300 }

--------------------------------------------------------------------------------
-- Y-Axis Mapping Functions
--------------------------------------------------------------------------------

-- Apply compression regions to map value to Y position
local function applyCompressionMapping(value: number, chartHeight: number, rangeMin: number, rangeMax: number, regions: { CompressionRegion }): number
	-- Padding to prevent points from being clipped at edges
	local edgePadding = 4

	-- Find which region the value falls into
	local accumulatedHeight = 0
	local usableHeight = chartHeight - (edgePadding * 2)

	for _, region in ipairs(regions) do
		if value >= region.rangeStart and value <= region.rangeEnd then
			-- Value is in this region
			local regionRange = region.rangeEnd - region.rangeStart
			local regionHeight = usableHeight * region.heightPercent
			local positionInRegion = (value - region.rangeStart) / math.max(regionRange, 0.001)
			-- Y position: 0 = top, chartHeight = bottom
			-- Higher values should be higher on screen (lower Y)
			return edgePadding + usableHeight - (accumulatedHeight + positionInRegion * regionHeight)
		elseif value > region.rangeEnd then
			-- Value is above this region, accumulate its height
			accumulatedHeight = accumulatedHeight + usableHeight * region.heightPercent
		else
			-- Value is below this region
			return edgePadding + usableHeight - accumulatedHeight
		end
	end

	-- Value above all regions
	return edgePadding
end

-- Standard linear mapping
local function linearMapping(value: number, chartHeight: number, rangeMin: number, rangeMax: number): number
	-- Padding to prevent points from being clipped at edges
	local edgePadding = 4
	local usableHeight = chartHeight - (edgePadding * 2)

	local range = rangeMax - rangeMin
	if range <= 0 then
		return chartHeight / 2
	end
	local normalized = (value - rangeMin) / range
	return edgePadding + usableHeight * (1 - normalized) -- Invert: higher values = lower Y
end

-- Get Y position for a value based on config
local function getYPosition(state: ChartState, value: number, rangeMin: number, rangeMax: number): number
	local config = state.config.yAxis
	local chartHeight = state.chartHeight

	-- Custom mapping takes precedence
	if config.customMapping then
		return config.customMapping(value, chartHeight, rangeMin, rangeMax)
	end

	-- Compression regions
	if config.compressionRegions and #config.compressionRegions > 0 then
		return applyCompressionMapping(value, chartHeight, rangeMin, rangeMax, config.compressionRegions)
	end

	-- Default linear mapping
	return linearMapping(value, chartHeight, rangeMin, rangeMax)
end

--------------------------------------------------------------------------------
-- Color Functions
--------------------------------------------------------------------------------

local function getValueColor(state: ChartState, value: number, time: number, index: number): Color3
	local config = state.config.color

	if config.mode == "single" then
		return config.color or colors.warpColor
	elseif config.mode == "threshold" then
		if config.thresholds then
			-- Sort by value descending and find first match
			for _, threshold in ipairs(config.thresholds) do
				if value >= threshold.value then
					return threshold.color
				end
			end
		end
		return config.defaultColor or colors.defaultGrey
	elseif config.mode == "gradient" then
		local gradientRange = config.gradientRange or { min = 0, max = 100 }
		local t = math.clamp((value - gradientRange.min) / (gradientRange.max - gradientRange.min), 0, 1)
		local startColor = config.gradientStart or colors.blueDone
		local endColor = config.gradientEnd or colors.meColor
		return startColor:Lerp(endColor, t)
	elseif config.mode == "custom" and config.colorFunction then
		return config.colorFunction(value, time, index)
	end

	return config.color or colors.warpColor
end

--------------------------------------------------------------------------------
-- Time Marker Management
--------------------------------------------------------------------------------

local function chooseMarkerInterval(timeWindow: number, chartWidth: number, yAxisWidth: number): number
	local chartAreaWidth = chartWidth - yAxisWidth - 8
	local minSpacing = MIN_MARKER_SPACING_PIXELS
	local maxMarkers = math.floor(chartAreaWidth / minSpacing)

	for _, interval in ipairs(MARKER_INTERVALS) do
		local numMarkers = math.ceil(timeWindow / interval)
		if numMarkers <= maxMarkers then
			return interval
		end
	end

	return MARKER_INTERVALS[#MARKER_INTERVALS]
end

local function updateTimeMarkers(state: ChartState, windowStart: number, timeWindow: number, now: number)
	local config = state.config.xAxis
	local yAxisWidth = state.config.yAxis.width or DEFAULT_Y_AXIS_WIDTH

	if config.markerMode == "sticky" then
		-- Sticky markers: anchor at absolute times and slide left (for "all" / expanding windows)
		-- Labels show "Xs ago" and update as time passes
		local interval = chooseMarkerInterval(timeWindow, state.chartWidth, yAxisWidth)

		-- Remove markers outside window
		local i = 1
		while i <= #state.timeMarkers do
			local marker = state.timeMarkers[i]
			if marker.anchorTime < windowStart then
				marker.label:Destroy()
				table.remove(state.timeMarkers, i)
			else
				i = i + 1
			end
		end

		-- Add markers at interval boundaries
		local latestBoundary = math.floor(now / interval) * interval

		-- Safety: limit iterations to prevent infinite loop if windowStart is invalid
		local maxIterations = 100
		local iterations = 0
		for boundary = latestBoundary, windowStart, -interval do
			iterations = iterations + 1
			if iterations > maxIterations then
				break
			end
			local exists = false
			for _, marker in ipairs(state.timeMarkers) do
				if math.abs(marker.anchorTime - boundary) < 0.1 then
					exists = true
					break
				end
			end

			if not exists and boundary >= windowStart then
				local secondsAgo = math.floor(now - boundary + 0.5)
				local label = Instance.new("TextLabel")
				label.Name = "TimeMarker_" .. secondsAgo
				label.Size = UDim2.fromOffset(35, 14)
				label.AnchorPoint = Vector2.new(0.5, 0)
				label.BackgroundTransparency = 1
				label.TextColor3 = colors.white
				label.FontFace = fonts.GetFont(false, false)
				label.TextSize = config.fontSize or DEFAULT_X_AXIS_FONT_SIZE
				label.Text = if secondsAgo == 0 then "now" else string.format("%ds", secondsAgo)
				label.Parent = state.xAxisFrame

				table.insert(state.timeMarkers, {
					label = label,
					anchorTime = boundary,
					seconds = secondsAgo,
				})
			end
		end

		-- Update positions (slide left as time passes)
		for _, marker in ipairs(state.timeMarkers) do
			local relativePos = (marker.anchorTime - windowStart) / timeWindow
			marker.label.Position = UDim2.fromScale(relativePos, 0)
			local secondsAgo = math.floor(now - marker.anchorTime + 0.5)
			marker.label.Text = if secondsAgo <= 0 then "now" else string.format("%ds", secondsAgo)
		end
	elseif config.markerMode == "fixed" then
		-- Fixed markers: for sliding windows with constant duration
		-- Labels are at fixed positions: "now" at right edge, "5s", "10s", etc. going left
		-- Positions and labels never change because window is always "last N seconds"
		local interval = chooseMarkerInterval(timeWindow, state.chartWidth, yAxisWidth)
		local numMarkers = math.floor(timeWindow / interval) + 1

		-- Ensure we have enough marker labels
		while #state.timeMarkers < numMarkers do
			local label = Instance.new("TextLabel")
			label.Name = "TimeMarker_fixed_" .. #state.timeMarkers
			label.Size = UDim2.fromOffset(35, 14)
			label.AnchorPoint = Vector2.new(0.5, 0)
			label.BackgroundTransparency = 1
			label.TextColor3 = colors.white
			label.FontFace = fonts.GetFont(false, false)
			label.TextSize = config.fontSize or DEFAULT_X_AXIS_FONT_SIZE
			label.Parent = state.xAxisFrame
			table.insert(state.timeMarkers, {
				label = label,
				anchorTime = 0,
				seconds = 0,
			})
		end

		-- Update fixed markers (from right to left: "now", "5s", "10s", etc.)
		for i = 1, numMarkers do
			local marker = state.timeMarkers[i]
			if marker then
				local secondsAgo = (i - 1) * interval
				local relativePos = 1 - (secondsAgo / timeWindow) -- 0s = 1.0 (right), 10s = 0.0 (left)

				-- Adjust anchor point to prevent edge labels from being cut off
				local anchorX: number
				local posOffset: number = 0
				if relativePos > 0.95 then
					-- "now" at right edge: right-align with small inset
					anchorX = 1
					posOffset = -4
				elseif relativePos < 0.05 then
					-- Oldest label at left edge: left-align with small inset
					anchorX = 0
					posOffset = 4
				else
					-- Middle labels: center
					anchorX = 0.5
				end
				marker.label.AnchorPoint = Vector2.new(anchorX, 0)
				marker.label.Position = UDim2.new(relativePos, posOffset, 0, 0)
				marker.label.Text = if secondsAgo == 0 then "now" else string.format("%.0fs", secondsAgo)
				marker.label.Visible = true
			end
		end

		-- Hide extra markers
		for i = numMarkers + 1, #state.timeMarkers do
			state.timeMarkers[i].label.Visible = false
		end
	else
		-- Recalculated markers (legacy): reposition based on window
		local numMarkers = math.min(#state.timeMarkers, 5)
		local interval = timeWindow / math.max(numMarkers - 1, 1)

		for i, marker in ipairs(state.timeMarkers) do
			if i <= numMarkers then
				local seconds = (i - 1) * interval
				marker.label.Text = if seconds == 0 then "now" else string.format("%.0fs", seconds)
				marker.label.Position = UDim2.fromScale(1 - (seconds / timeWindow), 0)
				marker.label.Visible = true
			else
				marker.label.Visible = false
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Event Marker Management (generic - caller defines what events mean)
--------------------------------------------------------------------------------

local function updateEventMarkers(state: ChartState, windowStart: number, timeWindow: number)
	-- Clear old markers
	for _, marker in ipairs(state.eventMarkerFrames) do
		marker:Destroy()
	end
	state.eventMarkerFrames = {}

	local chart = state.chartFrame
	local annotationConfig = state.config.annotations
	local markerConfig = annotationConfig and annotationConfig.eventMarkers
	local markerWidth = if markerConfig then markerConfig.width or 2 else 2
	local showTip = if markerConfig then markerConfig.showTip else false
	local defaultColor = if markerConfig then markerConfig.color or colors.orangeAccent else colors.orangeAccent

	-- Render simple timestamp markers (backwards compatibility)
	if markerConfig and markerConfig.enabled then
		for i, eventTime in ipairs(state.eventTimestamps) do
			if eventTime >= windowStart and eventTime <= windowStart + timeWindow then
				local relativeTime = (eventTime - windowStart) / timeWindow
				local xPos = relativeTime * state.chartWidth

				local marker = Instance.new("Frame")
				marker.Name = "EventMarker" .. i
				marker.Size = UDim2.fromOffset(markerWidth, state.chartHeight * 0.7)
				marker.Position = UDim2.fromOffset(xPos, state.chartHeight * 0.15)
				marker.AnchorPoint = Vector2.new(0.5, 0)
				marker.BackgroundColor3 = defaultColor
				marker.BackgroundTransparency = 0.3
				marker.BorderSizePixel = 0
				marker.ZIndex = 5
				marker.Parent = chart

				if showTip then
					local tip = Instance.new("Frame")
					tip.Size = UDim2.fromOffset(6, 4)
					tip.Position = UDim2.fromOffset(0, -2)
					tip.AnchorPoint = Vector2.new(0.5, 1)
					tip.BackgroundColor3 = defaultColor
					tip.BackgroundTransparency = 0.3
					tip.BorderSizePixel = 0
					tip.Parent = marker
				end

				table.insert(state.eventMarkerFrames, marker)
			end
		end
	end

	-- Render typed event markers with individual colors
	for i, typedMarker in ipairs(state.typedEventMarkers) do
		if typedMarker.time >= windowStart and typedMarker.time <= windowStart + timeWindow then
			local relativeTime = (typedMarker.time - windowStart) / timeWindow
			local xPos = relativeTime * state.chartWidth
			local markerColor = typedMarker.color

			local marker = Instance.new("Frame")
			marker.Name = "TypedMarker" .. i
			marker.Size = UDim2.fromOffset(markerWidth, state.chartHeight * 0.7)
			marker.Position = UDim2.fromOffset(xPos, state.chartHeight * 0.15)
			marker.AnchorPoint = Vector2.new(0.5, 0)
			marker.BackgroundColor3 = markerColor
			marker.BackgroundTransparency = 0.3
			marker.BorderSizePixel = 0
			marker.ZIndex = 5
			marker.Parent = chart

			-- Always show tip for typed markers (they're explicitly added)
			local tip = Instance.new("Frame")
			tip.Size = UDim2.fromOffset(6, 4)
			tip.Position = UDim2.fromOffset(0, -2)
			tip.AnchorPoint = Vector2.new(0.5, 1)
			tip.BackgroundColor3 = markerColor
			tip.BackgroundTransparency = 0.3
			tip.BorderSizePixel = 0
			tip.Parent = marker

			table.insert(state.eventMarkerFrames, marker)
		end
	end
end

--------------------------------------------------------------------------------
-- Element Rendering (Bars, Points, Lines)
--------------------------------------------------------------------------------

local function ensureElements(state: ChartState, count: number)
	local chart = state.chartFrame
	local vizConfig = state.config.visualization

	-- Remove excess elements
	while #state.elements > count do
		local el = table.remove(state.elements)
		if el then
			el:Destroy()
		end
	end

	-- Add missing elements
	while #state.elements < count do
		local i = #state.elements + 1
		local el = Instance.new("Frame")
		el.Name = "Element" .. i
		el.BorderSizePixel = 0
		el.ZIndex = 3

		if vizConfig.mode == "point" then
			el.Size = UDim2.fromOffset(vizConfig.pointSize or DEFAULT_POINT_SIZE, vizConfig.pointSize or DEFAULT_POINT_SIZE)
			el.AnchorPoint = Vector2.new(0.5, 0.5)
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = el
		else
			-- Bar mode (default)
			el.AnchorPoint = Vector2.new(0, 1)
		end

		el.Parent = chart
		table.insert(state.elements, el)
	end
end

local function renderElements(state: ChartState, bucketValues: { { value: number, hasData: boolean } }, rangeMin: number, rangeMax: number, windowStart: number, timeWindow: number)
	local vizConfig = state.config.visualization
	local numBuckets = #bucketValues
	local bucketWidth = 1 / numBuckets
	local barGap = vizConfig.barGap or 0

	ensureElements(state, numBuckets)

	-- Also create line segments for point mode with connections
	local _lineSegments: { Frame } = {}

	for i, bucket in ipairs(bucketValues) do
		local el = state.elements[i]
		if not el then
			continue
		end

		if bucket.hasData then
			local yPos = getYPosition(state, bucket.value, rangeMin, rangeMax)
			local color = getValueColor(state, bucket.value, windowStart + (i - 0.5) * (timeWindow / numBuckets), i)

			if vizConfig.mode == "bar" then
				local height = (state.chartHeight - yPos) / state.chartHeight
				el.Size = UDim2.fromScale(bucketWidth - barGap, height)
				el.Position = UDim2.fromScale((i - 1) * bucketWidth, 1)
				el.BackgroundColor3 = color
				el.Visible = true
			elseif vizConfig.mode == "point" then
				local xPos = ((i - 0.5) / numBuckets) * state.chartWidth
				el.Position = UDim2.fromOffset(xPos, yPos)
				el.BackgroundColor3 = color
				el.Visible = true

				-- Draw connecting line to next point
				if vizConfig.connectPoints and i < numBuckets then
					local nextBucket = bucketValues[i + 1]
					if nextBucket and nextBucket.hasData then
						local nextYPos = getYPosition(state, nextBucket.value, rangeMin, rangeMax)
						local nextXPos = ((i + 0.5) / numBuckets) * state.chartWidth

						local dx = nextXPos - xPos
						local dy = nextYPos - yPos
						local length = math.sqrt(dx * dx + dy * dy)
						local angle = math.atan2(dy, dx)

						local line = Instance.new("Frame")
						line.Name = "Line" .. i
						line.Size = UDim2.fromOffset(math.max(length, 1), vizConfig.lineThickness or DEFAULT_LINE_THICKNESS)
						line.Position = UDim2.fromOffset(xPos, yPos)
						line.AnchorPoint = Vector2.new(0, 0.5)
						line.Rotation = math.deg(angle)
						line.BackgroundColor3 = color
						line.BackgroundTransparency = 0.3
						line.BorderSizePixel = 0
						line.ZIndex = 2
						line.Parent = state.chartFrame
						table.insert(_lineSegments, line)
					end
				end
			elseif vizConfig.mode == "line" then
				-- Line mode: draw segments between consecutive points
				if i < numBuckets then
					local nextBucket = bucketValues[i + 1]
					if nextBucket and nextBucket.hasData then
						local xPos = ((i - 0.5) / numBuckets) * state.chartWidth
						local nextYPos = getYPosition(state, nextBucket.value, rangeMin, rangeMax)
						local nextXPos = ((i + 0.5) / numBuckets) * state.chartWidth

						local dx = nextXPos - xPos
						local dy = nextYPos - yPos
						local length = math.sqrt(dx * dx + dy * dy)
						local angle = math.atan2(dy, dx)

						el.Size = UDim2.fromOffset(math.max(length, 1), vizConfig.lineThickness or DEFAULT_LINE_THICKNESS)
						el.Position = UDim2.fromOffset(xPos, yPos)
						el.AnchorPoint = Vector2.new(0, 0.5)
						el.Rotation = math.deg(angle)
						el.BackgroundColor3 = color
						el.Visible = true
					else
						el.Visible = false
					end
				else
					el.Visible = false
				end
			end
		else
			el.Visible = false
		end
	end
end

--------------------------------------------------------------------------------
-- Y-Axis Labels and Grid
--------------------------------------------------------------------------------

local function updateYAxisLabels(state: ChartState, rangeMin: number, rangeMax: number)
	local config = state.config.yAxis
	local labelConfig = config.labels

	if not labelConfig then
		return
	end

	local values: { number }
	if labelConfig.values then
		values = labelConfig.values
	elseif labelConfig.autoCount then
		values = {}
		local step = (rangeMax - rangeMin) / (labelConfig.autoCount - 1)
		for i = 0, labelConfig.autoCount - 1 do
			table.insert(values, rangeMin + i * step)
		end
	else
		return
	end

	-- Ensure we have enough labels
	while #state.yAxisLabels < #values do
		local label = Instance.new("TextLabel")
		label.Name = "YLabel" .. #state.yAxisLabels
		label.Size = UDim2.new(1, -4, 0, 14)
		label.BackgroundTransparency = 1
		label.TextColor3 = labelConfig.color or colors.defaultGrey
		label.FontFace = fonts.GetFont(true, false)
		label.TextSize = labelConfig.fontSize or DEFAULT_Y_AXIS_FONT_SIZE
		label.TextXAlignment = Enum.TextXAlignment.Right
		label.Parent = state.yAxisFrame
		table.insert(state.yAxisLabels, label)
	end

	-- Update labels
	local unitSymbol = config.unitSymbol or ""
	for i, value in ipairs(values) do
		local label = state.yAxisLabels[i]
		if label then
			local yPos = getYPosition(state, value, rangeMin, rangeMax)
			label.Position = UDim2.fromOffset(0, yPos - 7)
			label.Text = string.format("%.1f%s", value, unitSymbol)

			-- Bold override
			local isBold = false
			if labelConfig.boldValues then
				for _, boldVal in ipairs(labelConfig.boldValues) do
					if math.abs(boldVal - value) < 0.01 then
						isBold = true
						break
					end
				end
			end
			label.FontFace = fonts.GetFont(true, isBold)

			-- Color override
			if labelConfig.colorOverrides and labelConfig.colorOverrides[value] then
				label.TextColor3 = labelConfig.colorOverrides[value]
			else
				label.TextColor3 = labelConfig.color or colors.defaultGrey
			end

			label.Visible = true
		end
	end

	-- Hide extra labels
	for i = #values + 1, #state.yAxisLabels do
		state.yAxisLabels[i].Visible = false
	end
end

local function updateGridLines(state: ChartState, rangeMin: number, rangeMax: number)
	local config = state.config.yAxis
	local gridConfig = config.gridLines

	if not gridConfig then
		return
	end

	local values: { number }
	if gridConfig.values then
		values = gridConfig.values
	elseif gridConfig.autoCount then
		values = {}
		local step = (rangeMax - rangeMin) / (gridConfig.autoCount + 1)
		for i = 1, gridConfig.autoCount do
			table.insert(values, rangeMin + i * step)
		end
	else
		return
	end

	-- Ensure we have enough grid lines
	while #state.gridLines < #values do
		local line = Instance.new("Frame")
		line.Name = "GridLine" .. #state.gridLines
		line.Size = UDim2.new(1, 0, 0, 1)
		line.BackgroundColor3 = gridConfig.color or colors.defaultGrey
		line.BackgroundTransparency = gridConfig.transparency or 0.7
		line.BorderSizePixel = 0
		line.ZIndex = 1
		line.Parent = state.chartFrame
		table.insert(state.gridLines, line)
	end

	-- Update positions
	for i, value in ipairs(values) do
		local line = state.gridLines[i]
		if line then
			local yPos = getYPosition(state, value, rangeMin, rangeMax)
			line.Position = UDim2.fromOffset(0, yPos)
			line.Visible = true
		end
	end

	-- Hide extra lines
	for i = #values + 1, #state.gridLines do
		state.gridLines[i].Visible = false
	end
end

-- Choose a "nice" interval for vertical grid lines based on time window
-- Returns an interval that produces rounded numbers (5s, 10s, 15s, 30s, 60s, etc.)
local NICE_INTERVALS = { 1, 2, 5, 10, 15, 20, 30, 60, 120, 300, 600 }

local function chooseVerticalGridInterval(timeWindow: number, targetCount: number): number
	-- We want approximately targetCount lines
	local idealInterval = timeWindow / (targetCount + 1)

	-- Find the closest "nice" interval
	for _, interval in ipairs(NICE_INTERVALS) do
		if interval >= idealInterval * 0.7 then
			return interval
		end
	end

	return NICE_INTERVALS[#NICE_INTERVALS]
end

local function updateVerticalGridLines(state: ChartState, windowStart: number, timeWindow: number)
	local config = state.config.xAxis
	local gridConfig = config.gridLines

	if not gridConfig or not gridConfig.enabled then
		-- Hide all existing vertical grid lines
		for _, line in ipairs(state.verticalGridLines) do
			line.Visible = false
		end
		return
	end

	local chart = state.chartFrame
	local chartHeight = state.chartHeight
	local chartWidth = state.chartWidth
	local yAxisWidth = state.config.yAxis.width or DEFAULT_Y_AXIS_WIDTH

	-- Determine interval
	local interval: number
	if gridConfig.intervalSeconds then
		interval = gridConfig.intervalSeconds
	else
		local targetCount = gridConfig.targetCount or 3
		interval = chooseVerticalGridInterval(timeWindow, targetCount)
	end

	-- Calculate grid line positions
	-- Lines at multiples of interval within the visible window
	local windowEnd = windowStart + timeWindow
	local firstLine = math.ceil(windowStart / interval) * interval
	local linePositions: { number } = {}

	local t = firstLine
	while t < windowEnd do
		-- Don't place line at the very edge
		local relativePos = (t - windowStart) / timeWindow
		if relativePos > 0.05 and relativePos < 0.95 then
			table.insert(linePositions, t)
		end
		t = t + interval
	end

	-- Ensure we have enough line elements
	while #state.verticalGridLines < #linePositions do
		local i = #state.verticalGridLines + 1
		local line = Instance.new("Frame")
		line.Name = "VerticalGridLine" .. i
		line.Size = UDim2.new(0, 1, 1, 0)
		line.BackgroundColor3 = gridConfig.color or colors.defaultGrey
		line.BackgroundTransparency = gridConfig.transparency or 0.8
		line.BorderSizePixel = 0
		line.ZIndex = 1
		line.Parent = chart
		table.insert(state.verticalGridLines, line)
	end

	-- Update positions
	for i, lineTime in ipairs(linePositions) do
		local line = state.verticalGridLines[i]
		if line then
			local relativePos = (lineTime - windowStart) / timeWindow
			local xPos = relativePos * (chartWidth - yAxisWidth)
			line.Position = UDim2.fromOffset(xPos, 0)
			line.Visible = true
		end
	end

	-- Hide extra lines
	for i = #linePositions + 1, #state.verticalGridLines do
		state.verticalGridLines[i].Visible = false
	end
end

--------------------------------------------------------------------------------
-- Direct Point Rendering (prevents flickering for point charts)
--------------------------------------------------------------------------------

-- Render actual data points directly without bucketing
-- This is used when visualization.renderDirect = true for point mode
local function renderDirectPoints(state: ChartState, rangeMin: number, rangeMax: number, windowStart: number, timeWindow: number)
	local vizConfig = state.config.visualization
	local chart = state.chartFrame
	local pointSize = vizConfig.pointSize or DEFAULT_POINT_SIZE

	-- Collect visible data points
	local visiblePoints: { DataPoint } = {}
	for _, point in ipairs(state.dataPoints) do
		if point.time >= windowStart and point.time <= windowStart + timeWindow then
			table.insert(visiblePoints, point)
		end
	end

	-- Ensure we have enough point elements
	while #state.elements > #visiblePoints do
		local el = table.remove(state.elements)
		if el then
			el:Destroy()
		end
	end

	while #state.elements < #visiblePoints do
		local i = #state.elements + 1
		local el = Instance.new("Frame")
		el.Name = "Point" .. i
		el.Size = UDim2.fromOffset(pointSize, pointSize)
		el.AnchorPoint = Vector2.new(0.5, 0.5)
		el.BorderSizePixel = 0
		el.ZIndex = 3
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = el
		el.Parent = chart
		table.insert(state.elements, el)
	end

	-- Render each visible point at its actual position
	for i, point in ipairs(visiblePoints) do
		local el = state.elements[i]
		if not el then
			continue
		end

		local relativeTime = (point.time - windowStart) / timeWindow
		local xPos = relativeTime * state.chartWidth
		local yPos = getYPosition(state, point.value, rangeMin, rangeMax)
		local color = getValueColor(state, point.value, point.time, i)

		el.Position = UDim2.fromOffset(xPos, yPos)
		el.BackgroundColor3 = color
		el.Visible = true
	end

	-- Hide any extra elements (shouldn't happen, but safety)
	for i = #visiblePoints + 1, #state.elements do
		state.elements[i].Visible = false
	end
end

--------------------------------------------------------------------------------
-- Data Management (Bucket-based for uniform resolution)
-- Defined here before Multi-Series Rendering which uses these functions
--------------------------------------------------------------------------------

-- Apply condensation strategy to a list of values
local function applyStrategy(values: { number }, strategy: string): number
	if #values == 0 then
		return 0
	end
	if #values == 1 then
		return values[1]
	end

	if strategy == "max" then
		local result = values[1]
		for i = 2, #values do
			if values[i] > result then
				result = values[i]
			end
		end
		return result
	elseif strategy == "min" then
		local result = values[1]
		for i = 2, #values do
			if values[i] < result then
				result = values[i]
			end
		end
		return result
	else -- "average"
		local sum = 0
		for _, v in ipairs(values) do
			sum = sum + v
		end
		return sum / #values
	end
end

-- Finalize the current bucket accumulator into a DataBucket (legacy single-series)
local function _finalizeBucket(accumulator: BucketAccumulator, bucketDuration: number, strategy: string): DataBucket
	return {
		startTime = accumulator.startTime + bucketDuration / 2, -- Use midpoint as time
		value = applyStrategy(accumulator.values, strategy),
	}
end

-- Finalize a unified bucket accumulator into a UnifiedTimeBucket
local function finalizeUnifiedBucket(accumulator: UnifiedBucketAccumulator, bucketDuration: number, seriesConfigs: { [string]: DataSeriesState }): UnifiedTimeBucket
	local finalValues: { [string]: number } = {}
	for seriesName, rawValues in pairs(accumulator.seriesValues) do
		if #rawValues > 0 then
			local strategy = if seriesConfigs[seriesName] then seriesConfigs[seriesName].condensationStrategy else "max"
			finalValues[seriesName] = applyStrategy(rawValues, strategy)
		end
	end
	return {
		time = accumulator.startTime + bucketDuration / 2, -- Use midpoint
		values = finalValues,
	}
end

-- Re-bucket unified data with doubled bucket duration
local function rebucketUnified(state: ChartState)
	local oldBuckets = state.timeBuckets
	local oldDuration = state.bucketDuration
	local newDuration = oldDuration * 2
	local seriesConfigs = state.dataSeries

	-- Combine pairs of adjacent buckets
	local newBuckets: { UnifiedTimeBucket } = {}
	for i = 1, #oldBuckets, 2 do
		local a = oldBuckets[i]
		local b = oldBuckets[i + 1]
		if b then
			-- Merge values from both buckets using per-series strategy
			local combinedValues: { [string]: number } = {}
			-- Collect all series names from both buckets
			local allSeries: { [string]: boolean } = {}
			for name, _ in pairs(a.values) do
				allSeries[name] = true
			end
			for name, _ in pairs(b.values) do
				allSeries[name] = true
			end
			-- Combine each series
			for seriesName, _ in pairs(allSeries) do
				local valA = a.values[seriesName]
				local valB = b.values[seriesName]
				local strategy = if seriesConfigs[seriesName] then seriesConfigs[seriesName].condensationStrategy else "max"
				if valA and valB then
					if strategy == "max" then
						combinedValues[seriesName] = math.max(valA, valB)
					elseif strategy == "min" then
						combinedValues[seriesName] = math.min(valA, valB)
					else
						combinedValues[seriesName] = (valA + valB) / 2
					end
				else
					combinedValues[seriesName] = valA or valB
				end
			end
			table.insert(newBuckets, {
				time = (a.time + b.time) / 2,
				values = combinedValues,
			})
		else
			-- Odd bucket at end, keep as-is
			table.insert(newBuckets, a)
		end
	end

	state.timeBuckets = newBuckets
	state.bucketDuration = newDuration
end

--------------------------------------------------------------------------------
-- Multi-Series Rendering
--------------------------------------------------------------------------------

-- Render all visible data series as points with their own colors (unified bucket version)
-- Single-pass rendering
local function renderMultiSeriesPoints(state: ChartState, rangeMin: number, rangeMax: number, windowStart: number, timeWindow: number)
	debug.profilebegin("timeSeriesChart.renderPoints")
	local vizConfig = state.config.visualization
	local chart = state.chartFrame
	local pointSize = vizConfig.pointSize or DEFAULT_POINT_SIZE
	local windowEnd = windowStart + timeWindow
	local bucketCount = #state.timeBuckets

	-- All buckets are within the visible window by design:
	-- - Sliding mode: buckets outside window are pruned in addSeriesDataPoint
	-- - All mode: window spans from chart start to now, covering all data
	local startIdx = 1
	local endIdx = bucketCount

	-- Pre-compute current bucket contribution (if visible)
	local currentBucketTime: number? = nil
	local currentBucketValues: { [string]: number } = {}
	if state.currentTimeBucket and state.currentTimeBucket.seriesValues then
		local t = state.currentTimeBucket.startTime + state.bucketDuration / 2
		if t >= windowStart and t <= windowEnd then
			currentBucketTime = t
			for seriesName, rawValues in pairs(state.currentTimeBucket.seriesValues) do
				if #rawValues > 0 then
					local series = state.dataSeries[seriesName]
					local strategy = if series then series.condensationStrategy else "max"
					currentBucketValues[seriesName] = applyStrategy(rawValues, strategy)
				end
			end
		end
	end

	-- Pre-compute shared layout constants
	local chartWidth = state.chartWidth
	local chartHeight = state.chartHeight
	local edgePadding = 4
	local usableHeight = chartHeight - (edgePadding * 2)
	local invTimeWindow = 1 / timeWindow

	-- Render each series
	for seriesName, series in pairs(state.dataSeries) do
		if not series.visible then
			-- Hide all elements for this series (only if currently visible)
			for _, el in ipairs(series.elements) do
				if el.Visible then
					el.Visible = false
				end
			end
			continue
		end

		-- Count visible points and compute auto-scale range in one pass
		local visibleCount = 0
		local minVal = math.huge
		local maxVal = -math.huge
		local useAutoScale = series.autoScale

		-- Count from finalized buckets
		for i = startIdx, endIdx do
			local val = state.timeBuckets[i].values[seriesName]
			if val then
				visibleCount = visibleCount + 1
				if useAutoScale then
					if val < minVal then
						minVal = val
					end
					if val > maxVal then
						maxVal = val
					end
				end
			end
		end

		-- Count current bucket contribution
		local currentVal = currentBucketValues[seriesName]
		if currentVal then
			visibleCount = visibleCount + 1
			if useAutoScale then
				if currentVal < minVal then
					minVal = currentVal
				end
				if currentVal > maxVal then
					maxVal = currentVal
				end
			end
		end

		-- Compute auto-scale range
		local seriesRangeMin = rangeMin
		local seriesRangeMax = rangeMax
		if useAutoScale and visibleCount > 0 then
			local range = maxVal - minVal
			if range < 1 then
				range = 1
			end
			seriesRangeMin = minVal - range * 0.05
			seriesRangeMax = maxVal + range * 0.05
		end
		local yRangeSpan = seriesRangeMax - seriesRangeMin
		local invYRange = if yRangeSpan > 0 then 1 / yRangeSpan else 1

		-- Manage element pool
		local poolSize = #series.elements

		-- Hide elements beyond what we need (only if currently visible)
		for i = visibleCount + 1, poolSize do
			local el = series.elements[i]
			if el.Visible then
				el.Visible = false
			end
		end

		-- Shrink pool if way too large (2x needed)
		while #series.elements > math.max(visibleCount * 2, 50) do
			local el = table.remove(series.elements)
			if el then
				el:Destroy()
			end
		end

		-- Grow pool if needed
		while #series.elements < visibleCount do
			local idx = #series.elements + 1
			local el = Instance.new("Frame")
			el.Name = seriesName .. "_Point" .. idx
			el.Size = UDim2.fromOffset(pointSize, pointSize)
			el.AnchorPoint = Vector2.new(0.5, 0.5)
			el.BorderSizePixel = 0
			el.ZIndex = 3
			el.BackgroundColor3 = series.color -- Set color once at creation
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = el
			el.Parent = chart
			table.insert(series.elements, el)
		end

		-- Render points directly from buckets (no intermediate tables)
		local elementIdx = 0

		for i = startIdx, endIdx do
			local bucket = state.timeBuckets[i]
			local val = bucket.values[seriesName]
			if val then
				elementIdx = elementIdx + 1
				local el = series.elements[elementIdx]
				if el then
					local relativeTime = (bucket.time - windowStart) * invTimeWindow
					local xPos = math.floor(relativeTime * chartWidth + 0.5)

					local yPos: number
					if useAutoScale then
						local normalizedValue = (val - seriesRangeMin) * invYRange
						yPos = math.floor(edgePadding + usableHeight * (1 - normalizedValue) + 0.5)
					else
						yPos = math.floor(getYPosition(state, val, rangeMin, rangeMax) + 0.5)
					end

					el.Position = UDim2.fromOffset(xPos, yPos)

					-- Only set Visible if not already visible
					if not el.Visible then
						el.Visible = true
					end
				end
			end
		end

		-- Render current bucket point if applicable (reuse currentVal from counting pass)
		if currentBucketTime and currentVal then
			elementIdx = elementIdx + 1
			local el = series.elements[elementIdx]
			if el then
				local relativeTime = (currentBucketTime - windowStart) * invTimeWindow
				local xPos = math.floor(relativeTime * chartWidth + 0.5)

				local yPos: number
				if useAutoScale then
					local normalizedValue = (currentVal - seriesRangeMin) * invYRange
					yPos = math.floor(edgePadding + usableHeight * (1 - normalizedValue) + 0.5)
				else
					yPos = math.floor(getYPosition(state, currentVal, rangeMin, rangeMax) + 0.5)
				end

				el.Position = UDim2.fromOffset(xPos, yPos)

				if not el.Visible then
					el.Visible = true
				end
			end
		end
	end
	debug.profileend()
end

-- Render all visible marker categories as points with large labels
-- Renders directly from marker data
local function renderMultiSeriesMarkers(state: ChartState, windowStart: number, timeWindow: number)
	debug.profilebegin("timeSeriesChart.renderMarkers")
	local chart = state.chartFrame
	local pointSize = 10 -- Marker point size
	local windowEnd = windowStart + timeWindow
	local invTimeWindow = 1 / timeWindow

	for categoryName, category in pairs(state.markerCategories) do
		if not category.visible then
			-- Hide all elements for this category (only if currently visible)
			for _, el in ipairs(category.elements) do
				if el.Visible then
					el.Visible = false
				end
			end
			continue
		end

		-- Count visible markers without allocating a table
		local visibleCount = 0
		for _, marker in ipairs(category.markers) do
			if marker.time >= windowStart and marker.time <= windowEnd then
				visibleCount = visibleCount + 1
			end
		end

		-- Manage marker element pool for this category
		local poolSize = #category.elements

		-- Hide elements beyond what we need (only if currently visible)
		for i = visibleCount + 1, poolSize do
			local el = category.elements[i]
			if el.Visible then
				el.Visible = false
			end
		end

		-- Only destroy if pool is way too large (2x needed)
		while #category.elements > math.max(visibleCount * 2, 20) do
			local el = table.remove(category.elements)
			if el then
				el:Destroy()
			end
		end

		-- Create new elements if pool is too small
		while #category.elements < visibleCount do
			local i = #category.elements + 1
			-- Create container for point + label
			local el = Instance.new("Frame")
			el.Name = categoryName .. "_Marker" .. i
			el.Size = UDim2.fromOffset(pointSize, pointSize)
			el.AnchorPoint = Vector2.new(0.5, 0.5)
			el.BorderSizePixel = 0
			el.ZIndex = 5
			el.BackgroundTransparency = 0

			-- Make point circular
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = el

			-- Add label below the point (labels always go below for clarity at top of chart)
			local label = Instance.new("TextLabel")
			label.Name = "Label"
			label.Size = UDim2.fromOffset(60, 16)
			label.Position = UDim2.fromOffset(0, 10)
			label.AnchorPoint = Vector2.new(0.5, 0)
			label.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
			label.BackgroundTransparency = 0.3
			label.TextSize = 18
			label.FontFace = fonts.GetFont(false, true) -- Bold for clarity
			label.TextXAlignment = Enum.TextXAlignment.Center
			label.TextYAlignment = Enum.TextYAlignment.Center
			label.Parent = el

			el.Parent = chart
			table.insert(category.elements, el)
		end

		-- Render each visible marker directly from source data
		local elementIdx = 0
		local lastLabelX: number? = nil
		local minLabelSpacing = 60 -- Minimum pixels between visible labels
		local rowSpacing = 24 -- Increased spacing to prevent vertical label overlap
		local chartWidth = state.chartWidth
		local yBase = pointSize / 2 + 4 + (category.row - 1) * rowSpacing

		for _, marker in ipairs(category.markers) do
			if marker.time < windowStart or marker.time > windowEnd then
				continue
			end

			elementIdx = elementIdx + 1
			local el = category.elements[elementIdx]
			if not el then
				continue
			end

			local relativeTime = (marker.time - windowStart) * invTimeWindow
			local xPos = math.floor(relativeTime * chartWidth + 0.5)
			local markerColor = marker.color or category.color

			el.Position = UDim2.fromOffset(xPos, yBase)

			-- Only set color if changed
			if el.BackgroundColor3 ~= markerColor then
				el.BackgroundColor3 = markerColor
			end

			-- Update label - only show if sufficiently spaced from previous label
			local label = el:FindFirstChild("Label")
			if label and label:IsA("TextLabel") then
				local showLabel = (lastLabelX == nil) or (xPos - lastLabelX >= minLabelSpacing)
				if showLabel then
					local labelText = marker.label or categoryName
					if label.Text ~= labelText then
						label.Text = labelText
					end
					if label.TextColor3 ~= markerColor then
						label.TextColor3 = markerColor
					end
					if not label.Visible then
						label.Visible = true
					end
					lastLabelX = xPos
				else
					if label.Visible then
						label.Visible = false
					end
				end
			end

			if not el.Visible then
				el.Visible = true
			end
		end
	end
	debug.profileend()
end

--------------------------------------------------------------------------------
-- Current Value Indicator
--------------------------------------------------------------------------------

local function updateCurrentValueIndicator(state: ChartState, rangeMin: number, rangeMax: number)
	local config = state.config.currentValue
	if not config or not config.enabled then
		return
	end

	local label = state.currentValueLabel
	if not label then
		return
	end

	local value = state.currentValue
	if not value then
		label.Visible = false
		return
	end

	local yPos = getYPosition(state, value, rangeMin, rangeMax)
	local formatString = config.formatString or "%.1f"
	label.Text = string.format(formatString, value)
	label.Position = UDim2.new(1, -62, 0, math.clamp(yPos, 8, state.chartHeight - 8))
	label.TextColor3 = config.color or state.config.color.color or colors.warpColor
	label.Visible = true
end

--------------------------------------------------------------------------------
-- Main Update Function
--------------------------------------------------------------------------------

local function updateChart(state: ChartState)
	debug.profilebegin("timeSeriesChart.updateChart")
	local frameStart = tick()
	local chart = state.chartFrame
	if not chart then
		debug.profileend()
		return
	end

	-- Check if there's any data to render
	local hasData = #state.dataPoints > 0
	if state.isMultiSeriesMode then
		-- Check unified buckets for data
		if #state.timeBuckets > 0 then
			hasData = true
		elseif state.currentTimeBucket then
			for _, values in pairs(state.currentTimeBucket.seriesValues) do
				if #values > 0 then
					hasData = true
					break
				end
			end
		end
	end
	if not hasData then
		return
	end

	local now = tick()
	local windowConfig = state.config.window
	local bucketConfig = state.config.buckets

	-- Window calculations: use wall-clock time when live, or latestDataTime when paused.
	-- When paused (e.g., run ended), freezing at latestDataTime prevents the sliding window
	-- from moving past historical data and allows filter toggling on frozen data.
	local effectiveNow: number
	if state.isPaused and state.latestDataTime > 0 then
		effectiveNow = state.latestDataTime
	else
		effectiveNow = now
	end

	-- Calculate window
	local timeWindow: number
	local windowStart: number

	if windowConfig.mode == "all" then
		-- Guard against uninitialized windowStartTick (would cause infinite loop in updateTimeMarkers)
		local safeWindowStart = if state.windowStartTick > 0 then state.windowStartTick else effectiveNow - 1
		timeWindow = math.max(1, effectiveNow - safeWindowStart)
		windowStart = safeWindowStart
	else
		timeWindow = windowConfig.windowDuration or 10
		-- Sliding window start updates every frame (no rounding/quantization).
		windowStart = effectiveNow - timeWindow
	end

	-- NOTE: no "skip render" early-exit. If updateChart() runs, it performs a full render pass.

	-- Calculate bucket count
	local numBuckets: number
	if bucketConfig.mode == "fixed" then
		numBuckets = bucketConfig.fixedCount or 60
	else
		local yAxisWidth = state.config.yAxis.width or DEFAULT_Y_AXIS_WIDTH
		local chartAreaWidth = state.chartWidth - yAxisWidth - 8
		local targetPixels = bucketConfig.targetPixelWidth or DEFAULT_TARGET_BUCKET_PIXELS
		numBuckets = math.max(bucketConfig.minBuckets or DEFAULT_MIN_BUCKETS, math.floor(chartAreaWidth / targetPixels))
	end

	-- Calculate range from visible data
	local yAxisConfig = state.config.yAxis
	local rangeMin: number
	local rangeMax: number

	if yAxisConfig.rangeMode == "fixed" then
		rangeMin = yAxisConfig.fixedMin or 0
		rangeMax = yAxisConfig.fixedMax or 100
	else
		-- Auto range from data
		local visibleMin = math.huge
		local visibleMax = -math.huge
		for _, point in ipairs(state.dataPoints) do
			if point.time >= windowStart then
				if point.value < visibleMin then
					visibleMin = point.value
				end
				if point.value > visibleMax then
					visibleMax = point.value
				end
			end
		end

		if visibleMin == math.huge then
			visibleMin = 0
			visibleMax = 100
		end

		local paddingAbove = if yAxisConfig.padding then yAxisConfig.padding.above else DEFAULT_PADDING
		local paddingBelow = if yAxisConfig.padding then yAxisConfig.padding.below else DEFAULT_PADDING

		rangeMin = visibleMin - (paddingBelow or DEFAULT_PADDING)
		rangeMax = visibleMax + (paddingAbove or DEFAULT_PADDING)

		if yAxisConfig.rangeMode == "autoWithZero" then
			rangeMin = math.min(rangeMin, 0)
		end

		-- Apply minimum range
		local minRange = yAxisConfig.minRange or DEFAULT_MIN_RANGE
		if rangeMax - rangeMin < minRange then
			local mid = (rangeMin + rangeMax) / 2
			rangeMin = mid - minRange / 2
			rangeMax = mid + minRange / 2
		end
	end

	local vizConfig = state.config.visualization

	-- Direct rendering mode for point charts: render actual data points instead of bucketing
	-- This prevents flickering caused by bucket boundary shifts in sliding windows
	if vizConfig.renderDirect and vizConfig.mode == "point" then
		renderDirectPoints(state, rangeMin, rangeMax, windowStart, timeWindow)
	else
		-- Aggregate data into buckets
		local bucketValues: { { value: number, hasData: boolean } } = {}
		local bucketDuration = timeWindow / numBuckets
		local aggregation = bucketConfig.aggregation

		-- For sliding windows, align bucket boundaries to fixed absolute time intervals
		-- This prevents the "shaking" effect caused by boundaries shifting every frame
		-- Buckets are aligned to multiples of bucketDuration (e.g., 0.0, 0.5, 1.0, 1.5...)
		-- and only shift when now crosses a bucket boundary
		local useSlidingAlignment = windowConfig.mode == "sliding"

		-- For sliding mode: find the rightmost bucket boundary (aligned to bucketDuration)
		-- The rightmost bucket ends at the next multiple of bucketDuration >= now
		local alignedRightEdge: number
		if useSlidingAlignment then
			alignedRightEdge = math.ceil(now / bucketDuration) * bucketDuration
		else
			alignedRightEdge = windowStart + timeWindow
		end

		for i = 1, numBuckets do
			local bucketStart: number
			local bucketEnd: number

			if useSlidingAlignment then
				-- Sliding mode: buckets aligned to fixed time intervals
				-- Work backwards from alignedRightEdge
				local bucketsFromRight = numBuckets - i
				bucketEnd = alignedRightEdge - bucketsFromRight * bucketDuration
				bucketStart = bucketEnd - bucketDuration
			else
				-- All mode: anchor buckets relative to windowStart
				bucketStart = windowStart + (i - 1) * bucketDuration
				bucketEnd = windowStart + i * bucketDuration
			end

			local values: { number } = {}
			for _, point in ipairs(state.dataPoints) do
				if point.time >= bucketStart and point.time < bucketEnd then
					table.insert(values, point.value)
				end
			end

			local resultValue = 0
			local bucketHasData = #values > 0

			if bucketHasData then
				if aggregation == "max" then
					resultValue = -math.huge
					for _, v in ipairs(values) do
						if v > resultValue then
							resultValue = v
						end
					end
				elseif aggregation == "min" then
					resultValue = math.huge
					for _, v in ipairs(values) do
						if v < resultValue then
							resultValue = v
						end
					end
				elseif aggregation == "average" then
					local sum = 0
					for _, v in ipairs(values) do
						sum = sum + v
					end
					resultValue = sum / #values
				elseif aggregation == "last" then
					resultValue = values[#values]
				end
			end

			table.insert(bucketValues, { value = resultValue, hasData = bucketHasData })
		end

		-- Render
		renderElements(state, bucketValues, rangeMin, rangeMax, windowStart, timeWindow)
	end

	-- Multi-series rendering (in addition to or instead of single-series)
	if state.isMultiSeriesMode then
		renderMultiSeriesPoints(state, rangeMin, rangeMax, windowStart, timeWindow)
		renderMultiSeriesMarkers(state, windowStart, timeWindow)
	end

	updateYAxisLabels(state, rangeMin, rangeMax)
	updateGridLines(state, rangeMin, rangeMax)
	updateVerticalGridLines(state, windowStart, timeWindow)
	updateTimeMarkers(state, windowStart, timeWindow, now)
	updateEventMarkers(state, windowStart, timeWindow)
	updateCurrentValueIndicator(state, rangeMin, rangeMax)

	-- Perf tracking (silent in production, stats available via bucketInfoLabel)

	-- Update bucket info label (for multi-series mode)
	if state.bucketInfoLabel and state.isMultiSeriesMode then
		local totalBuckets = #state.timeBuckets
		local bucketDuration = state.bucketDuration
		-- Format duration: show as ms if < 1s, otherwise as seconds
		local durationStr: string
		if bucketDuration < 1 then
			durationStr = string.format("%dms", math.floor(bucketDuration * 1000 + 0.5))
		else
			durationStr = string.format("%.1fs", bucketDuration)
		end
		state.bucketInfoLabel.Text = string.format("%d @ %s", totalBuckets, durationStr)
	end
	debug.profileend()

	-- Per-frame cost (only log when dropping frames)
	local elapsedMs = (tick() - frameStart) * 1000
	if elapsedMs >= 16 then
		warn(string.format("[Chart] slow frame: %.1fms", elapsedMs))
	end
end

--------------------------------------------------------------------------------
-- Legacy Data Condensation (for single-series mode backwards compatibility)
--------------------------------------------------------------------------------

local function condenseData(dataPoints: { DataPoint }, strategy: string): { DataPoint }
	local condensed: { DataPoint } = {}
	for i = 1, #dataPoints, 2 do
		local a = dataPoints[i]
		local b = dataPoints[i + 1]
		if b then
			local resultValue: number
			if strategy == "average" then
				resultValue = (a.value + b.value) / 2
			elseif strategy == "max" then
				resultValue = math.max(a.value, b.value)
			elseif strategy == "min" then
				resultValue = math.min(a.value, b.value)
			else
				resultValue = (a.value + b.value) / 2
			end
			table.insert(condensed, {
				time = (a.time + b.time) / 2,
				value = resultValue,
			})
		else
			table.insert(condensed, a)
		end
	end
	return condensed
end

--------------------------------------------------------------------------------
-- Resize Handle
--------------------------------------------------------------------------------

local function createResizeHandle(state: ChartState): (() -> ())?
	local config = state.config.resize
	if not config or not config.enabled or config.handlePosition == "none" then
		return nil
	end

	local container = state.container
	local isResizing = false
	local resizeStartPos = Vector2.zero
	local resizeStartSize = Vector2.zero
	local connections: { RBXScriptConnection } = {}

	local handle = Instance.new("TextButton")
	handle.Name = "ResizeHandle"
	handle.Size = UDim2.fromOffset(16, 16)
	handle.BackgroundColor3 = colors.defaultGrey
	handle.BackgroundTransparency = 0.5
	handle.BorderSizePixel = 0
	handle.ZIndex = 20
	handle.Text = ""
	handle.AutoButtonColor = false

	if config.handlePosition == "bottomRight" then
		handle.Position = UDim2.new(1, -16, 1, -16)
	elseif config.handlePosition == "right" then
		handle.Size = UDim2.fromOffset(8, 40)
		handle.Position = UDim2.new(1, -4, 0.5, 0)
		handle.AnchorPoint = Vector2.new(0.5, 0.5)
	elseif config.handlePosition == "left" then
		handle.Size = UDim2.fromOffset(8, 40)
		handle.Position = UDim2.new(0, 4, 0.5, 0)
		handle.AnchorPoint = Vector2.new(0.5, 0.5)
	end

	-- Grip dots
	for i = 0, 2 do
		local grip = Instance.new("Frame")
		grip.Size = UDim2.fromOffset(2, 2)
		grip.Position = UDim2.fromOffset(4 + i * 4, 4 + i * 4)
		grip.BackgroundColor3 = colors.white
		grip.BackgroundTransparency = 0.5
		grip.BorderSizePixel = 0
		grip.Parent = handle
	end

	handle.Parent = container

	-- handle.InputBegan only fires when the handle receives input (Roblox handles layer order)
	table.insert(
		connections,
		handle.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				local clickPos = Vector2.new(input.Position.X, input.Position.Y)
				isResizing = true
				resizeStartPos = clickPos
				resizeStartSize = Vector2.new(container.Size.X.Offset, container.Size.Y.Offset)
			end
		end)
	)

	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input)
			if isResizing and input.UserInputType == Enum.UserInputType.MouseMovement then
				local delta = Vector2.new(input.Position.X, input.Position.Y) - resizeStartPos
				local newWidth = math.clamp(resizeStartSize.X + delta.X, config.minWidth, config.maxWidth or 9999)
				local newHeight = math.clamp(resizeStartSize.Y + delta.Y, config.minHeight, config.maxHeight or 1000)

				if config.lockAspectRatio and config.aspectRatio then
					newHeight = newWidth / config.aspectRatio
				end

				container.Size = UDim2.fromOffset(newWidth, newHeight)
				state.chartWidth = newWidth
				state.chartHeight = newHeight - (state.config.title.height or DEFAULT_TITLE_HEIGHT) - (state.config.xAxis.height or DEFAULT_X_AXIS_HEIGHT)

				-- Update chart frame size
				local cfgYAxisWidth = state.config.yAxis.width or DEFAULT_Y_AXIS_WIDTH
				local cfgTitleHeight = state.config.title.height or DEFAULT_TITLE_HEIGHT
				local cfgXAxisHeight = state.config.xAxis.height or DEFAULT_X_AXIS_HEIGHT
				state.chartFrame.Size = UDim2.new(1, -(cfgYAxisWidth + 4), 1, -(cfgTitleHeight + cfgXAxisHeight + 4))

				updateChart(state)
			end
		end)
	)

	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 and isResizing then
				isResizing = false
			end
		end)
	)

	return function()
		for _, conn in ipairs(connections) do
			conn:Disconnect()
		end
		if handle then
			handle:Destroy()
		end
	end
end

--------------------------------------------------------------------------------
-- Factory Function
--------------------------------------------------------------------------------

function module.create(parent: Frame, name: string, position: UDim2?, _initialWidth: number?, _initialHeight: number?, config: ChartConfig): ChartHandle
	local titleHeight = config.title.height or DEFAULT_TITLE_HEIGHT
	local yAxisWidth = config.yAxis.width or DEFAULT_Y_AXIS_WIDTH
	local xAxisHeight = config.xAxis.height or DEFAULT_X_AXIS_HEIGHT

	-- Always use fill-parent mode: chart fills its container
	-- Parent container controls the size; chart auto-adjusts
	-- (initialWidth/initialHeight params kept for API compatibility but ignored)

	-- Main container
	local container = Instance.new("Frame")
	container.Name = name
	container.Size = UDim2.fromScale(1, 1)
	container.AnchorPoint = Vector2.new(0, 0)
	container.BackgroundColor3 = config.background and config.background.color or Color3.fromRGB(30, 35, 45)
	container.BackgroundTransparency = config.background and config.background.transparency or 0.1
	container.BorderSizePixel = 1
	container.BorderColor3 = colors.black

	if position then
		container.Position = position
	end

	container.Parent = parent

	-- Get actual dimensions from AbsoluteSize (fill-parent mode)
	local absSize = container.AbsoluteSize
	local actualWidth = absSize.X
	local actualHeight = absSize.Y
	-- Fallback to reasonable defaults if not yet laid out
	if actualWidth < 10 then
		actualWidth = 400
	end
	if actualHeight < 10 then
		actualHeight = 200
	end

	-- Title bar
	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, titleHeight)
	titleBar.BackgroundColor3 = config.title.backgroundColor or colors.signColor
	titleBar.BackgroundTransparency = 0
	titleBar.BorderSizePixel = 1
	titleBar.BorderColor3 = colors.black
	titleBar.Parent = container

	local titleText = (config.title.symbol or "") .. " " .. config.title.text
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.fromScale(1, 1)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = config.title.textColor or colors.white
	titleLabel.FontFace = fonts.GetFont(false, true)
	titleLabel.TextScaled = true
	titleLabel.Text = titleText
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.Parent = titleBar

	local titleConstraint = Instance.new("UITextSizeConstraint")
	titleConstraint.MaxTextSize = 16
	titleConstraint.Parent = titleLabel

	-- Minimize button size
	local minimizeButtonSize = titleHeight - 4

	-- Bucket info label (right-aligned in title bar, shifted left if minimize enabled)
	local minimizeConfig = config.title.minimize
	local hasMinimize = minimizeConfig and minimizeConfig.enabled
	local bucketInfoRightPadding = if hasMinimize then minimizeButtonSize + 6 else 4

	local bucketInfoLabel = Instance.new("TextLabel")
	bucketInfoLabel.Name = "BucketInfo"
	bucketInfoLabel.Size = UDim2.new(0.4, -bucketInfoRightPadding, 1, 0)
	bucketInfoLabel.Position = UDim2.new(0.6, 2, 0, 0)
	bucketInfoLabel.BackgroundTransparency = 1
	bucketInfoLabel.TextColor3 = colors.white
	bucketInfoLabel.FontFace = fonts.GetFont(true, false) -- Monospace
	bucketInfoLabel.TextSize = 11
	bucketInfoLabel.Text = ""
	bucketInfoLabel.TextXAlignment = Enum.TextXAlignment.Right
	bucketInfoLabel.Parent = titleBar

	-- Minimize button (right side of title bar)
	local minimizeButton: TextButton? = nil
	if hasMinimize then
		local btn = Instance.new("TextButton")
		btn.Name = "MinimizeButton"
		btn.Size = UDim2.fromOffset(minimizeButtonSize, minimizeButtonSize)
		btn.Position = UDim2.new(1, -(minimizeButtonSize + 2), 0, 2)
		btn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
		btn.BackgroundTransparency = 0.3
		btn.BorderSizePixel = 1
		btn.BorderColor3 = colors.defaultGrey
		btn.Text = "-"
		btn.TextColor3 = colors.white
		btn.FontFace = fonts.GetFont(true, true)
		btn.TextSize = 14
		btn.Parent = titleBar
		minimizeButton = btn
	end

	-- Y-axis frame
	local yAxisFrame = Instance.new("Frame")
	yAxisFrame.Name = "YAxis"
	yAxisFrame.Size = UDim2.new(0, yAxisWidth, 1, -(titleHeight + xAxisHeight))
	yAxisFrame.Position = UDim2.fromOffset(0, titleHeight)
	yAxisFrame.BackgroundTransparency = 1
	yAxisFrame.Parent = container

	-- Chart area
	local chartFrame = Instance.new("Frame")
	chartFrame.Name = "ChartArea"
	chartFrame.Size = UDim2.new(1, -(yAxisWidth + 4), 1, -(titleHeight + xAxisHeight + 4))
	chartFrame.Position = UDim2.fromOffset(yAxisWidth + 2, titleHeight + 2)
	chartFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 30)
	chartFrame.BackgroundTransparency = 0
	chartFrame.BorderSizePixel = 0
	chartFrame.ClipsDescendants = true
	chartFrame.Parent = container

	-- X-axis frame
	local xAxisFrame = Instance.new("Frame")
	xAxisFrame.Name = "XAxis"
	xAxisFrame.Size = UDim2.new(1, -(yAxisWidth + 4), 0, xAxisHeight)
	xAxisFrame.Position = UDim2.new(0, yAxisWidth + 2, 1, -xAxisHeight)
	xAxisFrame.BackgroundTransparency = 1
	xAxisFrame.ClipsDescendants = true
	xAxisFrame.Parent = container

	-- Current value label
	local currentValueLabel: TextLabel? = nil
	if config.currentValue and config.currentValue.enabled then
		local cvLabel = Instance.new("TextLabel")
		cvLabel.Name = "CurrentValue"
		cvLabel.Size = UDim2.fromOffset(60, 16)
		cvLabel.Position = UDim2.new(1, -62, 0.5, 0)
		cvLabel.AnchorPoint = Vector2.new(0, 0.5)
		cvLabel.BackgroundColor3 = Color3.fromRGB(20, 25, 30)
		cvLabel.BackgroundTransparency = 0.3
		cvLabel.TextColor3 = config.currentValue.color or config.color.color or colors.warpColor
		cvLabel.FontFace = fonts.GetFont(true, true)
		cvLabel.TextSize = config.currentValue.fontSize or 12
		cvLabel.TextXAlignment = Enum.TextXAlignment.Left
		cvLabel.Text = ""
		cvLabel.ZIndex = 10
		cvLabel.Visible = false
		cvLabel.Parent = chartFrame
		currentValueLabel = cvLabel

		if config.currentValue.showConnector then
			local connector = Instance.new("Frame")
			connector.Name = "Connector"
			connector.Size = UDim2.fromOffset(4, 2)
			connector.Position = UDim2.new(0, -4, 0.5, 0)
			connector.AnchorPoint = Vector2.new(1, 0.5)
			connector.BackgroundColor3 = config.currentValue.color or config.color.color or colors.warpColor
			connector.BorderSizePixel = 0
			connector.Parent = cvLabel
		end
	end

	-- Create state
	local state: ChartState = {
		container = container,
		chartFrame = chartFrame,
		elements = {},
		yAxisFrame = yAxisFrame,
		yAxisLabels = {},
		gridLines = {},
		verticalGridLines = {},
		timeMarkers = {},
		xAxisFrame = xAxisFrame,
		currentValueLabel = currentValueLabel,
		bucketInfoLabel = bucketInfoLabel,
		eventMarkerFrames = {},
		config = config,
		chartWidth = actualWidth,
		chartHeight = actualHeight - titleHeight - xAxisHeight,
		dataPoints = {},
		eventTimestamps = {},
		typedEventMarkers = {},
		windowStartTick = 0,
		currentValue = nil,
		dataSeries = {},
		markerCategories = {},
		series = {}, -- Unified series storage (both lines and markers)
		isMultiSeriesMode = false,
		latestDataTime = 0,
		timeBuckets = {},
		currentTimeBucket = nil,
		bucketDuration = 0.01, -- Start with 10ms buckets
		resizeCleanup = nil,
		fillParentConnection = nil,
		needsUpdate = false,
		renderConnection = nil,
		isMinimized = if minimizeConfig and minimizeConfig.defaultMinimized then true else false,
		minimizeButton = minimizeButton,
		titleBar = titleBar,
		-- No position caches; no render-skip cache.
		isPaused = false,
	}

	-- Create resize handle
	state.resizeCleanup = createResizeHandle(state)

	-- Listen for parent size changes (fill-parent mode)
	state.fillParentConnection = container:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local absSize = container.AbsoluteSize
		local newWidth = absSize.X
		local newHeight = absSize.Y
		if newWidth > 10 and newHeight > 10 then
			-- Update internal dimensions
			local cfgTitleHeight = state.config.title.height or DEFAULT_TITLE_HEIGHT
			local cfgXAxisHeight = state.config.xAxis.height or DEFAULT_X_AXIS_HEIGHT
			state.chartWidth = newWidth
			state.chartHeight = newHeight - cfgTitleHeight - cfgXAxisHeight
			state.needsUpdate = true
		end
	end)

	-- Set up per-frame update (batches multiple data additions into one render)
	-- Skip rendering when minimized to save performance
	state.renderConnection = RunService.RenderStepped:Connect(function()
		if state.needsUpdate and not state.isMinimized then
			state.needsUpdate = false
			updateChart(state)
		end
	end)

	-- Create handle
	local handle: ChartHandle = {
		addDataPoint = function(time: number, value: number)
			-- Skip data processing when minimized to save performance
			if state.isMinimized then
				return
			end

			table.insert(state.dataPoints, { time = time, value = value })
			state.currentValue = value

			-- Condense if needed
			local dataConfig = state.config.data
			if #state.dataPoints > dataConfig.maxSamples then
				state.dataPoints = condenseData(state.dataPoints, dataConfig.condensationStrategy)
			end

			-- Prune old data for sliding window
			if dataConfig.retentionDuration then
				local cutoff = time - dataConfig.retentionDuration
				while #state.dataPoints > 0 and state.dataPoints[1].time < cutoff do
					table.remove(state.dataPoints, 1)
				end
			end

			state.needsUpdate = true -- Batched: actual render happens once per frame
		end,

		setEventMarkers = function(timestamps: { number })
			state.eventTimestamps = timestamps
		end,

		setTypedEventMarkers = function(markers: { TypedEventMarker })
			state.typedEventMarkers = markers
		end,

		--------------------------------------------------------------------------------
		-- Unified Series API (preferred over legacy registerSeries/registerMarkerCategory)
		--------------------------------------------------------------------------------

		-- Register a series (line or marker) with unified configuration
		register = function(seriesName: string, config: SeriesConfig)
			if state.series[seriesName] then
				return -- Already registered
			end

			local seriesState: SeriesState = {
				name = seriesName,
				seriesType = config.type,
				color = config.color,
				visible = true,
				-- Line-specific defaults
				autoScale = config.autoScale or false,
				condensationStrategy = config.strategy or "average",
				-- Marker-specific defaults
				row = config.row or 1,
				markers = {},
				elements = {},
			}
			state.series[seriesName] = seriesState
			state.isMultiSeriesMode = true

			-- Also register in legacy storage for rendering compatibility
			if config.type == "line" then
				state.dataSeries[seriesName] = {
					name = seriesName,
					color = config.color,
					visible = true,
					autoScale = seriesState.autoScale,
					condensationStrategy = seriesState.condensationStrategy,
					elements = {},
				}
			else -- marker
				state.markerCategories[seriesName] = {
					name = seriesName,
					color = config.color,
					visible = true,
					row = seriesState.row,
					markers = seriesState.markers, -- Share the markers array
					elements = {},
				}
			end
		end,

		-- Add data to any series (line or marker)
		add = function(seriesName: string, time: number, data: DataPointInput?)
			-- Skip data processing when minimized to save performance
			if state.isMinimized then
				return
			end

			local series = state.series[seriesName]
			if not series then
				return
			end

			-- Track latest data time
			if time > state.latestDataTime then
				state.latestDataTime = time
			end

			if series.seriesType == "line" then
				-- Line series: add to time buckets
				local value = if data and data.value then data.value else 0
				local bucketDuration = state.bucketDuration
				local bucketStart = math.floor(time / bucketDuration) * bucketDuration

				if not state.currentTimeBucket then
					state.currentTimeBucket = {
						startTime = bucketStart,
						seriesValues = { [seriesName] = { value } },
					}
				elseif state.currentTimeBucket.startTime == bucketStart then
					if not state.currentTimeBucket.seriesValues[seriesName] then
						state.currentTimeBucket.seriesValues[seriesName] = {}
					end
					table.insert(state.currentTimeBucket.seriesValues[seriesName], value)
				else
					local finalizedBucket = finalizeUnifiedBucket(state.currentTimeBucket, bucketDuration, state.dataSeries)
					table.insert(state.timeBuckets, finalizedBucket)
					state.currentTimeBucket = {
						startTime = bucketStart,
						seriesValues = { [seriesName] = { value } },
					}

					-- Prune for sliding window
					local windowConfig = state.config.window
					local dataConfig = state.config.data
					if windowConfig.mode == "sliding" then
						local windowDuration = windowConfig.windowDuration or 10
						local cutoffTime = time - windowDuration
						while #state.timeBuckets > 0 and state.timeBuckets[1].time < cutoffTime do
							table.remove(state.timeBuckets, 1)
						end
					end
					if #state.timeBuckets > dataConfig.maxSamples then
						rebucketUnified(state)
					end
				end
			else
				-- Marker series: add to markers array
				table.insert(series.markers, {
					time = time,
					eventType = seriesName,
					color = if data and data.color then data.color else series.color,
					label = if data then data.label else nil,
				})

				-- Prune old markers
				local dataConfig = state.config.data
				if dataConfig.retentionDuration then
					local cutoff = time - dataConfig.retentionDuration
					local i = 1
					while i <= #series.markers do
						if series.markers[i].time < cutoff then
							table.remove(series.markers, i)
						else
							i = i + 1
						end
					end
				end
			end

			state.needsUpdate = true
		end,

		-- Set visibility for any series (line or marker)
		setVisible = function(seriesName: string, visible: boolean)
			local series = state.series[seriesName]
			if not series then
				-- Fall back to legacy storage
				local legacySeries = state.dataSeries[seriesName]
				if legacySeries then
					legacySeries.visible = visible
					-- No render-skip cache; nothing to invalidate.
					if not visible then
						for _, el in ipairs(legacySeries.elements) do
							el.Visible = false
						end
					end
					state.needsUpdate = true
					return
				end
				local legacyMarker = state.markerCategories[seriesName]
				if legacyMarker then
					legacyMarker.visible = visible
					-- No render-skip cache; nothing to invalidate.
					if not visible then
						for _, el in ipairs(legacyMarker.elements) do
							el.Visible = false
						end
					end
					state.needsUpdate = true
				end
				return
			end

			series.visible = visible
			-- No render-skip cache; nothing to invalidate.

			-- Update legacy storage too
			if series.seriesType == "line" then
				local legacy = state.dataSeries[seriesName]
				if legacy then
					legacy.visible = visible
					if not visible then
						for _, el in ipairs(legacy.elements) do
							el.Visible = false
						end
					end
				end
			else
				local legacy = state.markerCategories[seriesName]
				if legacy then
					legacy.visible = visible
					if not visible then
						for _, el in ipairs(legacy.elements) do
							el.Visible = false
						end
					end
				end
			end

			state.needsUpdate = true
		end,

		--------------------------------------------------------------------------------
		-- Legacy Multi-Series API (deprecated, use unified register/add/setVisible)
		--------------------------------------------------------------------------------

		-- Multi-series mode: register a named data series with its color
		-- config.autoScale: if true, Y-axis auto-scales to fill full height based on visible data min/max
		-- config.strategy: how to combine values in a bucket ("average", "min", "max")
		registerSeries = function(seriesName: string, seriesColor: Color3, seriesConfig: { autoScale: boolean?, strategy: ("average" | "min" | "max")? }?)
			if not state.dataSeries[seriesName] then
				local autoScale = if seriesConfig and seriesConfig.autoScale then seriesConfig.autoScale else false
				local strategy: "average" | "min" | "max" = if seriesConfig and seriesConfig.strategy then seriesConfig.strategy else "average"
				state.dataSeries[seriesName] = {
					name = seriesName,
					color = seriesColor,
					visible = true,
					autoScale = autoScale,
					condensationStrategy = strategy,
					elements = {},
				}
				state.isMultiSeriesMode = true
			end
		end,

		-- Multi-series mode: add data point to a named series (unified bucket-based)
		addSeriesDataPoint = function(seriesName: string, time: number, value: number)
			-- Skip data processing when minimized to save performance
			if state.isMinimized then
				return
			end

			local series = state.dataSeries[seriesName]
			if not series then
				return
			end

			-- Track latest data time for sliding window calculations
			if time > state.latestDataTime then
				state.latestDataTime = time
			end

			local bucketDuration = state.bucketDuration

			-- Determine which bucket this time belongs to
			local bucketStart = math.floor(time / bucketDuration) * bucketDuration

			-- Check if we have a current unified bucket accumulator
			if not state.currentTimeBucket then
				-- Start new accumulator
				state.currentTimeBucket = {
					startTime = bucketStart,
					seriesValues = { [seriesName] = { value } },
				}
			elseif state.currentTimeBucket.startTime == bucketStart then
				-- Same bucket, accumulate for this series
				if not state.currentTimeBucket.seriesValues[seriesName] then
					state.currentTimeBucket.seriesValues[seriesName] = {}
				end
				table.insert(state.currentTimeBucket.seriesValues[seriesName], value)
			else
				-- New bucket - finalize current and start new
				local finalizedBucket = finalizeUnifiedBucket(state.currentTimeBucket, bucketDuration, state.dataSeries)
				table.insert(state.timeBuckets, finalizedBucket)

				-- Start new accumulator
				state.currentTimeBucket = {
					startTime = bucketStart,
					seriesValues = { [seriesName] = { value } },
				}

				-- Handle bucket limits based on window mode
				local windowConfig = state.config.window
				local dataConfig = state.config.data

				if windowConfig.mode == "sliding" then
					-- Sliding window: prune buckets outside the visible window
					local windowDuration = windowConfig.windowDuration or 10
					local cutoffTime = time - windowDuration
					while #state.timeBuckets > 0 and state.timeBuckets[1].time < cutoffTime do
						table.remove(state.timeBuckets, 1)
					end
				end

				-- Both modes: compress when too many buckets (keeps render cost bounded)
				if #state.timeBuckets > dataConfig.maxSamples then
					rebucketUnified(state)
				end
			end

			state.needsUpdate = true -- Batched: actual render happens once per frame
		end,

		-- Multi-series mode: toggle series visibility
		setSeriesVisible = function(seriesName: string, visible: boolean)
			local series = state.dataSeries[seriesName]
			if series then
				series.visible = visible
				-- No render-skip cache; nothing to invalidate.
				-- Hide elements immediately if turning off
				if not visible then
					for _, el in ipairs(series.elements) do
						el.Visible = false
					end
				end
				state.needsUpdate = true
			end
		end,

		-- Multi-series mode: register a marker category
		registerMarkerCategory = function(categoryName: string, categoryColor: Color3, categoryRow: number?)
			if not state.markerCategories[categoryName] then
				state.markerCategories[categoryName] = {
					name = categoryName,
					color = categoryColor,
					visible = true,
					row = categoryRow or 1, -- Default to row 1 (topmost)
					markers = {},
					elements = {},
				}
			end
		end,

		-- Multi-series mode: add a marker to a category
		-- Optional markerColor overrides the category default color
		addCategoryMarker = function(category: string, time: number, label: string?, markerColor: Color3?)
			-- Skip data processing when minimized to save performance
			if state.isMinimized then
				return
			end

			local cat = state.markerCategories[category]
			if not cat then
				return
			end

			table.insert(cat.markers, {
				time = time,
				eventType = category,
				color = markerColor or cat.color,
				label = label,
			})

			-- Prune old markers for sliding window
			local dataConfig = state.config.data
			if dataConfig.retentionDuration then
				local cutoff = time - dataConfig.retentionDuration
				local i = 1
				while i <= #cat.markers do
					if cat.markers[i].time < cutoff then
						table.remove(cat.markers, i)
					else
						i = i + 1
					end
				end
			end

			state.needsUpdate = true -- Batched: actual render happens once per frame
		end,

		-- Multi-series mode: toggle marker category visibility
		setMarkerCategoryVisible = function(category: string, visible: boolean)
			local cat = state.markerCategories[category]
			if cat then
				cat.visible = visible
				-- No render-skip cache; nothing to invalidate.
				-- Hide elements immediately if turning off
				if not visible then
					for _, el in ipairs(cat.elements) do
						el.Visible = false
					end
				end
				state.needsUpdate = true
			end
		end,

		clearData = function()
			-- Clear single-series data
			state.dataPoints = {}
			state.eventTimestamps = {}
			state.typedEventMarkers = {}
			state.currentValue = nil
			for _, el in ipairs(state.elements) do
				el.Visible = false
			end
			for _, marker in ipairs(state.eventMarkerFrames) do
				marker:Destroy()
			end
			state.eventMarkerFrames = {}

			-- Clear unified bucket data
			state.timeBuckets = {}
			state.currentTimeBucket = nil
			state.bucketDuration = 0.01 -- Reset to initial bucket size
			state.latestDataTime = 0

			-- No position caches; no render-skip cache.

			-- Clear series render elements (but keep series configs)
			for _, series in pairs(state.dataSeries) do
				for _, el in ipairs(series.elements) do
					el:Destroy()
				end
				series.elements = {}
			end

			-- Clear marker categories (clear in-place to preserve shared reference with state.series)
			for _, cat in pairs(state.markerCategories) do
				table.clear(cat.markers)
				for _, el in ipairs(cat.elements) do
					el:Destroy()
				end
				cat.elements = {}
			end

			-- Also clear unified series markers
			for _, series in pairs(state.series) do
				if series.seriesType == "marker" then
					table.clear(series.markers)
				end
				for _, el in ipairs(series.elements) do
					el:Destroy()
				end
				series.elements = {}
			end
		end,

		setWindowStart = function(startTick: number)
			state.windowStartTick = startTick
		end,

		setWindowDuration = function(seconds: number)
			state.config.window.windowDuration = seconds
			state.needsUpdate = true
		end,

		-- Change window mode without destroying data
		-- "sliding" shows last N seconds, "all" shows from start to now
		setWindowMode = function(mode: "sliding" | "all", duration: number?)
			state.config.window.mode = mode
			if duration then
				state.config.window.windowDuration = duration
			end
			state.needsUpdate = true
		end,

		setSize = function(width: number, height: number)
			-- Update container size
			state.container.Size = UDim2.fromOffset(width, height)

			-- Update internal dimensions
			local cfgTitleHeight = state.config.title.height or DEFAULT_TITLE_HEIGHT
			local cfgXAxisHeight = state.config.xAxis.height or DEFAULT_X_AXIS_HEIGHT
			local cfgYAxisWidth = state.config.yAxis.width or DEFAULT_Y_AXIS_WIDTH

			state.chartWidth = width
			state.chartHeight = height - cfgTitleHeight - cfgXAxisHeight

			-- Update chart frame size
			state.chartFrame.Size = UDim2.new(1, -(cfgYAxisWidth + 4), 1, -(cfgTitleHeight + cfgXAxisHeight + 4))

			-- Update x-axis frame size
			state.xAxisFrame.Size = UDim2.new(1, -(cfgYAxisWidth + 4), 0, cfgXAxisHeight)

			-- Re-render
			updateChart(state)
		end,

		update = function()
			updateChart(state)
		end,

		-- Chart-level visibility (renamed to avoid conflict with series setVisible)
		setChartVisible = function(visible: boolean)
			state.container.Visible = visible
		end,

		destroy = function()
			if state.renderConnection then
				state.renderConnection:Disconnect()
				state.renderConnection = nil
			end
			if state.fillParentConnection then
				state.fillParentConnection:Disconnect()
				state.fillParentConnection = nil
			end
			if state.resizeCleanup then
				state.resizeCleanup()
			end
			for _, marker in ipairs(state.timeMarkers) do
				marker.label:Destroy()
			end
			for _, marker in ipairs(state.eventMarkerFrames) do
				marker:Destroy()
			end
			state.container:Destroy()
		end,

		getFrame = function(): Frame?
			return state.container
		end,

		getSize = function(): (number, number)
			return state.chartWidth, state.chartHeight
		end,

		onSizeChanged = nil,

		setMinimized = function(minimized: boolean)
			if state.isMinimized == minimized then
				return
			end
			state.isMinimized = minimized

			local titleHeight = state.config.title.height or DEFAULT_TITLE_HEIGHT
			local minimizeButtonSize = titleHeight - 4

			if minimized then
				-- Hide chart content (parent container handles actual size change)
				state.chartFrame.Visible = false
				state.yAxisFrame.Visible = false
				state.xAxisFrame.Visible = false
				-- Hide title bar elements except minimize button
				if state.titleBar then
					for _, child in ipairs(state.titleBar:GetChildren()) do
						if child.Name ~= "MinimizeButton" then
							child.Visible = false
						end
					end
				end
				-- Update button text
				if state.minimizeButton then
					state.minimizeButton.Text = "+"
				end
				-- Stop render loop to save performance
				if state.renderConnection then
					state.renderConnection:Disconnect()
					state.renderConnection = nil
				end
			else
				-- Show chart content
				state.chartFrame.Visible = true
				state.yAxisFrame.Visible = true
				state.xAxisFrame.Visible = true
				-- Restore title bar elements
				if state.titleBar then
					for _, child in ipairs(state.titleBar:GetChildren()) do
						child.Visible = true
					end
				end
				-- Update button text
				if state.minimizeButton then
					state.minimizeButton.Text = "-"
				end
				-- Restart render loop
				if not state.renderConnection then
					state.renderConnection = RunService.RenderStepped:Connect(function()
						if state.needsUpdate and not state.isMinimized then
							state.needsUpdate = false
							updateChart(state)
						end
					end)
				end
				-- Trigger re-render
				state.needsUpdate = true
			end

			-- Call the onToggle callback if provided
			local minCfg = state.config.title.minimize
			if minCfg and minCfg.onToggle then
				minCfg.onToggle(minimized)
			end
		end,

		isMinimized = function(): boolean
			return state.isMinimized
		end,

		-- Pause: freeze the X-axis at the latest data time
		-- Use this when viewing historical data (e.g., after a run ends)
		pause = function()
			state.isPaused = true
			state.needsUpdate = true
		end,

		-- Resume: return to live mode (X-axis follows tick())
		-- Use this when new data will be arriving (e.g., run starts)
		resume = function()
			state.isPaused = false
			state.needsUpdate = true
		end,
	}

	-- Wire up minimize button click
	if minimizeButton then
		minimizeButton.MouseButton1Click:Connect(function()
			handle.setMinimized(not state.isMinimized)
		end)

		-- Apply initial minimized state if configured
		if minimizeConfig and minimizeConfig.defaultMinimized then
			handle.setMinimized(true)
		end
	end

	return handle
end

_annotate("end")
return module
