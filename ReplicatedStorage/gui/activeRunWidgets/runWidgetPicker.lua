--!strict
-- runWidgetPicker.lua (ReplicatedStorage/gui/activeRunWidgets/runWidgetPicker.lua)
-- Run Widget Picker: Configuration UI for selecting active run widgets.
-- Card-based layout with Off toggle per category, TP standard colors.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local Players = game:GetService("Players")

local colors = require(game.ReplicatedStorage.util.colors)
local fonts = require(game.StarterPlayer.StarterPlayerScripts.guis.fonts)
local highlightUtils = require(game.ReplicatedStorage.gui.activeRunWidgets.highlightUtils)
local standardButton = require(game.ReplicatedStorage.gui.standardButton)
local toolTip = require(game.ReplicatedStorage.gui.toolTip)
local widgetTypes = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetTypes)
local widgetComposer = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetComposer)
local windowFunctions = require(game.StarterPlayer.StarterPlayerScripts.guis.windowFunctions)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

-- Module type definition
export type RunWidgetPicker = {
	Init: () -> (),
	CreateGui: () -> (),
	DestroyGui: () -> (),
	Toggle: () -> (),
	IsOpen: () -> boolean,
}

-- Module internals

-- Position persistence (dedicated setting, not shared blob)
local SETTING_NAME = "RUN_WIDGET_PICKER_GUI_LAYOUT"
local POSITION_KEY = "position"

local currentConfig: { [string]: string } = {}
local allStyleButtons: { [string]: { [string]: TextButton } } = {}
local allOffToggles: { [string]: TextButton } = {}
local allCards: { [string]: Frame } = {} -- Store card frames for reverse highlighting

-- UI Style toggle buttons (Classic/Modern)
local classicButton: TextButton? = nil
local modernButton: TextButton? = nil

-- Preset buttons
local presetButtons: { [string]: TextButton } = {}

-- Sections that show/hide based on UI Style
local modernContentSection: Frame? = nil

-- For dynamic panel resizing
local outerFrameRef: Frame? = nil
local classicPanelHeight: number = 0
local modernPanelHeight: number = 0
local panelWidthRef: number = 0

-- Layout constants
local CARD_WIDTH = 200 -- Width of each category card
local CARD_HEADER_HEIGHT = 28 -- Title row height in cards
local CARD_SPACING = 8
local BUTTON_HEIGHT = 24
local STYLE_BUTTON_HEIGHT = 22
local STYLE_BUTTON_CELL_GAP = 4
local BORDER_SIZE = 1
local MAX_TEXT_SIZE = 13
local MAX_TEXT_SIZE_BOLD = 24
local OFF_TOGGLE_WIDTH = 40
local CARD_CORNER_RADIUS = 6
local CARD_INNER_PADDING = 6
local GRID_COLUMNS = 4 -- Number of cards per row

-- Body area layout: buttons in a 2-column grid
-- Card width: 200, body padding: 6px each side = 188px usable
-- Each button cell: 88px + 4px gap = 92px, so 2 buttons fit per row
local BUTTONS_PER_ROW = 2
local BODY_TOP_PADDING = 4
local BODY_BOTTOM_PADDING = 6

-- Count non-"none" styles in a styles table
local function countStyles(stylesTable: { [string]: string }): number
	local count = 0
	for _, style in pairs(stylesTable) do
		if style ~= "none" then
			count = count + 1
		end
	end
	return count
end

-- Calculate body height based on number of styles
-- Rows needed = ceil(styleCount / 2)
-- Row height = 22px cell + 4px gap between rows
-- Body height = topPadding + rows*22 + (rows-1)*4 + bottomPadding
local function getCardBodyHeightFromStyles(stylesTable: { [string]: string }): number
	local styleCount = countStyles(stylesTable)
	local rows = math.ceil(styleCount / BUTTONS_PER_ROW)
	if rows == 0 then
		rows = 1 -- Minimum 1 row
	end
	-- Height = top padding + (row heights) + (gaps between rows) + bottom padding
	local height = BODY_TOP_PADDING + (rows * STYLE_BUTTON_HEIGHT) + ((rows - 1) * STYLE_BUTTON_CELL_GAP) + BODY_BOTTOM_PADDING
	return height
end

-- Calculate total card height for a category info entry
local function getCardHeightFromCatInfo(catInfo: widgetTypes.CategoryInfoEntry): number
	return CARD_HEADER_HEIGHT + getCardBodyHeightFromStyles(catInfo.styles)
