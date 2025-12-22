--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local colors = require(game.ReplicatedStorage.util.colors)
local tt = require(game.ReplicatedStorage.types.gametypes)
local gt = require(game.ReplicatedStorage.gui.guiTypes)

local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local settingSort = require(game.ReplicatedStorage.settingSort)
local settings = require(game.ReplicatedStorage.settings)
local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)
local wt = require(game.StarterPlayer.StarterPlayerScripts.guis.windowsTypes)

local module = {}

local function createSurveyRow(setting: tt.userSettingValue, order: number): wt.rowSpec
	local tiles: { wt.tileSpec } = {}

	-- Domain (Type)
	table.insert(tiles, {
		name = "Type",
		order = 1,
		width = UDim.new(0.2, 0),
		spec = {
			type = "text",
			text = setting.domain,
			backgroundColor = colors.defaultGrey,
			textColor = colors.black,
			textXAlignment = Enum.TextXAlignment.Center,
		},
	})

	-- Setting Name
	table.insert(tiles, {
		name = "Name",
		order = 2,
		width = UDim.new(0.5, 0),
		spec = {
			type = "text",
			text = setting.name .. "?",
			backgroundColor = colors.defaultGrey,
			textColor = colors.black,
			textXAlignment = Enum.TextXAlignment.Left,
			leftPadding = 8,
		},
	})

	-- Value (Buttons)
	table.insert(tiles, {
		name = "Value",
		order = 3,
		width = UDim.new(0.3, 0),
		spec = {
			type = "rowTile",
			name = "ValueButtons",
			tileSpecs = {
				{
					name = "No",
					order = 1,
					width = UDim.new(0.33, 0),
					spec = {
						type = "button",
						text = "No",
						backgroundColor = (setting.booleanValue == false) and colors.redStop or colors.defaultGrey,
						textColor = colors.black,
						onClick = function(_, btn)
							local newValue: boolean?
							if setting.booleanValue == false then
								newValue = nil
							else
								newValue = false
							end
							setting.booleanValue = newValue
							settings.SetSetting(setting)
							
							local rowFrame = btn:FindFirstAncestor("ValueButtons")
							if rowFrame and rowFrame:IsA("Frame") then
								local noBtn = rowFrame:FindFirstChild("0001_No") 
								local unsetBtn = rowFrame:FindFirstChild("0002_Unset") 
								local yesBtn = rowFrame:FindFirstChild("0003_Yes")
								
								if noBtn and unsetBtn and yesBtn then
									local noTextBtn = noBtn :: TextButton
									local unsetTextBtn = unsetBtn :: TextButton
									local yesTextBtn = yesBtn :: TextButton
									
									if newValue == false then
										noTextBtn.BackgroundColor3 = colors.redStop
										yesTextBtn.BackgroundColor3 = colors.defaultGrey
										unsetTextBtn.BackgroundColor3 = colors.defaultGrey
									elseif newValue == true then
										noTextBtn.BackgroundColor3 = colors.defaultGrey
										yesTextBtn.BackgroundColor3 = colors.greenGo
										unsetTextBtn.BackgroundColor3 = colors.defaultGrey
									else
										noTextBtn.BackgroundColor3 = colors.defaultGrey
										yesTextBtn.BackgroundColor3 = colors.defaultGrey
										unsetTextBtn.BackgroundColor3 = colors.defaultGrey
									end
								end
							end
						end
					}
				},
				{
					name = "Unset",
					order = 2,
					width = UDim.new(0.33, 0),
					spec = {
						type = "button",
						text = "-",
						backgroundColor = (setting.booleanValue == nil) and colors.defaultGrey or colors.defaultGrey,
						textColor = colors.black,
						onClick = function(_, btn)
							local newValue = nil
							setting.booleanValue = newValue
							settings.SetSetting(setting)
							
							local rowFrame = btn:FindFirstAncestor("ValueButtons")
							if rowFrame and rowFrame:IsA("Frame") then
								local noBtn = rowFrame:FindFirstChild("0001_No") 
								local unsetBtn = rowFrame:FindFirstChild("0002_Unset")
								local yesBtn = rowFrame:FindFirstChild("0003_Yes")
								if noBtn and yesBtn and unsetBtn then
									local noTextBtn = noBtn :: TextButton
									local unsetTextBtn = unsetBtn :: TextButton
									local yesTextBtn = yesBtn :: TextButton

									noTextBtn.BackgroundColor3 = colors.defaultGrey
									yesTextBtn.BackgroundColor3 = colors.defaultGrey
									unsetTextBtn.BackgroundColor3 = colors.defaultGrey
								end
							end
						end
					}
				},
				{
					name = "Yes",
					order = 3,
					width = UDim.new(0.33, 0),
					spec = {
						type = "button",
						text = "Yes",
						backgroundColor = (setting.booleanValue == true) and colors.greenGo or colors.defaultGrey,
						textColor = colors.black,
						onClick = function(_, btn)
							local newValue: boolean?
							if setting.booleanValue == true then
								newValue = nil
							else
								newValue = true
							end
							setting.booleanValue = newValue
							settings.SetSetting(setting)
							
							local rowFrame = btn:FindFirstAncestor("ValueButtons")
							if rowFrame and rowFrame:IsA("Frame") then
								local noBtn = rowFrame:FindFirstChild("0001_No") 
								local unsetBtn = rowFrame:FindFirstChild("0002_Unset")
								local yesBtn = rowFrame:FindFirstChild("0003_Yes")
								if noBtn and yesBtn and unsetBtn then
									local noTextBtn = noBtn :: TextButton
									local unsetTextBtn = unsetBtn :: TextButton
									local yesTextBtn = yesBtn :: TextButton

									if newValue == true then
										yesTextBtn.BackgroundColor3 = colors.greenGo
										noTextBtn.BackgroundColor3 = colors.defaultGrey
										unsetTextBtn.BackgroundColor3 = colors.defaultGrey
									else
										yesTextBtn.BackgroundColor3 = colors.defaultGrey
										noTextBtn.BackgroundColor3 = colors.defaultGrey
										unsetTextBtn.BackgroundColor3 = colors.defaultGrey
									end
								end
							end
						end
					}
				}
			}
		}
	})

	return {
		name = "Setting_" .. setting.name,
		order = order,
		height = UDim.new(0, 30),
		tileSpecs = tiles,
	}
