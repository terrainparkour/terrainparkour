--!strict

-- windows.lua, used in clients

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local UserInputService = game:GetService("UserInputService")
local colors = require(game.ReplicatedStorage.util.colors)
-- Correcting the require path for uiPositionManager
local uiPositionManager = require(game.StarterPlayer.StarterPlayerScripts.guis.uiPositionManager)
local attemptResizeOnMinimized = Instance.new("BindableEvent")

local buttonScalePixel = 15
local minimizedSize = Vector2.new(buttonScalePixel * 2, buttonScalePixel)

-- Add this at the module level
local currentlyDraggingFrame: Frame? = nil
local module = {}

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
	return button
end

local SetupResizeability = function(frame: Frame): TextButton
	local resizing = false
	local lastInputPosition = Vector2.new()
	local initialFrameSize = UDim2.new()
	local initialFramePosition = UDim2.new()

	-- Create resize handle as a TextButton directly on the input frame.
	-- Position it in the bottom left corner of the frame
	local resizeHandle = createWindowControl(frame, "resizer", "O", UDim2.new(0, 0, 1, -buttonScalePixel))

	local deb = false
	local function handleResize(input: InputObject)
		if deb then
			return
		end

		deb = true
		-- this is the delta since the last time we resized (as the user drags)
		local delta = Vector2.new(input.Position.X - lastInputPosition.X, input.Position.Y - lastInputPosition.Y)

		-- Adjust frame position and size
		-- as you drag down, the height increases and position Y stays the same.
		-- as you drag left, the width increases and position X shrinks since the window has to move underneath you.
		-- do NOT remove the above explanatory comments above.

		--continuously update the frame
		initialFrameSize = frame.Size
		initialFramePosition = frame.Position

		local newSizeXScale = initialFrameSize.X.Scale
		local newSizeXOffset = initialFrameSize.X.Offset - delta.X
		local newPositionXOffset = initialFramePosition.X.Offset + delta.X

		local newSizeYScale = initialFrameSize.Y.Scale
		local newSizeYOffset = initialFrameSize.Y.Offset + delta.Y

		frame.Size = UDim2.new(newSizeXScale, newSizeXOffset, newSizeYScale, newSizeYOffset)

		local newPosition = UDim2.new(
			initialFramePosition.X.Scale,
			newPositionXOffset,
			initialFramePosition.Y.Scale,
			initialFramePosition.Y.Offset
		)

		frame.Position = newPosition

		-- Update last input position
		lastInputPosition = Vector2.new(input.Position.X, input.Position.Y)
		deb = false
	end

	resizeHandle.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			if frame:GetAttribute("IsMinimized") then
				attemptResizeOnMinimized:Fire(input, frame.Name)
				return
			end
			resizing = true
			lastInputPosition = input.Position
			initialFrameSize = frame.Size
			initialFramePosition = frame.Position
		end
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject)
		if
			resizing
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			handleResize(input)
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			resizing = false
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

	local childrenSizes: { [string]: UDim2 } = {}
	local originalSize: UDim2 = frame.Size
	-- minimiize all Frame children of the outer frame.
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

		-- find all child Frames and minimize them or restore them.
		-- we shrink
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
			end
		end
	end)
end

local function updateDrag(
	frame: Frame,
	activelyChangingInput: InputObject,
	mouseDragStart: Vector2,
	framePositionAtStartOfDrag: UDim2
)
	local dragDelta = calculateVector2Delta(activelyChangingInput.Position, mouseDragStart)

	local absoluteX = framePositionAtStartOfDrag.X.Scale * workspace.CurrentCamera.ViewportSize.X
		+ framePositionAtStartOfDrag.X.Offset
		+ dragDelta.X
	local absoluteY = framePositionAtStartOfDrag.Y.Scale * workspace.CurrentCamera.ViewportSize.Y
		+ framePositionAtStartOfDrag.Y.Offset
		+ dragDelta.Y

	local isMinimized = frame:GetAttribute("IsMinimized")

	local currentSize = isMinimized and minimizedSize or frame.AbsoluteSize

	-- Calculate the maximum allowed position
	local maxX = workspace.CurrentCamera.ViewportSize.X - currentSize.X
	local maxY = workspace.CurrentCamera.ViewportSize.Y - currentSize.Y

	-- Cap the position based on minimized state
	local cappedX: number
	local cappedY: number
	if not isMinimized then
		cappedX = math.clamp(absoluteX, 0, math.max(maxX, 0))
		cappedY = math.clamp(absoluteY, 0, math.max(maxY, 0))
	else
		cappedX = math.clamp(absoluteX, currentSize.X, workspace.CurrentCamera.ViewportSize.X)
		cappedY = math.clamp(absoluteY, currentSize.Y, workspace.CurrentCamera.ViewportSize.Y)
	end

	-- Convert back to UDim2
	local newPosition = UDim2.new(0, cappedX, 0, cappedY)
	frame.Position = newPosition
