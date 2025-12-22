--!strict

-- windows.lua, used in clients

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local UserInputService = game:GetService("UserInputService")
local colors = require(game.ReplicatedStorage.util.colors)
-- Correcting the require path for uiPositionManager
local uiPositionManager = require(game.StarterPlayer.StarterPlayerScripts.guis.uiPositionManager)
local attemptResizeOnMinimized = Instance.new("BindableEvent")
local thumbnails = require(game.ReplicatedStorage.thumbnails)
local settings = require(game.ReplicatedStorage.settings)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)

local buttonScalePixel = 15
local minimizedSize = Vector2.new(buttonScalePixel * 2, buttonScalePixel)

-- Add this at the module level
local currentlyDraggingFrame: Frame? = nil

-- Global DisplayOrder counter for click-to-front behavior across ScreenGuis
-- Base starts at 50 (above widgets at 5-10, below tooltips at 100)
local BASE_DISPLAY_ORDER = 50
local nextDisplayOrder = BASE_DISPLAY_ORDER

local module = {}

-- Position persistence configuration type
export type PositionPersistenceConfig = {
	settingName: string, -- Dedicated GUI layout setting (e.g., "RUN_RESULTS_GUI_LAYOUT")
	settingKey: string, -- Key within the setting (e.g., "position", "size")
	saveSize: boolean?, -- Default: false
	sizeKey: string?, -- Only if saveSize = true, default: "size"
	clampOnLoad: boolean?, -- Default: true
	minSizePixels: Vector2?, -- Optional: reject persisted sizes smaller than this (absolute pixels)
	maxSizePixels: Vector2?, -- Optional: clamp persisted sizes larger than this (absolute pixels)
	defaultPosition: UDim2?, -- Default position when no saved position exists (scale-based)
	onSave: ((position: UDim2, size: UDim2?, minimized: boolean?) -> ())?, -- Optional callback for complex saves
	onResizeEnd: ((frame: Frame) -> ())?, -- Optional callback when resize drag ends (InputEnded)
	onDragEnd: ((frame: Frame) -> ())?, -- Optional callback when drag ends (InputEnded)
}

-- Resize handle configuration type
export type ResizeHandlePosition = "bottomRight" | "bottomLeft"

export type ResizeHandleConfig = {
	position: ResizeHandlePosition?, -- Default: "bottomRight"
	positionBelow: boolean?, -- If true, position handle just below frame instead of inside bottom-right
	zIndex: number?, -- Override default ZIndex (10) for click priority
}

-- Convert absolute position to scale-based UDim2 (clamps to non-negative to avoid saving off-screen positions)
local function _absoluteToScale(absoluteX: number, absoluteY: number): UDim2
	local camera = workspace.CurrentCamera
	if not camera then
		return UDim2.fromOffset(math.max(0, absoluteX), math.max(0, absoluteY))
	end
	local viewportSize = camera.ViewportSize
	-- Clamp to non-negative before converting to scale
	local clampedX = math.max(0, absoluteX)
	local clampedY = math.max(0, absoluteY)
	local scaleX = clampedX / viewportSize.X
	local scaleY = clampedY / viewportSize.Y
	return UDim2.fromScale(scaleX, scaleY)
end

-- Convert absolute size to scale-based UDim2
local function sizeToScale(absoluteWidth: number, absoluteHeight: number): UDim2
	local camera = workspace.CurrentCamera
	if not camera then
		return UDim2.fromOffset(absoluteWidth, absoluteHeight)
	end
	local viewportSize = camera.ViewportSize
	local scaleX = absoluteWidth / viewportSize.X
	local scaleY = absoluteHeight / viewportSize.Y
	return UDim2.fromScale(scaleX, scaleY)
end

-- Clamp a saved position to ensure the frame stays fully on-screen (matches drag behavior)
local function clampPositionToScreen(pos: UDim2, frameSize: Vector2?): UDim2
	local camera = workspace.CurrentCamera
	if not camera then
		return pos
	end

	local viewportSize = camera.ViewportSize
	local size = frameSize or Vector2.new(200, 100) -- Conservative default

	-- Convert UDim2 to absolute position
	local absoluteX = pos.X.Scale * viewportSize.X + pos.X.Offset
	local absoluteY = pos.Y.Scale * viewportSize.Y + pos.Y.Offset

	-- Keep window fully on-screen (consistent with drag behavior in updateDrag)
	local maxX = math.max(0, viewportSize.X - size.X)
	local maxY = math.max(0, viewportSize.Y - size.Y)

	local clampedX = math.clamp(absoluteX, 0, maxX)
	local clampedY = math.clamp(absoluteY, 0, maxY)

	-- Only return new UDim2 if clamping changed the position
	if clampedX ~= absoluteX or clampedY ~= absoluteY then
		-- Convert back to scale-based to maintain monitor independence
		local clampedScaleX = clampedX / viewportSize.X
		local clampedScaleY = clampedY / viewportSize.Y
		_annotate(string.format("CLAMPED offscreen position: scale(%.3f,%.3f)->scale(%.3f,%.3f) viewport=%.0fx%.0f", pos.X.Scale, pos.Y.Scale, clampedScaleX, clampedScaleY, viewportSize.X, viewportSize.Y))
		return UDim2.fromScale(clampedScaleX, clampedScaleY)
	end

	return pos
end

-- Load saved position from settings
local function loadPosition(settingName: string, settingKey: string, defaultPosition: UDim2?, clampOnLoad: boolean, frameSize: Vector2?): UDim2?
	local settingDef = settingEnums.settingDefinitions[settingName]
	if not settingDef then
		_annotate(string.format("Position persistence: setting '%s' not found", settingName))
		return defaultPosition
	end

	local setting = settings.GetSettingByName(settingDef.name)
	if not setting or not setting.luaValue then
		return defaultPosition
	end

	local savedData = setting.luaValue :: { [string]: any }
	local savedPos = savedData[settingKey]

	if not savedPos or typeof(savedPos) ~= "UDim2" then
		return defaultPosition
	end

	local pos = savedPos :: UDim2

	-- Reject offset-based positions (old format) - must be scale-based
	-- A valid scale-based position has non-zero scale and zero offset
	local isOffsetBased = (pos.X.Offset ~= 0 or pos.Y.Offset ~= 0) and (pos.X.Scale == 0 and pos.Y.Scale == 0)
	if isOffsetBased then
		_annotate(string.format("REJECTED offset-based position from '%s'[%s]: offset(%.0f, %.0f) - resetting to default", settingName, settingKey, pos.X.Offset, pos.Y.Offset))
		return defaultPosition
	end

	if clampOnLoad then
		pos = clampPositionToScreen(pos, frameSize)
	end

	return pos