end

local function getSurveyModal(localPlayer: Player): ScreenGui
	local surveyData = settings.GetSettingByDomain(settingEnums.settingDomains.SURVEYS)
	
	local settingsHolder = {}
	for _, setting in pairs(surveyData) do
		table.insert(settingsHolder, setting)
	end
	table.sort(settingsHolder, settingSort.SettingSort)

	local headerRow: wt.rowSpec = {
		name = "Header",
		order = 1,
		height = UDim.new(0, 40),
		tileSpecs = {
			{
				name = "Type",
				order = 1,
				width = UDim.new(0.2, 0),
				spec = {
					type = "text",
					text = "Type",
					backgroundColor = colors.blueDone,
					textColor = colors.black,
					isBold = true,
					textXAlignment = Enum.TextXAlignment.Center
				}
			},
			{
				name = "Name",
				order = 2,
				width = UDim.new(0.5, 0),
				spec = {
					type = "text",
					text = "Name",
					backgroundColor = colors.blueDone,
					textColor = colors.black,
					isBold = true,
					textXAlignment = Enum.TextXAlignment.Center
				}
			},
			{
				name = "Value",
				order = 3,
				width = UDim.new(0.3, 0),
				spec = {
					type = "text",
					text = "Value",
					backgroundColor = colors.blueDone,
					textColor = colors.black,
					isBold = true,
					textXAlignment = Enum.TextXAlignment.Center
				}
			}
		}
	}

	local dataRows = {}
	local ii = 0
	for _, setting in pairs(settingsHolder) do
		if setting.domain == settingEnums.settingDomains.SURVEYS then
			ii += 1
			table.insert(dataRows, createSurveyRow(setting, ii))
		end
	end

	-- Calculate rows to show based on actual content (max 10)
	local rowHeight = 30
	local maxRowsToShow = 10
	local actualSurveyCount = #dataRows
	local rowsToShow = math.min(actualSurveyCount + 1, maxRowsToShow) -- +1 for header
	rowsToShow = math.max(rowsToShow, 2) -- At least header + 1 data row

	local scrollingFrameSpec: wt.scrollingFrameTileSpec = {
		type = "scrollingFrameTileSpec",
		name = "SurveyScrollingFrame",
		headerRow = headerRow,
		dataRows = dataRows,
		stickyRows = {},
		rowHeight = rowHeight,
		howManyRowsToShow = rowsToShow,
	}

	-- Calculate popup height based on actual content
	local titleHeight = 36
	local noticeHeight = 24
	local closeButtonHeight = 30
	local scrollingFrameHeight = rowsToShow * rowHeight
	local totalHeight = titleHeight + noticeHeight + scrollingFrameHeight + closeButtonHeight

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
					text = "  Surveys  ",
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
		name = "SurveySettings",
		rowSpecs = {
			titleRowSpec,
			{
				name = "PublicNotice",
				order = 2,
				height = UDim.new(0, noticeHeight),
				tileSpecs = {
					{
						name = "Notice",
						order = 1,
						width = UDim.new(1, 0),
						spec = {
							type = "text",
							text = "Your answers are public.",
							backgroundColor = colors.defaultGrey,
							textColor = colors.black,
							textXAlignment = Enum.TextXAlignment.Center,
						},
					},
				},
			},
			{
				name = "Content",
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
				name = "Close",
				order = 4,
				height = UDim.new(0, closeButtonHeight),
				tileSpecs = { windows.StandardCloseButton },
			},
		},
	}

	local result = windows.CreatePopup(
		guiSpec,
		"SurveySettingsPopup",
		true, -- draggable
		true, -- resizable
		false, -- minimizable
		true, -- pinnable
		true, -- dismissableWithX
		false, -- dismissableByClick - standard modal behavior: only close button closes
		UDim2.new(0.5, 0, 0, totalHeight),
		rowsToShow
	)
	return result.sgui
end

local surveySettingsButton: gt.button = {
	name = "Surveys",
	contentsGetter = getSurveyModal,
}

module.surveySettingsButton = surveySettingsButton

_annotate("end")
return module
