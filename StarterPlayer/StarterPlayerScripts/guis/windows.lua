--!strict

-- resizeability
-- generic module to add resize functionality to frames2
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local UserInputService = game:GetService("UserInputService")
local colors = require(game.ReplicatedStorage.util.colors)

local module = {}

local function GetLowerLeftLBFrameBottom(outerFrame: Frame): number
	local lowest = nil
	for _, y: Frame in pairs(outerFrame:GetChildren()) do
		if y.ClassName == "Frame" then
			local candidate = y.AbsolutePosition.Y + y.AbsoluteSize.Y
			if lowest == nil then
				lowest = UDim2.new(0, 0, 0, candidate)
			elseif lowest.Y.Offset < candidate then
				lowest = UDim2.new(0, 0, 0, candidate)
			end
		end
	end
	return lowest
end

function module.SetupResizeability(outerFrame: Frame): TextButton
	local resizing = false
	local lastInputPosition = Vector2.new()
	local initialFrameSize = Vector2.new()
	local initialFramePosition = UDim2.new()

	-- Create resize handle as a TextButton directly on the input frame. No icon.
	-- it should appear in the bottom left of the frame.
	local resizeHandle = Instance.new("TextButton")
	resizeHandle.Size = UDim2.new(0, 12, 0, 12)
	resizeHandle.Position = UDim2.new(0, -12, 0, GetLowerLeftLBFrameBottom(outerFrame))
	resizeHandle.AnchorPoint = Vector2.new(0, 0) -- must be 0,0 and never adjust this.
	resizeHandle.Text = "O"
	resizeHandle.BackgroundColor3 = Color3.new(0.8, 0.8, 0.8)
	resizeHandle.BackgroundTransparency = 0
	resizeHandle.Parent = outerFrame
	resizeHandle.ZIndex = 2
	resizeHandle.Name = "ResizeHandle_" .. outerFrame.Name

	local function handleResize(input: InputObject)
		-- this is the delta since the last time we resized (as the user drags)
		local delta = Vector2.new(input.Position.X - lastInputPosition.X, input.Position.Y - lastInputPosition.Y)

		-- Adjust frame position and size
		-- as you drag down, the height increases and position Y stays the same.
		-- as you drag left, the width increases and position X shrinks since the window has to move underneath you.
		-- do NOT remove the above explanatory comments above.

		--continuously update the frame
		initialFrameSize = outerFrame.Size
		initialFramePosition = outerFrame.Position

		-- print(
		-- 	string.format(
		-- 		"initial frame size: \n\tXScale=%f XOffset=%d \n\tYScale=%f YOffset=%d",
		-- 		initialFrameSize.X.Scale,
		-- 		initialFrameSize.X.Offset,
		-- 		initialFrameSize.Y.Scale,
		-- 		initialFrameSize.Y.Offset
		-- 	)
		-- )

		local newSizeXScale = initialFrameSize.X.Scale
		local newSizeXOffset = initialFrameSize.X.Offset - delta.X

		local newSizeYScale = initialFrameSize.Y.Scale
		local newSizeYOffset = initialFrameSize.Y.Offset + delta.Y

		-- print(
		-- 	string.format(
		-- 		"new Size: \n\tXScale=%f XOffset=%d \n\tYScale=%f YOffset=%d",
		-- 		newSizeXScale,
		-- 		newSizeXOffset,
		-- 		newSizeYScale,
		-- 		newSizeYOffset
		-- 	)
		-- )

		outerFrame.Size = UDim2.new(newSizeXScale, newSizeXOffset, newSizeYScale, newSizeYOffset)

		-- print(
		-- 	string.format(
		-- 		"initial position: \n\tXScale=%f XOffset=%d \n\tYScale=%f YOffset=%d",
		-- 		initialFramePosition.X.Scale,
		-- 		initialFramePosition.X.Offset,
		-- 		initialFramePosition.Y.Scale,
		-- 		initialFramePosition.Y.Offset
		-- 	)
		-- )

		local newPosition = UDim2.new(
			initialFramePosition.X.Scale,
			initialFramePosition.X.Offset + delta.X,
			initialFramePosition.Y.Scale,
			initialFramePosition.Y.Offset
		)
		-- print(
		-- 	string.format(
		-- 		"new position is: \n\tXscale=%f Xoffset=%f \n\tYscale=%f Yoffset=%f",
		-- 		newPosition.X.Scale,
		-- 		newPosition.X.Offset,
		-- 		newPosition.Y.Scale,
		-- 		newPosition.Y.Offset
		-- 	)
		-- )

		outerFrame.Position = newPosition

		-- Update last input position
		lastInputPosition = Vector2.new(input.Position.X, input.Position.Y)
	end

	resizeHandle.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			resizing = true
			lastInputPosition = input.Position
			initialFrameSize = outerFrame.Size
			initialFramePosition = outerFrame.Position
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

