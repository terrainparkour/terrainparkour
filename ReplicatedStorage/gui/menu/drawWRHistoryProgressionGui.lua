--!strict

-- this is the companion to the serverside command: WRProgressionCommand!
-- there is a unified rpc name which clients can send as well as server. the next version is runResults
-- let's think about whta this file really is. It's a drawer for a UI with the following elements:

local tt = require(game.ReplicatedStorage.types.gametypes)
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local colors = require(game.ReplicatedStorage.util.colors)
local friendshipCache = require(game.ReplicatedStorage.util.friendshipCache)
local warper = require(game.StarterPlayer.StarterCharacterScripts.client.warper)
local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)
local tpUtil: typeof(require(game.ReplicatedStorage.util.tpUtil)) = require(game.ReplicatedStorage.util.tpUtil)
local toolTip = require(game.ReplicatedStorage.gui.toolTip)

-- Add this near the top of the file, with the other imports
local remotes = require(game.ReplicatedStorage.util.remotes)

local settings = require(game.ReplicatedStorage.settings)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local PlayersService = game:GetService("Players")
local localPlayer = PlayersService.LocalPlayer
local GenericClientUIFunction = remotes.getRemoteFunction("GenericClientUIFunction")
local wt = require(game.StarterPlayer.StarterPlayerScripts.guis.windowsTypes)
local yourRunsPopup = require(game.ReplicatedStorage.gui.yourRunsPopup)
local wrProgressionChart = require(game.ReplicatedStorage.gui.wrProgressionChart)

--------------------- GLOBALS -------------------

-- Track active chart popup for cleanup
local activeChartGui: ScreenGui? = nil

local function showWRProgressionChart(data: tt.WRProgressionEndpointResponse)
	-- Clean up any existing chart
	if activeChartGui then
		activeChartGui:Destroy()
		activeChartGui = nil
	end

	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end

	local raceTitle = string.format("%s-%s", data.raceHistoryData.raceStartName, data.raceHistoryData.raceEndName)

	-- Modal dimensions (default, can be resized)
	local titleHeight = 36
	local defaultChartWidth = 700
	local defaultChartHeight = 400
	local closeButtonHeight = 30
	local totalWidth = defaultChartWidth
	local totalHeight = titleHeight + defaultChartHeight + closeButtonHeight

	-- Title row: standard modal header with "Chart" in the title
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
					text = string.format("  WR Progression Chart: %s  ", raceTitle),
					isMonospaced = false,
					isBold = true,
					backgroundColor = colors.signColor,
					textColor = colors.white,
					textXAlignment = Enum.TextXAlignment.Center,
					textScaled = false,
				},
			},
		},
	}

	-- Close button row at bottom
	local closeButtonRowSpec: wt.rowSpec = {
		name = "CloseRow",
		order = 3,
		height = UDim.new(0, closeButtonHeight),
		tileSpecs = { windows.StandardCloseButton },
	}

	local guiSpec: wt.guiSpec = {
		name = "WRProgressionChart",
		rowSpecs = {
			titleRowSpec,
			-- Content row will be added after popup creation
			closeButtonRowSpec,
		},
	}

	-- Create the popup using standard modal pattern with resize and persistence
	-- Default position: left side of screen to avoid overlapping with speed chart (right side)
	local chartGuiResult = windows.CreatePopup(
		guiSpec,
		"WRProgressionChartPopup", -- Use consistent name for global persistence
		true, -- draggable
		true, -- resizable
		false, -- minimizable
		false, -- pinnable
		true, -- dismissableWithX
		false, -- dismissableByClick
		UDim2.fromOffset(totalWidth, totalHeight),
		nil,
		{
			settingName = "WR_CHART_GUI_LAYOUT",
			settingKey = "position",
			saveSize = true,
			sizeKey = "size",
			clampOnLoad = true,
			defaultPosition = UDim2.fromScale(0.05, 0.25), -- Left side, upper-middle
		}
	)
	local chartGui = chartGuiResult.sgui
	activeChartGui = chartGui

	-- Find the content frame
	local popupName = "WRProgressionChartPopup"
	local outerFrame = chartGui:FindFirstChild("outer_" .. popupName) :: Frame?
	if not outerFrame then
		for _, child in chartGui:GetChildren() do
			if child:IsA("Frame") then
				outerFrame = child :: Frame
				break
			end
		end
	end

	if outerFrame then
		local contentFrame = outerFrame:FindFirstChild("content_" .. popupName) :: Frame?
		if not contentFrame then
			for _, child in outerFrame:GetChildren() do
				if child:IsA("Frame") then
					contentFrame = child :: Frame
					break
				end
			end
		end

		if contentFrame then
			-- Create chart container that fills available space between title and close button
			-- Use scale-based sizing so it resizes instantly with the modal
			local chartContainerFrame = Instance.new("Frame")
			chartContainerFrame.Name = "0002_ChartContent"
			chartContainerFrame.Size = UDim2.new(1, 0, 1, -(titleHeight + closeButtonHeight))
			chartContainerFrame.BackgroundTransparency = 1
			chartContainerFrame.BorderSizePixel = 0
			chartContainerFrame.Parent = contentFrame

			-- Get user's best time if available (for Y-axis marker)
			local userBestMs: number? = nil
			if data.userRaceInfo and data.userRaceInfo.userFastestRun then
				userBestMs = data.userRaceInfo.userFastestRun.runMilliseconds
			end

			-- Create the scale-based chart directly (no nested wrapper)
			wrProgressionChart.CreateScaled(chartContainerFrame, data.wrProgression, raceTitle, {
				title = raceTitle,
				showAttempts = true,
				showVersionMarkers = true,
				showTitle = false,
				userBestMs = userBestMs,
				userBestUserId = localPlayer.UserId,
				userBestUsername = localPlayer.Name,
			})
		end
	end

	chartGui.Parent = playerGui
