--!strict
-- mapsWidgets.lua (ReplicatedStorage/gui/activeRunWidgets/mapsWidgets.lua)
-- Map display widgets (journey visualization).

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local Players = game:GetService("Players")

local colors = require(game.ReplicatedStorage.util.colors)
local fonts = require(game.StarterPlayer.StarterPlayerScripts.guis.fonts)
local widgetTypes = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetTypes)
local widgetStyles = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetStyles)

local localPlayer = Players.LocalPlayer

local module = {}

-- Journey map configuration
local DEFAULT_MAP_SIZE = 180
local MIN_MAP_SIZE = 100
local MAX_MAP_SIZE = 600
local MAX_TRAIL_POINTS = 500
local SAMPLE_DISTANCE = 4

local TITLE_BAR_HEIGHT = 20
local MAP_TOP_OFFSET = TITLE_BAR_HEIGHT + 4
local INFO_BAR_HEIGHT = 24
local PADDING = 12

local TRAIL_SLOW = Color3.fromRGB(80, 140, 220)
local TRAIL_MEDIUM = Color3.fromRGB(100, 220, 180)
local TRAIL_FAST = Color3.fromRGB(255, 220, 80)
local TRAIL_BLAZING = Color3.fromRGB(255, 100, 100)

local PLAYER_COLOR = colors.signColor
local START_COLOR = Color3.fromRGB(100, 255, 120)
local GRID_COLOR = Color3.fromRGB(45, 55, 65)
local MAP_BG_COLOR = Color3.fromRGB(20, 25, 32)

