local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Create Frame
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 50)
frame.Position = UDim2.new(1, -220, 1, -70)
frame.BackgroundColor3 = Color3.new(0.8, 0.8, 0.8)
frame.Parent = screenGui

-- Create FOV Label
local fovLabel = Instance.new("TextLabel")
fovLabel.Size = UDim2.new(1, 0, 0, 20)
fovLabel.Position = UDim2.new(0, 0, 0, 0)
fovLabel.Text = "FOV: 70°"
fovLabel.Parent = frame

-- Create FOV Slider
local fovSlider = Instance.new("TextButton")
fovSlider.Size = UDim2.new(1, -20, 0, 20)
fovSlider.Position = UDim2.new(0, 10, 0, 25)
fovSlider.Text = ""
fovSlider.Parent = frame

-- Variables to store FOV
local currentFOV = 70 -- Default FOV
local minFOV = 20
local maxFOV = 180

-- Function to update camera FOV
local function updateFOV()
	local camera = workspace.CurrentCamera
	camera.FieldOfView = currentFOV
end

-- Function to handle slider input
local function handleSliderInput(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		local connection: RBXScriptConnection
		connection = UserInputService.InputChanged:Connect(function(inputObject: InputObject)
			if
				inputObject.UserInputType == Enum.UserInputType.MouseMovement
				or inputObject.UserInputType == Enum.UserInputType.Touch
			then
				local relativeX =
					math.clamp((inputObject.Position.X - fovSlider.AbsolutePosition.X) / fovSlider.AbsoluteSize.X, 0, 1)
				currentFOV = minFOV + (maxFOV - minFOV) * relativeX
				fovLabel.Text = string.format("FOV: %.1f°", currentFOV)
				updateFOV()
			end
		end)

		UserInputService.InputEnded:Connect(function(inputObject: InputObject)
			if inputObject == input then
				connection:Disconnect()
			end
		end)
	end
end

-- Connect input handler
fovSlider.InputBegan:Connect(handleSliderInput)

-- Initial FOV setup
updateFOV()