end
local rowHeightPixels = 36 -- Matches generalRowHeight in Run Results

--------------------- DESCRIPTORS --------------------------------

local bestTimeHeaderTile: wt.tileSpec = {
	name = "BestTime",
	order = 1,
	width = UDim.new(1, 0), -- Reduced from 2 to 1
	spec = {
		type = "text",
		text = "Best Time",
		textScaled = false,
		isMonospaced = false,
		isBold = false,
		backgroundColor = colors.blueDone,
		textColor = colors.black,
		textXAlignment = Enum.TextXAlignment.Center,
	},
}

local improvementHeaderTile: wt.tileSpec = {
	name = "Improvement",
	order = 2,
	width = UDim.new(2.25, 0), -- Increased from 1.25 to absorb BestTime reduction
	spec = {
		type = "text",
		text = "Improvement",
		textScaled = false,
		isMonospaced = false,
		isBold = false,
		backgroundColor = colors.blueDone,
		textColor = colors.black,
		textXAlignment = Enum.TextXAlignment.Center,
	},
}

local portraitHeaderTile: wt.tileSpec = {
	name = "Portrait",
	order = 3, -- Moved before Username
	width = UDim.new(0, rowHeightPixels),
	spec = {
		type = "portrait",
		textScaled = false,
		userId = 123456,
		doPopup = true,
		width = UDim.new(0, rowHeightPixels),
		backgroundColor = colors.blueDone,
	},
}

local usernameHeaderTile: wt.tileSpec = {
	name = "Username",
	order = 4, -- Moved after Portrait
	width = UDim.new(3.2, 0), -- Slightly reduced to make room for attempts column
	spec = {
		type = "text",
		text = "Achievement",
		textScaled = false,
		isMonospaced = false,
		isBold = false,
		backgroundColor = colors.blueDone,
		textColor = colors.black,
		textXAlignment = Enum.TextXAlignment.Center,
	},
}

