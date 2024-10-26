--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- windows.lua, used in clients
-- generic module to add resize functionality to frames

-- This windowing system in Roblox LUA/luau has a couple or problems:
-- 1. There is no option to make windows block each other / not overlap with each other, or at least, to "snap" stick to each others's edges.  Instead, they just overlap each other.
-- 2.  it's a bit weird that the resize dragger is only on the left corner of windows; if they are already left-aligned, it means there isn't really a way to resize them.  It'd be nice to have multiple resizers, or to let the developer choose where to put the resizer.

-- Generic UI popup creation system.
-- nearly all popups ahve this format:
-- the overall popup is a
-- 1. title at top, full width. Cell widths are specified by a "width" which is an UDim, where scale part will be treated as a proportion, and offset part as an absolute reservation of that size.
-- 2. data row at top,with many individual elements which are either textLabels, textButtons, or images. Widths are specified by widthWeight, or sometimes absolute pixel width.
-- 3. header row which has headers for a scrolling area. Same here, using widthWeight and tt.headerDefinition
-- 4. data area which can scroll up and down
-- 5. last button row.
-- Let's standardize on thse names in however we refer to each section.
-- Let's also make it so that there are clearly specified formats for how to draw each thing, and its order, too.  i.e. an area for how to create the title row, then a list of descriptors for the entries in the data row.
-- Then a list of information on the columns which applies to both the headers list, how to draw and create them, and their order. Then the data rows ALSO use this same column specification.
-- Finally the last button row.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local colors = require(game.ReplicatedStorage.util.colors)
local fonts = require(game.StarterPlayer.StarterPlayerScripts.guis.fonts)
local wt = require(game.StarterPlayer.StarterPlayerScripts.guis.windowsTypes)

local windowFunctions = require(game.StarterPlayer.StarterPlayerScripts.guis.windowFunctions)

local toolTip = require(game.ReplicatedStorage.gui.toolTip)
local thumbnails = require(game.ReplicatedStorage.thumbnails)

local scrollingFrameBorderSizePixel = 1
local textLabelBorderSizePixel = 1
local textButtonBorderSizePixel = 1
local frameBorderSizePixel = 1
local portraitBorderSizePixel = 1
local globalBorderMode = Enum.BorderMode.Outline

local module = {}

-------------------- DEFAULTS --------------------
local globalMaxTextSize = 16
local globalMaxTextSizeBold = 24
local defaultTextBackgroundColor = colors.defaultGrey
local defaultPortraitBackgroundColor = colors.defaultGrey
local defaultTextColor = colors.black

local defaultTextButtonColor = colors.black
local defaultTextTileXAlignment = Enum.TextXAlignment.Left
local defaultTextButtonXAlignment = Enum.TextXAlignment.Center
local defaultTextButtonBackgroundColor = colors.defaultGrey

----------------------

local closeButtonTextButtonTileSpec: wt.buttonTileSpec = {
	type = "button",
	text = "Close",
	onClick = function(_: InputObject, theButton: TextButton)
		local screenGui = theButton:FindFirstAncestorOfClass("ScreenGui")
		if screenGui then
			toolTip.KillFinalTooltip()
			screenGui:Destroy()
		else
			warn("Could not find ScreenGui to close")
		end
	end,
	backgroundColor = colors.redSlowDown,
	textColor = colors.white,
	isMonospaced = false,
	isBold = true,
	textXAlignment = Enum.TextXAlignment.Center,
}

local closeButtonLeavingroom: wt.tileSpec = {
	name = "Close",
	order = 1,
	width = UDim.new(1, -15),
	spec = closeButtonTextButtonTileSpec,
}

local standardCloseButton: wt.tileSpec = {
	name = "Close",
	order = 1,
	width = UDim.new(1, 0),
	spec = closeButtonTextButtonTileSpec,
}

module.StandardCloseButton = standardCloseButton
module.CloseButtonLeavingRoom = closeButtonLeavingroom

