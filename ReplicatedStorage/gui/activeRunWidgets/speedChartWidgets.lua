--!strict
-- speedChartWidgets.lua (ReplicatedStorage/gui/activeRunWidgets/speedChartWidgets.lua)
-- Speed chart/graph widget implementations with resizable time windows.
-- All chart visualizations use the unified timeSeriesChart library.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local colors = require(game.ReplicatedStorage.util.colors)
local widgetTypes = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetTypes)
local widgetStyles = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetStyles)
local timeSeriesChart = require(game.ReplicatedStorage.gui.timeSeriesChart)

local module = {}

--------------------------------------------------------------------------------
-- Shared Constants (identical for all run chart variants)
--------------------------------------------------------------------------------

local CHART_WIDTH: number = 410
local CHART_HEIGHT: number = 180
local FILTER_PANEL_WIDTH: number = 70
-- Default widget dimensions (container = chart + filter panel on right)
local DEFAULT_WIDGET_WIDTH: number = CHART_WIDTH + FILTER_PANEL_WIDTH
local DEFAULT_WIDGET_HEIGHT: number = CHART_HEIGHT
local FILTER_BUTTON_HEIGHT: number = 22
local FILTER_BUTTON_SPACING: number = 2
local TITLE_BAR_HEIGHT: number = 22
local MAX_SAMPLES: number = 500
local MODE_TOGGLE_SIZE: number = 18

-- Chart modes
type ChartMode = "10s" | "full"

-- Mode display names (shown in title)
local MODE_TITLES: { [ChartMode]: string } = {
	["10s"] = "Run Chart - Last 10s",
	["full"] = "Run Chart - Full",
}

-- Series colors
local SERIES_COLORS = {
	runspeed = colors.defaultGrey, -- WalkSpeed setting (boring, usually flat)
	hvel = colors.lightGreen, -- Horizontal physics velocity (interesting!)
	velocity = colors.lightRed, -- Total 3D velocity
	altitude = colors.hudCyan, -- Blue for altitude (easy to see)
	distance = Color3.fromRGB(200, 100, 200), -- Purple/magenta
}