local attemptsHeaderTile: wt.tileSpec = {
	name = "Attempts",
	order = 5,
	width = UDim.new(1.4, 0),
	spec = {
		type = "text",
		text = "Attempts",
		textScaled = false,
		isMonospaced = false,
		isBold = false,
		backgroundColor = colors.blueDone,
		textColor = colors.black,
		textXAlignment = Enum.TextXAlignment.Center,
	},
	tooltipText = "Total attempts / Winner's attempts\nHow many tries before the record was broken",
}

local lastedHeaderTile: wt.tileSpec = {
	name = "Lasted",
	order = 6,
	width = UDim.new(1.6, 0), -- Reduced to make room for attempts
	spec = {
		type = "text",
		text = "Lasted",
		isMonospaced = false,
		isBold = false,
		backgroundColor = colors.blueDone,
		textColor = colors.black,
		textScaled = false,
		textXAlignment = Enum.TextXAlignment.Center,
	},
}

local dateSetHeaderTile: wt.tileSpec = {
	name = "Date Set",
	order = 7,
	width = UDim.new(1.5, 0), -- Reduced to make room for attempts
	spec = {
		type = "text",
		text = "Date Set",
		isMonospaced = false,
		isBold = false,
		backgroundColor = colors.blueDone,
		textColor = colors.black,
		textScaled = false,
		textXAlignment = Enum.TextXAlignment.Center,
	},
}

