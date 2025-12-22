--!strict
-- dragUtil.lua (ReplicatedStorage/gui/activeRunWidgets/dragUtil.lua)
-- Shared utility for making UI elements draggable with edge snapping to screen and other widgets.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local UserInputService = game:GetService("UserInputService")

local module = {}

-- Snapping configuration
local SCREEN_SNAP_THRESHOLD = 20 -- Pixels within which to snap to screen edge
local EDGE_PADDING = 4 -- Padding from screen edge when snapped
local CORNER_ATTRACT_RADIUS = 30 -- Pixels within which corners attract to each other
local EDGE_SNAP_THRESHOLD = 15 -- Pixels within which edges snap to each other
local WIDGET_GAP = 2 -- Gap between widgets when docking side-by-side

-- Registry of all draggable frames for widget-to-widget snapping
local registeredFrames: { [GuiObject]: boolean } = {}

export type DragConfig = {
	frame: GuiObject,
	onPositionChanged: ((position: UDim2) -> ())?, -- Called during drag (for live preview)
	onDragEnd: ((position: UDim2) -> ())?, -- Called when drag finishes (for saving)
	dragHandle: GuiObject?, -- Optional separate handle; if nil, frame itself is draggable
	enableEdgeSnap: boolean?, -- Enable snapping to screen edges (default: true)
	enableWidgetSnap: boolean?, -- Enable snapping to other widgets (default: true)
}

-- Register a frame for widget-to-widget snapping
function module.registerFrame(frame: GuiObject)
	registeredFrames[frame] = true
	_annotate(string.format("Registered frame for snapping: %s (total: %d)", frame.Name, module.getRegisteredCount()))
end

-- Get count of registered frames (for debugging)
function module.getRegisteredCount(): number
	local count = 0
	for _ in pairs(registeredFrames) do
		count = count + 1
	end
	return count
end

-- Unregister a frame
function module.unregisterFrame(frame: GuiObject)
	registeredFrames[frame] = nil
end

-- Get all registered frames except the specified one
local function getOtherFrames(excludeFrame: GuiObject): { GuiObject }
	local others = {}
	for registeredFrame, _ in pairs(registeredFrames) do
		if registeredFrame ~= excludeFrame and registeredFrame.Parent ~= nil then
			table.insert(others, registeredFrame)
		end
	end
	return others
end

-- Apply screen edge snapping (hard snap when within threshold)
local function applyScreenEdgeSnapping(topLeftX: number, topLeftY: number, frameSize: Vector2, viewportSize: Vector2): (number, number)
	local snappedX = topLeftX
	local snappedY = topLeftY

	-- Left edge snap
	if topLeftX < SCREEN_SNAP_THRESHOLD then
		snappedX = EDGE_PADDING
	end

	-- Right edge snap
	local rightEdge = topLeftX + frameSize.X
	if rightEdge > viewportSize.X - SCREEN_SNAP_THRESHOLD then
		snappedX = viewportSize.X - frameSize.X - EDGE_PADDING
	end

	-- Top edge snap
	if topLeftY < SCREEN_SNAP_THRESHOLD then
		snappedY = EDGE_PADDING
	end

	-- Bottom edge snap
	local bottomEdge = topLeftY + frameSize.Y
	if bottomEdge > viewportSize.Y - SCREEN_SNAP_THRESHOLD then
		snappedY = viewportSize.Y - frameSize.Y - EDGE_PADDING
	end

	return snappedX, snappedY
end

-- Corner position type
type Corner = {
	x: number,
	y: number,
	-- Offset from top-left: how much to add to top-left to snap this corner to target
	offsetX: number,
	offsetY: number,
}

