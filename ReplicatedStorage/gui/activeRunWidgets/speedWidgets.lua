--!strict
-- speedWidgets.lua (ReplicatedStorage/gui/activeRunWidgets/speedWidgets.lua)
-- Speed display widget implementations for current speed values.
-- Charts showing speed over time are in speedChartWidgets.lua.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local TweenService = game:GetService("TweenService")

local colors = require(game.ReplicatedStorage.util.colors)
local fonts = require(game.StarterPlayer.StarterPlayerScripts.guis.fonts)
local widgetTypes = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetTypes)
local widgetStyles = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetStyles)

local module = {}

-- Numeric speed display ("68.0 d/s") - transparent with stroked text
local function createNumericSpeed(): widgetTypes.Widget
	local speedLabel: TextLabel? = nil
	local cleanupFn: (() -> ())? = nil

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local result = widgetStyles.createTransparentLabel({
				name = "SpeedWidget_numeric",
				size = UDim2.fromOffset(120, 36),
				position = position,
				text = "0.0d/s",
				textColor = colors.yellow,
				fontSize = 24,
				fontMono = true,
				fontBold = true,
				xAlignment = Enum.TextXAlignment.Right,
			})
			result.frame.Parent = parent
			speedLabel = result.label
			cleanupFn = result.cleanup
			return result.frame
		end,

		Destroy = function()
			if cleanupFn then
				cleanupFn()
				cleanupFn = nil
			end
			speedLabel = nil
		end,

		OnRunStart = function()
			if speedLabel then
				speedLabel.Text = "0.0d/s"
			end
		end,

		UpdateSpeed = function(speed: number)
			if speedLabel then
				speedLabel.Text = string.format("%.1fd/s", speed)
			end
		end,
	})
end

-- Transparent large speed display - large text, no background
local function createTransparentLarge(): widgetTypes.Widget
	local speedLabel: TextLabel? = nil
	local cleanupFn: (() -> ())? = nil

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local result = widgetStyles.createTransparentLabel({
				name = "SpeedWidget_transparentLarge",
				size = UDim2.fromOffset(180, 50),
				position = position,
				text = "0.0d/s",
				textColor = colors.yellow,
				fontSize = 36,
				fontMono = true,
				fontBold = true,
				xAlignment = Enum.TextXAlignment.Right,
			})
			result.frame.Parent = parent
			speedLabel = result.label
			cleanupFn = result.cleanup
			return result.frame
		end,

		Destroy = function()
			if cleanupFn then
				cleanupFn()
				cleanupFn = nil
			end
			speedLabel = nil
		end,

		OnRunStart = function()
			if speedLabel then
				speedLabel.Text = "0.0d/s"
			end
		end,

		UpdateSpeed = function(speed: number)
			if speedLabel then
				speedLabel.Text = string.format("%.1fd/s", speed)
			end
		end,
	})
end

-- Transparent small speed display - compact text, no background
local function createTransparentSmall(): widgetTypes.Widget
	local speedLabel: TextLabel? = nil
	local cleanupFn: (() -> ())? = nil

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local result = widgetStyles.createTransparentLabel({
				name = "SpeedWidget_transparentSmall",
				size = UDim2.fromOffset(85, 26),
				position = position,
				text = "0.0d/s",
				textColor = colors.yellow,
				fontSize = 16,
				fontMono = true,
				fontBold = true,
				xAlignment = Enum.TextXAlignment.Right,
			})
			result.frame.Parent = parent
			speedLabel = result.label
			cleanupFn = result.cleanup
			return result.frame
		end,

		Destroy = function()
			if cleanupFn then
				cleanupFn()
				cleanupFn = nil
			end
			speedLabel = nil
		end,

		OnRunStart = function()
			if speedLabel then
				speedLabel.Text = "0.0d/s"
			end
		end,

		UpdateSpeed = function(speed: number)
			if speedLabel then
				speedLabel.Text = string.format("%.1fd/s", speed)
			end
		end,
	})
end

