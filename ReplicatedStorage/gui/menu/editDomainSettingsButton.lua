--!strict

-- generic setting editor for all settings in a DOMAIN.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local settings = require(game.ReplicatedStorage.settings)
local colors = require(game.ReplicatedStorage.util.colors)
local tt = require(game.ReplicatedStorage.types.gametypes)
local gt = require(game.ReplicatedStorage.gui.guiTypes)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local settingSort = require(game.ReplicatedStorage.settingSort)
local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)
local PlayersService = game:GetService("Players")

local module = {}

local function createSettingRowSpec(setting: tt.userSettingValue, n: number): windows.rowSpec
	local toggleButtonSpec: windows.buttonTileSpec = {
		type = "button",
		text = setting.booleanValue and "Yes" or "No",
		isMonospaced = false,
		isBold = false,
		backgroundColor = setting.booleanValue and colors.greenGo or colors.redStop,
		textColor = colors.black,
		textXAlignment = Enum.TextXAlignment.Center,
		onClick = function(_, theButton: TextButton)
			local newValue = not setting.booleanValue
			setting.booleanValue = newValue
			theButton.Text = newValue and "Yes" or "No"
			theButton.BackgroundColor3 = newValue and colors.greenGo or colors.redStop
			settings.SetSetting(setting)
		end,
	}

	local x: windows.rowSpec = {
		name = string.format("%04d-%s", n, setting.name),
		order = n,
		height = UDim.new(0, 30),
		tileSpecs = {
			{
				name = "SettingName",
				order = 1,
				width = UDim.new(0.7, 0),
				spec = {
					type = "text",
					text = setting.name,
					isMonospaced = false,
					isBold = false,
					backgroundColor = colors.defaultGrey,
					textColor = colors.black,
					textXAlignment = Enum.TextXAlignment.Left,
				},
			},
			{
				name = "ToggleButton",
				order = 2,
				width = UDim.new(0.3, 0),
				spec = toggleButtonSpec,
			},
		},
	}
	return x
end

function module.CreateGenericSettingsEditor(domain: string): windows.guiSpec
	local userSettings: { [string]: tt.userSettingValue } =
		settings.GetSettingByDomainAndKind(domain, settingEnums.settingKinds.BOOLEAN)

	local settingsToDisplay = {}
	for _, setting in pairs(userSettings) do
		table.insert(settingsToDisplay, setting)
	end
	table.sort(settingsToDisplay, settingSort.SettingSort)

	local settingSpecs: { windows.rowSpec } = {}
	for i, setting in ipairs(settingsToDisplay) do
		table.insert(settingSpecs, createSettingRowSpec(setting, i))
	end

	-- Define individual tile specs
	local titleTextSpec: windows.textTileSpec = {
		type = "text",
		text = "Modify your " .. domain .. " Settings",
		isMonospaced = false,
		isBold = true,
		backgroundColor = colors.blueDone,
		textColor = colors.black,
		textXAlignment = Enum.TextXAlignment.Center,
	}

	local nameHeaderSpec: windows.textTileSpec = {
		type = "text",
		text = "Settings",
		isMonospaced = false,
		isBold = true,
		backgroundColor = colors.blueDone,
		textColor = colors.black,
		textXAlignment = Enum.TextXAlignment.Left,
	}

	-- Define scrollingFrame components
	local scrollingFrameHeaderTileSpec: windows.tileSpec = {
		name = "NameHeader",
		order = 1,
		width = UDim.new(1, 0),
		spec = nameHeaderSpec,
	}

	local scrollingFrameHeaderRowSpec: windows.rowSpec = {
		name = "SettingsHeader",
		order = 1,
		tileSpecs = { scrollingFrameHeaderTileSpec },
		height = UDim.new(0, 30),
	}

	local scrollingFrameSpec: windows.scrollingFrameTileSpec = {
		type = "scrollingFrame",
		name = "SettingsScrollingFrame",
		headerRow = scrollingFrameHeaderRowSpec,
		dataRows = settingSpecs,
		rowHeight = 30,
	}

	-- Define row specs
	local titleRowSpec: windows.rowSpec = {
		name = "Title",
		order = 1,
		tileSpecs = {
			{
				name = "TitleText",
				order = 1,
				width = UDim.new(1, 0),
				spec = titleTextSpec,
			},
		},
		height = UDim.new(0, 45),
	}

	local settingsContentRowSpec: windows.rowSpec = {
		name = "SettingsContent",
		order = 2,
		tileSpecs = {
			{
				name = "SettingsScrollingFrame",
				order = 1,
				width = UDim.new(1, 0),
				spec = scrollingFrameSpec,
			},
		},
		height = UDim.new(1, 0),
	}

	-- Assemble the final guiSpec
	local guiSpec: windows.guiSpec = {
		name = domain .. "SettingsEditor",
		rowSpecs = {
			titleRowSpec,
			settingsContentRowSpec,
			{
				name = "CloseButtonRow",
				order = 3,
				height = UDim.new(0, 30),
				tileSpecs = { windows.StandardCloseButton },
				horizontalAlignment = Enum.HorizontalAlignment.Right,
			},
		},
	}

	return guiSpec
end

_annotate("end")
return module