local wrProgressionDataTableHeaderTileSpec: { wt.tileSpec } = {
	bestTimeHeaderTile,
	improvementHeaderTile,
	portraitHeaderTile, -- Portrait now before Username
	usernameHeaderTile,
	attemptsHeaderTile, -- New attempts column
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
			textScaled = false,
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
		text = "Reverse Race Progression",
		isMonospaced = false,
		isBold = false,
		textScaled = false,
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

	local chartTile: wt.tileSpec = {
		name = "Chart",
		order = 4,
		width = UDim.new(1, 0),
		spec = {
			type = "button",
			text = "WR Progression Chart",
			isMonospaced = false,
			isBold = false,
			backgroundColor = colors.greenGo,
			textColor = colors.black,
			textXAlignment = Enum.TextXAlignment.Center,
			onClick = function()
				showWRProgressionChart(data)
			end,
		},
	}

	table.insert(tileSpecs, runResultsTile)
	table.insert(tileSpecs, reverseRaceTile)
	table.insert(tileSpecs, createWarpButton(data))
	table.insert(tileSpecs, chartTile)

	return {
		name = "CommandRow",
		order = 2,
		height = UDim.new(40, 0), -- Proportional weight for resizable layout
		tileSpecs = tileSpecs,
	}
end

-- Stats row: Your Runs, racers, total runs, distance (matching Run Results layout)
local function getStatsRow(data: tt.WRProgressionEndpointResponse): (wt.rowSpec, (TextLabel) -> ())
	local statsTiles: { wt.tileSpec } = {}
	local startSignId = tpUtil.signName2SignId(data.raceHistoryData.raceStartName)
	local endSignId = tpUtil.signName2SignId(data.raceHistoryData.raceEndName)

	-- Chip order: Your Runs → Racers → Total Runs → Distance (matching Run Results)
	local yourRunsTile: wt.tileSpec = {
		name = "YourRuns",
		order = 1,
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

	local racersText = string.format("%d racers", data.raceHistoryData.raceRunnerCount)
	if data.raceHistoryData.raceRunnerCount == 1 then
		racersText = "1 racer"
	end
	local racersTile: wt.tileSpec = {
		name = "Racers",
		order = 2,
		width = UDim.new(2, 0),
		spec = {
			type = "text",
			text = racersText,
			isMonospaced = false,
			isBold = false,
			backgroundColor = colors.defaultGrey,
			textColor = colors.black,
			textXAlignment = Enum.TextXAlignment.Center,
		},
	}

	local totalRunsTile: wt.tileSpec = {
		name = "TotalRuns",
		order = 3,
		width = UDim.new(2, 0),
		spec = {
			type = "text",
			text = string.format("%d total runs", data.raceHistoryData.raceRunCount),
			isMonospaced = false,
			isBold = false,
			backgroundColor = colors.defaultGrey,
			textColor = colors.black,
			textXAlignment = Enum.TextXAlignment.Center,
		},
	}

	local lengthTile: wt.tileSpec = {
		name = "Length",
		order = 4,
		width = UDim.new(2, 0),
		spec = {
			type = "text",
			text = string.format("%.1fd", data.raceHistoryData.raceLength),
			isMonospaced = true,
			isBold = false,
			backgroundColor = colors.defaultGrey,
			textColor = colors.black,
			textXAlignment = Enum.TextXAlignment.Center,
		},
	}

	-- WR count: how many times the record has been broken (unique to WR Progression)
	local wrCount = #data.wrProgression
	local wrCountText = wrCount == 1 and "1 WR set" or string.format("%d WRs set", wrCount)
	local wrCountTile: wt.tileSpec = {
		name = "WRCount",
		order = 5,
		width = UDim.new(2, 0),
		spec = {
			type = "text",
			text = wrCountText,
			isMonospaced = false,
			isBold = true,
			backgroundColor = colors.greenGo, -- Distinct color for WR-specific stat
			textColor = colors.black,
			textXAlignment = Enum.TextXAlignment.Center,
		},
	}

	table.insert(statsTiles, yourRunsTile)
	table.insert(statsTiles, racersTile)
	table.insert(statsTiles, totalRunsTile)
	table.insert(statsTiles, lengthTile)
	table.insert(statsTiles, wrCountTile)

	local statsRow: wt.rowSpec = {
		name = "StatsRow",
		order = 2,
		height = UDim.new(rowHeightPixels, 0),
		tileSpecs = statsTiles,
	}

	-- Setup function for hover behavior on Your Runs tile
	local function setupYourRunsHover(textLabel: TextLabel)
		yourRunsPopup.SetupHover(textLabel, startSignId, endSignId)
	end

	return statsRow, setupYourRunsHover
end

-- First Runner row: Commemorates the race discoverer with portrait and single sentence
local function getFirstRunnerRow(data: tt.WRProgressionEndpointResponse, currentPlayerNames: { [string]: boolean }): wt.rowSpec?
	if not data.raceHistoryData.firstRunnerUserId or not data.raceHistoryData.firstRunnerUsername then
		return nil
	end

	local firstRunnerTiles: { wt.tileSpec } = {}

	-- Background color: highlight based on relationship
	-- Priority: me > friend+inServer > friend > inServer > default
	local bgColor = colors.defaultGrey
	local userId = data.raceHistoryData.firstRunnerUserId
	local isInServer = currentPlayerNames[data.raceHistoryData.firstRunnerUsername]
	local isFriend = friendshipCache.isFriend(userId)

	if userId == localPlayer.UserId then
		bgColor = colors.meColor
	elseif isFriend and isInServer then
		bgColor = colors.friendInServerColor
	elseif isFriend then
		bgColor = colors.friendColor
	elseif isInServer then
		bgColor = colors.inServerColor
	end

	local portraitSpec: wt.portraitTileSpec = {
		type = "portrait",
		userId = data.raceHistoryData.firstRunnerUserId,
		doPopup = true,
		width = UDim.new(0, rowHeightPixels),
		backgroundColor = bgColor,
	}

	local firstRunnerPortraitTile: wt.tileSpec = {
		name = "FirstRunnerPortrait",
		order = 1,
		spec = portraitSpec,
		width = UDim.new(0, rowHeightPixels),
	}

	-- Single sentence describing the discoverer
	local dateStr = os.date("%Y-%m-%d", data.raceHistoryData.raceCreatedTime)
	local discoveryText = string.format("%s discovered this race on %s", data.raceHistoryData.firstRunnerUsername, dateStr)

	local discoveryTextTile: wt.tileSpec = {
		name = "DiscoveryText",
		order = 2,
		width = UDim.new(1, 0), -- Fill remaining width
		spec = {
			type = "text",
			text = discoveryText,
			isMonospaced = false,
			isBold = false,
			backgroundColor = bgColor,
			textColor = colors.black,
			textXAlignment = Enum.TextXAlignment.Left,
			leftPadding = 8,
		},
	}

	table.insert(firstRunnerTiles, firstRunnerPortraitTile)
	table.insert(firstRunnerTiles, discoveryTextTile)

	local firstRunnerRow: wt.rowSpec = {
		name = "FirstRunnerRow",
		order = 3,
		height = UDim.new(rowHeightPixels, 0),
		tileSpecs = firstRunnerTiles,
	}

	return firstRunnerRow
end

local function createWRProgressionEntryRow(
	entry: tt.wrProgressionEntry,
	index: number,
	kind: string,
	currentPlayerNames: { [string]: boolean },
	formatString: string,
	maxImprovementMs: number,
	isFirstRunEver: boolean,
	previousWRHolder: string? -- Username of the person whose record this entry beat (nil if first run)
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
				rightBorderColor = colors.black, -- Match the left border
			}
			tileSpecShell.spec = portraitSpec
		else
			local content = ""
			local backgroundColor = colors.defaultGrey
			local align: Enum.TextXAlignment = Enum.TextXAlignment.Center
			local isMonospaced = false
			local useCustomLastedTile = false
			local useCustomImprovementTile = false
			local lastedSeconds = 0
			local improvementMs = 0
			local leftPadding = 0
			local rightPadding = 0

			if headerTileSpec.name == "BestTime" then
				content = string.format(formatString, entry.runMilliseconds / 1000)
				isMonospaced = true
				align = Enum.TextXAlignment.Right
				rightPadding = 6
			elseif headerTileSpec.name == "Improvement" then
				if kind == "theUserSpecial" then
					content = ""
					isMonospaced = true
					align = Enum.TextXAlignment.Right
				elseif isFirstRunEver then
					-- First WR ever - no previous record to improve upon
					content = "first run"
					isMonospaced = false
					align = Enum.TextXAlignment.Center
				elseif not entry.improvementMs or entry.improvementMs == 0 then
					content = ""
					isMonospaced = true
					align = Enum.TextXAlignment.Right
				else
					content = string.format(formatString, entry.improvementMs / 1000)
					improvementMs = entry.improvementMs
					useCustomImprovementTile = true
					isMonospaced = true
					align = Enum.TextXAlignment.Right
				end
				rightPadding = 6
			elseif headerTileSpec.name == "Username" then
				-- Contextual achievement text
				if kind == "theUserSpecial" then
					content = string.format("%s's best run", entry.username)
				elseif isFirstRunEver then
					content = string.format("%s discovered", entry.username)
				elseif previousWRHolder and previousWRHolder == entry.username then
					content = string.format("%s improved", entry.username)
				elseif previousWRHolder then
					content = string.format("%s beat %s", entry.username, previousWRHolder)
				else
					content = entry.username
				end
				-- Determine background color based on relationship
				local isInServer = currentPlayerNames[entry.username]
				local isFriend = friendshipCache.isFriend(entry.userId)
				if entry.userId == localPlayer.UserId then
					backgroundColor = colors.meColor
				elseif isFriend and isInServer then
					backgroundColor = colors.friendInServerColor
				elseif isFriend then
					backgroundColor = colors.friendColor
				elseif isInServer then
					backgroundColor = colors.inServerColor
				else
					backgroundColor = colors.defaultGrey
				end
				align = Enum.TextXAlignment.Left
				leftPadding = 6
			elseif headerTileSpec.name == "Attempts" then
				-- Show attempts: "total / byWinner" with tooltip explanation
				if kind == "theUserSpecial" then
					content = ""
				elseif entry.attemptsBetween ~= nil and entry.attemptsByWinner ~= nil then
					content = string.format("%d / %d", entry.attemptsBetween, entry.attemptsByWinner)
					-- Add tooltip to explain the numbers
					tileSpecShell.tooltipText = string.format("Total attempts before record broken: %d\nAttempts by %s to beat it: %d", entry.attemptsBetween, entry.username, entry.attemptsByWinner)
				elseif entry.attemptsBetween ~= nil then
					content = string.format("%d / ?", entry.attemptsBetween)
				else
					content = ""
				end
				isMonospaced = true
				align = Enum.TextXAlignment.Center
			elseif headerTileSpec.name == "Lasted" then
				if kind == "theUserSpecial" then
					content = ""
				else
					local formattedToDisplay, _ = tpUtil.formatDateGap(entry.recordStood)
					content = entry.recordStood and formattedToDisplay or ""
					backgroundColor = index == 1 and colors.greenGo or colors.defaultGrey
					lastedSeconds = entry.recordStood or 0
					useCustomLastedTile = lastedSeconds > 0
				end
				isMonospaced = true
				align = Enum.TextXAlignment.Left
			elseif headerTileSpec.name == "Date Set" then
				content = os.date("%Y-%m-%d", entry.runTime)
				isMonospaced = true
			end

			if useCustomLastedTile then
				-- Use custom tile spec for logarithmic duration indicator
				local customSpec = {
					type = "lasted",
					text = content,
					durationSeconds = lastedSeconds,
					backgroundColor = backgroundColor,
					textColor = colors.black,
				}
				tileSpecShell.spec = customSpec :: any
			elseif useCustomImprovementTile then
				-- Use custom tile spec for linear improvement indicator with gradient
				local improvementSpec = {
					type = "improvement",
					text = content,
					improvementMs = improvementMs,
					maxImprovementMs = maxImprovementMs,
					backgroundColor = backgroundColor,
					textColor = colors.black,
				}
				tileSpecShell.spec = improvementSpec :: any
			else
				local textSpec: wt.textTileSpec = {
					type = "text",
					text = content,
					isMonospaced = isMonospaced,
					isBold = false,
					backgroundColor = backgroundColor,
					textColor = colors.black,
					textXAlignment = align,
					leftPadding = leftPadding > 0 and leftPadding or nil,
					rightPadding = rightPadding > 0 and rightPadding or nil,
				}
				tileSpecShell.spec = textSpec
			end
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
		height = UDim.new(rowHeightPixels, 0), -- Proportional weight for resizable layout
		tileSpecs = { windows.StandardCloseButton },
		horizontalAlignment = Enum.HorizontalAlignment.Right,
	}
	return lastRow
end

local function createWRProgressionScrollingFrameSpec(data: tt.WRProgressionEndpointResponse, currentPlayerNames: { [string]: boolean }, formatString: string): (wt.scrollingFrameTileSpec, number)
	local headerRowSpec: wt.rowSpec = {
		name = "HeaderRow",
		order = 1,
		height = UDim.new(0, rowHeightPixels), -- Fixed pixels, scaled dynamically by scrolling frame
		tileSpecs = wrProgressionDataTableHeaderTileSpec,
	}

	-- Calculate max improvement for dynamic gradient scaling
	local maxImprovementMs = 0
	for _, entry in ipairs(data.wrProgression) do
		if entry.improvementMs and entry.improvementMs > maxImprovementMs then
			maxImprovementMs = entry.improvementMs
		end
	end

	local dataRowSpecs: { wt.rowSpec } = {}
	local weStillNeedToDisplayUsersRun: boolean = false
	if data.userRaceInfo.userFastestRun and data.userRaceInfo.userFastestRun.runId then
		weStillNeedToDisplayUsersRun = true
	end

	local totalWREntries = #data.wrProgression
	for i, entry in ipairs(data.wrProgression) do
		if entry.userId == localPlayer.UserId then
			weStillNeedToDisplayUsersRun = false
		end
		if data.userRaceInfo.userFastestRun and weStillNeedToDisplayUsersRun and entry.runMilliseconds > data.userRaceInfo.userFastestRun.runMilliseconds then
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
				formatString,
				maxImprovementMs,
				false, -- not the first run ever
				nil -- no previous WR holder for user's personal best row
			)
			userBestRow.height = UDim.new(0, rowHeightPixels) -- Set the height for the user's best run row
			table.insert(dataRowSpecs, userBestRow)
		end
		-- Last entry in the WR progression is the first run ever (chronologically oldest)
		local isFirstRunEver = (i == totalWREntries)
		-- The person this entry beat is at index i+1 (the next slower WR holder)
		local previousWRHolder: string? = nil
		if not isFirstRunEver and data.wrProgression[i + 1] then
			previousWRHolder = data.wrProgression[i + 1].username
		end
		local wrRow = createWRProgressionEntryRow(entry, i, "normal", currentPlayerNames, formatString, maxImprovementMs, isFirstRunEver, previousWRHolder)
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
			formatString,
			maxImprovementMs,
			false, -- not the first run ever
			nil -- no previous WR holder for user's personal best row
		)
		userBestRow.height = UDim.new(0, rowHeightPixels) -- Set the height for the user's best run row
		table.insert(dataRowSpecs, userBestRow)
	end

	-- Calculate rows to show based on actual content (min 1, max 12)
	-- +1 accounts for the header row in the total visible count
	local maxRowsToShow = 12
	local actualDataRowCount = #dataRowSpecs
	local rowsToShow = math.min(actualDataRowCount + 1, maxRowsToShow)
	rowsToShow = math.max(rowsToShow, 2) -- At least header + 1 data row

	local scrollingFrameSpec: wt.scrollingFrameTileSpec = {
		name = "WRProgressionScrollingFrame",
		type = "scrollingFrameTileSpec",
		headerRow = headerRowSpec,
		dataRows = dataRowSpecs,
		stickyRows = {},
		rowHeight = rowHeightPixels,
		howManyRowsToShow = rowsToShow,
	}

	return scrollingFrameSpec, rowsToShow
