--!strict

-- uiPositionManager.lua, used in clients
-- Manages UI element positioning to keep them on screen

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local managedFrames: { Frame } = {}

local function adjustFramePosition(frame: Frame)
	local viewportSize = workspace.CurrentCamera.ViewportSize
	local frameSize = frame.AbsoluteSize
	local framePosition = frame.AbsolutePosition

	-- Calculate the maximum allowed position
	local maxX = math.max(0, viewportSize.X - frameSize.X)
	local maxY = math.max(0, viewportSize.Y - frameSize.Y)

	-- Clamp the position to keep the frame on screen
	local newX = math.clamp(framePosition.X, 0, maxX)
	local newY = math.clamp(framePosition.Y, 0, maxY)

	-- If the frame is larger than the viewport, align it to the left or top edge
	if frameSize.X > viewportSize.X then
		newX = 0
	end
	if frameSize.Y > viewportSize.Y then
		newY = 0
	end

	if newX ~= framePosition.X or newY ~= framePosition.Y then
		frame.Position = UDim2.new(0, newX, 0, newY)
		_annotate(string.format("Adjusted position of frame %s to (%d, %d)", frame.Name, newX, newY))
	end
end

local function checkAllFrames()
	for _, frame in ipairs(managedFrames) do
		adjustFramePosition(frame)
	end
end

local function onWindowResize()
	_annotate("Window resized, checking all frames")
	checkAllFrames()
end

function module.registerFrame(frame: Frame)
	table.insert(managedFrames, frame)
	_annotate(string.format("Registered frame %s for position management", frame.Name))

	frame:GetPropertyChangedSignal("Position"):Connect(function()
		adjustFramePosition(frame)
	end)
end

-- Set up periodic check
RunService.Heartbeat:Connect(function()
	checkAllFrames()
end)

-- Listen for window resize events
UserInputService.WindowFocused:Connect(onWindowResize)
UserInputService.WindowFocusReleased:Connect(onWindowResize)

_annotate("end")
return module
