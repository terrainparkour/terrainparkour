--!strict

-- this is the companion to the serverside command: WRProgressionCommand!
-- there is a unified rpc name which clients can send as well as server. the next version is runResults
-- let's think about whta this file really is. It's a drawer for a UI with the following elements:

local tt = require(game.ReplicatedStorage.types.gametypes)
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local colors = require(game.ReplicatedStorage.util.colors)
local warper = require(game.StarterPlayer.StarterPlayerScripts.warper)
local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local toolTip = require(game.ReplicatedStorage.gui.toolTip)

-- Add this near the top of the file, with the other imports
local remotes = require(game.ReplicatedStorage.util.remotes)

local settings = require(game.ReplicatedStorage.settings)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local PlayersService = game:GetService("Players")
local localPlayer = PlayersService.LocalPlayer
local GenericClientUIFunction = remotes.getRemoteFunction("GenericClientUIFunction")
local wt = require(game.StarterPlayer.StarterPlayerScripts.guis.windowsTypes)

--------------------- GLOBALS -------------------
local rowHeightPixels = 30 -- Adjust this value as needed

--------------------- DESCRIPTORS --------------------------------

local bestTimeHeaderTile: wt.tileSpec = {
	name = "BestTime",
	order = 1,
	width = UDim.new(2, 0),
	spec = {
		type = "text",
		text = "Best Time",
		isMonospaced = false,
		isBold = false,
		backgroundColor = colors.WRProgressionColor,
		textColor = colors.black,
		textXAlignment = Enum.TextXAlignment.Center,
	},
}

local improvementHeaderTile: wt.tileSpec = {
	name = "Improvement",
	order = 2,
	width = UDim.new(1, 0),
	spec = {
		type = "text",
		text = "Improvement",
		isMonospaced = false,
		isBold = false,
		backgroundColor = colors.WRProgressionColor,
		textColor = colors.black,
		textXAlignment = Enum.TextXAlignment.Center,
	},
}

local usernameHeaderTile: wt.tileSpec = {
	name = "Username",
	order = 3,
	width = UDim.new(2, 0),
	spec = {
		type = "text",
		text = "Username",
		isMonospaced = false,
		isBold = false,
		backgroundColor = colors.WRProgressionColor,
		textColor = colors.black,
		textXAlignment = Enum.TextXAlignment.Center,
	},
}

local portraitHeaderTile: wt.tileSpec = {
	name = "Portrait",
	order = 4,
	width = UDim.new(0, rowHeightPixels),
	spec = {
		type = "portrait",
		userId = 123456,
		doPopup = true,
		width = UDim.new(0, rowHeightPixels),
		backgroundColor = colors.WRProgressionColor,
	},
}

local lastedHeaderTile: wt.tileSpec = {
	name = "Lasted",
	order = 5,
	width = UDim.new(2, 0),
	spec = {
		type = "text",
		text = "Lasted",
		isMonospaced = false,
		isBold = false,
		backgroundColor = colors.WRProgressionColor,
		textColor = colors.black,
		textXAlignment = Enum.TextXAlignment.Center,
	},
}

local dateSetHeaderTile: wt.tileSpec = {
	name = "Date Set",
	order = 6,
	width = UDim.new(2, 0),
	spec = {
		type = "text",
		text = "Date Set",
		isMonospaced = false,
		isBold = false,
		backgroundColor = colors.WRProgressionColor,
		textColor = colors.black,
		textXAlignment = Enum.TextXAlignment.Center,
	},
}

local wrProgressionDataTableHeaderTileSpec: { wt.tileSpec } = {
	bestTimeHeaderTile,
	improvementHeaderTile,
	usernameHeaderTile,
	portraitHeaderTile,
	lastedHeaderTile,
	dateSetHeaderTile,
}

local function requestWRProgression(startSignId: number, endSignId: number)
	local success = GenericClientUIFunction:InvokeServer({
		eventKind = "wrProgressionRequest",
		data = {
			startSignId = startSignId,
			endSignId = endSignId,
		},
	})

	if not success then
		warn("Failed to request WR progression")
	end
