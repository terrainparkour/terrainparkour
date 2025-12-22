--!strict

-- windows.lua, used in clients
-- generic module to add resize functionality to frames

-- This windowing system in Roblox LUA/luau has a couple of problems:
-- 1. There is no option to make windows block each other / not overlap with each other, or at least, to "snap" stick to each others's edges.  Instead, they just overlap each other.
-- 2. It's a bit weird that the resize dragger is only on the left corner of windows; if they are already left-aligned, it means there isn't really a way to resize them.  It'd be nice to have multiple resizers, or to let the developer choose where to put the resizer.

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
local standardButton = require(game.ReplicatedStorage.gui.standardButton)
local wt = require(game.StarterPlayer.StarterPlayerScripts.guis.windowsTypes)
local scrollingFrameUtils = require(game.ReplicatedStorage.gui.scrollingFrameUtils)
local stickyScrollingFrame = require(game.StarterPlayer.StarterPlayerScripts.guis.stickyScrollingFrame)
local windowFunctions = require(game.StarterPlayer.StarterPlayerScripts.guis.windowFunctions)
local Players = game:GetService("Players")

local toolTip = require(game.ReplicatedStorage.gui.toolTip)
local thumbnails = require(game.ReplicatedStorage.thumbnails)

local scrollingFrameBorderSizePixel = 1
local textLabelBorderSizePixel = 1
local textButtonBorderSizePixel = 1
local frameBorderSizePixel = 1
local portraitBorderSizePixel = 1
local globalBorderMode = Enum.BorderMode.Outline

local module = {}

export type PopupResult = {
	sgui: ScreenGui,
	builtContent: { [string]: Frame },
}

-- Forward declarations for mutually recursive functions
local createRowImpl: (rowSpec: wt.rowSpec) -> Frame
local createScrollingFrameImpl: (scrollingFrameSpec: wt.scrollingFrameTileSpec) -> Frame
local addLayout: (parent: Frame, direction: Enum.FillDirection) -> UIListLayout

-------------------- DEFAULTS --------------------

local globalMaxTextSize = 24
local globalMaxTextSizeBold = 24
local defaultTextBackgroundColor = colors.defaultGrey
local defaultPortraitBackgroundColor = colors.defaultGrey
local defaultTextColor = colors.black

local defaultTextButtonColor = colors.black
local defaultTextTileXAlignment = Enum.TextXAlignment.Left
local defaultTextButtonXAlignment = Enum.TextXAlignment.Center
local defaultTextButtonBackgroundColor = colors.defaultGrey

export type popupDedupeConfig = {
	key: string?, -- optional logical key; defaults to popup name
	enabled: boolean?, -- default true
	shouldDedupe: (() -> boolean)?, -- optional predicate to decide at runtime (e.g., user setting)
}

-- Ensure only one popup with a given ScreenGui name exists. This prevents stacking duplicate modals.
local function destroyExistingPopup(screenGuiName: string, dedupeConfig: popupDedupeConfig?)
	local shouldDedupe = true
	if dedupeConfig then
		if dedupeConfig.shouldDedupe then
			local ok, res = pcall(dedupeConfig.shouldDedupe)
			if ok then
				shouldDedupe = res
			else
				warn("popup dedupe predicate error:", res)
			end
		elseif dedupeConfig.enabled ~= nil then
			shouldDedupe = dedupeConfig.enabled
		end
	end
	if not shouldDedupe then
		return
	end

	local dedupeKey = (dedupeConfig and dedupeConfig.key) or screenGuiName
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return
	end
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	for _, child in ipairs(playerGui:GetChildren()) do
		if child:IsA("ScreenGui") then
			local childKey = child:GetAttribute("DedupeKey")
			if child.Name == dedupeKey or childKey == dedupeKey then
				toolTip.KillFinalTooltip()
				child:Destroy()
			end
		end
	end
end

----------------------

-- Default close button onClick: finds ScreenGui ancestor and destroys it
local function defaultCloseButtonOnClick(_: InputObject, theButton: TextButton)
	local screenGui = theButton:FindFirstAncestorOfClass("ScreenGui")
	if screenGui then
		toolTip.KillFinalTooltip()
		screenGui:Destroy()
	else
		warn("Could not find ScreenGui to close")
	end
end

-- Create a close button tileSpec with optional custom onClick handler.
-- If no onClick provided, uses default behavior (destroy ancestor ScreenGui).
-- This is the single factory for all close button tileSpecs.
module.CreateCloseButtonTileSpec = function(customOnClick: ((InputObject, TextButton) -> ())?): wt.tileSpec
	local onClick = customOnClick or defaultCloseButtonOnClick

	local buttonSpec: wt.buttonTileSpec = {
		type = "button",
		text = "Close",
		onClick = onClick,
		backgroundColor = standardButton.CLOSE_BUTTON.bg,
		hoverBackgroundColor = standardButton.CLOSE_BUTTON.hoverBg,
		textColor = standardButton.CLOSE_BUTTON.text,
		isMonospaced = false,
		isBold = true,
		textXAlignment = Enum.TextXAlignment.Center,
	}

	local tileSpec: wt.tileSpec = {
		name = "Close",
		order = 1,
		width = UDim.new(1, 0),
		spec = buttonSpec,
	}

	return tileSpec
end

-- Standard close button using default behavior (for backward compatibility)
module.StandardCloseButton = module.CreateCloseButtonTileSpec(nil)

module.CreateButton = function(buttonSpec: wt.buttonTileSpec): TextButton
	local res = Instance.new("TextButton")
	res.BorderSizePixel = textButtonBorderSizePixel
	res.BorderMode = globalBorderMode
	res.RichText = true

	-- When textSize is specified, use fixed size like text tiles do
	-- Otherwise use TextScaled with constraint for auto-sizing
	if buttonSpec.textSize then
		res.TextSize = buttonSpec.textSize
		res.TextScaled = false
	else
		res.TextScaled = true
		local constraint = Instance.new("UITextSizeConstraint")
		constraint.Name = "UITextSizeConstraint_Text"
		constraint.MaxTextSize = if buttonSpec.isBold then globalMaxTextSizeBold else globalMaxTextSize
		constraint.Parent = res
	end

	res.Text = buttonSpec.text
	res.Activated:Connect(function(el: InputObject)
		buttonSpec.onClick(el, res)
	end)
	return res
end

module.CreatePortrait = function(portraitSpec: wt.portraitTileSpec): Frame
	local res = thumbnails.createAvatarPortraitPopup(portraitSpec.userId, portraitSpec.doPopup, portraitSpec.backgroundColor, portraitBorderSizePixel)
	return res
end

