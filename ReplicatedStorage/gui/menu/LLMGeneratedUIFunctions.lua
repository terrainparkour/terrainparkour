--!strict

-- LLMGeneratedUIFunctions: Utility module for creating UI elements
-- Used in both client and server scripts

-- lets genericize my UI system.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local tt = require(game.ReplicatedStorage.types.gametypes)

local module = {}

export type Properties = { [string]: any }

-- Add these global variables for text size constraints
local globalTextSize = 20
local globalMinTextSize = 8
local globalMaxTextSize = 24
local globalFixedWidthFontSize = 26

-- Add this new function to determine the appropriate font
function module.getFont(isMonospaced: boolean?): Enum.Font
	if isMonospaced then
		return Enum.Font.RobotoMono
	else
		return Enum.Font.Gotham
	end
end

function module.createUIElement(elementType: string, properties: Properties): Instance
	local element = Instance.new(elementType)
	for key, value in pairs(properties) do
		element[key] = value
	end
	return element
end

function module.createTextLabel(properties: Properties): TextLabel
	properties.BackgroundTransparency = properties.BackgroundTransparency or 0
	properties.Font = module.getFont(properties.isMonospaced)
	properties.TextSize = properties.TextSize or globalFixedWidthFontSize
	properties.TextXAlignment = properties.TextXAlignment or Enum.TextXAlignment.Left
	properties.isMonospaced = nil -- Remove this property as it's not a valid TextLabel property
	return module.createUIElement("TextLabel", properties) :: TextLabel
end

function module.createImageLabel(properties: Properties): ImageLabel
	properties.BackgroundTransparency = properties.BackgroundTransparency or 0
	properties.ScaleType = properties.ScaleType or Enum.ScaleType.Fit
	return module.createUIElement("ImageLabel", properties) :: ImageLabel
end

function module.createFrame(properties: Properties): Frame
	properties.BorderSizePixel = properties.BorderSizePixel or 0
	return module.createUIElement("Frame", properties) :: Frame
end

function module.createLayout(
	layoutType: string,
	parent: Instance,
	properties: Properties
): UIGridStyleLayout | UIListLayout
	local layout = module.createUIElement(layoutType, properties) :: UIGridStyleLayout | UIListLayout
	layout.Parent = parent
	return layout
end

function module.createScrollingFrame(properties: Properties): ScrollingFrame
	properties.ScrollBarThickness = properties.ScrollBarThickness or 8
	properties.VerticalScrollBarInset = properties.VerticalScrollBarInset or Enum.ScrollBarInset.ScrollBar
	return module.createUIElement("ScrollingFrame", properties) :: ScrollingFrame
end

function module.createButton(properties: Properties): TextButton
	properties.Font = properties.Font or module.getFont(properties.isMonospaced)
	properties.TextSize = properties.TextSize or globalTextSize
	properties.TextXAlignment = properties.TextXAlignment or Enum.TextXAlignment.Center
	properties.isMonospaced = nil -- Remove this property as it's not a valid TextButton property
	return module.createUIElement("TextButton", properties) :: TextButton
end

function module.createContainer(
	containerType: "Frame" | "ScrollingFrame",
	layoutType: LayoutType,
	properties: Properties
): Frame | ScrollingFrame
	local container = if containerType == "Frame"
		then module.createFrame(properties)
		else module.createScrollingFrame(properties)

	module.createLayout(layoutType, container, {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 0),
	})

	return container
end

-- New function to create a row with multiple elements
function module.createRow(parent: Instance, elements: { Properties }, spacing: number?): Frame
	local row = module.createFrame({
		Parent = parent,
		Size = UDim2.new(1, 0, 0, 30), -- Default height, can be overridden
		BackgroundTransparency = 1,
	})

	module.createLayout("UIListLayout", row, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 0),
	})

	for i, elementProps in ipairs(elements) do
		local elementType = elementProps.ElementType or "TextLabel"
		elementProps.ElementType = nil
		elementProps.Parent = row
		elementProps.LayoutOrder = i

		module.createUIElement(elementType, elementProps)
	end

	return row
end

function module.createTextButton(properties: Properties): TextButton
	properties.Font = properties.Font or module.getFont(properties.isMonospaced)
	properties.TextSize = properties.TextSize or globalTextSize
	properties.isMonospaced = nil -- Remove this property as it's not a valid TextButton property
	return module.createUIElement("TextButton", properties) :: TextButton
end

function module.addInvisibleButton(parent: Instance, callback: () -> ()): TextButton
	local button = module.createTextButton({
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 20,
		Parent = parent,
	})
	button.Activated:Connect(callback)
	return button
end