end

-- Modify the isFrameOnScreen function
local function isFrameOnScreen(frame: Frame): (boolean, string)
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

	local onScreen = framePosition.X < viewportSize.X
		and framePosition.Y < viewportSize.Y
		and framePosition.X + frameSize.X > 0
		and framePosition.Y + frameSize.Y > 0

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
		screenGui.Enabled = not screenGui.Enabled
		screenGui.Enabled = not screenGui.Enabled
	end

	-- -- Still set the ZIndex to be higher than siblings
	-- local highestZIndex = 0
	-- for _, child in ipairs(screenGui:GetChildren()) do
	-- 	if child:IsA("GuiObject") and child.ZIndex > highestZIndex then
	-- 		highestZIndex = child.ZIndex
	-- 	end
	-- end
	-- frame.ZIndex = highestZIndex + 1
end

-- Main function to setup draggability for a frame
local SetupDraggability = function(frame: Frame)
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

		mouseDragStartPosition = Vector2.new(input.Position.X, input.Position.Y)
		framePositionAtStartOfDrag = frame.Position

		local dragConnection
		dragConnection = UserInputService.InputChanged:Connect(function(changedInput: InputObject)
			if
				dragging
				and (
					changedInput.UserInputType == Enum.UserInputType.MouseMovement
					or changedInput.UserInputType == Enum.UserInputType.Touch
				)
			then
				updateDrag(frame, changedInput, mouseDragStartPosition, framePositionAtStartOfDrag)
			end
		end)

		-- Disconnect dragConnection when dragging ends
		local endConnection
		endConnection = UserInputService.InputEnded:Connect(function(endedInput: InputObject)
			if
				endedInput.UserInputType == Enum.UserInputType.MouseButton1
				or endedInput.UserInputType == Enum.UserInputType.Touch
			then
				dragging = false
				currentlyDraggingFrame = nil
				dragConnection:Disconnect()
				endConnection:Disconnect()
			end
		end)
	end

	frame.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			startDragging(input)
		end
	end)

	attemptResizeOnMinimized.Event:Connect(function(input: InputObject, frameName: string)
		if frame.Name == frameName then
			startDragging(input)
		end
	end)
end

-- Add this new function to create the pin button
local function SetupPinnability(frame: Frame)
	local isPinned = false
	local pinButton: TextButton =
		createWindowControl(frame, "pinner", "📌", UDim2.new(0, 0, 1, -2 * buttonScalePixel))

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

module.SetupFrame = function(
	name: string,
	draggable: boolean,
	resizable: boolean,
	minimizable: boolean,
	pinnable: boolean,
	outerFrameSize: UDim2
): { outerFrame: Frame, contentFrame: Frame }
	-- Set outer frame size based on content size
	local outerFrame = Instance.new("Frame")
	outerFrame.Name = "outer_" .. name
	outerFrame.BackgroundTransparency = 1
	outerFrame.Visible = true
	outerFrame.BorderSizePixel = 1
	outerFrame.BorderColor3 = colors.meColor
	outerFrame.BorderMode = Enum.BorderMode.Outline
	outerFrame:SetAttribute("IsMinimized", false)
	outerFrame.Size = outerFrameSize

	if draggable then
		SetupDraggability(outerFrame)
	end
	if resizable then
		SetupResizeability(outerFrame)
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

	uiPositionManager.registerFrame(outerFrame)

	-- Debug: Print frame information when it's fully loaded
	task.defer(function()
		task.wait()
		local position = outerFrame.AbsolutePosition
		local size = outerFrame.AbsoluteSize
		local onScreen, status = isFrameOnScreen(outerFrame)
		_annotate(
			string.format(
				"GUI Debug - %s: Position: (%d, %d), Size: (%d, %d), Status: %s",
				name,
				position.X,
				position.Y,
				size.X,
				size.Y,
				status
			)
		)
	end)

	return { outerFrame = outerFrame, contentFrame = contentFrame }
end

_annotate("end")

return module