-- Black background small speed display - compact with dark background
local function createBlackSmall(): widgetTypes.Widget
	local speedLabel: TextLabel? = nil

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local frame = Instance.new("Frame")
			frame.Name = "SpeedWidget_blackSmall"
			frame.Position = position or UDim2.fromScale(0.5, 0.5)
			frame.Size = UDim2.fromOffset(85, 26)
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.BackgroundColor3 = colors.black
			frame.BackgroundTransparency = 0.2
			frame.BorderSizePixel = 1
			frame.BorderColor3 = colors.signColor
			frame.Parent = parent

			local label = Instance.new("TextLabel")
			label.Name = "SpeedLabel"
			label.Size = UDim2.fromScale(1, 1)
			label.Position = UDim2.fromScale(0, 0)
			label.BackgroundTransparency = 1
			label.TextColor3 = colors.yellow
			label.FontFace = fonts.GetFont(true, true)
			label.TextSize = 16
			label.Text = "0.0d/s"
			label.TextXAlignment = Enum.TextXAlignment.Right
			label.TextStrokeTransparency = 0.5
			label.TextStrokeColor3 = colors.black
			label.Parent = frame
			speedLabel = label

			return frame
		end,

		Destroy = function()
			speedLabel = nil
		end,

		OnRunStart = function()
			if speedLabel then
				speedLabel.Text = "0.0d/s"
			end
		end,

		UpdateSpeed = function(speed: number)
			if speedLabel then
				speedLabel.Text = string.format("%.1fd/s", speed)
			end
		end,
	})
end

