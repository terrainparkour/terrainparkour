--!strict

-- draggability.lua
-- This module provides functionality to make GUI frames draggable in Roblox.

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

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local UserInputService = game:GetService("UserInputService")

local module = {}

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
