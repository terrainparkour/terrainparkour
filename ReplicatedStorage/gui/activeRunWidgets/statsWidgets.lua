--!strict
-- statsWidgets.lua (ReplicatedStorage/gui/activeRunWidgets/statsWidgets.lua)
-- Statistics display widget implementations with run insights.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local colors = require(game.ReplicatedStorage.util.colors)
local fonts = require(game.StarterPlayer.StarterPlayerScripts.guis.fonts)
local widgetTypes = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetTypes)
local widgetStyles = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetStyles)

local module = {}

-- Compact line stats: jumps, spins, peak speed, climb
local function createCompactLine(): widgetTypes.Widget
	local jumpLabel: TextLabel? = nil
	local spinLabel: TextLabel? = nil
	local maxSpeedLabel: TextLabel? = nil
	local climbLabel: TextLabel? = nil
	local hoverCleanup: (() -> ())? = nil

	local maxSpeed: number = 0
	local lastAltitude: number = 0
	local totalClimb: number = 0

	local function createStrokedLabel(name: string, text: string, textColor: Color3, width: number): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Size = UDim2.fromOffset(width, 24)
		label.BackgroundTransparency = 1
		label.TextColor3 = textColor
		label.FontFace = fonts.GetFont(true, false)
		label.TextSize = 16
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextStrokeTransparency = 0.3
		label.TextStrokeColor3 = colors.black
		label.Text = text
		return label
	end

	local LABEL_WIDTHS = { 45, 70, 55, 55 }
	local PADDING = 12
	local CONTENT_WIDTH = 0
	for _, w in ipairs(LABEL_WIDTHS) do
		CONTENT_WIDTH = CONTENT_WIDTH + w
	end
	CONTENT_WIDTH = CONTENT_WIDTH + PADDING * (#LABEL_WIDTHS - 1)

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local frame = Instance.new("Frame")
			frame.Name = "StatsWidget_compact"
			frame.Size = UDim2.fromOffset(CONTENT_WIDTH, 26)
			frame.BackgroundTransparency = 1
			frame.BorderSizePixel = 0

			if position then
				frame.Position = position
				frame.AnchorPoint = Vector2.new(0.5, 0.5)
			end

			frame.Parent = parent

			hoverCleanup = widgetStyles.addHoverBorder(frame)

			local layout = Instance.new("UIListLayout")
			layout.FillDirection = Enum.FillDirection.Horizontal
			layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
			layout.VerticalAlignment = Enum.VerticalAlignment.Center
			layout.Padding = UDim.new(0, PADDING)
			layout.Parent = frame

			jumpLabel = createStrokedLabel("JumpLabel", "↑0", colors.orangeAccent, LABEL_WIDTHS[1])
			jumpLabel.Parent = frame

			spinLabel = createStrokedLabel("SpinLabel", "⟳0", widgetStyles.textColors.spins, LABEL_WIDTHS[2])
			spinLabel.Parent = frame

			maxSpeedLabel = createStrokedLabel("MaxSpeedLabel", "▲0", colors.lightGreen, LABEL_WIDTHS[3])
			maxSpeedLabel.Parent = frame

			climbLabel = createStrokedLabel("ClimbLabel", "△0", widgetStyles.textColors.altitude, LABEL_WIDTHS[4])
			climbLabel.Parent = frame

			return frame
		end,

		Destroy = function()
			if hoverCleanup then
				hoverCleanup()
				hoverCleanup = nil
			end
			jumpLabel = nil
			spinLabel = nil
			maxSpeedLabel = nil
			climbLabel = nil
		end,

		OnRunStart = function()
			maxSpeed = 0
			lastAltitude = 0
			totalClimb = 0

			local jl = jumpLabel
			local sl = spinLabel
			local ml = maxSpeedLabel
			local cl = climbLabel
			if jl then
				jl.Text = "↑0"
			end
			if sl then
				sl.Text = "⟳0"
			end
			if ml then
				ml.Text = "▲0"
			end
			if cl then
				cl.Text = "△0"
			end
		end,

		OnRunEnd = function()
			maxSpeed = 0
			totalClimb = 0
		end,

		UpdateSpeed = function(speed: number)
			if speed > maxSpeed then
				maxSpeed = speed
				if maxSpeedLabel then
					maxSpeedLabel.Text = string.format("▲%.0f", maxSpeed)
				end
			end
		end,

		UpdateJumpCount = function(count: number)
			if jumpLabel then
				jumpLabel.Text = "↑" .. tostring(count)
			end
		end,

		UpdateSpinCount = function(clockwise: number, counterClockwise: number)
			if spinLabel then
				local netSpin = clockwise - counterClockwise
				local total = clockwise + counterClockwise
				if total == 0 then
					spinLabel.Text = "⟳0"
				elseif netSpin > 0 then
					spinLabel.Text = string.format("↻%d(%+d)", total, netSpin)
				elseif netSpin < 0 then
					spinLabel.Text = string.format("↺%d(%+d)", total, netSpin)
				else
					spinLabel.Text = string.format("⟳%d", total)
				end
			end
		end,

		UpdateAltitude = function(altitude: number, _verticalVelocity: number)
			if lastAltitude > 0 and altitude > lastAltitude then
				totalClimb = totalClimb + (altitude - lastAltitude)
				if climbLabel then
					climbLabel.Text = string.format("△%.0f", totalClimb)
				end
			end
			lastAltitude = altitude
		end,
	})
