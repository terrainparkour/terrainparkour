--!strict
-- altitudeWidgets.lua (ReplicatedStorage/gui/activeRunWidgets/altitudeWidgets.lua)
-- Altitude display widget implementations.
-- All chart visualizations use the unified timeSeriesChart library.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local colors = require(game.ReplicatedStorage.util.colors)
local fonts = require(game.StarterPlayer.StarterPlayerScripts.guis.fonts)
local widgetTypes = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetTypes)
local widgetStyles = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetStyles)

local module = {}

--------------------------------------------------------------------------------
-- Numeric altitude display variants
--------------------------------------------------------------------------------

-- Helper to create a numeric altitude widget with specified style
local function createNumericAltitude(style: "transparent-large" | "transparent-small" | "black-medium"): widgetTypes.Widget
	local altLabel: TextLabel? = nil
	local vertLabel: TextLabel? = nil
	local hoverCleanup: (() -> ())? = nil

	-- Style configuration
	local config = {
		["transparent-large"] = { size = UDim2.fromOffset(140, 55), altTextSize = 24, vertTextSize = 18, bgTransparency = 1 },
		["transparent-small"] = { size = UDim2.fromOffset(100, 40), altTextSize = 16, vertTextSize = 12, bgTransparency = 1 },
		["black-medium"] = { size = UDim2.fromOffset(120, 50), altTextSize = 20, vertTextSize = 16, bgTransparency = 0.15 },
	}
	local cfg = config[style]

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local frame = Instance.new("Frame")
			frame.Name = "AltitudeWidget_numeric_" .. style
			frame.Size = cfg.size
			frame.BackgroundTransparency = cfg.bgTransparency
			frame.BackgroundColor3 = widgetStyles.containerBackground
			frame.BorderSizePixel = if cfg.bgTransparency < 1 then widgetStyles.containerBorderSize else 0
			frame.BorderColor3 = widgetStyles.containerBorderColor

			if position then
				frame.Position = position
				frame.AnchorPoint = Vector2.new(0.5, 0.5)
			end

			frame.Parent = parent

			hoverCleanup = widgetStyles.addHoverBorder(frame)

			local alt = Instance.new("TextLabel")
			alt.Name = "AltLabel"
			alt.Size = UDim2.fromScale(1, 0.55)
			alt.Position = UDim2.fromOffset(0, 0)
			alt.BackgroundTransparency = 1
			alt.TextColor3 = widgetStyles.textColors.altitude
			alt.FontFace = fonts.GetFont(true, true)
			alt.TextSize = cfg.altTextSize
			alt.TextXAlignment = Enum.TextXAlignment.Center
			alt.TextStrokeTransparency = 0.3
			alt.TextStrokeColor3 = colors.black
			alt.Text = "0.0↕"
			alt.Parent = frame
			altLabel = alt

			local vert = Instance.new("TextLabel")
			vert.Name = "VertLabel"
			vert.Size = UDim2.fromScale(1, 0.45)
			vert.Position = UDim2.fromScale(0, 0.55)
			vert.BackgroundTransparency = 1
			vert.TextColor3 = colors.grey
			vert.FontFace = fonts.GetFont(true, false)
			vert.TextSize = cfg.vertTextSize
			vert.TextXAlignment = Enum.TextXAlignment.Center
			vert.TextStrokeTransparency = 0.3
			vert.TextStrokeColor3 = colors.black
			vert.Text = "—"
			vert.Parent = frame
			vertLabel = vert

			return frame
		end,

		Destroy = function()
			if hoverCleanup then
				hoverCleanup()
				hoverCleanup = nil
			end
			altLabel = nil
			vertLabel = nil
		end,

		OnRunStart = function()
			if altLabel then
				altLabel.Text = "0.0↕"
			end
			if vertLabel then
				vertLabel.Text = "—"
				vertLabel.TextColor3 = colors.grey
			end
		end,

		UpdateAltitude = function(altitude: number, verticalVelocity: number)
			if altLabel then
				altLabel.Text = string.format("%.1f↕", altitude)
			end

			if vertLabel then
				if verticalVelocity > 1 then
					vertLabel.Text = string.format("▲%.1f↕", verticalVelocity)
					vertLabel.TextColor3 = colors.lightGreen
				elseif verticalVelocity < -1 then
					vertLabel.Text = string.format("▼%.1f↕", math.abs(verticalVelocity))
					vertLabel.TextColor3 = colors.lightRed
				else
					vertLabel.Text = "—"
					vertLabel.TextColor3 = colors.grey
				end
			end
		end,
	})
end

--------------------------------------------------------------------------------
-- Stats panel with altitude info
-- Collapses to just "Current" when not in a run; expands when run starts
--------------------------------------------------------------------------------

