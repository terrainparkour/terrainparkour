--!strict
-- compassWidgets.lua (ReplicatedStorage/gui/activeRunWidgets/compassWidgets.lua)
-- Compass display widgets showing movement direction and/or camera facing.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local colors = require(game.ReplicatedStorage.util.colors)
local fonts = require(game.StarterPlayer.StarterPlayerScripts.guis.fonts)
local widgetTypes = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetTypes)
local widgetStyles = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetStyles)

local localPlayer = Players.LocalPlayer

local module = {}

local MAP_BG_COLOR = Color3.fromRGB(20, 25, 32)
local MOVEMENT_COLOR = colors.lightGreen
local CAMERA_COLOR = colors.blueDone

local function yRotationToCompassBearing(yRotDegrees: number): number
	local bearing = -yRotDegrees
	while bearing < 0 do
		bearing = bearing + 360
	end
	while bearing >= 360 do
		bearing = bearing - 360
	end
	return bearing
end

local function degreesToCardinal(compassBearing: number): string
	local normalized = compassBearing % 360
	if normalized < 22.5 or normalized >= 337.5 then
		return "N"
	elseif normalized < 67.5 then
		return "NE"
	elseif normalized < 112.5 then
		return "E"
	elseif normalized < 157.5 then
		return "SE"
	elseif normalized < 202.5 then
		return "S"
	elseif normalized < 247.5 then
		return "SW"
	elseif normalized < 292.5 then
		return "W"
	else
		return "NW"
	end
end

local function createNeedle(parent: Frame, color: Color3, zBase: number): Frame
	local pivot = Instance.new("Frame")
	pivot.Name = "NeedlePivot"
	pivot.Size = UDim2.fromOffset(4, 4)
	pivot.Position = UDim2.fromScale(0.5, 0.5)
	pivot.AnchorPoint = Vector2.new(0.5, 0.5)
	pivot.BackgroundTransparency = 1
	pivot.Rotation = 0
	pivot.ZIndex = zBase
	pivot.Parent = parent

	local needle = Instance.new("Frame")
	needle.Size = UDim2.fromOffset(4, 28)
	needle.Position = UDim2.fromOffset(0, -14)
	needle.AnchorPoint = Vector2.new(0.5, 1)
	needle.BackgroundColor3 = color
	needle.BorderSizePixel = 0
	needle.ZIndex = zBase
	needle.Parent = pivot

	local arrowhead = Instance.new("Frame")
	arrowhead.Size = UDim2.fromOffset(10, 10)
	arrowhead.Position = UDim2.fromOffset(0, -28)
	arrowhead.AnchorPoint = Vector2.new(0.5, 0.5)
	arrowhead.BackgroundColor3 = color
	arrowhead.BorderSizePixel = 0
	arrowhead.Rotation = 45
	arrowhead.ZIndex = zBase
	arrowhead.Parent = pivot

	local tail = Instance.new("Frame")
	tail.Size = UDim2.fromOffset(3, 12)
	tail.Position = UDim2.fromOffset(0, 6)
	tail.AnchorPoint = Vector2.new(0.5, 0)
	tail.BackgroundColor3 = color
	tail.BackgroundTransparency = 0.5
	tail.BorderSizePixel = 0
	tail.ZIndex = zBase - 1
	tail.Parent = pivot

	return pivot
end