end

-- Detailed stats panel
local function createDetailedPanel(): widgetTypes.Widget
	local container: Frame? = nil
	local labels: { [string]: TextLabel } = {}

	local startTick: number = 0
	local maxSpeed: number = 0
	local speedSum: number = 0
	local speedCount: number = 0
	local lastAltitude: number = 0
	local totalClimb: number = 0
	local totalDrop: number = 0

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local frame = Instance.new("Frame")
			frame.Name = "StatsWidget_detailed"
			frame.Position = position or UDim2.fromScale(0.1, 0.4)
			frame.Size = UDim2.fromOffset(160, 200)
			frame.AnchorPoint = Vector2.new(0.5, 0)
			frame.BackgroundColor3 = widgetStyles.containerBackground
			frame.BackgroundTransparency = 0.1
			frame.BorderSizePixel = widgetStyles.containerBorderSize
			frame.BorderColor3 = widgetStyles.containerBorderColor
			frame.Parent = parent
			container = frame

			widgetStyles.createTitleBar(frame, "Run Stats")

			local ROW_HEIGHT = 20
			local CONTENT_START = widgetStyles.TITLE_BAR_HEIGHT + 4

			local rows: { { key: string, label: string, color: Color3 } } = {
				{ key = "jumps", label = "Jumps", color = colors.orangeAccent },
				{ key = "jumpRate", label = "J/min", color = colors.orangeAccent },
				{ key = "spins", label = "Spins", color = widgetStyles.textColors.spins },
				{ key = "maxSpeed", label = "Peak", color = colors.lightGreen },
				{ key = "avgSpeed", label = "Avg", color = colors.blueDone },
				{ key = "climb", label = "Climb", color = widgetStyles.textColors.positive },
				{ key = "drop", label = "Drop", color = widgetStyles.textColors.negative },
				{ key = "efficiency", label = "Eff%", color = colors.meColor },
			}

			for i, row in ipairs(rows) do
				local y = CONTENT_START + (i - 1) * ROW_HEIGHT
				local valueLabel = widgetStyles.createStatRow(frame, row.label, "-", row.color, y, ROW_HEIGHT)
				labels[row.key] = valueLabel
			end

			return frame
		end,

		Destroy = function()
			if container then
				container:Destroy()
				container = nil
			end
			labels = {}
		end,

		OnRunStart = function(runStartTick: number)
			startTick = runStartTick
			maxSpeed = 0
			speedSum = 0
			speedCount = 0
			lastAltitude = 0
			totalClimb = 0
			totalDrop = 0

			for _, label in pairs(labels) do
				label.Text = "-"
			end
		end,

		UpdateSpeed = function(speed: number)
			if speed > maxSpeed then
				maxSpeed = speed
				if labels["maxSpeed"] then
					labels["maxSpeed"].Text = string.format("%.1f", maxSpeed)
				end
			end

			speedSum = speedSum + speed
			speedCount = speedCount + 1
			if labels["avgSpeed"] then
				labels["avgSpeed"].Text = string.format("%.1f", speedSum / speedCount)
			end
		end,

		UpdateJumpCount = function(count: number)
			if labels["jumps"] then
				labels["jumps"].Text = tostring(count)
			end

			local elapsed = tick() - startTick
			if elapsed > 0 and labels["jumpRate"] then
				labels["jumpRate"].Text = string.format("%.1f", (count / elapsed) * 60)
			end
		end,

		UpdateSpinCount = function(clockwise: number, counterClockwise: number)
			if labels["spins"] then
				local netSpin = clockwise - counterClockwise
				local total = clockwise + counterClockwise
				if total > 0 then
					if netSpin == total or netSpin == -total then
						labels["spins"].Text = (if netSpin >= 0 then "+" else "") .. tostring(netSpin)
					else
						labels["spins"].Text = string.format("%+d(%d)", netSpin, total)
					end
				else
					labels["spins"].Text = "0"
				end
			end
		end,

		UpdateAltitude = function(altitude: number, _verticalVelocity: number)
			if lastAltitude > 0 then
				local delta = altitude - lastAltitude
				if delta > 0 then
					totalClimb = totalClimb + delta
					if labels["climb"] then
						labels["climb"].Text = string.format("%.0f↑", totalClimb)
					end
				elseif delta < 0 then
					totalDrop = totalDrop + math.abs(delta)
					if labels["drop"] then
						labels["drop"].Text = string.format("%.0f↓", totalDrop)
					end
				end
			end
			lastAltitude = altitude
		end,

		UpdateDistance = function(fromStart: number, total: number)
			if labels["efficiency"] then
				if total > 1 then
					labels["efficiency"].Text = string.format("%.0f%%", math.min((fromStart / total) * 100, 100))
				else
					labels["efficiency"].Text = "-"
				end
			end
		end,
	})
end

-- Register all stats widgets
function module.Register(composer: { RegisterWidget: (string, string, () -> any) -> () })
	local category = widgetTypes.CATEGORIES.STATS
	composer.RegisterWidget(category, widgetTypes.STATS_STYLES.COMPACT_LINE, createCompactLine)
	composer.RegisterWidget(category, widgetTypes.STATS_STYLES.DETAILED_PANEL, createDetailedPanel)
	_annotate("Registered stats widgets")
end

_annotate("end")
return module
