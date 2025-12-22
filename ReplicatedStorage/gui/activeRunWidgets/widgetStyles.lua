--!strict
-- widgetStyles.lua (ReplicatedStorage/gui/activeRunWidgets/widgetStyles.lua)
-- Centralized style definitions for active run widgets.
-- This module allows easy adjustment of the overall widget aesthetic
-- while maintaining consistency with the game's color scheme.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local colors = require(game.ReplicatedStorage.util.colors)

local localPlayer = Players.LocalPlayer
local fonts = require(game.StarterPlayer.StarterPlayerScripts.guis.fonts)

local module = {}

-- Resize handle constants
local RESIZE_HANDLE_SIZE = 16
local RESIZE_GRIP_COLOR = colors.white
local RESIZE_GRIP_TRANSPARENCY = 0.5
local RESIZE_BG_COLOR = colors.signColor
local RESIZE_BG_TRANSPARENCY = 0.5

-- Hover border constants
local HOVER_BORDER_COLOR = colors.signColor
local HOVER_BORDER_THICKNESS = 1
local HOVER_BORDER_TRANSPARENCY = 0.3

-- Widget container styles
-- These are semi-transparent HUD overlays, so they intentionally differ
-- from the solid game menu style to avoid obstructing gameplay view.
module.containerBackground = colors.black -- Dark background using game color
module.containerTransparency = 0.25 -- Semi-transparent for HUD overlay
module.containerBorderColor = colors.black
module.containerBorderSize = 1

-- Whether to use rounded corners on widgets (false = match game style)
module.useRoundedCorners = false
module.cornerRadius = UDim.new(0, 4)

-- Text colors mapped to semantic meaning (all from colors.lua)
module.textColors = {
	timer = colors.meColor, -- Yellow for time (matches "me" color for personal data)
	speed = colors.blueDone, -- Cyan for speed
	distance = colors.blueDone, -- Cyan for distance
	altitude = colors.warpColor, -- Light blue for altitude
	jumps = colors.orangeAccent, -- Orange for jumps
	spins = colors.magenta, -- Magenta for spins (from colors.lua)
	maxSpeed = colors.lightGreen, -- Green for max/best values
	avgSpeed = colors.blueDone, -- Cyan for averages
	negative = colors.lightRed, -- Red for decreases/losses
	positive = colors.lightGreen, -- Green for increases/gains
	neutral = colors.defaultGrey, -- Grey for neutral values
	label = colors.white, -- White for labels
	signName = colors.white, -- White text on sign background
}

-- Background colors for different widget types (all from colors.lua)
module.backgrounds = {
	timer = colors.signColor, -- Red for sign/timer accent
	speed = colors.black, -- Dark background
	stats = colors.black, -- Dark background
	terrain = colors.black, -- Dark background
	signInfo = colors.signColor, -- Red for sign info
	accent = colors.signColor, -- Accent color for highlights
	gaugeCenter = colors.grey, -- Gauge center cap
}

-- Font settings
module.fonts = {
	timer = fonts.GetFont(true, true), -- Monospaced bold for timer
	speed = fonts.GetFont(true, true), -- Monospaced bold for speed
	stats = fonts.GetFont(true, false), -- Monospaced for stats
	labels = fonts.GetFont(false, true), -- Regular bold for labels
	normal = fonts.GetFont(false, false), -- Regular for descriptions
}

-- Standard text sizes (these work well for HUD overlay readability)
module.textSizes = {
	large = 28, -- Large timer display
	medium = 20, -- Speed, main values
	normal = 16, -- Standard text
	small = 12, -- Labels, secondary info
	tiny = 10, -- Very small annotations
}

-- Standard units (always use these for consistency)
module.SPEED_UNIT = "d/s"
module.TIME_UNIT = "s"
module.DISTANCE_UNIT = "d"

-- Format speed with unit (always shows 1 decimal place)
function module.formatSpeed(speed: number): string
	return string.format("%.1f %s", speed, module.SPEED_UNIT)
end

-- Format time with unit (always shows 1 decimal place)
-- NOTE: This takes seconds (not milliseconds) and is designed for HUD real-time display.
-- For millisecond-based race times, use tpUtil.fmtms or tpUtil.fmtmsWithUnit instead.
function module.formatTime(seconds: number): string
	return string.format("%.1f%s", seconds, module.TIME_UNIT)
end

-- Format distance with unit (always shows 1 decimal place)
function module.formatDistance(distance: number): string
	return string.format("%.1f%s", distance, module.DISTANCE_UNIT)
end

-- Format acceleration with unit (d/s²)
function module.formatAcceleration(accel: number): string
	return string.format("%.1f d/s²", accel)