local function createCompassBase(frame: Frame): (Frame, TextLabel)
	local hasTitleBar = frame:FindFirstChild("TitleBar") ~= nil
	local topOffset = if hasTitleBar then widgetStyles.TITLE_BAR_HEIGHT + 5 else 5

	local compassBg = Instance.new("Frame")
	compassBg.Name = "CompassBg"
	compassBg.Size = UDim2.fromOffset(80, 80)
	compassBg.Position = UDim2.new(0.5, 0, 0, topOffset)
	compassBg.AnchorPoint = Vector2.new(0.5, 0)
	compassBg.BackgroundColor3 = MAP_BG_COLOR
	compassBg.BorderSizePixel = 0
	compassBg.Parent = frame

	local compassCorner = Instance.new("UICorner")
	compassCorner.CornerRadius = UDim.new(0.5, 0)
	compassCorner.Parent = compassBg

	local compassStroke = Instance.new("UIStroke")
	compassStroke.Color = colors.signColor
	compassStroke.Thickness = 2
	compassStroke.Parent = compassBg

	local cardinals: { { dir: string, angle: number } } = {
		{ dir = "N", angle = 0 },
		{ dir = "E", angle = 90 },
		{ dir = "S", angle = 180 },
		{ dir = "W", angle = 270 },
	}
	for _, cardinal in ipairs(cardinals) do
		local rad = math.rad(cardinal.angle - 90)
		local radius = 0.38
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromOffset(16, 14)
		label.Position = UDim2.fromScale(0.5 + math.cos(rad) * radius, 0.5 + math.sin(rad) * radius)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.BackgroundTransparency = 1
		label.TextColor3 = if cardinal.dir == "N" then colors.signColor else colors.white
		label.FontFace = fonts.GetFont(false, true)
		label.TextSize = 14
		label.Text = cardinal.dir
		label.ZIndex = 2
		label.Parent = compassBg
	end

	local center = Instance.new("Frame")
	center.Size = UDim2.fromOffset(10, 10)
	center.Position = UDim2.fromScale(0.5, 0.5)
	center.AnchorPoint = Vector2.new(0.5, 0.5)
	center.BackgroundColor3 = colors.grey
	center.BorderSizePixel = 0
	center.ZIndex = 10
	center.Parent = compassBg

	local centerCorner = Instance.new("UICorner")
	centerCorner.CornerRadius = UDim.new(0.5, 0)
	centerCorner.Parent = center

	local dirLabel = Instance.new("TextLabel")
	dirLabel.Name = "DirectionLabel"
	dirLabel.Size = UDim2.new(1, 0, 0, 16)
	dirLabel.Position = UDim2.new(0, 0, 1, -16)
	dirLabel.BackgroundTransparency = 1
	dirLabel.TextColor3 = colors.meColor
	dirLabel.FontFace = fonts.GetFont(true, true)
	dirLabel.TextSize = 16
	dirLabel.Text = "N"
	dirLabel.ZIndex = 2
	dirLabel.Parent = frame

	return compassBg, dirLabel
end

local function getCameraFacing(): number
	local camera = workspace.CurrentCamera
	if camera then
		local _, yRot, _ = camera.CFrame:ToOrientation()
		return math.deg(yRot)
	end
	return 0
end

local function getMovementDirection(): number?
	local character = localPlayer.Character
	if not character then
		return nil
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return nil
	end
	local velocity = hrp.AssemblyLinearVelocity
	local horizontalVel = Vector3.new(velocity.X, 0, velocity.Z)
	if horizontalVel.Magnitude < 2 then
		return nil
	end
	return math.deg(math.atan2(horizontalVel.X, horizontalVel.Z))
end

