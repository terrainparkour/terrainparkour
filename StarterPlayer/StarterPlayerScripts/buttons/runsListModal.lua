--!strict

-- runsListModal.lua
-- Unified modal for displaying Popular Runs and New Runs lists.
-- Replaces duplicated code from popularButton.lua and newButton.lua.
-- Uses the modern windows.CreatePopup system for draggability, resizing, and persistence.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayersService = game:GetService("Players")
local localPlayer = PlayersService.LocalPlayer

local tpUtil: typeof(require(game.ReplicatedStorage.util.tpUtil)) = require(game.ReplicatedStorage.util.tpUtil)
local colors = require(game.ReplicatedStorage.util.colors)
local enums = require(game.ReplicatedStorage.util.enums)
local remotes = require(game.ReplicatedStorage.util.remotes)
local _thumbnails = require(game.ReplicatedStorage.thumbnails)
local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)
local wt = require(game.StarterPlayer.StarterPlayerScripts.guis.windowsTypes)
local PopularResponseTypes = require(game.ReplicatedStorage.types.PopularResponseTypes)

local warper = require(game.StarterPlayer.StarterCharacterScripts.client.warper)

local module = {}

-- Remote functions
local GetPopularRacesFunction = remotes.getRemoteFunction("GetPopularRacesFunction")
local GetNewRacesFunction = remotes.getRemoteFunction("GetNewRacesFunction")

-- Modal modes
export type RunsListMode = "popular" | "new"

-- Column width constants (proportional widths that sum to ~1.0)
-- Kind column removed - was redundant (just showed "Pop" or "New" which you already know from the modal title)
local COLUMN_WIDTHS = {
	count = 0.10,
	race = 0.35,
	leaders = 0.40,
	warp = 0.15,
}

-- Layout constants
local ROW_HEIGHT_PIXELS = 40
local HEADER_HEIGHT_PIXELS = 30

-- Font sizes (matching drawRunResultGui pattern: fixed textSize, not textScaled)
local HEADER_TEXT_SIZE = 14
local DATA_TEXT_SIZE = 16
local TITLE_HEIGHT_PIXELS = 36
local CLOSE_BUTTON_HEIGHT_PIXELS = 30
local MAX_ROWS_TO_SHOW = 12

-- Mode-specific configuration
local MODE_CONFIG: { [RunsListMode]: { title: string, remoteFunction: RemoteFunction, popupName: string, countHeader: string, countTooltip: string } } = {
	popular = {
		title = "Recent Popular Runs",
		remoteFunction = GetPopularRacesFunction,
		popupName = "PopularRunsPopup",
		countHeader = "Ct",
		countTooltip = "Run count (how many times this race was run recently)",
	},
	new = {
		title = "New Races Found Today",
		remoteFunction = GetNewRacesFunction,
		popupName = "NewRacesPopup",
		countHeader = "Runs",
		countTooltip = "How many players have run this race so far",
	},
}

-- Create a tile spec for a leader position (portrait + place + username in horizontal layout)
local function createLeaderTileSpec(el: { userId: number, place: number, username: string }, index: number, widthScale: number): wt.tileSpec
	local useColor = colors.defaultGrey
	if el.userId == localPlayer.UserId then
		useColor = colors.meColor
	end

	local posColor = colors.defaultGrey
	local placeText = ""

	if el.place == nil then
		placeText = "-"
		posColor = colors.defaultGrey
	elseif el.place > 10 then
		placeText = "dnp"
		posColor = colors.defaultGrey
	else
		placeText = tpUtil.getCardinalEmoji(el.place)
		if el.place == 1 then
			posColor = colors.greenGo
		else
			posColor = colors.warpColor
		end
	end

	-- Combine place and username: "🥇 username"
	local displayText = string.format("%s %s", placeText, el.username)

	local rowTileSpec: wt.rowTileSpec = {
		type = "rowTile",
		name = "LeaderPosition_" .. index,
		tileSpecs = {
			{
				name = "Portrait",
				order = 1,
				width = UDim.new(0, 35), -- Fixed pixel width for portrait
				spec = {
					type = "portrait",
					userId = el.userId,
					doPopup = true,
					backgroundColor = useColor,
				},
			},
			{
				name = "Info",
				order = 2,
				width = UDim.new(1, -35), -- Remaining space
				spec = {
					type = "text",
					text = displayText,
					backgroundColor = posColor,
					textColor = colors.black,
					textXAlignment = Enum.TextXAlignment.Left,
					leftPadding = 4,
				},
			},
		},
	}

	return {
		name = "Leader_" .. index,
		order = index,
		width = UDim.new(widthScale, 0),
		spec = rowTileSpec,
	}
