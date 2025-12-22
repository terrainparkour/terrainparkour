--!strict

--2022 centralize to this game's ui style.
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local function applyUniformPadding(target: GuiObject, padding: number?)
	if not padding or padding <= 0 then
		return
	end

	local padValue = UDim.new(0, padding)
	local paddingInstance = Instance.new("UIPadding")
	paddingInstance.PaddingLeft = padValue
	paddingInstance.PaddingRight = padValue
	paddingInstance.PaddingTop = padValue
	paddingInstance.PaddingBottom = padValue
	paddingInstance.Parent = target
end

--get a tl, put it into parent with padding, return inner thing for further work

module.getTl = function(
	name: string,
	size: UDim2,
	padding: number,
	parent: Frame | ScrollingFrame | nil,
	bgcolor: Color3,
	borderSizePixel: number?,
	transparency: number?,
	automaticSize: Enum.AutomaticSize?,
	useTextSize: number?, -- Optional: use fixed TextSize instead of TextScaled
	flat: boolean? -- Optional: create flat label without nested structure
): TextLabel
	if transparency == nil then
		transparency = 0
	end

	-- Flat label creation (no nesting)
	if flat then
		local tl = Instance.new("TextLabel")
		tl.ZIndex = 1
		tl.Size = size
		tl.Parent = parent
		tl.Name = name
		tl.BackgroundColor3 = bgcolor
		tl.BorderMode = Enum.BorderMode.Inset
		tl.BorderSizePixel = 1
		tl.BackgroundTransparency = transparency or 0
		tl.AutoLocalize = true

		if borderSizePixel ~= nil then
			tl.BorderSizePixel = borderSizePixel
		end

		if automaticSize ~= nil then
			tl.AutomaticSize = automaticSize
		end

		-- Use TextSize if specified, otherwise TextScaled
		if useTextSize then
			tl.TextSize = useTextSize
		else
			tl.TextScaled = true
		end

		tl.Font = Enum.Font.Gotham
		return tl
	end

	-- Nested label creation (default behavior)
	local tl = Instance.new("TextLabel")
	tl.ZIndex = 1
	tl.TextTransparency = 1
	tl.Size = size
	tl.Parent = parent
	tl.Name = name
	tl.BackgroundColor3 = bgcolor
	tl.BorderMode = Enum.BorderMode.Inset
	tl.BorderSizePixel = 1
	tl.BackgroundTransparency = transparency or 0
	if automaticSize ~= nil then
		tl.AutomaticSize = automaticSize
	end

	if borderSizePixel ~= nil then
		tl.BorderSizePixel = borderSizePixel
	end

	local innerTl = Instance.new("TextLabel")
	innerTl.Parent = tl
	innerTl.ZIndex = 2
	innerTl.Name = "Inner"
	innerTl.Font = Enum.Font.Gotham
	innerTl.Size = UDim2.fromScale(1, 1)
	innerTl.Position = UDim2.fromScale(0, 0)
	innerTl.BackgroundColor3 = bgcolor
	innerTl.BorderSizePixel = 0
	innerTl.AutoLocalize = true
	applyUniformPadding(innerTl, padding)
	if transparency ~= 0 then
		innerTl.BackgroundTransparency = 1
	end

	-- Use TextSize if specified, otherwise TextScaled
	if useTextSize then
		innerTl.TextSize = useTextSize
	else
		innerTl.TextScaled = true
	end

	return innerTl
end

-- DEPRECATED: Use standardButton.Create() from gui.standardButton instead.
-- This function creates nested inner/outer structure which is inconsistent
-- with modern UI patterns. standardButton provides:
-- - Consistent styling with STYLES table (default, primary, danger, success)
-- - Built-in hover effects
-- - Tooltip integration
-- - Cleaner single-element structure
function module.createTextButton(
	name: string,
	size: UDim2,
	padding: number,
	parent: Frame | ScrollingFrame | nil,
	text: string?,
	textColor: Color3?,
	font: Enum.Font?,
	textSize: number?
): TextButton
	local button = Instance.new("TextButton")
	button.ZIndex = 1
	button.TextTransparency = 1
	button.Size = size
	button.Parent = parent
	button.Name = name
	button.BackgroundColor3 = Color3.fromRGB(70, 70, 70) -- Default button color
	button.BorderMode = Enum.BorderMode.Inset
	button.BorderSizePixel = 1
	button.BackgroundTransparency = 0
	button.AutoButtonColor = true

	local innerButton = Instance.new("TextButton")
	innerButton.Parent = button
	innerButton.ZIndex = 2
	innerButton.Name = "Inner"
	local appliedFont: Enum.Font = font or Enum.Font.Gotham
	innerButton.Font = appliedFont
	innerButton.TextSize = textSize or 14 -- Default text size for buttons
	innerButton.Text = text or ""
	innerButton.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
	innerButton.Size = UDim2.fromScale(1, 1)
	innerButton.Position = UDim2.fromScale(0, 0)
	innerButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	innerButton.BorderSizePixel = 0
	innerButton.AutoButtonColor = true
	applyUniformPadding(innerButton, padding)

	return innerButton
end

-- DEPRECATED: Use standardButton.Create() from gui.standardButton instead.
-- This creates an unstyled button without hover effects or consistent theming.
module.getTbSimple = function(): TextButton
	local tl = Instance.new("TextButton")
	tl.TextScaled = true
	tl.Font = Enum.Font.Gotham
	tl.Size = UDim2.new(1, 0, 1, 0)
	tl.BorderMode = Enum.BorderMode.Outline
	tl.BorderSizePixel = 1
	return tl