local function createStatsPanel(): widgetTypes.Widget
	local container: Frame? = nil
	local labels: { [string]: TextLabel } = {}
	local extraRows: { Frame } = {}
	local inRun: boolean = false
	local startAltitudeValue: number = 0
	local maxAltitude: number = 0
	local minAltitude: number = math.huge

	local ROW_HEIGHT = 22
	local TITLE_HEIGHT = 20
	local COLLAPSED_HEIGHT = TITLE_HEIGHT + ROW_HEIGHT + 4
	local EXPANDED_HEIGHT = TITLE_HEIGHT + ROW_HEIGHT * 5 + 4

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local frame = Instance.new("Frame")
			frame.Name = "AltitudeWidget_stats"
			frame.Position = position or UDim2.fromScale(0.1, 0.5)
			frame.Size = UDim2.fromOffset(140, COLLAPSED_HEIGHT)
			frame.AnchorPoint = Vector2.new(0.5, 0)
			frame.BackgroundColor3 = widgetStyles.containerBackground
			frame.BackgroundTransparency = 0.1
			frame.BorderSizePixel = widgetStyles.containerBorderSize
			frame.BorderColor3 = widgetStyles.containerBorderColor
			frame.Parent = parent
			container = frame

			widgetStyles.createTitleBar(frame, "↕ Stats")

			local currentLabel =
				widgetStyles.createStatRow(frame, "Current", "0.0↕", widgetStyles.textColors.altitude, TITLE_HEIGHT + 2, ROW_HEIGHT)
			labels["current"] = currentLabel

			local extraRowDefs: { { key: string, label: string, y: number } } = {
				{ key = "start", label = "Start", y = TITLE_HEIGHT + 2 + ROW_HEIGHT },
				{ key = "highest", label = "Highest", y = TITLE_HEIGHT + 2 + ROW_HEIGHT * 2 },
				{ key = "lowest", label = "Lowest", y = TITLE_HEIGHT + 2 + ROW_HEIGHT * 3 },
				{ key = "net", label = "Net", y = TITLE_HEIGHT + 2 + ROW_HEIGHT * 4 },
			}

			for _, row in ipairs(extraRowDefs) do
				local valueLabel =
					widgetStyles.createStatRow(frame, row.label, "0.0↕", widgetStyles.textColors.altitude, row.y, ROW_HEIGHT)
				labels[row.key] = valueLabel
				local rowFrame = valueLabel.Parent
				if rowFrame and rowFrame:IsA("Frame") then
					rowFrame.Visible = false
					table.insert(extraRows, rowFrame)
				end
			end

			return frame
		end,

		Destroy = function()
			if container then
				container:Destroy()
				container = nil
			end
			labels = {}
			extraRows = {}
		end,

		OnRunStart = function()
			inRun = true
			startAltitudeValue = 0
			maxAltitude = 0
			minAltitude = math.huge

			if container then
				container.Size = UDim2.fromOffset(140, EXPANDED_HEIGHT)
			end
			for _, rowFrame in ipairs(extraRows) do
				rowFrame.Visible = true
			end

			for key, label in pairs(labels) do
				if key == "current" then
					label.Text = "0.0↕"
					label.TextColor3 = widgetStyles.textColors.altitude
				else
					label.Text = "0.0↕"
					label.TextColor3 = colors.grey
				end
			end
		end,

		OnRunEnd = function()
			inRun = false
			startAltitudeValue = 0
			maxAltitude = 0
			minAltitude = math.huge

			if container then
				container.Size = UDim2.fromOffset(140, COLLAPSED_HEIGHT)
			end
			for _, rowFrame in ipairs(extraRows) do
				rowFrame.Visible = false
			end
		end,

		UpdateAltitude = function(altitude: number, _verticalVelocity: number)
			local currentLabel = labels["current"]
			if currentLabel then
				currentLabel.Text = string.format("%.1f↕", altitude)
			end

			if not inRun then
				return
			end

			if startAltitudeValue == 0 then
				startAltitudeValue = altitude
				maxAltitude = altitude
				minAltitude = altitude
			end

			if altitude > maxAltitude then
				maxAltitude = altitude
			end
			if altitude < minAltitude then
				minAltitude = altitude
			end

			local net = altitude - startAltitudeValue

			local startLabel = labels["start"]
			if startLabel then
				startLabel.Text = string.format("%.1f↕", startAltitudeValue)
				startLabel.TextColor3 = widgetStyles.textColors.altitude
			end

			local highestLabel = labels["highest"]
			if highestLabel then
				highestLabel.Text = string.format("%.1f↕", maxAltitude)
				highestLabel.TextColor3 = widgetStyles.textColors.altitude
			end

			local lowestLabel = labels["lowest"]
			if lowestLabel then
				lowestLabel.Text = string.format("%.1f↕", minAltitude)
				lowestLabel.TextColor3 = widgetStyles.textColors.altitude
			end

			local netLabel = labels["net"]
			if netLabel then
				if net > 0 then
					netLabel.Text = string.format("▲%.1f↕", net)
					netLabel.TextColor3 = colors.lightGreen
				elseif net < 0 then
					netLabel.Text = string.format("▼%.1f↕", math.abs(net))
					netLabel.TextColor3 = colors.lightRed
				else
					netLabel.Text = "0.0↕"
					netLabel.TextColor3 = colors.grey
				end
			end
		end,
	})
end

--------------------------------------------------------------------------------
-- Factory functions for each variant
--------------------------------------------------------------------------------

local function createNumericTransparentLarge(): widgetTypes.Widget
	return createNumericAltitude("transparent-large")
end

local function createNumericTransparentSmall(): widgetTypes.Widget
	return createNumericAltitude("transparent-small")
end

local function createNumericBlackMedium(): widgetTypes.Widget
	return createNumericAltitude("black-medium")
end

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

function module.Register(composer: { RegisterWidget: (string, string, () -> any) -> () })
	local category = widgetTypes.CATEGORIES.ALTITUDE
	local styles = widgetTypes.ALTITUDE_STYLES

	composer.RegisterWidget(category, styles.NUMERIC_LARGE, createNumericTransparentLarge)
	composer.RegisterWidget(category, styles.NUMERIC_SMALL, createNumericTransparentSmall)
	composer.RegisterWidget(category, styles.NUMERIC_BLACK, createNumericBlackMedium)
	composer.RegisterWidget(category, styles.STATS, createStatsPanel)

	_annotate("Registered altitude widgets")
end

_annotate("end")
return module