--[[
    Creates a row with two sets of chips (text elements), each with its own color.
    Typically used for displaying player-specific data alongside general information.
]]
function module.createChippedRow(allChips: { tt.runChip }, properties: Properties): Frame
	local frame = module.createFrame(properties)

	module.createLayout("UIListLayout", frame, {
		FillDirection = Enum.FillDirection.Horizontal,
	})

	local function createChips(chips: { tt.runChip })
		for i, chip in ipairs(chips) do
			local chipLabel = module.createTextLabel({
				Text = chip.text,
				Size = UDim2.new(1 / #allChips, 0, 1, 0),
				BackgroundColor3 = chip.bgcolor,
				Parent = frame,
				TextScaled = true,
			})

			-- Add UITextSizeConstraint to limit the maximum text size
			local textSizeConstraint = Instance.new("UITextSizeConstraint")
			textSizeConstraint.MaxTextSize = globalMaxTextSize -- Adjust this value as needed
			textSizeConstraint.Parent = chipLabel
		end
	end

	createChips(allChips)

	return frame
end

-- Add this function to the LLMGeneratedUIFunctions module

function module.addTextSizeConstraint(instance: GuiObject, maxTextSize: number?)
	local textSizeConstraint = Instance.new("UITextSizeConstraint")
	textSizeConstraint.MaxTextSize = maxTextSize or globalMaxTextSize
	textSizeConstraint.MinTextSize = globalMinTextSize
	textSizeConstraint.Parent = instance
end

-- Add this new function
function module.createDetailItem(detail: DetailItem, parent: Instance, totalSizeProportion: number): GuiObject
	local sizeFraction = detail.sizeProportion / totalSizeProportion
	local properties = {
		Name = detail.name,
		Size = UDim2.new(sizeFraction, 0, 1, 0),
		BackgroundColor3 = detail.color,
		LayoutOrder = detail.order,
		Parent = parent,
		isMonospaced = detail.isMonospaced,
		TextXAlignment = detail.TextXAlignment or Enum.TextXAlignment.Left,
	}

	if detail.isButton then
		local button = module.createButton(properties)
		button.Text = detail.text or ""
		module.addTextSizeConstraint(button, globalMaxTextSize)
		if detail.onClick then
			button.MouseButton1Click:Connect(detail.onClick)
		end
		return button
	elseif detail.isPortrait then
		properties.Image = "" -- You'll need to set this separately using your thumbnail system
		return module.createImageLabel(properties)
	else
		local label = module.createTextLabel(properties)
		label.Text = detail.text or ""
		module.addTextSizeConstraint(label, globalMaxTextSize)
		return label
	end
end

-- Add this utility function
function module.calculateTotalSizeProportion(details: { DetailItem }): number
	local total = 0
	for _, detail in ipairs(details) do
		total += detail.sizeProportion
	end
	return total
end

function module.createTitleRow(text: string, properties: Properties): Frame
	-- Separate frame properties from label properties
	local frameProperties = {
		Name = properties.Name or "TitleFrame",
		Size = properties.Size or UDim2.new(1, 0, 0, 40), -- Default height if not provided
		BackgroundColor3 = properties.BackgroundColor3 or Color3.new(1, 1, 1),
		BorderSizePixel = properties.BorderSizePixel or 0,
		Parent = properties.Parent,
	}

	local labelProperties = {
		Name = "TitleLabel",
		Size = UDim2.new(1, 0, 1, 0),
		Text = text,
		TextColor3 = properties.TextColor3 or Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		TextScaled = true,
		Font = properties.Font or module.getFont(properties.isMonospaced),
		isMonospaced = properties.isMonospaced,
	}

	local frame = module.createFrame(frameProperties)
	local titleLabel = module.createTextLabel(labelProperties)
	titleLabel.Parent = frame

	module.addTextSizeConstraint(titleLabel, properties.MaxTextSize or 24)

	return frame
end

-- Add this new function to the module
function module.createHeaderChipsRow(chips: { tt.runChip }, properties: Properties): Frame
	local frame = module.createFrame(properties)

	module.createLayout("UIListLayout", frame, {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 0),
	})

	for i, chip in ipairs(chips) do
		local chipLabel = module.createTextLabel({
			Text = chip.text,
			Size = UDim2.new(1 / #chips, -5, 1, 0),
			BackgroundColor3 = chip.bgcolor,
			Parent = frame,
			TextScaled = true,
			TextColor3 = Color3.new(0, 0, 0), -- Set text color to black
		})

		module.addTextSizeConstraint(chipLabel, globalMaxTextSize)
	end

	return frame
end

-- Add this new function to the module
function module.createScaledTextLabel(properties: Properties): TextLabel
	local outerLabel = module.createTextLabel({
		Name = properties.Name,
		Size = properties.Size,
		BackgroundColor3 = properties.BackgroundColor3,
		BorderSizePixel = properties.BorderSizePixel or 1,
		BorderMode = properties.BorderMode or Enum.BorderMode.Outline,
		BackgroundTransparency = properties.BackgroundTransparency or 0,
		Parent = properties.Parent,
		ZIndex = 1,
		TextTransparency = 1,
	})

	local innerLabel = module.createTextLabel({
		Name = "Inner",
		Text = properties.Text,
		TextColor3 = properties.TextColor3 or Color3.new(0, 0, 0),
		Font = properties.Font or Enum.Font.Gotham,
		TextXAlignment = properties.TextXAlignment or Enum.TextXAlignment.Center,
		TextYAlignment = properties.TextYAlignment or Enum.TextYAlignment.Center,
		Size = UDim2.new(1, -2 * (properties.Padding or 0), 1, -2 * (properties.Padding or 0)),
		Position = UDim2.new(0, properties.Padding or 0, 0, properties.Padding or 0),
		BackgroundTransparency = 1,
		Parent = outerLabel,
		ZIndex = 2,
		TextScaled = true,
	})

	module.addTextSizeConstraint(innerLabel, properties.MaxTextSize)

	return innerLabel
end

_annotate("end")
return module