-- Analog gauge speedometer with non-linear scale
-- Focused on the interesting speed range: 68-100 d/s
local function createAnalogGauge(): widgetTypes.Widget
	local container: Frame? = nil
	local needlePivot: Frame? = nil
	local speedLabel: TextLabel? = nil
	local accelLabel: TextLabel? = nil
	local currentTween: Tween? = nil

	-- Non-linear speed to angle mapping
	local function speedToAngle(speed: number): number
		local clampedSpeed = math.clamp(speed, 0, 100)
		local ZONE1_ARC = 32.4
		local ZONE2_ARC = 237.6

		if clampedSpeed <= 68 then
			local t = clampedSpeed / 68
			return -135 + t * ZONE1_ARC
		else
			local t = (clampedSpeed - 68) / 32
			return -135 + ZONE1_ARC + t * ZONE2_ARC
		end
	end

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local frame = Instance.new("Frame")
			frame.Name = "SpeedWidget_gauge"
			frame.Position = position or UDim2.fromScale(0.9, 0.75)
			frame.Size = UDim2.fromOffset(160, 160)
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.BackgroundColor3 = widgetStyles.containerBackground
			frame.BackgroundTransparency = 0.1
			frame.Parent = parent
			container = frame

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = frame

			local stroke = Instance.new("UIStroke")
			stroke.Color = colors.signColor
			stroke.Thickness = 3
			stroke.Parent = frame

			-- Major tick marks with labels
			local majorSpeeds: { { speed: number, isOptimal: boolean } } = {
				{ speed = 0, isOptimal = false },
				{ speed = 68, isOptimal = true },
				{ speed = 76, isOptimal = true },
				{ speed = 84, isOptimal = true },
				{ speed = 92, isOptimal = false },
				{ speed = 100, isOptimal = false },
			}

			for _, info in ipairs(majorSpeeds) do
				local speedVal = info.speed
				local angle = speedToAngle(speedVal)
				local rad = math.rad(angle - 90)
				local outerRadius = 0.44
				local labelRadius = 0.30

				local tick = Instance.new("Frame")
				tick.Size = UDim2.fromOffset(4, 16)
				tick.Position = UDim2.fromScale(0.5 + math.cos(rad) * outerRadius, 0.5 + math.sin(rad) * outerRadius)
				tick.AnchorPoint = Vector2.new(0.5, 0.5)
				tick.Rotation = angle
				local tickColor = if info.isOptimal then colors.lightGreen else colors.white
				if speedVal == 0 then
					tickColor = colors.defaultGrey
				end
				tick.BackgroundColor3 = tickColor
				tick.BorderSizePixel = 0
				tick.ZIndex = 2
				tick.Parent = frame

				local label = Instance.new("TextLabel")
				label.Size = UDim2.fromOffset(28, 14)
				label.Position = UDim2.fromScale(0.5 + math.cos(rad) * labelRadius, 0.5 + math.sin(rad) * labelRadius)
				label.AnchorPoint = Vector2.new(0.5, 0.5)
				label.BackgroundTransparency = 1
				label.TextColor3 = tickColor
				label.FontFace = fonts.GetFont(true, true)
				label.TextSize = 14
				label.Text = tostring(speedVal)
				label.ZIndex = 2
				label.Parent = frame
			end

			-- Minor tick marks in focus zone
			local minorSpeeds = { 70, 72, 74, 78, 80, 82, 86, 88, 90, 94, 96, 98 }
			for _, speedVal in ipairs(minorSpeeds) do
				local angle = speedToAngle(speedVal)
				local rad = math.rad(angle - 90)
				local outerRadius = 0.44

				local tick = Instance.new("Frame")
				tick.Size = UDim2.fromOffset(2, 10)
				tick.Position = UDim2.fromScale(0.5 + math.cos(rad) * outerRadius, 0.5 + math.sin(rad) * outerRadius)
				tick.AnchorPoint = Vector2.new(0.5, 0.5)
				tick.Rotation = angle
				tick.BackgroundColor3 = if speedVal <= 88 then colors.lightGreen else colors.defaultGrey
				tick.BorderSizePixel = 0
				tick.ZIndex = 2
				tick.Parent = frame
			end

			-- Green arc highlight for optimal zone
			local greenZoneStart = speedToAngle(68)
			local greenZoneEnd = speedToAngle(88)
			local arcSegments = 20
			local arcStep = (greenZoneEnd - greenZoneStart) / arcSegments
			for i = 0, arcSegments - 1 do
				local angle = greenZoneStart + i * arcStep + arcStep / 2
				local rad = math.rad(angle - 90)
				local arcRadius = 0.48

				local segment = Instance.new("Frame")
				segment.Size = UDim2.fromOffset(6, 4)
				segment.Position = UDim2.fromScale(0.5 + math.cos(rad) * arcRadius, 0.5 + math.sin(rad) * arcRadius)
				segment.AnchorPoint = Vector2.new(0.5, 0.5)
				segment.Rotation = angle
				segment.BackgroundColor3 = colors.lightGreen
				segment.BackgroundTransparency = 0.5
				segment.BorderSizePixel = 0
				segment.ZIndex = 1
				segment.Parent = frame
			end

			-- Needle pivot
			local pivot = Instance.new("Frame")
			pivot.Name = "NeedlePivot"
			pivot.Size = UDim2.fromOffset(4, 4)
			pivot.Position = UDim2.fromScale(0.5, 0.5)
			pivot.AnchorPoint = Vector2.new(0.5, 0.5)
			pivot.BackgroundTransparency = 1
			pivot.Rotation = -135
			pivot.ZIndex = 5
			pivot.Parent = frame
			needlePivot = pivot

			local shaft = Instance.new("Frame")
			shaft.Name = "Shaft"
			shaft.Size = UDim2.fromOffset(4, 55)
			shaft.Position = UDim2.fromOffset(0, -27)
			shaft.AnchorPoint = Vector2.new(0.5, 1)
			shaft.BackgroundColor3 = colors.signColor
			shaft.BorderSizePixel = 0
			shaft.ZIndex = 5
			shaft.Parent = pivot

			local arrowhead = Instance.new("Frame")
			arrowhead.Name = "Arrowhead"
			arrowhead.Size = UDim2.fromOffset(12, 12)
			arrowhead.Position = UDim2.fromOffset(0, -55)
			arrowhead.AnchorPoint = Vector2.new(0.5, 0.5)
			arrowhead.BackgroundColor3 = colors.signColor
			arrowhead.BorderSizePixel = 0
			arrowhead.Rotation = 45
			arrowhead.ZIndex = 5
			arrowhead.Parent = pivot

			local tail = Instance.new("Frame")
			tail.Name = "Tail"
			tail.Size = UDim2.fromOffset(6, 15)
			tail.Position = UDim2.fromOffset(0, 7)
			tail.AnchorPoint = Vector2.new(0.5, 0)
			tail.BackgroundColor3 = colors.signColor
			tail.BackgroundTransparency = 0.3
			tail.BorderSizePixel = 0
			tail.ZIndex = 4
			tail.Parent = pivot

			local cap = Instance.new("Frame")
			cap.Size = UDim2.fromOffset(20, 20)
			cap.Position = UDim2.fromScale(0.5, 0.5)
			cap.AnchorPoint = Vector2.new(0.5, 0.5)
			cap.BackgroundColor3 = colors.grey
			cap.BorderSizePixel = 0
			cap.ZIndex = 6
			cap.Parent = frame

			local capCorner = Instance.new("UICorner")
			capCorner.CornerRadius = UDim.new(0.5, 0)
			capCorner.Parent = cap

			local capHighlight = Instance.new("Frame")
			capHighlight.Size = UDim2.fromOffset(10, 10)
			capHighlight.Position = UDim2.fromScale(0.5, 0.5)
			capHighlight.AnchorPoint = Vector2.new(0.5, 0.5)
			capHighlight.BackgroundColor3 = colors.defaultGrey
			capHighlight.BorderSizePixel = 0
			capHighlight.ZIndex = 7
			capHighlight.Parent = cap

			local highlightCorner = Instance.new("UICorner")
			highlightCorner.CornerRadius = UDim.new(0.5, 0)
			highlightCorner.Parent = capHighlight

			local speedText = Instance.new("TextLabel")
			speedText.Size = UDim2.fromOffset(80, 26)
			speedText.Position = UDim2.fromScale(0.5, 0.72)
			speedText.AnchorPoint = Vector2.new(0.5, 0.5)
			speedText.BackgroundTransparency = 1
			speedText.TextColor3 = colors.meColor
			speedText.FontFace = fonts.GetFont(true, true)
			speedText.TextSize = 22
			speedText.Text = "0.0"
			speedText.TextStrokeTransparency = 0.3
			speedText.TextStrokeColor3 = colors.black
			speedText.ZIndex = 3
			speedText.Parent = frame
			speedLabel = speedText

			local unit = Instance.new("TextLabel")
			unit.Size = UDim2.fromOffset(40, 14)
			unit.Position = UDim2.fromScale(0.5, 0.86)
			unit.AnchorPoint = Vector2.new(0.5, 0.5)
			unit.BackgroundTransparency = 1
			unit.TextColor3 = colors.defaultGrey
			unit.FontFace = fonts.GetFont(false, true)
			unit.TextSize = 14
			unit.Text = "d/s"
			unit.ZIndex = 3
			unit.Parent = frame

			local accel = Instance.new("TextLabel")
			accel.Name = "AccelLabel"
			accel.Size = UDim2.fromOffset(70, 12)
			accel.Position = UDim2.fromScale(0.5, 0.95)
			accel.AnchorPoint = Vector2.new(0.5, 0.5)
			accel.BackgroundTransparency = 1
			accel.TextColor3 = Color3.fromRGB(100, 180, 255)
			accel.FontFace = fonts.GetFont(true, false)
			accel.TextSize = 10
			accel.Text = ""
			accel.TextTransparency = 1
			accel.TextStrokeTransparency = 0.5
			accel.TextStrokeColor3 = colors.black
			accel.ZIndex = 3
			accel.Parent = frame
			accelLabel = accel

			return frame
		end,

		Destroy = function()
			if currentTween then
				currentTween:Cancel()
				currentTween = nil
			end
			if container then
				container:Destroy()
				container = nil
			end
			needlePivot = nil
			speedLabel = nil
			accelLabel = nil
		end,

		OnRunStart = function()
			if needlePivot then
				if currentTween then
					currentTween:Cancel()
				end
				needlePivot.Rotation = -135
			end
			if speedLabel then
				speedLabel.Text = "0.0"
			end
		end,

		UpdateSpeed = function(speed: number)
			if needlePivot then
				local targetRotation = speedToAngle(speed)
				if currentTween then
					currentTween:Cancel()
				end
				local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				local newTween = TweenService:Create(needlePivot, tweenInfo, { Rotation = targetRotation })
				currentTween = newTween
				newTween:Play()
			end
			if speedLabel then
				speedLabel.Text = string.format("%.1f", speed)
			end
		end,

		UpdateAcceleration = function(rate: number)
			if not accelLabel then
				return
			end
			if math.abs(rate) < 0.01 then
				accelLabel.Text = ""
				accelLabel.TextTransparency = 1
				return
			end
			local signPrefix = if rate > 0 then "+" else ""
			accelLabel.Text = string.format("%s%.2fd/s²", signPrefix, rate)
			accelLabel.TextTransparency = 0

			local intensity = math.clamp((math.abs(rate) - 0.01) / 0.6, 0.3, 1.0)
			if rate > 0 then
				local r = math.floor(100 * (1 - intensity * 0.5))
				local g = math.floor(180 + 75 * intensity)
				accelLabel.TextColor3 = Color3.fromRGB(r, g, 255)
			else
				local r = math.floor(200 + 55 * intensity)
				local g = math.floor(100 * (1 - intensity * 0.5))
				local b = math.floor(200 + 55 * intensity)
				accelLabel.TextColor3 = Color3.fromRGB(r, g, b)
			end
		end,
	})
