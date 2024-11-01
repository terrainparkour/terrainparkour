--!strict

-- DrawRunResultsGui: Creates the race result UI for player localscripts
-- Used locally

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local colors = require(game.ReplicatedStorage.util.colors)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local toolTip = require(game.ReplicatedStorage.gui.toolTip)
local enums = require(game.ReplicatedStorage.util.enums)
local settings = require(game.ReplicatedStorage.settings)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local warper = require(game.StarterPlayer.StarterPlayerScripts.warper)
local tt = require(game.ReplicatedStorage.types.gametypes)
local wt = require(game.StarterPlayer.StarterPlayerScripts.guis.windowsTypes)
local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)

local PlayersService = game:GetService("Players")
local localPlayer = PlayersService.LocalPlayer
local remotes = require(game.ReplicatedStorage.util.remotes)

-- local GenericClientUIEvent = remotes.getRemoteEvent("GenericClientUIEvent")
local GenericClientUIFunction = remotes.getRemoteFunction("GenericClientUIFunction")

------------------------- live-monitor this setting value. -------------
local userWantsHighlightingWhenWarpingFromRunResults = false
local globalSettingShowRunResultPopups = true
local globalSettingShrinkRunResultPopups = false
local globalSettingOnlyHaveOneRunResultPopupAtATime = false
local generalRowHeight = 36

--global counter for this "class"

local theLastGui: ScreenGui? = nil
local theLastGuiPosition: UDim2? = nil

local module = {}

------------------ COLUMN SPECS -----------------------------

local columnSpecs: { wt.tileSpec } = {
	{
		name = "Place",
		order = 1,
		width = UDim.new(1, 0),
		spec = {
			type = "text",
			text = "#",
			isMonospaced = false,
			isBold = false,
			backgroundColor = colors.blueDone,
			textColor = colors.black,
			textXAlignment = Enum.TextXAlignment.Center,
		},
	},
	{
		name = "Portrait",
		order = 2,
		width = UDim.new(0, generalRowHeight),
		spec = {
			type = "portrait",
			doPopup = true,
			userId = 1,
			backgroundColor = colors.blueDone,
			width = UDim.new(0, generalRowHeight),
		},
	},
	{
		name = "Username",
		order = 3,
		width = UDim.new(8, 0),
		spec = {
			type = "text",
			text = "Username",
			isMonospaced = false,
			isBold = false,
			backgroundColor = colors.blueDone,
			textColor = colors.black,
			textXAlignment = Enum.TextXAlignment.Center,
		},
	},
	{
		name = "Time",
		order = 4,
		width = UDim.new(5, 0),
		spec = {
			type = "text",
			text = "Time",
			isMonospaced = false,
			isBold = false,
			backgroundColor = colors.blueDone,
			textColor = colors.black,
			textXAlignment = Enum.TextXAlignment.Center,
		},
	},
}

------------- GUI HELPERS -----------------------------

local function formatRunAgeTooltip(runAgeSeconds: number): string
	local formattedRunAge, _ageDescriptor = tpUtil.formatDateGap(runAgeSeconds)
	return string.format("Run age: %s", formattedRunAge)
end

local function requestPinRace(startSignId: number, endSignId: number)
	local req = {
		eventKind = "pinRaceRequest",
		data = {
			startSignId = startSignId,
			endSignId = endSignId,
		},
	}
	GenericClientUIFunction:InvokeServer(req)
end

-- Add this function near the top of the file, after the imports
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

-- Add this function near the top of the file, after the imports
local function requestFavoriteRace(startSignId: number, endSignId: number, favoriteStatus: boolean)
	local success = GenericClientUIFunction:InvokeServer({
		eventKind = "adjustFavoriteRaceRequest",
		data = {
			signId1 = startSignId,
			signId2 = endSignId,
			favoriteStatus = favoriteStatus,
		},
	})

	if not success then
		warn("Failed to request WR progression")
	end
end