module.CreateButton = function(buttonSpec: wt.buttonTileSpec): TextButton
	local res = Instance.new("TextButton")
	res.BorderSizePixel = textButtonBorderSizePixel
	res.BorderMode = globalBorderMode
	res.RichText = true
	res.TextScaled = true

	local constraint = Instance.new("UITextSizeConstraint")

	constraint.Name = "UITextSizeConstraint_Text"
	constraint.MaxTextSize = globalMaxTextSize
	constraint.Parent = res

	res.Text = buttonSpec.text
	res.Activated:Connect(function(el: InputObject)
		buttonSpec.onClick(el, res)
	end)
	return res
end

module.CreatePortrait = function(portraitSpec: wt.portraitTileSpec): Frame
	local res = thumbnails.createAvatarPortraitPopup(
		portraitSpec.userId,
		portraitSpec.doPopup,
		portraitSpec.backgroundColor,
		portraitBorderSizePixel
	)
	return res
end

module.CreateText = function(textSpec: wt.textTileSpec): TextLabel
	local res = Instance.new("TextLabel")
	res.BorderSizePixel = textLabelBorderSizePixel
	res.BorderMode = globalBorderMode
	res.BackgroundColor3 = textSpec.backgroundColor or defaultTextBackgroundColor
	res.TextColor3 = textSpec.textColor or defaultTextColor
	res.TextScaled = true
	res.RichText = true
	res.TextXAlignment = textSpec.textXAlignment or defaultTextTileXAlignment
	res.FontFace = fonts.GetFont(textSpec.isMonospaced, textSpec.isBold)
	res.Text = textSpec.text

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.Name = "UITextSizeConstraint_Text"

	if textSpec.isBold then
		constraint.MaxTextSize = globalMaxTextSizeBold
	else
		constraint.MaxTextSize = globalMaxTextSize
	end
	constraint.Parent = res

	return res
end

local function addLayout(parent: Frame, direction: Enum.FillDirection): UIListLayout
	local res = Instance.new("UIListLayout")
	res.Name = string.format("%s_layout", parent.Name)
	res.HorizontalFlex = Enum.UIFlexAlignment.Fill
	res.SortOrder = Enum.SortOrder.Name
	res.Parent = parent
	res.FillDirection = direction
	return res
end

local function applyProportionalHeights(objects: { Frame })
	local totalScale = 0
	local totalFixed = 0

	-- Calculate total scale and fixed offset
	for _, obj in ipairs(objects) do
		local size = obj.Size
		if size.Y.Scale > 0 then
			totalScale = totalScale + size.Y.Scale
		else
			totalFixed = totalFixed + size.Y.Offset
		end
	end

	for _, obj in ipairs(objects) do
		local size = obj.Size
		local newScaleY = 0
		local myNegative = 0
		if totalScale > 0 then
			newScaleY = size.Y.Scale / totalScale
			myNegative = newScaleY * totalFixed * -1
		end
		obj.Size = UDim2.new(size.X.Scale, size.X.Offset, newScaleY, size.Y.Offset + myNegative)
	end
end

local function applyProportionalWidths(objects: { Frame | TextLabel | TextButton | ImageButton | ImageLabel })
	local totalScale = 0
	local totalFixed = 0

	-- Calculate total scale and fixed offset
	for _, obj in ipairs(objects) do
		local size = obj.Size
		if size.X.Scale > 0 then
			totalScale = totalScale + size.X.Scale
		else
			totalFixed = totalFixed + size.X.Offset
		end
	end

	for _, obj in ipairs(objects) do
		local size = obj.Size
		local newScaleX = 0
		local myNegative = 0
		if totalScale > 0 then
			newScaleX = size.X.Scale / totalScale
			myNegative = newScaleX * totalFixed * -1
		end
		obj.Size = UDim2.new(newScaleX, size.X.Offset + myNegative, size.Y.Scale, size.Y.Offset)
	end
end