end

-- Create a tile spec for the leaders column (contains multiple leader positions)
local function createLeadersTileSpec(userPlaces: { { userId: number, place: number, username: string } }, order: number): wt.tileSpec
	local leaderTiles: { wt.tileSpec } = {}

	for ii, el in ipairs(userPlaces) do
		if el.place == nil then
			continue
		end
		local width = 1 / #userPlaces
		width = math.min(width, 1 / 3)
		table.insert(leaderTiles, createLeaderTileSpec(el, ii, width))
	end

	-- If no leaders, show empty placeholder
	if #leaderTiles == 0 then
		table.insert(leaderTiles, {
			name = "NoLeaders",
			order = 1,
			width = UDim.new(1, 0),
			spec = {
				type = "text",
				text = "-",
				backgroundColor = colors.defaultGrey,
				textColor = colors.black,
				textXAlignment = Enum.TextXAlignment.Center,
			},
		})
	end

	return {
		name = "Leaders",
		order = order,
		width = UDim.new(COLUMN_WIDTHS.leaders, 0),
		spec = {
			type = "rowTile",
			name = "LeadersRow",
			tileSpecs = leaderTiles,
		},
	}
end

-- Create a data row for a single race result
local function createRaceRowSpec(raceResult: PopularResponseTypes.popularRaceResult, rowIndex: number, onWarp: (startSignId: number, endSignId: number) -> ()): wt.rowSpec
	local tiles: { wt.tileSpec } = {}

	-- Count column
	local countText = if raceResult.ct == 0 then "-" else tostring(raceResult.ct)
	local countBgColor = colors.defaultGrey
	-- Highlight if this was the last race
	if raceResult.wasLastRace then
		countBgColor = colors.greenGo
	end

	table.insert(tiles, {
		name = "Count",
		order = 1,
		width = UDim.new(COLUMN_WIDTHS.count, 0),
		spec = {
			type = "text",
			text = countText,
			backgroundColor = countBgColor,
			textColor = colors.black,
			textXAlignment = Enum.TextXAlignment.Center,
			textScaled = false,
			textSize = DATA_TEXT_SIZE,
		},
	})

	-- Race column (start sign → end sign)
	local raceText = string.format("%s → %s", raceResult.startSignName, raceResult.endSignName)
	table.insert(tiles, {
		name = "Race",
		order = 2,
		width = UDim.new(COLUMN_WIDTHS.race, 0),
		tooltipText = string.format("Start: %s\nEnd: %s", raceResult.startSignName, raceResult.endSignName),
		spec = {
			type = "text",
			text = raceText,
			backgroundColor = colors.signColor,
			textColor = colors.signTextColor,
			textXAlignment = Enum.TextXAlignment.Left,
			leftPadding = 4,
		},
	})

	-- Leaders column
	table.insert(tiles, createLeadersTileSpec(raceResult.userPlaces, 3))

	-- Warp column - determine warp state
	local warpMode = "found"
	if not raceResult.hasFoundStart then
		warpMode = "unfound"
	end
	if raceResult.hasFoundStart and enums.SignIdIsExcludedFromStart[raceResult.startSignId] then
		warpMode = "excluded"
	end

	if warpMode == "found" then
		table.insert(tiles, {
			name = "Warp",
			order = 4,
			width = UDim.new(COLUMN_WIDTHS.warp, 0),
			spec = {
				type = "button",
				text = "Warp",
				backgroundColor = colors.warpColor,
				textColor = colors.black,
				textXAlignment = Enum.TextXAlignment.Center,
				onClick = function(_inputObject: InputObject, _theButton: TextButton)
					onWarp(raceResult.startSignId, raceResult.endSignId)
				end,
			},
		})
	elseif warpMode == "unfound" then
		table.insert(tiles, {
			name = "Warp",
			order = 4,
			width = UDim.new(COLUMN_WIDTHS.warp, 0),
			spec = {
				type = "text",
				text = "Find Sign First",
				backgroundColor = colors.defaultGrey,
				textColor = colors.black,
				textXAlignment = Enum.TextXAlignment.Center,
			},
		})
	else -- excluded
		table.insert(tiles, {
			name = "Warp",
			order = 4,
			width = UDim.new(COLUMN_WIDTHS.warp, 0),
			spec = {
				type = "text",
				text = "Excluded",
				backgroundColor = colors.defaultGrey,
				textColor = colors.black,
				textXAlignment = Enum.TextXAlignment.Center,
			},
		})
	end

	return {
		name = "Race_" .. rowIndex,
		order = rowIndex,
		height = UDim.new(0, ROW_HEIGHT_PIXELS),
		tileSpecs = tiles,
		searchText = string.format("%s %s", raceResult.startSignName, raceResult.endSignName),
	}