end

-------------------- RESET FUNCTION (must be before CreateWRHistoryProgressionGui) -----------------------------

module.Reset = function()
	_annotate("Resetting WRHistoryProgression UIs")
	local player = PlayersService.LocalPlayer
	if not player then
		return
	end
	local pgui = player:FindFirstChildOfClass("PlayerGui")
	if not pgui then
		return
	end
	for _, child in ipairs(pgui:GetChildren()) do
		if child:IsA("ScreenGui") and string.match(child.Name, "^WRHistoryProgression%-") then
			child:Destroy()
		end
	end
end

-------------------- THE ACTUAL DRAWING FUNCTION -----------------------------

module.CreateWRHistoryProgressionGui = function(data: tt.WRProgressionEndpointResponse)
	-- Destroy any existing WR Progression GUI to prevent duplicates
	module.Reset()

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

	-- Title row matches run results style: full width, red background, "WR Progression: StartSign-EndSign"
	-- Add horizontal padding (spaces) to clear pin button on left and balance on right
	local titleText = string.format("  WR Progression: %s-%s  ", data.raceHistoryData.raceStartName, data.raceHistoryData.raceEndName)
	local titleRowTileSpecs: { wt.tileSpec } = {
		{
			name = "Title",
			order = 1,
			width = UDim.new(1, 0),
			spec = {
				type = "text",
				text = titleText,
				isMonospaced = false,
				isBold = true,
				backgroundColor = colors.signColor,
				textColor = colors.white,
				textXAlignment = Enum.TextXAlignment.Center,
				includeTextSizeConstraint = false,
			},
		},
	}

	local titleRowSpec: wt.rowSpec = {
		name = "TitleRow",
		order = 1,
		height = UDim.new(rowHeightPixels * 2, 0), -- Proportional weight, taller like run results title
		tileSpecs = titleRowTileSpecs,
	}
	local cmdRow = getCommandRow(data)
	local statsRowSpec, setupYourRunsHover = getStatsRow(data)
	local firstRunnerRowSpec = getFirstRunnerRow(data, currentPlayerNames)
	local scrollingFrameSpec, scrollingRowsToShow = createWRProgressionScrollingFrameSpec(data, currentPlayerNames, formatString)

	-- Scrolling frame weight = rows to show * row height (proportional to other rows)
	local scrollingFrameWeight = scrollingRowsToShow * rowHeightPixels
	local scrollingFrameRowSpec = {
		name = "ScrollingFrameRow",
		order = 4, -- After stats and first runner rows
		height = UDim.new(scrollingFrameWeight, 0), -- Proportional weight for resizable layout
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
		statsRowSpec,
	}

	-- Add first runner row if data exists
	if firstRunnerRowSpec then
		table.insert(allRowSpecs, firstRunnerRowSpec)
	end

	table.insert(allRowSpecs, scrollingFrameRowSpec)
	table.insert(allRowSpecs, buttonRow)

	local guiSpec: wt.guiSpec = {
		name = "WRProgressionEntry",
		rowSpecs = allRowSpecs,
	}

	-- Calculate popup height based on actual content
	-- Fixed rows: title (60) + cmdRow (40) + statsRow (30) + firstRunnerRow (30, optional) + buttonRow (30)
	-- Scrolling frame: scrollingRowsToShow * rowHeightPixels
	local fixedRowsHeight = (rowHeightPixels * 2) + 40 + rowHeightPixels + rowHeightPixels -- title + cmd + stats + button
	if firstRunnerRowSpec then
		fixedRowsHeight = fixedRowsHeight + rowHeightPixels -- Add first runner row height
	end
	local scrollingFrameHeight = scrollingRowsToShow * rowHeightPixels
	local totalHeight = fixedRowsHeight + scrollingFrameHeight

	local wrHistoryScreenGuiResult = windows.CreatePopup(
		guiSpec,
		string.format("WRHistoryProgression-%s-%s", data.raceHistoryData.raceStartName, data.raceHistoryData.raceEndName),
		true, -- draggable
		true, -- resizable
		false, -- minimizable (removed)
		true, -- pinnable
		true, -- dismissableWithX
		false, -- dismissableByClick
		UDim2.new(0.35, 0, 0, totalHeight),
		scrollingRowsToShow,
		{
			settingName = "WR_PROGRESSION_GUI_LAYOUT",
			settingKey = "position",
			saveSize = true,
			sizeKey = "size",
			clampOnLoad = true,
		}
	)
	local wrHistoryScreenGui = wrHistoryScreenGuiResult.sgui
	-- Position is automatically loaded/saved by windowFunctions persistence system
	local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	wrHistoryScreenGui.Parent = playerGui

	-- Set up hover behavior on the "Your Runs" tile
	task.defer(function()
		local yourRunsLabel: TextLabel? = nil
		for _, desc in ipairs(wrHistoryScreenGui:GetDescendants()) do
			if desc:IsA("TextLabel") and string.find(desc.Name, "_YourRuns$") then
				yourRunsLabel = desc :: TextLabel
				break
			end
		end

		if yourRunsLabel then
			yourRunsLabel.Active = true
			setupYourRunsHover(yourRunsLabel)
			_annotate("Set up hover behavior on YourRuns tile: " .. yourRunsLabel.Name)
		else
			_annotate("Could not find YourRuns tile for hover setup")
		end
	end)
end

-------------------- SETTINGS MANAGEMENT -----------------------------

local function handleUserSettingChanged(item: tt.userSettingValue)
	-- if item.name == settingEnums.settingDefinitions.HIGHLIGHT_ON_RUN_COMPLETE_WARP.name then
	-- 	userWantsHighlightingWhenWarpingFromRunResults = item.booleanValue or false
	-- end
	return
end

module.Init = function()
	_annotate("init")
	module.Reset()
	settings.RegisterFunctionToListenForSettingName(handleUserSettingChanged, settingEnums.settingDefinitions.HIGHLIGHT_ON_RUN_COMPLETE_WARP.name, "drawWRHistoryProgressionGui")

	local userSettingValue = settings.GetSettingByName(settingEnums.settingDefinitions.HIGHLIGHT_ON_RUN_COMPLETE_WARP.name)
	handleUserSettingChanged(userSettingValue)
	_annotate("init done")
end

-- Export the chart function for direct access from other modules
module.ShowWRProgressionChart = showWRProgressionChart

_annotate("end")
return module
