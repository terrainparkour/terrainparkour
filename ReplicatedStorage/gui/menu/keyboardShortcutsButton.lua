--!strict

-- keyboardShortcutsButton.lua :: ReplicatedStorage.gui.menu.keyboardShortcutsButton
-- Button for the hamburger menu that opens the keyboard shortcuts modal using standard windows system.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local colors = require(game.ReplicatedStorage.util.colors)
local gt = require(game.ReplicatedStorage.gui.guiTypes)
local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)
local wt = require(game.StarterPlayer.StarterPlayerScripts.guis.windowsTypes)

local module = {}

-- Keyboard shortcuts data
local shortcuts = {
	{ key = "1", desc = "Warp to last completed run start" },
	{ key = "2", desc = "Warp to last sign you started a race from" },
	{ key = "r", desc = "Same as 2" },
	{ key = "h", desc = "Remove sign highlights" },
	{ key = "z", desc = "Cancel current race" },
	{ key = "x", desc = "Close popups and hide chat" },
	{ key = "Tab", desc = "Toggle UI (chat, leaderboard, but not widgets)" },
	{ key = "/", desc = "Open chat with command prefix" },
	{ key = "k", desc = "Show this help screen" },
}

local rowHeightPixels = 36

-- Create a row spec for a single shortcut
local function createShortcutRow(shortcut: { key: string, desc: string }, order: number): wt.rowSpec
	return {
		name = "Shortcut_" .. shortcut.key,
		order = order,
		height = UDim.new(0, rowHeightPixels),
		tileSpecs = {
			{
				name = "Key",
				order = 1,
				width = UDim.new(0.15, 0),
				spec = {
					type = "text",
					text = shortcut.key,
					backgroundColor = colors.meColor,
					textColor = colors.black,
					isBold = true,
					isMonospaced = true,
					textXAlignment = Enum.TextXAlignment.Center,
				},
			},
			{
				name = "Description",
				order = 2,
				width = UDim.new(0.85, 0),
				spec = {
					type = "text",
					text = shortcut.desc,
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
				name = "KeyHeader",
				order = 1,
				width = UDim.new(0.15, 0),
				spec = {
					type = "text",
					text = "Key",
					backgroundColor = colors.blueDone,
					textColor = colors.black,
					isBold = true,
					textXAlignment = Enum.TextXAlignment.Center,
				},
			},
			{
				name = "DescHeader",
				order = 2,
				width = UDim.new(0.85, 0),
				spec = {
					type = "text",
					text = "Action",
					backgroundColor = colors.blueDone,
					textColor = colors.black,
					isBold = true,
					textXAlignment = Enum.TextXAlignment.Center,
				},
			},
		},
	}
end

local function getKeyboardShortcutsModal(_localPlayer: Player): ScreenGui
	-- Build data rows from shortcuts
	local dataRows: { wt.rowSpec } = {}
	for i, shortcut in ipairs(shortcuts) do
		table.insert(dataRows, createShortcutRow(shortcut, i))
	end

	-- Calculate rows to show based on actual content (max 10)
	local maxRowsToShow = 10
	local actualShortcutCount = #dataRows
	local rowsToShow = math.min(actualShortcutCount + 1, maxRowsToShow) -- +1 for header
	rowsToShow = math.max(rowsToShow, 2) -- At least header + 1 data row

	local scrollingFrameSpec: wt.scrollingFrameTileSpec = {
		type = "scrollingFrameTileSpec",
		name = "ShortcutsScrollingFrame",
		headerRow = createHeaderRow(),
		dataRows = dataRows,
		stickyRows = {},
		rowHeight = rowHeightPixels,
		howManyRowsToShow = rowsToShow,
	}

	-- Calculate popup height based on actual content
	local titleHeight = 36
	local closeButtonHeight = 30
	local scrollingFrameHeight = rowsToShow * rowHeightPixels
	local totalHeight = titleHeight + scrollingFrameHeight + closeButtonHeight

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
					text = "  Keyboard Shortcuts  ",
					isMonospaced = false,
					isBold = true,
					backgroundColor = colors.signColor,
					textColor = colors.white,
					textXAlignment = Enum.TextXAlignment.Center,
				},
			},
		},
	}

	local guiSpec: wt.guiSpec = {
		name = "KeyboardShortcuts",
		rowSpecs = {
			titleRowSpec,
			{
				name = "ScrollingFrameRow",
				order = 2,
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
				order = 3,
				height = UDim.new(0, closeButtonHeight),
				tileSpecs = { windows.StandardCloseButton },
			},
		},
	}

	local popupResult = windows.CreatePopup(
		guiSpec,
		"KeyboardShortcutsPopup",
		true, -- draggable
		true, -- resizable
		false, -- minimizable
		true, -- pinnable
		true, -- dismissableWithX
		false, -- dismissableByClick - standard modal behavior
		UDim2.new(0.4, 0, 0, totalHeight),
		rowsToShow
	)

	return popupResult.sgui
end

local keyboardShortcutsButton: gt.button = {
	name = "Keyboard Shortcuts",
	contentsGetter = getKeyboardShortcutsModal,
}

module.keyboardShortcutsButton = keyboardShortcutsButton

_annotate("end")
return module
