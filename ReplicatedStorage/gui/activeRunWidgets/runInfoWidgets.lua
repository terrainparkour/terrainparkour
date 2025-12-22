--!strict
-- runInfoWidgets.lua (ReplicatedStorage/gui/activeRunWidgets/runInfoWidgets.lua)
-- Run info (sign name + description) widget implementations.
-- ALL variants include an expandable description area - variations are in sign name display style.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local colors = require(game.ReplicatedStorage.util.colors)
local fonts = require(game.StarterPlayer.StarterPlayerScripts.guis.fonts)
local widgetTypes = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetTypes)
local widgetStyles = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetStyles)

local module = {}

local DESC_HEIGHT = 28
local DESC_GAP = 4

local function createDescriptionLabel(parent: Frame, yOffset: number): TextLabel
	local desc = Instance.new("TextLabel")
	desc.Name = "DescLabel"
	desc.Size = UDim2.new(1, 0, 0, DESC_HEIGHT)
	desc.Position = UDim2.fromOffset(0, yOffset)
	desc.BackgroundTransparency = 1
	desc.TextColor3 = colors.orangeAccent
	desc.FontFace = fonts.GetFont(false, false)
	desc.TextSize = 14
	desc.TextWrapped = true
	desc.TextXAlignment = Enum.TextXAlignment.Center
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.TextStrokeTransparency = 0.3
	desc.TextStrokeColor3 = colors.black
	desc.Text = ""
	desc.Parent = parent
	return desc
end

--------------------------------------------------------------------------------
-- Viewport: 3D red granite sign
--------------------------------------------------------------------------------
local function createViewport(): widgetTypes.Widget
	local container: Frame? = nil
	local signLabel: TextLabel? = nil
	local descLabel: TextLabel? = nil
	local visible: boolean = true
	local signCleanup: (() -> ())? = nil
	local hoverCleanup: (() -> ())? = nil
	local resizeCleanup: (() -> ())? = nil

	local FROM_WIDTH = 40
	local DEFAULT_SIGN_WIDTH = 160
	local SIGN_HEIGHT = 32
	local MIN_WIDTH = 120
	local MAX_WIDTH = 350
	local MIN_HEIGHT = 60
	local MAX_HEIGHT = 150

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?, context: widgetTypes.WidgetCreateContext?): Frame?
			local frameWidth = FROM_WIDTH + DEFAULT_SIGN_WIDTH
			local frameHeight = SIGN_HEIGHT + DESC_GAP + DESC_HEIGHT
			if context and context.savedSize then
				frameWidth = context.savedSize.width
				frameHeight = context.savedSize.height
			end

			local frame = Instance.new("Frame")
			frame.Name = "RunInfoWidget_viewport"
			frame.Size = UDim2.fromOffset(frameWidth, frameHeight)
			frame.BackgroundTransparency = 1
			frame.BorderSizePixel = 0
			frame.Visible = false

			if position then
				frame.Position = position
				frame.AnchorPoint = Vector2.new(0.5, 0)
			end

			frame.Parent = parent
			container = frame

			hoverCleanup = widgetStyles.addHoverBorder(frame)

			local fromLabel = Instance.new("TextLabel")
			fromLabel.Name = "FromLabel"
			fromLabel.Size = UDim2.fromOffset(FROM_WIDTH, SIGN_HEIGHT)
			fromLabel.Position = UDim2.fromOffset(0, 0)
			fromLabel.BackgroundTransparency = 1
			fromLabel.TextColor3 = colors.white
			fromLabel.FontFace = fonts.GetFont(false, true)
			fromLabel.TextSize = 16
			fromLabel.TextXAlignment = Enum.TextXAlignment.Right
			fromLabel.TextYAlignment = Enum.TextYAlignment.Center
			fromLabel.TextStrokeTransparency = 0.2
			fromLabel.TextStrokeColor3 = colors.black
			fromLabel.Text = "from"
			fromLabel.Parent = frame

			local signResult = widgetStyles.createSignViewport({
				name = "SignViewport",
				size = UDim2.new(1, -FROM_WIDTH - 4, 0, SIGN_HEIGHT),
			})
			signResult.frame.Position = UDim2.fromOffset(FROM_WIDTH + 4, 0)
			signResult.frame.ClipsDescendants = true
			signResult.frame.Parent = frame
			signLabel = signResult.textLabel
			signCleanup = signResult.cleanup

			if signLabel then
				signLabel.TextTruncate = Enum.TextTruncate.AtEnd
				signLabel.ClipsDescendants = true
			end

			descLabel = createDescriptionLabel(frame, SIGN_HEIGHT + DESC_GAP)

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
				-- No onSizeChanged needed - children use scale-based sizing
				onResizeEnd = if context and context.onSaveSize then context.onSaveSize else nil,
			})
			resizeCleanup = cleanup

			local resizeHandle = frame:FindFirstChild("ResizeHandle")
			if resizeHandle and resizeHandle:IsA("GuiButton") then
				resizeHandle.BackgroundTransparency = 1
				for _, child in ipairs(resizeHandle:GetChildren()) do
					if child:IsA("Frame") then
						child.BackgroundTransparency = 1
					end
				end
			end

			return frame
		end,

		Destroy = function()
			if signCleanup then
				signCleanup()
				signCleanup = nil
			end
			if hoverCleanup then
				hoverCleanup()
				hoverCleanup = nil
			end
			if resizeCleanup then
				resizeCleanup()
				resizeCleanup = nil
			end
			if container then
				container:Destroy()
				container = nil
			end
			signLabel = nil
			descLabel = nil
		end,

		SetVisible = function(vis: boolean)
			visible = vis
			if container then
				container.Visible = vis
			end
		end,

		IsVisible = function(): boolean
			return visible
		end,

		OnRunStart = function(_startTick: number, signName: string)
			if container then
				container.Visible = true
			end
			if signLabel then
				signLabel.Text = signName
			end
			if descLabel then
				descLabel.Text = ""
			end
		end,

		OnRunEnd = function()
			if container then
				container.Visible = false
			end
			if signLabel then
				signLabel.Text = ""
			end
			if descLabel then
				descLabel.Text = ""
			end
		end,

		UpdateDescription = function(description: string)
			if descLabel then
				descLabel.Text = description
			end
		end,
	})
