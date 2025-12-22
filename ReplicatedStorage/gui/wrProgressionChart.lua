--!strict

-- wrProgressionChart.lua
-- Visualizes WR progression as a step chart showing how the world record
-- improved over time, with version markers and attempt density.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local Players = game:GetService("Players")
local _UserInputService = game:GetService("UserInputService")

local gametypes = require(game.ReplicatedStorage.types.gametypes)
local colors = require(game.ReplicatedStorage.util.colors)
local fonts = require(game.StarterPlayer.StarterPlayerScripts.guis.fonts)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local versionHistory = require(game.ReplicatedStorage.data.versionHistory)
local thumbnails = require(game.ReplicatedStorage.thumbnails)
local windowFunctions = require(game.StarterPlayer.StarterPlayerScripts.guis.windowFunctions)
local settings = require(game.ReplicatedStorage.settings)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)

local localPlayer = Players.LocalPlayer

--------------------------------------------------------------------------------
-- Types
--------------------------------------------------------------------------------

export type WRPoint = {
	time: number, -- Unix timestamp when WR was set
	milliseconds: number, -- WR time in ms
	username: string,
	userId: number,
	improvement: number?, -- Improvement over previous in ms
	attemptsBetween: number?, -- Total attempts to beat this
	attemptsByWinner: number?, -- Winner's attempts in the window
	recordStood: number?, -- Seconds this record stood before being broken
	isFirstRun: boolean,
}

export type ChartConfig = {
	title: string,
	width: number?,
	height: number?,
	showAttempts: boolean,
	showVersionMarkers: boolean,
	showTitle: boolean?,
}

export type ScaledChartConfig = {
	title: string,
	showAttempts: boolean,
	showVersionMarkers: boolean,
	showTitle: boolean?,
	userBestMs: number?, -- User's personal best time (ms); shown on Y-axis if not current WR holder
	userBestUserId: number?, -- User's ID for portrait display
	userBestUsername: string?, -- User's name for label display
}

export type ChartHandle = {
	destroy: () -> (),
	getFrame: () -> Frame,
}

local module = {}

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local TITLE_HEIGHT = 30
local X_AXIS_HEIGHT = 60 -- Taller for larger date labels
local Y_AXIS_WIDTH = 70 -- Wider for time labels with "s" suffix
local POINT_SIZE = 60 -- Triple size for clear avatar visibility
local LINE_THICKNESS = 2
local PADDING = 10 -- Used in fixed-size Create() only

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

-- Use centralized time formatting from tpUtil
local formatTime = tpUtil.fmtms
local formatTimeWithUnit = tpUtil.fmtAdaptiveWithUnit

-- Round milliseconds to nice display values for axis labels
local function roundToNiceMs(ms: number): number
	local seconds = ms / 1000
	if seconds >= 60 then
		-- Round to nearest 10 seconds
		return math.floor(seconds / 10 + 0.5) * 10 * 1000
	elseif seconds >= 10 then
		-- Round to nearest second
		return math.floor(seconds + 0.5) * 1000
	elseif seconds >= 1 then
		-- Round to nearest 0.5 seconds
		return math.floor(seconds * 2 + 0.5) / 2 * 1000
	else
		-- Round to nearest 0.1 seconds
		return math.floor(seconds * 10 + 0.5) / 10 * 1000
	end
end

-- Get midnight timestamp for start of a month
local function getMidnightOfMonth(timestamp: number): number
	local date = os.date("*t", timestamp) :: { year: number, month: number, day: number }
	return os.time({ year = date.year, month = date.month, day = 1, hour = 0, min = 0, sec = 0 })
end

-- Make avatar frame circular by adding UICorner
local function makeCircular(frame: Frame)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	-- Also apply to child ImageLabel if present
	local img = frame:FindFirstChildOfClass("ImageLabel")
	if img then
		local imgCorner = Instance.new("UICorner")
		imgCorner.CornerRadius = UDim.new(0.5, 0)
		imgCorner.Parent = img
	end
end

local function formatDate(timestamp: number): string
	return os.date("%b %Y", timestamp) :: string
end

local function formatDateFull(timestamp: number): string
	return os.date("%Y-%m-%d", timestamp) :: string
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

--------------------------------------------------------------------------------
-- Chart Creation (Fixed Size - Legacy)
--------------------------------------------------------------------------------