end

-- Colors - semantic aliases for picker UI (all sourced from colors.lua)
local selectedButtonColor = colors.blueDone -- Blue for selected state
local selectedTextColor = colors.black
local unselectedButtonColor = colors.pickerButtonUnselected -- Dark grey for unselected
local unselectedTextColor = colors.white
local cardBackgroundColor = colors.pickerCardBg
local cardBorderColor = colors.pickerCardBorder
local cardHeaderColor = colors.pickerHeaderBg -- Reddish header area

local module: RunWidgetPicker = {} :: RunWidgetPicker

-- Check if currently in Classic mode (FULL_UI = "classic")
local function isClassicMode(): boolean
	local fullUiStyle = currentConfig[widgetTypes.CATEGORIES.FULL_UI] or "classic"
	return fullUiStyle == "classic"
end

-- Update UI Style button highlighting (Classic/Modern)
local function updateUIStyleButtons()
	local isClassic = isClassicMode()

	if classicButton then
		if isClassic then
			classicButton.BackgroundColor3 = selectedButtonColor
			classicButton.TextColor3 = selectedTextColor
		else
			classicButton.BackgroundColor3 = unselectedButtonColor
			classicButton.TextColor3 = unselectedTextColor
		end
	end

	if modernButton then
		if not isClassic then
			modernButton.BackgroundColor3 = selectedButtonColor
			modernButton.TextColor3 = selectedTextColor
		else
			modernButton.BackgroundColor3 = unselectedButtonColor
			modernButton.TextColor3 = unselectedTextColor
		end
	end
end