end

-- Format altitude with unit (always shows 1 decimal place, ↕ suffix)
function module.formatAltitude(altitude: number): string
	return string.format("%.1f↕", altitude)
end

-- Format percentage (always shows 1 decimal place)
function module.formatPercent(value: number): string
	return string.format("%.1f%%", value)
end

-- Standard widget sizes
module.sizes = {
	timerLarge = UDim2.fromOffset(180, 50),
	timerCompact = UDim2.fromOffset(100, 30),
	speedNumeric = UDim2.fromOffset(100, 30),
	statsCompact = UDim2.fromOffset(80, 26),
	distanceLabel = UDim2.fromOffset(120, 24),
}

-- Helper to create a standard widget container frame
function module.createContainer(name: string, size: UDim2, position: UDim2?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position or UDim2.fromScale(0.5, 0.5)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = module.containerBackground
	frame.BackgroundTransparency = module.containerTransparency
	frame.BorderSizePixel = module.containerBorderSize
	frame.BorderColor3 = module.containerBorderColor

	if module.useRoundedCorners then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = module.cornerRadius
		corner.Parent = frame
	end

	return frame
end

-- Helper to create a text label with standard styling (fixed size)
function module.createLabel(name: string, text: string, textColor: Color3, font: Font, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.TextColor3 = textColor
	label.FontFace = font
	label.TextSize = textSize
	label.Text = text
	label.TextStrokeTransparency = 0.5
	label.TextStrokeColor3 = colors.black

	return label
end

-- Standard game text sizes (match windows.lua globals)
module.STANDARD_TEXT_SIZE = 16
module.STANDARD_BOLD_TEXT_SIZE = 24

-- Helper to create a scalable text label matching game UI standards
-- Uses TextScaled with UITextSizeConstraint for responsive sizing
function module.createStandardLabel(
	name: string,
	text: string,
	textColor: Color3,
	isBold: boolean,
	xAlignment: Enum.TextXAlignment?
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.TextColor3 = textColor
	label.FontFace = fonts.GetFont(false, isBold)
	label.TextScaled = true
	label.RichText = true
	label.Text = text
	label.TextXAlignment = xAlignment or Enum.TextXAlignment.Left

	-- UITextSizeConstraint matches windows.lua pattern
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.Name = "UITextSizeConstraint"
	constraint.MaxTextSize = if isBold then module.STANDARD_BOLD_TEXT_SIZE else module.STANDARD_TEXT_SIZE
	constraint.Parent = label

	return label
end

-- Helper to create a standard value label (for stats panels)
-- Name on left, value on right, standard sizing
function module.createStatRow(
	parent: Frame,
	labelText: string,
	valueText: string,
	valueColor: Color3,
	yPosition: number,
	rowHeight: number
): TextLabel
	-- Label (left side)
	local nameLabel = module.createStandardLabel(labelText .. "Label", labelText, colors.white, false, Enum.TextXAlignment.Left)
	nameLabel.Size = UDim2.new(0.5, -4, 0, rowHeight)
	nameLabel.Position = UDim2.fromOffset(4, yPosition)
	nameLabel.Parent = parent

	-- Value (right side)
	local valueLabel = module.createStandardLabel(labelText .. "Value", valueText, valueColor, true, Enum.TextXAlignment.Right)
	valueLabel.Size = UDim2.new(0.5, -4, 0, rowHeight)
	valueLabel.Position = UDim2.new(0.5, 0, 0, yPosition)
	valueLabel.Parent = parent

	return valueLabel -- Return value label for updates
end

-- Helper to create an accent bar (colored strip for visual emphasis)
function module.createAccentBar(color: Color3, thickness: number): Frame
	local bar = Instance.new("Frame")
	bar.Name = "AccentBar"
	bar.Size = UDim2.new(1, 0, 0, thickness)
	bar.BackgroundColor3 = color
	bar.BorderSizePixel = 0
	return bar
end

-- Helper to create a container-friendly widget frame
-- In free mode: uses position and anchor for absolute placement
-- Anchored at top-center so resizing grows downward, preserving user's chosen position
-- In container mode: uses fixed size and no position for UIListLayout compatibility
function module.createWidgetFrame(name: string, size: UDim2, position: UDim2?, background: Color3?, transparency: number?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.BackgroundColor3 = background or module.containerBackground
	frame.BackgroundTransparency = transparency or module.containerTransparency
	frame.BorderSizePixel = module.containerBorderSize
	frame.BorderColor3 = module.containerBorderColor

	-- If position provided, we're in free positioning mode
	if position then
		frame.Position = position
		-- Anchor at top-center: resizing grows downward, not in all directions
		frame.AnchorPoint = Vector2.new(0.5, 0)
	else
		-- No position = container mode, UIListLayout will arrange us
		frame.Position = UDim2.fromScale(0, 0)
		frame.AnchorPoint = Vector2.new(0, 0)
	end

	return frame
end

-- Determine if a widget is inside a container (has UIListLayout parent)
function module.isInContainerMode(frame: Frame): boolean
	local parent = frame.Parent
	if parent and parent:IsA("Frame") then
		return parent:FindFirstChildOfClass("UIListLayout") ~= nil
	end
	return false
end

-- Standard title bar height
module.TITLE_BAR_HEIGHT = 20

-- Check if mouse is within a frame's screen bounds
-- GetMouseLocation and AbsolutePosition both use screen coordinates (0,0 at top-left)
-- for GUIs with IgnoreGuiInset = true, so no adjustment needed
function module.isMouseOverFrame(frame: Frame): boolean
	if not frame or not frame.Parent then
		return false
	end

	local mousePos = UserInputService:GetMouseLocation()
	local absPos = frame.AbsolutePosition
	local absSize = frame.AbsoluteSize

	return mousePos.X >= absPos.X
		and mousePos.X <= absPos.X + absSize.X
		and mousePos.Y >= absPos.Y
		and mousePos.Y <= absPos.Y + absSize.Y
end

-- Check if the topmost GUI element at mouse position belongs to the given frame
-- Exported for use by other modules that need the same topmost check
function module.isFrameTopmostAtMouse(frame: Frame): boolean
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return false
	end

	local mousePos = UserInputService:GetMouseLocation()
	local guiObjects = playerGui:GetGuiObjectsAtPosition(mousePos.X, mousePos.Y)
	if #guiObjects == 0 then
		return false
	end

	-- The topmost GUI is the first in the list
	local topmost = guiObjects[1]

	-- Check if topmost is the frame itself or a descendant of the frame
	if topmost == frame then
		return true
	end

	return topmost:IsDescendantOf(frame)
end

-- Helper to create a standard title bar (red background, white text)
-- The entire title bar serves as the drag handle for widgets
-- Uses standard TP style: signColor background, white bold text
function module.createTitleBar(parent: Frame, title: string): Frame
	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, module.TITLE_BAR_HEIGHT)
	titleBar.BackgroundColor3 = colors.signColor
	titleBar.BackgroundTransparency = 0
	titleBar.BorderSizePixel = 1
	titleBar.BorderColor3 = colors.black
	titleBar.Parent = parent

	-- Standard game font, bold, white on red
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.fromScale(1, 1)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = colors.white
	titleLabel.FontFace = fonts.GetFont(false, true)
	titleLabel.TextScaled = true
	titleLabel.Text = title
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.Parent = titleBar

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = module.STANDARD_TEXT_SIZE
	constraint.Parent = titleLabel

	-- Hover effect to indicate draggability (only when topmost layer)
	local isMouseOver = false
	local inputChangedConnection: RBXScriptConnection? = nil

	local function updateTitleBarHover()
		if not isMouseOver then
			titleBar.BackgroundColor3 = colors.signColor
			return
		end

		if module.isFrameTopmostAtMouse(titleBar) then
			titleBar.BackgroundColor3 = colors.lightRed
		else
			titleBar.BackgroundColor3 = colors.signColor
		end
	end

	titleBar.MouseEnter:Connect(function()
		isMouseOver = true
		updateTitleBarHover()
	end)

	titleBar.MouseLeave:Connect(function()
		isMouseOver = false
		updateTitleBarHover()
	end)

	-- Re-check on mouse movement to handle overlapping widgets
	inputChangedConnection = UserInputService.InputChanged:Connect(function(input)
		if isMouseOver and input.UserInputType == Enum.UserInputType.MouseMovement then
			updateTitleBarHover()
		end
	end)

	-- Cleanup when titleBar is destroyed to avoid connection leaks
	titleBar.Destroying:Connect(function()
		if inputChangedConnection then
			inputChangedConnection:Disconnect()
			inputChangedConnection = nil
		end
	end)

	return titleBar
end

-- Helper to create a complete widget with title bar
-- Returns: { frame: Frame, contentFrame: Frame, titleBar: Frame }
function module.createWidgetWithTitle(
	name: string,
	title: string,
	size: UDim2,
	position: UDim2?
): { frame: Frame, contentFrame: Frame, titleBar: Frame }
	local frame = module.createWidgetFrame(name, size, position)

	local titleBar = module.createTitleBar(frame, title)

	-- Content area below title bar
	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "Content"
	contentFrame.Size = UDim2.new(1, -4, 1, -module.TITLE_BAR_HEIGHT - 4)
	contentFrame.Position = UDim2.fromOffset(2, module.TITLE_BAR_HEIGHT + 2)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Parent = frame

	return {
		frame = frame,
		contentFrame = contentFrame,
		titleBar = titleBar,
	}
end

-- Helper to create a value display label (for speed, distance, etc.)
function module.createValueLabel(name: string, initialValue: string, textColor: Color3, fontSize: number?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.TextColor3 = textColor
	label.FontFace = fonts.GetFont(true, true)
	label.TextSize = fontSize or module.textSizes.medium
	label.Text = initialValue
	label.TextStrokeTransparency = 0.5
	label.TextStrokeColor3 = colors.black
	return label
end

-- Type for resize handle configuration
export type ResizeConfig = {
	parent: Frame,
	minWidth: number,
	maxWidth: number,
	minHeight: number,
	maxHeight: number,
	-- Optional: callback during resize (not needed if children use fill-parent mode)
	onSizeChanged: ((width: number, height: number) -> ())?,
	-- Optional: callback when resize ends (for saving size to settings)
	onResizeEnd: ((width: number, height: number) -> ())?,
	-- Optional: initial size to apply (from saved settings)
	-- If provided, the parent frame will be resized to this size on creation
	initialWidth: number?,
	initialHeight: number?,
}

-- Type for directional resize handle configuration
-- Allows user to resize in horizontal, vertical, or both directions based on mouse movement
export type DirectionalResizeConfig = {
	parent: Frame,
	minWidth: number,
	maxWidth: number,
	minHeight: number,
	maxHeight: number,
	-- Optional: callback during resize (not needed if children use fill-parent mode)
	onSizeChanged: ((width: number, height: number) -> ())?,
	-- Optional: threshold for direction detection (0-1, default 0.6)
	-- Higher = more diagonal movement required to trigger both-axis resize
	directionThreshold: number?,
	-- Optional: callback when resize ends (for saving size to settings)
	onResizeEnd: ((width: number, height: number) -> ())?,
	-- Optional: initial size to apply (from saved settings)
	initialWidth: number?,
	initialHeight: number?,
}

-- Standard resize handle (3-dot diagonal grip in bottom-right corner)
-- Uses top-left anchoring during resize so upper-left stays fixed while growing down+right
-- Returns the handle button and a cleanup function
function module.createResizeHandle(config: ResizeConfig): (TextButton, () -> ())
	local parent = config.parent
	local minWidth = config.minWidth
	local maxWidth = config.maxWidth
	local minHeight = config.minHeight
	local maxHeight = config.maxHeight
	local onSizeChanged = config.onSizeChanged
	local onResizeEnd = config.onResizeEnd

	local isResizing = false
	local resizeStartPos = Vector2.zero
	local resizeStartSize = Vector2.zero
	local resizeStartFramePos = Vector2.zero
	local currentWidth = config.initialWidth or parent.AbsoluteSize.X
	local currentHeight = config.initialHeight or parent.AbsoluteSize.Y

	-- Apply initial size if provided (from saved settings)
	if config.initialWidth and config.initialHeight then
		local initW = math.clamp(config.initialWidth, minWidth, maxWidth)
		local initH = math.clamp(config.initialHeight, minHeight, maxHeight)
		parent.Size = UDim2.fromOffset(initW, initH)
		currentWidth = initW
		currentHeight = initH
		-- Notify widget of initial size (if callback provided)
		if onSizeChanged then
			onSizeChanged(initW, initH)
		end
	end

	-- Use TextButton to properly sink input and prevent drag handler from firing
	local resizeHandle = Instance.new("TextButton")
	resizeHandle.Name = "ResizeHandle"
	resizeHandle.Size = UDim2.fromOffset(RESIZE_HANDLE_SIZE, RESIZE_HANDLE_SIZE)
	resizeHandle.Position = UDim2.new(1, -RESIZE_HANDLE_SIZE, 1, -RESIZE_HANDLE_SIZE)
	resizeHandle.BackgroundColor3 = RESIZE_BG_COLOR
	resizeHandle.BackgroundTransparency = RESIZE_BG_TRANSPARENCY
	resizeHandle.BorderSizePixel = 0
	resizeHandle.ZIndex = 20
	resizeHandle.Text = ""
	resizeHandle.AutoButtonColor = false
	resizeHandle.Parent = parent

	-- Create 3-dot diagonal grip pattern
	for i = 0, 2 do
		local grip = Instance.new("Frame")
		grip.Size = UDim2.fromOffset(2, 2)
		grip.Position = UDim2.fromOffset(4 + i * 4, 10 - i * 4)
		grip.BackgroundColor3 = RESIZE_GRIP_COLOR
		grip.BackgroundTransparency = RESIZE_GRIP_TRANSPARENCY
		grip.BorderSizePixel = 0
		grip.Parent = resizeHandle
	end

	-- Track connections for cleanup
	local connections: { RBXScriptConnection } = {}

	-- Begin resize on mouse down - use tracked size, not AbsoluteSize (fixes jump bug)
	-- resizeHandle.InputBegan only fires when the handle receives input (Roblox handles layer order)
	table.insert(
		connections,
		resizeHandle.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				local clickPos = Vector2.new(input.Position.X, input.Position.Y)
				isResizing = true
				resizeStartPos = clickPos
				-- Use the tracked current size, not AbsoluteSize which may differ
				resizeStartSize = Vector2.new(currentWidth, currentHeight)
				resizeStartFramePos = parent.AbsolutePosition
			end
		end)
	)

	-- Update size during drag - only adjust SIZE, keep top-left corner fixed
	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input)
			if isResizing and input.UserInputType == Enum.UserInputType.MouseMovement then
				local deltaX = input.Position.X - resizeStartPos.X
				local deltaY = input.Position.Y - resizeStartPos.Y
				local newWidth = math.clamp(resizeStartSize.X + deltaX, minWidth, maxWidth)
				local newHeight = math.clamp(resizeStartSize.Y + deltaY, minHeight, maxHeight)

				-- Track current size
				currentWidth = newWidth
				currentHeight = newHeight

				-- Update size
				parent.Size = UDim2.fromOffset(newWidth, newHeight)

				-- If anchor point is not top-left, compensate position to keep top-left fixed
				-- Top-left corner was at resizeStartFramePos; we want it to stay there
				-- Position = top-left + (size * anchor)
				local anchor = parent.AnchorPoint
				if anchor.X ~= 0 or anchor.Y ~= 0 then
					parent.Position = UDim2.fromOffset(
						resizeStartFramePos.X + newWidth * anchor.X,
						resizeStartFramePos.Y + newHeight * anchor.Y
					)
				end

				if onSizeChanged then
					onSizeChanged(newWidth, newHeight)
				end
			end
		end)
	)

	-- End resize on mouse up - call onResizeEnd for size persistence
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 and isResizing then
				isResizing = false
				-- Save size when resize ends
				if onResizeEnd then
					onResizeEnd(currentWidth, currentHeight)
				end
			end
		end)
	)

	-- Cleanup function
	local function cleanup()
		for _, conn in ipairs(connections) do
			conn:Disconnect()
		end
		if resizeHandle then
			resizeHandle:Destroy()
		end
	end

	return resizeHandle, cleanup
