--!strict

-- menu.lua @ ReplicatedStorage.gui.menu.menu
-- Hamburger menu button and menu list modal using standard windows system.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local colors = require(game.ReplicatedStorage.util.colors)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local gt = require(game.ReplicatedStorage.gui.guiTypes)
local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)
local wt = require(game.StarterPlayer.StarterPlayerScripts.guis.windowsTypes)

local module = {}

local ROW_HEIGHT = 40

module.getHamburger = function(): ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.IgnoreGuiInset = true
	screenGui.Name = "HamburgerMenu"
	local frame = Instance.new("Frame")
	local corner = 32
	frame.Size = UDim2.new(0, corner, 0, corner)
	frame.Name = "hamburgerFrame"
	frame.Parent = screenGui
	frame.Position = UDim2.new(1, -1 * corner, 1, -1 * corner)
	local tb = guiUtil.getTbSimple()
	tb.Name = "button"
	tb.Parent = frame
	tb.Text = "S"
	return screenGui
end

module.getMenuList = function(localPlayer: Player, buttons: { gt.button }, pgui: PlayerGui): ScreenGui
	-- Build button row specs for the scrolling frame
	local buttonRowSpecs: { wt.rowSpec } = {}

	for i, but in ipairs(buttons) do
		-- Capture loop variables for closure
		local buttonName = but.name
		local contentsGetter = but.contentsGetter

		local buttonSpec: wt.buttonTileSpec = {
			type = "button",
			text = buttonName,
			isMonospaced = false,
			isBold = false,
			backgroundColor = colors.defaultGrey,
			hoverBackgroundColor = colors.lightGrey,
			textColor = colors.black,
			textXAlignment = Enum.TextXAlignment.Center,
			onClick = function(_: InputObject, theButton: TextButton)
				-- Find the ScreenGui ancestor and destroy it after opening content
				local screenGui = theButton:FindFirstAncestorOfClass("ScreenGui")
				task.spawn(function()
					local content = contentsGetter(localPlayer)
					content.Parent = pgui
					if screenGui then
						screenGui:Destroy()
					end
				end)
			end,
		}

		local rowSpec: wt.rowSpec = {
			name = string.format("Button%02d_%s", i, buttonName),
			order = i,
			height = UDim.new(0, ROW_HEIGHT),
			tileSpecs = {
				{
					name = "Button",
					order = 1,
					width = UDim.new(1, 0),
					spec = buttonSpec,
				},
			},
		}
		table.insert(buttonRowSpecs, rowSpec)
	end

	-- Header row for the scrolling frame - shows "Menu" title
	local headerRowSpec: wt.rowSpec = {
		name = "Header",
		order = 0,
		height = UDim.new(0, ROW_HEIGHT),
		tileSpecs = {
			{
				name = "TitleText",
				order = 1,
				width = UDim.new(1, 0),
				spec = {
					type = "text",
					text = "Menu",
					isMonospaced = false,
					isBold = true,
					backgroundColor = colors.blueDone,
					textColor = colors.black,
					textXAlignment = Enum.TextXAlignment.Center,
				} :: wt.textTileSpec,
			},
		},
	}

	-- Calculate how many rows to show (cap at 10 for reasonable screen usage)
	local maxRowsToShow = 10
	local actualRowsToShow = math.min(#buttons + 1, maxRowsToShow) -- +1 for header

	-- Scrolling frame spec for the button list
	local scrollingFrameSpec: wt.scrollingFrameTileSpec = {
		type = "scrollingFrameTileSpec",
		name = "MenuButtonsScrollingFrame",
		headerRow = headerRowSpec,
		dataRows = buttonRowSpecs,
		stickyRows = {},
		rowHeight = ROW_HEIGHT,
		howManyRowsToShow = actualRowsToShow,
	}

	-- Content row with scrolling frame (includes header inside)
	local contentRowSpec: wt.rowSpec = {
		name = "Content",
		order = 1,
		height = UDim.new(1, 0), -- Fill remaining space
		tileSpecs = {
			{
				name = "ScrollingFrame",
				order = 1,
				width = UDim.new(1, 0),
				spec = scrollingFrameSpec,
			},
		},
	}

	-- Assemble the guiSpec with close button at bottom
	local guiSpec: wt.guiSpec = {
		name = "MenuListModal",
		rowSpecs = {
			contentRowSpec,
			{
				name = "CloseButtonRow",
				order = 2,
				height = UDim.new(0, ROW_HEIGHT),
				tileSpecs = { windows.StandardCloseButton },
			},
		},
	}

	-- Calculate total height based on content
	local scrollingFrameHeight = actualRowsToShow * ROW_HEIGHT
	local totalHeight = scrollingFrameHeight + ROW_HEIGHT -- content (includes header) + close
	local desiredSize = UDim2.new(0.4, 0, 0, totalHeight)

	local screenGuiResult = windows.CreatePopup(
		guiSpec,
		"MenuList",
		true, -- draggable
		false, -- resizable
		false, -- minimizable
		false, -- pinnable
		true, -- dismissableWithX
		false, -- dismissableByClick
		desiredSize
	)

	return screenGuiResult.sgui
end

_annotate("end")
return module
