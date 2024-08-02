--!strict

-- minimizeability
-- module to add minimize functionality to frames
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local colors = require(game.ReplicatedStorage.util.colors)

local function GetMinimizeButtonPosition(frame: Frame): UDim2
	-- _annotate("got miminize button position.")
	--sets  it  just to the left of the upper left corner of the frame
	local location = UDim2.fromOffset(frame.AbsolutePosition.X, frame.AbsolutePosition.Y)
	return location
end

function module.SetupMinimizeability(frame: Frame)
	_annotate("create miminize button")
	local isMinimized: boolean = false
	local minimizeButton: TextButton
	minimizeButton = Instance.new("TextButton")
	minimizeButton.Size = UDim2.new(0, 15, 0, 15) -- Increased size
	minimizeButton.Position = GetMinimizeButtonPosition(frame)
	minimizeButton.Text = "-"
	minimizeButton.TextScaled = true
	minimizeButton.Name = "MinimizeButton"
	minimizeButton.ZIndex = 10
	minimizeButton.BackgroundColor3 = colors.defaultGrey
	minimizeButton.TextColor3 = colors.black
	minimizeButton.TextSize = 18 -- Larger text
	minimizeButton.Font = Enum.Font.Gotham
	minimizeButton.Parent = frame.Parent -- Set as sibling to the frame

	minimizeButton.MouseButton1Click:Connect(function()
		isMinimized = not isMinimized
		if isMinimized then
			frame.Visible = false
			minimizeButton.Text = "+"
		else
			frame.Visible = true
			minimizeButton.Text = "-"
		end
	end)

	-- Ensure the minimize button moves with the frame if the frame's position or size
	frame:GetPropertyChangedSignal("Size"):Connect(function()
		-- _annotate("minize button related parent changed position")
		minimizeButton.Position = GetMinimizeButtonPosition(frame)
	end)

	frame:GetPropertyChangedSignal("Position"):Connect(function()
		-- _annotate("minize button related parent changed position")
		minimizeButton.Position = GetMinimizeButtonPosition(frame)
	end)
end

_annotate("end")

return module