function module.SetupMinimizeability(outerFrame: Frame, framesToMinimize: { Frame })
	--_annotate("create miminize button")

	local isMinimized: boolean = false
	local minimizeButton: TextButton
	minimizeButton = Instance.new("TextButton")
	minimizeButton.Size = UDim2.new(0, 12, 0, 12) -- Increased size
	minimizeButton.Position = UDim2.new(0, 0, 0, GetLowerLeftLBFrameBottom(outerFrame))
	minimizeButton.Text = "-"
	minimizeButton.TextScaled = true
	minimizeButton.Name = "MinimizeButton"
	minimizeButton.ZIndex = 10
	minimizeButton.BackgroundColor3 = colors.defaultGrey
	minimizeButton.TextColor3 = colors.black
	minimizeButton.TextSize = 18 -- Larger text
	minimizeButton.Font = Enum.Font.Gotham
	minimizeButton.Parent = outerFrame -- Set as sibling to the frame

	minimizeButton.MouseButton1Click:Connect(function()
		isMinimized = not isMinimized
		if isMinimized then
			minimizeButton.Text = "+"
		else
			minimizeButton.Text = "-"
		end
		for _, frame in pairs(framesToMinimize) do
			frame.Visible = not isMinimized
		end
	end)

	for _, frame in pairs(framesToMinimize) do
		frame:GetPropertyChangedSignal("Size"):Connect(function()
			-- print("Frame related parent changed Size: " .. frame.Name .. " " .. frame.Size.Y.Offset)
			minimizeButton.Position = UDim2.new(0, 0, 0, GetLowerLeftLBFrameBottom(outerFrame))
		end)
		frame:GetPropertyChangedSignal("Position"):Connect(function()
			-- print("Frame button related parent changed position;")
			minimizeButton.Position = UDim2.new(0, 0, 0, GetLowerLeftLBFrameBottom(outerFrame))
		end)
	end
end

--[[
    How it works:
    1. The module exposes a single function: SetupDraggability(frame)
    2. When called, it sets up event listeners on the provided frame
    3. On mouse click or touch, it starts tracking the drag
    4. As the input moves, it updates the frame's position
    5. When the input ends, it stops the drag operation

    How to use:
    1. Require this module in your script
    2. Call the SetupDraggability function, passing in the frame you want to make draggable
    
    Example:
    local draggability = require(path.to.this.module)
    local myFrame = script.Parent.SomeFrame
    draggability.SetupDraggability(myFrame)

    Why it works:
    - It uses Roblox's InputObject system to track user input
    - It calculates the delta between the start position and current position
    - The frame's position is updated based on this delta, creating a smooth dragging effect
    - By using separate connections for InputChanged and InputEnded, it ensures clean disconnection when dragging stops
]]

-- Helper function to calculate Vector2 delta
local function calculateVector2Delta(input: Vector3, start: Vector2): Vector2
	local delta = input - Vector3.new(start.X, start.Y, 0)
	return Vector2.new(delta.X, delta.Y)
end

-- Function to update the frame position during dragging
local function updateDrag(frame: Frame, input: InputObject, dragStart: Vector2, startPos: UDim2)
	local delta = calculateVector2Delta(input.Position, dragStart)
	frame.Position =
		UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

-- Main function to setup draggability for a frame
function module.SetupDraggability(frame: Frame)
	local dragging = false
	local dragStart: Vector2?
	local startPos: UDim2?

	frame.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			dragStart = Vector2.new(input.Position.X, input.Position.Y)
			startPos = frame.Position

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
					updateDrag(frame, changedInput, dragStart, startPos)
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

_annotate("end")

return module