local function requestReverseResults(startSignId: number, endSignId: number)
	local success = GenericClientUIFunction:InvokeServer({
		eventKind = "runResultsRequest",
		data = {
			userId = localPlayer.UserId,
			startSignId = endSignId,
			endSignId = startSignId,
		},
	})

	if not success then
		warn("Failed to request RunResult")
	end
end

------------------ BUTTONS, ROWS ETC spec makers. ---------

local function createInverseTop10Button(options: tt.userFinishedRunResponse): wt.tileSpec
	local x: wt.tileSpec = {
		name = "InverseTop10",
		order = 2,
		width = UDim.new(1, 0),
		spec = {
			type = "button",
			text = "Inverse Top 10",
			backgroundColor = colors.WRProgressionColor,
			textColor = colors.black,
			isMonospaced = false,
			isBold = false,
			textXAlignment = Enum.TextXAlignment.Center,
			onClick = function()
				requestReverseResults(options.raceInfo.startSignId, options.raceInfo.endSignId)
			end,
		},
	}
	return x
end

local function createWRProgressionButton(options: tt.userFinishedRunResponse): wt.tileSpec
	local x: wt.tileSpec = {
		name = "WRProgression",
		order = 1,
		width = UDim.new(1, 0),
		spec = {
			type = "button",
			text = "WR Progression",
			backgroundColor = colors.WRProgressionColor,
			textColor = colors.black,
			isMonospaced = false,
			isBold = false,
			textXAlignment = Enum.TextXAlignment.Center,
			onClick = function()
				requestWRProgression(options.raceInfo.startSignId, options.raceInfo.endSignId)
			end,
		},
	}
	return x
end

local function createPinRaceButton(options: tt.userFinishedRunResponse): wt.tileSpec
	local x: wt.tileSpec = {
		name = "PinRace",
		order = 1,
		width = UDim.new(1, 0),
		spec = {
			type = "button",
			text = "Pin Race",
			backgroundColor = colors.WRProgressionColor,
			textColor = colors.black,
			isMonospaced = false,
			isBold = false,
			textXAlignment = Enum.TextXAlignment.Center,
			onClick = function()
				requestPinRace(options.raceInfo.startSignId, options.raceInfo.endSignId)
			end,
		},
	}
	return x
end

