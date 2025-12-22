--!strict
-- timerWidgets.lua (ReplicatedStorage/gui/activeRunWidgets/timerWidgets.lua)
-- Timer display widget implementations with click-to-cancel functionality.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local colors = require(game.ReplicatedStorage.util.colors)
local fonts = require(game.StarterPlayer.StarterPlayerScripts.guis.fonts)
local widgetTypes = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetTypes)
local widgetStyles = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetStyles)
local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local aet = require(game.ReplicatedStorage.avatarEventTypes)
local terrainData = require(game.ReplicatedStorage.gui.activeRunWidgets.terrainData)

local fireEvent = avatarEventFiring.FireEvent

local module = {}

-- Click vs drag threshold in pixels
local CLICK_THRESHOLD = 8

-- Timer style configuration
type TimerConfig = {
	style: string,
	size: UDim2,
	textSize: number,
	textColor: Color3,
	isTransparent: boolean,
	hasBackground: boolean,
	backgroundColor: Color3?,
	backgroundTransparency: number?,
}

-- Helper to wire click-to-cancel on a frame
local function wireClickToCancel(frame: Frame): () -> ()
	local clickStartPos: Vector2? = nil
	local wasDrag: boolean = false
	local connections: { RBXScriptConnection } = {}

	table.insert(
		connections,
		frame.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				clickStartPos = Vector2.new(input.Position.X, input.Position.Y)
				wasDrag = false
			end
		end)
	)

	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				if clickStartPos then
					local currentPos = Vector2.new(input.Position.X, input.Position.Y)
					if (currentPos - clickStartPos).Magnitude >= CLICK_THRESHOLD then
						wasDrag = true
					end
				end
			end
		end)
	)

	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				local startPos = clickStartPos
				local dragOccurred = wasDrag
				clickStartPos = nil
				wasDrag = false

				if not startPos then
					return
				end

				if not dragOccurred then
					local endPos = Vector2.new(input.Position.X, input.Position.Y)
					if (endPos - startPos).Magnitude < CLICK_THRESHOLD then
						local details: aet.avatarEventDetails = {
							reason = "clicked on timer widget",
							sender = "timerWidgets",
						}
						fireEvent(aet.avatarEventTypes.RUN_CANCEL, details)
					end
				end
			end
		end)
	)

	return function()
		for _, conn in ipairs(connections) do
			conn:Disconnect()
		end
	end
end

-- Base timer widget with common functionality
-- Timer-specific visibility: hidden when no run is happening, visible during runs.
local function createBaseTimer(config: TimerConfig): widgetTypes.Widget
	local container: Frame? = nil
	local timerLabel: TextLabel? = nil
	local startTick: number = 0
	local renderConn: RBXScriptConnection? = nil
	local visible: boolean = true
	local hoverBorderCleanup: (() -> ())? = nil
	local clickCancelCleanup: (() -> ())? = nil

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local frame = Instance.new("Frame")
			frame.Name = "TimerWidget_" .. config.style
			frame.Size = config.size
			frame.Visible = false -- Hidden until run starts

			if config.hasBackground then
				frame.BackgroundColor3 = config.backgroundColor or colors.black
				frame.BackgroundTransparency = config.backgroundTransparency or 0.25
				frame.BorderSizePixel = 1
				frame.BorderColor3 = colors.black
			else
				frame.BackgroundTransparency = 1
			end

			if position then
				frame.Position = position
				frame.AnchorPoint = Vector2.new(0.5, 0.5)
			end

			frame.Parent = parent
			container = frame

			if config.isTransparent then
				hoverBorderCleanup = widgetStyles.addHoverBorder(frame)
			end

			local label = Instance.new("TextLabel")
			label.Name = "TimerLabel"
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.TextColor3 = config.textColor
			label.FontFace = fonts.GetFont(true, true)
			label.TextSize = config.textSize
			label.TextStrokeTransparency = 0.3
			label.TextStrokeColor3 = colors.black
			label.TextXAlignment = Enum.TextXAlignment.Right
			label.Text = ""
			label.Parent = frame
			timerLabel = label

			clickCancelCleanup = wireClickToCancel(frame)

			return frame
		end,

		Destroy = function()
			if clickCancelCleanup then
				clickCancelCleanup()
				clickCancelCleanup = nil
			end
			if hoverBorderCleanup then
				hoverBorderCleanup()
				hoverBorderCleanup = nil
			end
			if renderConn then
				renderConn:Disconnect()
				renderConn = nil
			end
			if container then
				container:Destroy()
				container = nil
			end
			timerLabel = nil
		end,

		SetVisible = function(vis: boolean)
			visible = vis
			if container then
				container.Visible = vis and startTick > 0
			end
		end,

		IsVisible = function(): boolean
			return visible
		end,

		OnRunStart = function(runStartTick: number)
			startTick = runStartTick
			if container and visible then
				container.Visible = true
			end

			if renderConn then
				renderConn:Disconnect()
			end

			renderConn = RunService.RenderStepped:Connect(function()
				if timerLabel and startTick > 0 then
					timerLabel.Text = string.format("%.2fs", tick() - startTick)
				end
			end)
		end,

		OnRunEnd = function()
			if renderConn then
				renderConn:Disconnect()
				renderConn = nil
			end
			if container then
				container.Visible = false
			end
			startTick = 0
		end,
	})