end

-- Save position to settings (scale-based for monitor independence)
-- Takes UDim2 directly to avoid pixel round-trip drift from AbsolutePosition
local function savePosition(settingName: string, settingKey: string, position: UDim2, reason: string?)
	local settingDef = settingEnums.settingDefinitions[settingName]
	if not settingDef then
		_annotate(string.format("Position persistence: setting '%s' not found, cannot save", settingName))
		return
	end

	-- Ensure position is scale-based (reject offset-only positions)
	local savePos = position
	if position.X.Scale == 0 and position.Y.Scale == 0 and (position.X.Offset ~= 0 or position.Y.Offset ~= 0) then
		-- Convert offset-based to scale-based
		local camera = workspace.CurrentCamera
		local viewportSize = if camera then camera.ViewportSize else Vector2.new(1920, 1080)
		savePos = UDim2.fromScale(math.max(0, position.X.Offset) / viewportSize.X, math.max(0, position.Y.Offset) / viewportSize.Y)
	end

	local setting = settings.GetSettingByName(settingDef.name)
	local savedData: { [string]: any } = {}
	if setting and setting.luaValue then
		savedData = setting.luaValue :: { [string]: any }
	end

	savedData[settingKey] = savePos

	local newSetting = {
		name = settingDef.name,
		domain = settingDef.domain,
		kind = settingDef.kind,
		luaValue = savedData,
	}

	local _result = settings.SetSetting(newSetting)
end

-- Save size to settings (converts to scale-based for monitor independence)
local function saveSizeAsScale(settingName: string, sizeKey: string, absoluteWidth: number, absoluteHeight: number)
	local settingDef = settingEnums.settingDefinitions[settingName]
	if not settingDef then
		_annotate(string.format("Position persistence: setting '%s' not found, cannot save size", settingName))
		return
	end

	-- Convert absolute size to scale-based UDim2
	local size = sizeToScale(absoluteWidth, absoluteHeight)

	local setting = settings.GetSettingByName(settingDef.name)
	local savedData: { [string]: any } = {}
	if setting and setting.luaValue then
		savedData = setting.luaValue :: { [string]: any }
	end

	savedData[sizeKey] = size

	local newSetting = {
		name = settingDef.name,
		domain = settingDef.domain,
		kind = settingDef.kind,
		luaValue = savedData,
	}

	local _result = settings.SetSetting(newSetting)
end

-- Helper function to calculate Vector2 delta
local function calculateVector2Delta(input: Vector3, start: Vector2): Vector2
	local delta = input - Vector3.new(start.X, start.Y, 0)
	return Vector2.new(delta.X, delta.Y)
end

local function createWindowControl(frame: Frame, name: string, text: string, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, buttonScalePixel, 0, buttonScalePixel)
	button.Position = position
	button.Text = text
	button.TextScaled = true
	button.Name = frame.Name .. "_" .. name
	button.ZIndex = 10
	button.BackgroundColor3 = colors.defaultGrey
	button.TextColor3 = colors.black
	button.TextSize = 18
	button.Font = Enum.Font.Gotham
	button.Parent = frame
	button.BackgroundTransparency = 0.5
	button.Active = true
	return button
end