-- Find horizontal edge snapping when widgets vertically overlap
-- Returns pullX or 0 if no edge is close enough
local function findHorizontalEdgeSnap(topLeftX: number, topLeftY: number, frameSize: Vector2, excludeFrame: GuiObject): number
	local otherFrames = getOtherFrames(excludeFrame)
	if #otherFrames == 0 then
		return 0
	end

	local myLeft = topLeftX
	local myRight = topLeftX + frameSize.X
	local myTop = topLeftY
	local myBottom = topLeftY + frameSize.Y

	local bestPullX = 0
	local bestDist = math.huge

	for _, other in ipairs(otherFrames) do
		local otherPos = other.AbsolutePosition
		local otherSize = other.AbsoluteSize
		local otherLeft = otherPos.X
		local otherRight = otherPos.X + otherSize.X
		local otherTop = otherPos.Y
		local otherBottom = otherPos.Y + otherSize.Y

		-- Only snap if widgets vertically overlap (or nearly overlap)
		local verticalOverlap = myBottom > otherTop and myTop < otherBottom
		if not verticalOverlap then
			continue
		end

		-- Left-to-left alignment
		local leftToLeftDist = math.abs(myLeft - otherLeft)
		if leftToLeftDist < EDGE_SNAP_THRESHOLD and leftToLeftDist < bestDist then
			bestDist = leftToLeftDist
			bestPullX = otherLeft - myLeft
		end

		-- Right-to-right alignment
		local rightToRightDist = math.abs(myRight - otherRight)
		if rightToRightDist < EDGE_SNAP_THRESHOLD and rightToRightDist < bestDist then
			bestDist = rightToRightDist
			bestPullX = otherRight - myRight
		end

		-- Right-to-left docking (my right touches their left)
		local dockTargetRight = otherLeft - WIDGET_GAP
		local rightToLeftDist = math.abs(myRight - dockTargetRight)
		if rightToLeftDist < EDGE_SNAP_THRESHOLD and rightToLeftDist < bestDist then
			bestDist = rightToLeftDist
			bestPullX = dockTargetRight - myRight
		end

		-- Left-to-right docking (my left touches their right)
		local dockTargetLeft = otherRight + WIDGET_GAP
		local leftToRightDist = math.abs(myLeft - dockTargetLeft)
		if leftToRightDist < EDGE_SNAP_THRESHOLD and leftToRightDist < bestDist then
			bestDist = leftToRightDist
			bestPullX = dockTargetLeft - myLeft
		end
	end

	return bestPullX
end

-- Find the closest corner pair and return the pull needed to align them
-- Returns (pullX, pullY) or (0, 0) if no corner is close enough
local function findCornerAttraction(topLeftX: number, topLeftY: number, frameSize: Vector2, excludeFrame: GuiObject): (number, number)
	local otherFrames = getOtherFrames(excludeFrame)
	if #otherFrames == 0 then
		return 0, 0
	end

	-- My corners with their offsets from top-left position
	local myCorners: { Corner } = {
		{ x = topLeftX, y = topLeftY, offsetX = 0, offsetY = 0 }, -- top-left
		{ x = topLeftX + frameSize.X, y = topLeftY, offsetX = frameSize.X, offsetY = 0 }, -- top-right
		{ x = topLeftX, y = topLeftY + frameSize.Y, offsetX = 0, offsetY = frameSize.Y }, -- bottom-left
		{ x = topLeftX + frameSize.X, y = topLeftY + frameSize.Y, offsetX = frameSize.X, offsetY = frameSize.Y }, -- bottom-right
	}

	-- Find the closest corner-to-corner pair across all widgets
	local bestDist = math.huge
	local bestPullX = 0
	local bestPullY = 0

	for _, other in ipairs(otherFrames) do
		local otherPos = other.AbsolutePosition
		local otherSize = other.AbsoluteSize

		-- Other widget's corners
		local otherCorners = {
			Vector2.new(otherPos.X, otherPos.Y), -- top-left
			Vector2.new(otherPos.X + otherSize.X, otherPos.Y), -- top-right
			Vector2.new(otherPos.X, otherPos.Y + otherSize.Y), -- bottom-left
			Vector2.new(otherPos.X + otherSize.X, otherPos.Y + otherSize.Y), -- bottom-right
		}

		-- Check each of my corners against each of their corners
		for _, myCorner in ipairs(myCorners) do
			for _, otherCorner in ipairs(otherCorners) do
				local dx = otherCorner.X - myCorner.x
				local dy = otherCorner.Y - myCorner.y
				local dist = math.sqrt(dx * dx + dy * dy)

				-- Only attract if within radius AND this is the closest pair
				if dist < CORNER_ATTRACT_RADIUS and dist < bestDist then
					bestDist = dist
					-- Pull to align this corner pair exactly
					bestPullX = dx
					bestPullY = dy
				end
			end
		end
	end

	-- If we found a close corner pair, return the pull
	-- The pull is scaled by proximity (closer = stronger, but always reaches target when very close)
	if bestDist < CORNER_ATTRACT_RADIUS then
		-- Hard snap when very close (< 5px), soft pull otherwise
		if bestDist < 5 then
			return bestPullX, bestPullY
		else
			-- Pull strength increases as we get closer
			local strength = 1 - (bestDist / CORNER_ATTRACT_RADIUS)
			return bestPullX * strength, bestPullY * strength
		end
	end

	return 0, 0