end

-- DEPRECATED: Use standardButton.Create() from gui.standardButton instead.
-- This function creates nested inner/outer structure. standardButton provides
-- hover effects, consistent styling, and tooltip support.
function module.getPaddedButton(
	name: string,
	size: UDim2,
	padding: number,
	parent: Frame | ScrollingFrame | nil,
	bgcolor: Color3,
	borderSizePixel: number?,
	transparency: number?
): TextButton
	if transparency == nil then
		transparency = 0
	end

	local outerTb = Instance.new("TextButton")
	outerTb.ZIndex = 1
	outerTb.TextTransparency = 1
	outerTb.Size = size
	outerTb.Parent = parent
	outerTb.Name = name
	outerTb.BackgroundColor3 = bgcolor
	outerTb.BorderMode = Enum.BorderMode.Inset
	outerTb.BorderSizePixel = 1

	outerTb.BackgroundTransparency = transparency or 0

	if borderSizePixel ~= nil then
		outerTb.BorderSizePixel = borderSizePixel
		outerTb.BorderMode = Enum.BorderMode.Outline
	end

	local innerTb = Instance.new("TextButton")
	innerTb.Parent = outerTb
	innerTb.TextScaled = true
	innerTb.ZIndex = 2
	innerTb.Name = "Inner"
	innerTb.Font = Enum.Font.Gotham
	innerTb.Size = UDim2.fromScale(1, 1)
	innerTb.Position = UDim2.fromScale(0, 0)
	innerTb.BackgroundColor3 = bgcolor
	innerTb.BorderSizePixel = 0
	innerTb.BorderMode = Enum.BorderMode.Inset
	applyUniformPadding(innerTb, padding)
	if transparency ~= 0 then
		innerTb.BackgroundTransparency = 1
	end
	return innerTb
end

module.getTb = module.createTextButton

--kill a sgui with an invisible textbutton on top of it.
--shrinkYScale is to leave room for a warper or other button at the bottom.
--IS used for runresults, not used for find
module.setupKillOnClick = function(sgui: ScreenGui, excludeElementName: string?, actualExcludedFrame: Frame?)
	local invisibleCloseModalButton = Instance.new("TextButton")
	local mainFrame = sgui:FindFirstChildOfClass("Frame") :: Frame
	if not mainFrame then
		annotater.Error("no mainiframe.'")
	end
	invisibleCloseModalButton.Position = mainFrame.Position
	invisibleCloseModalButton.Size = mainFrame.Size
	invisibleCloseModalButton.Name = "invisibleCloseModalButton"
	invisibleCloseModalButton.Transparency = 1.0
	invisibleCloseModalButton.Text = "kill but can't see"
	invisibleCloseModalButton.TextScaled = true
	invisibleCloseModalButton.Parent = sgui
	invisibleCloseModalButton.Activated:Connect(function()
		sgui:Destroy()
	end)
	invisibleCloseModalButton.ZIndex = 10
end

--pixel-sized udim creator
module.p = function(xpixel: number, ypixel: number): UDim2
	return UDim2.new(0, xpixel, 0, ypixel)
end

--scaled udim creator
module.s = function(xscale: number, yscale: number): UDim2
	return UDim2.new(xscale, 0, yscale, 0)
end

-- Clamp a frame position to stay within screen bounds
-- position: The proposed position as UDim2 offset values
-- frameWidth: Width of the frame in pixels
-- frameHeight: Height of the frame in pixels
-- padding: Optional padding from screen edges (default 0)
-- Returns: Clamped position as UDim2.fromOffset
function module.clampPositionToScreen(
	position: UDim2,
	frameWidth: number,
	frameHeight: number,
	padding: number?
): UDim2
	local camera = workspace.CurrentCamera
	if not camera then
		return position
	end
	local viewportSize = camera.ViewportSize
	local pad = padding or 0

	local xPos = position.X.Offset
	local yPos = position.Y.Offset

	xPos = math.clamp(xPos, pad, viewportSize.X - frameWidth - pad)
	yPos = math.clamp(yPos, pad, viewportSize.Y - frameHeight - pad)

	return UDim2.fromOffset(xPos, yPos)
end

-- Clamp position from mouse location (for tooltips, popups)
-- mouseX, mouseY: Current mouse position
-- frameWidth, frameHeight: Size of element to position
-- preferRight: If true, prefer positioning to right/bottom of mouse
-- padding: Padding from screen edges
function module.clampTooltipPosition(
	mouseX: number,
	mouseY: number,
	frameWidth: number,
	frameHeight: number,
	preferRight: boolean?,
	padding: number?
): UDim2
	local camera = workspace.CurrentCamera
	if not camera then
		return UDim2.fromOffset(mouseX, mouseY)
	end
	local viewportSize = camera.ViewportSize
	local pad = padding or 10

	local xPos: number
	local yPos: number

	if preferRight == nil or preferRight then
		xPos = mouseX + pad
		yPos = mouseY + pad
	else
		xPos = mouseX - frameWidth - pad
		yPos = mouseY + pad
	end

	-- Ensure doesn't go off-screen
	xPos = math.clamp(xPos, 0, viewportSize.X - frameWidth)
	yPos = math.clamp(yPos, 0, viewportSize.Y - frameHeight)

	return UDim2.fromOffset(xPos, yPos)
end

_annotate("end")
return module