local SetupResizeability = function(frame: Frame, aspectRatio: number?, resizeConfig: ResizeHandleConfig?, onResizeEnd: ((Frame) -> ())?): TextButton
	local resizing = false
	local startInputPosition = Vector2.new()
	local startAbsoluteSize = Vector2.new()
	local startAbsolutePosition = Vector2.new()

	local position: ResizeHandlePosition = if resizeConfig and resizeConfig.position then resizeConfig.position else "bottomRight"
	local isBottomLeft = position == "bottomLeft"

	-- Determine handle position based on config
	local positionBelow = resizeConfig and resizeConfig.positionBelow or false
	local handleY = if positionBelow then 0 else -buttonScalePixel
	local handlePos = if isBottomLeft then UDim2.new(0, 0, 1, handleY) else UDim2.new(1, -buttonScalePixel, 1, handleY)
	local handleText = if isBottomLeft then "⋰" else "⋱"

	-- Create resize handle as a TextButton directly on the input frame.
	local resizeHandle = createWindowControl(frame, "resizer", handleText, handlePos)

	-- Apply custom ZIndex if specified, otherwise use default (10 from createWindowControl)
	if resizeConfig and resizeConfig.zIndex then
		resizeHandle.ZIndex = resizeConfig.zIndex
	end

	-- Make handle clearly visible at all times; brighten on hover for interactivity feedback
	resizeHandle.BackgroundTransparency = 0.2
	resizeHandle.BackgroundColor3 = colors.defaultGrey
	resizeHandle.TextTransparency = 0
	resizeHandle.TextColor3 = colors.black

	-- Hide portrait tooltip and brighten handle when hovering
	resizeHandle.MouseEnter:Connect(function()
		thumbnails.HideAvatarPopup()
		resizeHandle.BackgroundTransparency = 0
		resizeHandle.BackgroundColor3 = colors.white
		resizeHandle.TextColor3 = colors.black
	end)

	resizeHandle.MouseLeave:Connect(function()
		resizeHandle.BackgroundTransparency = 0.2
		resizeHandle.BackgroundColor3 = colors.defaultGrey
		resizeHandle.TextTransparency = 0
		resizeHandle.TextColor3 = colors.black
	end)

	-- Store aspect ratio at creation time if provided
	if aspectRatio then
		frame:SetAttribute("AspectRatio", aspectRatio)
	end

	-- Enforce screen bounds: size cannot exceed viewport, frame must stay fully on-screen
	local function enforceScreenBounds()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewportSize = camera.ViewportSize
		local currentSize = frame.AbsoluteSize
		local currentPos = frame.AbsolutePosition

		local needsUpdate = false
		local newWidth = currentSize.X
		local newHeight = currentSize.Y
		local newPosX = currentPos.X
		local newPosY = currentPos.Y

		-- Check for max size constraints from attributes
		local maxWidthValue = frame:GetAttribute("MaxWidth")
		local maxWidth: number? = if type(maxWidthValue) == "number" and maxWidthValue > 0 then maxWidthValue else nil
		local maxHeightValue = frame:GetAttribute("MaxHeight")
		local maxHeight: number? = if type(maxHeightValue) == "number" and maxHeightValue > 0 then maxHeightValue else nil

		-- Clamp size to not exceed screen OR max size constraints
		local maxAllowedWidth = viewportSize.X
		if maxWidth then
			maxAllowedWidth = math.min(maxAllowedWidth, maxWidth)
		end
		if newWidth > maxAllowedWidth then
			newWidth = maxAllowedWidth
			needsUpdate = true
		end

		local maxAllowedHeight = viewportSize.Y
		if maxHeight then
			maxAllowedHeight = math.min(maxAllowedHeight, maxHeight)
		end
		if newHeight > maxAllowedHeight then
			newHeight = maxAllowedHeight
			needsUpdate = true
		end

		-- Clamp position to keep frame fully on-screen
		if newPosX < 0 then
			newPosX = 0
			needsUpdate = true
		elseif newPosX + newWidth > viewportSize.X then
			newPosX = viewportSize.X - newWidth
			needsUpdate = true
		end
		if newPosY < 0 then
			newPosY = 0
			needsUpdate = true
		elseif newPosY + newHeight > viewportSize.Y then
			newPosY = viewportSize.Y - newHeight
			needsUpdate = true
		end

		if needsUpdate then
			frame.Size = UDim2.fromOffset(newWidth, newHeight)
			frame.Position = UDim2.fromOffset(newPosX, newPosY)
		end
	end

	-- Listen for viewport size changes to re-enforce bounds
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			-- Defer to let any other updates settle
			task.defer(enforceScreenBounds)
		end)
	end

	local function handleResize(input: InputObject)
		-- Calculate total delta from start of drag
		local currentInputPosition = Vector2.new(input.Position.X, input.Position.Y)
		local totalDelta = currentInputPosition - startInputPosition

		-- Check if this frame should maintain aspect ratio
		local storedAspectRatioValue = frame:GetAttribute("AspectRatio")
		local storedAspectRatio: number? = if type(storedAspectRatioValue) == "number" then storedAspectRatioValue else nil
		local maintainAspectRatio = storedAspectRatio ~= nil and storedAspectRatio > 0

		-- Calculate target dimensions based on drag
		local targetWidth: number
		local targetHeight: number
		local targetPosX: number
		local targetPosY: number

		if isBottomLeft then
			-- Bottom-Left resize:
			-- Dragging Left (negative X) -> Width increases, position moves left
			-- Dragging Right (positive X) -> Width decreases, position moves right
			-- Dragging Down (positive Y) -> Height increases
			targetWidth = startAbsoluteSize.X - totalDelta.X
			targetPosX = startAbsolutePosition.X + totalDelta.X
			targetHeight = startAbsoluteSize.Y + totalDelta.Y
			targetPosY = startAbsolutePosition.Y -- Y position unchanged for bottom resize
		else
			-- Bottom-Right resize (default):
			-- Dragging Right (positive X) -> Width increases
			-- Dragging Down (positive Y) -> Height increases
			targetWidth = startAbsoluteSize.X + totalDelta.X
			targetHeight = startAbsoluteSize.Y + totalDelta.Y
			targetPosX = startAbsolutePosition.X
			targetPosY = startAbsolutePosition.Y
		end

		-- Apply minimum size constraints (respect MinWidth/MinHeight attributes if set).
		-- Defaults are conservative to prevent unreadably small TextScaled windows being persisted.
		local minWidthValue = frame:GetAttribute("MinWidth")
		local minWidth: number = if type(minWidthValue) == "number" and minWidthValue > 50 then minWidthValue else 150
		local minHeightValue = frame:GetAttribute("MinHeight")
		local minHeight: number = if type(minHeightValue) == "number" and minHeightValue > 50 then minHeightValue else 80

		-- For bottom-left, if width would go below minimum, adjust position accordingly
		if isBottomLeft then
			if targetWidth < minWidth then
				local widthDiff = minWidth - targetWidth
				targetWidth = minWidth
				targetPosX = targetPosX - widthDiff
			end
		else
			targetWidth = math.max(targetWidth, minWidth)
		end
		targetHeight = math.max(targetHeight, minHeight)

		-- Apply maximum size constraints if set
		local maxWidthValue = frame:GetAttribute("MaxWidth")
		local maxWidth: number? = if type(maxWidthValue) == "number" and maxWidthValue > 0 then maxWidthValue else nil
		if maxWidth then
			targetWidth = math.min(targetWidth, maxWidth)
		end

		local maxHeightValue = frame:GetAttribute("MaxHeight")
		local maxHeight: number? = if type(maxHeightValue) == "number" and maxHeightValue > 0 then maxHeightValue else nil
		if maxHeight then
			targetHeight = math.min(targetHeight, maxHeight)
		end

		-- Apply height snapping if set (snaps to multiples of row height)
		local snapIntervalValue = frame:GetAttribute("HeightSnapInterval")
		local snapOffsetValue = frame:GetAttribute("HeightSnapOffset")
		local snapInterval: number? = if type(snapIntervalValue) == "number" then snapIntervalValue else nil
		local snapOffset: number = if type(snapOffsetValue) == "number" then snapOffsetValue else 0
		if snapInterval and snapInterval > 0 then
			-- Calculate how many rows fit, round to nearest whole number (minimum 1)
			local contentHeight = targetHeight - snapOffset
			local numRows = math.max(1, math.floor(contentHeight / snapInterval + 0.5))
			targetHeight = snapOffset + (numRows * snapInterval)
			-- Re-apply max height after snapping
			if maxHeight and maxHeight > 0 then
				targetHeight = math.min(targetHeight, maxHeight)
			end
		end

		local finalWidth = targetWidth
		local finalHeight = targetHeight

		if maintainAspectRatio and storedAspectRatio then
			-- Determine primary drag direction based on absolute movement
			if math.abs(totalDelta.Y) > math.abs(totalDelta.X) then
				-- Vertical drag is dominant
				finalHeight = targetHeight
				finalWidth = finalHeight * storedAspectRatio
			else
				-- Horizontal drag is dominant
				finalWidth = targetWidth
				finalHeight = finalWidth / storedAspectRatio
			end
		end

		-- Apply screen bounds during resize
		local viewportSize = workspace.CurrentCamera.ViewportSize

		-- Size cannot exceed screen
		finalWidth = math.min(finalWidth, viewportSize.X)
		finalHeight = math.min(finalHeight, viewportSize.Y)

		-- For bottom-left, we need to recalculate position based on final width
		local finalPosX = targetPosX
		local finalPosY = targetPosY

		if isBottomLeft then
			-- Recalculate position based on width change from original
			finalPosX = startAbsolutePosition.X + (startAbsoluteSize.X - finalWidth)
		end

		-- Ensure frame stays fully on-screen
		if finalPosX < 0 then
			finalPosX = 0
		end
		if finalPosX + finalWidth > viewportSize.X then
			if isBottomLeft then
				-- For bottom-left, clamp width instead of moving position
				finalWidth = viewportSize.X - finalPosX
			else
				finalPosX = viewportSize.X - finalWidth
			end
		end
		if finalPosY < 0 then
			finalPosY = 0
		end
		if finalPosY + finalHeight > viewportSize.Y then
			finalHeight = viewportSize.Y - finalPosY
		end

		-- Re-apply size constraints after bounds clamping
		finalWidth = math.max(finalWidth, minWidth)
		finalHeight = math.max(finalHeight, minHeight)
		if maxWidth then
			finalWidth = math.min(finalWidth, maxWidth)
		end
		if maxHeight then
			finalHeight = math.min(finalHeight, maxHeight)
		end

		-- Apply size and position (scale-based position to avoid drift on save/load)
		frame.Size = UDim2.fromOffset(finalWidth, finalHeight)
		if isBottomLeft then
			frame.Position = UDim2.fromScale(finalPosX / viewportSize.X, finalPosY / viewportSize.Y)
		end
	end

	resizeHandle.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if frame:GetAttribute("IsMinimized") then
				attemptResizeOnMinimized:Fire(input, frame.Name)
				return
			end
			resizing = true
			startInputPosition = Vector2.new(input.Position.X, input.Position.Y)
			startAbsoluteSize = frame.AbsoluteSize
			startAbsolutePosition = frame.AbsolutePosition
		end
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject)
		if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			handleResize(input)
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if resizing then
				resizing = false
				-- Fire callback when resize drag ends
				if onResizeEnd then
					onResizeEnd(frame)
				end
			end
		end
	end)

	return resizeHandle