end

-- Clamp position to keep frame on screen
local function clampToScreen(absoluteX: number, absoluteY: number, frameSize: Vector2, viewportSize: Vector2): (number, number)
	local maxX = math.max(0, viewportSize.X - frameSize.X)
	local maxY = math.max(0, viewportSize.Y - frameSize.Y)

	local clampedX = math.clamp(absoluteX, 0, maxX)
	local clampedY = math.clamp(absoluteY, 0, maxY)

	return clampedX, clampedY
end

-- Makes a frame draggable. Returns a cleanup function.
-- Uses handle.InputBegan directly - Roblox's native input system handles layer order.
function module.makeDraggable(config: DragConfig): () -> ()
	local frame = config.frame
	local handle = config.dragHandle or frame
	local dragging = false
	local dragStart: Vector2?
	local startPos: UDim2?
	local lastDragPos: UDim2? -- Track the last position during drag for saving on end
	local enableEdgeSnap = if config.enableEdgeSnap == nil then true else config.enableEdgeSnap
	local enableWidgetSnap = if config.enableWidgetSnap == nil then true else config.enableWidgetSnap

	-- Register this frame for widget-to-widget snapping
	module.registerFrame(frame)

	local connections: { RBXScriptConnection } = {}

	-- InputBegan on the handle itself - only fires when this element receives input
	-- Roblox's native input system already respects layer order (topmost gets the event)
	local function onHandleInputBegan(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local clickPos = Vector2.new(input.Position.X, input.Position.Y)

			dragging = true
			dragStart = clickPos
			startPos = frame.Position
			lastDragPos = nil
			_annotate(string.format("DRAG START on %s at %.0f, %.0f", frame.Name, input.Position.X, input.Position.Y))
		end
	end

	local function onInputEnded(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			-- IMMEDIATELY clear drag state to stop any pending InputChanged events
			local wasDragging = dragging
			local finalPos = lastDragPos
			dragging = false
			dragStart = nil
			startPos = nil
			lastDragPos = nil

			if not wasDragging then
				return
			end

			_annotate(
				string.format(
					"INPUT ENDED - wasDragging=%s, finalPos=%s, hasOnDragEnd=%s",
					tostring(wasDragging),
					if finalPos then "yes" else "nil",
					if config.onDragEnd then "yes" else "no"
				)
			)

			-- Save final position when drag ends (after state is cleared)
			if finalPos and config.onDragEnd then
				_annotate(string.format("SAVING position for %s: %.0f, %.0f (offset)", frame.Name, finalPos.X.Offset, finalPos.Y.Offset))
				config.onDragEnd(finalPos)
			elseif not finalPos then
				_annotate(string.format("NOT SAVING - finalPos is nil (frame: %s)", frame.Name))
			end
		end
	end

	local function onInputChanged(input: InputObject)
		if not dragging or not dragStart or not startPos then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart

			-- Get viewport and frame size
			local camera = workspace.CurrentCamera
			if not camera then
				return
			end
			local viewportSize = camera.ViewportSize
			local frameSize = frame.AbsoluteSize

			-- Calculate raw absolute position from UDim2
			local rawAbsoluteX = startPos.X.Scale * viewportSize.X + startPos.X.Offset + delta.X
			local rawAbsoluteY = startPos.Y.Scale * viewportSize.Y + startPos.Y.Offset + delta.Y

			-- Account for anchor point to get top-left corner
			local anchorOffset = frame.AnchorPoint * frameSize
			local topLeftX = rawAbsoluteX - anchorOffset.X
			local topLeftY = rawAbsoluteY - anchorOffset.Y

			-- Clamp to keep on screen first
			topLeftX, topLeftY = clampToScreen(topLeftX, topLeftY, frameSize, viewportSize)

			-- Apply screen edge snapping (only at screen edges)
			if enableEdgeSnap then
				topLeftX, topLeftY = applyScreenEdgeSnapping(topLeftX, topLeftY, frameSize, viewportSize)
			end

			-- Apply widget snapping (corners + horizontal edges)
			if enableWidgetSnap then
				-- First check horizontal edge snapping (when widgets vertically overlap)
				local edgePullX = findHorizontalEdgeSnap(topLeftX, topLeftY, frameSize, frame)
				if edgePullX ~= 0 then
					topLeftX = topLeftX + edgePullX
				else
					-- Fall back to corner-to-corner attraction if no edge snap
					local pullX, pullY = findCornerAttraction(topLeftX, topLeftY, frameSize, frame)
					topLeftX = topLeftX + pullX
					topLeftY = topLeftY + pullY
				end
			end

			-- Convert back to position with anchor point
			local finalX = topLeftX + anchorOffset.X
			local finalY = topLeftY + anchorOffset.Y

			-- Store as offset-based UDim2 for precision
			local newPos = UDim2.fromOffset(finalX, finalY)
			frame.Position = newPos
			local wasNil = lastDragPos == nil
			lastDragPos = newPos

			-- Log first position update to confirm dragging is working
			if wasNil then
				_annotate(string.format("DRAG MOVE first update for %s: %.0f, %.0f", frame.Name, finalX, finalY))
			end

			-- onPositionChanged is for live preview during drag (not for saving)
			if config.onPositionChanged then
				config.onPositionChanged(newPos)
			end
		end
	end

	-- Use handle.InputBegan - Roblox's native input handles layer order automatically
	-- Input on child elements bubbles up to the handle
	table.insert(connections, handle.InputBegan:Connect(onHandleInputBegan))
	-- InputEnded/InputChanged must use UserInputService because mouse often leaves handle during drag
	table.insert(connections, UserInputService.InputEnded:Connect(onInputEnded))
	table.insert(connections, UserInputService.InputChanged:Connect(onInputChanged))

	-- Return cleanup function
	return function()
		module.unregisterFrame(frame)
		for _, conn in ipairs(connections) do
			conn:Disconnect()
		end
	end
end

-- Creates a small drag handle icon (three horizontal lines)
-- Uses TextButton to properly sink input and prevent click-through
function module.createDragHandle(parent: GuiObject, position: UDim2): TextButton
	local handle = Instance.new("TextButton")
	handle.Name = "DragHandle"
	handle.Size = UDim2.fromOffset(20, 16)
	handle.Position = position
	handle.AnchorPoint = Vector2.new(0.5, 0.5)
	handle.BackgroundTransparency = 0.7
	handle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	handle.Text = "≡"
	handle.TextColor3 = Color3.fromRGB(180, 180, 180)
	handle.TextSize = 14
	handle.Font = Enum.Font.GothamBold
	handle.BorderSizePixel = 0
	handle.AutoButtonColor = false -- Prevent default button behavior
	handle.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = handle

	-- Hover effect
	handle.MouseEnter:Connect(function()
		handle.BackgroundTransparency = 0.4
		handle.TextColor3 = Color3.fromRGB(255, 255, 255)
	end)

	handle.MouseLeave:Connect(function()
		handle.BackgroundTransparency = 0.7
		handle.TextColor3 = Color3.fromRGB(180, 180, 180)
	end)

	return handle
end

-- Make a frame block input (prevent click-through to elements below)
function module.makeInputSink(frame: GuiObject)
	-- Setting Active = true makes the frame intercept input
	if frame:IsA("GuiButton") then
		-- Already a button, it sinks input by default
		return
	end

	-- For frames, we need to add an invisible button overlay
	local existingSink = frame:FindFirstChild("_InputSink")
	if existingSink then
		return -- Already has an input sink
	end

	local sinkButton = Instance.new("TextButton")
	sinkButton.Name = "_InputSink"
	sinkButton.Size = UDim2.fromScale(1, 1)
	sinkButton.Position = UDim2.fromScale(0, 0)
	sinkButton.BackgroundTransparency = 1
	sinkButton.Text = ""
	sinkButton.ZIndex = 0 -- Behind other content
	sinkButton.AutoButtonColor = false
	sinkButton.Parent = frame
end

_annotate("end")
return module
