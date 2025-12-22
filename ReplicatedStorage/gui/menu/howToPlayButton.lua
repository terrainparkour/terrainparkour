--!strict

-- howToPlayButton.lua :: ReplicatedStorage.gui.menu.howToPlayButton
-- Button for the hamburger menu that opens the "Ways to Play" modal using standard windows system.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local colors = require(game.ReplicatedStorage.util.colors)
local gt = require(game.ReplicatedStorage.gui.guiTypes)
local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)
local wt = require(game.StarterPlayer.StarterPlayerScripts.guis.windowsTypes)

local module = {}

-- Play styles data
local playStyles = {
	{ name = "Explorer", desc = "Wander around randomly discovering new signs" },
	{ name = "Grinder", desc = "Warp back over and over trying to beat a run" },
	{ name = "Sign Takeover", desc = "Click a sign - get the most WRs to/from it to lead" },
	{ name = "Marathoner", desc = "Complete all marathons (enable in settings)" },
	{ name = "Team Racer", desc = "Challenge someone to complete /rr runs together" },
	{ name = "Chainer", desc = "After a run, click sign and do shortest unfinished route" },
	{ name = "Sniper", desc = "Eliminate all other WR holders from a single sign" },
}

local rowHeightPixels = 36

-- Create a row spec for a single play style
local function createPlayStyleRow(style: { name: string, desc: string }, order: number): wt.rowSpec
	return {
		name = "Style_" .. style.name,
		order = order,
		height = UDim.new(0, rowHeightPixels),
		tileSpecs = {
			{
				name = "Name",
				order = 1,
				width = UDim.new(0.25, 0),
				spec = {
					type = "text",
					text = style.name,
					backgroundColor = colors.meColor,
					textColor = colors.black,
					isBold = true,
					isMonospaced = false,
					textXAlignment = Enum.TextXAlignment.Center,
				},
			},
			{
				name = "Description",
				order = 2,
				width = UDim.new(0.75, 0),
				spec = {
					type = "text",
					text = style.desc,
					backgroundColor = colors.defaultGrey,
					textColor = colors.black,
					isBold = false,
					isMonospaced = false,
					textXAlignment = Enum.TextXAlignment.Left,
					leftPadding = 8,
				},
			},
		},
	}
end

-- Create header row for the scrolling frame
local function createHeaderRow(): wt.rowSpec
	return {
		name = "Header",
		order = 1,
		height = UDim.new(0, rowHeightPixels),
		tileSpecs = {
			{
				name = "StyleHeader",
				order = 1,
				width = UDim.new(0.25, 0),
				spec = {
					type = "text",
					text = "Style",
					backgroundColor = colors.blueDone,
					textColor = colors.black,
					isBold = true,
					textXAlignment = Enum.TextXAlignment.Center,
				},
			},
			{
				name = "DescHeader",
				order = 2,
				width = UDim.new(0.75, 0),
				spec = {
					type = "text",
					text = "Description",
					backgroundColor = colors.blueDone,
					textColor = colors.black,
					isBold = true,
					textXAlignment = Enum.TextXAlignment.Center,
				},
			},
		},
	}
end

local function getHowToPlayModal(_localPlayer: Player): ScreenGui
	-- Build data rows from play styles
	local dataRows: { wt.rowSpec } = {}
	for i, style in ipairs(playStyles) do
		table.insert(dataRows, createPlayStyleRow(style, i))
	end

	-- Calculate rows to show based on actual content (max 10)
	local maxRowsToShow = 10
	local actualStyleCount = #dataRows
	local rowsToShow = math.min(actualStyleCount + 1, maxRowsToShow) -- +1 for header
	rowsToShow = math.max(rowsToShow, 2) -- At least header + 1 data row

	local scrollingFrameSpec: wt.scrollingFrameTileSpec = {
		type = "scrollingFrameTileSpec",
		name = "PlayStylesScrollingFrame",
		headerRow = createHeaderRow(),
		dataRows = dataRows,
		stickyRows = {},
		rowHeight = rowHeightPixels,
		howManyRowsToShow = rowsToShow,
	}

	-- Calculate popup height based on actual content
	local titleHeight = 36
	local introHeight = 60 -- Intro text explaining basics
	local closeButtonHeight = 30
	local scrollingFrameHeight = rowsToShow * rowHeightPixels
	local totalHeight = titleHeight + introHeight + scrollingFrameHeight + closeButtonHeight

	-- Title row: standard modal header style
	local titleRowSpec: wt.rowSpec = {
		name = "TitleRow",
		order = 1,
		height = UDim.new(0, titleHeight),
		tileSpecs = {
			{
				name = "Title",
				order = 1,
				width = UDim.new(1, 0),
				spec = {
					type = "text",
					text = "  Ways to Play  ",
					isMonospaced = false,
					isBold = true,
					backgroundColor = colors.signColor,
					textColor = colors.white,
					textXAlignment = Enum.TextXAlignment.Center,
				},
			},
		},
	}

	-- Intro row explaining the basics
	local introRowSpec: wt.rowSpec = {
		name = "IntroRow",
		order = 2,
		height = UDim.new(0, introHeight),
		tileSpecs = {
			{
				name = "IntroText",
				order = 1,
				width = UDim.new(1, 0),
				spec = {
					type = "text",
					text = "Touch red signs to find them. Run between signs to race. Check results, get WRs, earn badges. Game since 2017.",
					backgroundColor = colors.defaultGrey,
					textColor = colors.black,
					isBold = false,
					isMonospaced = false,
					textXAlignment = Enum.TextXAlignment.Center,
				},
			},
		},
	}

	local guiSpec: wt.guiSpec = {
		name = "WaysToPlay",
		rowSpecs = {
			titleRowSpec,
			introRowSpec,
			{
				name = "ScrollingFrameRow",
				order = 3,
				height = UDim.new(scrollingFrameHeight, 0), -- Proportional weight for resizable layout
				tileSpecs = {
					{
						name = "ScrollingFrame",
						order = 1,
						width = UDim.new(1, 0),
						spec = scrollingFrameSpec,
					},
				},
			},
			{
				name = "CloseButtonRow",
				order = 4,
				height = UDim.new(0, closeButtonHeight),
				tileSpecs = { windows.StandardCloseButton },
			},
		},
	}

	local popupResult = windows.CreatePopup(
		guiSpec,
		"WaysToPlayPopup",
		true, -- draggable
		true, -- resizable
		false, -- minimizable
		true, -- pinnable
		true, -- dismissableWithX
		false, -- dismissableByClick - standard modal behavior
		UDim2.new(0.45, 0, 0, totalHeight),
		rowsToShow
	)

	return popupResult.sgui
end

local howToPlayButton: gt.button = {
	name = "Ways to play",
	contentsGetter = getHowToPlayModal,
}

module.howToPlayButton = howToPlayButton

_annotate("end")
return module
