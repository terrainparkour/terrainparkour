--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local colors = require(game.ReplicatedStorage.util.colors)
local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)
local wt = require(game.StarterPlayer.StarterPlayerScripts.guis.windowsTypes)
local module = {}

local function _TestMe()
	local titleRow: wt.rowSpec = {
		name = "Title",
		height = UDim.new(0, 100),
		order = 1,
		tileSpecs = {
			{
				name = "Title",
				order = 1,
				width = UDim.new(1, 0),
				spec = {
					type = "text",
					text = "Title",
					backgroundColor = colors.defaultGrey,
					textColor = colors.meColor,
					isMonospaced = false,
					isBold = true,
					textXAlignment = Enum.TextXAlignment.Center,
				},
			},
			{
				name = "Title2",
				order = 2,
				width = UDim.new(0.5, 0),
				spec = {
					type = "text",
					text = "narrower",
					backgroundColor = colors.defaultGrey,
					textColor = colors.white,
					isMonospaced = false,
					isBold = false,
					textXAlignment = Enum.TextXAlignment.Center,
				},
				tooltipText = "tooltip2 on NARROW yo",
			},
			{
				name = "Portrait",
				order = 3,
				width = UDim.new(0, 50),
				spec = {
					type = "portrait",
					userId = 90115385,
					doPopup = true,
					width = UDim.new(0, 50),
					backgroundColor = colors.defaultGrey,
				},
			},
		},
	}

	local lastRow: wt.rowSpec = {
		name = "Last",
		order = 5,
		height = UDim.new(0, 30),
		tileSpecs = { windows.StandardCloseButton },
		horizontalAlignment = Enum.HorizontalAlignment.Right,
	}

	local dataRow: wt.rowSpec = {
		name = "Data",
		order = 2,
		height = UDim.new(2.5, 0),
		tileSpecs = {
			{
				name = "Text",
				order = 1,
				width = UDim.new(1, 0),
				spec = {
					type = "text",
					text = "0.3303s",
					backgroundColor = colors.meColor,
					textColor = colors.black,
					isMonospaced = true,
					isBold = false,
					textXAlignment = Enum.TextXAlignment.Right,
				},
			},
			{
				name = "Portrait",
				order = 2,
				width = UDim.new(0, 50),
				spec = {
					type = "portrait",
					userId = 90115385,
					backgroundColor = colors.blueDone,
					doPopup = true,
					width = UDim.new(0, 50),
				},
			},
		},
	}

	local imageRow: wt.rowSpec = {
		name = "images",
		order = 3,
		height = UDim.new(0, 60),
		tileSpecs = {
			{
				name = "Portrait",
				order = 1,
				width = UDim.new(0, 50),

				spec = {
					type = "portrait",
					userId = 505050,
					backgroundColor = colors.defaultGrey,
					doPopup = true,
					width = UDim.new(0, 100),
				},
			},
			{
				name = "Portrait",
				order = 2,
				width = UDim.new(0, 50),

				spec = {
					type = "portrait",
					userId = 1,
					backgroundColor = colors.defaultGrey,
					doPopup = false,
					width = UDim.new(0, 50),
					tooltipText = "tooltip",
				},
			},
			{
				name = "Portrait",
				order = 3,
				width = UDim.new(0, 50),

				spec = {
					type = "portrait",
					userId = 90115385,
					backgroundColor = colors.defaultGrey,
					doPopup = true,
					width = UDim.new(0, 50),
				},
			},
			{
				name = "Portrait",
				order = 4,
				width = UDim.new(0, 50),

				spec = {
					type = "portrait",
					backgroundColor = colors.defaultGrey,
					userId = 261,
					doPopup = false,
					width = UDim.new(0.5, 0),
				},
			},
		},
	}

	local rowSpecs: { wt.rowSpec } = { titleRow, dataRow, imageRow, lastRow }
	local guiSpec: wt.guiSpec = {
		name = "Test",
		rowSpecs = rowSpecs,
	}
	local popup = windows.CreatePopup(guiSpec, "Test", true, true, true, true, true, false, UDim2.new(0, 400, 0, 300))
	popup.Parent = playerGui
end

module.Init = function()
	_TestMe()
end

_annotate("end")

return module