end

local SetupMinimizeability = function(frame: Frame)
	_annotate("create minimize button for: " .. frame.Name)

	local isMinimized: boolean = false
	local minimizeButton: TextButton
	-- Position the minimize button in the bottom left corner, next to the resize handle
	minimizeButton = createWindowControl(frame, "minimizer", "-", UDim2.new(0, buttonScalePixel, 1, -buttonScalePixel))

	-- Hide portrait tooltip when hovering over minimize button
	minimizeButton.MouseEnter:Connect(function()
		thumbnails.HideAvatarPopup()
	end)

	local childrenSizes: { [string]: UDim2 } = {}
	local originalSize: UDim2 = frame.Size
	-- Minimize all Frame children of the outer frame, plus hide the resize handle.
	minimizeButton.MouseButton1Click:Connect(function()
		isMinimized = not isMinimized
		frame:SetAttribute("IsMinimized", isMinimized)

		if isMinimized then
			-- we minimize it.
			minimizeButton.Text = "+"
			originalSize = frame.Size
			frame.Size = UDim2.new(0, 2 * buttonScalePixel, 0, buttonScalePixel)
		else
			minimizeButton.Text = "-"
			frame.Size = originalSize -- Restore original size
			-- we need to bump it away from the edge as much as possible here.
		end

		-- Find all child Frames and minimize them or restore them.
		-- Also hide/show the resize handle (TextButton) when minimizing.
		for _, child in pairs(frame:GetChildren()) do
			if child:IsA("Frame") then
				local childFrame: Frame = child :: Frame
				if isMinimized then
					-- back up the size
					childrenSizes[child.Name] = childFrame.Size
					childFrame.Size = UDim2.new(0, 2 * buttonScalePixel, 0, buttonScalePixel)
				else
					-- restore the size
					if childrenSizes[child.Name] then
						childFrame.Size = childrenSizes[child.Name]
					end
				end

				childFrame.Visible = not isMinimized
			elseif child:IsA("TextButton") and child.Name:match("_resizer$") then
				-- Hide resize handle when minimized; show when restored
				child.Visible = not isMinimized
			end
		end
	end)
end

local function updateDrag(frame: Frame, activelyChangingInput: InputObject, mouseDragStart: Vector2, framePositionAtStartOfDrag: UDim2)
	local dragDelta = calculateVector2Delta(activelyChangingInput.Position, mouseDragStart)
	local viewportSize = workspace.CurrentCamera.ViewportSize

	local absoluteX = framePositionAtStartOfDrag.X.Scale * viewportSize.X + framePositionAtStartOfDrag.X.Offset + dragDelta.X
	local absoluteY = framePositionAtStartOfDrag.Y.Scale * viewportSize.Y + framePositionAtStartOfDrag.Y.Offset + dragDelta.Y

	local isMinimized = frame:GetAttribute("IsMinimized")

	local currentSize = isMinimized and minimizedSize or frame.AbsoluteSize

	-- Calculate the maximum allowed position
	local maxX = viewportSize.X - currentSize.X
	local maxY = viewportSize.Y - currentSize.Y

	-- Cap the position based on minimized state
	local cappedX: number
	local cappedY: number
	if not isMinimized then
		cappedX = math.clamp(absoluteX, 0, math.max(maxX, 0))
		cappedY = math.clamp(absoluteY, 0, math.max(maxY, 0))
	else
		cappedX = math.clamp(absoluteX, currentSize.X, viewportSize.X)
		cappedY = math.clamp(absoluteY, currentSize.Y, viewportSize.Y)
	end

	-- Convert to scale-based UDim2 to avoid pixel drift on save/load
	local newPosition = UDim2.fromScale(cappedX / viewportSize.X, cappedY / viewportSize.Y)
	frame.Position = newPosition
end

-- Modify the isFrameOnScreen function
module.isFrameOnScreen = function(frame: Frame): (boolean, string)
	if not frame.Visible then
		return false, "Frame is intentionally hidden"
	end

	local isMinimized = frame:GetAttribute("IsMinimized")
	if isMinimized then
		return true, "Frame is minimized"
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return false, "No camera found"
	end

	local viewportSize = camera.ViewportSize
	local framePosition = frame.AbsolutePosition
	local frameSize = frame.AbsoluteSize

	local onScreen = framePosition.X < viewportSize.X and framePosition.Y < viewportSize.Y and framePosition.X + frameSize.X > 0 and framePosition.Y + frameSize.Y > 0

	if onScreen then
		return true, "Fully visible"
	else
		return false, "Off screen"
	end
end