end

-- Transparent Large Timer
local function createTransparentLargeTimer(): widgetTypes.Widget
	return createBaseTimer({
		style = "transparent-large",
		size = UDim2.fromOffset(200, 60),
		textSize = 42,
		textColor = colors.yellow,
		isTransparent = true,
		hasBackground = false,
	})
end

-- Transparent Small Timer
local function createTransparentSmallTimer(): widgetTypes.Widget
	return createBaseTimer({
		style = "transparent-small",
		size = UDim2.fromOffset(100, 30),
		textSize = 24,
		textColor = colors.yellow,
		isTransparent = true,
		hasBackground = false,
	})
end

-- Black Background Large Timer
local function createBlackBackgroundLargeTimer(): widgetTypes.Widget
	return createBaseTimer({
		style = "black-background-large",
		size = UDim2.fromOffset(200, 60),
		textSize = 42,
		textColor = colors.yellow,
		isTransparent = false,
		hasBackground = true,
		backgroundColor = colors.black,
		backgroundTransparency = 0.25,
	})
end

-- Transparent Very Large Timer
local function createTransparentVeryLargeTimer(): widgetTypes.Widget
	return createBaseTimer({
		style = "transparent-very-large",
		size = UDim2.fromOffset(300, 90),
		textSize = 64,
		textColor = colors.yellow,
		isTransparent = true,
		hasBackground = false,
	})
end

--------------------------------------------------------------------------------
-- CONDENSER TIMER
--------------------------------------------------------------------------------

local CONDENSER_HEIGHT = 50
local CONDENSER_BRICK_SIZE = 12
local CONDENSER_STICK_WIDTH = 8
local CONDENSER_STICK_HEIGHT = 30
local CONDENSER_BAR_WIDTH = 14
local CONDENSER_BAR_HEIGHT = 36
local CONDENSER_MINUTE_SIZE = 32
local CONDENSER_SPACING = 2
local CONDENSER_TIME_WIDTH = 100
local CONDENSER_GAP = 4

local CONDENSER_COLORS = {
	brick = Color3.fromRGB(255, 200, 100),
	stick = Color3.fromRGB(255, 140, 60),
	bar = Color3.fromRGB(60, 180, 180),
	minute = Color3.fromRGB(200, 40, 40),
}