end

-- Directional resize handle (3-dot diagonal grip in bottom-right corner)
-- Allows user to resize horizontally only, vertically only, or both based on mouse movement direction
-- Uses top-left anchoring during resize so upper-left stays fixed while growing down+right
-- Returns the handle button and a cleanup function
function module.createDirectionalResizeHandle(config: DirectionalResizeConfig): (TextButton, () -> ())
	local parent = config.parent
	local minWidth = config.minWidth
	local maxWidth = config.maxWidth
	local minHeight = config.minHeight
	local maxHeight = config.maxHeight
	local onSizeChanged = config.onSizeChanged
	local directionThreshold = config.directionThreshold or 0.6
	local onResizeEnd = config.onResizeEnd

	local isResizing = false
	local resizeStartPos = Vector2.zero
	local resizeStartSize = Vector2.zero
	local resizeStartFramePos = Vector2.zero
	local currentWidth = config.initialWidth or parent.AbsoluteSize.X
	local currentHeight = config.initialHeight or parent.AbsoluteSize.Y

	-- Apply initial size if provided (from saved settings)
	if config.initialWidth and config.initialHeight then
		local initW = math.clamp(config.initialWidth, minWidth, maxWidth)
		local initH = math.clamp(config.initialHeight, minHeight, maxHeight)
		parent.Size = UDim2.fromOffset(initW, initH)
		currentWidth = initW
		currentHeight = initH
		if onSizeChanged then
			onSizeChanged(initW, initH)
		end
	end

	-- Use TextButton to properly sink input and prevent drag handler from firing
	local resizeHandle = Instance.new("TextButton")
	resizeHandle.Name = "ResizeHandle"
	resizeHandle.Size = UDim2.fromOffset(RESIZE_HANDLE_SIZE, RESIZE_HANDLE_SIZE)
	resizeHandle.Position = UDim2.new(1, -RESIZE_HANDLE_SIZE, 1, -RESIZE_HANDLE_SIZE)
	resizeHandle.BackgroundColor3 = RESIZE_BG_COLOR
	resizeHandle.BackgroundTransparency = RESIZE_BG_TRANSPARENCY
	resizeHandle.BorderSizePixel = 0
	resizeHandle.ZIndex = 20
	resizeHandle.Text = ""
	resizeHandle.AutoButtonColor = false
	resizeHandle.Parent = parent

	-- Create 3-dot diagonal grip pattern (same as standard resize handle)
	for i = 0, 2 do
		local grip = Instance.new("Frame")
		grip.Size = UDim2.fromOffset(2, 2)
		grip.Position = UDim2.fromOffset(4 + i * 4, 10 - i * 4)
		grip.BackgroundColor3 = RESIZE_GRIP_COLOR
		grip.BackgroundTransparency = RESIZE_GRIP_TRANSPARENCY
		grip.BorderSizePixel = 0
		grip.Parent = resizeHandle
	end

	-- Track connections for cleanup
	local connections: { RBXScriptConnection } = {}

	-- Begin resize on mouse down - use tracked size, not AbsoluteSize (fixes jump bug)
	-- resizeHandle.InputBegan only fires when the handle receives input (Roblox handles layer order)
	table.insert(
		connections,
		resizeHandle.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				local clickPos = Vector2.new(input.Position.X, input.Position.Y)
				isResizing = true
				resizeStartPos = clickPos
				resizeStartSize = Vector2.new(currentWidth, currentHeight)
				resizeStartFramePos = parent.AbsolutePosition
			end
		end)
	)

	-- Update size during drag based on movement direction
	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input)
			if isResizing and input.UserInputType == Enum.UserInputType.MouseMovement then
				local deltaX = input.Position.X - resizeStartPos.X
				local deltaY = input.Position.Y - resizeStartPos.Y
				local absDeltaX = math.abs(deltaX)
				local absDeltaY = math.abs(deltaY)
				local totalDelta = absDeltaX + absDeltaY

				-- Determine resize direction based on mouse movement
				-- Default to both if no significant movement yet
				local resizeHorizontal = true
				local resizeVertical = true

				if totalDelta > 5 then -- Threshold to avoid jitter on small movements
					local horizontalRatio = absDeltaX / totalDelta
					local verticalRatio = absDeltaY / totalDelta

					if horizontalRatio > directionThreshold then
						-- Mostly horizontal movement -> resize width only
						resizeHorizontal = true
						resizeVertical = false
					elseif verticalRatio > directionThreshold then
						-- Mostly vertical movement -> resize height only
						resizeHorizontal = false
						resizeVertical = true
					else
						-- Diagonal movement -> resize both
						resizeHorizontal = true
						resizeVertical = true
					end
				end

				-- Calculate new dimensions
				local newWidth = resizeStartSize.X
				local newHeight = resizeStartSize.Y

				if resizeHorizontal then
					newWidth = math.clamp(resizeStartSize.X + deltaX, minWidth, maxWidth)
				end
				if resizeVertical then
					newHeight = math.clamp(resizeStartSize.Y + deltaY, minHeight, maxHeight)
				end

				-- Track current size
				currentWidth = newWidth
				currentHeight = newHeight

				-- Update size
				parent.Size = UDim2.fromOffset(newWidth, newHeight)

				-- If anchor point is not top-left, compensate position to keep top-left fixed
				local anchor = parent.AnchorPoint
				if anchor.X ~= 0 or anchor.Y ~= 0 then
					parent.Position = UDim2.fromOffset(
						resizeStartFramePos.X + newWidth * anchor.X,
						resizeStartFramePos.Y + newHeight * anchor.Y
					)
				end

				if onSizeChanged then
					onSizeChanged(newWidth, newHeight)
				end
			end
		end)
	)

	-- End resize on mouse up - call onResizeEnd for size persistence
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 and isResizing then
				isResizing = false
				if onResizeEnd then
					onResizeEnd(currentWidth, currentHeight)
				end
			end
		end)
	)

	-- Cleanup function
	local function cleanup()
		for _, conn in ipairs(connections) do
			conn:Disconnect()
		end
		if resizeHandle then
			resizeHandle:Destroy()
		end
	end

	return resizeHandle, cleanup
