--!strict
-- terrainWidgets.lua (ReplicatedStorage/gui/activeRunWidgets/terrainWidgets.lua)
-- Terrain tracking widget implementations - simple list display ordered by time percentage.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local colors = require(game.ReplicatedStorage.util.colors)
local fonts = require(game.StarterPlayer.StarterPlayerScripts.guis.fonts)
local widgetTypes = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetTypes)
local widgetStyles = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetStyles)
local runStats = require(game.ReplicatedStorage.gui.activeRunWidgets.runStats)
local terrainData = require(game.ReplicatedStorage.gui.activeRunWidgets.terrainData)

local module = {}

-- Compact info showing terrain types touched
local function createCompactBadges(): widgetTypes.Widget
	local BADGES_WIDTH = 160
	local BADGES_HEIGHT = 100
	local BADGES_MIN_WIDTH = 120
	local BADGES_MAX_WIDTH = 250
	local BADGES_MIN_HEIGHT = 80
	local BADGES_MAX_HEIGHT = 200

	local container: Frame? = nil
	local terrainLabels: { [string]: TextLabel } = {}
	local terrainIconFrame: Frame? = nil
	local resizeCleanup: (() -> ())? = nil

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?, context: widgetTypes.WidgetCreateContext?): Frame?
			local frameWidth = BADGES_WIDTH
			local frameHeight = BADGES_HEIGHT
			if context and context.savedSize then
				frameWidth = context.savedSize.width
				frameHeight = context.savedSize.height
			end

			local frame = Instance.new("Frame")
			frame.Name = "TerrainWidget_badges"
			frame.Size = UDim2.fromOffset(frameWidth, frameHeight)

			if position then
				frame.Position = position
				frame.AnchorPoint = Vector2.new(0, 0)
			end

			frame.BackgroundColor3 = widgetStyles.containerBackground
			frame.BackgroundTransparency = widgetStyles.containerTransparency
			frame.BorderSizePixel = widgetStyles.containerBorderSize
			frame.BorderColor3 = widgetStyles.containerBorderColor
			frame.Parent = parent
			container = frame

			local iconFrame = Instance.new("Frame")
			iconFrame.Name = "TerrainIcon"
			iconFrame.Size = UDim2.fromOffset(32, 32)
			iconFrame.Position = UDim2.fromOffset(8, 6)
			iconFrame.BackgroundColor3 = colors.defaultGrey
			iconFrame.BackgroundTransparency = 0.5
			iconFrame.BorderSizePixel = 1
			iconFrame.BorderColor3 = colors.signColor
			iconFrame.Parent = frame
			terrainIconFrame = iconFrame

			local currentLabel = widgetStyles.createStandardLabel("Current", "—", colors.meColor, true, Enum.TextXAlignment.Left)
			currentLabel.Size = UDim2.new(1, -50, 0, 24)
			currentLabel.Position = UDim2.fromOffset(46, 8)
			currentLabel.Parent = frame
			terrainLabels["current"] = currentLabel

			local countLabel = widgetStyles.createStandardLabel("Count", "Types: 0", colors.defaultGrey, false, Enum.TextXAlignment.Left)
			countLabel.Size = UDim2.new(1, -8, 0, 20)
			countLabel.Position = UDim2.fromOffset(8, 38)
			countLabel.Parent = frame
			terrainLabels["count"] = countLabel

			local timeLabel = widgetStyles.createStandardLabel("Time", "0.0s", colors.orangeAccent, false, Enum.TextXAlignment.Left)
			timeLabel.Size = UDim2.new(1, -8, 0, 20)
			timeLabel.Position = UDim2.fromOffset(8, 58)
			timeLabel.Parent = frame
			terrainLabels["time"] = timeLabel

			local initialW = if context and context.savedSize then context.savedSize.width else nil
			local initialH = if context and context.savedSize then context.savedSize.height else nil
			local _, cleanup = widgetStyles.createResizeHandle({
				parent = frame,
				minWidth = BADGES_MIN_WIDTH,
				maxWidth = BADGES_MAX_WIDTH,
				minHeight = BADGES_MIN_HEIGHT,
				maxHeight = BADGES_MAX_HEIGHT,
				initialWidth = initialW,
				initialHeight = initialH,
				-- No onSizeChanged needed - children use scale-based sizing
				onResizeEnd = if context and context.onSaveSize then context.onSaveSize else nil,
			})
			resizeCleanup = cleanup

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
			terrainLabels = {}
			terrainIconFrame = nil
		end,

		OnRunStart = function()
			if terrainLabels["current"] then
				terrainLabels["current"].Text = "—"
			end
			if terrainLabels["count"] then
				terrainLabels["count"].Text = "Types: 0"
			end
			if terrainLabels["time"] then
				terrainLabels["time"].Text = "0.0s"
			end
			if terrainIconFrame then
				terrainIconFrame.BackgroundColor3 = colors.defaultGrey
			end
		end,

		UpdateTerrain = function(terrainName: string)
			if terrainLabels["current"] then
				terrainLabels["current"].Text = terrainName ~= "" and terrainName or "—"
			end

			if terrainIconFrame and terrainName ~= "" then
				local info = terrainData.GetTerrainInfo(terrainName)
				terrainIconFrame.BackgroundColor3 = info.color

				local existingImg = terrainIconFrame:FindFirstChild("TerrainTexture")
				if existingImg then
					existingImg:Destroy()
				end

				if info.textureId ~= "" then
					local img = Instance.new("ImageLabel")
					img.Name = "TerrainTexture"
					img.Size = UDim2.fromScale(1, 1)
					img.BackgroundTransparency = 1
					img.Image = info.textureId
					img.ScaleType = Enum.ScaleType.Crop
					img.Parent = terrainIconFrame
				end
			end

			local breakdown = runStats.GetTerrainBreakdown()
			if terrainLabels["count"] then
				terrainLabels["count"].Text = string.format("Types: %d", #breakdown)
			end

			if terrainLabels["time"] then
				for _, entry in ipairs(breakdown) do
					if entry.name == terrainName then
						terrainLabels["time"].Text = string.format("%.1fs on %s", entry.time, terrainName)
						break
					end
				end
			end
		end,
	})