module.CreateText = function(textSpec: wt.textTileSpec): TextLabel
	local res = Instance.new("TextLabel")
	res.BorderSizePixel = textLabelBorderSizePixel
	res.BorderMode = globalBorderMode
	res.BackgroundColor3 = textSpec.backgroundColor or defaultTextBackgroundColor
	res.TextColor3 = textSpec.textColor or defaultTextColor

	res.RichText = true
	res.TextXAlignment = textSpec.textXAlignment or defaultTextTileXAlignment
	res.TextYAlignment = textSpec.textYAlignment or Enum.TextYAlignment.Center
	res.TextWrapped = textSpec.textWrapped or false
	res.FontFace = fonts.GetFont(textSpec.isMonospaced, textSpec.isBold)
	res.Text = textSpec.text

	-- TextSize must be set BEFORE TextScaled, because setting TextSize resets TextScaled to false
	-- Callers should explicitly specify textScaled; if unspecified, default to true
	res.TextSize = textSpec.textSize or 24
	res.TextScaled = if textSpec.textScaled == nil then false else textSpec.textScaled
	res.TextTruncate = Enum.TextTruncate.AtEnd -- Prevent overflow with ellipsis

	-- 410-style cap so TextScaled labels do not become arbitrarily large when row heights are large.
	if res.TextScaled then
		local constraint = Instance.new("UITextSizeConstraint")
		constraint.Name = "UITextSizeConstraint_Text"
		constraint.MaxTextSize = if textSpec.isBold then globalMaxTextSizeBold else globalMaxTextSize
		constraint.Parent = res
	end

	if (textSpec.leftPadding and textSpec.leftPadding > 0) or (textSpec.rightPadding and textSpec.rightPadding > 0) or (textSpec.topPadding and textSpec.topPadding > 0) or (textSpec.bottomPadding and textSpec.bottomPadding > 0) then
		local padding = Instance.new("UIPadding")
		if textSpec.leftPadding and textSpec.leftPadding > 0 then
			padding.PaddingLeft = UDim.new(0, textSpec.leftPadding)
		end
		if textSpec.rightPadding and textSpec.rightPadding > 0 then
			padding.PaddingRight = UDim.new(0, textSpec.rightPadding)
		end
		if textSpec.topPadding and textSpec.topPadding > 0 then
			padding.PaddingTop = UDim.new(0, textSpec.topPadding)
		end
		if textSpec.bottomPadding and textSpec.bottomPadding > 0 then
			padding.PaddingBottom = UDim.new(0, textSpec.bottomPadding)
		end
		padding.Parent = res
	end

	return res
end

local function findFirstSearchEnabledScrollingFrameSpecInTileSpec(tileSpec: wt.tileSpec): wt.scrollingFrameTileSpec?
	if tileSpec.spec.type == "scrollingFrameTileSpec" then
		local scrollingSpec = tileSpec.spec :: wt.scrollingFrameTileSpec
		if scrollingSpec.searchConfig then
			return scrollingSpec
		end
		return nil
	end
	if tileSpec.spec.type == "rowTile" then
		local rowTileSpec = tileSpec.spec :: wt.rowTileSpec
		for _, innerTileSpec in ipairs(rowTileSpec.tileSpecs) do
			local found = findFirstSearchEnabledScrollingFrameSpecInTileSpec(innerTileSpec)
			if found then
				return found
			end
		end
		return nil
	end
	return nil
end

local function cloneRowSpecShallow(rowSpec: wt.rowSpec): wt.rowSpec
	-- Shallow clone: we do not copy nested tile specs, we just reuse them.
	local cloned: wt.rowSpec = {
		name = rowSpec.name,
		order = rowSpec.order,
		tileSpecs = rowSpec.tileSpecs,
		height = rowSpec.height,
		horizontalAlignment = rowSpec.horizontalAlignment,
		bottomBorderColor = rowSpec.bottomBorderColor,
		bottomBorderThickness = rowSpec.bottomBorderThickness,
		timeText = rowSpec.timeText,
		searchText = rowSpec.searchText,
	}
	return cloned
end

local function createSearchChromeRow(rowOrder: number, searchConfig: wt.scrollingFrameSearchConfig, searchTargetName: string): Frame
	local searchRowHeightPixels = 30
	local clearButtonWidthPixels = 30
	local countLabelWidthPixels = 190

	local rowFrame = Instance.new("Frame")
	rowFrame.Name = string.format("%04d_SearchChrome_%s", rowOrder, searchTargetName)
	rowFrame:SetAttribute("SearchTargetName", searchTargetName)
	rowFrame.Size = UDim2.new(1, 0, 0, searchRowHeightPixels)
	rowFrame.BorderSizePixel = 0
	rowFrame.BackgroundTransparency = 0
	rowFrame.BackgroundColor3 = colors.white

	local layout = addLayout(rowFrame, Enum.FillDirection.Horizontal)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = rowFrame

	local searchBox = Instance.new("TextBox")
	searchBox.Name = "SearchBox"
	searchBox.LayoutOrder = 1
	searchBox.Size = UDim2.new(1, -(clearButtonWidthPixels + countLabelWidthPixels), 1, 0)
	searchBox.BackgroundColor3 = colors.white
	searchBox.TextColor3 = colors.black
	searchBox.TextScaled = true
	searchBox.ClearTextOnFocus = false
	searchBox.RichText = false
	searchBox.Text = "" -- Prevent Roblox default "TextBox" text
	searchBox.PlaceholderText = searchConfig.placeholderText or "Search..."
	searchBox.PlaceholderColor3 = colors.textSubtle
	searchBox.FontFace = fonts.GetFont(false, true)
	searchBox.TextXAlignment = Enum.TextXAlignment.Left
	searchBox.Parent = rowFrame

	local searchPadding = Instance.new("UIPadding")
	searchPadding.PaddingLeft = UDim.new(0, 6)
	searchPadding.PaddingRight = UDim.new(0, 6)
	searchPadding.Parent = searchBox

	local searchConstraint = Instance.new("UITextSizeConstraint")
	searchConstraint.Name = "UITextSizeConstraint_Search"
	searchConstraint.MaxTextSize = globalMaxTextSize
	searchConstraint.Parent = searchBox

	local clearButton = Instance.new("TextButton")
	clearButton.Name = "ClearButton"
	clearButton.LayoutOrder = 2
	clearButton.Size = UDim2.new(0, clearButtonWidthPixels, 1, 0)
	clearButton.BackgroundColor3 = colors.white
	clearButton.TextColor3 = colors.black
	clearButton.TextScaled = true
	clearButton.RichText = false
	clearButton.FontFace = fonts.GetFont(false, true)
	clearButton.TextXAlignment = Enum.TextXAlignment.Center
	clearButton.Text = "x"
	clearButton.Visible = false
	clearButton.Parent = rowFrame

	local clearConstraint = Instance.new("UITextSizeConstraint")
	clearConstraint.Name = "UITextSizeConstraint_Clear"
	clearConstraint.MaxTextSize = globalMaxTextSize
	clearConstraint.Parent = clearButton

	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.LayoutOrder = 3
	countLabel.Size = UDim2.new(0, countLabelWidthPixels, 1, 0)
	countLabel.BackgroundColor3 = colors.white
	countLabel.BackgroundTransparency = 0
	countLabel.BorderSizePixel = 0
	countLabel.TextScaled = true
	countLabel.RichText = false
	countLabel.TextColor3 = colors.black
	countLabel.FontFace = fonts.GetFont(false, false)
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.Text = ""
	countLabel.Visible = false
	countLabel.Parent = rowFrame

	local countConstraint = Instance.new("UITextSizeConstraint")
	countConstraint.Name = "UITextSizeConstraint_Count"
	countConstraint.MaxTextSize = 13
	countConstraint.Parent = countLabel

	local countPadding = Instance.new("UIPadding")
	countPadding.PaddingLeft = UDim.new(0, 6)
	countPadding.PaddingRight = UDim.new(0, 6)
	countPadding.Parent = countLabel

	return rowFrame
end