end

-- Add hover border to a frame for indicating draggability on transparent widgets
-- Only shows border when frame is the topmost layer under the mouse
-- Returns a cleanup function
function module.addHoverBorder(frame: Frame): () -> ()
	local stroke = Instance.new("UIStroke")
	stroke.Name = "HoverBorder"
	stroke.Color = HOVER_BORDER_COLOR
	stroke.Thickness = HOVER_BORDER_THICKNESS
	stroke.Transparency = 1 -- Start invisible
	stroke.Parent = frame

	local connections: { RBXScriptConnection } = {}
	local isMouseOver = false

	local function updateHoverState()
		if not isMouseOver then
			stroke.Transparency = 1
			return
		end

		if module.isFrameTopmostAtMouse(frame) then
			stroke.Transparency = HOVER_BORDER_TRANSPARENCY
		else
			stroke.Transparency = 1
		end
	end

	table.insert(
		connections,
		frame.MouseEnter:Connect(function()
			isMouseOver = true
			updateHoverState()
		end)
	)

	table.insert(
		connections,
		frame.MouseLeave:Connect(function()
			isMouseOver = false
			updateHoverState()
		end)
	)

	-- Re-check on mouse movement to handle cases where overlapping frames change
	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input)
			if isMouseOver and input.UserInputType == Enum.UserInputType.MouseMovement then
				updateHoverState()
			end
		end)
	)

	return function()
		for _, conn in ipairs(connections) do
			conn:Disconnect()
		end
		if stroke then
			stroke:Destroy()
		end
	end