local function createCondenserTimer(): widgetTypes.Widget
	local container: Frame? = nil
	local condenserContainer: Frame? = nil
	local timeLabel: TextLabel? = nil
	local incomingBrick: Frame? = nil
	local startTick: number = 0
	local renderConn: RBXScriptConnection? = nil
	local visible: boolean = true
	local clickCancelCleanup: (() -> ())? = nil
	local hoverBorderCleanup: (() -> ())? = nil

	local brickFrames: { Frame } = {}
	local stickFrames: { Frame } = {}
	local barFrames: { Frame } = {}
	local minuteFrames: { Frame } = {}
	local lastWholeSecond: number = -1
	local lastIncomingXOffset: number = 0

	local function clearVisuals()
		for _, f in ipairs(brickFrames) do
			f:Destroy()
		end
		for _, f in ipairs(stickFrames) do
			f:Destroy()
		end
		for _, f in ipairs(barFrames) do
			f:Destroy()
		end
		for _, f in ipairs(minuteFrames) do
			f:Destroy()
		end
		brickFrames = {}
		stickFrames = {}
		barFrames = {}
		minuteFrames = {}
		lastWholeSecond = -1
		lastIncomingXOffset = 0
	end

	local function rebuildSolidElements(wholeSeconds: number): number
		local condenser = condenserContainer
		if not condenser then
			return 0
		end

		for _, f in ipairs(brickFrames) do
			f:Destroy()
		end
		for _, f in ipairs(stickFrames) do
			f:Destroy()
		end
		for _, f in ipairs(barFrames) do
			f:Destroy()
		end
		for _, f in ipairs(minuteFrames) do
			f:Destroy()
		end
		brickFrames = {}
		stickFrames = {}
		barFrames = {}
		minuteFrames = {}

		local minutes = math.floor(wholeSeconds / 60)
		local remainingAfterMinutes = wholeSeconds % 60
		local bars = math.floor(remainingAfterMinutes / 20)
		local remainingAfterBars = remainingAfterMinutes % 20
		local sticks = math.floor(remainingAfterBars / 5)
		local looseBricks = remainingAfterBars % 5

		local xOffset = 2
		local yCenter = CONDENSER_HEIGHT / 2

		for i = 1, minutes do
			local minuteFrame = Instance.new("Frame")
			minuteFrame.Name = "Minute_" .. i
			minuteFrame.Size = UDim2.fromOffset(CONDENSER_MINUTE_SIZE, CONDENSER_MINUTE_SIZE)
			minuteFrame.Position = UDim2.fromOffset(xOffset, yCenter - CONDENSER_MINUTE_SIZE / 2)
			minuteFrame.BackgroundColor3 = CONDENSER_COLORS.minute
			minuteFrame.BorderSizePixel = 1
			minuteFrame.BorderColor3 = colors.black
			minuteFrame.Parent = condenser
			table.insert(minuteFrames, minuteFrame)
			xOffset = xOffset + CONDENSER_MINUTE_SIZE + CONDENSER_SPACING + 1
		end

		for i = 1, bars do
			local barFrame = Instance.new("Frame")
			barFrame.Name = "Bar_" .. i
			barFrame.Size = UDim2.fromOffset(CONDENSER_BAR_WIDTH, CONDENSER_BAR_HEIGHT)
			barFrame.Position = UDim2.fromOffset(xOffset, yCenter - CONDENSER_BAR_HEIGHT / 2)
			barFrame.BackgroundColor3 = CONDENSER_COLORS.bar
			barFrame.BorderSizePixel = 1
			barFrame.BorderColor3 = colors.black
			barFrame.Parent = condenser
			table.insert(barFrames, barFrame)
			xOffset = xOffset + CONDENSER_BAR_WIDTH + CONDENSER_SPACING
		end

		for i = 1, sticks do
			local stickFrame = Instance.new("Frame")
			stickFrame.Name = "Stick_" .. i
			stickFrame.Size = UDim2.fromOffset(CONDENSER_STICK_WIDTH, CONDENSER_STICK_HEIGHT)
			stickFrame.Position = UDim2.fromOffset(xOffset, yCenter - CONDENSER_STICK_HEIGHT / 2)
			stickFrame.BackgroundColor3 = CONDENSER_COLORS.stick
			stickFrame.BorderSizePixel = 1
			stickFrame.BorderColor3 = colors.black
			stickFrame.Parent = condenser
			table.insert(stickFrames, stickFrame)
			xOffset = xOffset + CONDENSER_STICK_WIDTH + CONDENSER_SPACING
		end

		for i = 1, looseBricks do
			local brickFrame = Instance.new("Frame")
			brickFrame.Name = "Brick_" .. i
			brickFrame.Size = UDim2.fromOffset(CONDENSER_BRICK_SIZE, CONDENSER_BRICK_SIZE)
			brickFrame.Position = UDim2.fromOffset(xOffset, yCenter - CONDENSER_BRICK_SIZE / 2)
			brickFrame.BackgroundColor3 = CONDENSER_COLORS.brick
			brickFrame.BorderSizePixel = 1
			brickFrame.BorderColor3 = colors.black
			brickFrame.Parent = condenser
			table.insert(brickFrames, brickFrame)
			xOffset = xOffset + CONDENSER_BRICK_SIZE + CONDENSER_SPACING
		end

		return xOffset
	end

	local function updateVisuals(elapsed: number)
		local condenser = condenserContainer
		local incoming = incomingBrick
		if not condenser or not incoming then
			return
		end

		local wholeSeconds = math.floor(elapsed)
		local fraction = elapsed - wholeSeconds

		if wholeSeconds ~= lastWholeSecond then
			lastWholeSecond = wholeSeconds
			lastIncomingXOffset = rebuildSolidElements(wholeSeconds)
		end

		local yCenter = CONDENSER_HEIGHT / 2
		incoming.Position = UDim2.fromOffset(lastIncomingXOffset, yCenter - CONDENSER_BRICK_SIZE / 2)
		incoming.BackgroundTransparency = 1 - fraction
		incoming.Visible = true
	end

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local frame = Instance.new("Frame")
			frame.Name = "TimerWidget_condenser"
			frame.Size = UDim2.fromOffset(320, CONDENSER_HEIGHT)
			frame.BackgroundTransparency = 1
			frame.BorderSizePixel = 0
			frame.Visible = false

			if position then
				frame.Position = position
				frame.AnchorPoint = Vector2.new(0.5, 0.5)
			end

			frame.Parent = parent
			container = frame

			hoverBorderCleanup = widgetStyles.addHoverBorder(frame)

			local label = Instance.new("TextLabel")
			label.Name = "TimeLabel"
			label.Size = UDim2.fromOffset(CONDENSER_TIME_WIDTH, CONDENSER_HEIGHT)
			label.Position = UDim2.fromOffset(0, 0)
			label.BackgroundTransparency = 1
			label.TextColor3 = colors.yellow
			label.FontFace = fonts.GetFont(true, true)
			label.TextSize = 48
			label.TextStrokeTransparency = 0.2
			label.TextStrokeColor3 = colors.black
			label.TextXAlignment = Enum.TextXAlignment.Right
			label.TextYAlignment = Enum.TextYAlignment.Center
			label.Text = ""
			label.Parent = frame
			timeLabel = label

			local condenserStart = CONDENSER_TIME_WIDTH + CONDENSER_GAP
			local condenser = Instance.new("Frame")
			condenser.Name = "CondenserContainer"
			condenser.Size = UDim2.new(1, -condenserStart, 1, 0)
			condenser.Position = UDim2.fromOffset(condenserStart, 0)
			condenser.BackgroundTransparency = 1
			condenser.ClipsDescendants = true
			condenser.Parent = frame
			condenserContainer = condenser

			local incoming = Instance.new("Frame")
			incoming.Name = "IncomingBrick"
			incoming.Size = UDim2.fromOffset(CONDENSER_BRICK_SIZE, CONDENSER_BRICK_SIZE)
			incoming.BackgroundColor3 = CONDENSER_COLORS.brick
			incoming.BorderSizePixel = 1
			incoming.BorderColor3 = colors.black
			incoming.BackgroundTransparency = 1
			incoming.Visible = false
			incoming.Parent = condenser
			incomingBrick = incoming

			clickCancelCleanup = wireClickToCancel(frame)

			return frame
		end,

		Destroy = function()
			clearVisuals()
			if incomingBrick then
				incomingBrick:Destroy()
				incomingBrick = nil
			end
			if clickCancelCleanup then
				clickCancelCleanup()
				clickCancelCleanup = nil
			end
			if hoverBorderCleanup then
				hoverBorderCleanup()
				hoverBorderCleanup = nil
			end
			if renderConn then
				renderConn:Disconnect()
				renderConn = nil
			end
			if container then
				container:Destroy()
				container = nil
			end
			condenserContainer = nil
			timeLabel = nil
		end,

		SetVisible = function(vis: boolean)
			visible = vis
			if container then
				container.Visible = vis and startTick > 0
			end
		end,

		IsVisible = function(): boolean
			return visible
		end,

		OnRunStart = function(runStartTick: number)
			startTick = runStartTick
			clearVisuals()
			if incomingBrick then
				incomingBrick.BackgroundTransparency = 1
				incomingBrick.Visible = false
			end

			if container and visible then
				container.Visible = true
			end

			if renderConn then
				renderConn:Disconnect()
			end

			renderConn = RunService.RenderStepped:Connect(function()
				if startTick > 0 then
					local elapsed = tick() - startTick
					if timeLabel then
						timeLabel.Text = string.format("%.2fs", elapsed)
					end
					updateVisuals(elapsed)
				end
			end)
		end,

		OnRunEnd = function()
			if renderConn then
				renderConn:Disconnect()
				renderConn = nil
			end
			clearVisuals()
			if incomingBrick then
				incomingBrick.Visible = false
			end
			if container then
				container.Visible = false
			end
			startTick = 0
		end,
	})