end

local function requestRunResults(startSignId: number, endSignId: number)
	local success = GenericClientUIFunction:InvokeServer({
		eventKind = "runResultsRequest",
		data = {
			userId = localPlayer.UserId,
			startSignId = startSignId,
			endSignId = endSignId,
		},
	})

	if not success then
		warn("Failed to request RunResult")
	end
end

local function createWarpButton(data: tt.WRProgressionEndpointResponse): wt.tileSpec
	local buttonSpec: wt.buttonTileSpec = {
		type = "button",
		text = string.format("Warp to %s", data.raceHistoryData.raceStartName),
		backgroundColor = colors.warpColor,
		textColor = colors.black,
		isMonospaced = false,
		isBold = false,
		textXAlignment = Enum.TextXAlignment.Center,
		onClick = function(_: InputObject, _2: TextButton)
			warper.WarpToSignId(data.raceHistoryData.raceStartSignId, data.raceHistoryData.raceEndSignId)
		end,
	}

	local res: wt.tileSpec = {
		name = "Warp",
		order = 3,
		width = UDim.new(1, 0),
		spec = buttonSpec,
	}
	return res
end

local function getCommandRow(data: tt.WRProgressionEndpointResponse): wt.rowSpec
	local tileSpecs: { wt.tileSpec } = {}

	local runResultsTile: wt.tileSpec = {
		name = "RunResults",
		order = 1,
		width = UDim.new(1, 0),
		spec = {
			type = "button",
			text = "Top 10",
			isMonospaced = false,
			isBold = false,
			backgroundColor = colors.WRProgressionColor,
			textColor = colors.black,
			textXAlignment = Enum.TextXAlignment.Center,
			onClick = function()
				local startSignId = tpUtil.signName2SignId(data.raceHistoryData.raceStartName)
				local endSignId = tpUtil.signName2SignId(data.raceHistoryData.raceEndName)
				requestRunResults(startSignId, endSignId)
			end,
		},
	}
	local reverseSpec: wt.buttonTileSpec = {
		type = "button",
		text = "Reverse Race",
		isMonospaced = false,
		isBold = false,
		backgroundColor = colors.WRProgressionColor,
		textColor = colors.black,
		textXAlignment = Enum.TextXAlignment.Center,
		onClick = function(_: InputObject, theButton: TextButton)
			local screenGui = theButton:FindFirstAncestorOfClass("ScreenGui")
			if screenGui then
				toolTip.KillFinalTooltip()
				screenGui:Destroy()
			else
				warn("Could not find ScreenGui to close")
			end

			local startSignId = tpUtil.signName2SignId(data.raceHistoryData.raceEndName)
			local endSignId = tpUtil.signName2SignId(data.raceHistoryData.raceStartName)
			requestWRProgression(startSignId, endSignId)
		end,
	}

	local reverseRaceTile: wt.tileSpec = {
		name = "ReverseRace",
		order = 2,
		width = UDim.new(1, 0),
		spec = reverseSpec,
	}

	table.insert(tileSpecs, runResultsTile)
	table.insert(tileSpecs, reverseRaceTile)
	table.insert(tileSpecs, createWarpButton(data))

	return {
		name = "CommandRow",
		order = 2,
		height = UDim.new(0, 40),
		tileSpecs = tileSpecs,
	}
end

