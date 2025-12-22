--!strict

-- uiPositionManager.lua, used in clients
-- Manages UI element positioning to keep them on screen

local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local managedFrames: { Frame } = {}
local adjustingFrames: { [Frame]: boolean } = {}
local draggingFrames: { [Frame]: boolean } = {}

-- Called by windowFunctions when drag starts/ends
function module.setDragging(frame: Frame, isDragging: boolean)
	draggingFrames[frame] = isDragging or nil
end

local function adjustFramePosition(frame: Frame)
	-- Skip frames that are currently being dragged - drag logic handles clamping
	if draggingFrames[frame] then
		return
	end

	-- Prevent re-entrancy - if we're already adjusting this frame, ignore this call
	if adjustingFrames[frame] then
		return
	end

	local currentCamera = Workspace.CurrentCamera
	if not currentCamera then
		return
	end

	local viewportSize = currentCamera.ViewportSize
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

	-- Use tolerance to avoid floating-point jitter triggering unnecessary adjustments
	local tolerance = 1
	if math.abs(newX - framePosition.X) > tolerance or math.abs(newY - framePosition.Y) > tolerance then
		adjustingFrames[frame] = true
		-- Preserve scale-based positioning: convert clamped pixels back to scale
		local scaleX = newX / viewportSize.X
		local scaleY = newY / viewportSize.Y
		frame.Position = UDim2.fromScale(scaleX, scaleY)
		adjustingFrames[frame] = false
		-- Note: If this fires constantly during drag, there may be a GUI inset mismatch
		-- or duplicate clamping between drag logic and this manager
		_annotate(string.format("[CLAMP] %s: (%.0f,%.0f)->(%.0f,%.0f) size=%.0fx%.0f", frame.Name, framePosition.X, framePosition.Y, newX, newY, frameSize.X, frameSize.Y))
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

	frame:GetPropertyChangedSignal("Size"):Connect(function()
		adjustFramePosition(frame)
	end)

	-- Note: We intentionally do NOT listen to AbsoluteSize.
	-- When Size changes, AbsoluteSize also changes, causing double-fire.
	-- When viewport resizes, the ViewportSize listener already calls checkAllFrames().

	-- Note: Removed automatic adjustment on registration.
	-- Persistence system handles initial clamping; this avoids
	-- conflicting with intentionally loaded positions.
end

local viewportConnection: RBXScriptConnection? = nil

local function bindViewportResizeListener()
	if viewportConnection then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(onWindowResize)
end

-- Listen for window resize events
UserInputService.WindowFocused:Connect(onWindowResize)
UserInputService.WindowFocusReleased:Connect(onWindowResize)

bindViewportResizeListener()

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	bindViewportResizeListener()
	onWindowResize()
end)

_annotate("end")
return module