local function wireSearchChromeRow(rowFrame: Frame, searchConfig: wt.scrollingFrameSearchConfig, outerFrame: Frame)
	local searchTargetNameAttr = rowFrame:GetAttribute("SearchTargetName")
	local searchTargetName: string? = if typeof(searchTargetNameAttr) == "string" then searchTargetNameAttr else nil
	if not searchTargetName then
		annotater.Error("Search chrome row missing SearchTargetName attribute")
		return
	end

	local searchBox = rowFrame:FindFirstChild("SearchBox")
	if not searchBox or not searchBox:IsA("TextBox") then
		annotater.Error("Search chrome row missing SearchBox TextBox")
		return
	end

	local clearButton = rowFrame:FindFirstChild("ClearButton")
	local countLabel = rowFrame:FindFirstChild("CountLabel")
	if not clearButton or not clearButton:IsA("TextButton") then
		annotater.Error("Search chrome row missing ClearButton TextButton")
		return
	end
	if not countLabel or not countLabel:IsA("TextLabel") then
		annotater.Error("Search chrome row missing CountLabel TextLabel")
		return
	end

	local filterEventName = "SearchFilterEvent_" .. searchTargetName
	local totalValueName = "SearchTotalCount_" .. searchTargetName
	local shownValueName = "SearchShownCount_" .. searchTargetName

	local filterEvent = outerFrame:FindFirstChild(filterEventName, true)
	local totalValue = outerFrame:FindFirstChild(totalValueName, true)
	local shownValue = outerFrame:FindFirstChild(shownValueName, true)

	if not filterEvent or not filterEvent:IsA("BindableEvent") then
		annotater.Error(string.format("Search chrome could not find BindableEvent '%s'", filterEventName))
		return
	end
	if not totalValue or not totalValue:IsA("IntValue") then
		annotater.Error(string.format("Search chrome could not find IntValue '%s'", totalValueName))
		return
	end
	if not shownValue or not shownValue:IsA("IntValue") then
		annotater.Error(string.format("Search chrome could not find IntValue '%s'", shownValueName))
		return
	end

	local filterEventInstance = filterEvent :: BindableEvent
	local totalValueInstance = totalValue :: IntValue
	local shownValueInstance = shownValue :: IntValue
	local noun = searchConfig.countNoun or "items"

	local function updateCountText()
		if searchBox.Text == "" then
			countLabel.Visible = false
			return
		end
		countLabel.Visible = true
		countLabel.Text = string.format("showing %d of %d %s", shownValueInstance.Value, totalValueInstance.Value, noun)
	end

	totalValueInstance.Changed:Connect(updateCountText)
	shownValueInstance.Changed:Connect(updateCountText)

	clearButton.Activated:Connect(function()
		searchBox.Text = ""
		searchBox:CaptureFocus()
	end)

	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		local hasText = searchBox.Text ~= ""
		clearButton.Visible = hasText
		countLabel.Visible = hasText
		updateCountText()
		filterEventInstance:Fire(searchBox.Text)
	end)

	updateCountText()

	local shouldAutoFocus = if searchConfig.autoFocus ~= nil then searchConfig.autoFocus else true
	if shouldAutoFocus then
		task.defer(function()
			if searchBox.Parent then
				searchBox:CaptureFocus()
			end
		end)
	end
end

--------------------------------------------------------------------------------
-- Digit-Highlighted Time Tile
-- Displays a time string with per-digit background highlighting based on
-- comparison with the previous row's time. Worse (higher) digits get red tint,
-- better (lower) digits get green tint.
--------------------------------------------------------------------------------

-- Default highlight colors (subtle tints)
local DEFAULT_WORSE_DIGIT_COLOR = Color3.fromRGB(239, 68, 68) -- Red for worse digits
local HIGHLIGHT_ALPHA = 0.15 -- How much to blend the highlight color (subtle)

-- Blend a highlight color with a base color
local function blendColors(baseColor: Color3, highlightColor: Color3, alpha: number): Color3
	return Color3.new(baseColor.R + (highlightColor.R - baseColor.R) * alpha, baseColor.G + (highlightColor.G - baseColor.G) * alpha, baseColor.B + (highlightColor.B - baseColor.B) * alpha)
end

-- Compare two time strings and determine which characters to highlight.
-- Once a digit is worse (higher) than the corresponding digit above, that digit
-- AND all subsequent characters are highlighted because they represent the "worse suffix".
-- Example: 3.32 → 3.41 highlights "41" because 41 > 32
-- Example: 3.31 → 3.38 highlights just "8" because only the last digit differs
local function compareTimeDigits(currentText: string, previousText: string?): { { char: string, shouldHighlight: boolean } }
	local results: { { char: string, shouldHighlight: boolean } } = {}

	if not previousText then
		-- No comparison, no highlighting
		for i = 1, #currentText do
			table.insert(results, { char = string.sub(currentText, i, i), shouldHighlight = false })
		end
		return results
	end

	-- Find the first position where current digit is worse (higher)
	local highlightFromIndex: number? = nil

	for i = 1, #currentText do
		local currChar = string.sub(currentText, i, i)
		local prevChar = string.sub(previousText, i, i)

		local currDigit = tonumber(currChar)
		local prevDigit = tonumber(prevChar)

		if currDigit and prevDigit then
			if currDigit > prevDigit then
				-- Found the first worse digit - highlight from here onwards
				highlightFromIndex = i
				break
			elseif currDigit < prevDigit then
				-- Current digit is better - no highlighting needed for this time
				-- (the overall time is faster from this position)
				break
			end
			-- If equal, continue to next digit
		end
	end

	-- Build results: highlight from the found index onwards
	for i = 1, #currentText do
		local currChar = string.sub(currentText, i, i)
		local shouldHighlight = highlightFromIndex ~= nil and i >= highlightFromIndex
		table.insert(results, { char = currChar, shouldHighlight = shouldHighlight })
	end

	return results
end

module.CreateDigitHighlightedTime = function(spec: wt.digitHighlightedTimeTileSpec): Frame
	local baseColor = spec.backgroundColor or defaultTextBackgroundColor
	local textColor = spec.textColor or defaultTextColor
	local worseColor = spec.worseDigitColor or DEFAULT_WORSE_DIGIT_COLOR
	local textAlignment = spec.textXAlignment or Enum.TextXAlignment.Right

	-- Container frame
	local container = Instance.new("Frame")
	container.BorderSizePixel = textLabelBorderSizePixel
	container.BorderMode = globalBorderMode
	container.BackgroundColor3 = baseColor

	-- Horizontal layout for digits
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 0)

	-- Handle alignment
	if textAlignment == Enum.TextXAlignment.Right then
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	elseif textAlignment == Enum.TextXAlignment.Center then
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	else
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	end

	layout.Parent = container

	-- Add small padding on the right for visual balance
	local padding = Instance.new("UIPadding")
	padding.PaddingRight = UDim.new(0, 4)
	padding.Parent = container

	-- Compare and create digit labels
	local comparison = compareTimeDigits(spec.text, spec.previousText)

	for i, info in ipairs(comparison) do
		-- Skip empty or whitespace-only characters
		if info.char == "" or info.char == " " or info.char == "\n" or info.char == "\r" then
			continue
		end

		local digitLabel = Instance.new("TextLabel")
		digitLabel.Name = string.format("Digit_%d", i)
		digitLabel.LayoutOrder = i
		digitLabel.Size = UDim2.new(0, 0, 1, 0) -- Height fills, width auto
		digitLabel.AutomaticSize = Enum.AutomaticSize.X
		digitLabel.BorderSizePixel = 0
		digitLabel.TextColor3 = textColor
		-- Fixed size for row-to-row comparability (must match plain text time display)
		digitLabel.TextSize = 24
		digitLabel.TextScaled = false
		digitLabel.FontFace = fonts.GetFont(true, false) -- Monospaced
		digitLabel.Text = info.char

		-- Apply background: highlight worse suffix with subtle red
		if info.shouldHighlight then
			digitLabel.BackgroundColor3 = blendColors(baseColor, worseColor, HIGHLIGHT_ALPHA)
		else
			digitLabel.BackgroundColor3 = baseColor
		end
		digitLabel.BackgroundTransparency = 0
		digitLabel.Parent = container
	end

	return container