local function getDetailRow(
	data: tt.WRProgressionEndpointResponse,
	currentPlayerNames: { [string]: boolean }
): wt.rowSpec
	local detailsTiles: { wt.tileSpec } = {}

	local lengthTile: wt.tileSpec = {
		name = "Length",
		order = 5,
		width = UDim.new(3, 0),
		spec = {
			type = "text",
			text = string.format("Length: %.1fd", data.raceHistoryData.raceLength),
			isMonospaced = false,
			isBold = false,
			backgroundColor = colors.defaultGrey,
			textColor = colors.black,
			textXAlignment = Enum.TextXAlignment.Center,
		},
	}

	local totalRunsTile: wt.tileSpec = {
		name = "TotalRuns",
		order = 6,
		width = UDim.new(2, 0),
		spec = {
			type = "text",
			text = string.format("Total Runs: %d", data.raceHistoryData.raceRunCount),
			isMonospaced = false,
			isBold = false,
			backgroundColor = colors.defaultGrey,
			textColor = colors.black,
			textXAlignment = Enum.TextXAlignment.Center,
		},
	}

	local totalRunnersTile: wt.tileSpec = {
		name = "TotalRunners",
		order = 7,
		width = UDim.new(3, 0),
		spec = {
			type = "text",
			text = string.format("Total Runners: %d", data.raceHistoryData.raceRunnerCount),
			isMonospaced = false,
			isBold = false,
			backgroundColor = colors.defaultGrey,
			textColor = colors.black,
			textXAlignment = Enum.TextXAlignment.Center,
		},
	}

	local yourRunsTile: wt.tileSpec = {
		name = "YourRuns",
		order = 8,
		width = UDim.new(2, 0),
		spec = {
			type = "text",
			text = string.format("Your Runs: %d", data.userRaceInfo.userRunCount),
			isMonospaced = false,
			isBold = false,
			backgroundColor = colors.meColor,
			textColor = colors.black,
			textXAlignment = Enum.TextXAlignment.Center,
		},
	}

	if data.raceHistoryData.firstRunnerUserId and data.raceHistoryData.firstRunnerUsername then
		local firstRunTile: wt.tileSpec = {
			name = "FirstRunTile",
			order = 3,
			width = UDim.new(4, 0),
			spec = {
				type = "text",
				text = string.format("First run: %s", os.date("%Y-%m-%d", data.raceHistoryData.raceCreatedTime)),
				isMonospaced = false,
				isBold = false,
				backgroundColor = colors.defaultGrey,
				textColor = colors.black,
				textXAlignment = Enum.TextXAlignment.Center,
			},
		}

		local firstRunnerTile: wt.tileSpec = {
			name = "FirstRunner",
			order = 4,
			width = UDim.new(4, 0),
			spec = {
				type = "text",
				text = string.format("First Runner: %s", data.raceHistoryData.firstRunnerUsername or "N/A"),
				isMonospaced = false,
				isBold = false,
				backgroundColor = (data.raceHistoryData.firstRunnerUserId == localPlayer.UserId and colors.meColor)
					or (currentPlayerNames[data.raceHistoryData.firstRunnerUsername] and colors.WRProgressionColor)
					or colors.defaultGrey,
				textColor = colors.black,
				textXAlignment = Enum.TextXAlignment.Center,
			},
		}

		local portraitSpec: wt.portraitTileSpec = {
			type = "portrait",
			userId = data.raceHistoryData.firstRunnerUserId,
			doPopup = true,
			width = UDim.new(0, 40),
			backgroundColor = colors.defaultGrey,
		}

		local firstRunnerPortraitTile: wt.tileSpec = {
			name = "FirstRunnerPortrait",
			order = 2,
			spec = portraitSpec,
			width = UDim.new(0, 40),
		}

		table.insert(detailsTiles, firstRunTile)
		table.insert(detailsTiles, firstRunnerTile)
		table.insert(detailsTiles, firstRunnerPortraitTile)
	end
	table.insert(detailsTiles, lengthTile)
	table.insert(detailsTiles, totalRunsTile)
	table.insert(detailsTiles, totalRunnersTile)
	table.insert(detailsTiles, yourRunsTile)

	local detailsRow: wt.rowSpec = {
		name = "DetailsRow",
		order = 2,
		height = UDim.new(0, rowHeightPixels),
		tileSpecs = detailsTiles,
	}
	return detailsRow
end