local function createWarpButton(userFinishedRunResponse: tt.userFinishedRunResponse): wt.tileSpec
	local canWarp = userFinishedRunResponse.raceInfo.startSignId and not userFinishedRunResponse.isMarathon
	local startSign = canWarp and tpUtil.signId2Sign(userFinishedRunResponse.raceInfo.startSignId) or nil
	local canHighlight = startSign and tpUtil.SignCanBeHighlighted(startSign)
	local buttonSpec: wt.buttonTileSpec = {
		type = "button",
		text = canHighlight
				and string.format("Warp to %s", enums.signId2name[userFinishedRunResponse.raceInfo.startSignId])
			or "Warp",
		backgroundColor = colors.warpColor,
		textColor = colors.black,
		isMonospaced = false,
		isBold = false,
		textXAlignment = Enum.TextXAlignment.Center,
		onClick = function(_: InputObject, _2: TextButton)
			if canHighlight then
				local useLastRunEnd = userWantsHighlightingWhenWarpingFromRunResults
						and tpUtil.SignCanBeHighlighted(tpUtil.signId2Sign(userFinishedRunResponse.raceInfo.endSignId))
						and userFinishedRunResponse.raceInfo.endSignId
					or nil
				warper.WarpToSignId(userFinishedRunResponse.raceInfo.startSignId, useLastRunEnd)
			end
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

local function createFavoriteRaceButton(options: tt.userFinishedRunResponse): wt.tileSpec
	local isFavorite = options.isFavoriteRace
	local useColor = isFavorite and colors.subtlePink or colors.defaultGrey
	local x: wt.tileSpec = {
		name = "favoriteRaceButton",
		order = 1,
		width = UDim.new(1, 0),
		spec = {
			type = "button",
			text = "fav",
			backgroundColor = useColor,
			textColor = colors.black,
			isMonospaced = false,
			isBold = false,
			textXAlignment = Enum.TextXAlignment.Center,
			onClick = function(io: InputObject, el: TextButton)
				isFavorite = not isFavorite
				requestFavoriteRace(options.raceInfo.startSignId, options.raceInfo.endSignId, isFavorite)
				useColor = isFavorite and colors.subtlePink or colors.defaultGrey
				el.BackgroundColor3 = useColor
			end,
		},
	}
	return x
end

-- we fork our own close button since we have to also remember the lastGuiPosition.
local closeButtonTextButtonTileSpec: wt.buttonTileSpec = {
	type = "button",
	text = "Close",
	onClick = function(_: InputObject, theButton: TextButton)
		local screenGui = theButton:FindFirstAncestorOfClass("ScreenGui")

		if screenGui then
			local outerFrame = screenGui:FindFirstChildOfClass("Frame")
			if outerFrame then
				theLastGuiPosition = outerFrame.Position
				_annotate(
					string.format(
						"set theLastGuiPosition to %s based on %s",
						tostring(theLastGuiPosition),
						outerFrame.Name
					)
				)
			end
			theLastGui = nil
			_annotate("destroying lastGui")
			toolTip.KillFinalTooltip()
			screenGui:Destroy()
		else
			warn("Could not find ScreenGui to close")
		end
	end,
	backgroundColor = colors.redSlowDown,
	textColor = colors.white,
	isMonospaced = false,
	isBold = true,
	textXAlignment = Enum.TextXAlignment.Center,
}

local closeButtonLeavingroom: wt.tileSpec = {
	name = "Close",
	order = 1,
	width = UDim.new(1, -15),
	spec = closeButtonTextButtonTileSpec,
}

local function createLastRow(): wt.rowSpec
	local lastRow: wt.rowSpec = {
		name = "ButtonRow",
		order = 9000, -- Ensure it's at the bottom
		height = UDim.new(0, 30),
		tileSpecs = { closeButtonLeavingroom },
		horizontalAlignment = Enum.HorizontalAlignment.Right,
	}
	return lastRow
end

local function createDataRow(userFinishedRunResponse: tt.userFinishedRunResponse): wt.rowSpec
	local res: { wt.tileSpec } = {}
	local meRunsText = string.format("You've run %d times", userFinishedRunResponse.userRaceStats.userRaceRunCount)
	if userFinishedRunResponse.userRaceStats.userRaceRunCount == 1 then
		meRunsText = "You've run once"
	end
	local mySpec: wt.textTileSpec = {
		type = "text",
		text = meRunsText,
		isMonospaced = false,
		isBold = false,
		backgroundColor = colors.meColor,
		textColor = colors.black,
		textXAlignment = Enum.TextXAlignment.Center,
	}
	local meTile: wt.tileSpec = {
		name = "meRunCount",
		order = 1,
		width = UDim.new(0.25, 0),
		spec = mySpec,
	}
	table.insert(res, meTile)

	local racersText = string.format("%d racers", userFinishedRunResponse.userRaceStats.totalRacersOfThisRaceCount)
	if userFinishedRunResponse.userRaceStats.totalRacersOfThisRaceCount == 1 then
		racersText = "1 racer"
	end

	local racersSpec: wt.textTileSpec = {
		type = "text",
		text = racersText,
		isMonospaced = false,
		isBold = false,
		backgroundColor = colors.defaultGrey,
		textColor = colors.black,
		textXAlignment = Enum.TextXAlignment.Center,
	}

	local racersTile: wt.tileSpec = {
		name = "Racers",
		order = 3,
		width = UDim.new(0.1, 0),
		spec = racersSpec,
	}
	table.insert(res, racersTile)

	-- Determine race level
	local raceLevelText = "normal"
	if userFinishedRunResponse.userRaceStats.totalRacersOfThisRaceCount > 1000 then
		raceLevelText = "mega"
	elseif userFinishedRunResponse.userRaceStats.totalRacersOfThisRaceCount > 100 then
		raceLevelText = "competitive2"
	elseif userFinishedRunResponse.userRaceStats.totalRacersOfThisRaceCount > 10 then
		raceLevelText = "competitive"
	end

	local compSpec: wt.textTileSpec = {
		type = "text",
		text = raceLevelText,
		isMonospaced = false,
		isBold = false,
		backgroundColor = colors.defaultGrey,
		textColor = colors.black,
		textXAlignment = Enum.TextXAlignment.Center,
	}

	local compTile: wt.tileSpec = {
		name = "CompetitionLevel",
		order = 2,
		width = UDim.new(0.19, 0),
		spec = compSpec,
	}
	table.insert(res, compTile)

	local otherRunsText = string.format("%d runs total", userFinishedRunResponse.userRaceStats.totalRunsOfThisRaceCount)
	local otherRunsSpec: wt.textTileSpec = {
		type = "text",
		text = otherRunsText,
		isMonospaced = false,
		isBold = false,
		backgroundColor = colors.defaultGrey,
		textColor = colors.black,
		textXAlignment = Enum.TextXAlignment.Center,
	}
	local otherRunsTile: wt.tileSpec = {
		name = "OtherRuns",
		order = 4,
		width = UDim.new(0.1, 0),
		spec = otherRunsSpec,
	}
	table.insert(res, otherRunsTile)

	local distText = string.format("%0.1fd", userFinishedRunResponse.raceInfo.distance)
	local distSpec: wt.textTileSpec = {
		type = "text",
		text = distText,
		isMonospaced = true,
		isBold = false,
		backgroundColor = colors.defaultGrey,
		textColor = colors.black,
		textXAlignment = Enum.TextXAlignment.Center,
	}

	local distTile: wt.tileSpec = {
		name = "Distance",
		order = 7,
		width = UDim.new(0.1, 0),
		spec = distSpec,
	}
	table.insert(res, distTile)

	if userFinishedRunResponse.runUserJustDid and userFinishedRunResponse.runUserJustDid.runMilliseconds > 0 then
		local spdText = string.format(
			"%0.1fd/s",
			userFinishedRunResponse.raceInfo.distance / userFinishedRunResponse.runUserJustDid.runMilliseconds * 1000
		)
		local spdSpec: wt.textTileSpec = {
			type = "text",
			text = spdText,
			isMonospaced = true,
			isBold = false,
			backgroundColor = colors.defaultGrey,
			textColor = colors.black,
			textXAlignment = Enum.TextXAlignment.Center,
		}
		local spdTile: wt.tileSpec = {
			name = "Speed",
			order = 5,
			width = UDim.new(0.12, 0),
			spec = spdSpec,
		}
		table.insert(res, spdTile)
	end

	local row: wt.rowSpec = {
		name = "DataRow",
		order = 2,
		height = UDim.new(0, 45),
		tileSpecs = res,
	}

	return row
end

local function createJsonRunRow(jsonBestRun: tt.jsonBestRun, useColor: Color3): wt.rowSpec
	local tileSpecs: { wt.tileSpec } = {}

	for _, columnSpec in ipairs(columnSpecs) do
		local tileSpecShell: any = {
			name = columnSpec.name,
			order = columnSpec.order,
			width = columnSpec.width,
		}

		if columnSpec.name == "Place" then
			local usePlace = tostring(jsonBestRun.place)
			if jsonBestRun.place == 0 then
				usePlace = "-"
			end
			tileSpecShell.spec = {
				type = "text",
				text = usePlace,
				backgroundColor = useColor,
				textColor = colors.black,
				isMonospaced = false,
				isBold = false,
				textXAlignment = Enum.TextXAlignment.Center,
			}
		elseif columnSpec.name == "Portrait" then
			tileSpecShell.spec = {
				type = "portrait",
				userId = jsonBestRun.userId,
				doPopup = true,
				backgroundColor = useColor,
				width = UDim.new(0, generalRowHeight),
			}
		elseif columnSpec.name == "Username" then
			tileSpecShell.spec = {
				type = "text",
				text = jsonBestRun.username,
				backgroundColor = useColor,
				textColor = colors.black,
				isMonospaced = false,
				isBold = false,
				textXAlignment = Enum.TextXAlignment.Left,
			}
		elseif columnSpec.name == "Time" then
			tileSpecShell.spec = {
				type = "text",
				text = tpUtil.fmtms(jsonBestRun.runMilliseconds) .. " ",
				backgroundColor = useColor,
				textColor = colors.black,
				isMonospaced = true,
				isBold = false,
				textXAlignment = Enum.TextXAlignment.Right,
			}
			tileSpecShell.tooltipText = formatRunAgeTooltip(jsonBestRun.runAgeSeconds)
		end

		table.insert(tileSpecs, tileSpecShell)
	end

	return {
		name = string.format("RunEntry_%s", jsonBestRun.username),
		height = UDim.new(0, generalRowHeight),
		order = jsonBestRun.runMilliseconds,
		tileSpecs = tileSpecs,
	}
end

local function createRelationshipRow(userFinishedRunResponse: tt.userFinishedRunResponse): wt.rowSpec
	local tileSpecs: { wt.tileSpec } = {}

	-- WR Progression button
	table.insert(tileSpecs, createWRProgressionButton(userFinishedRunResponse))
	table.insert(tileSpecs, createInverseTop10Button(userFinishedRunResponse))
	table.insert(tileSpecs, createWarpButton(userFinishedRunResponse))
	table.insert(tileSpecs, createPinRaceButton(userFinishedRunResponse))
	table.insert(tileSpecs, createFavoriteRaceButton(userFinishedRunResponse))

	-- Pin Race button

	return {
		name = "RelationshipRow",
		order = 3,
		height = UDim.new(0, generalRowHeight),
		tileSpecs = tileSpecs,
	}
end

local function createTimeRow(userFinishedRunResponse: tt.userFinishedRunResponse): wt.rowSpec
	local tileSpecs: { wt.tileSpec } = {}

	if userFinishedRunResponse.runUserJustDid then
		-- Time display
		table.insert(tileSpecs, {
			name = "TimeDisplay",
			order = 1,
			width = UDim.new(0.5, 0),
			spec = {
				type = "text",
				text = string.format("%0.3fs", userFinishedRunResponse.runUserJustDid.runMilliseconds / 1000),
				isMonospaced = true,
				isBold = true,
				backgroundColor = colors.meColor,
				textColor = colors.black,
				textXAlignment = Enum.TextXAlignment.Center,
			},
		})
		-- Your text display is actually not really calculable using the interleaving stuff from dynamic til I think about a better way to do it.
		if false and true then
			table.insert(tileSpecs, {
				name = "YourTextDisplay",
				order = 2,
				width = UDim.new(0.5, 0),
				spec = {
					type = "text",
					text = userFinishedRunResponse.runUserJustDid.yourText,
					isMonospaced = false,
					isBold = false,
					backgroundColor = userFinishedRunResponse.runUserJustDid.yourColor,
					textColor = colors.black,
					textXAlignment = Enum.TextXAlignment.Center,
				},
			})
		end
	end

	return {
		name = "TimeRow",
		order = 4,
		height = UDim.new(0, generalRowHeight),
		tileSpecs = tileSpecs,
	}
end

------------- The actual drawing function -----------------------------

module.DrawRunResultsGui = function(userFinishedRunResponse: tt.userFinishedRunResponse)
	if not globalSettingShowRunResultPopups then
		_annotate("not showing popups for this user due to setting")
		return
	end

	local guiSpec: wt.guiSpec = {
		name = "RaceResult",
		rowSpecs = {},
	}

	table.insert(guiSpec.rowSpecs, {
		name = "Title",
		order = 1,
		height = UDim.new(0, 60),
		tileSpecs = {
			{
				name = "RaceTitle",
				order = 1,
				width = UDim.new(1, 0),
				spec = {
					type = "text",
					text = userFinishedRunResponse.raceInfo.raceName,
					backgroundColor = colors.signColor,
					textColor = colors.white,
					isBold = true,
					textXAlignment = Enum.TextXAlignment.Center,
					includeTextSizeConstraint = false,
				},
			},
		},
	})

	if userFinishedRunResponse.runUserJustDid and userFinishedRunResponse.runUserJustDid.runMilliseconds then
		local timeRow = createTimeRow(userFinishedRunResponse)
		table.insert(guiSpec.rowSpecs, timeRow)
	end

	local relationshipRow = createRelationshipRow(userFinishedRunResponse)
	table.insert(guiSpec.rowSpecs, relationshipRow)

	local dataRow = createDataRow(userFinishedRunResponse)
	table.insert(guiSpec.rowSpecs, dataRow)

	-- Create a scrolling frame for user entries
	local scrollingFrameSpec: wt.scrollingFrameTileSpec = {
		name = "UserEntriesScrollingFrame",
		type = "scrollingFrameTileSpec",
		headerRow = {
			name = "HeaderRow",
			order = 1,
			height = UDim.new(0, generalRowHeight),
			tileSpecs = columnSpecs,
		},
		dataRows = {},
		stickyRows = {},
		rowHeight = generalRowHeight,
		howManyRowsToShow = 1,
	}

	local alreadyShownUserIds: { [number]: boolean } = {}

	-- Add race best runs to the scrolling frame
	for _, jsonBestRun in ipairs(userFinishedRunResponse.raceBestRuns) do
		if not jsonBestRun.place then
			annotater.Error(
				"a jsonBestRun showed up without any place. probably failed pathinc it",
				userFinishedRunResponse.userId,
				jsonBestRun
			)

			continue
		end

		local useColor = colors.defaultGrey
		if jsonBestRun.userId == userFinishedRunResponse.userId then
			if userFinishedRunResponse.runUserJustDid then
				if jsonBestRun.runId == userFinishedRunResponse.runUserJustDid.runId then
					-- this only happens if we just did this AND it beat (which means that our past run won't even appear?)
					useColor = colors.meColor
				else
					-- this is when you did just do a run, but another run is your best, so your just now run will appear below in otherRuns.
					useColor = colors.mePastColor
				end
			else
				-- if we are just browsing runs, this past run is ours, so meColor
				useColor = colors.meColor
			end
		elseif alreadyShownUserIds[jsonBestRun.userId] then
			useColor = colors.otherGuyPresentColor
		end

		alreadyShownUserIds[jsonBestRun.userId] = true

		local rowSpec = createJsonRunRow(jsonBestRun, useColor)
		if rowSpec then
			if jsonBestRun.place == 0 then
				table.insert(scrollingFrameSpec.stickyRows, rowSpec)
			elseif jsonBestRun.userId == userFinishedRunResponse.userId then
				table.insert(scrollingFrameSpec.stickyRows, rowSpec)
			else
				table.insert(scrollingFrameSpec.dataRows, rowSpec)
			end
		end
	end

	-- Add extra best runs to the scrolling frame
	-- if it's the same user it's complex.
	for index, jsonBestRun in ipairs(userFinishedRunResponse.extraBestRuns) do
		if jsonBestRun.userId ~= userFinishedRunResponse.userId and alreadyShownUserIds[jsonBestRun.userId] then
			continue
		end

		local useColor

		-- the system doesn't actually clearly tell you if a run showing up in extraBestRuns was your old time which you jsut beat (and hence should be blue/old)
		-- vs your new time.
		if jsonBestRun.userId == userFinishedRunResponse.userId then
			if jsonBestRun.runAgeSeconds < 4 then
				useColor = colors.meColor
			else
				useColor = colors.otherGuyPresentColor
			end
		else
			useColor = colors.otherGuyPresentColor
		end

		local rowSpec = createJsonRunRow(jsonBestRun, useColor)
		if rowSpec then
			if jsonBestRun.place == 0 then
				table.insert(scrollingFrameSpec.stickyRows, rowSpec)
			elseif jsonBestRun.userId == userFinishedRunResponse.userId then
				table.insert(scrollingFrameSpec.stickyRows, rowSpec)
			else
				table.insert(scrollingFrameSpec.dataRows, rowSpec)
			end
		end
	end

	-- Sort the dataRows based on the runMilliseconds
	table.sort(scrollingFrameSpec.dataRows, function(a, b)
		return a.order < b.order
	end)

	table.sort(scrollingFrameSpec.stickyRows, function(a, b)
		return a.order < b.order
	end)

	local maxIntendedRowsOfScrollingFrameToShow = 12
	if globalSettingShrinkRunResultPopups then
		maxIntendedRowsOfScrollingFrameToShow = 4
	end
	local actualRowsAvailable = #scrollingFrameSpec.dataRows + #scrollingFrameSpec.stickyRows
	local usingHowManyRowsToShow = math.min(actualRowsAvailable + 1, maxIntendedRowsOfScrollingFrameToShow)
	-- +1 for the header
	local scrollFramePixelHeight: number = usingHowManyRowsToShow * generalRowHeight

	scrollingFrameSpec.howManyRowsToShow = usingHowManyRowsToShow
	_annotate(string.format("set howManyRowsToShow to %d", usingHowManyRowsToShow))

	local totalHeight = scrollFramePixelHeight + 171
	if userFinishedRunResponse.runUserJustDid and userFinishedRunResponse.runUserJustDid.runMilliseconds then
		totalHeight = totalHeight + 36
	end
	_annotate(string.format("set totalHeight to %d", totalHeight))

	-- Add the scrolling frame to the guiSpec
	table.insert(guiSpec.rowSpecs, {
		name = "ScrollingFrameRow",
		order = 5,
		height = UDim.new(0, scrollFramePixelHeight),
		tileSpecs = {
			{
				name = "ScrollingFrameContainer",
				order = 1,
				width = UDim.new(1, 0),
				spec = scrollingFrameSpec,
			},
		},
	})

	local buttonRow = createLastRow()
	table.insert(guiSpec.rowSpecs, buttonRow)

	local runResultsFrameOuterName = string.format("RunResults-%s", userFinishedRunResponse.raceInfo.raceName)

	local raceResultSgui = windows.CreatePopup(
		guiSpec,
		runResultsFrameOuterName,
		true, -- draggable
		false, -- resizable
		false, -- minimizable
		true, -- pinnable
		true, -- dismissableWithX
		false, -- dismissableByClick
		UDim2.new(0.27, 0, 0, totalHeight),
		maxIntendedRowsOfScrollingFrameToShow
	)
	local outerFrame = raceResultSgui:FindFirstChildOfClass("Frame")
	if outerFrame then
		if theLastGui then --if the last gui lives, we prefer that.
			local lastGuiOuterFrame = theLastGui:FindFirstChildOfClass("Frame")
			if lastGuiOuterFrame then
				_annotate("\tRunResult positioning: set outerFrame.Position to lastGuiOuterFrame.Position")
				theLastGuiPosition = lastGuiOuterFrame.Position
				outerFrame.Position = theLastGuiPosition
			else
				if theLastGuiPosition then --if its been closed, then just use that.
					outerFrame.Position = theLastGuiPosition
					_annotate("\tRunResult positioning: set outerFrame.Position to theLastGuiPosition")
				else
					_annotate(
						"\tRunResult positioning: no lastGuiOuterFrame found, AND no lastGuiPosition so default.."
					)
					outerFrame.Position = UDim2.new(0.70, -5, 0.18, 0) --the default. end
				end
			end
		elseif theLastGuiPosition then --if its been closed, then just use that.
			outerFrame.Position = theLastGuiPosition
			_annotate("set outerFrame.Position to theLastGuiPosition")
		else
			outerFrame.Position = UDim2.new(0.70, -5, 0.18, 0) --the default.
			_annotate("\tRunResult positioning: outerFrame.Position to default")
		end
	else
		_annotate("\tRunResult positioning: no outerFrame found")
	end

	if globalSettingOnlyHaveOneRunResultPopupAtATime then
		if theLastGui then
			_annotate("\tRunResult positioning: destroy lastGui")
			theLastGui:Destroy()
			theLastGui = nil
		end
	end

	if theLastGui then
		local outerFrame2 = raceResultSgui:FindFirstChildOfClass("Frame")
		if outerFrame2 then
			_annotate("\tRunResult positioning: set lastGuiPosition to", outerFrame2.Position)
			theLastGuiPosition = outerFrame2.Position
		end
	end

	_annotate("\tRunResult positioning: set lastGui to", raceResultSgui.Name)
	theLastGui = raceResultSgui

	local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	raceResultSgui.Parent = playerGui
end

--------------------- SETTINGS MANAGEMENT -----------------------------

local function handleUserSettingChanged(item: tt.userSettingValue)
	if item.name == settingEnums.settingDefinitions.HIGHLIGHT_ON_RUN_COMPLETE_WARP.name then
		userWantsHighlightingWhenWarpingFromRunResults = item.booleanValue or false
	elseif item.name == settingEnums.settingDefinitions.SHOW_RUN_RESULT_POPUPS.name then
		globalSettingShowRunResultPopups = item.booleanValue or false
	elseif item.name == settingEnums.settingDefinitions.SHRINK_RUN_RESULT_POPUPS.name then
		globalSettingShrinkRunResultPopups = item.booleanValue or false
	elseif item.name == settingEnums.settingDefinitions.ONLY_HAVE_ONE_RUN_RESULT_POPUP_AT_A_TIME.name then
		globalSettingOnlyHaveOneRunResultPopupAtATime = item.booleanValue or false
	end
	return
end

module.Init = function()
	_annotate("init")
	settings.RegisterFunctionToListenForSettingName(
		handleUserSettingChanged,
		settingEnums.settingDefinitions.HIGHLIGHT_ON_RUN_COMPLETE_WARP.name,
		"drawRunResultGui"
	)

	local highlightOnRunCompleteWarpSettingValue =
		settings.GetSettingByName(settingEnums.settingDefinitions.HIGHLIGHT_ON_RUN_COMPLETE_WARP.name)
	handleUserSettingChanged(highlightOnRunCompleteWarpSettingValue)

	settings.RegisterFunctionToListenForSettingName(
		handleUserSettingChanged,
		settingEnums.settingDefinitions.SHOW_RUN_RESULT_POPUPS.name,
		"drawRunResultGui"
	)

	local popupsSettingValue = settings.GetSettingByName(settingEnums.settingDefinitions.SHOW_RUN_RESULT_POPUPS.name)
	handleUserSettingChanged(popupsSettingValue)

	settings.RegisterFunctionToListenForSettingName(
		handleUserSettingChanged,
		settingEnums.settingDefinitions.SHRINK_RUN_RESULT_POPUPS.name,
		"drawRunResultGui"
	)

	local shrinkRunResultPopupsSettingValue =
		settings.GetSettingByName(settingEnums.settingDefinitions.SHRINK_RUN_RESULT_POPUPS.name)
	handleUserSettingChanged(shrinkRunResultPopupsSettingValue)

	settings.RegisterFunctionToListenForSettingName(
		handleUserSettingChanged,
		settingEnums.settingDefinitions.ONLY_HAVE_ONE_RUN_RESULT_POPUP_AT_A_TIME.name,
		"drawRunResultGui"
	)

	local onlyHaveOneRunResultPopupAtATimeSettingValue =
		settings.GetSettingByName(settingEnums.settingDefinitions.ONLY_HAVE_ONE_RUN_RESULT_POPUP_AT_A_TIME.name)
	handleUserSettingChanged(onlyHaveOneRunResultPopupAtATimeSettingValue)

	_annotate("init done")
end

_annotate("end")
return module
