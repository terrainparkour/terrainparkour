--!strict
-- distanceWidgets.lua (ReplicatedStorage/gui/activeRunWidgets/distanceWidgets.lua)
-- Distance display widget implementations.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local colors = require(game.ReplicatedStorage.util.colors)
local fonts = require(game.StarterPlayer.StarterPlayerScripts.guis.fonts)
local widgetTypes = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetTypes)
local widgetStyles = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetStyles)

local module = {}

-- Standard distance widget sizes (match speed widget proportions)
local SINGLE_WIDTH = 120
local SINGLE_HEIGHT = 36
local DUAL_WIDTH = 120
local DUAL_HEIGHT = 60

-- Distance from start only - transparent with stroked text
local function createFromStartDistance(): widgetTypes.Widget
	local distLabel: TextLabel? = nil
	local cleanupFn: (() -> ())? = nil

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local result = widgetStyles.createTransparentLabel({
				name = "DistanceWidget_fromStart",
				size = UDim2.fromOffset(SINGLE_WIDTH, SINGLE_HEIGHT),
				position = position or UDim2.fromScale(0.5, 0.88),
				text = "↔ 0d",
				textColor = colors.blueDone,
				fontSize = 24,
				fontMono = true,
				fontBold = true,
				xAlignment = Enum.TextXAlignment.Center,
			})
			result.frame.Parent = parent
			distLabel = result.label
			cleanupFn = result.cleanup
			return result.frame
		end,

		Destroy = function()
			if cleanupFn then
				cleanupFn()
				cleanupFn = nil
			end
			distLabel = nil
		end,

		OnRunStart = function()
			if distLabel then
				distLabel.Text = "↔ 0d"
			end
		end,

		UpdateDistance = function(fromStart: number, _total: number)
			if distLabel then
				distLabel.Text = string.format("↔ %.0fd", fromStart)
			end
		end,
	})
end

-- Total distance only - transparent with stroked text
local function createTotalDistance(): widgetTypes.Widget
	local distLabel: TextLabel? = nil
	local cleanupFn: (() -> ())? = nil

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local result = widgetStyles.createTransparentLabel({
				name = "DistanceWidget_total",
				size = UDim2.fromOffset(SINGLE_WIDTH, SINGLE_HEIGHT),
				position = position or UDim2.fromScale(0.5, 0.88),
				text = "∑ 0d",
				textColor = colors.grey,
				fontSize = 24,
				fontMono = true,
				fontBold = true,
				xAlignment = Enum.TextXAlignment.Center,
			})
			result.frame.Parent = parent
			distLabel = result.label
			cleanupFn = result.cleanup
			return result.frame
		end,

		Destroy = function()
			if cleanupFn then
				cleanupFn()
				cleanupFn = nil
			end
			distLabel = nil
		end,

		OnRunStart = function()
			if distLabel then
				distLabel.Text = "∑ 0d"
			end
		end,

		UpdateDistance = function(_fromStart: number, total: number)
			if distLabel then
				distLabel.Text = string.format("∑ %.0fd", total)
			end
		end,
	})
end

-- Combined distance display (both from start and total) - transparent stacked labels
local function createCombinedDistance(): widgetTypes.Widget
	local fromStartLabel: TextLabel? = nil
	local totalLabel: TextLabel? = nil
	local hoverCleanup: (() -> ())? = nil

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local frame = Instance.new("Frame")
			frame.Name = "DistanceWidget_combined"
			frame.Size = UDim2.fromOffset(DUAL_WIDTH, DUAL_HEIGHT)
			frame.BackgroundTransparency = 1
			frame.BorderSizePixel = 0

			if position then
				frame.Position = position
				frame.AnchorPoint = Vector2.new(0.5, 0.5)
			end

			frame.Parent = parent

			hoverCleanup = widgetStyles.addHoverBorder(frame)

			local fromLabel = Instance.new("TextLabel")
			fromLabel.Name = "FromStartLabel"
			fromLabel.Size = UDim2.new(1, 0, 0.55, 0)
			fromLabel.Position = UDim2.fromOffset(0, 0)
			fromLabel.BackgroundTransparency = 1
			fromLabel.TextColor3 = colors.blueDone
			fromLabel.FontFace = fonts.GetFont(true, true)
			fromLabel.TextSize = 24
			fromLabel.TextXAlignment = Enum.TextXAlignment.Center
			fromLabel.TextStrokeTransparency = 0.3
			fromLabel.TextStrokeColor3 = colors.black
			fromLabel.Text = "↔ 0d"
			fromLabel.Parent = frame
			fromStartLabel = fromLabel

			local totLabel = Instance.new("TextLabel")
			totLabel.Name = "TotalLabel"
			totLabel.Size = UDim2.new(1, 0, 0.45, 0)
			totLabel.Position = UDim2.fromScale(0, 0.55)
			totLabel.BackgroundTransparency = 1
			totLabel.TextColor3 = colors.grey
			totLabel.FontFace = fonts.GetFont(true, false)
			totLabel.TextSize = 18
			totLabel.TextXAlignment = Enum.TextXAlignment.Center
			totLabel.TextStrokeTransparency = 0.3
			totLabel.TextStrokeColor3 = colors.black
			totLabel.Text = "∑ 0d"
			totLabel.Parent = frame
			totalLabel = totLabel

			return frame
		end,

		Destroy = function()
			if hoverCleanup then
				hoverCleanup()
				hoverCleanup = nil
			end
			fromStartLabel = nil
			totalLabel = nil
		end,

		OnRunStart = function()
			if fromStartLabel then
				fromStartLabel.Text = "↔ 0d"
			end
			if totalLabel then
				totalLabel.Text = "∑ 0d"
			end
		end,

		UpdateDistance = function(fromStart: number, total: number)
			if fromStartLabel then
				fromStartLabel.Text = string.format("↔ %.0fd", fromStart)
			end
			if totalLabel then
				totalLabel.Text = string.format("∑ %.0fd", total)
			end
		end,
	})
end

-- Register all distance widgets
function module.Register(composer: { RegisterWidget: (string, string, () -> any) -> () })
	local category = widgetTypes.CATEGORIES.DISTANCE
	composer.RegisterWidget(category, widgetTypes.DISTANCE_STYLES.FROM_START, createFromStartDistance)
	composer.RegisterWidget(category, widgetTypes.DISTANCE_STYLES.TOTAL, createTotalDistance)
	composer.RegisterWidget(category, widgetTypes.DISTANCE_STYLES.COMBINED, createCombinedDistance)
	_annotate("Registered distance widgets")
end

_annotate("end")
return module