local function createWRProgressionEntryRow(
	entry: tt.wrProgressionEntry,
	index: number,
	kind: string,
	currentPlayerNames: { [string]: boolean },
	formatString: string
): wt.rowSpec
	local tileSpecs: { wt.tileSpec } = {}

	for _, headerTileSpec in ipairs(wrProgressionDataTableHeaderTileSpec) do
		local tileSpecShell: any = {
			name = headerTileSpec.name,
			order = headerTileSpec.order,
			width = headerTileSpec.width,
		}

		if headerTileSpec.name == "Portrait" then
			local portraitSpec: wt.portraitTileSpec = {
				type = "portrait",
				userId = entry.userId,
				doPopup = true,
				width = headerTileSpec.width,
			}
			tileSpecShell.spec = portraitSpec
		else
			local content = ""
			local backgroundColor = colors.defaultGrey
			local align: Enum.TextXAlignment = Enum.TextXAlignment.Center
			local isMonospaced = false

			if headerTileSpec.name == "BestTime" then
				content = string.format(formatString, entry.runMilliseconds / 1000) .. "s"
				isMonospaced = true
			elseif headerTileSpec.name == "Improvement" then
				content = kind == "theUserSpecial" and ""
					or (entry.improvementMs and (string.format(formatString, entry.improvementMs / 1000) .. "s") or "")
				isMonospaced = true
			elseif headerTileSpec.name == "Username" then
				content = entry.username
				backgroundColor = entry.userId == localPlayer.UserId and colors.meColor
					or (currentPlayerNames[entry.username] and colors.WRProgressionColor or colors.defaultGrey)
			elseif headerTileSpec.name == "Lasted" then
				if kind == "theUserSpecial" then
					content = ""
				else
					local formattedToDisplay, desc = tpUtil.formatDateGap(entry.recordStood)
					content = entry.recordStood and formattedToDisplay or ""
					backgroundColor = index == 1 and colors.greenGo or colors.defaultGrey
					if desc == "seconds" or desc == "minutes" then
						align = Enum.TextXAlignment.Left
					elseif desc == "hours" or desc == "days" then
						align = Enum.TextXAlignment.Center
					else
						align = Enum.TextXAlignment.Right
					end
				end
				isMonospaced = true
			elseif headerTileSpec.name == "Date Set" then
				content = os.date("%Y-%m-%d", entry.runTime)
				isMonospaced = true
			end

			local textSpec: wt.textTileSpec = {
				type = "text",
				text = content,
				isMonospaced = isMonospaced,
				isBold = false,
				backgroundColor = backgroundColor,
				textColor = colors.black,
				textXAlignment = align,
			}
			tileSpecShell.spec = textSpec
		end

		table.insert(tileSpecs, tileSpecShell)
	end

	local rowSpec: wt.rowSpec = {
		name = string.format("WRProgressionEntry_%d", index),
		order = index,
		height = UDim.new(0, rowHeightPixels),
		tileSpecs = tileSpecs,
	}
	return rowSpec
end

local function createLastRow(): wt.rowSpec
	local lastRow: wt.rowSpec = {
		name = "ButtonRow",
		order = 9000, -- Ensure it's at the bottom
		height = UDim.new(0, rowHeightPixels),
		tileSpecs = { windows.CloseButtonLeavingRoom },
		horizontalAlignment = Enum.HorizontalAlignment.Right,
	}
	return lastRow
end