-- Movement direction compass
local function createMovementCompass(): widgetTypes.Widget
	local needlePivot: Frame? = nil
	local compassLabel: TextLabel? = nil
	local renderConn: RBXScriptConnection? = nil

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local frame = Instance.new("Frame")
			frame.Name = "CompassWidget_movement"
			frame.Size = UDim2.fromOffset(90, 100)

			if position then
				frame.Position = position
				frame.AnchorPoint = Vector2.new(0.5, 0.5)
			end

			frame.BackgroundColor3 = widgetStyles.containerBackground
			frame.BackgroundTransparency = 0.1
			frame.BorderSizePixel = widgetStyles.containerBorderSize
			frame.BorderColor3 = widgetStyles.containerBorderColor
			frame.Parent = parent

			local compass: Frame
			compass, compassLabel = createCompassBase(frame)
			needlePivot = createNeedle(compass, MOVEMENT_COLOR, 5)

			local typeLabel = Instance.new("TextLabel")
			typeLabel.Size = UDim2.fromOffset(30, 12)
			typeLabel.Position = UDim2.fromOffset(4, 4)
			typeLabel.BackgroundTransparency = 1
			typeLabel.TextColor3 = MOVEMENT_COLOR
			typeLabel.FontFace = fonts.GetFont(false, true)
			typeLabel.TextSize = 10
			typeLabel.Text = "MOV"
			typeLabel.TextXAlignment = Enum.TextXAlignment.Left
			typeLabel.Parent = frame

			return frame
		end,

		Destroy = function()
			if renderConn then
				renderConn:Disconnect()
				renderConn = nil
			end
			needlePivot = nil
			compassLabel = nil
		end,

		OnRunStart = function()
			if needlePivot then
				needlePivot.Rotation = 0
			end
			if renderConn then
				renderConn:Disconnect()
			end
			renderConn = RunService.RenderStepped:Connect(function()
				local movDir = getMovementDirection()
				if movDir then
					local bearing = yRotationToCompassBearing(movDir)
					if needlePivot then
						needlePivot.Rotation = bearing
					end
					if compassLabel then
						compassLabel.Text = degreesToCardinal(bearing)
					end
				end
			end)
		end,

		OnRunEnd = function()
			if renderConn then
				renderConn:Disconnect()
				renderConn = nil
			end
		end,
	})
end

-- Camera facing compass
local function createCameraCompass(): widgetTypes.Widget
	local needlePivot: Frame? = nil
	local compassLabel: TextLabel? = nil
	local renderConn: RBXScriptConnection? = nil

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local frame = Instance.new("Frame")
			frame.Name = "CompassWidget_camera"
			frame.Size = UDim2.fromOffset(90, 100)

			if position then
				frame.Position = position
				frame.AnchorPoint = Vector2.new(0.5, 0.5)
			end

			frame.BackgroundColor3 = widgetStyles.containerBackground
			frame.BackgroundTransparency = 0.1
			frame.BorderSizePixel = widgetStyles.containerBorderSize
			frame.BorderColor3 = widgetStyles.containerBorderColor
			frame.Parent = parent

			local compass: Frame
			compass, compassLabel = createCompassBase(frame)
			needlePivot = createNeedle(compass, CAMERA_COLOR, 5)

			local typeLabel = Instance.new("TextLabel")
			typeLabel.Size = UDim2.fromOffset(30, 12)
			typeLabel.Position = UDim2.fromOffset(4, 4)
			typeLabel.BackgroundTransparency = 1
			typeLabel.TextColor3 = CAMERA_COLOR
			typeLabel.FontFace = fonts.GetFont(false, true)
			typeLabel.TextSize = 10
			typeLabel.Text = "CAM"
			typeLabel.TextXAlignment = Enum.TextXAlignment.Left
			typeLabel.Parent = frame

			return frame
		end,

		Destroy = function()
			if renderConn then
				renderConn:Disconnect()
				renderConn = nil
			end
			needlePivot = nil
			compassLabel = nil
		end,

		OnRunStart = function()
			if needlePivot then
				needlePivot.Rotation = 0
			end
			if renderConn then
				renderConn:Disconnect()
			end
			renderConn = RunService.RenderStepped:Connect(function()
				local camDir = getCameraFacing()
				local bearing = yRotationToCompassBearing(camDir)
				if needlePivot then
					needlePivot.Rotation = bearing
				end
				if compassLabel then
					compassLabel.Text = degreesToCardinal(bearing)
				end
			end)
		end,

		OnRunEnd = function()
			if renderConn then
				renderConn:Disconnect()
				renderConn = nil
			end
		end,
	})
end