local function isFrameOnTop(frame: Frame): boolean
	local screenGui = frame:FindFirstAncestorOfClass("ScreenGui")
	if not screenGui then
		return false
	end

	local children = screenGui:GetChildren()
	for i = #children, 1, -1 do
		local child = children[i]
		if child:IsA("GuiObject") and child.Visible then
			return child == frame
		end
	end

	return false
end

local function bringFrameToFront(frame: Frame)
	_annotate(string.format("bringing frame to front %s", frame.Name))
	local screenGui: ScreenGui = frame:FindFirstAncestorOfClass("ScreenGui") :: ScreenGui
	if screenGui then
		-- Increment and set DisplayOrder to bring this ScreenGui above others
		nextDisplayOrder = nextDisplayOrder + 1
		screenGui.DisplayOrder = nextDisplayOrder
		_annotate(string.format("Set DisplayOrder=%d for %s", nextDisplayOrder, screenGui.Name))

		-- Toggle Enabled to refresh rendering order within the ScreenGui
		screenGui.Enabled = not screenGui.Enabled
		screenGui.Enabled = not screenGui.Enabled
	end
end

-- Main function to setup draggability for a frame
local SetupDraggability = function(frame: Frame, onDragEnd: ((Frame) -> ())?)
	local dragging = false
	local mouseDragStartPosition: Vector2
	local framePositionAtStartOfDrag: UDim2

	local function startDragging(input: InputObject)
		-- Check if another frame is already being dragged
		if currentlyDraggingFrame and currentlyDraggingFrame ~= frame then
			return
		end
		if frame:GetAttribute("IsPinned") then
			return
		end

		bringFrameToFront(frame)

		if isFrameOnTop(frame) then
			_annotate(string.format("on top so dragging me, %s", input.Name))
		else
			_annotate(string.format("not on top, so not dragging me., %s", input.Name))
			return
		end

		_annotate("dragging me.")

		dragging = true
		currentlyDraggingFrame = frame
		uiPositionManager.setDragging(frame, true)

		mouseDragStartPosition = Vector2.new(input.Position.X, input.Position.Y)
		framePositionAtStartOfDrag = frame.Position

		local dragConnection
		dragConnection = UserInputService.InputChanged:Connect(function(changedInput: InputObject)
			if dragging and (changedInput.UserInputType == Enum.UserInputType.MouseMovement or changedInput.UserInputType == Enum.UserInputType.Touch) then
				updateDrag(frame, changedInput, mouseDragStartPosition, framePositionAtStartOfDrag)
			end
		end)

		-- Disconnect dragConnection when dragging ends
		local endConnection
		endConnection = UserInputService.InputEnded:Connect(function(endedInput: InputObject)
			if endedInput.UserInputType == Enum.UserInputType.MouseButton1 or endedInput.UserInputType == Enum.UserInputType.Touch then
				if dragging then
					dragging = false
					currentlyDraggingFrame = nil
					uiPositionManager.setDragging(frame, false)
					-- Fire callback when drag ends
					if onDragEnd then
						onDragEnd(frame)
					end
					dragConnection:Disconnect()
					endConnection:Disconnect()
				end
			end
		end)
	end

	frame.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			startDragging(input)
		end
	end)

	attemptResizeOnMinimized.Event:Connect(function(input: InputObject, frameName: string)
		if frame.Name == frameName then
			startDragging(input)
		end
	end)
end

-- Add this new function to create the pin button (top-left corner)
local function SetupPinnability(frame: Frame)
	local isPinned = false
	local pinButton: TextButton = createWindowControl(frame, "pinner", "📌", UDim2.new(0, 0, 0, 0))

	-- Hide portrait tooltip when hovering over pin button
	pinButton.MouseEnter:Connect(function()
		thumbnails.HideAvatarPopup()
	end)

	pinButton.MouseButton1Click:Connect(function()
		isPinned = not isPinned
		frame:SetAttribute("IsPinned", isPinned)
		if isPinned then
			pinButton.Text = "📍"
		else
			pinButton.Text = "📌"
		end
		pinButton.BackgroundColor3 = isPinned and colors.meColor or colors.defaultGrey
	end)
end

-- Helper function to build content from guiSpec and return named references
-- Note: Requires windows.lua lazily to avoid cyclic dependency
local function buildContentFromGuiSpec(
	guiSpec: any, -- wt.guiSpec
	contentFrame: Frame,
	outerFrame: Frame,
	intendedRowsOfScrollingFrameToShow: number?
): { [string]: GuiObject }
	local builtContent: { [string]: GuiObject } = {}
	-- Lazy require to avoid cyclic dependency (windows.lua requires windowFunctions.lua)
	local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)
	local wt = require(game.StarterPlayer.StarterPlayerScripts.guis.windowsTypes)

	-- Add vertical layout
	local layout = Instance.new("UIListLayout")
	layout.Name = string.format("%s_layout", contentFrame.Name)
	layout.SortOrder = Enum.SortOrder.Name
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Parent = contentFrame

	-- Find search-enabled scrolling frame
	local searchEnabledSpec: wt.scrollingFrameTileSpec? = nil
	local searchTargetRowOrder: number? = nil
	for _, rowSpec in ipairs(guiSpec.rowSpecs) do
		for _, tileSpec in ipairs(rowSpec.tileSpecs) do
			local found = windows.findFirstSearchEnabledScrollingFrameSpecInTileSpec(tileSpec)
			if found then
				if searchEnabledSpec then
					_annotate(string.format("buildContentFromGuiSpec('%s') found multiple search-enabled scrolling frames; using first '%s', ignoring '%s'", guiSpec.name, searchEnabledSpec.name, found.name))
				else
					searchEnabledSpec = found
					searchTargetRowOrder = rowSpec.order
				end
			end
		end
	end

	-- Clone and sort row specs
	local rowFrames: { Frame } = {}
	local shallowClonedRowSpecs: { wt.rowSpec } = {}
	for _, rowSpec in ipairs(guiSpec.rowSpecs) do
		table.insert(shallowClonedRowSpecs, windows.cloneRowSpecShallow(rowSpec))
	end
	table.sort(shallowClonedRowSpecs, function(a: wt.rowSpec, b: wt.rowSpec)
		return a.order < b.order
	end)

	-- Adjust orders for search row insertion
	local insertSearchRowOrder: number? = nil
	if searchEnabledSpec and searchTargetRowOrder then
		local insertOrder: number = searchTargetRowOrder
		insertSearchRowOrder = insertOrder
		for _, rowSpec in ipairs(shallowClonedRowSpecs) do
			if rowSpec.order >= insertOrder then
				rowSpec.order += 1
			end
		end
	end

	-- Build rows
	local insertedSearch = false
	local createdSearchRowFrame: Frame? = nil
	for _, rowSpec in ipairs(shallowClonedRowSpecs) do
		if insertSearchRowOrder and not insertedSearch and rowSpec.order == insertSearchRowOrder + 1 then
			if searchEnabledSpec and searchEnabledSpec.searchConfig then
				local searchRowFrame = windows.createSearchChromeRow(insertSearchRowOrder, searchEnabledSpec.searchConfig, searchEnabledSpec.name)
				createdSearchRowFrame = searchRowFrame
				table.insert(rowFrames, searchRowFrame)
				insertedSearch = true
			end
		end

		local rowFrame, rowTileReferences = windows.CreateRow(rowSpec)
		rowFrame.Size = UDim2.new(1, 0, rowSpec.height.Scale, rowSpec.height.Offset)
		table.insert(rowFrames, rowFrame)

		-- Store row frame reference by row name
		builtContent[rowSpec.name] = rowFrame

		-- Store tile references from CreateRow (captured at creation time, no fallback search)
		for tileName, tile in pairs(rowTileReferences) do
			builtContent[tileName] = tile
		end
	end

	-- Apply proportional heights
	windows.applyProportionalHeights(rowFrames)

	-- Parent rows to content frame
	for _, rowFrame in ipairs(rowFrames) do
		rowFrame.Parent = contentFrame
	end

	-- Wire search if needed
	if createdSearchRowFrame and searchEnabledSpec and searchEnabledSpec.searchConfig then
		windows.wireSearchChromeRow(createdSearchRowFrame, searchEnabledSpec.searchConfig, outerFrame)
	end

	return builtContent