end

--------------------------------------------------------------------------------
-- Logarithmic-Scaled Indicator Tiles
-- Shared library for tiles that show a value on a logarithmic scale with a
-- color gradient background and vertical position indicator.
--------------------------------------------------------------------------------

-- Color gradient: pure sky blue (low) → warm amber (high)
-- Gives a "progression" feel without implying good/bad
local LOG_SCALE_COLOR_LOW = Color3.fromRGB(140, 180, 230) -- Pure sky blue
local LOG_SCALE_COLOR_HIGH = Color3.fromRGB(245, 190, 120) -- Warm amber/orange

-- Default indicator color: matte red for visibility
local DEFAULT_INDICATOR_COLOR = Color3.fromRGB(180, 70, 70)

local function getLogScaleColor(logPosition: number): Color3
	local r = LOG_SCALE_COLOR_LOW.R + (LOG_SCALE_COLOR_HIGH.R - LOG_SCALE_COLOR_LOW.R) * logPosition
	local g = LOG_SCALE_COLOR_LOW.G + (LOG_SCALE_COLOR_HIGH.G - LOG_SCALE_COLOR_LOW.G) * logPosition
	local b = LOG_SCALE_COLOR_LOW.B + (LOG_SCALE_COLOR_HIGH.B - LOG_SCALE_COLOR_LOW.B) * logPosition
	return Color3.new(r, g, b)
end