-- Both compasses
local function createBothCompasses(): widgetTypes.Widget
	local movNeedle: Frame? = nil
	local camNeedle: Frame? = nil
	local compassLabel: TextLabel? = nil
	local renderConn: RBXScriptConnection? = nil

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local frame = Instance.new("Frame")
			frame.Name = "CompassWidget_both"
			frame.Size = UDim2.fromOffset(100, 140)

			if position then
				frame.Position = position
				frame.AnchorPoint = Vector2.new(0.5, 0.5)
			end

			frame.BackgroundColor3 = widgetStyles.containerBackground
			frame.BackgroundTransparency = 0.1
			frame.BorderSizePixel = widgetStyles.containerBorderSize
			frame.BorderColor3 = widgetStyles.containerBorderColor
			frame.Parent = parent

			widgetStyles.createTitleBar(frame, "Compass")

			local compassBgFrame: Frame
			compassBgFrame, compassLabel = createCompassBase(frame)

			movNeedle = createNeedle(compassBgFrame, MOVEMENT_COLOR, 5)
			camNeedle = createNeedle(compassBgFrame, CAMERA_COLOR, 4)

			local legend = Instance.new("Frame")
			legend.Size = UDim2.new(1, -8, 0, 16)
			legend.Position = UDim2.fromOffset(4, widgetStyles.TITLE_BAR_HEIGHT + 88)
			legend.BackgroundTransparency = 1
			legend.Parent = frame

			local movLegend = Instance.new("TextLabel")
			movLegend.Size = UDim2.fromOffset(40, 14)
			movLegend.Position = UDim2.fromOffset(0, 0)
			movLegend.BackgroundTransparency = 1
			movLegend.TextColor3 = MOVEMENT_COLOR
			movLegend.FontFace = fonts.GetFont(false, true)
			movLegend.TextSize = 11
			movLegend.Text = "● MOV"
			movLegend.TextXAlignment = Enum.TextXAlignment.Left
			movLegend.Parent = legend

			local camLegend = Instance.new("TextLabel")
			camLegend.Size = UDim2.fromOffset(40, 14)
			camLegend.Position = UDim2.new(1, -40, 0, 0)
			camLegend.BackgroundTransparency = 1
			camLegend.TextColor3 = CAMERA_COLOR
			camLegend.FontFace = fonts.GetFont(false, true)
			camLegend.TextSize = 11
			camLegend.Text = "● CAM"
			camLegend.TextXAlignment = Enum.TextXAlignment.Right
			camLegend.Parent = legend

			return frame
		end,

		Destroy = function()
			if renderConn then
				renderConn:Disconnect()
				renderConn = nil
			end
			movNeedle = nil
			camNeedle = nil
			compassLabel = nil
		end,

		OnRunStart = function()
			if movNeedle then
				movNeedle.Rotation = 0
			end
			if camNeedle then
				camNeedle.Rotation = 0
			end
			if renderConn then
				renderConn:Disconnect()
			end
			renderConn = RunService.RenderStepped:Connect(function()
				local movDir = getMovementDirection()
				if movDir and movNeedle then
					movNeedle.Rotation = yRotationToCompassBearing(movDir)
				end

				local camDir = getCameraFacing()
				local camBearing = yRotationToCompassBearing(camDir)
				if camNeedle then
					camNeedle.Rotation = camBearing
				end
				if compassLabel then
					compassLabel.Text = degreesToCardinal(camBearing)
				end
			end)
		end,

		OnRunEnd = function()
			if renderConn then
				renderConn:Disconnect()
				renderConn = nil
			end
		end,
	})
end

function module.Register(composer: { RegisterWidget: (string, string, () -> any) -> () })
	local category = widgetTypes.CATEGORIES.COMPASS
	composer.RegisterWidget(category, widgetTypes.COMPASS_STYLES.MOVEMENT, createMovementCompass)
	composer.RegisterWidget(category, widgetTypes.COMPASS_STYLES.CAMERA, createCameraCompass)
	composer.RegisterWidget(category, widgetTypes.COMPASS_STYLES.BOTH, createBothCompasses)
	_annotate("Registered compass widgets")
end

_annotate("end")
return module