module.CreateScrollingFrame = function(scrollingFrameSpec: wt.scrollingFrameTileSpec): Frame
	local contentFrame: Frame = Instance.new("Frame")
	contentFrame.Name = string.format("%s_OuterFor_ScrollingFrame", scrollingFrameSpec.name)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Size = UDim2.new(1, 0, 1, 0)
	contentFrame.BorderSizePixel = frameBorderSizePixel
	contentFrame.BorderMode = globalBorderMode

	local headerRow: Frame = module.CreateRow(scrollingFrameSpec.headerRow)
	headerRow.Parent = contentFrame
	headerRow.Position = UDim2.new(0, 0, 0, 0)
	-- headerRow.Size = UDim2.new(1, 0, 0, scrollingFrameSpec.rowHeight)

	local contentFrameLayout: UIListLayout = addLayout(contentFrame, Enum.FillDirection.Vertical)
	contentFrameLayout.SortOrder = Enum.SortOrder.Name
	contentFrameLayout.FillDirection = Enum.FillDirection.Vertical
	contentFrameLayout.Parent = contentFrame

	local scrollingFrame: ScrollingFrame = Instance.new("ScrollingFrame")
	scrollingFrame.Name = string.format("%s_ScrollingFrame", scrollingFrameSpec.name)
	scrollingFrame.BorderMode = globalBorderMode
	scrollingFrame.BackgroundTransparency = 1
	scrollingFrame.BorderSizePixel = scrollingFrameBorderSizePixel
	scrollingFrame.ScrollBarThickness = 8
	scrollingFrame.VerticalScrollBarInset = Enum.ScrollBarInset.None
	scrollingFrame.Parent = contentFrame
	scrollingFrame.Size = UDim2.new(1, 0, 1, -1 * scrollingFrameSpec.rowHeight)

	local layout: UIListLayout = addLayout(contentFrame, Enum.FillDirection.Vertical)
	layout.SortOrder = Enum.SortOrder.Name
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Parent = scrollingFrame
	layout.Name = "ScrollingFrameLayout"

	for _, rowSpec in ipairs(scrollingFrameSpec.dataRows) do
		local row: Frame = module.CreateRow(rowSpec)
		row.Parent = scrollingFrame
	end

	-- Calculate content size
	local contentHeight: number = #scrollingFrameSpec.dataRows * scrollingFrameSpec.rowHeight
	contentFrame.Size = UDim2.new(1, 0, 0, contentHeight)
	scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, contentHeight)

	return contentFrame
end