local function createJourneyMap(): widgetTypes.Widget
	local container: Frame? = nil
	local mapFrame: Frame? = nil
	local timerLabel: TextLabel? = nil
	local distLabel: TextLabel? = nil
	local zoomLabel: TextLabel? = nil
	local signLabel: TextLabel? = nil
	local playerMarker: Frame? = nil
	local playerArrow: Frame? = nil
	local startMarker: Frame? = nil
	local trailLines: { Frame } = {}

	local startTick: number = 0
	local startPosition: Vector3 = Vector3.new(0, 0, 0)
	type TrailPoint = { pos: Vector3, speed: number, time: number }
	local positionHistory: { TrailPoint } = {}
	local lastSamplePos: Vector3 = Vector3.new(0, 0, 0)
	local currentFacing: number = 0

	local zoomLevel: number = 1.0
	local mapSize: number = DEFAULT_MAP_SIZE
	local lastUpdateTime: number = 0

	local resizeCleanup: (() -> ())? = nil

	local function getFrameHeight(currentMapSize: number): number
		return MAP_TOP_OFFSET + 18 + currentMapSize + 4 + INFO_BAR_HEIGHT + 4
	end

	local function getInfoBarY(currentMapSize: number): number
		return MAP_TOP_OFFSET + 18 + currentMapSize + 4
	end

	local function getCharacterPosition(): Vector3?
		local character = localPlayer.Character
		if not character then
			return nil
		end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			return hrp.Position
		end
		return nil
	end

	local function worldToMap(worldPos: Vector3, centerPos: Vector3, scale: number, currentMapSize: number): Vector2
		local offset = worldPos - centerPos
		local halfSize = currentMapSize / 2
		local mapX = (offset.X / scale) * halfSize + halfSize
		local mapY = (offset.Z / scale) * halfSize + halfSize
		return Vector2.new(math.clamp(mapX, 4, currentMapSize - 4), math.clamp(mapY, 4, currentMapSize - 4))
	end

	local function getMapScale(): number
		if #positionHistory < 2 then
			return 80 * zoomLevel
		end
		local maxDist = 0
		for _, point in ipairs(positionHistory) do
			local dist = (Vector3.new(point.pos.X, 0, point.pos.Z) - Vector3.new(startPosition.X, 0, startPosition.Z)).Magnitude
			if dist > maxDist then
				maxDist = dist
			end
		end
		return math.max(40, maxDist * 1.4) * zoomLevel
	end

	local function getSpeedColor(speed: number): Color3
		if speed >= 85 then
			return TRAIL_BLAZING
		elseif speed >= 68 then
			return TRAIL_FAST
		elseif speed >= 40 then
			return TRAIL_MEDIUM
		else
			return TRAIL_SLOW
		end
	end

	local function clearTrail()
		for _, line in ipairs(trailLines) do
			line:Destroy()
		end
		trailLines = {}
	end

	local function updateTrail()
		clearTrail()

		local map = mapFrame
		if not map or #positionHistory < 2 then
			return
		end

		local scale = getMapScale()
		local centerPos = startPosition
		local currentMapSize = mapSize

		for i = 1, #positionHistory - 1 do
			local point1 = positionHistory[i]
			local point2 = positionHistory[i + 1]
			local mapPos1 = worldToMap(point1.pos, centerPos, scale, currentMapSize)
			local mapPos2 = worldToMap(point2.pos, centerPos, scale, currentMapSize)
			local length = (mapPos2 - mapPos1).Magnitude
			local angle = math.atan2(mapPos2.Y - mapPos1.Y, mapPos2.X - mapPos1.X)

			local alpha = 0.4 + 0.6 * (i / #positionHistory)
			local avgSpeed = (point1.speed + point2.speed) / 2

			local line = Instance.new("Frame")
			line.Name = "Trail" .. i
			line.Size = UDim2.fromOffset(math.max(length, 2), 3)
			line.Position = UDim2.fromOffset(mapPos1.X, mapPos1.Y)
			line.AnchorPoint = Vector2.new(0, 0.5)
			line.Rotation = math.deg(angle)
			line.BackgroundColor3 = getSpeedColor(avgSpeed)
			line.BackgroundTransparency = 1 - alpha
			line.BorderSizePixel = 0
			line.ZIndex = 2
			line.Parent = map
			table.insert(trailLines, line)
		end

		if startMarker then
			local mapPos = worldToMap(startPosition, centerPos, scale, currentMapSize)
			startMarker.Position = UDim2.fromOffset(mapPos.X, mapPos.Y)
		end

		local charPos = getCharacterPosition()
		if playerMarker and charPos then
			local mapPos = worldToMap(charPos, centerPos, scale, currentMapSize)
			playerMarker.Position = UDim2.fromOffset(mapPos.X, mapPos.Y)
		end
		if playerArrow then
			playerArrow.Rotation = currentFacing
		end
	end

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?, context: widgetTypes.WidgetCreateContext?): Frame?
			if context and context.savedSize then
				mapSize = context.savedSize.width - PADDING * 2
			end

			local frame = Instance.new("Frame")
			frame.Name = "MapsWidget_journey"
			frame.Size = UDim2.fromOffset(mapSize + PADDING * 2, getFrameHeight(mapSize))

			if position then
				frame.Position = position
				frame.AnchorPoint = Vector2.new(0, 0)
			end

			frame.BackgroundColor3 = widgetStyles.containerBackground
			frame.BackgroundTransparency = 0.05
			frame.BorderSizePixel = widgetStyles.containerBorderSize
			frame.BorderColor3 = widgetStyles.containerBorderColor
			frame.Parent = parent
			container = frame

			widgetStyles.createTitleBar(frame, "Map")

			local sign = Instance.new("TextLabel")
			sign.Name = "SignName"
			sign.Size = UDim2.new(0.6, -8, 0, 16)
			sign.Position = UDim2.fromOffset(8, TITLE_BAR_HEIGHT + 2)
			sign.BackgroundTransparency = 1
			sign.TextColor3 = colors.signColor
			sign.FontFace = fonts.GetFont(false, true)
			sign.TextSize = 14
			sign.TextXAlignment = Enum.TextXAlignment.Left
			sign.TextTruncate = Enum.TextTruncate.AtEnd
			sign.Text = ""
			sign.Parent = frame
			signLabel = sign

			local timer = Instance.new("TextLabel")
			timer.Name = "Timer"
			timer.Size = UDim2.fromOffset(70, 16)
			timer.Position = UDim2.new(1, -78, 0, TITLE_BAR_HEIGHT + 2)
			timer.BackgroundTransparency = 1
			timer.TextColor3 = colors.meColor
			timer.FontFace = fonts.GetFont(true, true)
			timer.TextSize = 16
			timer.TextXAlignment = Enum.TextXAlignment.Right
			timer.Text = "0.00s"
			timer.Parent = frame
			timerLabel = timer

			local map = Instance.new("Frame")
			map.Name = "Map"
			map.Size = UDim2.fromOffset(mapSize, mapSize)
			map.Position = UDim2.fromOffset(12, MAP_TOP_OFFSET + 18)
			map.BackgroundColor3 = MAP_BG_COLOR
			map.BorderSizePixel = 0
			map.ClipsDescendants = true
			map.Parent = frame
			mapFrame = map

			local mapStroke = Instance.new("UIStroke")
			mapStroke.Color = colors.signColor
			mapStroke.Thickness = 1
			mapStroke.Transparency = 0.5
			mapStroke.Parent = map

			for i = 1, 4 do
				local hLine = Instance.new("Frame")
				hLine.Size = UDim2.new(1, 0, 0, 1)
				hLine.Position = UDim2.fromScale(0, i * 0.2)
				hLine.BackgroundColor3 = GRID_COLOR
				hLine.BackgroundTransparency = 0.6
				hLine.BorderSizePixel = 0
				hLine.ZIndex = 1
				hLine.Parent = map

				local vLine = Instance.new("Frame")
				vLine.Size = UDim2.new(0, 1, 1, 0)
				vLine.Position = UDim2.fromScale(i * 0.2, 0)
				vLine.BackgroundColor3 = GRID_COLOR
				vLine.BackgroundTransparency = 0.6
				vLine.BorderSizePixel = 0
				vLine.ZIndex = 1
				vLine.Parent = map
			end

			local compassBg = Instance.new("Frame")
			compassBg.Name = "CompassRose"
			compassBg.Size = UDim2.fromOffset(24, 24)
			compassBg.Position = UDim2.fromOffset(4, 4)
			compassBg.BackgroundColor3 = Color3.fromRGB(30, 35, 42)
			compassBg.BackgroundTransparency = 0.3
			compassBg.BorderSizePixel = 0
			compassBg.ZIndex = 10
			compassBg.Parent = map

			local compassN = Instance.new("TextLabel")
			compassN.Size = UDim2.fromScale(1, 1)
			compassN.BackgroundTransparency = 1
			compassN.TextColor3 = colors.signColor
			compassN.FontFace = fonts.GetFont(false, true)
			compassN.TextSize = 12
			compassN.Text = "N"
			compassN.ZIndex = 11
			compassN.Parent = compassBg

			local startMark = Instance.new("Frame")
			startMark.Name = "StartMarker"
			startMark.Size = UDim2.fromOffset(10, 10)
			startMark.Position = UDim2.fromScale(0.5, 0.5)
			startMark.AnchorPoint = Vector2.new(0.5, 0.5)
			startMark.BackgroundColor3 = START_COLOR
			startMark.BorderSizePixel = 0
			startMark.Rotation = 45
			startMark.ZIndex = 5
			startMark.Parent = map
			startMarker = startMark

			local playerMark = Instance.new("Frame")
			playerMark.Name = "PlayerMarker"
			playerMark.Size = UDim2.fromOffset(14, 14)
			playerMark.Position = UDim2.fromScale(0.5, 0.5)
			playerMark.AnchorPoint = Vector2.new(0.5, 0.5)
			playerMark.BackgroundColor3 = PLAYER_COLOR
			playerMark.BorderSizePixel = 0
			playerMark.ZIndex = 10
			playerMark.Parent = map
			playerMarker = playerMark

			local playerCorner = Instance.new("UICorner")
			playerCorner.CornerRadius = UDim.new(0.5, 0)
			playerCorner.Parent = playerMark

			local arrow = Instance.new("Frame")
			arrow.Name = "DirectionArrow"
			arrow.Size = UDim2.fromOffset(4, 10)
			arrow.Position = UDim2.fromScale(0.5, 0.5)
			arrow.AnchorPoint = Vector2.new(0.5, 1.2)
			arrow.BackgroundColor3 = colors.white
			arrow.BorderSizePixel = 0
			arrow.Rotation = 0
			arrow.ZIndex = 11
			arrow.Parent = playerMark
			playerArrow = arrow

			local infoBar = Instance.new("Frame")
			infoBar.Name = "InfoBar"
			infoBar.Size = UDim2.new(1, -PADDING * 2, 0, INFO_BAR_HEIGHT)
			infoBar.Position = UDim2.fromOffset(PADDING, getInfoBarY(mapSize))
			infoBar.BackgroundTransparency = 1
			infoBar.Parent = frame

			local dist = Instance.new("TextLabel")
			dist.Name = "Distance"
			dist.Size = UDim2.fromOffset(80, 20)
			dist.Position = UDim2.fromOffset(0, 0)
			dist.BackgroundTransparency = 1
			dist.TextColor3 = TRAIL_MEDIUM
			dist.FontFace = fonts.GetFont(true, true)
			dist.TextSize = 16
			dist.TextXAlignment = Enum.TextXAlignment.Left
			dist.Text = "0.0d"
			dist.Parent = infoBar
			distLabel = dist

			local zoom = Instance.new("TextLabel")
			zoom.Name = "Zoom"
			zoom.Size = UDim2.fromOffset(50, 20)
			zoom.Position = UDim2.new(0.5, -25, 0, 0)
			zoom.BackgroundTransparency = 1
			zoom.TextColor3 = colors.defaultGrey
			zoom.FontFace = fonts.GetFont(true, false)
			zoom.TextSize = 14
			zoom.Text = "1.0x"
			zoom.Parent = infoBar
			zoomLabel = zoom

			local zoomIn = Instance.new("TextButton")
			zoomIn.Name = "ZoomIn"
			zoomIn.Size = UDim2.fromOffset(24, 24)
			zoomIn.Position = UDim2.new(1, -52, 0, -2)
			zoomIn.BackgroundColor3 = colors.defaultGrey
			zoomIn.BorderSizePixel = 0
			zoomIn.Text = "+"
			zoomIn.TextColor3 = colors.white
			zoomIn.TextSize = 18
			zoomIn.FontFace = fonts.GetFont(true, true)
			zoomIn.Parent = infoBar

			zoomIn.MouseButton1Click:Connect(function()
				zoomLevel = math.max(0.25, zoomLevel / 1.4)
				if zoomLabel then
					zoomLabel.Text = string.format("%.1fx", 1 / zoomLevel)
				end
				updateTrail()
			end)

			local zoomOut = Instance.new("TextButton")
			zoomOut.Name = "ZoomOut"
			zoomOut.Size = UDim2.fromOffset(24, 24)
			zoomOut.Position = UDim2.new(1, -24, 0, -2)
			zoomOut.BackgroundColor3 = colors.defaultGrey
			zoomOut.BorderSizePixel = 0
			zoomOut.Text = "-"
			zoomOut.TextColor3 = colors.white
			zoomOut.TextSize = 18
			zoomOut.FontFace = fonts.GetFont(true, true)
			zoomOut.Parent = infoBar

			zoomOut.MouseButton1Click:Connect(function()
				zoomLevel = math.min(4.0, zoomLevel * 1.4)
				if zoomLabel then
					zoomLabel.Text = string.format("%.1fx", 1 / zoomLevel)
				end
				updateTrail()
			end)

			local initialW = if context and context.savedSize then context.savedSize.width else nil
			local initialH = if context and context.savedSize then context.savedSize.height else nil
			local _, cleanup = widgetStyles.createResizeHandle({
				parent = frame,
				minWidth = MIN_MAP_SIZE + PADDING * 2,
				maxWidth = MAX_MAP_SIZE + PADDING * 2,
				minHeight = getFrameHeight(MIN_MAP_SIZE),
				maxHeight = getFrameHeight(MAX_MAP_SIZE),
				initialWidth = initialW,
				initialHeight = initialH,
				onSizeChanged = function(newWidth: number, _newHeight: number)
					local newMapSize = newWidth - PADDING * 2
					mapSize = newMapSize
					map.Size = UDim2.fromOffset(mapSize, mapSize)
					infoBar.Position = UDim2.fromOffset(PADDING, getInfoBarY(mapSize))
					updateTrail()
				end,
				onResizeEnd = if context and context.onSaveSize then context.onSaveSize else nil,
			})
			resizeCleanup = cleanup

			return frame
		end,

		Destroy = function()
			clearTrail()
			if resizeCleanup then
				resizeCleanup()
				resizeCleanup = nil
			end
			if container then
				container:Destroy()
				container = nil
			end
			mapFrame = nil
			timerLabel = nil
			distLabel = nil
			zoomLabel = nil
			signLabel = nil
			playerMarker = nil
			playerArrow = nil
			startMarker = nil
			positionHistory = {}
		end,

		OnRunStart = function(runStartTick: number, runSignName: string, runSignPosition: Vector3)
			startTick = runStartTick
			startPosition = runSignPosition
			positionHistory = {}
			lastSamplePos = runSignPosition
			zoomLevel = 1.0
			currentFacing = 0
			lastUpdateTime = 0
			clearTrail()

			if signLabel then
				signLabel.Text = runSignName
			end
			if zoomLabel then
				zoomLabel.Text = "1.0x"
			end
		end,

		OnRunEnd = function()
			startTick = 0
		end,

		UpdateSpeed = function(speed: number)
			if timerLabel and startTick > 0 then
				timerLabel.Text = string.format("%.2fs", tick() - startTick)
			end

			local charPos = getCharacterPosition()
			if charPos then
				local dist2d = (Vector3.new(charPos.X, 0, charPos.Z) - Vector3.new(lastSamplePos.X, 0, lastSamplePos.Z)).Magnitude
				if dist2d > SAMPLE_DISTANCE then
					table.insert(positionHistory, {
						pos = charPos,
						speed = speed,
						time = tick(),
					})
					lastSamplePos = charPos
					if #positionHistory > MAX_TRAIL_POINTS then
						table.remove(positionHistory, 1)
					end
				end
			end

			local now = tick()
			if now - lastUpdateTime > 0.15 then
				lastUpdateTime = now
				updateTrail()
			end
		end,

		UpdateDistance = function(fromStart: number, _total: number)
			if distLabel then
				distLabel.Text = string.format("%.1fd", fromStart)
			end
		end,

		UpdateFacing = function(degrees: number)
			currentFacing = -degrees
			if playerArrow then
				playerArrow.Rotation = currentFacing
			end
		end,
	})
end

function module.Register(composer: { RegisterWidget: (string, string, () -> any) -> () })
	local category = widgetTypes.CATEGORIES.MAPS
	composer.RegisterWidget(category, widgetTypes.MAPS_STYLES.JOURNEY_MAP, createJourneyMap)
	_annotate("Registered maps widgets")
end

_annotate("end")
return module