end

module.SetupFrame = function(
	name: string,
	draggable: boolean,
	resizable: boolean,
	minimizable: boolean,
	pinnable: boolean,
	outerFrameSize: UDim2,
	maintainAspectRatio: boolean?,
	persistenceConfig: PositionPersistenceConfig?,
	resizeConfig: ResizeHandleConfig?,
	guiSpec: any?, -- wt.guiSpec? - If provided, builds content automatically
	contentOptions: {
		intendedRowsOfScrollingFrameToShow: number?,
	}?,
	popupOptions: {
		showCloseButton: boolean?, -- Create close button (default: false)
		dismissableWithX: boolean?, -- Mark as dismissable with X key (default: false)
		dismissableByClick: boolean?, -- Create backdrop for click-to-dismiss (default: false)
		centerIfNoSavedPosition: boolean?, -- Center if no saved position (default: true)
	}?
): { outerFrame: Frame, contentFrame: Frame, builtContent: { [string]: GuiObject }? }
	-- Set outer frame size based on content size
	local outerFrame = Instance.new("Frame")
	outerFrame.Name = "outer_" .. name
	outerFrame.BackgroundTransparency = 1
	outerFrame.Visible = true
	outerFrame.BorderSizePixel = 1
	outerFrame.BorderColor3 = colors.meColor
	outerFrame.BorderMode = Enum.BorderMode.Outline
	outerFrame:SetAttribute("IsMinimized", false)
	-- Note: We set Active = true on contentFrame (not outerFrame) to prevent click-through
	-- while still allowing scrolling frames to handle their input via ContextActionService

	-- Handle persistence: load saved size if available, otherwise use provided size
	local shouldSaveSize = if persistenceConfig then (persistenceConfig.saveSize or false) else false
	local sizeKey = if persistenceConfig and persistenceConfig.sizeKey then persistenceConfig.sizeKey else "size"
	local minPersistedSizePixels: Vector2 = if persistenceConfig and persistenceConfig.minSizePixels then persistenceConfig.minSizePixels else Vector2.new(150, 80)
	local maxPersistedSizePixels: Vector2? = if persistenceConfig and persistenceConfig.maxSizePixels then persistenceConfig.maxSizePixels else nil
	local didRejectSavedSize = false

	if persistenceConfig and shouldSaveSize then
		local settingDef = settingEnums.settingDefinitions[persistenceConfig.settingName]
		if settingDef then
			local setting = settings.GetSettingByName(settingDef.name)
			if setting and setting.luaValue then
				local savedData = setting.luaValue :: { [string]: any }
				local savedSize = savedData[sizeKey]
				if savedSize and typeof(savedSize) == "UDim2" then
					local candidateSize = savedSize :: UDim2
					local camera = workspace.CurrentCamera
					local viewportSize = if camera then camera.ViewportSize else Vector2.new(1920, 1080)
					local absW = candidateSize.X.Scale * viewportSize.X + candidateSize.X.Offset
					local absH = candidateSize.Y.Scale * viewportSize.Y + candidateSize.Y.Offset

					if absW < minPersistedSizePixels.X or absH < minPersistedSizePixels.Y then
						didRejectSavedSize = true
						_annotate(string.format("Rejected saved size for '%s' (abs=%.0fx%.0f < min=%.0fx%.0f); using default size instead", name, absW, absH, minPersistedSizePixels.X, minPersistedSizePixels.Y))
					else
						-- Clamp to max size if specified
						local needsClamp = false
						local clampedW = absW
						local clampedH = absH
						if maxPersistedSizePixels then
							if clampedW > maxPersistedSizePixels.X then
								clampedW = maxPersistedSizePixels.X
								needsClamp = true
							end
							if clampedH > maxPersistedSizePixels.Y then
								clampedH = maxPersistedSizePixels.Y
								needsClamp = true
							end
						end

						if needsClamp then
							-- Convert clamped absolute size back to UDim2 (prefer scale-based for consistency)
							outerFrameSize = sizeToScale(clampedW, clampedH)
							_annotate(string.format("Clamped saved size for '%s' from %.0fx%.0f to %.0fx%.0f (max=%.0fx%.0f)", name, absW, absH, clampedW, clampedH, if maxPersistedSizePixels then maxPersistedSizePixels.X else 0, if maxPersistedSizePixels then maxPersistedSizePixels.Y else 0))
						else
							outerFrameSize = candidateSize
							_annotate(string.format("Loaded saved size for '%s': scale(%.3f, %.3f) offset(%.0f, %.0f)", name, outerFrameSize.X.Scale, outerFrameSize.Y.Scale, outerFrameSize.X.Offset, outerFrameSize.Y.Offset))
						end
					end
				end
			end
		end
	end

	outerFrame.Size = outerFrameSize

	-- Handle persistence: load saved position if available
	-- Note: We don't pass AbsoluteSize here because the frame isn't parented yet.
	-- Clamping will be handled by uiPositionManager after parenting if needed.
	if persistenceConfig then
		local clampOnLoad = if persistenceConfig.clampOnLoad ~= nil then persistenceConfig.clampOnLoad else true
		-- Use the UDim2 size to calculate approximate absolute size for clamping
		local camera = workspace.CurrentCamera
		local viewportSize = if camera then camera.ViewportSize else Vector2.new(1920, 1080)
		local approximateSize = Vector2.new(outerFrameSize.X.Scale * viewportSize.X + outerFrameSize.X.Offset, outerFrameSize.Y.Scale * viewportSize.Y + outerFrameSize.Y.Offset)
		local defaultPos = persistenceConfig.defaultPosition
		local savedPos = loadPosition(persistenceConfig.settingName, persistenceConfig.settingKey, defaultPos, clampOnLoad, approximateSize)
		if savedPos then
			outerFrame.Position = savedPos
		end
	end

	-- Calculate aspect ratio at creation time if maintaining aspect ratio
	local aspectRatio: number? = nil
	if maintainAspectRatio == true then
		-- Calculate from initial size (convert UDim2 to absolute pixels for aspect ratio)
		-- Since we're using offset-based sizing initially, calculate from that
		local initialWidth = outerFrameSize.X.Offset
		local initialHeight = outerFrameSize.Y.Offset
		if initialWidth > 0 and initialHeight > 0 then
			aspectRatio = initialWidth / initialHeight
		end
	end

	-- Set MaxWidth/MaxHeight attributes if maxSizePixels is specified
	if persistenceConfig and persistenceConfig.maxSizePixels then
		outerFrame:SetAttribute("MaxWidth", persistenceConfig.maxSizePixels.X)
		outerFrame:SetAttribute("MaxHeight", persistenceConfig.maxSizePixels.Y)
	end

	if draggable then
		SetupDraggability(outerFrame, persistenceConfig and persistenceConfig.onDragEnd)
	end
	if resizable then
		SetupResizeability(outerFrame, aspectRatio, resizeConfig, persistenceConfig and persistenceConfig.onResizeEnd)
	end
	if minimizable then
		SetupMinimizeability(outerFrame)
	end
	if pinnable then
		SetupPinnability(outerFrame)
	end

	local contentFrame = Instance.new("Frame")
	contentFrame.Parent = outerFrame
	contentFrame.Name = "content_" .. name
	contentFrame.Size = UDim2.new(1, 0, 1, 0)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Position = UDim2.new(0, 0, 0, 0)
	contentFrame.Visible = true

	-- Build content from guiSpec if provided
	local builtContent: { [string]: GuiObject }? = nil
	if guiSpec then
		local contentOptionsValue = if contentOptions then contentOptions else {}
		local intendedRows = if (contentOptionsValue :: any).intendedRowsOfScrollingFrameToShow then (contentOptionsValue :: any).intendedRowsOfScrollingFrameToShow else 11
		builtContent = buildContentFromGuiSpec(guiSpec, contentFrame, outerFrame, intendedRows)
	end

	-- Handle close button if requested
	if popupOptions and popupOptions.showCloseButton == true then
		-- Lazy require to avoid cyclic dependency
		local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)
		local toolTip = require(game.ReplicatedStorage.gui.toolTip)
		local closeButtonTileSpec = windows.CreateCloseButtonTileSpec(function(_: InputObject, theButton: TextButton)
			local screenGui = theButton:FindFirstAncestorOfClass("ScreenGui")
			if screenGui then
				toolTip.KillFinalTooltip()
				screenGui:Destroy()
			end
		end)
		-- Add close button to a button row (create minimal row for it)
		local closeButtonRow = Instance.new("Frame")
		closeButtonRow.Name = "CloseButtonRow"
		closeButtonRow.Size = UDim2.new(1, 0, 0, 30) -- Standard button row height
		closeButtonRow.BackgroundTransparency = 1
		closeButtonRow.Parent = contentFrame

		-- Add horizontal layout for the row
		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rowLayout.Parent = closeButtonRow

		local closeButton = windows.CreateButton(closeButtonTileSpec.spec)
		closeButton.Name = "CloseButton"
		closeButton.Size = UDim2.new(closeButtonTileSpec.width.Scale, closeButtonTileSpec.width.Offset, 1, 0)
		closeButton.Parent = closeButtonRow

		-- Store reference
		if builtContent then
			builtContent["CloseButton"] = closeButton
			builtContent["CloseButtonRow"] = closeButtonRow
		end
	end

	-- Handle dismissableWithX attribute (separate from close button)
	if popupOptions and popupOptions.dismissableWithX == true then
		-- This will be set on ScreenGui when it's created (caller's responsibility)
		-- We can't set it here because outerFrame isn't parented to ScreenGui yet
	end

	-- Handle dismissableByClick backdrop (caller creates ScreenGui, so this is handled there)
	-- But we can prepare outerFrame for it
	if popupOptions and popupOptions.dismissableByClick == true then
		outerFrame.ZIndex = 1 -- Ensure it renders above backdrop
	end

	-- Center if no saved position and centerIfNoSavedPosition is true (default: true)
	local shouldCenter = if popupOptions and popupOptions.centerIfNoSavedPosition ~= nil then popupOptions.centerIfNoSavedPosition else true
	if shouldCenter and (not persistenceConfig or (outerFrame.Position.X.Offset == 0 and outerFrame.Position.Y.Offset == 0 and outerFrame.Position.X.Scale == 0 and outerFrame.Position.Y.Scale == 0)) then
		local camera = workspace.CurrentCamera
		local screenSize = if camera then camera.ViewportSize else Vector2.new(1920, 1080)
		local frameWidth = outerFrameSize.X.Scale * screenSize.X + outerFrameSize.X.Offset
		local frameHeight = outerFrameSize.Y.Scale * screenSize.Y + outerFrameSize.Y.Offset
		local centeredPositionX = math.max(0, (screenSize.X - frameWidth) / 2)
		local centeredPositionY = math.max(0, (screenSize.Y - frameHeight) / 2)
		-- Use scale-based positioning to avoid pixel drift on save/load
		outerFrame.Position = UDim2.fromScale(centeredPositionX / screenSize.X, centeredPositionY / screenSize.Y)
	end

	-- Bring window to front when clicking anywhere in content area
	-- This complements the drag-to-front behavior on outerFrame
	contentFrame.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			bringFrameToFront(outerFrame)
		end
	end)

	uiPositionManager.registerFrame(outerFrame)

	-- Handle persistence: set up saving on position/size changes
	if persistenceConfig then
		local config = persistenceConfig
		local debounceDelay = 0.1 -- Debounce saves to avoid excessive writes
		local saveConnection: RBXScriptConnection? = nil
		local pendingSave: thread? = nil
		-- Track if this is the initial load phase - don't save positions during initial parenting
		local initialLoadComplete = false

		-- Track the last known good position for cleanup saves (UDim2 - no pixel conversion)
		local lastKnownPosition: UDim2? = nil
		local lastKnownSize: Vector2? = nil

		-- Mark initial load complete after a brief delay to allow parenting to settle
		task.defer(function()
			task.wait(0.2) -- Wait for frame to be fully parented and positioned
			initialLoadComplete = true

			-- If we rejected a bad saved size, proactively re-save a sane size once the frame is parented.
			if shouldSaveSize and didRejectSavedSize and outerFrame.Parent and persistenceConfig then
				local absSizeNow = outerFrame.AbsoluteSize
				if absSizeNow.X >= minPersistedSizePixels.X and absSizeNow.Y >= minPersistedSizePixels.Y then
					saveSizeAsScale(persistenceConfig.settingName, sizeKey, absSizeNow.X, absSizeNow.Y)
				end
			end
		end)

		local function scheduleSave()
			-- Skip saves during initial load to avoid saving adjusted positions
			if not initialLoadComplete then
				return
			end

			-- Update last known values IMMEDIATELY so cleanup saves have fresh data
			-- even if the debounced save hasn't fired yet
			-- Store Position (UDim2) not AbsolutePosition (pixels) to avoid 58-pixel inset drift
			if outerFrame.Parent then
				lastKnownPosition = outerFrame.Position
				lastKnownSize = outerFrame.AbsoluteSize
			end

			if pendingSave then
				task.cancel(pendingSave)
			end
			pendingSave = task.delay(debounceDelay, function()
				-- Save Position directly (UDim2) - no pixel conversion to avoid drift
				local position = outerFrame.Position
				local absoluteSize = outerFrame.AbsoluteSize
				local minimizedAttr = outerFrame:GetAttribute("IsMinimized")
				local minimized: boolean? = if typeof(minimizedAttr) == "boolean" then minimizedAttr else nil

				-- Never persist absurdly small or minimized window sizes; they make TextScaled labels unreadable and
				-- are difficult for users to recover from once saved.
				if shouldSaveSize then
					if (minimized == true) or absoluteSize.X < minPersistedSizePixels.X or absoluteSize.Y < minPersistedSizePixels.Y then
						if config.onSave then
							config.onSave(position, nil, minimized)
						else
							savePosition(config.settingName, config.settingKey, position, "minimized/tooSmall")
						end
						pendingSave = nil
						return
					end
				end

				-- Call custom save callback if provided (for complex saves like leaderboard)
				if config.onSave then
					local sizeAsScale = if shouldSaveSize then sizeToScale(absoluteSize.X, absoluteSize.Y) else nil
					config.onSave(position, sizeAsScale, minimized)
				else
					-- Simple save: position directly (no conversion)
					savePosition(config.settingName, config.settingKey, position, "debounce")

					-- Save size as scale if configured
					if shouldSaveSize then
						saveSizeAsScale(config.settingName, sizeKey, absoluteSize.X, absoluteSize.Y)
					end
				end
				pendingSave = nil
			end)
		end

		-- Save on position change
		saveConnection = outerFrame:GetPropertyChangedSignal("Position"):Connect(function()
			scheduleSave()
		end)

		-- Save on size change if configured
		if shouldSaveSize then
			outerFrame:GetPropertyChangedSignal("Size"):Connect(function()
				scheduleSave()
			end)
		end

		-- Save on minimized state change if minimizable
		if minimizable then
			outerFrame:GetAttributeChangedSignal("IsMinimized"):Connect(function()
				scheduleSave()
			end)
		end

		-- Cleanup connection when frame is destroyed - use last known position
		outerFrame.AncestryChanged:Connect(function()
			if not outerFrame.Parent then
				if saveConnection then
					saveConnection:Disconnect()
					saveConnection = nil
				end
				-- Cancel any pending save and use last known position instead
				-- This avoids reading AbsolutePosition from an unparented frame
				if pendingSave then
					task.cancel(pendingSave)
					pendingSave = nil
				end

				-- Only save if we have valid last known values
				if lastKnownPosition and initialLoadComplete then
					if config.onSave then
						-- lastKnownPosition is already UDim2 - pass directly
						local sizeAsScale = if shouldSaveSize and lastKnownSize then sizeToScale(lastKnownSize.X, lastKnownSize.Y) else nil
						local minimizedAttr = outerFrame:GetAttribute("IsMinimized")
						local minimized: boolean? = if typeof(minimizedAttr) == "boolean" then minimizedAttr else nil
						config.onSave(lastKnownPosition, sizeAsScale, minimized)
					else
						local _sizeStr = if lastKnownSize then string.format("(%.0f,%.0f)", lastKnownSize.X, lastKnownSize.Y) else "nil"

						savePosition(config.settingName, config.settingKey, lastKnownPosition, "cleanup")
						if shouldSaveSize and lastKnownSize then
							saveSizeAsScale(config.settingName, sizeKey, lastKnownSize.X, lastKnownSize.Y)
						end
					end
				end
			end
		end)
	end

	-- Debug: Print frame information when it's fully loaded
	task.defer(function()
		task.wait()
		local position = outerFrame.AbsolutePosition
		local size = outerFrame.AbsoluteSize
		local _onScreen, status = module.isFrameOnScreen(outerFrame)
		_annotate(string.format("GUI Debug - %s: Position: (%d, %d), Size: (%d, %d), Status: %s", name, position.X, position.Y, size.X, size.Y, status))
	end)

	return { outerFrame = outerFrame, contentFrame = contentFrame, builtContent = builtContent }
end

-- Expose bring-to-front for use by content that needs to trigger it on click
module.BringFrameToFront = bringFrameToFront

-- Get the next DisplayOrder value (for newly created popups)
-- This ensures each new popup appears above existing ones
function module.GetNextDisplayOrder(): number
	nextDisplayOrder = nextDisplayOrder + 1
	return nextDisplayOrder
end

_annotate("end")

return module