-- Modify the CreateRow function to handle scrolling frames
module.CreateRow = function(rowSpec: wt.rowSpec): Frame
	local frame = Instance.new("Frame")
	frame.Name = string.format("%06d_%s", rowSpec.order, rowSpec.name)
	frame.Size = UDim2.new(1, 0, 0, rowSpec.height.Offset)
	frame.BorderSizePixel = frameBorderSizePixel
	frame.BorderMode = globalBorderMode
	local layout = addLayout(frame, Enum.FillDirection.Horizontal)
	if rowSpec.horizontalAlignment then
		layout.HorizontalAlignment = rowSpec.horizontalAlignment
	end
	local items: { ImageButton | ImageLabel | TextLabel | TextButton | Frame } = {}

	-- we need to intelligently apply widths here based on both the tile widthWeight proportion, and also remembering to also handle offset-based tile types.
	for _, tileSpec: wt.tileSpec in pairs(rowSpec.tileSpecs) do
		if tileSpec.spec.type == "button" then
			local button = module.CreateButton(tileSpec.spec)
			button.BackgroundColor3 = tileSpec.spec.backgroundColor or defaultTextButtonBackgroundColor
			button.FontFace = fonts.GetFont(tileSpec.spec.isMonospaced, tileSpec.spec.isBold)
			button.TextColor3 = tileSpec.spec.textColor or defaultTextButtonColor
			button.TextXAlignment = tileSpec.spec.textXAlignment or defaultTextButtonXAlignment
			if tileSpec.tooltipText then
				toolTip.setupToolTip(button, tileSpec.tooltipText, toolTip.enum.toolTipSize.NormalText)
			end

			button.Name = string.format("%04d_%s", tileSpec.order, tileSpec.name)
			local useWidth: UDim = tileSpec.width or UDim.new(1, 0)
			button.Size = UDim2.new(useWidth.Scale, useWidth.Offset, 1, 0)
			table.insert(items, button)
		elseif tileSpec.spec.type == "text" then
			local text = module.CreateText(tileSpec.spec)
			text.Name = string.format("%04d_%s", tileSpec.order, tileSpec.name)
			local useWidth: UDim = tileSpec.width or UDim.new(1, 0)
			text.Size = UDim2.new(useWidth.Scale, useWidth.Offset, 1, 0)

			if tileSpec.tooltipText then
				toolTip.setupToolTip(text, tileSpec.tooltipText, toolTip.enum.toolTipSize.NormalText)
			end
			table.insert(items, text)
		elseif tileSpec.spec.type == "portrait" then
			local imageFrame = module.CreatePortrait(tileSpec.spec)
			imageFrame.Name = string.format("%04d_%s_ImageFrame", tileSpec.order, tileSpec.name)
			local useWidth = tileSpec.width or UDim.new(1, 0)
			imageFrame.Size = UDim2.new(useWidth.Scale, useWidth.Offset, 1, 0)
			imageFrame.BackgroundColor3 = tileSpec.spec.backgroundColor or defaultPortraitBackgroundColor

			local theImageLabel = imageFrame:FindFirstChildOfClass("ImageLabel") :: ImageLabel
			theImageLabel.Name = string.format("%04d_%s", tileSpec.order, tileSpec.name)

			if tileSpec.tooltipText then
				toolTip.setupToolTip(theImageLabel, tileSpec.tooltipText, toolTip.enum.toolTipSize.NormalText)
			end
			table.insert(items, imageFrame)
		elseif tileSpec.spec.type == "scrollingFrame" then
			local scrollingFrameFrame = module.CreateScrollingFrame(tileSpec.spec)
			scrollingFrameFrame.Name = string.format("%04d_%s", tileSpec.order, tileSpec.name)
			local useWidth = tileSpec.width or UDim.new(1, 0)
			scrollingFrameFrame.Size = UDim2.new(useWidth.Scale, useWidth.Offset, 1, 0)
			table.insert(items, scrollingFrameFrame)
		elseif tileSpec.spec.type == "rowTile" then
			local fakeRowSpec: wt.rowSpec = {
				type = "rowTile",
				name = tileSpec.name,
				order = tileSpec.order,
				tileSpecs = tileSpec.spec.tileSpecs,
				height = UDim.new(1, 0),
			}

			local theRow: Frame = module.CreateRow(fakeRowSpec) :: Frame
			theRow.Name = string.format("%04d_%s", tileSpec.order, tileSpec.name)
			theRow.Size = UDim2.new(1, 0, 1, 0)
			table.insert(items, theRow)
		else
			error("Unknown tile type")
		end
	end
	_annotate(string.format("applyng prop widths on %s - %s", frame.Name, rowSpec.name))

	--- dataRows inherit the exact current width of the header row (which, if the header row has a fixed height item like a portrait, will already be a combination of scale and offset)
	-- therefore we can't re-proportionalize them.
	-- if rowSpec.name ~= "DataRow" then
	applyProportionalWidths(items)
	-- end

	for _, el in ipairs(items) do
		el.Parent = frame
	end
	return frame
end

-- module.CreateScrollingFrame = function(scrollingFrameSpec: scrollingFrameTileSpec): ScrollingFrame
-- 	local res = Instance.new("ScrollingFrame")
-- 	res.Name = scrollingFrameSpec.name
-- 	local headerRow = module.CreateRow(scrollingFrameSpec.headerRow)
-- 	headerRow.Parent = res

-- 	for _, rowSpec in pairs(scrollingFrameSpec.dataRows) do
-- 		local row = module.CreateRow(rowSpec)
-- 		row.Parent = res
-- 	end
-- 	return res
-- end