-- Show or hide the modern content section and resize panel based on UI style
-- Does NOT reposition the panel - respects user's drag position
local function updateModernContentVisibility()
	local isClassic = isClassicMode()

	if modernContentSection then
		modernContentSection.Visible = not isClassic
	end

	-- Resize the panel to fit the current mode (but don't move it)
	if outerFrameRef then
		local targetHeight = if isClassic then classicPanelHeight else modernPanelHeight
		outerFrameRef.Size = UDim2.fromOffset(panelWidthRef, targetHeight)
	end
end

-- Get style display name
local function getStyleName(style: string): string
	return widgetTypes.STYLE_NAMES[style] or style
end

-- Sort styles, excluding "none" (handled by Off toggle)
-- Uses custom order from widgetTypes.STYLE_ORDER if available for the category
local function getSortedStylesWithoutNone(stylesTable: { [string]: string }, categoryId: string?): { string }
	local styles = {}
	for _, style in pairs(stylesTable) do
		if style ~= "none" then
			table.insert(styles, style)
		end
	end

	-- Check for custom order
	local customOrder = categoryId and widgetTypes.STYLE_ORDER[categoryId]
	if customOrder then
		-- Sort by position in custom order array
		local orderMap: { [string]: number } = {}
		for idx, style in ipairs(customOrder) do
			orderMap[style] = idx
		end
		table.sort(styles, function(a, b)
			local orderA = orderMap[a] or 999
			local orderB = orderMap[b] or 999
			return orderA < orderB
		end)
	else
		table.sort(styles)
	end

	return styles
end

-- Clear highlight from a card (delegates to highlightUtils)
local function clearCardHighlight(category: string, immediate: boolean?)
	local card = allCards[category]
	if card then
		highlightUtils.ClearHighlight(card, immediate)
	end
end

-- Highlight a card in the picker (delegates to highlightUtils)
-- aggressive: true for "other" element highlighting (bigger, faster pulse)
local function highlightCard(category: string, aggressive: boolean?)
	local card = allCards[category]
	if not card or not card.Parent then
		return
	end
	local mode: highlightUtils.HighlightMode = if aggressive then "aggressive" else "normal"
	highlightUtils.Highlight(card, mode)
end

-- Clear all card highlights (immediate, used when closing picker)
local function clearAllCardHighlights()
	for _, card in pairs(allCards) do
		highlightUtils.ClearHighlight(card, true)
	end
end

-- Handle widget hover events (reverse highlighting)
-- When widget is hovered, the card is the "other" element - use aggressive highlight
local function onWidgetHover(category: string, isHovering: boolean)
	if isHovering then
		highlightCard(category, true) -- Aggressive: card is the "other" element
	elseif not widgetComposer.IsEitherHovered(category) then
		clearCardHighlight(category, false)
	end
end

-- Update preset button highlighting based on current config
local function updatePresetButtons()
	local matchingPreset = widgetTypes.GetMatchingPreset(currentConfig)

	for presetKey, button in pairs(presetButtons) do
		if presetKey == matchingPreset then
			button.BackgroundColor3 = selectedButtonColor
			button.TextColor3 = selectedTextColor
		else
			button.BackgroundColor3 = unselectedButtonColor
			button.TextColor3 = unselectedTextColor
		end
	end
end

-- Update all button visuals based on current selection
local function updateAllButtons()
	for categoryId, buttons in pairs(allStyleButtons) do
		local selectedStyle = currentConfig[categoryId] or "none"
		local isOff = selectedStyle == "none"
		local isRequired = widgetTypes.REQUIRED_CATEGORIES[categoryId] == true

		-- Update Off toggle (only exists for optional categories)
		local offToggle = allOffToggles[categoryId]
		if offToggle then
			if isOff then
				offToggle.BackgroundColor3 = selectedButtonColor
				offToggle.TextColor3 = selectedTextColor
			else
				offToggle.BackgroundColor3 = unselectedButtonColor
				offToggle.TextColor3 = unselectedTextColor
			end
		end

		-- For required categories with invalid "none" config, select first style
		if isRequired and isOff then
			local styles = {}
			for _, style in pairs(widgetTypes.CATEGORY_INFO) do
				if style.id == categoryId then
					for _, s in pairs(style.styles) do
						table.insert(styles, s)
					end
					break
				end
			end
			table.sort(styles)
			if #styles > 0 then
				selectedStyle = styles[1]
				currentConfig[categoryId] = selectedStyle
				_annotate(string.format("Required category '%s' had no style, defaulting to '%s'", categoryId, selectedStyle))
			end
		end

		-- Update style buttons
		for style, button in pairs(buttons) do
			if style == selectedStyle then
				button.BackgroundColor3 = selectedButtonColor
				button.TextColor3 = selectedTextColor
			else
				button.BackgroundColor3 = unselectedButtonColor
				button.TextColor3 = unselectedTextColor
			end
		end
	end
	updateUIStyleButtons()
	updateModernContentVisibility()
	updatePresetButtons()
end

-- Create a standard button with rounded corners
local function createButton(text: string, bgColor: Color3, textColor: Color3, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = bgColor
	button.BorderSizePixel = 0
	button.TextColor3 = textColor
	button.FontFace = fonts.GetFont(false, false)
	button.TextScaled = true
	button.Text = text
	button.AutoButtonColor = true

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = MAX_TEXT_SIZE
	constraint.Parent = button

	button.MouseButton1Click:Connect(onClick)

	return button
end

function module.Init()
	_annotate("init")
end

-- Helper to create a grid card (for Timer, Speed, etc.)
-- Returns the card and its height for manual positioning
local function createGridCard(
	parent: Frame,
	catInfo: widgetTypes.CategoryInfoEntry,
	position: UDim2
): (Frame, number)
	local cardBodyHeight = getCardBodyHeightFromStyles(catInfo.styles)
	local cardHeight = CARD_HEADER_HEIGHT + cardBodyHeight
	local isRequired = widgetTypes.REQUIRED_CATEGORIES[catInfo.id] == true

	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(CARD_WIDTH, cardHeight)
	card.Position = position
	card.BackgroundColor3 = cardBackgroundColor
	card.BorderSizePixel = 0
	card.Parent = parent

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, CARD_CORNER_RADIUS)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Name = "CardBorder"
	cardStroke.Color = cardBorderColor
	cardStroke.Thickness = 1
	cardStroke.Parent = card

	allCards[catInfo.id] = card

	-- Header row: category name (left) + Off toggle (right, only for optional categories)
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, CARD_HEADER_HEIGHT)
	header.Position = UDim2.fromOffset(0, 0)
	header.BackgroundColor3 = cardHeaderColor
	header.BorderSizePixel = 0
	header.Parent = card

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, CARD_CORNER_RADIUS)
	headerCorner.Parent = header

	-- Cover bottom corners of header
	local headerBottomFill = Instance.new("Frame")
	headerBottomFill.Size = UDim2.new(1, 0, 0, CARD_CORNER_RADIUS)
	headerBottomFill.Position = UDim2.new(0, 0, 1, -CARD_CORNER_RADIUS)
	headerBottomFill.BackgroundColor3 = cardHeaderColor
	headerBottomFill.BorderSizePixel = 0
	headerBottomFill.Parent = header

	-- Category name (left-aligned)
	-- For required categories, label takes full width; for optional, leave room for Off toggle
	local labelRightPadding = if isRequired then 8 else (OFF_TOGGLE_WIDTH + 12)
	local catLabel = Instance.new("TextLabel")
	catLabel.Size = UDim2.new(1, -labelRightPadding, 1, 0)
	catLabel.Position = UDim2.fromOffset(8, 0)
	catLabel.BackgroundTransparency = 1
	catLabel.TextColor3 = colors.white
	catLabel.FontFace = fonts.GetFont(false, true)
	catLabel.TextScaled = true
	catLabel.Text = catInfo.name
	catLabel.TextXAlignment = Enum.TextXAlignment.Left
	catLabel.Parent = header

	local catConstraint = Instance.new("UITextSizeConstraint")
	catConstraint.MaxTextSize = MAX_TEXT_SIZE
	catConstraint.Parent = catLabel

	-- Off toggle (right side of header) - only for optional categories
	if not isRequired then
		local offToggle = Instance.new("TextButton")
		offToggle.Size = UDim2.fromOffset(OFF_TOGGLE_WIDTH, STYLE_BUTTON_HEIGHT)
		offToggle.Position = UDim2.new(1, -OFF_TOGGLE_WIDTH - 4, 0.5, -STYLE_BUTTON_HEIGHT / 2)
		offToggle.BackgroundColor3 = unselectedButtonColor
		offToggle.BorderSizePixel = 0
		offToggle.TextColor3 = unselectedTextColor
		offToggle.FontFace = fonts.GetFont(false, true)
		offToggle.TextScaled = true
		offToggle.Text = "Off"
		offToggle.AutoButtonColor = true
		offToggle.Parent = header

		local offCorner = Instance.new("UICorner")
		offCorner.CornerRadius = UDim.new(0, 4)
		offCorner.Parent = offToggle

		local offConstraint = Instance.new("UITextSizeConstraint")
		offConstraint.MaxTextSize = MAX_TEXT_SIZE - 2
		offConstraint.Parent = offToggle

		offToggle.MouseButton1Click:Connect(function()
			currentConfig[catInfo.id] = "none"
			_annotate(string.format("Off toggled for: %s", catInfo.id))
			updateAllButtons()
			widgetComposer.SaveConfiguration(currentConfig)
			widgetComposer.ApplyConfiguration(currentConfig)
			widgetComposer.ClearHighlight(catInfo.id)
		end)

		allOffToggles[catInfo.id] = offToggle
	end

	-- Body area: style option buttons
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.new(1, 0, 0, cardBodyHeight)
	body.Position = UDim2.fromOffset(0, CARD_HEADER_HEIGHT)
	body.BackgroundTransparency = 1
	body.ClipsDescendants = true
	body.Parent = card

	-- Wrap layout for style buttons
	local bodyLayout = Instance.new("UIGridLayout")
	bodyLayout.CellSize = UDim2.fromOffset(88, STYLE_BUTTON_HEIGHT)
	bodyLayout.CellPadding = UDim2.fromOffset(4, 4)
	bodyLayout.FillDirection = Enum.FillDirection.Horizontal
	bodyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	bodyLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bodyLayout.Parent = body

	local bodyPadding = Instance.new("UIPadding")
	bodyPadding.PaddingTop = UDim.new(0, 4)
	bodyPadding.PaddingLeft = UDim.new(0, 6)
	bodyPadding.PaddingRight = UDim.new(0, 6)
	bodyPadding.Parent = body

	-- Style buttons
	allStyleButtons[catInfo.id] = {}
	local styles = getSortedStylesWithoutNone(catInfo.styles, catInfo.id)

	for idx, style in ipairs(styles) do
		local styleName = getStyleName(style)

		local styleBtn = createButton(styleName, unselectedButtonColor, unselectedTextColor, function()
			local previousStyle = currentConfig[catInfo.id] or "none"
			currentConfig[catInfo.id] = style
			_annotate(string.format("Style changed: %s [%s -> %s]", catInfo.id, previousStyle, style))
			updateAllButtons()
			widgetComposer.SaveConfiguration(currentConfig)
			widgetComposer.ApplyConfiguration(currentConfig)
			widgetComposer.FlashHighlight(catInfo.id)
		end)
		styleBtn.LayoutOrder = idx
		styleBtn.Parent = body

		allStyleButtons[catInfo.id][style] = styleBtn
	end

	-- Hover handling - track card hover state for mutual highlighting (bidirectional)
	-- Skip for FullUI and Container - they don't need hover effects
	local skipHover = catInfo.id == widgetTypes.CATEGORIES.FULL_UI or catInfo.id == widgetTypes.CATEGORIES.CONTAINER
	if not skipHover then
		card.MouseEnter:Connect(function()
			widgetComposer.SetCardHover(catInfo.id, true)
			widgetComposer.HighlightWidget(catInfo.id, true) -- Aggressive: widget is the "other" element
			highlightCard(catInfo.id, false) -- Normal: card is what we're hovering
		end)
		card.MouseLeave:Connect(function()
			widgetComposer.SetCardHover(catInfo.id, false)
			if not widgetComposer.IsEitherHovered(catInfo.id) then
				widgetComposer.ClearHighlight(catInfo.id)
				clearCardHighlight(catInfo.id, false)
			end
		end)
	end

	return card, cardHeight