-- Shared tile renderer for logarithmic-scaled indicator tiles
-- Used by both "lasted" and "improvement" tile types
module.CreateLogScaledTile = function(config: wt.logScaledTileConfig): Frame
	local backgroundColor = getLogScaleColor(config.logPosition)
	local indicatorColor = config.indicatorColor or DEFAULT_INDICATOR_COLOR

	local container = Instance.new("Frame")
	container.BorderSizePixel = 0
	container.BackgroundColor3 = backgroundColor

	-- Text label
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "LogScaledText"
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.Position = UDim2.new(0, 0, 0, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.TextColor3 = config.textColor or defaultTextColor
	textLabel.TextScaled = true
	textLabel.TextXAlignment = config.textAlignment
	textLabel.FontFace = fonts.GetFont(true, false) -- monospaced
	textLabel.Text = config.text
	textLabel.ZIndex = 2
	textLabel.Parent = container

	local textPadding = Instance.new("UIPadding")
	if config.paddingSide == "left" then
		textPadding.PaddingLeft = UDim.new(0, 4)
	else
		textPadding.PaddingRight = UDim.new(0, 6)
	end
	textPadding.Parent = textLabel

	-- Vertical position indicator
	local shouldShowIndicator = config.showIndicatorAtZero or config.logPosition > 0
	if shouldShowIndicator then
		local indicator = Instance.new("Frame")
		indicator.Name = "PositionIndicator"
		indicator.Size = UDim2.new(0, 3, 0.7, 0) -- 3px wide, 70% height
		indicator.Position = UDim2.new(config.logPosition, -1, 0.15, 0) -- Centered on position
		indicator.BackgroundColor3 = indicatorColor
		indicator.BorderSizePixel = 0
		indicator.ZIndex = 3
		indicator.Parent = container

		local indicatorCorner = Instance.new("UICorner")
		indicatorCorner.CornerRadius = UDim.new(0, 1)
		indicatorCorner.Parent = indicator
	end

	return container
end

--------------------------------------------------------------------------------
-- Duration (Lasted) Tile
-- Fixed logarithmic scale: 1 second (left) to 5 years (right)
--------------------------------------------------------------------------------

local MIN_DURATION_SECONDS = 1
local MAX_DURATION_SECONDS = 5 * 365 * 24 * 60 * 60 -- 5 years
local DURATION_LOG_MIN = math.log(MIN_DURATION_SECONDS)
local DURATION_LOG_MAX = math.log(MAX_DURATION_SECONDS)

local function durationToLogPosition(durationSeconds: number): number
	if durationSeconds <= MIN_DURATION_SECONDS then
		return 0
	end
	if durationSeconds >= MAX_DURATION_SECONDS then
		return 1
	end
	local logDuration = math.log(durationSeconds)
	return (logDuration - DURATION_LOG_MIN) / (DURATION_LOG_MAX - DURATION_LOG_MIN)
end

module.CreateLastedTile = function(lastedSpec: wt.lastedTileSpec): Frame
	local logPosition = durationToLogPosition(lastedSpec.durationSeconds)

	local config: wt.logScaledTileConfig = {
		logPosition = logPosition,
		text = lastedSpec.text,
		textColor = lastedSpec.textColor,
		textAlignment = Enum.TextXAlignment.Left,
		paddingSide = "left",
		showIndicatorAtZero = true, -- Always show indicator for lasted
		indicatorColor = lastedSpec.indicatorColor,
	}

	return module.CreateLogScaledTile(config)
end

--------------------------------------------------------------------------------
-- Improvement Tile
-- Dynamic logarithmic scale: 1ms (left) to maxImprovementMs (right)
--------------------------------------------------------------------------------

local function improvementToLogPosition(improvementMs: number, maxImprovementMs: number): number
	if maxImprovementMs <= 0 or improvementMs <= 0 then
		return 0
	end

	local minMs = 1 -- Avoid log(0)
	local logMin = math.log(minMs)
	local logMax = math.log(math.max(maxImprovementMs, minMs + 1))
	local logValue = math.log(math.max(improvementMs, minMs))

	if logMax <= logMin then
		return 0
	end

	return math.clamp((logValue - logMin) / (logMax - logMin), 0, 1)
end

module.CreateImprovementTile = function(improvementSpec: wt.improvementTileSpec): Frame
	local logPosition = improvementToLogPosition(improvementSpec.improvementMs, improvementSpec.maxImprovementMs)

	local config: wt.logScaledTileConfig = {
		logPosition = logPosition,
		text = improvementSpec.text,
		textColor = improvementSpec.textColor,
		textAlignment = Enum.TextXAlignment.Right,
		paddingSide = "right",
		showIndicatorAtZero = false, -- Only show indicator for non-zero improvement
		indicatorColor = improvementSpec.indicatorColor,
	}

	return module.CreateLogScaledTile(config)
end

addLayout = function(parent: Frame, direction: Enum.FillDirection): UIListLayout
	local res = Instance.new("UIListLayout")
	res.Name = string.format("%s_layout", parent.Name)
	-- Do not set HorizontalFlex; let manual width calculations control layout
	-- res.HorizontalFlex = Enum.UIFlexAlignment.Fill
	-- res.VerticalFlex = Enum.UIFlexAlignment.Fill
	res.SortOrder = Enum.SortOrder.Name
	res.Parent = parent
	res.FillDirection = direction
	return res
end

-- Normalizes row heights: rows with Scale > 0 are treated as weights and share remaining space.
-- Rows with Scale = 0 keep their fixed Offset height. Weights are normalized to sum to 1.
-- Example: weights 400, 30, 30 with 100px fixed → weights become 0.87, 0.065, 0.065 of (parent - 100px).
-- IMPORTANT: UDim.new(400, 0) means "weight 400", not "400 pixels". See windowsTypes.lua for details.
local function applyProportionalHeights(frames: { Frame })
	local totalScale = 0
	local totalFixed = 0

	-- Calculate total scale and fixed offset
	for _, aFrameRow in ipairs(frames) do
		local size = aFrameRow.Size
		if size.Y.Scale > 0 then
			totalScale = totalScale + size.Y.Scale
		else
			totalFixed = totalFixed + size.Y.Offset
		end
	end

	for _, aFrameRow in ipairs(frames) do
		local size = aFrameRow.Size
		local newScaleY = 0
		local myNegative = 0
		if totalScale > 0 then
			newScaleY = size.Y.Scale / totalScale
			myNegative = newScaleY * totalFixed * -1
		end
		aFrameRow.Size = UDim2.new(size.X.Scale, size.X.Offset, newScaleY, size.Y.Offset + myNegative)
	end
end

local function applyProportionalWidths(objects: { GuiObject })
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

--- actually it's a fake frame which manages itself.
createScrollingFrameImpl = function(scrollingFrameSpec: wt.scrollingFrameTileSpec): Frame
	local contentFrame: Frame = Instance.new("Frame")
	contentFrame.Name = string.format("%s_OuterFor_ScrollingFrame", scrollingFrameSpec.name)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Size = UDim2.new(1, 0, 1, 0)
	contentFrame.BorderSizePixel = frameBorderSizePixel
	contentFrame.BorderMode = globalBorderMode
	contentFrame.ClipsDescendants = true -- Prevent header row borders from extending outside

	local contentFrameLayout: UIListLayout = addLayout(contentFrame, Enum.FillDirection.Vertical)
	contentFrameLayout.SortOrder = Enum.SortOrder.Name
	contentFrameLayout.FillDirection = Enum.FillDirection.Vertical
	contentFrameLayout.Parent = contentFrame

	local headerRow: Frame = createRowImpl(scrollingFrameSpec.headerRow)
	headerRow.Parent = contentFrame

	local rowsToShow: number = scrollingFrameSpec.howManyRowsToShow or 10
	local theStickyFrameManager: wt.stickyScrollingFrameType = stickyScrollingFrame.CreateStickyScrollingFrame(scrollingFrameSpec.rowHeight, rowsToShow - 1)
	theStickyFrameManager.frame.Parent = contentFrame
	theStickyFrameManager.frame.Name = string.format("%s_StickyFrame", scrollingFrameSpec.name)
	-- Container frame properties (ScrollingFrame-specific properties are set internally)
	theStickyFrameManager.frame.BorderMode = globalBorderMode
	theStickyFrameManager.frame.BackgroundTransparency = 1
	theStickyFrameManager.frame.BorderSizePixel = scrollingFrameBorderSizePixel
	theStickyFrameManager.frame.Size = UDim2.new(1, 0, 1, 0)

	-- Track last row height to avoid thrashing
	local lastRowHeight: number = 0

	-- Update header and scrolling frame sizes for proportional scaling
	-- Snap to whole pixel row heights so content exactly fills viewport (no gaps)
	local function updateScrollingFrameSize()
		local contentHeight = contentFrame.AbsoluteSize.Y
		if contentHeight <= 0 or rowsToShow <= 0 then
			return
		end

		-- Calculate row height and round down for pixel-perfect fit
		local idealRowHeight = contentHeight / rowsToShow
		local roundedRowHeight = math.floor(idealRowHeight)

		if roundedRowHeight < 1 then
			return
		end

		if math.abs(roundedRowHeight - lastRowHeight) < 1 then
			return -- Skip tiny changes to avoid thrashing
		end
		lastRowHeight = roundedRowHeight

		-- Header gets exactly 1 row height
		headerRow.Size = UDim2.new(1, 0, 0, roundedRowHeight)

		-- Scrolling frame gets exactly (rowsToShow - 1) row heights
		-- This ensures no fractional-pixel gaps within the scrolling area
		local scrollingFrameHeight = roundedRowHeight * (rowsToShow - 1)
		theStickyFrameManager.frame.Size = UDim2.new(1, 0, 0, scrollingFrameHeight)

		-- Any remainder pixels (0 to rowsToShow-1) appear as a small gap
		-- between this section and the next, which is less jarring than
		-- a gap within the scrolling list itself
	end

	contentFrameLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateScrollingFrameSize)
	contentFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScrollingFrameSize)

	-- Initial size update after layout is ready
	task.defer(updateScrollingFrameSize)

	local searchRowEntries: { { row: Frame, searchBlob: string } } = {}
	local filterEvent: BindableEvent? = nil
	local totalCountValue: IntValue? = nil
	local shownCountValue: IntValue? = nil

	if scrollingFrameSpec.searchConfig then
		local filterEventInstance = Instance.new("BindableEvent") :: BindableEvent
		filterEventInstance.Name = "SearchFilterEvent_" .. scrollingFrameSpec.name
		filterEventInstance.Parent = contentFrame
		filterEvent = filterEventInstance

		local totalCountValueInstance = Instance.new("IntValue") :: IntValue
		totalCountValueInstance.Name = "SearchTotalCount_" .. scrollingFrameSpec.name
		totalCountValueInstance.Value = 0
		totalCountValueInstance.Parent = contentFrame
		totalCountValue = totalCountValueInstance

		local shownCountValueInstance = Instance.new("IntValue") :: IntValue
		shownCountValueInstance.Name = "SearchShownCount_" .. scrollingFrameSpec.name
		shownCountValueInstance.Value = 0
		shownCountValueInstance.Parent = contentFrame
		shownCountValue = shownCountValueInstance
	end

	for _, rowSpec in ipairs(scrollingFrameSpec.dataRows) do
		local row: Frame = createRowImpl(rowSpec)
		theStickyFrameManager.addElement(row, rowSpec.order, false)
		-- row.Parent = scrollingFrame

		if filterEvent then
			local rawSearchText = rowSpec.searchText
			if not rawSearchText then
				annotater.Error(string.format("scrollingFrame '%s' has searchConfig but row '%s' missing rowSpec.searchText", scrollingFrameSpec.name, rowSpec.name))
			end
			local normalizedSearchText: string = string.lower(rawSearchText or rowSpec.name)
			table.insert(searchRowEntries, { row = row, searchBlob = normalizedSearchText })
		end
	end

	for _, rowSpec in ipairs(scrollingFrameSpec.stickyRows) do
		rowSpec.name = string.format("%s_Sticky", rowSpec.name)
		local row: Frame = createRowImpl(rowSpec)
		theStickyFrameManager.addElement(row, rowSpec.order, true)
		-- row.Parent = scrollingFrame
	end

	-- Calculate content size
	-- local contentHeight: number = #scrollingFrameSpec.dataRows * scrollingFrameSpec.rowHeight
	-- contentFrame.Size = UDim2.new(1, 0, 1, 0)
	-- theStickyFrameManager.frame.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
	theStickyFrameManager.doneAdding()

	if filterEvent and totalCountValue and shownCountValue then
		totalCountValue.Value = #searchRowEntries

		local function applyFilter(query: string)
			local normalizedQuery = string.lower(query)
			local shownCount = 0

			for _, entry in ipairs(searchRowEntries) do
				local shouldShow = true
				if query ~= "" then
					shouldShow = string.find(entry.searchBlob, normalizedQuery, 1, true) ~= nil
				end
				entry.row:SetAttribute("FilteredOut", if shouldShow then 0 else 1)
				if shouldShow then
					shownCount += 1
				end
			end

			shownCountValue.Value = shownCount
			theStickyFrameManager.refresh()
		end

		filterEvent.Event:Connect(function(query: any)
			if typeof(query) ~= "string" then
				return
			end
			applyFilter(query)
		end)

		applyFilter("")
	end

	return contentFrame