end

-- Standard panel widget sizes (for consistency)
module.panelSizes = {
	-- Distance widgets
	distanceSingle = UDim2.fromOffset(120, 26), -- from-start or total
	distanceDual = UDim2.fromOffset(130, 44), -- combined (both values)

	-- Stats widgets
	statsCompact = UDim2.fromOffset(80, 26),
	statsDetailed = UDim2.fromOffset(160, 100),

	-- Run info
	runInfoSignOnly = UDim2.fromOffset(160, 24),
	runInfoWithDesc = UDim2.fromOffset(220, 80),
}

-- Type for standard panel configuration
export type StandardPanelConfig = {
	name: string,
	width: number,
	height: number,
	position: UDim2?,
	-- Resize options (optional)
	resizable: boolean?,
	minWidth: number?,
	maxWidth: number?,
	minHeight: number?,
	maxHeight: number?,
	onSizeChanged: ((width: number, height: number) -> ())?,
	-- Appearance options
	transparent: boolean?, -- If true, uses full transparency and adds hover border
	background: Color3?, -- Override background color
	backgroundTransparency: number?, -- Override transparency
}

-- Result type for createStandardPanel
export type StandardPanelResult = {
	frame: Frame,
	cleanup: () -> (),
}

-- Create a standardized widget panel with consistent styling
-- Handles: background, borders, anchor points, resize handle, hover border
function module.createStandardPanel(config: StandardPanelConfig): StandardPanelResult
	local cleanupFunctions: { () -> () } = {}

	local frame = Instance.new("Frame")
	frame.Name = config.name

	-- Set size
	frame.Size = UDim2.fromOffset(config.width, config.height)

	-- Set position and anchor
	if config.position then
		frame.Position = config.position
		-- Resizable widgets anchor at top-left so resize grows down+right
		-- Non-resizable widgets anchor at center for easier positioning
		if config.resizable then
			frame.AnchorPoint = Vector2.new(0, 0)
		else
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
		end
	else
		-- Container mode: no position, UIListLayout handles placement
		frame.Position = UDim2.fromScale(0, 0)
		frame.AnchorPoint = Vector2.new(0, 0)
	end

	-- Set background
	if config.transparent then
		frame.BackgroundTransparency = 1
		-- Add hover border to indicate draggability
		local hoverCleanup = module.addHoverBorder(frame)
		table.insert(cleanupFunctions, hoverCleanup)
	else
		frame.BackgroundColor3 = config.background or module.containerBackground
		frame.BackgroundTransparency = config.backgroundTransparency or module.containerTransparency
	end

	-- Set border (visible even on transparent widgets via UIStroke)
	frame.BorderSizePixel = module.containerBorderSize
	frame.BorderColor3 = module.containerBorderColor

	-- Add resize handle if requested
	if config.resizable then
		local _, resizeCleanup = module.createResizeHandle({
			parent = frame,
			minWidth = config.minWidth or config.width,
			maxWidth = config.maxWidth or config.width * 2,
			minHeight = config.minHeight or config.height,
			maxHeight = config.maxHeight or config.height * 2,
			onSizeChanged = config.onSizeChanged, -- Optional: only needed if children require manual notification
		})
		table.insert(cleanupFunctions, resizeCleanup)
	end

	-- Combined cleanup function
	local function cleanup()
		for _, fn in ipairs(cleanupFunctions) do
			fn()
		end
		if frame then
			frame:Destroy()
		end
	end

	return {
		frame = frame,
		cleanup = cleanup,
	}
