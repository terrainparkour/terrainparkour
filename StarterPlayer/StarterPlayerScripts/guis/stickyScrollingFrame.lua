--!strict

-- stickyScrollingFrame.lua
-- a scrolling frame that snaps to rows and also allows sticky elements.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

-- okay it's actually a sticky scrolling frame which when you scroll, just fakes the nav
module.CreateStickyScrollingFrame = function(rowHeight: number, dataRowsToShowCount: number?)
	if not dataRowsToShowCount then
		dataRowsToShowCount = 10
		_annotate(string.format("dataRowsToShowCount fallback to: %d", dataRowsToShowCount))
	else
		_annotate(string.format("dataRowsToShowCount received: %d", dataRowsToShowCount))
	end

	local guiIsDoneAdding = false
	local ScrollingFrame = Instance.new("ScrollingFrame")
	local UIListLayout = Instance.new("UIListLayout")
	local rowFrames: { Frame } = {} -- Store references to all elements

	-- it's a scrolling frame in ordre to listen to scrolls, but the actual implementation of scrolling is a hack
	-- which is done with visibility of  rows so that it only appears to scroll
	ScrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.None
	ScrollingFrame.ElasticBehavior = Enum.ElasticBehavior.Always
	ScrollingFrame.ScrollingEnabled = true
	ScrollingFrame.AutomaticSize = Enum.AutomaticSize.None
	ScrollingFrame.ScrollBarThickness = 0
	ScrollingFrame.ScrollingDirection = Enum.ScrollingDirection.Y

	-- Configure UIListLayout
	UIListLayout.Parent = ScrollingFrame
	UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	-- UIListLayout.VerticalFlex = Enum.UIFlexAlignment.Fill

	local firstRowDisplayedIndex = 1
	local lastYPosition = 0

	-- job: hide/show row elements so that there are the proper number (rowCount)
	local function adjustVisibility()
		if not guiIsDoneAdding then
			return
		end
		--if we can show 10 rows and have required rows 1,2, 5, and 70, and we have 100 rows in all, then at first
		-- we show 1,2,   3,4,    5,    6,7,8,9,70.
		-- i.e. we take all required items and then fill in the blanks
		-- if the user scrolls down, then we skip 1 and add 10 before 70 etc.
		local shownCount = 0

		-- just hide all to start
		for _, row in ipairs(rowFrames) do
			row.Visible = false
		end

		-- turn on stickies. This can overload.
		for _, row in ipairs(rowFrames) do
			if row:GetAttribute("Sticky") == 1 then
				row.Visible = true
				shownCount += 1
				if shownCount >= dataRowsToShowCount then
					break
				end
			end
		end

		if shownCount < dataRowsToShowCount then
			for index, rowFrame in ipairs(rowFrames) do
				if rowFrame.Visible then
					continue
				end
				if shownCount >= dataRowsToShowCount then
					break
				end
				if index >= firstRowDisplayedIndex then
					rowFrame.Visible = true
					shownCount += 1
					continue
				end
			end
		end
	end

	-- we do momentarily accept scrolling but we always undo it and instead just hide the top non-sticky row and unhide the bottom one, if available.
	local function HandleChanges()
		if not guiIsDoneAdding then
			return
		end
		-- it appears my system scrolls 37 pixesl at a time anyway.
		local currentPosY = ScrollingFrame.CanvasPosition.Y
		_annotate(string.format("current posY: %0.2f", currentPosY))
		if currentPosY == lastYPosition then
			_annotate("no movement.")
			return
		end
		local scrollingDown = currentPosY > lastYPosition
		_annotate(string.format("down = %s", tostring(scrollingDown)))
		--always reset to top
		local maxFirstRowDisplayedIndex = #rowFrames - dataRowsToShowCount - 1
		_annotate(string.format("maxScrollDownAmount = %d", maxFirstRowDisplayedIndex))
		if scrollingDown then
			-- but we can't skip down below:
			firstRowDisplayedIndex += 1
			firstRowDisplayedIndex = math.min(firstRowDisplayedIndex, maxFirstRowDisplayedIndex)
		else
			firstRowDisplayedIndex -= 1
			firstRowDisplayedIndex = math.max(firstRowDisplayedIndex, 1)
		end
		_annotate(string.format("firstRowDisplayedIndex = %d", firstRowDisplayedIndex))

		ScrollingFrame.CanvasPosition = Vector2.new(0, 1)
		lastYPosition = 1
		adjustVisibility()
	end

	-- Now we can use updateStickyPositions in the scroll handler
	ScrollingFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(HandleChanges)
	ScrollingFrame:GetPropertyChangedSignal("CanvasSize"):Connect(HandleChanges)

	-- Function to add elements
	local function addRowFrame(row: Frame, layoutOrder: number, isSticky: boolean)
		table.insert(rowFrames, row)
		row.LayoutOrder = layoutOrder
		row.Size = UDim2.new(1, 0, 0, rowHeight) -- Ensure consistent row height
		row.Parent = ScrollingFrame

		if isSticky then
			row:SetAttribute("Sticky", 1)
		else
			row:SetAttribute("Sticky", 0)
		end
		row.Visible = true
		adjustVisibility()
	end

	local function doneAdding()
		guiIsDoneAdding = true
		adjustVisibility()
	end

	return {
		frame = ScrollingFrame,
		addElement = addRowFrame,
		doneAdding = doneAdding,
	}
end

_annotate("end")
return module
