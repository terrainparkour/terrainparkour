--!strict

-- stickyScrollingFrame.lua
-- a scrolling frame that snaps to rows and also allows sticky elements.
-- Uses "visibility hack" to support sticky interleaved rows.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local _UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

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
	local ScrollingFrame = Instance.new("ScrollingFrame")
	local UIListLayout = Instance.new("UIListLayout")
	local rowFrames: { Frame } = {} -- Store references to all elements

	-- "Fake" scrolling setup
	ScrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.None
	ScrollingFrame.ElasticBehavior = Enum.ElasticBehavior.Always
	ScrollingFrame.ScrollingEnabled = false -- Disable native scrolling
	ScrollingFrame.AutomaticSize = Enum.AutomaticSize.None
	ScrollingFrame.ScrollBarThickness = 0 -- Hide scrollbar
	ScrollingFrame.VerticalScrollBarInset = Enum.ScrollBarInset.None
	ScrollingFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	ScrollingFrame.Size = UDim2.new(1, 0, 1, 0)

	-- Configure UIListLayout
	UIListLayout.Parent = ScrollingFrame
	UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	
	local firstRegularRowDisplayedIndex = 1

	-- Helper: get count of sticky rows and list of regular row indices
	local function getStickyInfo()
		local stickyCount = 0
		local regularRowIndices: { number } = {}
		for index, row in ipairs(rowFrames) do
			local stickyAttr = row:GetAttribute("Sticky")
			if stickyAttr == 1 then
				stickyCount += 1
			else
				table.insert(regularRowIndices, index)
			end
		end
		return stickyCount, regularRowIndices
	end

	-- Helper: find first regular row index
	local function getFirstRegularRowIndex(): number
		for index, row in ipairs(rowFrames) do
			local stickyAttr = row:GetAttribute("Sticky")
			if stickyAttr ~= nil and stickyAttr ~= 1 then
				return index
			end
		end
		return 1
	end

	-- Core logic: hide/show row elements
	local function adjustVisibility()
		if not guiIsDoneAdding then return end
		
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
				if row:GetAttribute("Sticky") == 1 then continue end
				
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
	end

	-- Handle Input
	local localPlayer = Players.LocalPlayer
	local mouse = localPlayer:GetMouse()
	
	-- Check if mouse is over frame
	local function isMouseOver()
		if not guiIsDoneAdding then return false end
		
		local mouseX, mouseY = mouse.X, mouse.Y
		local framePos = ScrollingFrame.AbsolutePosition
		local frameSize = ScrollingFrame.AbsoluteSize
		
		if frameSize.X == 0 or frameSize.Y == 0 then return false end
		
		if mouseX < framePos.X or mouseX > framePos.X + frameSize.X then return false end
		if mouseY < framePos.Y or mouseY > framePos.Y + frameSize.Y then return false end
		
		return true
	end
	
	-- Combined Scroll and Sink Logic
	local function handleScrollAction(actionName, inputState, inputObject)
		if inputState ~= Enum.UserInputState.Change then return Enum.ContextActionResult.Pass end
		
		if not isMouseOver() then
			return Enum.ContextActionResult.Pass
		end

		-- Scroll logic
		local stickyCount, regularRowIndices = getStickyInfo()
		local totalRegularRows = #regularRowIndices
		
		if totalRegularRows == 0 then return Enum.ContextActionResult.Sink end
		
		-- How many regular rows fit?
		local availableSlots = math.max(0, actualDataRowsToShowCount - stickyCount)
		
		-- Max index we can start at
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
		
		-- Scroll
		if inputObject.Position.Z < 0 then -- Scroll Down
			currentVirtualIndex = math.min(currentVirtualIndex + 1, maxVirtualIndex)
		else -- Scroll Up
			currentVirtualIndex = math.max(currentVirtualIndex - 1, 1)
		end
		
		-- Map back to rowFrames index
		firstRegularRowDisplayedIndex = regularRowIndices[currentVirtualIndex]
		
		_annotate(string.format("Scroll handled by %s. New Index: %d", actionName, firstRegularRowDisplayedIndex))
		adjustVisibility()

		return Enum.ContextActionResult.Sink
	end
	
	-- Use a unique action name for each instance to prevent collisions
	-- We use HttpService:GenerateGUID to ensure uniqueness even if tostring(ScrollingFrame) is not unique enough (though it should be)
	local HttpService = game:GetService("HttpService")
	local actionName = "StickyScrollAction_" .. HttpService:GenerateGUID(false)
	
	ContextActionService:BindAction(actionName, handleScrollAction, false, Enum.UserInputType.MouseWheel)
	
	ScrollingFrame.Destroying:Connect(function() 
		ContextActionService:UnbindAction(actionName)
	end)

	-- API
	local function addRowFrame(row: Frame, layoutOrder: number, isSticky: boolean)
		table.insert(rowFrames, row)
		row.LayoutOrder = layoutOrder
		row.Size = UDim2.new(1, 0, 0, rowHeight)
		row.Parent = ScrollingFrame
		if isSticky then
			row:SetAttribute("Sticky", 1)
		else
			row:SetAttribute("Sticky", 0)
		end
		-- Visibility set by adjustVisibility
	end

	local function doneAdding()
		guiIsDoneAdding = true
		_annotate(string.format("doneAdding: %d rows total", #rowFrames))
		firstRegularRowDisplayedIndex = getFirstRegularRowIndex()
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