end

-- Create a transparent text display with stroke for readability (no background box)
-- Used for simple numeric displays like speed, distance, timer
-- Returns: { frame: Frame, label: TextLabel, cleanup: () -> () }
export type TransparentLabelResult = {
	frame: Frame,
	label: TextLabel,
	cleanup: () -> (),
}

function module.createTransparentLabel(config: {
	name: string,
	size: UDim2,
	position: UDim2?,
	text: string,
	textColor: Color3,
	fontSize: number?,
	fontBold: boolean?,
	fontMono: boolean?,
	xAlignment: Enum.TextXAlignment?,
}): TransparentLabelResult
	local cleanupFunctions: { () -> () } = {}

	local frame = Instance.new("Frame")
	frame.Name = config.name
	frame.Size = config.size
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0

	if config.position then
		frame.Position = config.position
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
	end

	-- Add hover border for draggability indication
	local hoverCleanup = module.addHoverBorder(frame)
	table.insert(cleanupFunctions, hoverCleanup)

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = config.textColor
	label.FontFace = fonts.GetFont(config.fontMono or false, config.fontBold or false)
	label.TextSize = config.fontSize or module.textSizes.medium
	label.TextXAlignment = config.xAlignment or Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Text = config.text
	label.TextStrokeTransparency = 0.3
	label.TextStrokeColor3 = colors.black
	label.Parent = frame

	local function cleanup()
		for _, fn in ipairs(cleanupFunctions) do
			fn()
		end
		if frame then
			frame:Destroy()
		end
	end

	return {
		frame = frame,
		label = label,
		cleanup = cleanup,
	}
