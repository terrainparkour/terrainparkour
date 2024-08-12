--!strict

-- resizeability
-- generic module to add resize functionality to frames
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local UserInputService = game:GetService("UserInputService")
local colors = require(game.ReplicatedStorage.util.colors)

local module = {}

local buttonScalePixel = 15

-- Helper function to calculate Vector2 delta
local function calculateVector2Delta(input: Vector3, start: Vector2): Vector2
	local delta = input - Vector3.new(start.X, start.Y, 0)
	return Vector2.new(delta.X, delta.Y)
end

function getLowerLeftOfFrame(frame: Frame): number
	return frame.Size.Y.Offset + frame.Position.Y.Offset
end

local SetupResizeability = function(frame: Frame): TextButton
	local resizing = false
	local lastInputPosition = Vector2.new()
	local initialFrameSize = Vector2.new()
	local initialFramePosition = UDim2.new()

	-- Create resize handle as a TextButton directly on the input frame.
	-- it should appear in the bottom left of the frame, just outside the bottom left corner.
	local resizeHandle = Instance.new("TextButton")
	resizeHandle.Size = UDim2.new(0, buttonScalePixel, 0, buttonScalePixel)
	resizeHandle.AnchorPoint = Vector2.new(0, 0)
	resizeHandle.Position = UDim2.new(0, 0, 1, -1 * buttonScalePixel)

	resizeHandle.Text = "O"
	resizeHandle.BackgroundColor3 = Color3.new(0.8, 0.8, 0.8)
	resizeHandle.BackgroundTransparency = 0
	resizeHandle.Parent = frame
	resizeHandle.ZIndex = 3
	resizeHandle.Name = frame.Name .. "_resizer"

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

		local newSizeYScale = initialFrameSize.Y.Scale
		local newSizeYOffset = initialFrameSize.Y.Offset + delta.Y

		frame.Size = UDim2.new(newSizeXScale, newSizeXOffset, newSizeYScale, newSizeYOffset)

		local newPosition = UDim2.new(
			initialFramePosition.X.Scale,
			initialFramePosition.X.Offset + delta.X,
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
	_annotate("create miminize button for: " .. frame.Name)

	local isMinimized: boolean = false
	local minimizeButton: TextButton
	minimizeButton = Instance.new("TextButton")
	minimizeButton.Size = UDim2.new(0, buttonScalePixel, 0, buttonScalePixel) -- Increased size
	minimizeButton.Position = UDim2.new(0, buttonScalePixel, 1, -1 * buttonScalePixel)

	minimizeButton.Text = "-"
	minimizeButton.TextScaled = true
	minimizeButton.Name = frame.Name .. "_minimizer"
	minimizeButton.ZIndex = 10
	minimizeButton.BackgroundColor3 = colors.defaultGrey
	minimizeButton.TextColor3 = colors.black
	minimizeButton.TextSize = 18 -- Larger text
	minimizeButton.Font = Enum.Font.Gotham
	minimizeButton.Parent = frame -- Set as sibling to the frame
	minimizeButton.ZIndex = 6

	local childrenSizes: { [string]: UDim2 } = {}
	local parentSize: UDim2
	-- minimiize all Frame children of the outer frame.
	minimizeButton.MouseButton1Click:Connect(function()
		isMinimized = not isMinimized
		if isMinimized then
			minimizeButton.Text = "+"
		else
			minimizeButton.Text = "-"
		end

		-- find all child Frames and minimize them or restore them.
		-- we shrink
		for _, child: Frame in pairs(frame:GetChildren()) do
			if child.ClassName == "Frame" then
				if isMinimized then
					-- back up the size
					childrenSizes[child.Name] = child.Size
					--shrink each to zero
					child.Size = UDim2.new(0, 2 * buttonScalePixel, 0, buttonScalePixel)
				else
					--restore the size
					child.Size = childrenSizes[child.Name]
				end

				child.Visible = not isMinimized
			end
		end

		-- we also shrink the outerFrame
		if isMinimized then
			parentSize = frame.Size
			frame.Size = UDim2.new(0, 50, 0, 20)
		else
			frame.Size = parentSize
		end
	end)
end

-- Function to update the frame position during dragging
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

	-- Get the frame's size
	local frameSize = frame.AbsoluteSize

	-- Calculate the maximum allowed position
	local maxX = workspace.CurrentCamera.ViewportSize.X - frameSize.X
	local maxY = workspace.CurrentCamera.ViewportSize.Y - frameSize.Y

	-- Cap the position to keep the frame on screen
	-- but only if its visible. If not, let it go to the edge.
	local cappedX: number
	local cappedY: number
	if frame.Visible then
		cappedX = math.clamp(absoluteX, 0, maxX)
		cappedY = math.clamp(absoluteY, 0, maxY)
	else
		cappedX = absoluteX
		cappedY = absoluteY
	end

	-- Convert back to UDim2
	local newPosition = UDim2.new(0, cappedX, 0, cappedY)
	-- local newPosition = UDim2.new(0, absoluteX, 0, absoluteY)
	frame.Position = newPosition
end

-- Main function to setup draggability for a frame
local SetupDraggability = function(frame: Frame)
	local dragging = false
	local mouseDragStartPosition: Vector2?
	local framePositionAtStartOfDrag: UDim2?

	frame.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			mouseDragStartPosition = Vector2.new(input.Position.X, input.Position.Y)
			framePositionAtStartOfDrag = frame.Position
			-- print("for this entire drag, startPOS is: " .. tostring(framePositionAtStartOfDrag))

			-- Create a new connection for InputChanged while dragging
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
					dragConnection:Disconnect()
					endConnection:Disconnect()
				end
			end)
		end
	end)
end

local SetupTitle = function(frame: Frame, titleFrame: Frame)
	titleFrame.Size = UDim2.new(1, 0, 0, 20)
	titleFrame.Position = UDim2.new(0, 0, 0, 0)
	titleFrame.BackgroundColor3 = colors.defaultGrey
	titleFrame.Parent = frame
end

local SetupCloseButton = function(frame: Frame) end

-- based on name and params, set up a frame which is the "outer" frame. That will have the controls attached to it.
-- you will be given the outer frame to position and the child "content" frame to populate
module.SetupFrame = function(
	name: string,
	draggable: boolean,
	resizable: boolean,
	minimizable: boolean
): { outerFrame: Frame, contentFrame: Frame }
	local outerFrame = Instance.new("Frame")
	outerFrame.Name = "outer_" .. name
	outerFrame.BackgroundTransparency = 1
	outerFrame.Visible = true

	if draggable then
		SetupDraggability(outerFrame)
	end
	if resizable then
		SetupResizeability(outerFrame)
	end
	if minimizable then
		SetupMinimizeability(outerFrame)
	end

	local contentFrame = Instance.new("Frame")
	contentFrame.Parent = outerFrame
	contentFrame.Name = "content_" .. name
	contentFrame.Size = UDim2.new(1, 0, 1, 0)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Position = UDim2.new(0, 0, 0, 0)
	contentFrame.Visible = true
	return { outerFrame = outerFrame, contentFrame = contentFrame }
end

_annotate("end")

return module