function module.Create(parent: Instance, wrData: { gametypes.wrProgressionEntry }, raceTitle: string, config: ChartConfig?): ChartHandle
	local cfg: ChartConfig = config or {
		title = raceTitle,
		width = 700,
		height = 400,
		showAttempts = true,
		showVersionMarkers = true,
	}

	-- Ensure fixed-size chart always has concrete pixel dimensions even if caller omits them.
	local widthPx = cfg.width or 700
	local heightPx = cfg.height or 400

	-- Convert WR entries to chart points (reverse to chronological order)
	local points: { WRPoint } = {}
	local totalEntries = #wrData
	for i = totalEntries, 1, -1 do
		local entry = wrData[i]
		table.insert(points, {
			time = entry.runTime,
			milliseconds = entry.runMilliseconds,
			username = entry.username,
			userId = entry.userId,
			improvement = entry.improvementMs,
			attemptsBetween = entry.attemptsBetween,
			attemptsByWinner = entry.attemptsByWinner,
			recordStood = entry.recordStood,
			isFirstRun = (i == totalEntries),
		})
	end

	if #points == 0 then
		-- No data, return empty frame
		local emptyFrame = Instance.new("Frame")
		emptyFrame.Size = UDim2.fromOffset(widthPx, heightPx)
		emptyFrame.BackgroundColor3 = colors.defaultGrey
		emptyFrame.Parent = parent
		return {
			destroy = function()
				emptyFrame:Destroy()
			end,
			getFrame = function()
				return emptyFrame
			end,
		}
	end

	-- Calculate data bounds
	-- X-axis: from first race run to today
	local minTime = points[1].time
	local maxTime = os.time() -- Extend to today, not just last WR
	local timeRange = math.max(maxTime - minTime, 1)

	-- Extend time range slightly for left padding only (right is already at today)
	minTime = minTime - timeRange * 0.02
	timeRange = maxTime - minTime

	-- Y-axis: from fastest (minMs) to slowest (maxMs)
	local minMs = math.huge
	local maxMs = -math.huge
	for _, p in ipairs(points) do
		minMs = math.min(minMs, p.milliseconds)
		maxMs = math.max(maxMs, p.milliseconds)
	end
	local msRange = math.max(maxMs - minMs, 1)

	-- Add padding to Y range, but NEVER go below 0 (impossible race time)
	local msPadding = msRange * 0.1
	minMs = math.max(0, minMs - msPadding) -- Clamp to 0 - can't run faster than 0 seconds
	maxMs = maxMs + msPadding
	msRange = maxMs - minMs

	-- Create main container
	local container = Instance.new("Frame")
	container.Name = "WRProgressionChart"
	container.Size = UDim2.fromOffset(widthPx, heightPx)
	container.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	container.BorderSizePixel = 2
	container.BorderColor3 = colors.black
	container.Parent = parent

	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(0, 8)
	containerCorner.Parent = container

	-- Title (optional - hidden when embedded in a modal)
	local showTitle = if cfg.showTitle == nil then true else cfg.showTitle
	local effectiveTitleHeight = if showTitle then TITLE_HEIGHT else 0

	if showTitle then
		local titleLabel = Instance.new("TextLabel")
		titleLabel.Name = "Title"
		titleLabel.Size = UDim2.new(1, 0, 0, TITLE_HEIGHT)
		titleLabel.Position = UDim2.new(0, 0, 0, 0)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Text = "WR Progression: " .. cfg.title
		titleLabel.TextColor3 = colors.white
		titleLabel.FontFace = fonts.GetFont(false, true)
		titleLabel.TextSize = 18
		titleLabel.Parent = container
	end

	-- Chart area dimensions (adjust for title presence)
	local chartX = Y_AXIS_WIDTH
	local chartY = effectiveTitleHeight + 10
	local chartWidth = widthPx - Y_AXIS_WIDTH - PADDING
	local chartHeight = heightPx - effectiveTitleHeight - X_AXIS_HEIGHT - 20

	-- Chart background
	local chartBg = Instance.new("Frame")
	chartBg.Name = "ChartBackground"
	chartBg.Size = UDim2.fromOffset(chartWidth, chartHeight)
	chartBg.Position = UDim2.fromOffset(chartX, chartY)
	chartBg.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
	chartBg.BorderSizePixel = 1
	chartBg.BorderColor3 = Color3.fromRGB(60, 60, 70)
	chartBg.Parent = container

	-- Y-axis labels (time values - inverted so faster is higher)
	local yAxisFrame = Instance.new("Frame")
	yAxisFrame.Name = "YAxis"
	yAxisFrame.Size = UDim2.fromOffset(Y_AXIS_WIDTH, chartHeight)
	yAxisFrame.Position = UDim2.fromOffset(0, chartY)
	yAxisFrame.BackgroundTransparency = 1
	yAxisFrame.Parent = container

	local numYLabels = 5
	for i = 0, numYLabels do
		local t = i / numYLabels
		-- Inverted: top = fastest (minMs), bottom = slowest (maxMs)
		local msValue = lerp(minMs, maxMs, t)
		local yPos = t * chartHeight

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -5, 0, 16)
		label.Position = UDim2.fromOffset(0, yPos - 8)
		label.BackgroundTransparency = 1
		label.Text = formatTime(math.floor(msValue))
		label.TextColor3 = Color3.fromRGB(150, 150, 160)
		label.FontFace = fonts.GetFont(true, false)
		label.TextSize = 11
		label.TextXAlignment = Enum.TextXAlignment.Right
		label.Parent = yAxisFrame

		-- Grid line
		local gridLine = Instance.new("Frame")
		gridLine.Size = UDim2.new(1, 0, 0, 1)
		gridLine.Position = UDim2.fromOffset(0, yPos)
		gridLine.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
		gridLine.BorderSizePixel = 0
		gridLine.Parent = chartBg
	end

	-- X-axis labels (dates)
	local xAxisFrame = Instance.new("Frame")
	xAxisFrame.Name = "XAxis"
	xAxisFrame.Size = UDim2.fromOffset(chartWidth, X_AXIS_HEIGHT)
	xAxisFrame.Position = UDim2.fromOffset(chartX, chartY + chartHeight)
	xAxisFrame.BackgroundTransparency = 1
	xAxisFrame.Parent = container

	local numXLabels = math.min(6, #points)
	for i = 0, numXLabels do
		local t = i / numXLabels
		local timeValue = lerp(minTime, maxTime, t)
		local xPos = t * chartWidth

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromOffset(80, 16)
		label.Position = UDim2.fromOffset(xPos - 40, 5)
		label.BackgroundTransparency = 1
		label.Text = formatDate(math.floor(timeValue))
		label.TextColor3 = Color3.fromRGB(150, 150, 160)
		label.FontFace = fonts.GetFont(false, false)
		label.TextSize = 10
		label.Parent = xAxisFrame
	end

	-- Version markers - small clear white text at bottom
	if cfg.showVersionMarkers then
		local versions = versionHistory.GetVersionsInRange(minTime, maxTime)
		for _, ver in ipairs(versions) do
			local t = (ver.timestamp - minTime) / timeRange
			if t >= 0 and t <= 1 then
				local xPos = t * chartWidth

				-- Subtle tick mark at bottom
				local versionLine = Instance.new("Frame")
				versionLine.Size = UDim2.fromOffset(1, math.floor(chartHeight * 0.08))
				versionLine.Position = UDim2.fromOffset(xPos, math.floor(chartHeight * 0.92))
				versionLine.BackgroundColor3 = colors.white
				versionLine.BackgroundTransparency = 0.6
				versionLine.BorderSizePixel = 0
				versionLine.ZIndex = 1
				versionLine.Parent = chartBg

				-- Version label - small, clear, white
				local versionLabel = Instance.new("TextLabel")
				versionLabel.Size = UDim2.fromOffset(48, 14)
				versionLabel.AnchorPoint = Vector2.new(0.5, 1)
				versionLabel.Position = UDim2.fromOffset(xPos, chartHeight - 2)
				versionLabel.BackgroundTransparency = 1
				versionLabel.Text = ver.version
				versionLabel.TextColor3 = colors.white
				versionLabel.FontFace = fonts.GetFont(false, false)
				versionLabel.TextSize = 11
				versionLabel.TextTransparency = 0.2
				versionLabel.ZIndex = 1
				versionLabel.Parent = chartBg
			end
		end
	end

	-- Draw step lines and points
	local prevX: number? = nil
	local prevY: number? = nil

	for i, point in ipairs(points) do
		local t = (point.time - minTime) / timeRange
		-- Inverted Y: faster times (lower ms) should be at the top
		local yT = (point.milliseconds - minMs) / msRange
		local xPos = t * chartWidth
		local yPos = yT * chartHeight

		-- Horizontal step line from previous point
		if prevX and prevY then
			local hLine = Instance.new("Frame")
			hLine.Size = UDim2.fromOffset(xPos - prevX, LINE_THICKNESS)
			hLine.Position = UDim2.fromOffset(prevX, prevY - LINE_THICKNESS / 2)
			hLine.BackgroundColor3 = colors.warpColor
			hLine.BorderSizePixel = 0
			hLine.ZIndex = 2
			hLine.Parent = chartBg

			-- Vertical drop line
			local vLine = Instance.new("Frame")
			vLine.Size = UDim2.fromOffset(LINE_THICKNESS, math.abs(yPos - prevY))
			vLine.Position = UDim2.fromOffset(xPos - LINE_THICKNESS / 2, math.min(yPos, prevY))
			vLine.BackgroundColor3 = colors.warpColor
			vLine.BorderSizePixel = 0
			vLine.ZIndex = 2
			vLine.Parent = chartBg
		end

		-- Point marker - use avatar portrait for "Other WRs", colored dot for user/first run
		local pointColor = colors.defaultGrey
		local isUserPoint = point.userId == localPlayer.UserId
		local useAvatar = not isUserPoint and not point.isFirstRun

		if isUserPoint then
			pointColor = colors.meColor
		elseif point.isFirstRun then
			pointColor = colors.greenGo
		end

		local pointFrame: Frame
		local avatarSize = POINT_SIZE + 6 -- Slightly larger for avatar visibility

		if useAvatar then
			-- Create avatar portrait for "Other WRs"
			pointFrame = thumbnails.createAvatarPortraitPopup(point.userId, false, nil, 1)
			pointFrame.Name = "Point_" .. i
			pointFrame.Size = UDim2.fromOffset(avatarSize, avatarSize)
			pointFrame.Position = UDim2.fromOffset(xPos - avatarSize / 2, yPos - avatarSize / 2)
			pointFrame.ZIndex = 3
			pointFrame.Parent = chartBg
		else
			-- Use colored dot for user's WRs and race discovery
			pointFrame = Instance.new("Frame")
			pointFrame.Name = "Point_" .. i
			pointFrame.Size = UDim2.fromOffset(POINT_SIZE, POINT_SIZE)
			pointFrame.Position = UDim2.fromOffset(xPos - POINT_SIZE / 2, yPos - POINT_SIZE / 2)
			pointFrame.BackgroundColor3 = pointColor
			pointFrame.BorderSizePixel = 1
			pointFrame.BorderColor3 = colors.black
			pointFrame.ZIndex = 3
			pointFrame.Parent = chartBg

			local pointCorner = Instance.new("UICorner")
			pointCorner.CornerRadius = UDim.new(0.5, 0)
			pointCorner.Parent = pointFrame
		end

		-- Enhanced tooltip on hover with grid layout
		local activeTooltip: Frame? = nil

		-- Helper to show tooltip - shared by parent frame and child image
		local function showTooltip()
			if activeTooltip then
				activeTooltip:Destroy()
			end

			-- Tooltip dimensions for grid layout
			local tooltipWidth = 220
			local avatarRowHeight = 40
			local gridRowHeight = 18
			local labelWidth = 90
			local _valueWidth = tooltipWidth - labelWidth - 16

			local tipFrame = Instance.new("Frame")
			tipFrame.Name = "Tooltip"
			tipFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
			tipFrame.BorderSizePixel = 1
			tipFrame.BorderColor3 = colors.black
			tipFrame.ZIndex = 10
			tipFrame.Parent = chartBg
			activeTooltip = tipFrame

			local tooltipCorner = Instance.new("UICorner")
			tooltipCorner.CornerRadius = UDim.new(0, 6)
			tooltipCorner.Parent = tipFrame

			local tooltipPadding = Instance.new("UIPadding")
			tooltipPadding.PaddingLeft = UDim.new(0, 8)
			tooltipPadding.PaddingRight = UDim.new(0, 8)
			tooltipPadding.PaddingTop = UDim.new(0, 8)
			tooltipPadding.PaddingBottom = UDim.new(0, 8)
			tooltipPadding.Parent = tipFrame

			local tooltipLayout = Instance.new("UIListLayout")
			tooltipLayout.SortOrder = Enum.SortOrder.LayoutOrder
			tooltipLayout.Padding = UDim.new(0, 4)
			tooltipLayout.Parent = tipFrame

			-- Header row: Avatar + Username
			local headerRow = Instance.new("Frame")
			headerRow.Size = UDim2.new(1, 0, 0, avatarRowHeight)
			headerRow.BackgroundTransparency = 1
			headerRow.LayoutOrder = 1
			headerRow.Parent = tipFrame

			-- Avatar in header
			local avatarFrame = thumbnails.createAvatarPortraitPopup(point.userId, false, nil, 1)
			avatarFrame.Size = UDim2.fromOffset(avatarRowHeight - 4, avatarRowHeight - 4)
			avatarFrame.Position = UDim2.fromOffset(0, 2)
			avatarFrame.Parent = headerRow

			-- Username next to avatar
			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(1, -(avatarRowHeight + 4), 0, avatarRowHeight)
			nameLabel.Position = UDim2.fromOffset(avatarRowHeight + 4, 0)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = point.username
			nameLabel.TextColor3 = pointColor
			nameLabel.FontFace = fonts.GetFont(false, true)
			nameLabel.TextSize = 14
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.TextYAlignment = Enum.TextYAlignment.Center
			nameLabel.Parent = headerRow

			-- Helper to create grid rows
			local function createGridRow(labelText: string, valueText: string, valueColor: Color3?, layoutOrder: number)
				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, 0, 0, gridRowHeight)
				row.BackgroundTransparency = 1
				row.LayoutOrder = layoutOrder
				row.Parent = tipFrame

				local label = Instance.new("TextLabel")
				label.Size = UDim2.fromOffset(labelWidth, gridRowHeight)
				label.BackgroundTransparency = 1
				label.Text = labelText
				label.TextColor3 = colors.white
				label.FontFace = fonts.GetFont(false, false)
				label.TextSize = 11
				label.TextXAlignment = Enum.TextXAlignment.Left
				label.Parent = row

				local value = Instance.new("TextLabel")
				value.Size = UDim2.new(1, -labelWidth, 0, gridRowHeight)
				value.Position = UDim2.fromOffset(labelWidth, 0)
				value.BackgroundTransparency = 1
				value.Text = valueText
				value.TextColor3 = valueColor or colors.white
				value.FontFace = fonts.GetFont(true, false)
				value.TextSize = 11
				value.TextXAlignment = Enum.TextXAlignment.Right
				value.Parent = row
			end

			-- Grid rows with data
			local rowOrder = 2
			createGridRow("Time:", formatTime(point.milliseconds), colors.white, rowOrder)
			rowOrder = rowOrder + 1

			createGridRow("Date:", formatDateFull(point.time), colors.textLight, rowOrder)
			rowOrder = rowOrder + 1

			if point.improvement and point.improvement > 0 then
				createGridRow("Improved by:", formatTime(point.improvement), colors.greenGo, rowOrder)
				rowOrder = rowOrder + 1
			end

			if point.attemptsByWinner and point.attemptsByWinner > 0 then
				createGridRow("Winner attempts:", tostring(point.attemptsByWinner), colors.textLight, rowOrder)
				rowOrder = rowOrder + 1
			end

			if point.attemptsBetween and point.attemptsBetween > 0 then
				createGridRow("Total attempts:", tostring(point.attemptsBetween), colors.textLight, rowOrder)
				rowOrder = rowOrder + 1
			end

			if point.recordStood and point.recordStood > 0 then
				local stoodText, _ = tpUtil.formatDateGap(point.recordStood)
				createGridRow("Record stood:", stoodText, colors.textLight, rowOrder)
				rowOrder = rowOrder + 1
			end

			-- Calculate total height
			local numGridRows = rowOrder - 2
			local contentHeight = avatarRowHeight + (numGridRows * (gridRowHeight + 4)) + 16
			tipFrame.Size = UDim2.fromOffset(tooltipWidth, contentHeight)

			-- Clamp tooltip to chart bounds
			local tooltipX = xPos + 20
			local tooltipY = yPos - contentHeight / 2
			if tooltipX + tooltipWidth > chartWidth then
				tooltipX = xPos - tooltipWidth - 10
			end
			if tooltipY < 0 then
				tooltipY = 0
			end
			if tooltipY + contentHeight > chartHeight then
				tooltipY = chartHeight - contentHeight
			end
			tipFrame.Position = UDim2.fromOffset(tooltipX, tooltipY)
		end

		-- Helper to hide tooltip - shared by parent frame and child image
		local function hideTooltip()
			if activeTooltip then
				activeTooltip:Destroy()
				activeTooltip = nil
			end
		end

		-- Connect tooltip handlers to both parent frame and child image
		-- Uses helper because Roblox mouse events don't bubble from child to parent
		thumbnails.connectPortraitMouseHandlers(pointFrame, showTooltip, hideTooltip)

		prevX = xPos
		prevY = yPos
	end

	-- Final horizontal line to edge
	if prevX and prevY then
		local finalLine = Instance.new("Frame")
		finalLine.Size = UDim2.fromOffset(chartWidth - prevX, LINE_THICKNESS)
		finalLine.Position = UDim2.fromOffset(prevX, prevY - LINE_THICKNESS / 2)
		finalLine.BackgroundColor3 = colors.warpColor
		finalLine.BorderSizePixel = 0
		finalLine.ZIndex = 2
		finalLine.Parent = chartBg
	end

	-- Legend
	local legendFrame = Instance.new("Frame")
	legendFrame.Name = "Legend"
	legendFrame.Size = UDim2.fromOffset(200, 60)
	legendFrame.Position = UDim2.fromOffset(chartX + chartWidth - 210, chartY + 10)
	legendFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	legendFrame.BackgroundTransparency = 0.3
	legendFrame.BorderSizePixel = 0
	legendFrame.ZIndex = 5
	legendFrame.Parent = container

	local legendCorner = Instance.new("UICorner")
	legendCorner.CornerRadius = UDim.new(0, 4)
	legendCorner.Parent = legendFrame

	local legendLayout = Instance.new("UIListLayout")
	legendLayout.SortOrder = Enum.SortOrder.LayoutOrder
	legendLayout.Padding = UDim.new(0, 2)
	legendLayout.Parent = legendFrame

	local legendPadding = Instance.new("UIPadding")
	legendPadding.PaddingLeft = UDim.new(0, 8)
	legendPadding.PaddingTop = UDim.new(0, 6)
	legendPadding.Parent = legendFrame

	local legendEntries = {
		{ color = colors.meColor, text = "Your WRs" },
		{ color = colors.greenGo, text = "Race Discovery" },
		{ color = colors.defaultGrey, text = "Other WRs" },
	}

	for i, entry in ipairs(legendEntries) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -16, 0, 14)
		row.BackgroundTransparency = 1
		row.LayoutOrder = i
		row.Parent = legendFrame

		local dot = Instance.new("Frame")
		dot.Size = UDim2.fromOffset(10, 10)
		dot.Position = UDim2.fromOffset(0, 2)
		dot.BackgroundColor3 = entry.color
		dot.BorderSizePixel = 0
		dot.Parent = row

		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(0.5, 0)
		dotCorner.Parent = dot

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -18, 1, 0)
		label.Position = UDim2.fromOffset(18, 0)
		label.BackgroundTransparency = 1
		label.Text = entry.text
		label.TextColor3 = colors.white
		label.FontFace = fonts.GetFont(false, true) -- Bold for clarity
		label.TextSize = 12
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = row
	end

	_annotate(string.format("Created WR progression chart with %d points", #points))

	return {
		destroy = function()
			container:Destroy()
		end,
		getFrame = function()
			return container
		end,
	}
end

--------------------------------------------------------------------------------
-- Scale-based Chart (fills parent, resizes instantly)
--------------------------------------------------------------------------------

function module.CreateScaled(parent: Frame, wrData: { gametypes.wrProgressionEntry }, raceTitle: string, config: ScaledChartConfig?): Frame
	local cfg: ScaledChartConfig = config or {
		title = raceTitle,
		showAttempts = true,
		showVersionMarkers = true,
		showTitle = true,
	}

	-- Load profile visibility setting
	local showProfilesSetting = settings.GetSettingByName(settingEnums.settingDefinitions.WR_CHART_SHOW_PROFILES.name)
	local showProfiles = if showProfilesSetting.booleanValue == nil then true else showProfilesSetting.booleanValue

	-- Load version visibility setting
	local showVersionsSetting = settings.GetSettingByName(settingEnums.settingDefinitions.WR_CHART_SHOW_VERSIONS.name)
	local showVersions = if showVersionsSetting.booleanValue == nil then true else showVersionsSetting.booleanValue

	-- Convert WR entries to chart points (reverse to chronological order)
	local points: { WRPoint } = {}
	local totalEntries = #wrData
	for i = totalEntries, 1, -1 do
		local entry = wrData[i]
		table.insert(points, {
			time = entry.runTime,
			milliseconds = entry.runMilliseconds,
			username = entry.username,
			userId = entry.userId,
			improvement = entry.improvementMs,
			attemptsBetween = entry.attemptsBetween,
			attemptsByWinner = entry.attemptsByWinner,
			recordStood = entry.recordStood,
			isFirstRun = (i == totalEntries),
		})
	end

	-- Toggle row height for "Show Profiles" toggle
	local TOGGLE_ROW_HEIGHT = 28

	-- Main container fills parent completely
	local container = Instance.new("Frame")
	container.Name = "WRProgressionChart"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundColor3 = colors.panelDark
	container.BorderSizePixel = 0
	container.Parent = parent

	if #points == 0 then
		local emptyLabel = Instance.new("TextLabel")
		emptyLabel.Size = UDim2.fromScale(1, 1)
		emptyLabel.BackgroundTransparency = 1
		emptyLabel.Text = "No WR data available"
		emptyLabel.TextColor3 = colors.white
		emptyLabel.FontFace = fonts.GetFont(false, false)
		emptyLabel.TextSize = 16
		emptyLabel.Parent = container
		return container
	end

	-- Calculate data bounds
	local minTime = points[1].time
	local maxTime = os.time() -- Extend to today
	local timeRange = math.max(maxTime - minTime, 1)
	minTime = minTime - timeRange * 0.02
	timeRange = maxTime - minTime

	local minMs = math.huge
	local maxMs = -math.huge
	for _, p in ipairs(points) do
		minMs = math.min(minMs, p.milliseconds)
		maxMs = math.max(maxMs, p.milliseconds)
	end
	local msRange = math.max(maxMs - minMs, 1)
	local msPadding = msRange * 0.1
	minMs = math.max(0, minMs - msPadding)
	maxMs = maxMs + msPadding
	msRange = maxMs - minMs

	-- Layout constants (as scale values)
	local yAxisWidthScale = 0.08 -- 8% for Y-axis (narrower, flush left)
	local xAxisHeightScale = 0.08 -- 8% for X-axis (moved up, less black space)
	local rightPaddingScale = 0.03 -- 3% right padding for "now" label
	local topPaddingScale = 0.04 -- 4% top padding to prevent Y-axis label overlapping header

	-- Y-axis frame (left side) - adjusted for toggle row at bottom
	local yAxisFrame = Instance.new("Frame")
	yAxisFrame.Name = "YAxis"
	yAxisFrame.Size = UDim2.new(yAxisWidthScale, 0, 1 - xAxisHeightScale - topPaddingScale, -TOGGLE_ROW_HEIGHT)
	yAxisFrame.Position = UDim2.fromScale(0, topPaddingScale)
	yAxisFrame.BackgroundTransparency = 1
	yAxisFrame.Parent = container

	-- Chart area (main plotting region) - adjusted for toggle row at bottom
	-- ClipsDescendants = false allows portraits at edges to extend slightly outside
	local chartBg = Instance.new("Frame")
	chartBg.Name = "ChartBackground"
	chartBg.Size = UDim2.new(1 - yAxisWidthScale - rightPaddingScale, 0, 1 - xAxisHeightScale - topPaddingScale, -TOGGLE_ROW_HEIGHT)
	chartBg.Position = UDim2.fromScale(yAxisWidthScale, topPaddingScale)
	chartBg.BackgroundColor3 = colors.panelMedium
	chartBg.BorderSizePixel = 0
	chartBg.ClipsDescendants = false -- Allow portraits at right edge to be fully visible
	chartBg.Parent = container

	-- X-axis frame (bottom, above toggle row)
	local xAxisFrame = Instance.new("Frame")
	xAxisFrame.Name = "XAxis"
	xAxisFrame.Size = UDim2.new(1 - yAxisWidthScale - rightPaddingScale, 0, xAxisHeightScale, 0)
	xAxisFrame.Position = UDim2.new(yAxisWidthScale, 0, 1 - xAxisHeightScale, -TOGGLE_ROW_HEIGHT)
	xAxisFrame.BackgroundTransparency = 1
	xAxisFrame.Parent = container

	-- Toggle row at very bottom
	local toggleRow = Instance.new("Frame")
	toggleRow.Name = "ToggleRow"
	toggleRow.Size = UDim2.new(1, 0, 0, TOGGLE_ROW_HEIGHT)
	toggleRow.Position = UDim2.new(0, 0, 1, -TOGGLE_ROW_HEIGHT)
	toggleRow.BackgroundColor3 = colors.panelMedium
	toggleRow.BorderSizePixel = 0
	toggleRow.Parent = container

	-- Helper to style toggle buttons consistently
	local function styleToggleButton(button: TextButton, isOn: boolean, label: string)
		button.BackgroundColor3 = if isOn then colors.greenGo else colors.defaultGrey
		button.Text = label .. ": " .. (if isOn then "On" else "Off")
		button.TextColor3 = colors.black
	end

	-- Toggle button for "Show Profiles"
	local profilesToggle = Instance.new("TextButton")
	profilesToggle.Name = "ShowProfilesToggle"
	profilesToggle.Size = UDim2.new(0, 100, 0, TOGGLE_ROW_HEIGHT - 6)
	profilesToggle.Position = UDim2.new(0, 4, 0, 3)
	profilesToggle.BorderSizePixel = 1
	profilesToggle.BorderColor3 = colors.black
	profilesToggle.FontFace = fonts.GetFont(false, true)
	profilesToggle.TextSize = 13
	profilesToggle.AutoButtonColor = true
	profilesToggle.Parent = toggleRow
	styleToggleButton(profilesToggle, showProfiles, "Profiles")

	-- Toggle button for "Show Versions"
	local versionsToggle = Instance.new("TextButton")
	versionsToggle.Name = "ShowVersionsToggle"
	versionsToggle.Size = UDim2.new(0, 100, 0, TOGGLE_ROW_HEIGHT - 6)
	versionsToggle.Position = UDim2.new(0, 110, 0, 3)
	versionsToggle.BorderSizePixel = 1
	versionsToggle.BorderColor3 = colors.black
	versionsToggle.FontFace = fonts.GetFont(false, true)
	versionsToggle.TextSize = 13
	versionsToggle.AutoButtonColor = true
	versionsToggle.Parent = toggleRow
	styleToggleButton(versionsToggle, showVersions, "Versions")

	-- Forward declaration for drawChart (defined below, but referenced by toggle handler)
	local drawChart: (Vector2) -> ()

	-- Profiles toggle click handler - saves setting and rebuilds chart
	profilesToggle.MouseButton1Click:Connect(function()
		showProfiles = not showProfiles
		styleToggleButton(profilesToggle, showProfiles, "Profiles")

		-- Save the setting
		local settingToSave = {
			name = settingEnums.settingDefinitions.WR_CHART_SHOW_PROFILES.name,
			domain = settingEnums.settingDefinitions.WR_CHART_SHOW_PROFILES.domain,
			kind = settingEnums.settingDefinitions.WR_CHART_SHOW_PROFILES.kind,
			booleanValue = showProfiles,
		}
		settings.SetSetting(settingToSave)

		-- Redraw the chart with new profile visibility
		drawChart(chartBg.AbsoluteSize)
	end)

	-- Versions toggle click handler - saves setting and rebuilds chart
	versionsToggle.MouseButton1Click:Connect(function()
		showVersions = not showVersions
		styleToggleButton(versionsToggle, showVersions, "Versions")

		-- Save the setting
		local settingToSave = {
			name = settingEnums.settingDefinitions.WR_CHART_SHOW_VERSIONS.name,
			domain = settingEnums.settingDefinitions.WR_CHART_SHOW_VERSIONS.domain,
			kind = settingEnums.settingDefinitions.WR_CHART_SHOW_VERSIONS.kind,
			booleanValue = showVersions,
		}
		settings.SetSetting(settingToSave)

		-- Redraw the chart with new version visibility
		drawChart(chartBg.AbsoluteSize)
	end)

	-- Y-axis labels (doubled font size, white, with "s" suffix, rounded to nice values)
	-- NOTE: Y-axis is INVERTED so faster times (lower ms) are at TOP of chart
	local numYLabels = 5
	for i = 0, numYLabels do
		local t = i / numYLabels
		local msValue = roundToNiceMs(lerp(minMs, maxMs, t))
		-- Recalculate actual scale position based on rounded value
		local yScale = (msValue - minMs) / msRange
		yScale = math.clamp(yScale, 0, 1)
		-- INVERT: lower ms values (better times) at TOP of chart
		local yPos = 1 - yScale

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -2, 0, 28)
		label.Position = UDim2.new(0, 0, yPos, -14)
		label.BackgroundTransparency = 1
		label.Text = formatTimeWithUnit(msValue)
		label.TextColor3 = colors.white
		label.FontFace = fonts.GetFont(true, true) -- Monospace bold
		label.TextSize = 28 -- Doubled from 14
		label.TextXAlignment = Enum.TextXAlignment.Right
		label.Parent = yAxisFrame

		-- Grid line at exact label position
		local gridLine = Instance.new("Frame")
		gridLine.Size = UDim2.new(1, 0, 0, 1)
		gridLine.Position = UDim2.fromScale(0, yPos)
		gridLine.BackgroundColor3 = colors.gridLine
		gridLine.BorderSizePixel = 0
		gridLine.Parent = chartBg
	end

	-- User's best time marker on Y-axis (only if not current WR holder)
	local currentWRHolderUserId = if #points > 0 then points[#points].userId else nil
	local userIsWRHolder = currentWRHolderUserId == localPlayer.UserId
	local userBestMs = cfg.userBestMs
	local userBestUserId = cfg.userBestUserId or localPlayer.UserId
	local userBestUsername = cfg.userBestUsername or localPlayer.Name

	if userBestMs and userBestMs > 0 and not userIsWRHolder then
		-- Calculate Y position for user's best time
		local userYScale = (userBestMs - minMs) / msRange
		userYScale = math.clamp(userYScale, 0, 1)
		local userYPos = 1 - userYScale -- Inverted: faster at top

		-- Portrait size for user marker
		local userPortraitSize = 36

		-- Container for the marker (on the Y-axis, right edge)
		local userBestMarker = Instance.new("Frame")
		userBestMarker.Name = "UserBestMarker"
		userBestMarker.Size = UDim2.new(0, 12, 0, 4)
		userBestMarker.AnchorPoint = Vector2.new(0, 0.5)
		userBestMarker.Position = UDim2.new(1, -12, userYPos, 0)
		userBestMarker.BackgroundColor3 = colors.meColor
		userBestMarker.BorderSizePixel = 0
		userBestMarker.ZIndex = 5
		userBestMarker.Parent = yAxisFrame

		-- Horizontal line extending into chart area to mark the level
		local userBestLine = Instance.new("Frame")
		userBestLine.Name = "UserBestLine"
		userBestLine.Size = UDim2.new(1, 0, 0, 2)
		userBestLine.Position = UDim2.fromScale(0, userYPos)
		userBestLine.AnchorPoint = Vector2.new(0, 0.5)
		userBestLine.BackgroundColor3 = colors.meColor
		userBestLine.BackgroundTransparency = 0.6
		userBestLine.BorderSizePixel = 0
		userBestLine.ZIndex = 1
		userBestLine.Parent = chartBg

		-- Border ring for portrait
		local userBorderRing = Instance.new("Frame")
		userBorderRing.Name = "UserBestBorderRing"
		userBorderRing.Size = UDim2.fromOffset(userPortraitSize + 4, userPortraitSize + 4)
		userBorderRing.AnchorPoint = Vector2.new(1, 0.5)
		userBorderRing.Position = UDim2.new(1, -14, userYPos, 0)
		userBorderRing.BackgroundColor3 = colors.meColor
		userBorderRing.BorderSizePixel = 0
		userBorderRing.ZIndex = 5
		userBorderRing.Parent = yAxisFrame
		local ringCorner = Instance.new("UICorner")
		ringCorner.CornerRadius = UDim.new(0.5, 0)
		ringCorner.Parent = userBorderRing

		-- Portrait
		local userPortrait = thumbnails.createAvatarPortraitPopup(userBestUserId, false, nil, 0)
		userPortrait.Name = "UserBestPortrait"
		userPortrait.Size = UDim2.fromOffset(userPortraitSize, userPortraitSize)
		userPortrait.AnchorPoint = Vector2.new(0.5, 0.5)
		userPortrait.Position = UDim2.fromScale(0.5, 0.5)
		userPortrait.ZIndex = 6
		userPortrait.Parent = userBorderRing
		makeCircular(userPortrait)

		-- Username label below portrait
		local userNameLabel = Instance.new("TextLabel")
		userNameLabel.Name = "UserBestNameLabel"
		userNameLabel.Size = UDim2.new(1, 0, 0, 14)
		userNameLabel.AnchorPoint = Vector2.new(1, 0)
		userNameLabel.Position = UDim2.new(1, -14, userYPos, (userPortraitSize / 2) + 4)
		userNameLabel.BackgroundTransparency = 1
		userNameLabel.Text = userBestUsername
		userNameLabel.TextColor3 = colors.meColor
		userNameLabel.FontFace = fonts.GetFont(false, true)
		userNameLabel.TextSize = 12
		userNameLabel.TextXAlignment = Enum.TextXAlignment.Right
		userNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		userNameLabel.ZIndex = 5
		userNameLabel.Parent = yAxisFrame

		-- Time label above portrait
		local userBestLabel = Instance.new("TextLabel")
		userBestLabel.Name = "UserBestLabel"
		userBestLabel.Size = UDim2.new(1, 0, 0, 16)
		userBestLabel.AnchorPoint = Vector2.new(1, 1)
		userBestLabel.Position = UDim2.new(1, -14, userYPos, -(userPortraitSize / 2) - 4)
		userBestLabel.BackgroundTransparency = 1
		userBestLabel.Text = formatTime(userBestMs)
		userBestLabel.TextColor3 = colors.meColor
		userBestLabel.FontFace = fonts.GetFont(true, true)
		userBestLabel.TextSize = 16
		userBestLabel.TextXAlignment = Enum.TextXAlignment.Right
		userBestLabel.ZIndex = 5
		userBestLabel.Parent = yAxisFrame
	end

	-- X-axis ticks/labels and version markers are rendered inside drawChart() so they
	-- stay aligned with marker positions (which reserve left-side space for portraits)
	-- and so they redraw correctly on resize.

	-- Global tooltip tracker - only one tooltip visible at a time
	local globalActiveTooltip: Frame? = nil

	-- Helper function to show tooltip for a point - used by both portraits and marker dots
	local function showTooltipForPoint(point: WRPoint, tooltipContainer: Frame): Frame
		if globalActiveTooltip then
			globalActiveTooltip:Destroy()
		end

		local tooltipWidth = 320
		local rowHeight = 28
		local tipFrame = Instance.new("Frame")
		tipFrame.Name = "Tooltip"
		tipFrame.Size = UDim2.fromOffset(tooltipWidth, 0)
		tipFrame.AutomaticSize = Enum.AutomaticSize.Y
		tipFrame.BackgroundColor3 = colors.defaultGrey
		tipFrame.BackgroundTransparency = 0
		tipFrame.BorderSizePixel = 2
		tipFrame.BorderColor3 = colors.black
		tipFrame.ZIndex = 100
		tipFrame.Parent = tooltipContainer

		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 0)
		layout.Parent = tipFrame

		-- Header row with portrait and username
		local header = Instance.new("Frame")
		header.Size = UDim2.new(1, 0, 0, 36)
		header.BackgroundColor3 = colors.meColor
		header.BorderSizePixel = 1
		header.BorderColor3 = colors.black
		header.ZIndex = 101
		header.LayoutOrder = 0
		header.Parent = tipFrame

		local av = thumbnails.createAvatarPortraitPopup(point.userId, false, nil, 0)
		av.Size = UDim2.fromOffset(32, 32)
		av.Position = UDim2.fromOffset(2, 2)
		av.ZIndex = 102
		av.Parent = header

		local nm = Instance.new("TextLabel")
		nm.Size = UDim2.new(1, -40, 1, 0)
		nm.Position = UDim2.fromOffset(38, 0)
		nm.BackgroundTransparency = 1
		nm.Text = point.username
		nm.TextColor3 = colors.black
		nm.TextSize = 18
		nm.FontFace = fonts.GetFont(false, true)
		nm.TextXAlignment = Enum.TextXAlignment.Left
		nm.ZIndex = 101
		nm.Parent = header

		-- Data Rows - standard table style
		local rowOrder = 1
		local function addRow(lbl: string, val: string)
			local fr = Instance.new("Frame")
			fr.Size = UDim2.new(1, 0, 0, rowHeight)
			fr.BackgroundColor3 = colors.defaultGrey
			fr.BorderSizePixel = 1
			fr.BorderColor3 = colors.black
			fr.ZIndex = 101
			fr.LayoutOrder = rowOrder
			fr.Parent = tipFrame
			rowOrder = rowOrder + 1

			local l = Instance.new("TextLabel")
			l.Size = UDim2.new(0.5, 0, 1, 0)
			l.BackgroundTransparency = 1
			l.Text = lbl
			l.TextColor3 = colors.black
			l.TextSize = 16
			l.FontFace = fonts.GetFont(false, false)
			l.TextXAlignment = Enum.TextXAlignment.Left
			l.ZIndex = 101
			l.Parent = fr

			local lPad = Instance.new("UIPadding")
			lPad.PaddingLeft = UDim.new(0, 6)
			lPad.Parent = l

			local v = Instance.new("TextLabel")
			v.Size = UDim2.new(0.5, 0, 1, 0)
			v.Position = UDim2.fromScale(0.5, 0)
			v.BackgroundTransparency = 1
			v.Text = val
			v.TextColor3 = colors.black
			v.TextSize = 16
			v.FontFace = fonts.GetFont(true, false)
			v.TextXAlignment = Enum.TextXAlignment.Right
			v.ZIndex = 101
			v.Parent = fr

			local vPad = Instance.new("UIPadding")
			vPad.PaddingRight = UDim.new(0, 6)
			vPad.Parent = v
		end

		addRow("Time:", formatTime(point.milliseconds))
		addRow("Date:", formatDateFull(point.time))
		if point.improvement and point.improvement > 0 then
			addRow("Improved by:", formatTime(point.improvement))
		end
		if point.attemptsBetween then
			addRow("Total attempts:", tostring(point.attemptsBetween))
		end
		if point.attemptsByWinner then
			addRow("Winner attempts:", tostring(point.attemptsByWinner))
		end
		if point.recordStood and point.recordStood > 0 then
			local stoodText, _ = tpUtil.formatDateGap(point.recordStood)
			addRow("Record stood:", stoodText)
		end

		-- Position: Pop down and left from mouse (Upper Right corner at mouse)
		tipFrame.AnchorPoint = Vector2.new(1, 0)
		local mouse = Players.LocalPlayer:GetMouse()
		local cPos = tooltipContainer.AbsolutePosition
		-- Mouse position relative to container
		local relX = mouse.X - cPos.X
		local relY = mouse.Y - cPos.Y
		tipFrame.Position = UDim2.fromOffset(relX, relY)

		globalActiveTooltip = tipFrame
		return tipFrame
	end

	local function hideTooltip()
		if globalActiveTooltip then
			globalActiveTooltip:Destroy()
			globalActiveTooltip = nil
		end
	end

	-- Use a reasonable default size if AbsoluteSize is not ready
	-- Cache portrait placements across resizes so portraits do not visibly "jump"
	-- left/right as the modal changes size.
	local lastPortraitCentersByIndex: { [number]: Vector2 } = {}
	local lastChartSize: Vector2? = nil
	local lastViolationCount: number? = nil

	drawChart = function(containerSize: Vector2)
		-- Destroy any active tooltip before redrawing - prevents orphaned tooltips when
		-- portraits are destroyed (MouseLeave doesn't fire on Instance:Destroy())
		if globalActiveTooltip then
			globalActiveTooltip:Destroy()
			globalActiveTooltip = nil
		end

		-- Clear previous dynamic elements (markers, lines, portraits, step lines, version markers)
		-- Note: chartBg contains grid lines too, so we should be careful what we destroy.
		for _, child in ipairs(chartBg:GetChildren()) do
			if child.Name:match("^Point_") or child.Name:match("^LineMarker_") or child.Name:match("^Connector_") or child.Name:match("^BorderRing_") or child.Name:match("^Username_") or child.Name:match("^StepLine_") or child.Name:match("^VersionLine_") or child.Name:match("^VersionLabel_") then
				child:Destroy()
			end
		end

		for _, child in ipairs(xAxisFrame:GetChildren()) do
			if child.Name:match("^XTick_") or child.Name:match("^XLabel_") then
				child:Destroy()
			end
		end

		local width = containerSize.X
		local height = containerSize.Y
		if width <= 0 then
			width = 800
		end -- Fallback
		if height <= 0 then
			height = 500
		end -- Fallback

		-- Adaptive portrait sizing: at small chart sizes, large fixed portraits make strict
		-- placement infeasible. Shrinking portraits preserves rules without overlaps.
		local pointCount = #points
		-- Tuned for feasibility: prefer smaller portraits when there are many WR points in a small plot.
		local portraitSizePx = math.clamp(math.floor(math.sqrt((width * height * 0.18) / math.max(pointCount, 1)) * 0.55), 18, POINT_SIZE)

		-- Helper: map raw [0..1] time progress into an adjusted X scale that reserves space
		-- near the left edge so portraits can sit left of their marker dots without
		-- overlapping the left axis.
		local function xScaleAdjusted(rawX: number): number
			local portraitRadius = (portraitSizePx / 2) + 3
			local markerRadius = 6
			local edgePadPx = 4
			local minDxPx = portraitRadius + markerRadius + 16
			local leftInsetPx = (portraitRadius * 2) + markerRadius + 16 + edgePadPx -- ensures portrait can be left of leftmost marker
			local rightInsetPx = 12

			local leftInsetScale = math.clamp(leftInsetPx / width, 0, 0.45)
			local rightInsetScale = math.clamp(rightInsetPx / width, 0, 0.2)

			local usable = math.max(1 - leftInsetScale - rightInsetScale, 0.05)
			local clampedRaw = math.clamp(rawX, 0, 1)

			-- If rawX is extremely close to 0, push it right enough that we can still place a portrait
			-- to the left (this enforces "no portraits to the right of the leader's marker").
			local _ = minDxPx -- retained for readability of the derived inset above
			return leftInsetScale + (clampedRaw * usable)
		end

		-- Geometry helpers (axis-aligned segments)
		type Segment = { x1: number, y1: number, x2: number, y2: number }

		local function circleIntersectsSegment(cx: number, cy: number, r: number, seg: Segment, extraGap: number): boolean
			local gap = extraGap or 0
			local x1 = seg.x1
			local y1 = seg.y1
			local x2 = seg.x2
			local y2 = seg.y2

			if x1 == x2 then
				-- Vertical
				local minY = math.min(y1, y2)
				local maxY = math.max(y1, y2)
				local closestY = math.clamp(cy, minY, maxY)
				local dx = math.abs(cx - x1)
				local dy = math.abs(cy - closestY)
				return (dx * dx + dy * dy) <= ((r + gap) * (r + gap))
			end

			-- Horizontal
			local minX = math.min(x1, x2)
			local maxX = math.max(x1, x2)
			local closestX = math.clamp(cx, minX, maxX)
			local dx = math.abs(cx - closestX)
			local dy = math.abs(cy - y1)
			return (dx * dx + dy * dy) <= ((r + gap) * (r + gap))
		end

		-- Build marker positions (oldest -> newest) and step-line segments
		type Marker = {
			index: number,
			point: WRPoint,
			xScale: number,
			yScale: number,
			xPx: number,
			yPx: number,
			borderColor: Color3,
		}

		local markers: { Marker } = {}
		for i, p in ipairs(points) do
			local rawX = (p.time - minTime) / timeRange
			local xS = xScaleAdjusted(rawX)
			local yRaw = (p.milliseconds - minMs) / msRange
			local yS = math.clamp(1 - yRaw, 0, 1)

			local borderColor = colors.defaultGrey
			if p.userId == localPlayer.UserId then
				borderColor = colors.meColor
			elseif p.isFirstRun then
				borderColor = colors.greenGo
			end

			table.insert(markers, {
				index = i,
				point = p,
				xScale = xS,
				yScale = yS,
				xPx = xS * width,
				yPx = yS * height,
				borderColor = borderColor,
			})
		end

		local segments: { Segment } = {}
		local stepLineIndex = 0
		for i = 2, #markers do
			local prev = markers[i - 1]
			local cur = markers[i]
			stepLineIndex = stepLineIndex + 1

			-- Horizontal segment from prev to current at prev.y
			local hLine = Instance.new("Frame")
			hLine.Name = "StepLine_H_" .. stepLineIndex
			hLine.Size = UDim2.fromOffset(math.max(cur.xPx - prev.xPx, 1), LINE_THICKNESS)
			hLine.Position = UDim2.fromOffset(prev.xPx, prev.yPx - (LINE_THICKNESS / 2))
			hLine.BackgroundColor3 = colors.warpColor
			hLine.BorderSizePixel = 0
			hLine.ZIndex = 2
			hLine.Parent = chartBg
			table.insert(segments, { x1 = prev.xPx, y1 = prev.yPx, x2 = cur.xPx, y2 = prev.yPx })

			-- Vertical segment at current.x from prev.y to current.y
			local minY = math.min(prev.yPx, cur.yPx)
			local maxY = math.max(prev.yPx, cur.yPx)
			local vLine = Instance.new("Frame")
			vLine.Name = "StepLine_V_" .. stepLineIndex
			vLine.Size = UDim2.fromOffset(LINE_THICKNESS, math.max(maxY - minY, 1))
			vLine.Position = UDim2.fromOffset(cur.xPx - (LINE_THICKNESS / 2), minY)
			vLine.BackgroundColor3 = colors.warpColor
			vLine.BorderSizePixel = 0
			vLine.ZIndex = 2
			vLine.Parent = chartBg
			table.insert(segments, { x1 = cur.xPx, y1 = prev.yPx, x2 = cur.xPx, y2 = cur.yPx })
		end

		-- X-axis ticks and labels (aligned with adjusted X mapping)
		do
			local numXLabels = 5
			for i = 0, numXLabels do
				local t = i / numXLabels
				local rawTimeValue = lerp(minTime, maxTime, t)
				local timeValue: number
				local isNow = (i == numXLabels)

				if isNow then
					timeValue = maxTime
				else
					timeValue = getMidnightOfMonth(math.floor(rawTimeValue))
				end

				local rawX = (timeValue - minTime) / timeRange
				local xS = xScaleAdjusted(rawX)

				local tick = Instance.new("Frame")
				tick.Name = "XTick_" .. tostring(i)
				tick.Size = UDim2.new(0, 2, 0.3, 0)
				tick.Position = UDim2.new(xS, -1, 0, 0)
				tick.BackgroundColor3 = colors.white
				tick.BorderSizePixel = 0
				tick.Parent = xAxisFrame

				local label = Instance.new("TextLabel")
				label.Name = "XLabel_" .. tostring(i)
				label.Size = UDim2.new(0.18, 0, 0.5, 0)
				local labelOffset = if isNow then -0.15 else -0.09
				label.Position = UDim2.new(xS + labelOffset, 0, 0.25, 0)
				label.BackgroundTransparency = 1
				if isNow then
					label.Text = os.date("%Y-%m-%d", math.floor(timeValue)) :: string .. "\nnow"
				else
					label.Text = os.date("1 %b %Y", math.floor(timeValue)) :: string
				end
				label.TextColor3 = colors.white
				label.FontFace = fonts.GetFont(false, true)
				label.TextSize = 18
				label.TextYAlignment = Enum.TextYAlignment.Top
				label.Parent = xAxisFrame
			end
		end

		-- Version markers (aligned with adjusted X mapping)
		-- Small clear white text at the bottom of the chart
		if showVersions then
			local versions = versionHistory.GetVersionsInRange(minTime, maxTime)
			local versionIndex = 0
			for _, ver in ipairs(versions) do
				local rawT = (ver.timestamp - minTime) / timeRange
				if rawT >= 0 and rawT <= 1 then
					versionIndex = versionIndex + 1
					local xS = xScaleAdjusted(rawT)

					-- Subtle vertical tick line at bottom only (not full height)
					local versionLine = Instance.new("Frame")
					versionLine.Name = "VersionLine_" .. tostring(versionIndex)
					versionLine.Size = UDim2.new(0, 1, 0.08, 0)
					versionLine.Position = UDim2.new(xS, 0, 0.92, 0)
					versionLine.BackgroundColor3 = colors.white
					versionLine.BackgroundTransparency = 0.6
					versionLine.BorderSizePixel = 0
					versionLine.ZIndex = 1
					versionLine.Parent = chartBg

					-- Version label at bottom - small, clear, white
					local versionLabel = Instance.new("TextLabel")
					versionLabel.Name = "VersionLabel_" .. tostring(versionIndex)
					versionLabel.Size = UDim2.fromOffset(48, 14)
					versionLabel.AnchorPoint = Vector2.new(0.5, 1)
					versionLabel.Position = UDim2.new(xS, 0, 1, -2)
					versionLabel.BackgroundTransparency = 1
					versionLabel.Text = ver.version
					versionLabel.TextColor3 = colors.white
					versionLabel.FontFace = fonts.GetFont(false, false)
					versionLabel.TextSize = 11
					versionLabel.TextTransparency = 0.2
					versionLabel.ZIndex = 1
					versionLabel.Parent = chartBg
				end
			end
		end

		-- Portrait placement: greedy newest -> oldest with collision checks.
		local markerSize = 12
		local markerRadius = markerSize / 2
		local portraitRadius = (portraitSizePx / 2) + 3 -- include border ring thickness in collision
		-- Minimum empty space between portrait circles (scaled to portrait size).
		local portraitGap = math.max(3, math.floor(portraitSizePx * 0.12))
		-- Clearance around the WR step line for portrait circles (scaled to portrait size).
		local lineGap = math.max(3, math.floor(portraitSizePx * 0.08) + 2)

		local placed: { { x: number, y: number, r: number } } = {}

		local function collidesWithPortraits(cx: number, cy: number, r: number): boolean
			for _, p in ipairs(placed) do
				local dx = cx - p.x
				local dy = cy - p.y
				local minDist = r + p.r + portraitGap
				if (dx * dx + dy * dy) < (minDist * minDist) then
					return true
				end
			end
			return false
		end

		local function collidesWithStepLine(cx: number, cy: number, r: number): boolean
			for _, seg in ipairs(segments) do
				-- Include half the line thickness in clearance so we don't visually overlap the stroke.
				if circleIntersectsSegment(cx, cy, r, seg, lineGap + (LINE_THICKNESS / 2)) then
					return true
				end
			end
			return false
		end

		local function withinChartBounds(cx: number, cy: number, r: number): boolean
			return (cx - r) >= 0 and (cy - r) >= 0 and (cx + r) <= width and (cy + r) <= height
		end

		local function choosePortraitCenter(mx: number, my: number, minCenterX: number?, preferredCenter: Vector2?): (number?, number?)
			-- Allow left/right placement to reduce crowding, but enforce monotonic X ordering:
			-- slower portraits cannot be to the right of faster portraits.
			local minX = minCenterX or -math.huge

			-- Base offsets are deliberately small; we rely on scoring to pick near placements.
			-- We also explore "vertical lane" candidates to avoid huge horizontal connector lengths.
			local baseDx = portraitRadius + markerRadius + 10
			local baseDy = 16
			local prefersUp = (my + portraitRadius + 8) > height
			local prefersDown = (my - portraitRadius - 8) < 0

			-- First try: keep the prior placement (scaled to current size) if it still satisfies constraints.
			if preferredCenter then
				local c = { x = preferredCenter.X, y = preferredCenter.Y }
				if c.x >= minX and withinChartBounds(c.x, c.y, portraitRadius) then
					if not collidesWithPortraits(c.x, c.y, portraitRadius) and not collidesWithStepLine(c.x, c.y, portraitRadius) then
						return c.x, c.y
					end
				end
			end

			local bestX: number? = nil
			local bestY: number? = nil
			local bestScore = math.huge

			-- We score candidates rather than first-fit to keep connectors short.
			local function scoreCandidate(cx: number, cy: number): number
				local dx = cx - mx
				local dy = cy - my
				local dist2 = dx * dx + dy * dy
				-- Penalize drifting to the right of the marker (reduces needless long diagonals).
				local rightPenalty = 0
				if dx > 0 then
					rightPenalty = dx * dx * 0.5
				end
				-- Mild penalty for vertical displacement to keep portraits near the point line,
				-- but not so strong that it forces huge horizontal shifts.
				local verticalPenalty = math.abs(dy) * 2
				return dist2 + rightPenalty + verticalPenalty
			end

			-- If monotonic ordering pushes us right of the marker, shift the "target" X used
			-- for candidate generation so we try near the minimum legal X first.
			local targetX = mx
			if minX > mx then
				targetX = minX
			end

			-- Lane spacing: big enough to avoid portrait overlap when stacked vertically.
			local laneStep = (portraitRadius * 2) + portraitGap
			local laneOffsets = {
				0,
				laneStep,
				-laneStep,
				laneStep * 2,
				-laneStep * 2,
				laneStep * 3,
				-laneStep * 3,
				laneStep * 4,
				-laneStep * 4,
				laneStep * 5,
				-laneStep * 5,
			}

			for attempt = 0, 35 do
				local dx = baseDx + (attempt * 12)
				local dy = baseDy + (attempt * 6)

				-- Candidates are ordered to keep connector short and reduce crowding:
				-- try near-horizontal offsets first, then diagonals, then increase radius.
				local candidates = {}

				-- 1) Near placements with lane stacking (keeps portraits near X, varies Y instead)
				for _, yOff in ipairs(laneOffsets) do
					table.insert(candidates, { x = targetX - dx, y = my + yOff })
					table.insert(candidates, { x = targetX + dx, y = my + yOff })
				end

				-- 2) Small diagonals around the marker (helps avoid step-line intersections)
				table.insert(candidates, { x = targetX - dx, y = my + (prefersUp and -dy or dy) })
				table.insert(candidates, { x = targetX - dx, y = my + (prefersDown and dy or -dy) })
				table.insert(candidates, { x = targetX + dx, y = my + (prefersUp and -dy or dy) })
				table.insert(candidates, { x = targetX + dx, y = my + (prefersDown and dy or -dy) })

				-- 3) Wider diagonals (last resort)
				table.insert(candidates, { x = targetX - (dx * 0.85), y = my - (dy * 1.2) })
				table.insert(candidates, { x = targetX - (dx * 0.85), y = my + (dy * 1.2) })
				table.insert(candidates, { x = targetX + (dx * 0.85), y = my - (dy * 1.2) })
				table.insert(candidates, { x = targetX + (dx * 0.85), y = my + (dy * 1.2) })

				-- If we have a preferredCenter, bias candidates around it before expanding outwards.
				if preferredCenter then
					local px = preferredCenter.X
					local py = preferredCenter.Y
					table.insert(candidates, 1, { x = px, y = py })
					table.insert(candidates, 2, { x = px - 16, y = py })
					table.insert(candidates, 3, { x = px + 16, y = py })
					table.insert(candidates, 4, { x = px, y = py - 16 })
					table.insert(candidates, 5, { x = px, y = py + 16 })
				end

				for _, c in ipairs(candidates) do
					if c.x >= minX and withinChartBounds(c.x, c.y, portraitRadius) then
						if not collidesWithPortraits(c.x, c.y, portraitRadius) and not collidesWithStepLine(c.x, c.y, portraitRadius) then
							local s = scoreCandidate(c.x, c.y)
							if s < bestScore then
								bestScore = s
								bestX = c.x
								bestY = c.y
							end
						end
					end
				end

				-- If we already found a very good candidate, stop expanding early.
				-- Threshold is in px^2 units; tuned to favor "near" placements.
				if bestX and bestScore < 1800 then
					break
				end
			end

			if bestX and bestY then
				return bestX, bestY
			end

			-- No safe position found. Returning nil prevents us from rendering an invalid portrait.
			return nil, nil
		end

		-- Render markers and (optionally) portraits.
		for i, m in ipairs(markers) do
			-- Marker Dot (always visible)
			local markerDot = Instance.new("Frame")
			markerDot.Name = "LineMarker_" .. tostring(i)
			markerDot.Size = UDim2.fromOffset(markerSize, markerSize)
			markerDot.AnchorPoint = Vector2.new(0.5, 0.5)
			markerDot.Position = UDim2.fromOffset(m.xPx, m.yPx)
			markerDot.BackgroundColor3 = m.borderColor
			markerDot.BorderSizePixel = 0
			markerDot.ZIndex = 6
			markerDot.Parent = chartBg
			local markerCorner = Instance.new("UICorner")
			markerCorner.CornerRadius = UDim.new(0.5, 0)
			markerCorner.Parent = markerDot

			-- Hover Tooltip (always available)
			markerDot.MouseEnter:Connect(function()
				showTooltipForPoint(m.point, container)
			end)
			markerDot.MouseLeave:Connect(hideTooltip)

			if showProfiles then
				-- Place portraits newest -> oldest, but render order still follows i; ZIndex ensures newer wins.
				-- We pick centers in a separate pass so collisions see already-placed newer portraits.
			end
		end

		if showProfiles then
			-- Reset to a strict, rule-preserving placement:
			-- single-pass placement that only accepts centers that satisfy constraints.
			-- No relaxation/post-processing until we have a validator that proves correctness.

			local scaledPreferredByIndex: { [number]: Vector2 } = {}
			if lastChartSize and lastChartSize.X > 0 and lastChartSize.Y > 0 then
				local sx = width / lastChartSize.X
				local sy = height / lastChartSize.Y
				for idx, v in pairs(lastPortraitCentersByIndex) do
					scaledPreferredByIndex[idx] = Vector2.new(v.X * sx, v.Y * sy)
				end
			end

			local portraitCentersByIndex: { [number]: Vector2 } = {}

			-- Place portraits oldest -> newest, enforcing monotonic X ordering by passing minCenterX.
			local lastCenterX: number? = nil
			for i = 1, #markers do
				local m = markers[i]
				local preferred = scaledPreferredByIndex[i]
				local px, py = choosePortraitCenter(m.xPx, m.yPx, lastCenterX, preferred)
				if px and py then
					table.insert(placed, { x = px, y = py, r = portraitRadius })
					lastCenterX = px
					portraitCentersByIndex[i] = Vector2.new(px, py)
				end
			end

			-- Post-check validator: detect violations explicitly (never guess).
			type Violation = { kind: string, indexA: number, indexB: number?, detail: string }
			local violations: { Violation } = {}

			-- Ordering violations (slower not right of faster)
			for i = 2, #markers do
				local prev = portraitCentersByIndex[i - 1]
				local cur = portraitCentersByIndex[i]
				if prev and cur and cur.X < prev.X then
					table.insert(violations, {
						kind = "ordering",
						indexA = i - 1,
						indexB = i,
						detail = string.format("centerX[%d]=%.1f > centerX[%d]=%.1f", i - 1, prev.X, i, cur.X),
					})
				end
			end

			-- Unplaced portraits (no valid position found) are violations too.
			local unplacedCount = 0
			local unplacedUsers: { string } = {}
			for i = 1, #markers do
				if not portraitCentersByIndex[i] then
					unplacedCount = unplacedCount + 1
					if #unplacedUsers < 12 then
						table.insert(unplacedUsers, markers[i].point.username)
					end
				end
			end
			if unplacedCount > 0 then
				table.insert(violations, {
					kind = "unplaced",
					indexA = 0,
					detail = string.format("%d portraits could not be placed under constraints (%s)", unplacedCount, table.concat(unplacedUsers, ", ")),
				})
			end

			-- Bounds + step-line overlap violations
			for i = 1, #markers do
				local c = portraitCentersByIndex[i]
				if c then
					if not withinChartBounds(c.X, c.Y, portraitRadius) then
						table.insert(violations, { kind = "bounds", indexA = i, detail = "portrait out of chart bounds" })
					end
					if collidesWithStepLine(c.X, c.Y, portraitRadius) then
						table.insert(violations, { kind = "stepLine", indexA = i, detail = "portrait intersects WR line" })
					end
				end
			end

			-- Portrait-portrait overlap violations
			for i = 1, #markers do
				local a = portraitCentersByIndex[i]
				if a then
					for j = i + 1, #markers do
						local b = portraitCentersByIndex[j]
						if b then
							local dx = a.X - b.X
							local dy = a.Y - b.Y
							local minDist = (portraitRadius * 2) + portraitGap
							if (dx * dx + dy * dy) < (minDist * minDist) then
								table.insert(violations, {
									kind = "portraitOverlap",
									indexA = i,
									indexB = j,
									detail = string.format("distance=%.1f < min=%.1f", math.sqrt(dx * dx + dy * dy), minDist),
								})
							end
						end
					end
				end
			end

			-- If violations exist, log loudly and draw red rings on the offending portraits.
			if #violations > 0 then
				-- Throttle spam: only send when the count changes.
				if lastViolationCount == nil or lastViolationCount ~= #violations then
					lastViolationCount = #violations

					local countsByKind: { [string]: number } = {}
					for _, v in ipairs(violations) do
						countsByKind[v.kind] = (countsByKind[v.kind] or 0) + 1
					end

					local sample: { string } = {}
					for i = 1, math.min(#violations, 12) do
						local v = violations[i]
						table.insert(sample, string.format("%s:%s", v.kind, v.detail))
					end

					_annotate(string.format("WR chart layout violations: %d (%s)", #violations, raceTitle))
					annotater.Error(string.format("WR chart layout violations: %d (%s)", #violations, raceTitle), {
						userId = localPlayer.UserId,
						raceTitle = raceTitle,
						violationCount = #violations,
						countsByKind = countsByKind,
						sample = sample,
						chartSize = { x = width, y = height },
						portraitSizePx = portraitSizePx,
					})
				end

				local bad: { [number]: boolean } = {}
				for _, v in ipairs(violations) do
					bad[v.indexA] = true
					if v.indexB then
						bad[v.indexB] = true
					end
				end

				for idx, isBad in pairs(bad) do
					if isBad then
						local c = portraitCentersByIndex[idx]
						if c then
							local ring = Instance.new("Frame")
							ring.Name = "ViolationRing_" .. tostring(idx)
							ring.Size = UDim2.fromOffset((portraitRadius * 2) + 8, (portraitRadius * 2) + 8)
							ring.AnchorPoint = Vector2.new(0.5, 0.5)
							ring.Position = UDim2.fromOffset(c.X, c.Y)
							ring.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
							ring.BackgroundTransparency = 0.75
							ring.BorderSizePixel = 2
							ring.BorderColor3 = Color3.fromRGB(255, 0, 0)
							ring.ZIndex = 50
							ring.Parent = chartBg
							local ringCorner = Instance.new("UICorner")
							ringCorner.CornerRadius = UDim.new(0.5, 0)
							ringCorner.Parent = ring
						end
					end
				end
			end

			-- Render portraits using strict centers
			lastPortraitCentersByIndex = {}
			for i = 1, #markers do
				local m = markers[i]
				local center = portraitCentersByIndex[i]
				if center then
					local px = center.X
					local py = center.Y
					lastPortraitCentersByIndex[i] = Vector2.new(px, py)

					-- Connector: portrait edge -> marker edge (exact)
					local vecX = m.xPx - px
					local vecY = m.yPx - py
					local len = math.sqrt(vecX * vecX + vecY * vecY)
					if len < 1 then
						len = 1
					end
					local dirX = vecX / len
					local dirY = vecY / len

					local startX = px + (dirX * portraitRadius)
					local startY = py + (dirY * portraitRadius)
					local endX = m.xPx - (dirX * markerRadius)
					local endY = m.yPx - (dirY * markerRadius)
					local dx = endX - startX
					local dy = endY - startY
					local actualLen = math.max(math.sqrt(dx * dx + dy * dy), 1)
					local angleDeg = math.deg(math.atan2(dy, dx))
					local midX = (startX + endX) / 2
					local midY = (startY + endY) / 2

					local connectorLine = Instance.new("Frame")
					connectorLine.Name = "Connector_" .. tostring(i)
					connectorLine.Size = UDim2.fromOffset(actualLen, 2)
					connectorLine.AnchorPoint = Vector2.new(0.5, 0.5)
					connectorLine.Position = UDim2.fromOffset(midX, midY)
					connectorLine.Rotation = angleDeg
					connectorLine.BackgroundColor3 = m.borderColor
					connectorLine.BackgroundTransparency = 0.3
					connectorLine.BorderSizePixel = 0
					connectorLine.ZIndex = 5
					connectorLine.Parent = chartBg

					-- Border ring
					local borderRing = Instance.new("Frame")
					borderRing.Name = "BorderRing_" .. tostring(i)
					borderRing.Size = UDim2.fromOffset(portraitSizePx + 6, portraitSizePx + 6)
					borderRing.AnchorPoint = Vector2.new(0.5, 0.5)
					borderRing.Position = UDim2.fromOffset(px, py)
					borderRing.BackgroundColor3 = m.borderColor
					borderRing.BorderSizePixel = 0
					borderRing.ZIndex = 10 + i
					borderRing.Parent = chartBg
					local ringCorner = Instance.new("UICorner")
					ringCorner.CornerRadius = UDim.new(0.5, 0)
					ringCorner.Parent = borderRing

					-- Portrait
					local pointFrame = thumbnails.createAvatarPortraitPopup(m.point.userId, false, nil, 0)
					pointFrame.Name = "Point_" .. tostring(i)
					pointFrame.Size = UDim2.fromOffset(portraitSizePx, portraitSizePx)
					pointFrame.AnchorPoint = Vector2.new(0.5, 0.5)
					pointFrame.Position = UDim2.fromOffset(px, py)
					pointFrame.ZIndex = 11 + i
					pointFrame.Parent = chartBg
					makeCircular(pointFrame)

					local avatarImage = pointFrame:FindFirstChildOfClass("ImageLabel")
					if avatarImage then
						avatarImage.ZIndex = 12 + i
					end

					-- Username label below portrait (kept inside chart bounds)
					local usernameLabel = Instance.new("TextLabel")
					usernameLabel.Name = "Username_" .. tostring(i)
					usernameLabel.Size = UDim2.fromOffset(80, 16)
					usernameLabel.AnchorPoint = Vector2.new(0.5, 0)
					usernameLabel.Position = UDim2.fromOffset(px, math.min(py + (portraitSizePx / 2) + 2, height - 18))
					usernameLabel.BackgroundTransparency = 1
					usernameLabel.Text = m.point.username
					usernameLabel.TextColor3 = colors.white
					usernameLabel.FontFace = fonts.GetFont(false, true)
					usernameLabel.TextSize = 12
					usernameLabel.TextTruncate = Enum.TextTruncate.AtEnd
					usernameLabel.ZIndex = 12 + i
					usernameLabel.Parent = chartBg

					-- Tooltip on portrait
					thumbnails.connectPortraitMouseHandlers(pointFrame, function()
						showTooltipForPoint(m.point, container)
					end, hideTooltip)
				end
			end
		end

		lastChartSize = containerSize
	end

	-- Initial Draw
	drawChart(chartBg.AbsoluteSize)

	-- Handle Resize
	chartBg:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		drawChart(chartBg.AbsoluteSize)
	end)

	-- Bring modal to front when chart is clicked (standard window behavior)
	container.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			-- Find the outer frame (ancestor with name starting with "outer_")
			local current: Instance? = container.Parent
			while current do
				if current:IsA("Frame") and string.match(current.Name, "^outer_") then
					windowFunctions.BringFrameToFront(current :: Frame)
					break
				end
				current = current.Parent
			end
		end
	end)

	_annotate(string.format("Created scaled WR progression chart with %d points", #points))
	return container
end

_annotate("end")
return module

--[[ # WR Progression Chart Requirements

## Modal Behavior
1. **Resize handle**: Chart modal must have a resize handle for user adjustment
2. **Position/size persistence**: Save and restore position and size globally for all WR progression charts (single setting, not per-race)

## X-Axis (Time)
1. Extend from the **first time the race was run** (leftmost point)
2. Extend to **today's date** (rightmost edge), not just the last WR set
3. This shows the full timeline from race discovery to present

## Y-Axis (Race Time)
1. Bottom of chart: the **fastest run ever** (current WR), with slight padding above
2. Top of chart: the **slowest WR** in the progression, with slight padding
3. **Critical constraint**: The chart must NEVER show vertical space below 0.000 seconds
   - 0 seconds is the theoretical minimum race time
   - For races with very fast times (e.g., 0.001s), the bottom padding must not extend below zero
   - Example: If fastest time is 50s, bottom of chart might be ~42s; if fastest is 0.5s, bottom is clamped to 0

## Legend
1. Shows "Your WRs", "Race Discovery", "Other WRs" with color dots
2. **Text must be white** and clear (not blurry)
3. Ensure proper font rendering and contrast

## Data Points (WR Markers)
1. **Your WRs**: Highlighted in user color (yellow)
2. **Race Discovery**: First run ever, highlighted in green
3. **Other WRs**: Show the **avatar portrait** (circular face image) of the record holder
   - Small circular avatar at the point location

## Hover Tooltip
When hovering over any WR point, display an ephemeral tooltip card with:
1. **Avatar face** (circular portrait)
2. **Username** of the record holder
3. **Exact time** of the run (formatted with precision)
4. **Improvement** over the prior record (how much faster)
5. **Attempts by winner**: How many attempts this person made to beat the record
6. **Total attempts**: Total attempts by anyone since the prior record was set
7. **Time since prior record**: Duration the previous record stood before being broken

Layout: Beautiful **grid/table layout** with labels and values aligned

]]