end

-- Create a sign viewport display (3D granite-textured sign matching game signs)
-- Used for displaying sign names with the authentic game look
-- Returns: { frame: Frame, textLabel: TextLabel, cleanup: () -> () }
export type SignViewportResult = {
	frame: Frame,
	textLabel: TextLabel,
	cleanup: () -> (),
}

function module.createSignViewport(config: {
	name: string,
	size: UDim2,
	position: UDim2?,
}): SignViewportResult
	local frame = Instance.new("Frame")
	frame.Name = config.name
	frame.Size = config.size
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0

	if config.position then
		frame.Position = config.position
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
	end

	-- ViewportFrame to render 3D sign with granite material
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "SignViewport"
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	viewport.LightDirection = Vector3.new(1, -1, -1).Unit
	viewport.Ambient = Color3.fromRGB(255, 255, 255)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.Parent = frame

	-- WorldModel for viewport content
	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport

	-- Granite part matching real signs
	local signPart = Instance.new("Part")
	signPart.Name = "SignPart"
	signPart.Size = Vector3.new(20, 0.5, 10)
	signPart.CFrame = CFrame.new(0, 0, 0)
	signPart.Material = Enum.Material.Granite
	signPart.Color = colors.signColor
	signPart.Anchored = true
	signPart.CanCollide = false
	signPart.TopSurface = Enum.SurfaceType.Smooth
	signPart.BottomSurface = Enum.SurfaceType.Smooth
	signPart.Parent = worldModel

	-- Camera looking straight down at sign
	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.new(0, 3, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	camera.FieldOfView = 90
	camera.Parent = worldModel
	viewport.CurrentCamera = camera

	-- Rounded corners on viewport
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.05, 0)
	corner.Parent = viewport

	-- Text overlay on the viewport
	local textContainer = Instance.new("Frame")
	textContainer.Name = "TextContainer"
	textContainer.Size = UDim2.fromScale(0.9, 0.8)
	textContainer.Position = UDim2.fromScale(0.5, 0.5)
	textContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	textContainer.BackgroundTransparency = 1
	textContainer.ClipsDescendants = true
	textContainer.ZIndex = 10
	textContainer.Parent = viewport

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "SignText"
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.TextColor3 = colors.signTextColor
	textLabel.Font = Enum.Font.Gotham
	textLabel.TextScaled = true
	textLabel.TextXAlignment = Enum.TextXAlignment.Center
	textLabel.TextYAlignment = Enum.TextYAlignment.Center
	textLabel.TextTruncate = Enum.TextTruncate.AtEnd
	textLabel.Text = ""
	textLabel.ZIndex = 11
	textLabel.Parent = textContainer

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 24
	constraint.Parent = textLabel

	local function cleanup()
		if frame then
			frame:Destroy()
		end
	end

	return {
		frame = frame,
		textLabel = textLabel,
		cleanup = cleanup,
	}
end

_annotate("end")
return module
