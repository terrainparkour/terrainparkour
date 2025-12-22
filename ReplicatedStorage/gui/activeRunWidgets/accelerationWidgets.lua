--!strict
-- accelerationWidgets.lua (ReplicatedStorage/gui/activeRunWidgets/accelerationWidgets.lua)
-- Acceleration display widget implementations.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local colors = require(game.ReplicatedStorage.util.colors)
local fonts = require(game.StarterPlayer.StarterPlayerScripts.guis.fonts)
local widgetTypes = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetTypes)
local widgetStyles = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetStyles)

local module = {}

local ACCEL_THRESHOLD = 1.0

-- Color bar acceleration indicator
local function createColorBar(): widgetTypes.Widget
	local fillFrame: Frame? = nil
	local smoothedAccel: number = 0

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local frame = Instance.new("Frame")
			frame.Name = "AccelWidget_colorBar"
			frame.Position = position or UDim2.fromScale(0.95, 0.5)
			frame.Size = UDim2.fromOffset(8, 80)
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.BackgroundColor3 = widgetStyles.containerBackground
			frame.BorderSizePixel = 0
			frame.Parent = parent

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 4)
			corner.Parent = frame

			local fill = Instance.new("Frame")
			fill.Name = "Fill"
			fill.Size = UDim2.fromScale(1, 0)
			fill.Position = UDim2.fromScale(0, 0.5)
			fill.AnchorPoint = Vector2.new(0, 0.5)
			fill.BackgroundColor3 = colors.grey
			fill.BorderSizePixel = 0
			fill.Parent = frame
			fillFrame = fill

			local fillCorner = Instance.new("UICorner")
			fillCorner.CornerRadius = UDim.new(0, 4)
			fillCorner.Parent = fill

			local center = Instance.new("Frame")
			center.Size = UDim2.fromScale(1, 0)
			center.Position = UDim2.fromScale(0, 0.5)
			center.AnchorPoint = Vector2.new(0, 0.5)
			center.BackgroundColor3 = colors.grey
			center.BorderSizePixel = 0

			local centerStroke = Instance.new("UIStroke")
			centerStroke.Thickness = 1
			centerStroke.Parent = center
			center.Parent = frame

			return frame
		end,

		Destroy = function()
			fillFrame = nil
		end,

		OnRunStart = function()
			smoothedAccel = 0
			if fillFrame then
				fillFrame.Size = UDim2.fromScale(1, 0)
				fillFrame.BackgroundColor3 = colors.grey
			end
		end,

		OnRunEnd = function()
			smoothedAccel = 0
		end,

		UpdateAcceleration = function(rate: number)
			smoothedAccel = smoothedAccel + (rate - smoothedAccel) * 0.2

			if fillFrame then
				local intensity = math.clamp(math.abs(smoothedAccel) / 20, 0, 0.5)

				if smoothedAccel > ACCEL_THRESHOLD then
					fillFrame.Position = UDim2.fromScale(0, 0.5 - intensity)
					fillFrame.Size = UDim2.fromScale(1, intensity)
					fillFrame.AnchorPoint = Vector2.new(0, 0)
					fillFrame.BackgroundColor3 = colors.lightGreen
				elseif smoothedAccel < -ACCEL_THRESHOLD then
					fillFrame.Position = UDim2.fromScale(0, 0.5)
					fillFrame.Size = UDim2.fromScale(1, intensity)
					fillFrame.AnchorPoint = Vector2.new(0, 0)
					fillFrame.BackgroundColor3 = colors.lightRed
				else
					fillFrame.Size = UDim2.fromScale(1, 0.02)
					fillFrame.Position = UDim2.fromScale(0, 0.5)
					fillFrame.AnchorPoint = Vector2.new(0, 0.5)
					fillFrame.BackgroundColor3 = colors.grey
				end
			end
		end,
	})
end