local function createWRProgressionScrollingFrameSpec(
	data: tt.WRProgressionEndpointResponse,
	currentPlayerNames: { [string]: boolean },
	formatString: string
): wt.scrollingFrameTileSpec
	local headerRowSpec: wt.rowSpec = {
		name = "HeaderRow",
		order = 1,
		height = UDim.new(0, rowHeightPixels),
		tileSpecs = wrProgressionDataTableHeaderTileSpec,
	}

	local dataRowSpecs: { wt.rowSpec } = {}
	local weStillNeedToDisplayUsersRun: boolean = false
	if data.userRaceInfo.userFastestRun and data.userRaceInfo.userFastestRun.runId then
		weStillNeedToDisplayUsersRun = true
	end

	for i, entry in ipairs(data.wrProgression) do
		if entry.userId == localPlayer.UserId then
			weStillNeedToDisplayUsersRun = false
		end
		if
			data.userRaceInfo.userFastestRun
			and weStillNeedToDisplayUsersRun
			and entry.runMilliseconds > data.userRaceInfo.userFastestRun.runMilliseconds
		then
			weStillNeedToDisplayUsersRun = false
			local specialOverrideUserBestAttemptEverEntry: tt.wrProgressionEntry = {
				runMilliseconds = data.userRaceInfo.userFastestRun.runMilliseconds,
				username = localPlayer.Name,
				userId = localPlayer.UserId,
				runTime = data.userRaceInfo.userFastestRun.runTime,
				improvementMs = 0,
				recordStood = 0,
				gameVersion = "",
				hasData = true,
				runId = 0,
				raceId = 0,
			}
			local userBestRow = createWRProgressionEntryRow(
				specialOverrideUserBestAttemptEverEntry,
				i,
				"theUserSpecial",
				currentPlayerNames,
				formatString
			)
			userBestRow.height = UDim.new(0, rowHeightPixels) -- Set the height for the user's best run row
			table.insert(dataRowSpecs, userBestRow)
		end
		local wrRow = createWRProgressionEntryRow(entry, i, "normal", currentPlayerNames, formatString)
		wrRow.height = UDim.new(0, rowHeightPixels) -- Set the height for each row
		table.insert(dataRowSpecs, wrRow)
	end

	if weStillNeedToDisplayUsersRun and data.userRaceInfo.userFastestRun then
		local specialOverrideUserBestAttemptEverEntry: tt.wrProgressionEntry = {
			runMilliseconds = data.userRaceInfo.userFastestRun.runMilliseconds,
			username = localPlayer.Name,
			userId = localPlayer.UserId,
			runTime = data.userRaceInfo.userFastestRun.runTime,
			improvementMs = 0,
			recordStood = 0,
			gameVersion = "",
			hasData = true,
			runId = 0,
			raceId = 0,
		}
		local userBestRow = createWRProgressionEntryRow(
			specialOverrideUserBestAttemptEverEntry,
			#dataRowSpecs + 1,
			"theUserSpecial",
			currentPlayerNames,
			formatString
		)
		userBestRow.height = UDim.new(0, rowHeightPixels) -- Set the height for the user's best run row
		table.insert(dataRowSpecs, userBestRow)
	end

	local scrollingFrameSpec: wt.scrollingFrameTileSpec = {
		name = "WRProgressionScrollingFrame",
		type = "scrollingFrame",
		headerRow = headerRowSpec,
		dataRows = dataRowSpecs,
		rowHeight = rowHeightPixels,
	}

	return scrollingFrameSpec
end

