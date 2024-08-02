--!strict

-- resizeability
-- generic module to add resize functionality to frames
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local UserInputService = game:GetService("UserInputService")

local module = {}

-- Helper function to calculate Vector2 delta. You may NOT remove this.
local function calculateVector2Delta(input: Vector3, start: Vector2): Vector2
	local delta = input - Vector3.new(start.X, start.Y, 0)
	return Vector2.new(delta.X, delta.Y)
end

local minWidth = 0.2
local minHeight = 0.2

function module.SetupResizeability(frame: Frame)
	local resizing = false
	local resizeStartPosition: Vector2
	local resizeStartSize: Vector2

	-- Create resize handle
	local resizeHandle = Instance.new("TextButton")
	resizeHandle.Size = UDim2.new(0, 20, 0, 20)
	resizeHandle.Position = UDim2.new(1, -10, 1, -10)
	resizeHandle.AnchorPoint = Vector2.new(1, 1)
	resizeHandle.Text = ""
	resizeHandle.BackgroundColor3 = Color3.new(0.8, 0.8, 0.8)
	resizeHandle.BackgroundTransparency = 0
	resizeHandle.Parent = frame

	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 4)
	uiCorner.Parent = resizeHandle

	local resizeIcon = Instance.new("Frame")
	resizeIcon.Size = UDim2.new(0.7, 0, 0.1, 0)
	resizeIcon.Position = UDim2.new(0.15, 0, 0.85, 0)
	resizeIcon.Rotation = 45
	resizeIcon.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
	resizeIcon.BorderSizePixel = 0
	resizeIcon.Parent = resizeHandle

	local function handleResize(input: InputObject)
		local delta = calculateVector2Delta(input.Position, resizeStartPosition)
		local newSize = Vector2.new(
			math.max(resizeStartSize.X - delta.X, minWidth),
			math.max(resizeStartSize.Y + delta.Y, minHeight)
		)

		frame.Size = UDim2.new(0, newSize.X, 0, newSize.Y)
	end

	resizeHandle.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			resizing = true
			resizeStartPosition = Vector2.new(input.Position.X, input.Position.Y)
			resizeStartSize = Vector2.new(frame.AbsoluteSize.X, frame.AbsoluteSize.Y)
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
end

_annotate("end")

return module