end

function module.CreateGui()

	currentConfig = widgetComposer.GetConfiguration()
	allStyleButtons = {}
	allOffToggles = {}
	allCards = {}
	classicButton = nil
	modernButton = nil
	presetButtons = {}
	modernContentSection = nil
	outerFrameRef = nil
	classicPanelHeight = 0
	modernPanelHeight = 0
	panelWidthRef = 0

	-- Register for reverse highlighting (widget hover -> card highlight)
	widgetComposer.SetWidgetHoverCallback(onWidgetHover)

	-- Create screen gui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RunWidgetPickerGui"
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 10
	screenGui:SetAttribute("DedupeKey", "RunWidgetPickerGui")

	-- Collect grid categories (excluding FullUI and Container) and calculate column heights
	local gridCategoryList: { widgetTypes.CategoryInfoEntry } = {}
	for _, catInfo in ipairs(widgetTypes.CATEGORY_INFO) do
		if catInfo.id ~= widgetTypes.CATEGORIES.FULL_UI and catInfo.id ~= widgetTypes.CATEGORIES.CONTAINER then
			table.insert(gridCategoryList, catInfo)
		end
	end

	-- Pre-calculate grid height using row-aligned layout (4 columns, 3 rows)
	-- Each row's height is determined by the tallest card in that row
	local GRID_ROWS = 3
	local rowHeights: { number } = {}
	for rowIdx = 1, GRID_ROWS do
		local maxCardHeight = 0
		for colIdx = 1, GRID_COLUMNS do
			local catIdx = (rowIdx - 1) * GRID_COLUMNS + colIdx
			local catInfo = gridCategoryList[catIdx]
			if catInfo then
				local cardHeight = getCardHeightFromCatInfo(catInfo)
				if cardHeight > maxCardHeight then
					maxCardHeight = cardHeight
				end
			end
		end
		rowHeights[rowIdx] = maxCardHeight
	end

	-- Total grid height = top padding + sum of row heights + row gaps + bottom padding
	local totalRowHeight = 0
	for _, h in ipairs(rowHeights) do
		totalRowHeight = totalRowHeight + h
	end
	local maxColumnHeight = CARD_SPACING + totalRowHeight + (GRID_ROWS - 1) * CARD_SPACING + CARD_SPACING

	-- Calculate sizes
	local titleHeight = 36
	local uiStyleRowHeight = 70 -- Height for the UI Style chooser row (includes CTA text)
	local presetRowHeight = 40 -- Height for preset buttons row
	local gridHeight = maxColumnHeight
	local closeHeight = 36
	local panelWidth = GRID_COLUMNS * CARD_WIDTH + (GRID_COLUMNS + 1) * CARD_SPACING + CARD_INNER_PADDING * 2

	-- Calculate heights for both modes
	classicPanelHeight = titleHeight + uiStyleRowHeight + closeHeight
	modernPanelHeight = titleHeight + uiStyleRowHeight + presetRowHeight + gridHeight + closeHeight
	panelWidthRef = panelWidth

	-- Start with the appropriate height based on current config
	local initialHeight = if isClassicMode() then classicPanelHeight else modernPanelHeight

	-- Use windowFunctions for standard draggable frame with position persistence
	local frameSetup = windowFunctions.SetupFrame(
		"RunWidgetPickerFrame",
		true, -- draggable
		false, -- resizable
		false, -- minimizable
		false, -- pinnable
		UDim2.fromOffset(panelWidth, initialHeight),
		false, -- maintainAspectRatio
		{
			settingName = SETTING_NAME,
			settingKey = POSITION_KEY,
			clampOnLoad = true,
		}
	)

	local outerFrame = frameSetup.outerFrame
	local contentFrame = frameSetup.contentFrame
	outerFrameRef = outerFrame

	outerFrame.BackgroundColor3 = colors.defaultGrey
	outerFrame.BackgroundTransparency = 0
	outerFrame.BorderSizePixel = BORDER_SIZE
	outerFrame.BorderColor3 = colors.black
	outerFrame.BorderMode = Enum.BorderMode.Outline

	-- If no saved position was loaded, center the panel (persistence system handles loading saved positions)
	local camera = workspace.CurrentCamera
	if camera and (outerFrame.Position.X.Offset == 0 and outerFrame.Position.Y.Offset == 0 and outerFrame.Position.X.Scale == 0 and outerFrame.Position.Y.Scale == 0) then
		local viewportSize = camera.ViewportSize
		local centeredX = (viewportSize.X - panelWidth) / 2
		local centeredY = (viewportSize.Y - initialHeight) / 2
		outerFrame.Position = UDim2.fromOffset(centeredX, centeredY)
	end

	outerFrame.Parent = screenGui

	-- Add vertical layout to content frame
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 0)
	layout.Parent = contentFrame

	-- === TITLE ===
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0, titleHeight)
	titleLabel.LayoutOrder = 1
	titleLabel.BackgroundColor3 = colors.blueDone
	titleLabel.BorderSizePixel = BORDER_SIZE
	titleLabel.BorderColor3 = colors.black
	titleLabel.TextColor3 = colors.black
	titleLabel.FontFace = fonts.GetFont(false, true)
	titleLabel.TextScaled = true
	titleLabel.Text = "Run Widget Picker"
	titleLabel.Parent = contentFrame

	local titleConstraint = Instance.new("UITextSizeConstraint")
	titleConstraint.MaxTextSize = MAX_TEXT_SIZE_BOLD
	titleConstraint.Parent = titleLabel

	-- === UI STYLE CHOICE ROW ===
	local uiStyleRow = Instance.new("Frame")
	uiStyleRow.Size = UDim2.new(1, 0, 0, uiStyleRowHeight)
	uiStyleRow.LayoutOrder = 2
	uiStyleRow.BackgroundColor3 = colors.meColor
	uiStyleRow.BorderSizePixel = BORDER_SIZE
	uiStyleRow.BorderColor3 = colors.black
	uiStyleRow.Parent = contentFrame

	-- Prompt label at top
	local promptLabel = Instance.new("TextLabel")
	promptLabel.Size = UDim2.new(1, 0, 0, 20)
	promptLabel.Position = UDim2.fromOffset(0, 4)
	promptLabel.BackgroundTransparency = 1
	promptLabel.TextColor3 = colors.black
	promptLabel.FontFace = fonts.GetFont(false, true)
	promptLabel.TextScaled = true
	promptLabel.Text = "Choose your UI style:"
	promptLabel.TextXAlignment = Enum.TextXAlignment.Center
	promptLabel.Parent = uiStyleRow

	local promptConstraint = Instance.new("UITextSizeConstraint")
	promptConstraint.MaxTextSize = 14
	promptConstraint.Parent = promptLabel

	-- Button row: Classic / Modern
	local buttonRow = Instance.new("Frame")
	buttonRow.Size = UDim2.new(1, 0, 0, 30)
	buttonRow.Position = UDim2.fromOffset(0, 24)
	buttonRow.BackgroundTransparency = 1
	buttonRow.Parent = uiStyleRow

	local buttonRowLayout = Instance.new("UIListLayout")
	buttonRowLayout.FillDirection = Enum.FillDirection.Horizontal
	buttonRowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	buttonRowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	buttonRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	buttonRowLayout.Padding = UDim.new(0, 20)
	buttonRowLayout.Parent = buttonRow

	-- Classic button
	local classicBtn = createButton("Classic", unselectedButtonColor, unselectedTextColor, function()
		_annotate("UI Style: Classic selected")
		currentConfig[widgetTypes.CATEGORIES.FULL_UI] = widgetTypes.FULL_UI_STYLES.CLASSIC
		updateAllButtons()
		widgetComposer.SaveConfiguration(currentConfig)
		widgetComposer.ApplyConfiguration(currentConfig)
	end)
	classicBtn.Size = UDim2.fromOffset(100, BUTTON_HEIGHT)
	classicBtn.LayoutOrder = 1
	classicBtn.Parent = buttonRow
	classicButton = classicBtn

	-- Modern button
	local modernBtn = createButton("Modern", unselectedButtonColor, unselectedTextColor, function()
		_annotate("UI Style: Modern selected")
		currentConfig[widgetTypes.CATEGORIES.FULL_UI] = widgetTypes.FULL_UI_STYLES.NONE
		updateAllButtons()
		widgetComposer.SaveConfiguration(currentConfig)
		widgetComposer.ApplyConfiguration(currentConfig)
	end)
	modernBtn.Size = UDim2.fromOffset(100, BUTTON_HEIGHT)
	modernBtn.LayoutOrder = 2
	modernBtn.Parent = buttonRow
	modernButton = modernBtn

	-- Description below buttons (with more space above)
	local ctaLabel = Instance.new("TextLabel")
	ctaLabel.Size = UDim2.new(1, -20, 0, 24)
	ctaLabel.Position = UDim2.fromOffset(10, 52)
	ctaLabel.BackgroundTransparency = 1
	ctaLabel.TextColor3 = colors.black
	ctaLabel.FontFace = fonts.GetFont(false, false)
	ctaLabel.TextScaled = true
	ctaLabel.Text = "This is your run timing HUD.  Classic = current  |  Modern = build your own  |  Switch freely"
	ctaLabel.TextXAlignment = Enum.TextXAlignment.Center
	ctaLabel.Parent = uiStyleRow

	local ctaConstraint = Instance.new("UITextSizeConstraint")
	ctaConstraint.MaxTextSize = 12
	ctaConstraint.Parent = ctaLabel

	-- === MODERN CONTENT SECTION (Preset row + Grid cards) ===
	-- This section is only visible when Modern is selected
	local modernSection = Instance.new("Frame")
	modernSection.Size = UDim2.new(1, 0, 0, presetRowHeight + gridHeight)
	modernSection.LayoutOrder = 3
	modernSection.BackgroundTransparency = 1
	modernSection.Parent = contentFrame
	modernContentSection = modernSection

	local modernContentLayout = Instance.new("UIListLayout")
	modernContentLayout.FillDirection = Enum.FillDirection.Vertical
	modernContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	modernContentLayout.Padding = UDim.new(0, 0)
	modernContentLayout.Parent = modernSection

	-- === PRESET ROW ===
	local presetRow = Instance.new("Frame")
	presetRow.Size = UDim2.new(1, 0, 0, presetRowHeight)
	presetRow.LayoutOrder = 0
	presetRow.BackgroundColor3 = colors.defaultGrey
	presetRow.BorderSizePixel = 0
	presetRow.Parent = modernSection

	local presetRowLayout = Instance.new("UIListLayout")
	presetRowLayout.FillDirection = Enum.FillDirection.Horizontal
	presetRowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	presetRowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	presetRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	presetRowLayout.Padding = UDim.new(0, 8)
	presetRowLayout.Parent = presetRow

	-- Reset action button (not a selectable preset - just applies and returns to unselected state)
	local resetPreset = widgetTypes.PRESETS.RESET_ALL
	local resetConfig = resetPreset.config
	local resetBtn = createButton("Reset", colors.pickerResetButton, colors.white, function()
		_annotate("Reset action triggered")
		for category, style in pairs(resetConfig) do
			currentConfig[category] = style
		end
		updateAllButtons()
		widgetComposer.SaveConfiguration(currentConfig)
		widgetComposer.ApplyConfiguration(currentConfig)
	end)
	resetBtn.Size = UDim2.fromOffset(70, BUTTON_HEIGHT)
	resetBtn.LayoutOrder = 0
	resetBtn.Parent = presetRow
	toolTip.setupToolTip(resetBtn, "Reset to minimal: timer and run info only", toolTip.enum.toolTipSize.NormalText)

	-- Separator
	local separator = Instance.new("Frame")
	separator.Size = UDim2.fromOffset(2, BUTTON_HEIGHT - 4)
	separator.BackgroundColor3 = colors.pickerSeparator
	separator.BorderSizePixel = 0
	separator.LayoutOrder = 1
	separator.Parent = presetRow

	-- Create selectable preset buttons from PICKER_PRESETS
	presetButtons = {}
	for idx, presetKey in ipairs(widgetTypes.PICKER_PRESETS) do
		local preset = widgetTypes.PRESETS[presetKey] :: widgetTypes.PresetEntry?
		if preset then
			local presetName = preset.name
			local presetConfig = preset.config
			local presetDescription: string? = preset.description

			local presetBtn = createButton(presetName, unselectedButtonColor, unselectedTextColor, function()
				_annotate(string.format("Preset selected: %s", presetKey))
				-- Deep copy the preset config
				for category, style in pairs(presetConfig) do
					currentConfig[category] = style
				end
				updateAllButtons()
				widgetComposer.SaveConfiguration(currentConfig)
				widgetComposer.ApplyConfiguration(currentConfig)
			end)
			presetBtn.Size = UDim2.fromOffset(80, BUTTON_HEIGHT)
			presetBtn.LayoutOrder = idx + 10 -- After separator
			presetBtn.Parent = presetRow

			presetButtons[presetKey] = presetBtn

			if presetDescription then
				toolTip.setupToolTip(presetBtn, presetDescription, toolTip.enum.toolTipSize.NormalText)
			end
		end
	end

	-- === GRID CARDS SECTION ===
	local gridSection = Instance.new("Frame")
	gridSection.Size = UDim2.new(1, 0, 0, gridHeight)
	gridSection.LayoutOrder = 1
	gridSection.BackgroundTransparency = 1
	gridSection.Parent = modernSection

	-- Row-aligned positioning: calculate row heights (same logic as pre-calculation)
	local placementRowHeights: { number } = {}
	for rowIdx = 1, GRID_ROWS do
		local maxCardHeight = 0
		for colIdx = 1, GRID_COLUMNS do
			local catIdx = (rowIdx - 1) * GRID_COLUMNS + colIdx
			local catInfo = gridCategoryList[catIdx]
			if catInfo then
				local cardHeight = getCardHeightFromCatInfo(catInfo)
				if cardHeight > maxCardHeight then
					maxCardHeight = cardHeight
				end
			end
		end
		placementRowHeights[rowIdx] = maxCardHeight
	end

	-- Calculate row Y positions (cumulative)
	local rowYPositions: { number } = { CARD_SPACING }
	for rowIdx = 2, GRID_ROWS do
		rowYPositions[rowIdx] = rowYPositions[rowIdx - 1] + placementRowHeights[rowIdx - 1] + CARD_SPACING
	end

	-- Create grid cards with row-aligned positioning
	for idx, catInfo in ipairs(gridCategoryList) do
		local rowIdx = math.ceil(idx / GRID_COLUMNS)
		local colIdx = ((idx - 1) % GRID_COLUMNS) + 1
		local xPos = CARD_SPACING + (colIdx - 1) * (CARD_WIDTH + CARD_SPACING)
		local yPos = rowYPositions[rowIdx]

		local position = UDim2.fromOffset(xPos, yPos)
		createGridCard(gridSection, catInfo, position)
	end

	-- === CLOSE BUTTON ===
	local _closeBtn = standardButton.CreateCloseButton({
		onClick = function()
			module.DestroyGui()
		end,
		size = UDim2.new(1, 0, 0, closeHeight),
		parent = contentFrame,
		layoutOrder = 100,
	})

	-- Update button states and visibility
	updateAllButtons()

	screenGui.Parent = playerGui

	_annotate("Created run widget picker GUI")