end

-- Create header row spec
-- Uses fixed textSize (not textScaled) for consistent readability in narrow columns
local function createHeaderRowSpec(config: { countHeader: string, countTooltip: string }): wt.rowSpec
	return {
		name = "Header",
		order = 1,
		height = UDim.new(0, HEADER_HEIGHT_PIXELS),
		tileSpecs = {
			{
				name = "CountHeader",
				order = 1,
				width = UDim.new(COLUMN_WIDTHS.count, 0),
				spec = {
					type = "text",
					text = config.countHeader,
					backgroundColor = colors.blueDone,
					textColor = colors.black,
					isBold = true,
					textXAlignment = Enum.TextXAlignment.Center,
					textScaled = false,
					textSize = HEADER_TEXT_SIZE,
				},
				tooltipText = config.countTooltip,
			},
			{
				name = "RaceHeader",
				order = 2,
				width = UDim.new(COLUMN_WIDTHS.race, 0),
				spec = {
					type = "text",
					text = "Race",
					backgroundColor = colors.blueDone,
					textColor = colors.black,
					isBold = true,
					textXAlignment = Enum.TextXAlignment.Center,
					textScaled = false,
					textSize = HEADER_TEXT_SIZE,
				},
			},
			{
				name = "LeadersHeader",
				order = 3,
				width = UDim.new(COLUMN_WIDTHS.leaders, 0),
				spec = {
					type = "text",
					text = "Leaders",
					backgroundColor = colors.blueDone,
					textColor = colors.black,
					isBold = true,
					textXAlignment = Enum.TextXAlignment.Center,
					textScaled = false,
					textSize = HEADER_TEXT_SIZE,
				},
				tooltipText = "Top placements from players in this server",
			},
			{
				name = "WarpHeader",
				order = 4,
				width = UDim.new(COLUMN_WIDTHS.warp, 0),
				spec = {
					type = "text",
					text = "Warp",
					backgroundColor = colors.blueDone,
					textColor = colors.black,
					isBold = true,
					textXAlignment = Enum.TextXAlignment.Center,
					textScaled = false,
					textSize = HEADER_TEXT_SIZE,
				},
			},
		},
	}
end