end

-- Legend list showing terrain types encountered this run
local function createLegendList(): widgetTypes.Widget
	local LEGEND_WIDTH = 180
	local LEGEND_HEIGHT = 200
	local LEGEND_MIN_WIDTH = 140
	local LEGEND_MAX_WIDTH = 350
	local LEGEND_MIN_HEIGHT = 100
	local LEGEND_MAX_HEIGHT = 500
	local LEGEND_ROW_HEIGHT = 20
	local LEGEND_HEADER_HEIGHT = 22

	local ICON_WIDTH = 18
	local NAME_WIDTH_RATIO = 0.45
	local TIME_WIDTH = 45
	local PERCENT_WIDTH = 35

	local container: Frame? = nil
	local scrollFrame: ScrollingFrame? = nil
	local legendLabels: { Frame } = {}
	local lastUpdateTime: number = 0
	local resizeCleanup: (() -> ())? = nil

	local function updateLegend()
		for _, row in ipairs(legendLabels) do
			row:Destroy()
		end
		legendLabels = {}

		local scroll = scrollFrame
		local frame = container
		if not scroll or not frame then
			return
		end

		local breakdown = runStats.GetTerrainBreakdown()
		local yPos = 0

		for i, terrain in ipairs(breakdown) do
			local info = terrainData.GetTerrainInfo(terrain.name)

			local row = Instance.new("Frame")
			row.Name = "TerrainRow" .. i
			row.Size = UDim2.new(1, 0, 0, LEGEND_ROW_HEIGHT)
			row.Position = UDim2.fromOffset(0, yPos)
			row.BackgroundTransparency = 1
			row.Parent = scroll

			local indicator = Instance.new("Frame")
			indicator.Name = "Indicator"
			indicator.Size = UDim2.fromOffset(14, 14)
			indicator.Position = UDim2.fromOffset(2, 3)
			indicator.BackgroundColor3 = info.color
			indicator.BorderSizePixel = 1
			indicator.BorderColor3 = colors.black
			indicator.ClipsDescendants = true
			indicator.Parent = row

			if info.textureId ~= "" then
				local texImg = Instance.new("ImageLabel")
				texImg.Name = "Texture"
				texImg.Size = UDim2.fromScale(1, 1)
				texImg.BackgroundTransparency = 1
				texImg.Image = info.textureId
				texImg.ScaleType = Enum.ScaleType.Crop
				texImg.Parent = indicator
			end

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Name = "Name"
			nameLabel.Size = UDim2.fromScale(NAME_WIDTH_RATIO, 1)
			nameLabel.Position = UDim2.fromOffset(ICON_WIDTH + 2, 0)
			nameLabel.BackgroundTransparency = 1
			nameLabel.TextColor3 = colors.white
			nameLabel.FontFace = fonts.GetFont(false, true)
			nameLabel.TextSize = 13
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
			nameLabel.TextStrokeTransparency = 0.5
			nameLabel.TextStrokeColor3 = colors.black
			nameLabel.Text = info.displayName
			nameLabel.Parent = row

			local timeLabel = Instance.new("TextLabel")
			timeLabel.Name = "Time"
			timeLabel.Size = UDim2.fromOffset(TIME_WIDTH, LEGEND_ROW_HEIGHT)
			timeLabel.Position = UDim2.new(1, -TIME_WIDTH - PERCENT_WIDTH - 4, 0, 0)
			timeLabel.BackgroundTransparency = 1
			timeLabel.TextColor3 = colors.white
			timeLabel.FontFace = fonts.GetFont(true, false)
			timeLabel.TextSize = 12
			timeLabel.TextXAlignment = Enum.TextXAlignment.Right
			timeLabel.TextStrokeTransparency = 0.5
			timeLabel.TextStrokeColor3 = colors.black
			timeLabel.Text = string.format("%.1fs", terrain.time)
			timeLabel.Parent = row

			local percentLabel = Instance.new("TextLabel")
			percentLabel.Name = "Percent"
			percentLabel.Size = UDim2.fromOffset(PERCENT_WIDTH, LEGEND_ROW_HEIGHT)
			percentLabel.Position = UDim2.new(1, -PERCENT_WIDTH - 2, 0, 0)
			percentLabel.BackgroundTransparency = 1
			percentLabel.TextColor3 = colors.white
			percentLabel.FontFace = fonts.GetFont(true, false)
			percentLabel.TextSize = 12
			percentLabel.TextXAlignment = Enum.TextXAlignment.Right
			percentLabel.TextStrokeTransparency = 0.5
			percentLabel.TextStrokeColor3 = colors.black
			percentLabel.Text = string.format("%.0f%%", terrain.percent)
			percentLabel.Parent = row

			table.insert(legendLabels, row)
			yPos = yPos + LEGEND_ROW_HEIGHT
		end

		scroll.CanvasSize = UDim2.fromOffset(0, yPos)

		local contentHeight = LEGEND_HEADER_HEIGHT + yPos
		local clampedHeight = math.clamp(contentHeight, LEGEND_MIN_HEIGHT, LEGEND_MAX_HEIGHT)
		frame.Size = UDim2.fromOffset(frame.Size.X.Offset, clampedHeight)
	end

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?, context: widgetTypes.WidgetCreateContext?): Frame?
			local frameWidth = LEGEND_WIDTH
			local frameHeight = LEGEND_HEIGHT
			if context and context.savedSize then
				frameWidth = context.savedSize.width
				frameHeight = context.savedSize.height
			end

			local frame = Instance.new("Frame")
			frame.Name = "TerrainWidget_legend"
			frame.Size = UDim2.fromOffset(frameWidth, frameHeight)

			if position then
				frame.Position = position
				frame.AnchorPoint = Vector2.new(0, 0)
			end

			frame.BackgroundColor3 = widgetStyles.containerBackground
			frame.BackgroundTransparency = widgetStyles.containerTransparency
			frame.BorderSizePixel = widgetStyles.containerBorderSize
			frame.BorderColor3 = widgetStyles.containerBorderColor
			frame.Parent = parent
			container = frame

			local header = Instance.new("TextLabel")
			header.Name = "Header"
			header.Size = UDim2.new(1, 0, 0, LEGEND_HEADER_HEIGHT)
			header.Position = UDim2.fromOffset(0, 0)
			header.BackgroundColor3 = colors.signColor
			header.BackgroundTransparency = 0.5
			header.BorderSizePixel = 0
			header.TextColor3 = colors.white
			header.FontFace = fonts.GetFont(false, true)
			header.TextSize = 11
			header.Text = "Terrain Seen this run"
			header.Parent = frame

			local scroll = Instance.new("ScrollingFrame")
			scroll.Name = "LegendScroll"
			scroll.Size = UDim2.new(1, 0, 1, -LEGEND_HEADER_HEIGHT)
			scroll.Position = UDim2.fromOffset(0, LEGEND_HEADER_HEIGHT)
			scroll.BackgroundTransparency = 1
			scroll.ScrollBarThickness = 4
			scroll.ScrollBarImageColor3 = colors.signColor
			scroll.CanvasSize = UDim2.fromOffset(0, 0)
			scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
			scroll.ClipsDescendants = true
			scroll.BorderSizePixel = 0
			scroll.Parent = frame
			scrollFrame = scroll

			local initialW = if context and context.savedSize then context.savedSize.width else nil
			local initialH = if context and context.savedSize then context.savedSize.height else nil
			local _, cleanup = widgetStyles.createResizeHandle({
				parent = frame,
				minWidth = LEGEND_MIN_WIDTH,
				maxWidth = LEGEND_MAX_WIDTH,
				minHeight = LEGEND_MIN_HEIGHT,
				maxHeight = LEGEND_MAX_HEIGHT,
				initialWidth = initialW,
				initialHeight = initialH,
				-- No onSizeChanged needed - children use scale-based sizing
				onResizeEnd = if context and context.onSaveSize then context.onSaveSize else nil,
			})
			resizeCleanup = cleanup

			return frame
		end,

		Destroy = function()
			for _, label in ipairs(legendLabels) do
				label:Destroy()
			end
			legendLabels = {}
			if resizeCleanup then
				resizeCleanup()
				resizeCleanup = nil
			end
			if container then
				container:Destroy()
				container = nil
			end
			scrollFrame = nil
		end,

		OnRunStart = function()
			for _, label in ipairs(legendLabels) do
				label:Destroy()
			end
			legendLabels = {}
		end,

		UpdateSpeed = function(_speed: number)
			local now = tick()
			if now - lastUpdateTime < 0.5 then
				return
			end
			lastUpdateTime = now
			updateLegend()
		end,
	})
end

function module.Register(composer: { RegisterWidget: (string, string, () -> any) -> () })
	local category = widgetTypes.CATEGORIES.TERRAIN
	composer.RegisterWidget(category, widgetTypes.TERRAIN_STYLES.TERRAIN_INFO, createCompactBadges)
	composer.RegisterWidget(category, widgetTypes.TERRAIN_STYLES.LEGEND_LIST, createLegendList)
	_annotate("Registered terrain widgets")
end

_annotate("end")
return module