end

--------------------------------------------------------------------------------
-- STRATA TIMER
--------------------------------------------------------------------------------

local STRATA_ROW_HEIGHT = 1
local STRATA_UPDATE_INTERVAL = 0.2
local STRATA_TIME_HEIGHT = 45
local STRATA_WIDTH = 65
local STRATA_DEFAULT_COLOR = Color3.fromRGB(80, 80, 80)

local function createStrataTimer(): widgetTypes.Widget
	local container: Frame? = nil
	local strataContainer: Frame? = nil
	local timeLabel: TextLabel? = nil
	local startTick: number = 0
	local renderConn: RBXScriptConnection? = nil
	local visible: boolean = true
	local clickCancelCleanup: (() -> ())? = nil
	local hoverBorderCleanup: (() -> ())? = nil

	local currentTerrain: string = ""
	local strataRows: { Frame } = {}
	local lastRowTime: number = 0

	local function clearStrata()
		for _, row in ipairs(strataRows) do
			row:Destroy()
		end
		strataRows = {}
		lastRowTime = 0
	end

	local function addTerrainRow()
		local strata = strataContainer
		if not strata then
			return
		end

		local terrainColor = STRATA_DEFAULT_COLOR
		if currentTerrain ~= "" then
			terrainColor = terrainData.GetTerrainColor(currentTerrain)
		end

		for _, row in ipairs(strataRows) do
			local currentPos = row.Position
			row.Position = UDim2.fromOffset(currentPos.X.Offset, currentPos.Y.Offset + STRATA_ROW_HEIGHT)
		end

		local newRow = Instance.new("Frame")
		newRow.Name = "StrataRow_" .. #strataRows + 1
		newRow.Size = UDim2.new(1, 0, 0, STRATA_ROW_HEIGHT)
		newRow.Position = UDim2.fromOffset(0, 0)
		newRow.BackgroundColor3 = terrainColor
		newRow.BackgroundTransparency = 0.3
		newRow.BorderSizePixel = 0
		newRow.Parent = strata
		table.insert(strataRows, 1, newRow)
	end

	local function updateStrata(elapsed: number)
		local rowsSinceStart = math.floor(elapsed / STRATA_UPDATE_INTERVAL)
		local rowsToAdd = rowsSinceStart - math.floor(lastRowTime / STRATA_UPDATE_INTERVAL)

		for _ = 1, math.min(rowsToAdd, 3) do
			addTerrainRow()
		end

		lastRowTime = elapsed

		if timeLabel then
			timeLabel.Text = string.format("%.2fs", elapsed)
		end
	end

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local frame = Instance.new("Frame")
			frame.Name = "TimerWidget_strata"
			frame.Size = UDim2.fromOffset(STRATA_WIDTH, 100)
			frame.BackgroundTransparency = 1
			frame.BorderSizePixel = 0
			frame.Visible = false
			frame.ClipsDescendants = false

			if position then
				frame.Position = position
				frame.AnchorPoint = Vector2.new(0.5, 0.5)
			end

			frame.Parent = parent
			container = frame

			hoverBorderCleanup = widgetStyles.addHoverBorder(frame)

			local label = Instance.new("TextLabel")
			label.Name = "TimeLabel"
			label.Size = UDim2.new(1, 0, 0, STRATA_TIME_HEIGHT)
			label.Position = UDim2.fromOffset(0, 0)
			label.BackgroundTransparency = 1
			label.TextColor3 = colors.yellow
			label.FontFace = fonts.GetFont(true, true)
			label.TextSize = 42
			label.TextStrokeTransparency = 0
			label.TextStrokeColor3 = colors.black
			label.TextXAlignment = Enum.TextXAlignment.Right
			label.TextYAlignment = Enum.TextYAlignment.Center
			label.Text = ""
			label.ZIndex = 10
			label.Parent = frame
			timeLabel = label

			local strata = Instance.new("Frame")
			strata.Name = "StrataContainer"
			strata.Size = UDim2.new(1, 0, 1, -STRATA_TIME_HEIGHT)
			strata.Position = UDim2.fromOffset(0, STRATA_TIME_HEIGHT)
			strata.BackgroundTransparency = 1
			strata.BorderSizePixel = 0
			strata.ClipsDescendants = false
			strata.Parent = frame
			strataContainer = strata

			clickCancelCleanup = wireClickToCancel(frame)

			return frame
		end,

		Destroy = function()
			clearStrata()
			if clickCancelCleanup then
				clickCancelCleanup()
				clickCancelCleanup = nil
			end
			if hoverBorderCleanup then
				hoverBorderCleanup()
				hoverBorderCleanup = nil
			end
			if renderConn then
				renderConn:Disconnect()
				renderConn = nil
			end
			if container then
				container:Destroy()
				container = nil
			end
			strataContainer = nil
			timeLabel = nil
			currentTerrain = ""
		end,

		SetVisible = function(vis: boolean)
			visible = vis
			if container then
				container.Visible = vis and startTick > 0
			end
		end,

		IsVisible = function(): boolean
			return visible
		end,

		OnRunStart = function(runStartTick: number)
			startTick = runStartTick
			currentTerrain = ""
			clearStrata()

			if container and visible then
				container.Visible = true
			end

			if renderConn then
				renderConn:Disconnect()
			end

			renderConn = RunService.RenderStepped:Connect(function()
				if startTick > 0 then
					updateStrata(tick() - startTick)
				end
			end)
		end,

		OnRunEnd = function()
			if renderConn then
				renderConn:Disconnect()
				renderConn = nil
			end
			clearStrata()
			if container then
				container.Visible = false
			end
			startTick = 0
			currentTerrain = ""
		end,

		UpdateTerrain = function(terrainName: string)
			currentTerrain = terrainName
		end,
	})
end

-- Register all timer widgets
function module.Register(composer: { RegisterWidget: (string, string, () -> any) -> () })
	local category = widgetTypes.CATEGORIES.TIMER
	composer.RegisterWidget(category, widgetTypes.TIMER_STYLES.TRANSPARENT_LARGE, createTransparentLargeTimer)
	composer.RegisterWidget(category, widgetTypes.TIMER_STYLES.TRANSPARENT_SMALL, createTransparentSmallTimer)
	composer.RegisterWidget(category, widgetTypes.TIMER_STYLES.BLACK_BACKGROUND_LARGE, createBlackBackgroundLargeTimer)
	composer.RegisterWidget(category, widgetTypes.TIMER_STYLES.TRANSPARENT_VERY_LARGE, createTransparentVeryLargeTimer)
	composer.RegisterWidget(category, widgetTypes.TIMER_STYLES.CONDENSER, createCondenserTimer)
	composer.RegisterWidget(category, widgetTypes.TIMER_STYLES.STRATA, createStrataTimer)
	_annotate("Registered timer widgets")
end

_annotate("end")
return module