-- Main function to create the runs list modal
function module.createRunsListModal(mode: RunsListMode, userIds: { number }): ScreenGui
	local config = MODE_CONFIG[mode]
	_annotate(string.format("Creating %s modal for %d users", mode, #userIds))

	-- Fetch data from server
	local raceResults: { PopularResponseTypes.popularRaceResult } = config.remoteFunction:InvokeServer(userIds)

	-- Build data rows
	local dataRows: { wt.rowSpec } = {}
	for ii, raceResult in ipairs(raceResults) do
		local rowSpec = createRaceRowSpec(raceResult, ii, function(startSignId: number, endSignId: number)
			warper.WarpToSignId(startSignId, endSignId)
			-- Close the modal after warping
			local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
			if playerGui then
				local popup = playerGui:FindFirstChild(config.popupName)
				if popup then
					popup:Destroy()
				end
			end
		end)
		table.insert(dataRows, rowSpec)
	end

	-- Calculate rows to show based on actual content
	local actualDataCount = #dataRows
	local rowsToShow = math.min(actualDataCount + 1, MAX_ROWS_TO_SHOW) -- +1 for header
	rowsToShow = math.max(rowsToShow, 2) -- At least header + 1 data row

	-- Create scrolling frame spec
	local scrollingFrameSpec: wt.scrollingFrameTileSpec = {
		type = "scrollingFrameTileSpec",
		name = config.popupName .. "_ScrollingFrame",
		headerRow = createHeaderRowSpec({ countHeader = config.countHeader, countTooltip = config.countTooltip }),
		dataRows = dataRows,
		stickyRows = {},
		rowHeight = ROW_HEIGHT_PIXELS,
		howManyRowsToShow = rowsToShow,
		searchConfig = {
			placeholderText = "Search races...",
			countNoun = "races",
			autoFocus = false, -- Don't auto-focus so user can scroll immediately
		},
	}

	-- Calculate total height
	local searchHeight = 30 -- Search chrome row
	local scrollingFrameHeight = rowsToShow * ROW_HEIGHT_PIXELS
	local totalHeight = TITLE_HEIGHT_PIXELS + searchHeight + scrollingFrameHeight + CLOSE_BUTTON_HEIGHT_PIXELS

	-- Build guiSpec
	local guiSpec: wt.guiSpec = {
		name = config.popupName,
		rowSpecs = {
			-- Title row
			{
				name = "TitleRow",
				order = 1,
				height = UDim.new(0, TITLE_HEIGHT_PIXELS),
				tileSpecs = {
					{
						name = "Title",
						order = 1,
						width = UDim.new(1, 0),
						spec = {
							type = "text",
							text = config.title,
							isMonospaced = false,
							isBold = true,
							backgroundColor = colors.signColor,
							textColor = colors.white,
							textXAlignment = Enum.TextXAlignment.Center,
						},
					},
				},
			},
			-- Scrolling frame row (weight-based height)
			{
				name = "ScrollingFrameRow",
				order = 2,
				height = UDim.new(scrollingFrameHeight, 0), -- Weight-based
				tileSpecs = {
					{
						name = "ScrollingFrame",
						order = 1,
						width = UDim.new(1, 0),
						spec = scrollingFrameSpec,
					},
				},
			},
			-- Close button row
			{
				name = "CloseButtonRow",
				order = 3,
				height = UDim.new(0, CLOSE_BUTTON_HEIGHT_PIXELS),
				tileSpecs = { windows.StandardCloseButton },
			},
		},
	}

	-- Create popup using modern windowing system
	local popupResult = windows.CreatePopup(
		guiSpec,
		config.popupName,
		true, -- draggable
		true, -- resizable
		false, -- minimizable
		true, -- pinnable
		true, -- dismissableWithX
		false, -- dismissableByClick
		UDim2.new(0.5, 0, 0, totalHeight),
		rowsToShow
	)

	return popupResult.sgui
end

_annotate("end")
return module