end

module.CreateScrollingFrameOrig = function(scrollingFrameSpec: wt.scrollingFrameTileSpec): Frame
	local contentFrame: Frame = Instance.new("Frame")
	contentFrame.Name = string.format("%s_OuterFor_ScrollingFrame", scrollingFrameSpec.name)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Size = UDim2.new(1, 0, 1, 0)
	contentFrame.BorderSizePixel = frameBorderSizePixel
	contentFrame.BorderMode = globalBorderMode

	local headerRow: Frame = createRowImpl(scrollingFrameSpec.headerRow)
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
		local row: Frame = createRowImpl(rowSpec)
		row.Parent = scrollingFrame
	end

	-- Calculate content size
	local contentHeight: number = #scrollingFrameSpec.dataRows * scrollingFrameSpec.rowHeight
	contentFrame.Size = UDim2.new(1, 0, 0, contentHeight)
	scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, contentHeight)

	-- Prevent camera scroll when hovering over scrolling frame
	scrollingFrameUtils.PreventCameraScrollOnHover(scrollingFrame)

	return contentFrame
end

-- Modify the CreateRow function to handle scrolling frames
-- Returns both the frame and a map of tile references by tile name
createRowImpl = function(rowSpec: wt.rowSpec): (Frame, { [string]: GuiObject })
	local frame = Instance.new("Frame")
	frame.Name = string.format("%04d_%s", rowSpec.order, rowSpec.name)
	frame.Size = UDim2.new(1, 0, 0, rowSpec.height.Offset)
	frame.BorderSizePixel = frameBorderSizePixel
	frame.BorderMode = globalBorderMode
	frame.ClipsDescendants = true -- Prevent text from overflowing row bounds

	if rowSpec.bottomBorderColor then
		local stroke = Instance.new("UIStroke")
		stroke.Name = "BottomBorder"
		stroke.Color = rowSpec.bottomBorderColor
		stroke.Thickness = rowSpec.bottomBorderThickness or 2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.LineJoinMode = Enum.LineJoinMode.Miter
		stroke.Parent = frame
	end

	local layout = addLayout(frame, Enum.FillDirection.Horizontal)
	if rowSpec.horizontalAlignment then
		layout.HorizontalAlignment = rowSpec.horizontalAlignment
	end
	local items: { GuiObject } = {}
	local tileReferences: { [string]: GuiObject } = {}

	-- we need to intelligently apply widths here based on both the tile widthWeight proportion, and also remembering to also handle offset-based tile types.
	for _, tileSpec: wt.tileSpec in pairs(rowSpec.tileSpecs) do
		if tileSpec.spec.type == "button" then
			local button = module.CreateButton(tileSpec.spec)
			local baseBg = tileSpec.spec.backgroundColor or defaultTextButtonBackgroundColor
			button.BackgroundColor3 = baseBg
			button.FontFace = fonts.GetFont(tileSpec.spec.isMonospaced, tileSpec.spec.isBold)
			button.TextColor3 = tileSpec.spec.textColor or defaultTextButtonColor
			button.TextXAlignment = tileSpec.spec.textXAlignment or defaultTextButtonXAlignment

			-- Add hover effect if hoverBackgroundColor is specified
			if tileSpec.spec.hoverBackgroundColor then
				local hoverBg = tileSpec.spec.hoverBackgroundColor
				button.AutoButtonColor = false
				button.MouseEnter:Connect(function()
					button.BackgroundColor3 = hoverBg
				end)
				button.MouseLeave:Connect(function()
					button.BackgroundColor3 = baseBg
				end)
			end

			if tileSpec.tooltipText ~= nil and tileSpec.tooltipText ~= "" then
				toolTip.setupToolTip(button, tileSpec.tooltipText, toolTip.enum.toolTipSize.NormalText, nil, nil, nil, nil, tileSpec.tooltipStyle)
			end

			button.Name = string.format("%04d_%s", tileSpec.order, tileSpec.name)
			local useWidth: UDim = tileSpec.width or UDim.new(1, 0)
			button.Size = UDim2.new(useWidth.Scale, useWidth.Offset, 1, 0)
			table.insert(items, button)
			tileReferences[tileSpec.name] = button
		elseif tileSpec.spec.type == "text" then
			local text = module.CreateText(tileSpec.spec)
			text.Name = string.format("%04d_%s", tileSpec.order, tileSpec.name)
			local useWidth: UDim = tileSpec.width or UDim.new(1, 0)
			text.Size = UDim2.new(useWidth.Scale, useWidth.Offset, 1, 0)

			if tileSpec.tooltipText ~= nil and tileSpec.tooltipText ~= "" then
				toolTip.setupToolTip(text, tileSpec.tooltipText, toolTip.enum.toolTipSize.NormalText, nil, nil, nil, nil, tileSpec.tooltipStyle)
			end
			table.insert(items, text)
			tileReferences[tileSpec.name] = text
		elseif tileSpec.spec.type == "portrait" then
			local imageFrame = module.CreatePortrait(tileSpec.spec)
			imageFrame.Name = string.format("%04d_%s_ImageFrame", tileSpec.order, tileSpec.name)
			local useWidth = tileSpec.width or UDim.new(1, 0)
			imageFrame.Size = UDim2.new(useWidth.Scale, useWidth.Offset, 1, 0)
			imageFrame.BackgroundColor3 = tileSpec.spec.backgroundColor or defaultPortraitBackgroundColor

			local theImageLabel = imageFrame:FindFirstChildOfClass("ImageLabel") :: ImageLabel
			theImageLabel.Name = string.format("%04d_%s", tileSpec.order, tileSpec.name)

			-- Add right border if specified
			if tileSpec.spec.rightBorderColor then
				local rightBorder = Instance.new("Frame")
				rightBorder.Name = "RightBorder"
				rightBorder.Size = UDim2.new(0, 1, 1, 0)
				rightBorder.Position = UDim2.new(1, -1, 0, 0)
				rightBorder.BackgroundColor3 = tileSpec.spec.rightBorderColor
				rightBorder.BorderSizePixel = 0
				rightBorder.ZIndex = 5
				rightBorder.Parent = imageFrame
			end

			if tileSpec.tooltipText ~= nil and tileSpec.tooltipText ~= "" then
				toolTip.setupToolTip(theImageLabel, tileSpec.tooltipText, toolTip.enum.toolTipSize.NormalText, nil, nil, nil, nil, tileSpec.tooltipStyle)
			end
			table.insert(items, imageFrame)
			tileReferences[tileSpec.name] = theImageLabel
		elseif tileSpec.spec.type == "image" then
			local imageSpec = tileSpec.spec :: wt.imageTileSpec
			local imageLabel: ImageLabel
			if imageSpec.doPopup then
				-- Use thumbnails module for popup support
				imageLabel = thumbnails.createBadgeImageWithPopup(imageSpec.imageId, true, imageSpec.backgroundColor)
			else
				imageLabel = Instance.new("ImageLabel")
				imageLabel.BackgroundColor3 = imageSpec.backgroundColor or colors.defaultGrey
				-- Transparent background if no backgroundColor specified (good for circular images like badges)
				imageLabel.BackgroundTransparency = if imageSpec.backgroundColor then 0 else 1
				imageLabel.BorderSizePixel = 0
				imageLabel.ScaleType = imageSpec.scaleType or Enum.ScaleType.Fit
				if imageSpec.imageId then
					imageLabel.Image = string.format("rbxassetid://%d", imageSpec.imageId)
				else
					imageLabel.Image = ""
				end
			end
			imageLabel.Name = string.format("%04d_%s", tileSpec.order, tileSpec.name)
			local useWidth = tileSpec.width or UDim.new(1, 0)
			imageLabel.Size = UDim2.new(useWidth.Scale, useWidth.Offset, 1, 0)
			if tileSpec.tooltipText ~= nil and tileSpec.tooltipText ~= "" then
				toolTip.setupToolTip(imageLabel, tileSpec.tooltipText, toolTip.enum.toolTipSize.NormalText, nil, nil, nil, nil, tileSpec.tooltipStyle)
			end
			table.insert(items, imageLabel)
			tileReferences[tileSpec.name] = imageLabel
		elseif tileSpec.spec.type == "scrollingFrameTileSpec" then
			local scrollingFrameFrame = createScrollingFrameImpl(tileSpec.spec)
			scrollingFrameFrame.Name = string.format("%04d_%s", tileSpec.order, tileSpec.name)
			local useWidth = tileSpec.width or UDim.new(1, 0)
			scrollingFrameFrame.Size = UDim2.new(useWidth.Scale, useWidth.Offset, 1, 0)
			table.insert(items, scrollingFrameFrame)
			tileReferences[tileSpec.name] = scrollingFrameFrame
		elseif tileSpec.spec.type == "rowTile" then
			local fakeRowSpec: wt.rowSpec = {
				type = "rowTile",
				name = tileSpec.name,
				order = tileSpec.order,
				tileSpecs = tileSpec.spec.tileSpecs,
				height = UDim.new(1, 0),
			}

			local theRow: Frame
			local _nestedTiles: { [string]: GuiObject }
			theRow, _nestedTiles = createRowImpl(fakeRowSpec)
			theRow.Name = string.format("%04d_%s", tileSpec.order, tileSpec.name)
			local useWidth: UDim = tileSpec.width or UDim.new(1, 0)
			theRow.Size = UDim2.new(useWidth.Scale, useWidth.Offset, 1, 0)
			table.insert(items, theRow)
			-- For rowTile, store the row frame itself
			tileReferences[tileSpec.name] = theRow
		elseif tileSpec.spec.type == "lasted" then
			local lastedSpec = tileSpec.spec :: wt.lastedTileSpec
			local lastedFrame = module.CreateLastedTile(lastedSpec)
			lastedFrame.Name = string.format("%04d_%s", tileSpec.order, tileSpec.name)
			local useWidth: UDim = tileSpec.width or UDim.new(1, 0)
			lastedFrame.Size = UDim2.new(useWidth.Scale, useWidth.Offset, 1, 0)
			table.insert(items, lastedFrame)
			tileReferences[tileSpec.name] = lastedFrame
		elseif tileSpec.spec.type == "improvement" then
			local improvementSpec = tileSpec.spec :: wt.improvementTileSpec
			local improvementFrame = module.CreateImprovementTile(improvementSpec)
			improvementFrame.Name = string.format("%04d_%s", tileSpec.order, tileSpec.name)
			local useWidth: UDim = tileSpec.width or UDim.new(1, 0)
			improvementFrame.Size = UDim2.new(useWidth.Scale, useWidth.Offset, 1, 0)
			table.insert(items, improvementFrame)
			tileReferences[tileSpec.name] = improvementFrame
		elseif tileSpec.spec.type == "digitHighlightedTime" then
			local digitSpec = tileSpec.spec :: wt.digitHighlightedTimeTileSpec
			local digitFrame = module.CreateDigitHighlightedTime(digitSpec)
			digitFrame.Name = string.format("%04d_%s", tileSpec.order, tileSpec.name)
			local useWidth: UDim = tileSpec.width or UDim.new(1, 0)
			digitFrame.Size = UDim2.new(useWidth.Scale, useWidth.Offset, 1, 0)

			if tileSpec.tooltipText ~= nil and tileSpec.tooltipText ~= "" then
				toolTip.setupToolTip(digitFrame, tileSpec.tooltipText, toolTip.enum.toolTipSize.NormalText, nil, nil, nil, nil, tileSpec.tooltipStyle)
			end
			table.insert(items, digitFrame)
			tileReferences[tileSpec.name] = digitFrame
		else
			error("Unknown tile type")
		end

		-- Call onCreate callback if provided, passing the created element
		if tileSpec.onCreate then
			local createdElement = tileReferences[tileSpec.name]
			if createdElement then
				tileSpec.onCreate(createdElement)
			end
		end
	end

	applyProportionalWidths(items)
	-- end

	for _, el in ipairs(items) do
		el.Parent = frame
	end
	return frame, tileReferences
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
	intendedRowsOfScrollingFrameToShow: number?,
	persistenceConfig: windowFunctions.PositionPersistenceConfig?,
	initialPosition: UDim2?,
	dedupeConfig: popupDedupeConfig?
): PopupResult
	if intendedRowsOfScrollingFrameToShow == nil then
		intendedRowsOfScrollingFrameToShow = 11
	end
	destroyExistingPopup(name, dedupeConfig)
	local theSgui: ScreenGui = Instance.new("ScreenGui")
	theSgui.IgnoreGuiInset = true
	theSgui.Name = string.format("%s", name)
	theSgui.Enabled = true
	theSgui:SetAttribute("DedupeKey", (dedupeConfig and dedupeConfig.key) or name)
	-- Each popup gets a fresh incrementing DisplayOrder so most recently opened is on top
	-- Click-to-front will further increment via windowFunctions.BringFrameToFront
	theSgui.DisplayOrder = windowFunctions.GetNextDisplayOrder()

	local res = windowFunctions.SetupFrame(name, draggable, resizable, minimizable, pinnable, desiredSize, nil, persistenceConfig)
	local contentFrame = res.contentFrame
	local outerFrame = res.outerFrame
	outerFrame.BackgroundTransparency = 0
	outerFrame.BorderSizePixel = frameBorderSizePixel
	outerFrame.BorderMode = globalBorderMode
	outerFrame.Parent = theSgui

	addLayout(contentFrame, Enum.FillDirection.Vertical)
	-- Center the outerFrame vertically without modifying AnchorPoint

	local searchEnabledSpec: wt.scrollingFrameTileSpec? = nil
	local searchTargetRowOrder: number? = nil
	for _, rowSpec in ipairs(guiSpec.rowSpecs) do
		for _, tileSpec in ipairs(rowSpec.tileSpecs) do
			local found = findFirstSearchEnabledScrollingFrameSpecInTileSpec(tileSpec)
			if found then
				if searchEnabledSpec then
					annotater.Error(string.format("CreatePopup('%s') found multiple search-enabled scrolling frames; using first '%s', ignoring '%s'", name, searchEnabledSpec.name, found.name))
				else
					searchEnabledSpec = found
					searchTargetRowOrder = rowSpec.order
				end
			end
		end
	end

	local rowFrames: { Frame } = {}
	local builtContent: { [string]: Frame } = {}
	local shallowClonedRowSpecs: { wt.rowSpec } = {}
	-- Store original names before order modification for builtContent lookup
	local originalRowNames: { [wt.rowSpec]: string } = {}
	for _, rowSpec in ipairs(guiSpec.rowSpecs) do
		local cloned = cloneRowSpecShallow(rowSpec)
		originalRowNames[cloned] = rowSpec.name
		table.insert(shallowClonedRowSpecs, cloned)
	end
	table.sort(shallowClonedRowSpecs, function(a: wt.rowSpec, b: wt.rowSpec)
		return a.order < b.order
	end)

	local insertSearchRowOrder: number? = nil
	if searchEnabledSpec and searchTargetRowOrder then
		local insertOrder: number = searchTargetRowOrder
		insertSearchRowOrder = insertOrder
		for _, rowSpec in ipairs(shallowClonedRowSpecs) do
			if rowSpec.order >= insertOrder then
				rowSpec.order += 1
			end
		end
	end

	local insertedSearch = false
	local createdSearchRowFrame: Frame? = nil
	for _, rowSpec in ipairs(shallowClonedRowSpecs) do
		if insertSearchRowOrder and not insertedSearch and rowSpec.order == insertSearchRowOrder + 1 then
			if searchEnabledSpec and searchEnabledSpec.searchConfig then
				local searchRowFrame = createSearchChromeRow(insertSearchRowOrder, searchEnabledSpec.searchConfig, searchEnabledSpec.name)
				createdSearchRowFrame = searchRowFrame
				table.insert(rowFrames, searchRowFrame)
				insertedSearch = true
			end
		end

		local rowFrame = createRowImpl(rowSpec)

		rowFrame.Size = UDim2.new(1, 0, rowSpec.height.Scale, rowSpec.height.Offset)
		table.insert(rowFrames, rowFrame)

		-- Store reference by original name (before order modification)
		local originalName = originalRowNames[rowSpec]
		if originalName then
			builtContent[originalName] = rowFrame
		end
	end

	-- Apply proportional sizes after all rows are created
	applyProportionalHeights(rowFrames)

	for _, rowFrame in ipairs(rowFrames) do
		rowFrame.Parent = contentFrame
	end

	if createdSearchRowFrame and searchEnabledSpec and searchEnabledSpec.searchConfig then
		wireSearchChromeRow(createdSearchRowFrame, searchEnabledSpec.searchConfig, outerFrame)
	end

	--okay so i'm thinking, this might work, but OTOH maybe it'd be better to specify it in the actual rowSpec for the scorlling frame.
	-- because he knows his own data counts? but
	-- local function calculateTotalHeight()
	-- 	local minVisibleRows = 1
	-- 	local maxVisibleRows = intendedRowsOfScrollingFrameToShow
	-- 	local totalHeight = 0
	-- 	local scrollingFrameHeight = 0

	-- 	for _, rowSpec in ipairs(guiSpec.rowSpecs) do
	-- 		for _, tileSpec in ipairs(rowSpec.tileSpecs) do
	-- 			if tileSpec.spec.type == "scrollingFrameTileSpec" then
	-- 				local scrollingFrameSpec = tileSpec.spec :: scrollingFrameTileSpec
	-- 				local dataRowCount = #scrollingFrameSpec.dataRows + 1 -- plusone for header.
	-- 				local visibleRows = math.min(math.max(minVisibleRows, dataRowCount), maxVisibleRows)
	-- 				scrollingFrameHeight = visibleRows * scrollingFrameSpec.rowHeight
	-- 				totalHeight += scrollingFrameHeight + 4
	-- 			end
	-- 		end
	-- 		totalHeight += rowSpec.height.Offset
	-- 	end

	-- 	return totalHeight, scrollingFrameHeight
	-- end

	-- local totalHeight, scrollingFrameHeight = calculateTotalHeight()
	-- local contentHeight = contentFrame.AbsoluteSize.Y

	-- -- Ensure we're showing at least the scrolling frame height or all content if it's less
	-- local finalHeight = math.max(totalHeight, contentHeight, scrollingFrameHeight)
	-- outerFrame.Size = UDim2.new(outerFrame.Size.X.Scale, outerFrame.Size.X.Offset, 0, finalHeight)

	local attribute = Instance.new("BoolValue")
	attribute.Parent = outerFrame.Parent
	attribute.Name = "DismissableWithX"
	attribute.Value = dismissableWithX

	-- Position the popup (only if no saved position was loaded via persistenceConfig)
	if not persistenceConfig or (outerFrame.Position.X.Offset == 0 and outerFrame.Position.Y.Offset == 0 and outerFrame.Position.X.Scale == 0 and outerFrame.Position.Y.Scale == 0) then
		if initialPosition then
			-- Use caller-specified position
			outerFrame.Position = initialPosition
		else
			-- Default: center on screen using scale (not offset) to avoid pixel drift
			local camera = workspace.CurrentCamera
			local screenSize = if camera then camera.ViewportSize else Vector2.new(1920, 1080)

			local frameWidth = desiredSize.X.Scale * screenSize.X + desiredSize.X.Offset
			local frameHeight = desiredSize.Y.Scale * screenSize.Y + desiredSize.Y.Offset

			-- Calculate center position as scale values
			local centeredScaleX = math.max(0, (screenSize.X - frameWidth) / 2) / screenSize.X
			local centeredScaleY = math.max(0, (screenSize.Y - frameHeight) / 2) / screenSize.Y

			outerFrame.Position = UDim2.fromScale(centeredScaleX, centeredScaleY)
		end
	end

	if dismissableByClick then
		local clickAttribute = Instance.new("BoolValue")
		clickAttribute.Parent = outerFrame.Parent
		clickAttribute.Name = "DismissableByClick"
		clickAttribute.Value = true

		-- Create a full-screen transparent backdrop button that closes the popup when clicked.
		-- This is the standard modal pattern: clicking outside the popup dismisses it.
		-- The backdrop is parented to the ScreenGui but positioned behind the outerFrame.
		local backdrop = Instance.new("TextButton")
		backdrop.Name = "DismissBackdrop"
		backdrop.Size = UDim2.new(1, 0, 1, 0)
		backdrop.Position = UDim2.new(0, 0, 0, 0)
		backdrop.BackgroundTransparency = 1
		backdrop.Text = ""
		backdrop.ZIndex = 0 -- Behind the popup content
		backdrop.Parent = theSgui

		backdrop.Activated:Connect(function()
			toolTip.KillFinalTooltip()
			theSgui:Destroy()
		end)

		-- Ensure outerFrame renders above the backdrop
		outerFrame.ZIndex = 1
	end

	return { sgui = theSgui, builtContent = builtContent }
end

-- Expose the forward-declared functions on the module
module.CreateRow = createRowImpl
module.CreateScrollingFrame = createScrollingFrameImpl

-- Expose helper functions for SetupFrame content building
module.findFirstSearchEnabledScrollingFrameSpecInTileSpec = findFirstSearchEnabledScrollingFrameSpecInTileSpec
module.cloneRowSpecShallow = cloneRowSpecShallow
module.createSearchChromeRow = createSearchChromeRow
module.wireSearchChromeRow = wireSearchChromeRow
module.applyProportionalHeights = applyProportionalHeights

_annotate("end")

return module
