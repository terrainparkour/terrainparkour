--!strict

-- stickyScrollingFrame.lua
-- a scrolling frame that snaps to rows and also allows sticky elements.
-- Uses "visibility hack" to support sticky interleaved rows.
-- Supports mouse wheel, touch/swipe, and shows a scroll position indicator.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local colors = require(game.ReplicatedStorage.util.colors)

local module = {}

module.CreateStickyScrollingFrame = function(rowHeight: number, dataRowsToShowCount: number?)
	local actualDataRowsToShowCount: number
	if dataRowsToShowCount then
		actualDataRowsToShowCount = dataRowsToShowCount
		_annotate(string.format("dataRowsToShowCount received: %d", actualDataRowsToShowCount))
	else
		actualDataRowsToShowCount = 10
		_annotate(string.format("dataRowsToShowCount fallback to: %d", actualDataRowsToShowCount))
	end

	local guiIsDoneAdding = false
	local rowFrames: { Frame } = {} -- Store references to all elements
	local currentRowHeight: number = rowHeight -- Track current row height for dynamic scaling

	-- Container frame holds both the ScrollingFrame and the scroll indicator
	-- This prevents the UIListLayout from affecting the scroll indicator
	local ContainerFrame = Instance.new("Frame")
	ContainerFrame.Name = "StickyScrollingContainer"
	ContainerFrame.Size = UDim2.new(1, 0, 1, 0)
	ContainerFrame.BackgroundTransparency = 1
	ContainerFrame.BorderSizePixel = 0

	local ScrollingFrame = Instance.new("ScrollingFrame")
	ScrollingFrame.Name = "StickyScrollingFrame"
	ScrollingFrame.Size = UDim2.new(1, 0, 1, 0)
	ScrollingFrame.Parent = ContainerFrame

	local UIListLayout = Instance.new("UIListLayout")

	-- "Fake" scrolling setup - we manage visibility ourselves for sticky row support
	ScrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.None
	ScrollingFrame.ElasticBehavior = Enum.ElasticBehavior.Always
	ScrollingFrame.ScrollingEnabled = false -- Disable native scrolling (we handle it manually)
	ScrollingFrame.AutomaticSize = Enum.AutomaticSize.None
	ScrollingFrame.ScrollBarThickness = 0 -- No native scrollbar (we draw our own indicator)
	ScrollingFrame.VerticalScrollBarInset = Enum.ScrollBarInset.None
	ScrollingFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	ScrollingFrame.BackgroundTransparency = 1 -- Transparent so rows are visible
	ScrollingFrame.BorderSizePixel = 0

	-- Scroll position indicator - sibling to ScrollingFrame, not affected by UIListLayout
	local scrollIndicatorTrack = Instance.new("Frame")
	scrollIndicatorTrack.Name = "ScrollIndicatorTrack"
	scrollIndicatorTrack.Size = UDim2.new(0, 9, 1, 0)
	scrollIndicatorTrack.Position = UDim2.new(1, -9, 0, 2)
	scrollIndicatorTrack.BackgroundColor3 = colors.defaultGrey
	scrollIndicatorTrack.BackgroundTransparency = 0
	scrollIndicatorTrack.BorderSizePixel = 0
	scrollIndicatorTrack.ZIndex = 10
	scrollIndicatorTrack.Parent = ContainerFrame -- Parent to container, not ScrollingFrame

	local scrollIndicatorThumb = Instance.new("Frame")
	scrollIndicatorThumb.Name = "ScrollIndicatorThumb"
	scrollIndicatorThumb.Size = UDim2.new(1, 0, 0.2, 0) -- Will be updated dynamically
	scrollIndicatorThumb.Position = UDim2.new(0, 0, 0, 0)
	scrollIndicatorThumb.BackgroundColor3 = colors.black
	scrollIndicatorThumb.BorderSizePixel = 0
	scrollIndicatorThumb.ZIndex = 11
	scrollIndicatorThumb.Parent = scrollIndicatorTrack

	local thumbCorner = Instance.new("UICorner")
	thumbCorner.CornerRadius = UDim.new(0, 3)
	thumbCorner.Parent = scrollIndicatorThumb

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 3)
	trackCorner.Parent = scrollIndicatorTrack

	-- Touch scrolling state
	local touchStartY: number? = nil
	local touchStartIndex: number = 1

	-- Configure UIListLayout for row ordering
	UIListLayout.Parent = ScrollingFrame
	UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local firstRegularRowDisplayedIndex = 1

	-- Helper: determine whether a non-sticky row is filtered out
	local function isRegularRowFilteredOut(row: Frame): boolean
		local stickyAttr = row:GetAttribute("Sticky")
		if stickyAttr == 1 then
			return false
		end
		return row:GetAttribute("FilteredOut") == 1
	end

	-- Update scroll indicator position and size based on current scroll state
	local function updateScrollIndicator()
		if not guiIsDoneAdding then
			return
		end

		local stickyCount = 0
		local regularRowIndices: { number } = {}
		for index, row in ipairs(rowFrames) do
			if row:GetAttribute("Sticky") == 1 then
				stickyCount += 1
			else
				if isRegularRowFilteredOut(row) then
					continue
				end
				table.insert(regularRowIndices, index)
			end
		end

		local regularCount = #regularRowIndices
		local availableSlots = math.max(1, actualDataRowsToShowCount - stickyCount)

		-- Hide indicator if all rows fit without scrolling
		if regularCount <= availableSlots then
			scrollIndicatorTrack.Visible = false
			return
		end

		scrollIndicatorTrack.Visible = true

		-- Calculate thumb size: proportion of visible rows to total rows
		local thumbSizeRatio = math.clamp(availableSlots / regularCount, 0.1, 1)
		scrollIndicatorThumb.Size = UDim2.new(1, 0, thumbSizeRatio, 0)

		-- Calculate thumb position based on current scroll index (virtual index among regular rows)
		local currentVirtualIndex = 1
		for i, idx in ipairs(regularRowIndices) do
			if idx == firstRegularRowDisplayedIndex then
				currentVirtualIndex = i
				break
			end
			if idx > firstRegularRowDisplayedIndex then
				currentVirtualIndex = math.max(1, i - 1)
				break
			end
		end

		local maxVirtualIndex = math.max(1, regularCount - availableSlots + 1)
		local maxOffset = maxVirtualIndex - 1
		local currentOffset = currentVirtualIndex - 1

		local scrollRatio = if maxOffset > 0 then currentOffset / maxOffset else 0
		local maxThumbY = 1 - thumbSizeRatio
		scrollIndicatorThumb.Position = UDim2.new(0, 0, scrollRatio * maxThumbY, 0)
	end

	-- Dynamic row height: when viewport resizes, scale rows to maintain visible count
	local function updateRowHeights()
		if not guiIsDoneAdding then
			return
		end
		local viewportHeight = ScrollingFrame.AbsoluteSize.Y
		if viewportHeight <= 0 or actualDataRowsToShowCount <= 0 then
			return
		end

		local newRowHeight = viewportHeight / actualDataRowsToShowCount
		if math.abs(newRowHeight - currentRowHeight) < 1 then
			return -- Skip tiny changes to avoid thrashing
		end

		currentRowHeight = newRowHeight
		for _, row in ipairs(rowFrames) do
			row.Size = UDim2.new(1, 0, 0, currentRowHeight)
		end
		_annotate(string.format("updateRowHeights: viewport=%.0f, rows=%d, rowHeight=%.1f", viewportHeight, actualDataRowsToShowCount, currentRowHeight))
	end

	ScrollingFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateRowHeights)

	-- Helper: get count of sticky rows and list of regular row indices
	local function getStickyInfo()
		local stickyCount = 0
		local regularRowIndices: { number } = {}
		for index, row in ipairs(rowFrames) do
			local stickyAttr = row:GetAttribute("Sticky")
			if stickyAttr == 1 then
				stickyCount += 1
			else
				if isRegularRowFilteredOut(row) then
					continue
				end
				table.insert(regularRowIndices, index)
			end
		end
		return stickyCount, regularRowIndices
	end

	local function ensureFirstRegularRowIndexValid(regularRowIndices: { number })
		if #regularRowIndices == 0 then
			firstRegularRowDisplayedIndex = 1
			return
		end

		local found = false
		for _, idx in ipairs(regularRowIndices) do
			if idx == firstRegularRowDisplayedIndex then
				found = true
				break
			end
		end

		if not found then
			firstRegularRowDisplayedIndex = regularRowIndices[1]
		end
	end

	-- Helper: find first regular row index
	local function getFirstRegularRowIndex(): number
		for index, row in ipairs(rowFrames) do
			local stickyAttr = row:GetAttribute("Sticky")
			if stickyAttr ~= nil and stickyAttr ~= 1 and not isRegularRowFilteredOut(row) then
				return index
			end
		end
		return 1
	end

	-- Core logic: hide/show row elements
	local function adjustVisibility()
		if not guiIsDoneAdding then
			return
		end

		local _stickyCount, regularRowIndices = getStickyInfo()
		ensureFirstRegularRowIndexValid(regularRowIndices)

		-- 1. Hide all
		for _, row in ipairs(rowFrames) do
			row.Visible = false
		end

		-- 2. Show all stickies
		local shownCount = 0
		for _, row in ipairs(rowFrames) do
			if row:GetAttribute("Sticky") == 1 then
				row.Visible = true
				shownCount += 1
			end
		end

		-- 3. Show regular rows starting from index
		if shownCount < actualDataRowsToShowCount then
			local countNeeded = actualDataRowsToShowCount - shownCount
			local regularAdded = 0

			for index, row in ipairs(rowFrames) do
				if row:GetAttribute("Sticky") == 1 then
					continue
				end
				if isRegularRowFilteredOut(row) then
					continue
				end

				-- We only start showing if index >= our cursor
				if index >= firstRegularRowDisplayedIndex then
					if regularAdded < countNeeded then
						row.Visible = true
						if regularAdded == 0 then
							_annotate(string.format("First regular row shown: %s (idx %d, order %d)", row.Name, index, row.LayoutOrder))
						end
						regularAdded += 1
					end
				end
			end
		end

		_annotate(string.format("adjustVisibility: startRegular=%d, totalShown=%d (max %d)", firstRegularRowDisplayedIndex, shownCount + 0, actualDataRowsToShowCount))

		-- Update scroll position indicator
		updateScrollIndicator()
	end

	-- Handle Input
	local localPlayer = Players.LocalPlayer
	local mouse = localPlayer:GetMouse()

	-- Check if a point is within the scrolling frame bounds
	local function isPointInFrame(x: number, y: number): boolean
		if not guiIsDoneAdding then
			return false
		end

		local framePos = ScrollingFrame.AbsolutePosition
		local frameSize = ScrollingFrame.AbsoluteSize

		if frameSize.X == 0 or frameSize.Y == 0 then
			return false
		end

		if x < framePos.X or x > framePos.X + frameSize.X then
			return false
		end
		if y < framePos.Y or y > framePos.Y + frameSize.Y then
			return false
		end

		return true
	end

	-- Check if mouse is over frame
	local function isMouseOver(): boolean
		return isPointInFrame(mouse.X, mouse.Y)
	end

	-- Shared scroll logic: scroll by a number of rows (positive = down, negative = up)
	local function scrollByRows(rowDelta: number)
		local stickyCount, regularRowIndices = getStickyInfo()
		ensureFirstRegularRowIndexValid(regularRowIndices)
		local totalRegularRows = #regularRowIndices

		if totalRegularRows == 0 then
			return
		end

		local availableSlots = math.max(0, actualDataRowsToShowCount - stickyCount)

		-- Find current virtual index
		local currentVirtualIndex = 1
		for i, idx in ipairs(regularRowIndices) do
			if idx == firstRegularRowDisplayedIndex then
				currentVirtualIndex = i
				break
			end
			if idx > firstRegularRowDisplayedIndex then
				currentVirtualIndex = math.max(1, i - 1)
				break
			end
		end

		local maxVirtualIndex = math.max(1, totalRegularRows - availableSlots + 1)

		-- Apply scroll delta
		currentVirtualIndex = math.clamp(currentVirtualIndex + rowDelta, 1, maxVirtualIndex)

		-- Map back to rowFrames index
		firstRegularRowDisplayedIndex = regularRowIndices[currentVirtualIndex]
		adjustVisibility()
	end

	-- Mouse wheel scroll handler
	local function handleMouseWheelAction(_actionName: string, inputState: Enum.UserInputState, inputObject: InputObject)
		if inputState ~= Enum.UserInputState.Change then
			return Enum.ContextActionResult.Pass
		end

		if not isMouseOver() then
			return Enum.ContextActionResult.Pass
		end

		-- Scroll direction: Z < 0 means scroll down (show later rows)
		local direction = if inputObject.Position.Z < 0 then 1 else -1
		scrollByRows(direction)
		_annotate(string.format("MouseWheel scroll: direction=%d", direction))

		return Enum.ContextActionResult.Sink
	end

	-- Touch scroll handling via InputBegan/Changed/Ended on the frame itself
	local activeTouchId: InputObject? = nil

	local function handleTouchBegan(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		if not isPointInFrame(input.Position.X, input.Position.Y) then
			return
		end

		-- Start tracking this touch (store the InputObject reference for identity comparison)
		activeTouchId = input
		touchStartY = input.Position.Y
		touchStartIndex = firstRegularRowDisplayedIndex
		_annotate(string.format("Touch began: y=%.0f", input.Position.Y))
	end

	local function handleTouchMoved(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		if activeTouchId ~= input then
			return
		end

		if not touchStartY then
			return
		end

		-- Calculate how many rows to scroll based on drag distance
		local deltaY = touchStartY - input.Position.Y -- Positive = dragged up = scroll down
		local rowsToScroll = math.floor(deltaY / currentRowHeight)

		if rowsToScroll ~= 0 then
			-- Find target index from start position
			local stickyCount, regularRowIndices = getStickyInfo()
			local totalRegularRows = #regularRowIndices

			if totalRegularRows > 0 then
				local availableSlots = math.max(0, actualDataRowsToShowCount - stickyCount)
				local maxVirtualIndex = math.max(1, totalRegularRows - availableSlots + 1)

				-- Find start virtual index
				local startVirtualIndex = 1
				for i, idx in ipairs(regularRowIndices) do
					if idx == touchStartIndex then
						startVirtualIndex = i
						break
					end
				end

				local targetVirtualIndex = math.clamp(startVirtualIndex + rowsToScroll, 1, maxVirtualIndex)
				local newFrameIndex = regularRowIndices[targetVirtualIndex]

				if newFrameIndex ~= firstRegularRowDisplayedIndex then
					firstRegularRowDisplayedIndex = newFrameIndex
					adjustVisibility()
					_annotate(string.format("Touch scroll: delta=%.0f, rows=%d", deltaY, rowsToScroll))
				end
			end
		end
	end

	local function handleTouchEnded(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		if activeTouchId == input then
			activeTouchId = nil
			touchStartY = nil
			_annotate("Touch ended")
		end
	end

	-- Connect touch events to the ScrollingFrame
	ScrollingFrame.InputBegan:Connect(handleTouchBegan)
	ScrollingFrame.InputChanged:Connect(handleTouchMoved)
	ScrollingFrame.InputEnded:Connect(handleTouchEnded)

	-- Also handle touch on UserInputService for cases where touch moves outside frame
	local touchMovedConnection = UserInputService.InputChanged:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		handleTouchMoved(input)
	end)

	local touchEndedConnection = UserInputService.InputEnded:Connect(function(input: InputObject, _gameProcessed: boolean)
		handleTouchEnded(input)
	end)

	-- Use a unique action name for each instance to prevent collisions
	local HttpService = game:GetService("HttpService")
	local actionName = "StickyScrollAction_" .. HttpService:GenerateGUID(false)

	ContextActionService:BindAction(actionName, handleMouseWheelAction, false, Enum.UserInputType.MouseWheel)

	ContainerFrame.Destroying:Connect(function()
		ContextActionService:UnbindAction(actionName)
		touchMovedConnection:Disconnect()
		touchEndedConnection:Disconnect()
	end)

	-- API
	local function addRowFrame(row: Frame, layoutOrder: number, isSticky: boolean)
		table.insert(rowFrames, row)
		row.LayoutOrder = layoutOrder
		row.Size = UDim2.new(1, 0, 0, currentRowHeight)
		row.Parent = ScrollingFrame
		if isSticky then
			row:SetAttribute("Sticky", 1)
		else
			row:SetAttribute("Sticky", 0)
		end
		row:SetAttribute("FilteredOut", 0)
		-- Visibility set by adjustVisibility
	end

	local function doneAdding()
		guiIsDoneAdding = true
		_annotate(string.format("doneAdding: %d rows total", #rowFrames))
		firstRegularRowDisplayedIndex = getFirstRegularRowIndex()
		-- Initial row height calculation after layout is ready
		task.defer(updateRowHeights)
		adjustVisibility()
	end

	-- Return ContainerFrame as 'frame' - callers parent this to their UI
	-- The ScrollingFrame and scroll indicator are children of this container
	local function refresh()
		if not guiIsDoneAdding then
			return
		end
		firstRegularRowDisplayedIndex = getFirstRegularRowIndex()
		adjustVisibility()
	end

	-- Allow external code to trigger refresh by setting an attribute on the container
	ContainerFrame:GetAttributeChangedSignal("_triggerRefresh"):Connect(function()
		refresh()
	end)

	return {
		frame = ContainerFrame,
		addElement = addRowFrame,
		doneAdding = doneAdding,
		refresh = refresh,
	}
end

_annotate("end")
return module