end

--------------------------------------------------------------------------------
-- Classic: Red background bar
--------------------------------------------------------------------------------
local function createClassic(): widgetTypes.Widget
	local container: Frame? = nil
	local signLabel: TextLabel? = nil
	local descLabel: TextLabel? = nil
	local visible: boolean = true
	local hoverCleanup: (() -> ())? = nil

	local MIN_WIDTH = 100
	local SIGN_HEIGHT = 28
	local PADDING = 12

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local frame = Instance.new("Frame")
			frame.Name = "RunInfoWidget_classic"
			frame.AutomaticSize = Enum.AutomaticSize.X
			frame.Size = UDim2.fromOffset(MIN_WIDTH, SIGN_HEIGHT + DESC_GAP + DESC_HEIGHT)
			frame.BackgroundTransparency = 1
			frame.BorderSizePixel = 0
			frame.Visible = false

			if position then
				frame.Position = position
				frame.AnchorPoint = Vector2.new(0.5, 0)
			end

			frame.Parent = parent
			container = frame

			hoverCleanup = widgetStyles.addHoverBorder(frame)

			local bar = Instance.new("Frame")
			bar.Name = "SignBar"
			bar.AutomaticSize = Enum.AutomaticSize.X
			bar.Size = UDim2.fromOffset(MIN_WIDTH, SIGN_HEIGHT)
			bar.Position = UDim2.fromOffset(0, 0)
			bar.BackgroundColor3 = colors.signColor
			bar.BorderSizePixel = 0
			bar.Parent = frame

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 4)
			corner.Parent = bar

			local padding = Instance.new("UIPadding")
			padding.PaddingLeft = UDim.new(0, PADDING)
			padding.PaddingRight = UDim.new(0, PADDING)
			padding.Parent = bar

			local label = Instance.new("TextLabel")
			label.Name = "SignLabel"
			label.AutomaticSize = Enum.AutomaticSize.X
			label.Size = UDim2.fromScale(0, 1)
			label.BackgroundTransparency = 1
			label.TextColor3 = colors.signTextColor
			label.FontFace = fonts.GetFont(false, true)
			label.TextSize = 18
			label.TextXAlignment = Enum.TextXAlignment.Center
			label.TextYAlignment = Enum.TextYAlignment.Center
			label.Text = ""
			label.Parent = bar
			signLabel = label

			descLabel = createDescriptionLabel(frame, SIGN_HEIGHT + DESC_GAP)

			return frame
		end,

		Destroy = function()
			if hoverCleanup then
				hoverCleanup()
				hoverCleanup = nil
			end
			if container then
				container:Destroy()
				container = nil
			end
			signLabel = nil
			descLabel = nil
		end,

		SetVisible = function(vis: boolean)
			visible = vis
			if container then
				container.Visible = vis
			end
		end,

		IsVisible = function(): boolean
			return visible
		end,

		OnRunStart = function(_startTick: number, signName: string)
			if container then
				container.Visible = true
			end
			if signLabel then
				signLabel.Text = "from " .. signName
			end
			if descLabel then
				descLabel.Text = ""
			end
		end,

		OnRunEnd = function()
			if container then
				container.Visible = false
			end
			if signLabel then
				signLabel.Text = ""
			end
			if descLabel then
				descLabel.Text = ""
			end
		end,

		UpdateDescription = function(description: string)
			if descLabel then
				descLabel.Text = description
			end
		end,
	})