-- Default marker colors for event categories (used when event doesn't specify color)
local DEFAULT_MARKER_COLORS = {
	avatar = colors.yellow, -- Jumps, swims, state changes
	terrain = colors.warpColor, -- Terrain transitions
}

-- Compression regions: 0-65 compressed (~10%), 65-85 expanded (~90%)
-- This focuses the chart on the interesting speed range (65-85)
local COMPRESSION_REGIONS: { timeSeriesChart.CompressionRegion } = {
	{ rangeStart = 0, rangeEnd = 65, heightPercent = 0.10 },
	{ rangeStart = 65, rangeEnd = 85, heightPercent = 0.90 },
}

--------------------------------------------------------------------------------
-- Run Chart Factory
--------------------------------------------------------------------------------

export type RunChartConfig = {
	initialMode: ChartMode,
	chartId: string, -- Unique ID for the chart instance
}

local function createRunChartWidget(config: RunChartConfig): widgetTypes.Widget
	-- Widget state (fresh per instance)
	local chartHandle: timeSeriesChart.ChartHandle? = nil
	local containerFrame: Frame? = nil
	local filterPanelFrame: Frame? = nil
	local _chartContainerFrame: Frame? = nil
	local modeToggleButton: TextButton? = nil
	local resizeHandleButton: TextButton? = nil
	local resizeCleanup: (() -> ())? = nil
	local noFilterOverlay: TextLabel? = nil
	local noDataOverlay: TextLabel? = nil
	local hasEverStartedRun: boolean = false

	-- Current chart mode
	local currentMode: ChartMode = config.initialMode

	-- Minimize state
	local isWidgetMinimized: boolean = false
	local savedContainerSize: UDim2? = nil

	-- Filter visibility state (defaults, may be overridden by saved state)
	-- Unified: all drawable things (lines AND markers) are "series"
	local seriesVisible = {
		-- Line series
		runspeed = false, -- WalkSpeed (usually boring flat line)
		hvel = true, -- Horizontal velocity (default on - most interesting)
		velocity = false,
		altitude = false,
		distance = false,
		-- Marker series
		avatar = true, -- Jumps, swims, speed reasons
		terrain = true, -- Terrain changes
	}

	-- Chart state
	local isFrozen = true

	-- Run state (for rebuilding chart)
	local currentStartTick: number = 0

	-- Persistence callback
	local saveFilterState: ((state: { [string]: any }) -> ())? = nil

	local function persistFilterState()
		if saveFilterState then
			saveFilterState({
				-- All series (lines and markers)
				runspeedVisible = seriesVisible.runspeed,
				hvelVisible = seriesVisible.hvel,
				velocityVisible = seriesVisible.velocity,
				altitudeVisible = seriesVisible.altitude,
				distanceVisible = seriesVisible.distance,
				avatarVisible = seriesVisible.avatar,
				terrainVisible = seriesVisible.terrain,
				chartMode = currentMode,
			})
		end
	end

	-- Check if any data series is visible and update "no filter" overlay
	local function updateNoFilterOverlay()
		local anySeriesVisible = seriesVisible.runspeed or seriesVisible.hvel or seriesVisible.velocity or seriesVisible.altitude or seriesVisible.distance or seriesVisible.avatar or seriesVisible.terrain
		if noFilterOverlay then
			-- Hide overlay when minimized regardless of filter state
			noFilterOverlay.Visible = not anySeriesVisible and not isWidgetMinimized
		end
	end

	-- Update "no data" overlay (shown when no run has ever started)
	local function updateNoDataOverlay()
		if noDataOverlay then
			-- Hide overlay when minimized regardless of data state
			noDataOverlay.Visible = not hasEverStartedRun and not isWidgetMinimized
		end
	end

	-- Toggle minimize for the entire widget (container, chart, filters)
	-- When minimized: shrink to just a small "+" button, stop all data processing
	-- When expanded: restore size, resume data collection if run is active
	local function toggleWidgetMinimize(minimized: boolean)
		if isWidgetMinimized == minimized then
			return
		end
		isWidgetMinimized = minimized

		if minimized then
			if containerFrame then
				local currentSize = containerFrame.Size
				savedContainerSize = currentSize
				-- Shrink to just a small square button
				containerFrame.Size = UDim2.fromOffset(TITLE_BAR_HEIGHT, TITLE_BAR_HEIGHT)
			end
			if filterPanelFrame then
				filterPanelFrame.Visible = false
			end
			if resizeHandleButton then
				resizeHandleButton.Visible = false
			end
			-- Hide helpful hint overlays when minimized
			if noFilterOverlay then
				noFilterOverlay.Visible = false
			end
			if noDataOverlay then
				noDataOverlay.Visible = false
			end
			-- Chart's setMinimized handles stopping its render loop
		else
			if containerFrame and savedContainerSize then
				containerFrame.Size = savedContainerSize
			end
			if filterPanelFrame then
				filterPanelFrame.Visible = true
			end
			if resizeHandleButton then
				resizeHandleButton.Visible = true
			end
			-- Restore overlay visibility based on actual state
			updateNoFilterOverlay()
			updateNoDataOverlay()
			-- Chart's setMinimized handles restarting its render loop
		end

		if saveFilterState then
			saveFilterState({
				runspeedVisible = seriesVisible.runspeed,
				hvelVisible = seriesVisible.hvel,
				velocityVisible = seriesVisible.velocity,
				altitudeVisible = seriesVisible.altitude,
				distanceVisible = seriesVisible.distance,
				avatarVisible = seriesVisible.avatar,
				terrainVisible = seriesVisible.terrain,
				chartMode = currentMode,
				minimized = minimized,
			})
		end
	end

	-- Build chart config for current mode
	local function buildChartConfig(): timeSeriesChart.ChartConfig
		local windowConfig: timeSeriesChart.WindowConfig
		if currentMode == "10s" then
			windowConfig = {
				mode = "sliding",
				windowDuration = 10,
			}
		else
			windowConfig = {
				mode = "all",
			}
		end

		return {
			title = {
				text = MODE_TITLES[currentMode],
				backgroundColor = colors.signColor,
				textColor = colors.white,
				height = TITLE_BAR_HEIGHT,
				minimize = {
					enabled = true,
					onToggle = toggleWidgetMinimize,
				},
			},
			data = {
				maxSamples = MAX_SAMPLES,
				condensationStrategy = "average",
			},
			window = windowConfig,
			buckets = {
				mode = "dynamic",
				targetPixelWidth = 3,
				minBuckets = 80,
				aggregation = "max",
			},
			visualization = {
				mode = "point",
				pointSize = 4,
				renderDirect = true,
			},
			yAxis = {
				rangeMode = "fixed",
				fixedMin = 0,
				fixedMax = 85,
				compressionRegions = COMPRESSION_REGIONS,
				labels = {
					values = { 65, 68, 70, 75, 80, 85 },
					fontSize = 14,
					color = colors.white,
					colorOverrides = {
						[68] = colors.meColor,
					},
					boldValues = { 68 },
				},
				gridLines = {
					values = { 65, 68, 70, 75, 80, 85 },
					transparency = 0.7,
				},
				width = 32,
				unitSymbol = "",
			},
			xAxis = {
				markerMode = "fixed",
				minSpacingPixels = 50,
				height = 20,
				fontSize = 18,
				gridLines = {
					enabled = true,
					targetCount = 3, -- Aim for 2-3 vertical lines
					color = colors.defaultGrey,
					transparency = 0.8,
				},
			},
			color = {
				mode = "single",
				color = colors.lightGreen,
			},
			currentValue = {
				enabled = false,
			},
			background = {
				color = colors.black,
				transparency = 0.05,
			},
		}
	end

	-- Setup chart with series (unified API - both lines and markers are "series")
	local function setupChartSeries(handle: timeSeriesChart.ChartHandle)
		-- Line series (Y position from value mapping)
		handle.register("runspeed", { type = "line", color = SERIES_COLORS.runspeed, strategy = "max" })
		handle.register("hvel", { type = "line", color = SERIES_COLORS.hvel, strategy = "max" })
		handle.register("velocity", { type = "line", color = SERIES_COLORS.velocity, strategy = "max" })
		handle.register("altitude", { type = "line", color = SERIES_COLORS.altitude, autoScale = true, strategy = "max" })
		handle.register("distance", { type = "line", color = SERIES_COLORS.distance, autoScale = true, strategy = "max" })

		-- Marker series (Y position from fixed row band)
		handle.register("avatar", { type = "marker", color = DEFAULT_MARKER_COLORS.avatar, row = 1 })
		handle.register("terrain", { type = "marker", color = DEFAULT_MARKER_COLORS.terrain, row = 2 })

		-- Apply visibility state (unified API)
		for seriesName, visible in pairs(seriesVisible) do
			handle.setVisible(seriesName, visible)
		end

		-- Set window start if we have an active run
		if currentStartTick > 0 then
			handle.setWindowStart(currentStartTick)
		end
	end

	-- Add mode toggle button to title bar
	local function addModeToggle(titleBar: Frame, onToggle: () -> ())
		local btn = Instance.new("TextButton")
		btn.Name = "ModeToggle"
		btn.Size = UDim2.fromOffset(MODE_TOGGLE_SIZE, MODE_TOGGLE_SIZE)
		btn.Position = UDim2.new(0, 4, 0.5, 0)
		btn.AnchorPoint = Vector2.new(0, 0.5)
		btn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
		btn.BackgroundTransparency = 0.3
		btn.BorderSizePixel = 1
		btn.BorderColor3 = colors.defaultGrey
		btn.Text = "⇄"
		btn.TextColor3 = colors.white
		btn.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold)
		btn.TextSize = 14
		btn.AutoButtonColor = false
		btn.ZIndex = 5
		btn.Parent = titleBar

		-- Hover effect
		btn.MouseEnter:Connect(function()
			btn.BackgroundTransparency = 0
			btn.BackgroundColor3 = colors.meColor
			btn.TextColor3 = colors.black
		end)

		btn.MouseLeave:Connect(function()
			btn.BackgroundTransparency = 0.3
			btn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
			btn.TextColor3 = colors.white
		end)

		btn.MouseButton1Click:Connect(onToggle)

		return btn
	end

	-- Rebuild chart with new mode (preserves filter state)
	-- Chart uses fill-parent mode: it automatically sizes to fill chartContainer
	local function rebuildChart(chartContainer: Frame)
		-- Destroy old chart
		if chartHandle then
			chartHandle.destroy()
			chartHandle = nil
		end

		-- Remove old mode toggle if it exists
		if modeToggleButton then
			modeToggleButton:Destroy()
			modeToggleButton = nil
		end

		-- Create new chart with current mode (nil dimensions = fill parent)
		local chartConfig = buildChartConfig()
		chartHandle = timeSeriesChart.create(chartContainer, config.chartId .. "_" .. currentMode, nil, nil, nil, chartConfig)

		local handle = chartHandle
		if not handle then
			return false
		end

		-- Setup series with current visibility state
		setupChartSeries(handle)

		-- Find the title bar and add mode toggle
		local chartFrame = handle.getFrame()
		if chartFrame then
			local titleBar = chartFrame:FindFirstChild("TitleBar")
			if titleBar and titleBar:IsA("Frame") then
				modeToggleButton = addModeToggle(titleBar, function()
					-- Toggle mode
					-- Note: This rebuilds the chart because 10s mode actively prunes
					-- data older than 10s, so switching modes changes data collection
					currentMode = if currentMode == "10s" then "full" else "10s"
					_annotate(string.format("Mode toggled to: %s", currentMode))

					-- Rebuild chart with new mode config
					rebuildChart(chartContainer)

					-- Persist the mode change
					persistFilterState()
				end)
			end
		end

		return true
	end

	-- Create a vertical filter button (for the right-side filter panel)
	-- Determine if a color is light (needs dark text) or dark (needs light text)
	local function isLightColor(c: Color3): boolean
		-- Perceived luminance formula (ITU-R BT.601)
		local luminance = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
		return luminance > 0.6
	end

	-- Creates a filter button and returns the button plus a setState function for external control
	local function createFilterButton(
		parent: Frame,
		label: string,
		color: Color3,
		initialState: boolean,
		onToggle: (boolean) -> ()
	): (TextButton, (boolean) -> ())
		local textColorOn = if isLightColor(color) then colors.black else colors.white

		local btn = Instance.new("TextButton")
		btn.Name = "Filter_" .. label
		-- Use Scale for height so buttons compress when container shrinks
		btn.Size = UDim2.new(1, -4, 0, FILTER_BUTTON_HEIGHT)
		btn.BackgroundColor3 = if initialState then color else Color3.fromRGB(30, 30, 35)
		btn.BackgroundTransparency = if initialState then 0 else 0.5
		btn.BorderSizePixel = 1
		btn.BorderColor3 = color
		btn.Text = label
		btn.TextColor3 = if initialState then textColorOn else color
		btn.TextSize = 11
		btn.TextScaled = true
		btn.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold)
		btn.AutoButtonColor = false
		btn.Parent = parent

		-- Add text size constraint to prevent text from getting too large
		local textConstraint = Instance.new("UITextSizeConstraint")
		textConstraint.MaxTextSize = 14
		textConstraint.MinTextSize = 6
		textConstraint.Parent = btn

		local isOn = initialState

		-- Function to update button appearance (for All/None buttons)
		local function setState(newState: boolean)
			isOn = newState
			btn.BackgroundColor3 = if isOn then color else Color3.fromRGB(30, 30, 35)
			btn.BackgroundTransparency = if isOn then 0 else 0.5
			btn.TextColor3 = if isOn then textColorOn else color
		end

		btn.MouseButton1Click:Connect(function()
			isOn = not isOn
			setState(isOn)
			onToggle(isOn)
		end)

		return btn, setState
	end

	local widget: widgetTypes.Widget = {
		Create = function(parent: Frame, position: UDim2?, context: widgetTypes.WidgetCreateContext?): Frame?
			-- Widget dimensions (container = chart + checkbox bar)
			-- savedSize stores the total container dimensions directly - no arithmetic needed
			local width = DEFAULT_WIDGET_WIDTH
			local height = DEFAULT_WIDGET_HEIGHT
			if context and context.savedSize then
				width = context.savedSize.width
				height = context.savedSize.height
			end

			local savedMinimized: boolean? = nil

			if context and context.savedState then
				local saved = context.savedState
				if saved.runspeedVisible ~= nil then
					seriesVisible.runspeed = saved.runspeedVisible
				end
				if saved.hvelVisible ~= nil then
					seriesVisible.hvel = saved.hvelVisible
				end
				if saved.velocityVisible ~= nil then
					seriesVisible.velocity = saved.velocityVisible
				end
				if saved.altitudeVisible ~= nil then
					seriesVisible.altitude = saved.altitudeVisible
				end
				if saved.distanceVisible ~= nil then
					seriesVisible.distance = saved.distanceVisible
				end
				if saved.avatarVisible ~= nil then
					seriesVisible.avatar = saved.avatarVisible
				end
				if saved.terrainVisible ~= nil then
					seriesVisible.terrain = saved.terrainVisible
				end
				if saved.minimized ~= nil then
					savedMinimized = saved.minimized
				end
				-- Restore saved mode (overrides initial mode from config)
				if saved.chartMode ~= nil then
					currentMode = saved.chartMode
				end
			end

			if context and context.onSaveState then
				saveFilterState = context.onSaveState
			end

			-- Create container for chart + filter panel (filter panel on right)
			local container = Instance.new("Frame")
			container.Name = config.chartId .. "Container"
			container.Size = UDim2.fromOffset(width, height)
			container.BackgroundTransparency = 1
			container.BorderSizePixel = 0
			if position then
				container.Position = position
			end
			container.Parent = parent
			containerFrame = container

			-- Create filter panel on the right side (vertical column of buttons)
			local filterPanel = Instance.new("Frame")
			filterPanel.Name = "FilterPanel"
			filterPanel.Size = UDim2.new(0, FILTER_PANEL_WIDTH, 1, 0)
			filterPanel.Position = UDim2.new(1, -FILTER_PANEL_WIDTH, 0, 0)
			filterPanel.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
			filterPanel.BackgroundTransparency = 0.2
			filterPanel.BorderSizePixel = 0
			filterPanel.ClipsDescendants = true -- Prevent overflow when shrunk
			filterPanel.Parent = container
			filterPanelFrame = filterPanel

			-- Add UIListLayout for vertical stacking with scale-based spacing
			local filterLayout = Instance.new("UIListLayout")
			filterLayout.FillDirection = Enum.FillDirection.Vertical
			filterLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			filterLayout.VerticalAlignment = Enum.VerticalAlignment.Top
			filterLayout.Padding = UDim.new(0.01, 0) -- Scale-based padding
			filterLayout.Parent = filterPanel

			-- Add padding at top/bottom using Scale
			local filterPadding = Instance.new("UIPadding")
			filterPadding.PaddingTop = UDim.new(0.02, 0)
			filterPadding.PaddingBottom = UDim.new(0.02, 0)
			filterPadding.PaddingLeft = UDim.new(0, 2)
			filterPadding.PaddingRight = UDim.new(0, 2)
			filterPadding.Parent = filterPanel

			-- Create chart in the remaining space (left side, full height)
			local chartContainer = Instance.new("Frame")
			chartContainer.Name = "ChartContainer"
			chartContainer.Size = UDim2.new(1, -FILTER_PANEL_WIDTH, 1, 0)
			chartContainer.Position = UDim2.fromOffset(0, 0)
			chartContainer.BackgroundTransparency = 1
			chartContainer.BorderSizePixel = 0
			chartContainer.Parent = container
			_chartContainerFrame = chartContainer

			-- Create "no filter enabled" overlay
			local overlay = Instance.new("TextLabel")
			overlay.Name = "NoFilterOverlay"
			overlay.Size = UDim2.new(1, 0, 1, -TITLE_BAR_HEIGHT)
			overlay.Position = UDim2.fromOffset(0, TITLE_BAR_HEIGHT)
			overlay.BackgroundTransparency = 1
			overlay.Text = "Enable a filter to see run data"
			overlay.TextColor3 = colors.defaultGrey
			overlay.TextSize = 22
			overlay.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular)
			overlay.TextXAlignment = Enum.TextXAlignment.Center
			overlay.TextYAlignment = Enum.TextYAlignment.Center
			overlay.ZIndex = 10
			overlay.Visible = false
			overlay.Parent = chartContainer
			noFilterOverlay = overlay

			-- Create "no data yet" overlay (shown when no run has ever started)
			local noDataLabel = Instance.new("TextLabel")
			noDataLabel.Name = "NoDataOverlay"
			noDataLabel.Size = UDim2.new(1, 0, 1, -TITLE_BAR_HEIGHT)
			noDataLabel.Position = UDim2.fromOffset(0, TITLE_BAR_HEIGHT)
			noDataLabel.BackgroundTransparency = 1
			noDataLabel.Text = "This chart will show data about a run once you start one."
			noDataLabel.TextColor3 = colors.defaultGrey
			noDataLabel.TextSize = 22
			noDataLabel.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular)
			noDataLabel.TextXAlignment = Enum.TextXAlignment.Center
			noDataLabel.TextYAlignment = Enum.TextYAlignment.Center
			noDataLabel.ZIndex = 11
			noDataLabel.Visible = not hasEverStartedRun
			noDataLabel.Parent = chartContainer
			noDataOverlay = noDataLabel

			-- Build and create chart (uses fill-parent mode - auto-sizes to chartContainer)
			if not rebuildChart(chartContainer) then
				container:Destroy()
				return nil
			end

			local handle = chartHandle
			if not handle then
				container:Destroy()
				return nil
			end

			-- Create filter buttons (all use unified setVisible API)
			-- Store setState functions for All/None buttons
			local filterSetters: { [string]: (boolean) -> () } = {}

			-- Helper to create a filter button with standard behavior
			local function addSeriesFilter(name: string, displayName: string, color: Color3)
				local _, setState = createFilterButton(filterPanel, displayName, color, seriesVisible[name], function(on)
					seriesVisible[name] = on
					if chartHandle then
						chartHandle.setVisible(name, on)
					end
					persistFilterState()
					updateNoFilterOverlay()
				end)
				filterSetters[name] = setState
			end

			-- Line series
			addSeriesFilter("hvel", "Horiz", SERIES_COLORS.hvel)
			addSeriesFilter("velocity", "Velocity", SERIES_COLORS.velocity)
			addSeriesFilter("altitude", "Altitude", SERIES_COLORS.altitude)
			addSeriesFilter("distance", "Distance", SERIES_COLORS.distance)
			addSeriesFilter("runspeed", "Speed", SERIES_COLORS.runspeed)

			-- Marker series
			addSeriesFilter("avatar", "Avatar", DEFAULT_MARKER_COLORS.avatar)
			addSeriesFilter("terrain", "Terrain", DEFAULT_MARKER_COLORS.terrain)

			-- Create All/None button row (horizontal container)
			local allNoneRow = Instance.new("Frame")
			allNoneRow.Name = "AllNoneRow"
			allNoneRow.Size = UDim2.new(1, -4, 0, FILTER_BUTTON_HEIGHT)
			allNoneRow.BackgroundTransparency = 1
			allNoneRow.BorderSizePixel = 0
			allNoneRow.Parent = filterPanel

			local rowLayout = Instance.new("UIListLayout")
			rowLayout.FillDirection = Enum.FillDirection.Horizontal
			rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			rowLayout.Padding = UDim.new(0, 2)
			rowLayout.Parent = allNoneRow

			-- "All" button
			local allBtn = Instance.new("TextButton")
			allBtn.Name = "AllButton"
			allBtn.Size = UDim2.new(0.48, 0, 1, 0)
			allBtn.BackgroundColor3 = Color3.fromRGB(50, 80, 50)
			allBtn.BackgroundTransparency = 0.3
			allBtn.BorderSizePixel = 1
			allBtn.BorderColor3 = colors.lightGreen
			allBtn.Text = "All"
			allBtn.TextColor3 = colors.white
			allBtn.TextScaled = true
			allBtn.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold)
			allBtn.AutoButtonColor = false
			allBtn.Parent = allNoneRow

			local allTextConstraint = Instance.new("UITextSizeConstraint")
			allTextConstraint.MaxTextSize = 12
			allTextConstraint.MinTextSize = 6
			allTextConstraint.Parent = allBtn

			allBtn.MouseButton1Click:Connect(function()
				for name, setter in pairs(filterSetters) do
					seriesVisible[name] = true
					setter(true)
					if chartHandle then
						chartHandle.setVisible(name, true)
					end
				end
				persistFilterState()
				updateNoFilterOverlay()
			end)

			-- "None" button
			local noneBtn = Instance.new("TextButton")
			noneBtn.Name = "NoneButton"
			noneBtn.Size = UDim2.new(0.48, 0, 1, 0)
			noneBtn.BackgroundColor3 = Color3.fromRGB(80, 50, 50)
			noneBtn.BackgroundTransparency = 0.3
			noneBtn.BorderSizePixel = 1
			noneBtn.BorderColor3 = colors.lightRed
			noneBtn.Text = "None"
			noneBtn.TextColor3 = colors.white
			noneBtn.TextScaled = true
			noneBtn.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold)
			noneBtn.AutoButtonColor = false
			noneBtn.Parent = allNoneRow

			local noneTextConstraint = Instance.new("UITextSizeConstraint")
			noneTextConstraint.MaxTextSize = 12
			noneTextConstraint.MinTextSize = 6
			noneTextConstraint.Parent = noneBtn

			noneBtn.MouseButton1Click:Connect(function()
				for name, setter in pairs(filterSetters) do
					seriesVisible[name] = false
					setter(false)
					if chartHandle then
						chartHandle.setVisible(name, false)
					end
				end
				persistFilterState()
				updateNoFilterOverlay()
			end)

			-- Set initial overlay state based on current filter visibility
			updateNoFilterOverlay()

			-- Add resize handle BEFORE applying minimize state
			-- (createResizeHandle sets parent.Size, which would undo minimize shrink if done after)
			-- Chart uses fill-parent mode, so resizing the container automatically resizes the chart
			-- We save the container dimensions directly - no arithmetic needed
			local resizeBtn, cleanup = widgetStyles.createResizeHandle({
				parent = container,
				minWidth = 200 + FILTER_PANEL_WIDTH, -- Chart min + filter panel
				maxWidth = 9999,
				minHeight = 120, -- Minimum chart height
				maxHeight = 1000,
				initialWidth = width,
				initialHeight = height,
				-- No onSizeChanged needed - chart auto-resizes via fill-parent mode
				onResizeEnd = if context and context.onSaveSize
					then function(w: number, h: number)
						-- Save container dimensions directly
						context.onSaveSize(w, h)
					end
					else nil,
			})
			resizeHandleButton = resizeBtn
			resizeCleanup = cleanup

			-- Apply saved minimized state AFTER resize handle is created
			-- (createResizeHandle sets parent.Size, which would undo minimize shrink if done before)
			if savedMinimized then
				toggleWidgetMinimize(true)
			end

			return container
		end,

		Destroy = function()
			if resizeCleanup then
				resizeCleanup()
				resizeCleanup = nil
			end
			resizeHandleButton = nil
			modeToggleButton = nil
			local handle = chartHandle
			if handle then
				handle.destroy()
				chartHandle = nil
			end
			if containerFrame then
				containerFrame:Destroy()
				containerFrame = nil
			end
		end,

		SetVisible = function(vis: boolean)
			if containerFrame then
				containerFrame.Visible = vis
			end
		end,

		IsVisible = function(): boolean
			if containerFrame then
				return containerFrame.Visible
			end
			return false
		end,

		GetFrame = function(): Frame?
			return containerFrame
		end,

		OnRunStart = function(startTick: number, _signName: string, _signPosition: Vector3)
			isFrozen = false
			currentStartTick = startTick
			hasEverStartedRun = true
			updateNoDataOverlay()

			local handle = chartHandle
			if handle then
				handle.resume() -- Unfreeze the X-axis for live data
				handle.clearData()
				handle.setWindowStart(startTick)
			end
		end,

		OnRunEnd = function()
			isFrozen = true
			local handle = chartHandle
			if handle then
				handle.pause() -- Freeze the X-axis at latest data point
			end
		end,

		-- Data updates use unified API: handle.add(series, time, data)
		UpdateSpeed = function(speed: number)
			if isFrozen then
				return
			end
			local handle = chartHandle
			if handle then
				handle.add("runspeed", tick(), { value = speed })
			end
		end,

		UpdateVelocity = function(horizontal: number, _vertical: number, total: number)
			if isFrozen then
				return
			end
			local now = tick()
			local handle = chartHandle
			if handle then
				handle.add("hvel", now, { value = horizontal })
				handle.add("velocity", now, { value = total })
			end
		end,

		UpdateAcceleration = function(_rate: number) end,

		UpdateAltitude = function(altitude: number, _verticalVelocity: number)
			if isFrozen then
				return
			end
			local handle = chartHandle
			if handle then
				local normalizedAlt = math.clamp(altitude / 2, 0, 100)
				handle.add("altitude", tick(), { value = normalizedAlt })
			end
		end,

		UpdateDistance = function(fromStart: number, _total: number)
			if isFrozen then
				return
			end
			local handle = chartHandle
			if handle then
				handle.add("distance", tick(), { value = fromStart })
			end
		end,

		-- No-op implementations: chart uses OnMarkerEvent instead of deriving from these
		UpdateJumpCount = function(_count: number) end,
		UpdateSpinCount = function(_clockwise: number, _counterClockwise: number) end,
		UpdateTerrain = function(_terrainName: string) end,

		UpdateDescription = function(_description: string) end,
		UpdateFacing = function(_degrees: number) end,

		-- Marker events use unified API: handle.add(series, time, data)
		OnMarkerEvent = function(category: string, timestamp: number, label: string, color: Color3)
			if isFrozen then
				return
			end
			local handle = chartHandle
			if handle then
				handle.add(category, timestamp, { label = label, color = color })
			end
		end,
	}

	return widgetTypes.asWidget(widget)
end

--------------------------------------------------------------------------------
-- Widget Constructors (thin wrappers around factory)
--------------------------------------------------------------------------------

local function createRunChart10s(): widgetTypes.Widget
	return createRunChartWidget({
		initialMode = "10s",
		chartId = "SpeedChartWidget_runChart",
	})
end

local function createRunChartFull(): widgetTypes.Widget
	return createRunChartWidget({
		initialMode = "full",
		chartId = "SpeedChartWidget_runChart",
	})
end

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

function module.Register(composer: { RegisterWidget: (string, string, () -> any) -> () })
	local category = widgetTypes.CATEGORIES.SPEED_CHART
	composer.RegisterWidget(category, widgetTypes.SPEED_CHART_STYLES.RUN_CHART_10S, createRunChart10s)
	composer.RegisterWidget(category, widgetTypes.SPEED_CHART_STYLES.RUN_CHART_FULL, createRunChartFull)
	_annotate("Registered run chart widgets")
end

_annotate("end")
return module