end

function module.DestroyGui()
	-- Clear widget hover callback
	widgetComposer.SetWidgetHoverCallback(nil)

	-- Reset hover states and clear all highlights
	widgetComposer.ResetHoverStates()
	widgetComposer.ClearAllHighlights()
	clearAllCardHighlights()

	-- Position is automatically saved by windowFunctions persistence system

	local existing = playerGui:FindFirstChild("RunWidgetPickerGui")
	if existing then
		existing:Destroy()
	end
	allStyleButtons = {}
	allOffToggles = {}
	allCards = {}
	classicButton = nil
	modernButton = nil
	presetButtons = {}
	modernContentSection = nil
	outerFrameRef = nil
end

function module.Toggle()
	local existing = playerGui:FindFirstChild("RunWidgetPickerGui")
	if existing then
		_annotate("Run widget picker closing")
		existing:Destroy()
	else
		_annotate("Run widget picker opening")
		module.CreateGui()
		local configParts = {}
		for category, style in pairs(currentConfig) do
			if style ~= "none" then
				table.insert(configParts, string.format("%s=%s", category, style))
			end
		end
		_annotate(string.format("Current config (non-none): {%s}", table.concat(configParts, ", ")))
	end
end

function module.IsOpen(): boolean
	return playerGui:FindFirstChild("RunWidgetPickerGui") ~= nil
end

_annotate("end")
return module