module.CreateWRHistoryProgressionGui = function(data: tt.WRProgressionEndpointResponse)
	local times = {}
	local improvements = {}
	for _, entry in ipairs(data.wrProgression) do
		table.insert(times, entry.runMilliseconds / 1000)
		if #times > 1 then
			table.insert(improvements, times[#times] - times[#times - 1])
		end
	end

	local maxDecimalPlaces = math.min(tpUtil.GetMaxDecimalPlaces(times), tpUtil.GetMaxDecimalPlaces(improvements), 3)
	local maxIntegerDigits = math.max(tpUtil.GetMaxIntegerDigits(times), tpUtil.GetMaxIntegerDigits(improvements))
	local formatString = string.format("%%%d.%df", maxIntegerDigits + maxDecimalPlaces + 1, maxDecimalPlaces)

	local currentPlayerNames: { [string]: boolean } = {}
	for _, player in PlayersService:GetPlayers() do
		currentPlayerNames[player.Name] = true
	end

	local titleRowTileSpecs: { wt.tileSpec } = {
		{
			name = "TextIntro",
			order = 1,
			width = UDim.new(1 / 3, 0),
			spec = {
				type = "text",
				text = "WR Progression: ",
				isMonospaced = false,
				isBold = true,
				backgroundColor = colors.WRProgressionColor,
				textColor = colors.black,
				textXAlignment = Enum.TextXAlignment.Center,
			},
		},
		{
			name = "FirstSignIntro",
			order = 2,
			width = UDim.new(1 / 3, 0),
			spec = {
				type = "text",
				text = data.raceHistoryData.raceStartName,
				isMonospaced = false,
				isBold = true,
				backgroundColor = colors.signColor,
				textColor = colors.signTextColor,
				textXAlignment = Enum.TextXAlignment.Center,
			},
		},
		{
			name = "SecondSignIntro",
			order = 3,
			width = UDim.new(1 / 3, 0),
			spec = {
				type = "text",
				text = data.raceHistoryData.raceEndName,
				isMonospaced = false,
				isBold = true,
				backgroundColor = colors.signColor,
				textColor = colors.signTextColor,
				textXAlignment = Enum.TextXAlignment.Center,
			},
		},
	}

	local titleRowSpec: wt.rowSpec = {
		name = "TitleRow",
		order = 1,
		height = UDim.new(0, rowHeightPixels),
		tileSpecs = titleRowTileSpecs,
	}
	local cmdRow = getCommandRow(data)
	local detailsRowSpec = getDetailRow(data, currentPlayerNames)
	local scrollingFrameSpec = createWRProgressionScrollingFrameSpec(data, currentPlayerNames, formatString)

	local scrollingFrameRowSpec = {
		name = "ScrollingFrameRow",
		order = 3,
		height = UDim.new(1, 0),
		tileSpecs = {
			{
				name = "ScrollingFrameTile",
				order = 1,
				width = UDim.new(1, 0),
				spec = scrollingFrameSpec,
			},
		},
	}

	local buttonRow = createLastRow()

	local allRowSpecs: { wt.rowSpec } = {
		titleRowSpec,
		cmdRow,
		detailsRowSpec,
		scrollingFrameRowSpec,
		buttonRow,
	}

	local guiSpec: wt.guiSpec = {
		name = "WRProgressionEntry",
		rowSpecs = allRowSpecs,
	}

	local wrHistoryScreenGui = windows.CreatePopup(
		guiSpec,
		string.format(
			"WRHistoryProgression-%s-%s",
			data.raceHistoryData.raceStartName,
			data.raceHistoryData.raceEndName
		),
		true, -- draggable
		true, -- resizable
		true, -- minimizable
		true, -- pinnable
		true, -- dismissableWithX
		false, -- dismissableByClick
		UDim2.new(0.35, 0, 0.35, 0)
	)
	local outerFrame = wrHistoryScreenGui:FindFirstChildOfClass("Frame")
	if outerFrame then
		outerFrame.Position = UDim2.new(0.35, 0, 0.35, 0)
	end
	local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	wrHistoryScreenGui.Parent = playerGui
end

local function handleUserSettingChanged(item: tt.userSettingValue)
	-- if item.name == settingEnums.settingDefinitions.HIGHLIGHT_ON_RUN_COMPLETE_WARP.name then
	-- 	userWantsHighlightingWhenWarpingFromRunResults = item.booleanValue or false
	-- end
	return
end

module.Init = function()
	_annotate("init")
	settings.RegisterFunctionToListenForSettingName(
		handleUserSettingChanged,
		settingEnums.settingDefinitions.HIGHLIGHT_ON_RUN_COMPLETE_WARP.name,
		"drawWRHistoryProgressionGui"
	)

	local userSettingValue =
		settings.GetSettingByName(settingEnums.settingDefinitions.HIGHLIGHT_ON_RUN_COMPLETE_WARP.name)
	handleUserSettingChanged(userSettingValue)
	_annotate("init done")
end

_annotate("end")
return module