end

-- Horizontal bar speed indicator (good for bottom of screen)
-- Non-linear scale: compresses 0-68, expands 68-100 (focus zone)
local function createHorizontalBar(): widgetTypes.Widget
	local container: Frame? = nil
	local barBackground: Frame? = nil
	local fillFrame: Frame? = nil
	local gainFillFrame: Frame? = nil
	local speedLabel: TextLabel? = nil
	local tickElements: { Instance } = {}
	local resizeCleanup: (() -> ())? = nil
	local speedHistory: { { speed: number, time: number } } = {}

	local GAIN_INTERVAL = 0.5
	local MAX_SPEED = 100
	local SLOW_ZONE = 50
	local GOOD_ZONE = 68
	local GREAT_ZONE = 88
	local MIN_WIDTH = 180
	local MAX_WIDTH = 800
	local MIN_HEIGHT = 32
	local MAX_HEIGHT = 120
	local TICK_LABEL_HEIGHT = 20
	local SPEED_LABEL_WIDTH = 95
	local ZONE1_WIDTH_PERCENT = 0.20
	local ZONE2_WIDTH_PERCENT = 0.80

	local barWidth: number = 320
	local barHeight: number = 40

	local function speedToPosition(speed: number): number
		local clampedSpeed = math.clamp(speed, 0, MAX_SPEED)
		if clampedSpeed <= GOOD_ZONE then
			return (clampedSpeed / GOOD_ZONE) * ZONE1_WIDTH_PERCENT
		else
			local t = (clampedSpeed - GOOD_ZONE) / (MAX_SPEED - GOOD_ZONE)
			return ZONE1_WIDTH_PERCENT + t * ZONE2_WIDTH_PERCENT
		end
	end

	local function recreateTickMarks()
		local barBg = barBackground
		local cont = container
		if not barBg or not cont then
			return
		end

		for _, el in ipairs(tickElements) do
			el:Destroy()
		end
		tickElements = {}

		local barAreaWidth = barWidth - SPEED_LABEL_WIDTH
		local showMinorTicks = barWidth >= 350
		local showLabels = barWidth >= 220

		for speedVal = 0, 100 do
			local xPos = speedToPosition(speedVal)
			local isMajor = (speedVal == 0 or speedVal == 68 or speedVal == 100)
			local isMultOf5 = (speedVal % 5 == 0)
			local isInFocusZone = (speedVal >= 68)

			if not isMajor and not isMultOf5 then
				if not showMinorTicks or not isInFocusZone then
					continue
				end
			end

			if speedVal > 0 and speedVal < 68 and not isMajor then
				if barWidth < 400 then
					continue
				end
			end

			local tickHeight: number
			local tickWidth: number
			local tickColor: Color3
			local tickTransparency: number
			local labelColor: Color3

			if isMajor then
				tickHeight = math.clamp(barHeight * 0.35, 10, 18)
				tickWidth = 2
				tickColor = if speedVal == 68 or speedVal == 100 then colors.meColor else colors.white
				labelColor = tickColor
				tickTransparency = 0
			elseif isMultOf5 and isInFocusZone then
				tickHeight = math.clamp(barHeight * 0.25, 6, 12)
				tickWidth = 2
				tickColor = colors.lightGreen
				labelColor = colors.white
				tickTransparency = 0.5
			elseif isMultOf5 then
				tickHeight = math.clamp(barHeight * 0.25, 6, 12)
				tickWidth = 2
				tickColor = colors.defaultGrey
				labelColor = colors.defaultGrey
				tickTransparency = 0.3
			else
				tickHeight = math.clamp(barHeight * 0.15, 4, 8)
				tickWidth = 1
				tickColor = colors.defaultGrey
				labelColor = colors.defaultGrey
				tickTransparency = 0.6
			end

			local tick = Instance.new("Frame")
			tick.Name = "Tick" .. speedVal
			tick.Size = UDim2.fromOffset(tickWidth, tickHeight)
			tick.Position = UDim2.fromScale(xPos, 0)
			tick.AnchorPoint = Vector2.new(0.5, 1)
			tick.BackgroundColor3 = tickColor
			tick.BackgroundTransparency = tickTransparency
			tick.BorderSizePixel = 0
			tick.ZIndex = 5
			tick.Parent = barBg
			table.insert(tickElements, tick)

			local showLabel = showLabels and (isMajor or (isMultOf5 and speedVal >= 68 and barWidth >= 300))
			if speedVal == 100 and barWidth < 400 then
				showLabel = false
			end

			if showLabel then
				local lbl = Instance.new("TextLabel")
				lbl.Name = "TickLabel" .. speedVal
				lbl.Size = UDim2.fromOffset(32, TICK_LABEL_HEIGHT)
				lbl.Position = UDim2.fromOffset(SPEED_LABEL_WIDTH + xPos * barAreaWidth, barHeight + 2)
				lbl.AnchorPoint = Vector2.new(0.5, 0)
				lbl.BackgroundTransparency = 1
				lbl.TextColor3 = labelColor
				lbl.FontFace = fonts.GetFont(true, isMajor)
				lbl.TextSize = if isMajor then math.clamp(barHeight * 0.4, 14, 18) else math.clamp(barHeight * 0.32, 10, 14)
				lbl.Text = tostring(speedVal)
				lbl.TextStrokeTransparency = 0.4
				lbl.TextStrokeColor3 = colors.black
				lbl.ZIndex = 5
				lbl.Parent = cont
				table.insert(tickElements, lbl)
			end
		end
	end

	local function updateLayout()
		local cont = container
		local barBg = barBackground
		local label = speedLabel
		if not cont or not barBg then
			return
		end

		cont.Size = UDim2.fromOffset(barWidth, barHeight + TICK_LABEL_HEIGHT + 4)
		barBg.Size = UDim2.fromOffset(barWidth - SPEED_LABEL_WIDTH, barHeight)
		barBg.Position = UDim2.fromOffset(SPEED_LABEL_WIDTH, 0)

		local fontSize = math.clamp(barHeight * 0.55, 18, 32)
		if label then
			label.Size = UDim2.fromOffset(SPEED_LABEL_WIDTH - 4, barHeight)
			label.TextSize = fontSize
		end

		recreateTickMarks()
	end

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?, context: widgetTypes.WidgetCreateContext?): Frame?
			if context and context.savedSize then
				barWidth = context.savedSize.width
				barHeight = context.savedSize.height - TICK_LABEL_HEIGHT - 4
			end

			local frame = Instance.new("Frame")
			frame.Name = "SpeedWidget_hbar"
			frame.Position = position or UDim2.fromScale(0.5, 0.92)
			frame.Size = UDim2.fromOffset(barWidth, barHeight + TICK_LABEL_HEIGHT + 4)
			frame.AnchorPoint = Vector2.new(0.5, 0)
			frame.BackgroundColor3 = colors.black
			frame.BackgroundTransparency = 0.05
			frame.BorderSizePixel = 1
			frame.BorderColor3 = colors.signColor
			frame.Parent = parent
			container = frame

			local fontSize = math.clamp(barHeight * 0.55, 18, 32)

			local label = Instance.new("TextLabel")
			label.Name = "SpeedLabel"
			label.Size = UDim2.fromOffset(SPEED_LABEL_WIDTH - 4, barHeight)
			label.Position = UDim2.fromOffset(4, 0)
			label.AnchorPoint = Vector2.new(0, 0)
			label.BackgroundTransparency = 1
			label.TextColor3 = colors.meColor
			label.FontFace = fonts.GetFont(true, true)
			label.TextSize = fontSize
			label.TextXAlignment = Enum.TextXAlignment.Center
			label.Text = "0.0d/s"
			label.TextStrokeTransparency = 0.3
			label.TextStrokeColor3 = colors.black
			label.ZIndex = 6
			label.Parent = frame
			speedLabel = label

			local barBg = Instance.new("Frame")
			barBg.Name = "BarBackground"
			barBg.Size = UDim2.fromOffset(barWidth - SPEED_LABEL_WIDTH, barHeight)
			barBg.Position = UDim2.fromOffset(SPEED_LABEL_WIDTH, 0)
			barBg.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
			barBg.BackgroundTransparency = 0
			barBg.BorderSizePixel = 1
			barBg.BorderColor3 = colors.defaultGrey
			barBg.ClipsDescendants = true
			barBg.Parent = frame
			barBackground = barBg

			local marker68 = Instance.new("Frame")
			marker68.Name = "Marker68"
			marker68.Size = UDim2.new(0, 2, 1, 0)
			marker68.Position = UDim2.fromScale(speedToPosition(GOOD_ZONE), 0)
			marker68.BackgroundColor3 = colors.lightGreen
			marker68.BackgroundTransparency = 0.3
			marker68.BorderSizePixel = 0
			marker68.ZIndex = 3
			marker68.Parent = barBg

			local marker88 = Instance.new("Frame")
			marker88.Name = "Marker88"
			marker88.Size = UDim2.new(0, 2, 1, 0)
			marker88.Position = UDim2.fromScale(speedToPosition(GREAT_ZONE), 0)
			marker88.BackgroundColor3 = colors.meColor
			marker88.BackgroundTransparency = 0.3
			marker88.BorderSizePixel = 0
			marker88.ZIndex = 3
			marker88.Parent = barBg

			local fill = Instance.new("Frame")
			fill.Name = "Fill"
			fill.Size = UDim2.fromScale(0, 1)
			fill.Position = UDim2.fromScale(0, 0)
			fill.BackgroundColor3 = widgetStyles.textColors.speed
			fill.BorderSizePixel = 0
			fill.ZIndex = 2
			fill.Parent = barBg
			fillFrame = fill

			local gainFill = Instance.new("Frame")
			gainFill.Name = "GainFill"
			gainFill.Size = UDim2.fromScale(0, 1)
			gainFill.Position = UDim2.fromScale(0, 0)
			gainFill.BackgroundColor3 = colors.darkGreen
			gainFill.BorderSizePixel = 0
			gainFill.ZIndex = 3
			gainFill.Parent = barBg
			gainFillFrame = gainFill

			local initialW = if context and context.savedSize then context.savedSize.width else nil
			local initialH = if context and context.savedSize then context.savedSize.height else nil
			local _, cleanup = widgetStyles.createResizeHandle({
				parent = frame,
				minWidth = MIN_WIDTH,
				maxWidth = MAX_WIDTH,
				minHeight = MIN_HEIGHT,
				maxHeight = MAX_HEIGHT,
				initialWidth = initialW,
				initialHeight = initialH,
				onSizeChanged = function(newWidth: number, newHeight: number)
					barWidth = newWidth
					barHeight = newHeight - TICK_LABEL_HEIGHT - 4
					updateLayout()
				end,
				onResizeEnd = if context and context.onSaveSize then context.onSaveSize else nil,
			})
			resizeCleanup = cleanup

			recreateTickMarks()

			return frame
		end,

		Destroy = function()
			if resizeCleanup then
				resizeCleanup()
				resizeCleanup = nil
			end
			if container then
				container:Destroy()
				container = nil
			end
			barBackground = nil
			fillFrame = nil
			gainFillFrame = nil
			speedLabel = nil
			tickElements = {}
			speedHistory = {}
		end,

		OnRunStart = function()
			if fillFrame then
				fillFrame.Size = UDim2.fromScale(0, 1)
			end
			if gainFillFrame then
				gainFillFrame.Size = UDim2.fromScale(0, 1)
			end
			if speedLabel then
				speedLabel.Text = "0.0d/s"
			end
			speedHistory = {}
		end,

		UpdateSpeed = function(speed: number)
			local now = tick()

			table.insert(speedHistory, { speed = speed, time = now })
			while #speedHistory > 0 and (now - speedHistory[1].time) > GAIN_INTERVAL do
				table.remove(speedHistory, 1)
			end

			local speedGain = 0
			if #speedHistory > 1 then
				speedGain = math.max(0, speed - speedHistory[1].speed)
			end

			if fillFrame then
				local pct = speedToPosition(speed)
				TweenService:Create(fillFrame, TweenInfo.new(0.1), { Size = UDim2.fromScale(pct, 1) }):Play()

				if speed >= GREAT_ZONE then
					fillFrame.BackgroundColor3 = colors.meColor
				elseif speed >= GOOD_ZONE then
					fillFrame.BackgroundColor3 = colors.lightGreen
				elseif speed >= SLOW_ZONE then
					fillFrame.BackgroundColor3 = colors.blueDone
				else
					fillFrame.BackgroundColor3 = colors.defaultGrey
				end
			end

			if gainFillFrame and speedGain > 0 then
				local basePct = speedToPosition(speed - speedGain)
				local gainPct = speedToPosition(speed) - basePct

				if speed >= GOOD_ZONE then
					gainFillFrame.Position = UDim2.fromScale(basePct, 0)
					TweenService:Create(gainFillFrame, TweenInfo.new(0.1), { Size = UDim2.fromScale(gainPct, 1) }):Play()
					gainFillFrame.Visible = true
				else
					gainFillFrame.Visible = false
				end
			elseif gainFillFrame then
				gainFillFrame.Visible = false
			end

			if speedLabel then
				speedLabel.Text = string.format("%.1f", speed)
			end
		end,
	})
end

-- Register all speed widgets
function module.Register(composer: { RegisterWidget: (string, string, () -> any) -> () })
	local category = widgetTypes.CATEGORIES.SPEED
	composer.RegisterWidget(category, widgetTypes.SPEED_STYLES.NUMERIC, createNumericSpeed)
	composer.RegisterWidget(category, widgetTypes.SPEED_STYLES.SPEED_TRANSPARENT_LARGE, createTransparentLarge)
	composer.RegisterWidget(category, widgetTypes.SPEED_STYLES.SPEED_TRANSPARENT_SMALL, createTransparentSmall)
	composer.RegisterWidget(category, widgetTypes.SPEED_STYLES.SPEED_BLACK_SMALL, createBlackSmall)
	composer.RegisterWidget(category, widgetTypes.SPEED_STYLES.ANALOG_GAUGE, createAnalogGauge)
	composer.RegisterWidget(category, widgetTypes.SPEED_STYLES.HORIZONTAL_BAR, createHorizontalBar)
	_annotate("Registered speed widgets")
end

_annotate("end")
return module