-- Momentum panel
local function createMomentumPanel(): widgetTypes.Widget
	local container: Frame? = nil
	local velocityArrow: Frame? = nil
	local accelArrow: Frame? = nil
	local speedLabel: TextLabel? = nil
	local accelLabel: TextLabel? = nil
	local vertLabel: TextLabel? = nil
	local momentumRing: Frame? = nil

	local maxSpeed: number = 100
	local facingDegrees: number = 0

	local CANVAS_SIZE = 80
	local SPEED_COLOR = colors.yellow
	local ACCEL_COLOR = Color3.fromRGB(100, 180, 255)
	local ACCEL_POSITIVE = colors.lightGreen
	local ACCEL_NEGATIVE = colors.lightRed

	local function createArrow(parent: Frame, color: Color3): Frame
		local arrow = Instance.new("Frame")
		arrow.Size = UDim2.fromOffset(0, 3)
		arrow.Position = UDim2.fromScale(0.5, 0.5)
		arrow.AnchorPoint = Vector2.new(0, 0.5)
		arrow.BackgroundColor3 = color
		arrow.BorderSizePixel = 0
		arrow.Rotation = 0
		arrow.Parent = parent

		local head = Instance.new("Frame")
		head.Name = "Head"
		head.Size = UDim2.fromOffset(6, 6)
		head.Position = UDim2.fromScale(1, 0.5)
		head.AnchorPoint = Vector2.new(0.5, 0.5)
		head.Rotation = 45
		head.BackgroundColor3 = color
		head.BorderSizePixel = 0
		head.Parent = arrow

		return arrow
	end

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local frame = Instance.new("Frame")
			frame.Name = "AccelWidget_momentum"
			frame.Size = UDim2.fromOffset(CANVAS_SIZE + 90, CANVAS_SIZE + widgetStyles.TITLE_BAR_HEIGHT + 4)

			if position then
				frame.Position = position
				frame.AnchorPoint = Vector2.new(0.5, 0.5)
			end

			frame.BackgroundColor3 = widgetStyles.containerBackground
			frame.BackgroundTransparency = 0.1
			frame.BorderSizePixel = widgetStyles.containerBorderSize
			frame.BorderColor3 = widgetStyles.containerBorderColor
			frame.Parent = parent
			container = frame

			widgetStyles.createTitleBar(frame, "Acceleration")

			local canvas = Instance.new("Frame")
			canvas.Name = "VectorCanvas"
			canvas.Size = UDim2.fromOffset(CANVAS_SIZE, CANVAS_SIZE)
			canvas.Position = UDim2.fromOffset(6, widgetStyles.TITLE_BAR_HEIGHT + 2)
			canvas.BackgroundColor3 = Color3.fromRGB(25, 28, 32)
			canvas.BorderSizePixel = 0
			canvas.ClipsDescendants = true
			canvas.Parent = frame

			local canvasCorner = Instance.new("UICorner")
			canvasCorner.CornerRadius = UDim.new(0.5, 0)
			canvasCorner.Parent = canvas

			local hLine = Instance.new("Frame")
			hLine.Size = UDim2.new(1, 0, 0, 1)
			hLine.Position = UDim2.fromScale(0, 0.5)
			hLine.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
			hLine.BorderSizePixel = 0
			hLine.Parent = canvas

			local vLine = Instance.new("Frame")
			vLine.Size = UDim2.new(0, 1, 1, 0)
			vLine.Position = UDim2.fromScale(0.5, 0)
			vLine.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
			vLine.BorderSizePixel = 0
			vLine.Parent = canvas

			local ring = Instance.new("Frame")
			ring.Name = "MomentumRing"
			ring.Size = UDim2.fromOffset(CANVAS_SIZE + 6, CANVAS_SIZE + 6)
			ring.Position = UDim2.fromOffset(3, widgetStyles.TITLE_BAR_HEIGHT - 1)
			ring.BackgroundTransparency = 1
			ring.Parent = frame
			momentumRing = ring

			local ringStroke = Instance.new("UIStroke")
			ringStroke.Color = colors.signColor
			ringStroke.Thickness = 2
			ringStroke.Transparency = 0.5
			ringStroke.Parent = ring

			local ringCorner = Instance.new("UICorner")
			ringCorner.CornerRadius = UDim.new(0.5, 0)
			ringCorner.Parent = ring

			velocityArrow = createArrow(canvas, SPEED_COLOR)
			velocityArrow.Name = "VelocityArrow"

			accelArrow = createArrow(canvas, ACCEL_POSITIVE)
			accelArrow.Name = "AccelArrow"
			local head = accelArrow:FindFirstChild("Head")
			if head and head:IsA("Frame") then
				head.Size = UDim2.fromOffset(5, 5)
			end

			local valuesX = CANVAS_SIZE + 12
			local valuesY = widgetStyles.TITLE_BAR_HEIGHT + 4
			local valGap = 22

			local speedLbl = Instance.new("TextLabel")
			speedLbl.Size = UDim2.fromOffset(75, 18)
			speedLbl.Position = UDim2.fromOffset(valuesX, valuesY)
			speedLbl.BackgroundTransparency = 1
			speedLbl.TextColor3 = SPEED_COLOR
			speedLbl.FontFace = fonts.GetFont(true, true)
			speedLbl.TextSize = 16
			speedLbl.TextXAlignment = Enum.TextXAlignment.Left
			speedLbl.Text = "0.0 d/s"
			speedLbl.Parent = frame
			speedLabel = speedLbl

			local accLbl = Instance.new("TextLabel")
			accLbl.Size = UDim2.fromOffset(75, 18)
			accLbl.Position = UDim2.fromOffset(valuesX, valuesY + valGap)
			accLbl.BackgroundTransparency = 1
			accLbl.TextColor3 = ACCEL_COLOR
			accLbl.FontFace = fonts.GetFont(true, false)
			accLbl.TextSize = 14
			accLbl.TextXAlignment = Enum.TextXAlignment.Left
			accLbl.Text = "Accel: 0"
			accLbl.Parent = frame
			accelLabel = accLbl

			local vrtLbl = Instance.new("TextLabel")
			vrtLbl.Size = UDim2.fromOffset(75, 18)
			vrtLbl.Position = UDim2.fromOffset(valuesX, valuesY + valGap * 2)
			vrtLbl.BackgroundTransparency = 1
			vrtLbl.TextColor3 = colors.defaultGrey
			vrtLbl.FontFace = fonts.GetFont(true, false)
			vrtLbl.TextSize = 14
			vrtLbl.TextXAlignment = Enum.TextXAlignment.Left
			vrtLbl.Text = "Vertical: —"
			vrtLbl.Parent = frame
			vertLabel = vrtLbl

			return frame
		end,

		Destroy = function()
			if container then
				container:Destroy()
				container = nil
			end
			velocityArrow = nil
			accelArrow = nil
			speedLabel = nil
			accelLabel = nil
			vertLabel = nil
			momentumRing = nil
		end,

		OnRunStart = function()
			maxSpeed = 100
		end,

		UpdateSpeed = function(speed: number)
			if speed > maxSpeed then
				maxSpeed = speed
			end

			if speedLabel then
				speedLabel.Text = string.format("%.1f d/s", speed)
			end

			if velocityArrow then
				local length = math.clamp(speed / 2, 5, CANVAS_SIZE / 2 - 5)
				velocityArrow.Rotation = facingDegrees - 90
				velocityArrow.Size = UDim2.fromOffset(length, 3)
			end

			if momentumRing then
				local stroke = momentumRing:FindFirstChildOfClass("UIStroke")
				if stroke then
					local speedPct = if maxSpeed > 0 then speed / maxSpeed else 0
					stroke.Thickness = 2 + speedPct * 3
					stroke.Transparency = 0.7 - speedPct * 0.4
				end
			end
		end,

		UpdateAcceleration = function(rate: number)
			if accelLabel then
				local displayRate = if math.abs(rate) < 0.1 then 0 else rate
				accelLabel.Text = string.format("Accel: %.1f", displayRate)
				accelLabel.TextColor3 = ACCEL_COLOR
			end

			local arrow = accelArrow
			if arrow then
				if math.abs(rate) > 2 then
					local length = math.clamp(math.abs(rate), 5, 20)
					local baseAngle = facingDegrees - 90
					arrow.Rotation = if rate >= 0 then baseAngle else baseAngle + 180
					arrow.Size = UDim2.fromOffset(length, 2)
					arrow.BackgroundColor3 = if rate >= 0 then ACCEL_POSITIVE else ACCEL_NEGATIVE
					local head = arrow:FindFirstChild("Head")
					if head and head:IsA("Frame") then
						head.BackgroundColor3 = arrow.BackgroundColor3
					end
				else
					arrow.Size = UDim2.fromOffset(0, 2)
				end
			end
		end,

		UpdateAltitude = function(_altitude: number, vVel: number)
			if vertLabel then
				local vertDir = if vVel > 1 then "↑" elseif vVel < -1 then "↓" else "―"
				vertLabel.Text = string.format("Vertical: %s%.0f", vertDir, math.abs(vVel))
			end
		end,

		UpdateFacing = function(degrees: number)
			facingDegrees = degrees
		end,
	})
end

-- Register all acceleration widgets
function module.Register(composer: { RegisterWidget: (string, string, () -> any) -> () })
	local category = widgetTypes.CATEGORIES.ACCELERATION
	composer.RegisterWidget(category, widgetTypes.ACCELERATION_STYLES.COLOR_BAR, createColorBar)
	composer.RegisterWidget(category, widgetTypes.ACCELERATION_STYLES.MOMENTUM_PANEL, createMomentumPanel)
	_annotate("Registered acceleration widgets")
end

_annotate("end")
return module