end

--------------------------------------------------------------------------------
-- Text variants
--------------------------------------------------------------------------------
local function createTextVariant(textColor: Color3, fontSize: number, widgetName: string): widgetTypes.Widget
	local container: Frame? = nil
	local signLabel: TextLabel? = nil
	local descLabel: TextLabel? = nil
	local visible: boolean = true
	local cleanupFn: (() -> ())? = nil

	local SIGN_WIDTH = if fontSize >= 28 then 240 else 180
	local SIGN_HEIGHT = if fontSize >= 28 then 40 else 28

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local frame = Instance.new("Frame")
			frame.Name = widgetName
			frame.Size = UDim2.fromOffset(SIGN_WIDTH, SIGN_HEIGHT + DESC_GAP + DESC_HEIGHT)
			frame.BackgroundTransparency = 1
			frame.BorderSizePixel = 0
			frame.Visible = false

			if position then
				frame.Position = position
				frame.AnchorPoint = Vector2.new(0.5, 0)
			end

			frame.Parent = parent
			container = frame

			cleanupFn = widgetStyles.addHoverBorder(frame)

			local label = Instance.new("TextLabel")
			label.Name = "SignLabel"
			label.Size = UDim2.new(1, 0, 0, SIGN_HEIGHT)
			label.Position = UDim2.fromOffset(0, 0)
			label.BackgroundTransparency = 1
			label.TextColor3 = textColor
			label.FontFace = fonts.GetFont(false, true)
			label.TextSize = fontSize
			label.TextScaled = false
			label.TextXAlignment = Enum.TextXAlignment.Center
			label.TextYAlignment = Enum.TextYAlignment.Center
			label.TextStrokeTransparency = 0.2
			label.TextStrokeColor3 = colors.black
			label.TextTruncate = Enum.TextTruncate.AtEnd
			label.Text = ""
			label.Parent = frame
			signLabel = label

			descLabel = createDescriptionLabel(frame, SIGN_HEIGHT + DESC_GAP)

			return frame
		end,

		Destroy = function()
			if cleanupFn then
				cleanupFn()
				cleanupFn = nil
			end
			if container then
				container:Destroy()
				container = nil
			end
			signLabel = nil
			descLabel = nil
		end,

		SetVisible = function(vis: boolean)
			visible = vis
			if container then
				container.Visible = vis
			end
		end,

		IsVisible = function(): boolean
			return visible
		end,

		OnRunStart = function(_startTick: number, signName: string)
			if container then
				container.Visible = true
			end
			if signLabel then
				signLabel.Text = "from " .. signName
			end
			if descLabel then
				descLabel.Text = ""
			end
		end,

		OnRunEnd = function()
			if container then
				container.Visible = false
			end
			if signLabel then
				signLabel.Text = ""
			end
			if descLabel then
				descLabel.Text = ""
			end
		end,

		UpdateDescription = function(description: string)
			if descLabel then
				descLabel.Text = description
			end
		end,
	})
end

local function createWhiteLarge(): widgetTypes.Widget
	return createTextVariant(colors.white, 32, "RunInfoWidget_whiteL")
end

local function createWhiteSmall(): widgetTypes.Widget
	return createTextVariant(colors.white, 18, "RunInfoWidget_whiteS")
end

local function createYellowLarge(): widgetTypes.Widget
	return createTextVariant(colors.meColor, 32, "RunInfoWidget_yellowL")
end

local function createYellowSmall(): widgetTypes.Widget
	return createTextVariant(colors.meColor, 18, "RunInfoWidget_yellowS")
end

--------------------------------------------------------------------------------
-- Register all run info widgets
--------------------------------------------------------------------------------
function module.Register(composer: { RegisterWidget: (string, string, () -> any) -> () })
	local category = widgetTypes.CATEGORIES.RUN_INFO
	local styles = widgetTypes.RUN_INFO_STYLES

	composer.RegisterWidget(category, styles.VIEWPORT, createViewport)
	composer.RegisterWidget(category, styles.CLASSIC, createClassic)
	composer.RegisterWidget(category, styles.WHITE_L, createWhiteLarge)
	composer.RegisterWidget(category, styles.WHITE_S, createWhiteSmall)
	composer.RegisterWidget(category, styles.YELLOW_L, createYellowLarge)
	composer.RegisterWidget(category, styles.YELLOW_S, createYellowSmall)

	_annotate("Registered run info widgets")
end

_annotate("end")
return module
