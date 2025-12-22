--!strict
-- standardButton.lua @ ReplicatedStorage.gui.standardButton
-- Shared utility for creating standard game buttons with consistent styling.
-- Provides hover effects matching popup close buttons and run widget picker style.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local colors = require(game.ReplicatedStorage.util.colors)
local fonts = require(game.StarterPlayer.StarterPlayerScripts.guis.fonts)
local toolTip = require(game.ReplicatedStorage.gui.toolTip)

-- Standard UI constants
local BORDER_SIZE = 1
local MAX_TEXT_SIZE = 14
local MAX_TEXT_SIZE_BOLD = 24

type ButtonConfig = {
	text: string,
	onClick: () -> (),
	style: string?,
	isBold: boolean?,
	tooltip: string?,
	width: UDim?,
	height: UDim?,
	autoSize: boolean?, -- If true, button auto-sizes to fit text with padding
	padding: number?, -- Padding in pixels when autoSize is true (default: 6)
}

type StyleDef = { bg: Color3, text: Color3, hoverBg: Color3 }

type CloseButtonStyle = {
	bg: Color3,
	hoverBg: Color3,
	pressedBg: Color3,
	text: Color3,
	border: Color3,
}

type CloseButtonConfig = {
	onClick: () -> (),
	size: UDim2?,
	parent: GuiObject?,
	layoutOrder: number?,
}

type Module = {
	Create: (config: ButtonConfig) -> TextButton,
	CreateSimple: (text: string, onClick: () -> ()) -> TextButton,
	CreateCloseButton: (config: CloseButtonConfig) -> TextButton,
	STYLES: { [string]: StyleDef },
	CLOSE_BUTTON: CloseButtonStyle,
}

local module: Module = {} :: Module

-- Compute a brighter version of a color for hover
local function brighten(c: Color3, factor: number): Color3
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, s * 0.7, math.min(1, v + factor))
end

-- Compute a darker version of a color for pressed state
local function darken(c: Color3, factor: number): Color3
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, math.min(1, s * 1.1), math.max(0, v - factor))
end

-- Close button style - colors sourced from colors.lua
module.CLOSE_BUTTON = {
	bg = colors.closeButtonBg,
	hoverBg = colors.closeButtonHoverBg,
	pressedBg = darken(colors.closeButtonBg, 0.15),
	text = colors.white,
	border = colors.closeButtonBorder,
}

-- Style definitions
module.STYLES = {
	default = { bg = colors.defaultGrey, text = colors.black, hoverBg = brighten(colors.defaultGrey, 0.15) },
	primary = { bg = colors.blueDone, text = colors.black, hoverBg = brighten(colors.blueDone, 0.15) },
	danger = { bg = colors.redSlowDown, text = colors.white, hoverBg = brighten(colors.redSlowDown, 0.15) },
	success = { bg = colors.signColor, text = colors.white, hoverBg = brighten(colors.signColor, 0.15) },
}

local defaultStyle: StyleDef = module.STYLES.default

-- Create the standard Close button used across all modals and popups
-- Full width by default, red background, white bold text, with hover effect
module.CreateCloseButton = function(config: CloseButtonConfig): TextButton
	local style = module.CLOSE_BUTTON
	local button = Instance.new("TextButton")
	button.Name = "CloseButton"
	button.Size = config.size or UDim2.new(1, 0, 0, 30)
	button.BackgroundColor3 = style.bg
	button.BorderSizePixel = BORDER_SIZE
	button.BorderColor3 = style.border
	button.TextColor3 = style.text
	button.FontFace = fonts.GetFont(false, true) -- bold
	button.TextScaled = true
	button.Text = "Close"
	button.AutoButtonColor = false
	button.Active = true

	if config.layoutOrder then
		button.LayoutOrder = config.layoutOrder
	end

	if config.parent then
		button.Parent = config.parent
	end

	-- Text size constraint
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = MAX_TEXT_SIZE_BOLD
	constraint.Parent = button

	-- Track button state for proper colors
	local isHovering = false
	local isPressed = false

	local function updateColor()
		if isPressed then
			button.BackgroundColor3 = style.pressedBg
		elseif isHovering then
			button.BackgroundColor3 = style.hoverBg
		else
			button.BackgroundColor3 = style.bg
		end
	end

	-- Hover effect (instant)
	button.MouseEnter:Connect(function()
		isHovering = true
		updateColor()
	end)

	button.MouseLeave:Connect(function()
		isHovering = false
		isPressed = false
		updateColor()
	end)

	-- Pressed state
	button.MouseButton1Down:Connect(function()
		isPressed = true
		updateColor()
	end)

	button.MouseButton1Up:Connect(function()
		isPressed = false
		updateColor()
	end)

	-- Click handler
	button.Activated:Connect(config.onClick)

	return button
end

-- Create a standard button with full configuration
module.Create = function(config: ButtonConfig): TextButton
	local style = config.style or "default"
	local styleColors = module.STYLES[style] or defaultStyle
	local isBold = config.isBold or false
	local baseBg = styleColors.bg
	local hoverBg = styleColors.hoverBg

	local button = Instance.new("TextButton")
	button.BackgroundColor3 = baseBg
	button.BorderSizePixel = BORDER_SIZE
	button.BorderColor3 = colors.black
	button.TextColor3 = styleColors.text
	button.FontFace = fonts.GetFont(false, isBold)
	button.Text = config.text
	button.AutoButtonColor = false
	button.Active = true

	-- Size handling
	if config.autoSize then
		-- Auto-size mode: button sizes to fit text with uniform padding

		local padding = config.padding or 6
		button.AutomaticSize = Enum.AutomaticSize.XY
		button.TextScaled = false
		button.TextSize = isBold and MAX_TEXT_SIZE_BOLD or MAX_TEXT_SIZE

		local uiPadding = Instance.new("UIPadding")
		uiPadding.PaddingLeft = UDim.new(0, padding)
		uiPadding.PaddingRight = UDim.new(0, padding)
		uiPadding.PaddingTop = UDim.new(0, padding)
		uiPadding.PaddingBottom = UDim.new(0, padding)
		uiPadding.Parent = button
	elseif config.width or config.height then
		local w = config.width or UDim.new(0, 60)
		local h = config.height or UDim.new(0, 22)
		button.Size = UDim2.new(w.Scale, w.Offset, h.Scale, h.Offset)
		button.TextScaled = true
	else
		button.TextScaled = true
	end

	-- Text size constraint (only needed when TextScaled is true)
	if not config.autoSize then
		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MaxTextSize = isBold and MAX_TEXT_SIZE_BOLD or MAX_TEXT_SIZE
		constraint.Parent = button
	end

	-- Hover effect: brighten background
	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = hoverBg
	end)

	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = baseBg
	end)

	-- Click handler (use Activated for mouse + touch support)
	button.Activated:Connect(config.onClick)

	-- Tooltip
	if config.tooltip ~= nil and config.tooltip ~= "" then
		toolTip.setupToolTip(button, config.tooltip, toolTip.enum.toolTipSize.NormalText)
	end

	return button
end

-- Simplified creation for basic buttons
module.CreateSimple = function(text: string, onClick: () -> ()): TextButton
	return module.Create({
		text = text,
		onClick = onClick,
		style = "default",
	})
end

_annotate("end")
return module