module.CreatePopup = function(
	guiSpec: wt.guiSpec,
	name: string,
	draggable: boolean,
	resizable: boolean,
	minimizable: boolean,
	pinnable: boolean,
	dismissableWithX: boolean,
	dismissableByClick: boolean,
	desiredSize: UDim2,
	intendedRowsOfScrollingFrameToShow: number?
): ScreenGui
	if intendedRowsOfScrollingFrameToShow == nil then
		intendedRowsOfScrollingFrameToShow = 11
	end
	local theSgui: ScreenGui = Instance.new("ScreenGui")
	theSgui.IgnoreGuiInset = true
	theSgui.Name = string.format("%s", name)
	theSgui.Enabled = true

	local res = windowFunctions.SetupFrame(name, draggable, resizable, minimizable, pinnable, desiredSize)
	local contentFrame = res.contentFrame
	local outerFrame = res.outerFrame
	outerFrame.Transparency = 0
	outerFrame.BorderSizePixel = frameBorderSizePixel
	outerFrame.BorderMode = globalBorderMode
	outerFrame.Parent = theSgui

	addLayout(contentFrame, Enum.FillDirection.Vertical)
	-- Center the outerFrame vertically without modifying AnchorPoint

	local rowFrames: { Frame } = {}
	for _, rowSpec in ipairs(guiSpec.rowSpecs) do
		local rowFrame = module.CreateRow(rowSpec)

		rowFrame.Size = UDim2.new(1, 0, rowSpec.height.Scale, rowSpec.height.Offset)
		table.insert(rowFrames, rowFrame)
	end

	-- Apply proportional sizes after all rows are created
	applyProportionalHeights(rowFrames)

	for _, rowFrame in ipairs(rowFrames) do
		rowFrame.Parent = contentFrame
	end

	--okay so i'm thinking, this might work, but OTOH maybe it'd be better to specify it in the actual rowSpec for the scorlling frame.
	-- because he knows his own data counts? but
	local function calculateTotalHeight()
		local minVisibleRows = 1
		local maxVisibleRows = intendedRowsOfScrollingFrameToShow
		local totalHeight = 0
		local scrollingFrameHeight = 0

		for _, rowSpec in ipairs(guiSpec.rowSpecs) do
			for _, tileSpec in ipairs(rowSpec.tileSpecs) do
				if tileSpec.spec.type == "scrollingFrame" then
					local scrollingFrameSpec = tileSpec.spec :: scrollingFrameTileSpec
					local dataRowCount = #scrollingFrameSpec.dataRows + 1 -- plusone for header.
					local visibleRows = math.min(math.max(minVisibleRows, dataRowCount), maxVisibleRows)
					scrollingFrameHeight = visibleRows * scrollingFrameSpec.rowHeight
					totalHeight += scrollingFrameHeight + 4
				end
			end
			totalHeight += rowSpec.height.Offset
		end

		return totalHeight, scrollingFrameHeight
	end

	local totalHeight, scrollingFrameHeight = calculateTotalHeight()
	local contentHeight = contentFrame.AbsoluteSize.Y

	-- Ensure we're showing at least the scrolling frame height or all content if it's less
	local finalHeight = math.max(totalHeight, contentHeight, scrollingFrameHeight)
	outerFrame.Size = UDim2.new(outerFrame.Size.X.Scale, outerFrame.Size.X.Offset, 0, finalHeight)

	local attribute = Instance.new("BoolValue")
	attribute.Parent = outerFrame.Parent
	attribute.Name = "DismissableWithX"
	attribute.Value = dismissableWithX

	-- position it in the center of the screen.
	local screenSize = theSgui.AbsoluteSize
	local outerFrameSize = outerFrame.AbsoluteSize

	-- Calculate the centered position
	local centeredPositionX = (screenSize.X - outerFrameSize.X) / 2
	local centeredPositionY = (screenSize.Y - outerFrameSize.Y) / 2

	-- Set the outerFrame's position to be centered
	outerFrame.Position = UDim2.new(0, centeredPositionX, 0, centeredPositionY)

	if dismissableByClick then
		local clickAttribute = Instance.new("BoolValue")
		clickAttribute.Parent = outerFrame.Parent
		clickAttribute.Name = "DismissableByClick"
		clickAttribute.Value = true

		contentFrame.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				theSgui:Destroy()
			end
		end)
	end

	return theSgui
end

_annotate("end")

return module
