--!strict

-- DrawRunResultGui (ReplicatedStorage.gui.runresults.drawRunResultGui)
-- Creates the race result UI for player LocalScripts.
-- Builds interactive tiles so players can warp, pin, or favourite runs.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local Players = game:GetService("Players")
local _UserInputService = game:GetService("UserInputService")
local localPlayer = Players.LocalPlayer
if not localPlayer then
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	localPlayer = Players.LocalPlayer
end

local _standardButton = require(game.ReplicatedStorage.gui.standardButton)
local settings = require(game.ReplicatedStorage.settings)
local tt = require(game.ReplicatedStorage.types.gametypes)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local colors = require(game.ReplicatedStorage.util.colors)
local enums = require(game.ReplicatedStorage.util.enums)
local friendshipCache = require(game.ReplicatedStorage.util.friendshipCache)
local remotes = require(game.ReplicatedStorage.util.remotes)
local tpUtil: typeof(require(game.ReplicatedStorage.util.tpUtil)) = require(game.ReplicatedStorage.util.tpUtil)
local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)
local wt = require(game.StarterPlayer.StarterPlayerScripts.guis.windowsTypes)
local fonts = require(game.StarterPlayer.StarterPlayerScripts.guis.fonts)
local warper = require(game.StarterPlayer.StarterCharacterScripts.client.warper)
local yourRunsPopup = require(game.ReplicatedStorage.gui.yourRunsPopup)

type Module = {
	DrawRunResultGui: (tt.userFinishedRunResponse) -> (),
	Init: () -> (),
}

-- Module internals
local GenericClientUIFunction = remotes.getRemoteFunction("GenericClientUIFunction")
local userWantsHighlightingWhenWarpingFromRunResults = false
local globalSettingShowRunResultPopups = true
local globalSettingShrinkRunResultPopups = false
local globalSettingOnlyHaveOneRunResultPopupAtATime = false
local globalSettingHighlightTimeDigits = false
local generalRowHeight = 36
local basePopupHeight = 171
local _inputEndedConnection: RBXScriptConnection? = nil

-- Base width as proportion of screen, height is calculated per-race
local naturalBaseWidthScale = 0.27

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
			textScaled = false,
			textSize = 18,
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
			textScaled = false,
			testSize = 18,
		},
	},
	{
		name = "Time",
		order = 4,
		width = UDim.new(5, 0),
		spec = {
			type = "text",
			text = "Time",
			isMonospaced = true,
			isBold = false,
			backgroundColor = colors.blueDone,
			textColor = colors.black,
			textXAlignment = Enum.TextXAlignment.Center,
			textScaled = false,
			textSize = 18,
		},
	},
}

------------- GUI HELPERS -----------------------------

local function formatRunAgeTooltip(runAgeSeconds: number): string
	local formattedRunAge, _ageDescriptor = tpUtil.formatDateGap(runAgeSeconds)
	return string.format("Run age: %s", formattedRunAge)
end

-- Build tooltip showing sign name with its alias (for command input discoverability)
-- Returns the formatted text and whether an alias was added
local function formatSignNameWithAlias(signName: string): (string, boolean)
	local alias = enums.signName2Alias[signName]
	if alias then
		return string.format("%s (%s)", signName, alias), true
	end
	return signName, false
end

-- Build tooltip for race title showing both sign names with aliases
-- Returns nil if neither sign has an alias (tooltip not needed)
local function formatRaceTitleTooltip(startSignId: number, endSignId: number): string?
	local startSignName = enums.signId2name[startSignId] or "?"
	local endSignName = enums.signId2name[endSignId] or "?"

	local startText, startHasAlias = formatSignNameWithAlias(startSignName)
	local endText, endHasAlias = formatSignNameWithAlias(endSignName)

	-- Only show tooltip if at least one sign has an alias worth discovering
	if not startHasAlias and not endHasAlias then
		return nil
	end

	return string.format("%s → %s", startText, endText)
end

local function requestPinRace(startSignId: number, endSignId: number)
	local req = {
		eventKind = "pinRaceRequest",
		data = {
			startSignId = startSignId,
			endSignId = endSignId,
		},
	}
	local response = GenericClientUIFunction:InvokeServer(req)

	-- Update client cache from server response
	if response and response.success and response.setting then
		settings.SetSetting(response.setting)
	end
end

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

local function requestWRProgressionChart(startSignId: number, endSignId: number)
	local success = GenericClientUIFunction:InvokeServer({
		eventKind = "wrProgressionChartRequest",
		data = {
			startSignId = startSignId,
			endSignId = endSignId,
		},
	})

	if not success then
		warn("Failed to request WR progression chart")
	end
end

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

local function createReverseTop10Button(options: tt.userFinishedRunResponse): wt.tileSpec
	local x: wt.tileSpec = {
		name = "ReverseTop10",
		order = 2,
		width = UDim.new(1, 0),
		spec = {
			type = "button",
			text = "Reverse Top 10",
			backgroundColor = colors.WRProgressionColor,
			textColor = colors.black,
			isMonospaced = false,
			isBold = false,
			textSize = 14,
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
			textSize = 14,
			textXAlignment = Enum.TextXAlignment.Center,
			onClick = function()
				requestWRProgression(options.raceInfo.startSignId, options.raceInfo.endSignId)
			end,
		},
	}
	return x
end

local function createWRChartButton(options: tt.userFinishedRunResponse): wt.tileSpec
	local x: wt.tileSpec = {
		name = "WRChart",
		order = 6, -- After favorite button
		width = UDim.new(1, 0),
		spec = {
			type = "button",
			text = "Chart",
			backgroundColor = colors.greenGo,
			textColor = colors.black,
			isMonospaced = false,
			isBold = false,
			textSize = 14,
			textXAlignment = Enum.TextXAlignment.Center,
			onClick = function()
				requestWRProgressionChart(options.raceInfo.startSignId, options.raceInfo.endSignId)
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
			textSize = 14,
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
		text = canHighlight and string.format("Warp to %s", enums.signId2name[userFinishedRunResponse.raceInfo.startSignId]) or "Warp",
		backgroundColor = colors.warpColor,
		textColor = colors.black,
		isMonospaced = false,
		isBold = false,
		textXAlignment = Enum.TextXAlignment.Center,
		textSize = 14,
		onClick = function(_: InputObject, _2: TextButton)
			if canHighlight then
				local useLastRunEnd = userWantsHighlightingWhenWarpingFromRunResults and tpUtil.SignCanBeHighlighted(tpUtil.signId2Sign(userFinishedRunResponse.raceInfo.endSignId)) and userFinishedRunResponse.raceInfo.endSignId or nil
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
			textSize = 14,
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

-- Custom close button
local closeButtonTileSpec = windows.CreateCloseButtonTileSpec(nil)

local function createLastRow(): wt.rowSpec
	local lastRow: wt.rowSpec = {
		name = "ButtonRow",
		order = 9000, -- Ensure it's at the bottom
		height = UDim.new(30, 0), -- Proportional weight for resizable layout
		tileSpecs = { closeButtonTileSpec },
		horizontalAlignment = Enum.HorizontalAlignment.Right,
	}
	return lastRow
end

-- Creates the meTile with hover behavior for showing user's runs
local function createMeTileWithHover(userFinishedRunResponse: tt.userFinishedRunResponse): wt.tileSpec
	local stats = userFinishedRunResponse.userRaceStats
	local meRunsText = string.format("Your Runs: %d", stats.userRaceRunCount)

	local mySpec: wt.textTileSpec = {
		type = "text",
		text = meRunsText,
		isMonospaced = false,
		isBold = false,
		backgroundColor = colors.meColor,
		textColor = colors.black,
		textXAlignment = Enum.TextXAlignment.Center,
		textSize = 14,
	}

	local startSignId = userFinishedRunResponse.raceInfo.startSignId
	local endSignId = userFinishedRunResponse.raceInfo.endSignId

	local meTile: wt.tileSpec = {
		name = "meRunCount",
		order = 1,
		width = UDim.new(0.25, 0),
		spec = mySpec,
		onCreate = function(element: GuiObject)
			local textLabel = element :: TextLabel
			textLabel.Active = true
			yourRunsPopup.SetupHover(textLabel, startSignId, endSignId)
			_annotate("Set up hover behavior on meRunCount tile via onCreate")
		end,
	}

	return meTile
end

local function createDataRow(userFinishedRunResponse: tt.userFinishedRunResponse): wt.rowSpec
	local stats = userFinishedRunResponse.userRaceStats
	local res: { wt.tileSpec } = table.create(6)

	-- Create meTile with hover behavior (hover setup via onCreate callback in tileSpec)
	local meTile = createMeTileWithHover(userFinishedRunResponse)
	res[#res + 1] = meTile

	local racersText = string.format("%d racers", stats.totalRacersOfThisRaceCount)
	if stats.totalRacersOfThisRaceCount == 1 then
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
		textSize = 14,
	}

	-- Order: Your Runs (1), racers (2), total runs (3), distance (4), competition level (5), speed (6)
	local racersTile: wt.tileSpec = {
		name = "Racers",
		order = 2,
		width = UDim.new(0.1, 0),
		spec = racersSpec,
	}
	res[#res + 1] = racersTile

	local totalRunsText = string.format("%d total runs", stats.totalRunsOfThisRaceCount)
	local totalRunsSpec: wt.textTileSpec = {
		type = "text",
		text = totalRunsText,
		isMonospaced = false,
		isBold = false,
		backgroundColor = colors.defaultGrey,
		textColor = colors.black,
		textXAlignment = Enum.TextXAlignment.Center,
		textSize = 14,
	}
	local totalRunsTile: wt.tileSpec = {
		name = "TotalRuns",
		order = 3,
		width = UDim.new(0.1, 0),
		spec = totalRunsSpec,
	}
	res[#res + 1] = totalRunsTile

	local distText = string.format("%0.1fd", userFinishedRunResponse.raceInfo.distance)
	local distSpec: wt.textTileSpec = {
		type = "text",
		text = distText,
		isMonospaced = true,
		isBold = false,
		backgroundColor = colors.defaultGrey,
		textColor = colors.black,
		textXAlignment = Enum.TextXAlignment.Center,
		textSize = 14,
	}

	local distTile: wt.tileSpec = {
		name = "Distance",
		order = 4,
		width = UDim.new(0.1, 0),
		spec = distSpec,
	}
	res[#res + 1] = distTile

	-- Determine race level
	local raceLevelText = "normal"
	if stats.totalRacersOfThisRaceCount > 1000 then
		raceLevelText = "mega"
	elseif stats.totalRacersOfThisRaceCount > 100 then
		raceLevelText = "competitive2"
	elseif stats.totalRacersOfThisRaceCount > 10 then
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
		textSize = 14,
	}

	local compTile: wt.tileSpec = {
		name = "CompetitionLevel",
		order = 5,
		width = UDim.new(0.19, 0),
		spec = compSpec,
	}
	res[#res + 1] = compTile

	if userFinishedRunResponse.runUserJustDid and userFinishedRunResponse.runUserJustDid.runMilliseconds > 0 then
		local spdText = string.format("%0.1fd/s", userFinishedRunResponse.raceInfo.distance / userFinishedRunResponse.runUserJustDid.runMilliseconds * 1000)
		local spdSpec: wt.textTileSpec = {
			type = "text",
			text = spdText,
			isMonospaced = true,
			isBold = false,
			backgroundColor = colors.defaultGrey,
			textColor = colors.black,
			textXAlignment = Enum.TextXAlignment.Center,
			textSize = 14,
		}
		local spdTile: wt.tileSpec = {
			name = "Speed",
			order = 6,
			width = UDim.new(0.12, 0),
			spec = spdSpec,
		}
		res[#res + 1] = spdTile
	end

	local row: wt.rowSpec = {
		name = "DataRow",
		order = 2,
		height = UDim.new(45, 0), -- Proportional weight for resizable layout
		tileSpecs = res,
	}

	return row
end

local function createJsonRunRow(jsonBestRun: tt.jsonBestRun, useColor: Color3, isJustNow: boolean?, previousTimeText: string?): wt.rowSpec
	local tileSpecs: { wt.tileSpec } = table.create(#columnSpecs)
	local currentTimeText = tpUtil.fmtms(jsonBestRun.runMilliseconds)

	for index, columnSpec in ipairs(columnSpecs) do
		local tileSpecShell: wt.tileSpec

		if columnSpec.name == "Place" then
			local usePlace = tostring(jsonBestRun.place)
			if jsonBestRun.place == 0 then
				usePlace = "-"
			end
			tileSpecShell = {
				name = columnSpec.name,
				order = columnSpec.order,
				width = columnSpec.width,
				spec = {
					type = "text",
					text = usePlace,
					backgroundColor = useColor,
					textColor = colors.black,
					isMonospaced = false,
					isBold = false,
					textXAlignment = Enum.TextXAlignment.Center,
					textScaled = false,
					textSize = 18,
				},
			}
		elseif columnSpec.name == "Portrait" then
			tileSpecShell = {
				name = columnSpec.name,
				order = columnSpec.order,
				width = columnSpec.width,
				spec = {
					type = "portrait",
					userId = jsonBestRun.userId,
					doPopup = true,
					backgroundColor = useColor,
					width = UDim.new(0, generalRowHeight),
				},
			}
		elseif columnSpec.name == "Username" then
			local displayName = jsonBestRun.username
			if isJustNow then
				displayName = displayName .. " (just now)"
			end
			tileSpecShell = {
				name = columnSpec.name,
				order = columnSpec.order,
				width = columnSpec.width,
				spec = {
					type = "text",
					text = displayName,
					backgroundColor = useColor,
					textColor = colors.black,
					isMonospaced = false,
					isBold = false,
					textXAlignment = Enum.TextXAlignment.Left,
					textScaled = false,
					textSize = 18,
				},
			}
		elseif columnSpec.name == "Time" then
			-- Use digit highlighting if enabled and we have a previous time to compare
			-- Times are fixed-size (textScaled=false) for row-to-row comparability
			if globalSettingHighlightTimeDigits and previousTimeText then
				tileSpecShell = {
					name = columnSpec.name,
					order = columnSpec.order,
					width = columnSpec.width,
					spec = {
						type = "digitHighlightedTime",
						text = currentTimeText,
						previousText = previousTimeText,
						backgroundColor = useColor,
						textColor = colors.black,
						textXAlignment = Enum.TextXAlignment.Right,
					},
					tooltipText = formatRunAgeTooltip(jsonBestRun.runAgeSeconds),
				}
			else
				-- Plain text time display (default or first row)
				tileSpecShell = {
					name = columnSpec.name,
					order = columnSpec.order,
					width = columnSpec.width,
					spec = {
						type = "text",
						text = currentTimeText,
						backgroundColor = useColor,
						textColor = colors.black,
						isMonospaced = true,
						isBold = false,
						textXAlignment = Enum.TextXAlignment.Right,
						textScaled = false,
						textSize = 18,
						rightPadding = 3,
					},
					tooltipText = formatRunAgeTooltip(jsonBestRun.runAgeSeconds),
				}
			end
		else
			tileSpecShell = columnSpec
		end

		tileSpecs[index] = tileSpecShell
	end

	-- Add grey scrollbar padding spacer on the right
	local scrollbarPaddingTile: wt.tileSpec = {
		name = "ScrollbarPadding",
		order = 5,
		width = UDim.new(0, 10),
		spec = {
			type = "text",
			text = "",
			backgroundColor = colors.defaultGrey,
		},
	}
	tileSpecs[#tileSpecs + 1] = scrollbarPaddingTile

	return {
		name = string.format("RunEntry_%s", jsonBestRun.username),
		height = UDim.new(0, generalRowHeight), -- Fixed pixels, scaled dynamically by scrolling frame
		order = jsonBestRun.runMilliseconds,
		tileSpecs = tileSpecs,
		timeText = currentTimeText, -- Store for next row comparison
	}
end

local function createRelationshipRow(userFinishedRunResponse: tt.userFinishedRunResponse): wt.rowSpec
	local tileSpecs: { wt.tileSpec } = {}

	-- Action buttons row
	table.insert(tileSpecs, createWRProgressionButton(userFinishedRunResponse))
	table.insert(tileSpecs, createReverseTop10Button(userFinishedRunResponse))
	table.insert(tileSpecs, createWarpButton(userFinishedRunResponse))
	table.insert(tileSpecs, createFavoriteRaceButton(userFinishedRunResponse))
	table.insert(tileSpecs, createWRChartButton(userFinishedRunResponse))

	return {
		name = "RelationshipRow",
		order = 3,
		height = UDim.new(generalRowHeight, 0), -- Proportional weight for resizable layout
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
				textScaled = false,
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
		height = UDim.new(generalRowHeight * 2, 0), -- Proportional weight for resizable layout
		tileSpecs = tileSpecs,
	}
end

------------- The actual drawing function -----------------------------

local function drawRunResultGui(userFinishedRunResponse: tt.userFinishedRunResponse)
	if not globalSettingShowRunResultPopups then
		_annotate("not showing popups for this user due to setting")
		return
	end

	local raceInfo = userFinishedRunResponse.raceInfo
	local runJustDid = userFinishedRunResponse.runUserJustDid
	local targetUserId = userFinishedRunResponse.userId

	local guiSpec: wt.guiSpec = {
		name = "RaceResult",
		rowSpecs = {},
	}

	guiSpec.rowSpecs[#guiSpec.rowSpecs + 1] = {
		name = "Title",
		order = 1,
		height = UDim.new(60, 0), -- Proportional weight for resizable layout
		tileSpecs = {
			{
				name = "RaceTitle",
				order = 1,
				width = UDim.new(1, 0),
				spec = {
					type = "text",
					text = raceInfo.raceName,
					backgroundColor = colors.signColor,
					textColor = colors.white,
					isBold = true,
					textXAlignment = Enum.TextXAlignment.Center,
				},
				tooltipText = formatRaceTitleTooltip(raceInfo.startSignId, raceInfo.endSignId), -- nil if no aliases
				tooltipStyle = {
					backgroundColor = colors.signColor,
					textColor = colors.white, -- Match title row exactly
					fontFace = fonts.GetFont(false, true), -- Merriweather Bold, same as title
				},
			},
		},
	}

	if runJustDid and runJustDid.runMilliseconds then
		local timeRow = createTimeRow(userFinishedRunResponse)
		guiSpec.rowSpecs[#guiSpec.rowSpecs + 1] = timeRow
	end

	local relationshipRow = createRelationshipRow(userFinishedRunResponse)
	guiSpec.rowSpecs[#guiSpec.rowSpecs + 1] = relationshipRow

	local dataRow = createDataRow(userFinishedRunResponse)
	guiSpec.rowSpecs[#guiSpec.rowSpecs + 1] = dataRow

	-- Create a scrolling frame for user entries
	-- Note: scrolling frame rows use Offset (fixed pixels at creation time)
	-- Dynamic row height is handled by the scrolling frame manager on resize
	-- Header row includes scrollbar padding spacer for alignment with data rows
	local headerTileSpecs: { wt.tileSpec } = table.clone(columnSpecs)
	-- headerTileSpecs[#headerTileSpecs + 1] = {
	-- 	name = "ScrollbarPadding",
	-- 	order = 5,
	-- 	width = UDim.new(0, 10),
	-- 	spec = {
	-- 		type = "text",
	-- 		text = "",
	-- 		backgroundColor = colors.defaultGrey,
	-- 	},
	-- }
	local scrollingFrameSpec: wt.scrollingFrameTileSpec = {
		name = "UserEntriesScrollingFrame",
		type = "scrollingFrameTileSpec",
		headerRow = {
			name = "HeaderRow",
			order = 1,
			height = UDim.new(0, generalRowHeight),
			tileSpecs = headerTileSpecs,
		},
		dataRows = {},
		stickyRows = {},
		rowHeight = generalRowHeight,
		howManyRowsToShow = 1,
	}

	local alreadyShownUserIds: { [number]: boolean } = {}

	-- Build set of userIds currently in this server
	local inServerUserIds: { [number]: boolean } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		inServerUserIds[player.UserId] = true
	end

	-- Helper to determine color and sticky status for a run
	-- Priority: me > friend+inServer > friend > inServer > default
	local function getRunColorAndSticky(
		userId: number,
		isMe: boolean,
		isMeRecent: boolean,
		isMePast: boolean
	): (Color3, boolean)
		if isMe then
			if isMeRecent then
				return colors.meColor, true
			elseif isMePast then
				return colors.mePastColor, true
			else
				return colors.meColor, true
			end
		end

		local isFriend = friendshipCache.isFriend(userId)
		local isInServer = inServerUserIds[userId]

		if isFriend and isInServer then
			return colors.friendInServerColor, true
		elseif isFriend then
			return colors.friendColor, true
		elseif isInServer then
			return colors.inServerColor, true
		end

		return colors.defaultGrey, false
	end

	-- Temporary arrays to collect runs before creating row specs
	-- We collect first, sort, then create rows with proper previousTime tracking
	type RunEntry = { run: tt.jsonBestRun, color: Color3, isJustNow: boolean, isSticky: boolean }
	local dataRunEntries: { RunEntry } = {}
	local stickyRunEntries: { RunEntry } = {}

	-- Add race best runs to the scrolling frame
	for _, jsonBestRun in ipairs(userFinishedRunResponse.raceBestRuns) do
		if not jsonBestRun.place then
			annotater.Error("a jsonBestRun showed up without any place. probably failed pathing it", {
				userId = targetUserId,
				run = jsonBestRun,
			})

			continue
		end

		local isMe = jsonBestRun.userId == targetUserId
		local isMeRecent = false
		local isMePast = false
		local isJustNow = false

		if isMe and runJustDid then
			if jsonBestRun.runId == runJustDid.runId then
				-- this only happens if we just did this AND it beat
				isMeRecent = true
				isJustNow = true
			else
				-- you did a run, but another run is your best, so this is your past best
				isMePast = true
			end
		end

		local useColor, isSticky = getRunColorAndSticky(jsonBestRun.userId, isMe, isMeRecent, isMePast)

		-- Also make unranked runs (place == 0) sticky
		if jsonBestRun.place == 0 then
			isSticky = true
		end

		local entry: RunEntry = { run = jsonBestRun, color = useColor, isJustNow = isJustNow, isSticky = isSticky }
		if isSticky then
			table.insert(stickyRunEntries, entry)
		else
			table.insert(dataRunEntries, entry)
		end
		alreadyShownUserIds[jsonBestRun.userId] = true
	end

	-- Add extra best runs to the scrolling frame
	-- extraBestRuns contains runs from in-server players not in top leaderboard
	for _, jsonBestRun in ipairs(userFinishedRunResponse.extraBestRuns) do
		if jsonBestRun.userId ~= targetUserId and alreadyShownUserIds[jsonBestRun.userId] then
			continue
		end

		local isMe = jsonBestRun.userId == targetUserId
		local isMeRecent = false
		local isMePast = false
		local isJustNow = false

		-- For extraBestRuns, use age heuristic to determine if this is your recent run
		if isMe then
			if jsonBestRun.runAgeSeconds < 4 then
				isMeRecent = true
				isJustNow = true
			else
				isMePast = true
			end
		end

		local useColor, isSticky = getRunColorAndSticky(jsonBestRun.userId, isMe, isMeRecent, isMePast)

		local entry: RunEntry = { run = jsonBestRun, color = useColor, isJustNow = isJustNow, isSticky = isSticky }
		if isSticky then
			table.insert(stickyRunEntries, entry)
		else
			table.insert(dataRunEntries, entry)
		end
		alreadyShownUserIds[jsonBestRun.userId] = true
	end

	-- Sort entries by runMilliseconds before creating row specs
	table.sort(dataRunEntries, function(a, b)
		return a.run.runMilliseconds < b.run.runMilliseconds
	end)

	table.sort(stickyRunEntries, function(a, b)
		return a.run.runMilliseconds < b.run.runMilliseconds
	end)

	-- Create row specs with digit highlighting for data rows (non-sticky leaderboard rows)
	-- User's own runs (sticky) don't get highlighting per the request
	local previousTimeText: string? = nil
	for _, entry in ipairs(dataRunEntries) do
		local rowSpec = createJsonRunRow(entry.run, entry.color, entry.isJustNow, previousTimeText)
		scrollingFrameSpec.dataRows[#scrollingFrameSpec.dataRows + 1] = rowSpec
		previousTimeText = rowSpec.timeText
	end

	-- Create sticky row specs without highlighting (user's runs)
	for _, entry in ipairs(stickyRunEntries) do
		local rowSpec = createJsonRunRow(entry.run, entry.color, entry.isJustNow, nil)
		scrollingFrameSpec.stickyRows[#scrollingFrameSpec.stickyRows + 1] = rowSpec
	end

	local maxIntendedRowsOfScrollingFrameToShow = 12
	if globalSettingShrinkRunResultPopups then
		maxIntendedRowsOfScrollingFrameToShow = 4
	end
	local actualRowsAvailable = #scrollingFrameSpec.dataRows + #scrollingFrameSpec.stickyRows
	-- howManyRowsToShow includes the header row (windows.lua passes howManyRowsToShow - 1 to CreateStickyScrollingFrame)
	-- Use actual rows + header if fewer than max, otherwise clamp to max to enable scrolling
	local usingHowManyRowsToShow = math.min(actualRowsAvailable + 1, maxIntendedRowsOfScrollingFrameToShow)
	local scrollFramePixelHeight: number = usingHowManyRowsToShow * generalRowHeight

	scrollingFrameSpec.howManyRowsToShow = usingHowManyRowsToShow
	_annotate(string.format("set howManyRowsToShow to %d (actualRowsAvailable=%d)", usingHowManyRowsToShow, actualRowsAvailable))

	-- Calculate popup height from actual content
	local popupHeight = scrollFramePixelHeight + basePopupHeight
	if runJustDid and runJustDid.runMilliseconds then
		popupHeight = popupHeight + generalRowHeight * 2
	end

	-- Calculate popup width in pixels using viewport
	local camera = workspace.CurrentCamera
	local viewportSize = if camera then camera.ViewportSize else Vector2.new(1920, 1080)
	local popupWidth = naturalBaseWidthScale * viewportSize.X

	-- Add the scrolling frame to the guiSpec
	-- Use scrollFramePixelHeight as proportional weight for resizable layout
	guiSpec.rowSpecs[#guiSpec.rowSpecs + 1] = {
		name = "ScrollingFrameRow",
		order = 5,
		height = UDim.new(scrollFramePixelHeight, 0),
		tileSpecs = {
			{
				name = "ScrollingFrameContainer",
				order = 1,
				width = UDim.new(1, 0),
				spec = scrollingFrameSpec,
			},
		},
	}

	local buttonRow = createLastRow()
	guiSpec.rowSpecs[#guiSpec.rowSpecs + 1] = buttonRow

	local runResultFrameOuterName = string.format("RunResult-%s", raceInfo.raceName)

	local raceResultSguiResult = windows.CreatePopup(
		guiSpec,
		runResultFrameOuterName,
		true, -- draggable
		true, -- resizable
		false, -- minimizable
		false, -- pinnable
		true, -- dismissableWithX
		false, -- dismissableByClick
		UDim2.new(0, popupWidth, 0, popupHeight),
		maxIntendedRowsOfScrollingFrameToShow,
		{
			settingName = "RUN_RESULTS_GUI_LAYOUT",
			settingKey = "position",
			saveSize = true,
			sizeKey = "size",
			clampOnLoad = true,
			defaultPosition = UDim2.new(0.05, 0, 0.08, 0), -- upper-left, leaves room for gameplay
		},
		nil,
		{
			key = "RunResultSingleton",
			shouldDedupe = function()
				return globalSettingOnlyHaveOneRunResultPopupAtATime
			end,
		}
	)
	local raceResultSgui = raceResultSguiResult.sgui

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	raceResultSgui.Parent = playerGui
end

--------------------- SETTINGS MANAGEMENT -----------------------------

local function handleUserSettingChanged(item: tt.userSettingValue?)
	if not item then
		return
	end

	if item.name == settingEnums.settingDefinitions.HIGHLIGHT_ON_RUN_COMPLETE_WARP.name then
		userWantsHighlightingWhenWarpingFromRunResults = item.booleanValue or false
	elseif item.name == settingEnums.settingDefinitions.SHOW_RUN_RESULT_POPUPS.name then
		globalSettingShowRunResultPopups = item.booleanValue or false
	elseif item.name == settingEnums.settingDefinitions.SHRINK_RUN_RESULT_POPUPS.name then
		globalSettingShrinkRunResultPopups = item.booleanValue or false
	elseif item.name == settingEnums.settingDefinitions.ONLY_HAVE_ONE_RUN_RESULT_POPUP_AT_A_TIME.name then
		globalSettingOnlyHaveOneRunResultPopupAtATime = item.booleanValue or false
	elseif item.name == settingEnums.settingDefinitions.HIGHLIGHT_TIME_DIGITS_IN_RESULTS.name then
		globalSettingHighlightTimeDigits = item.booleanValue or false
	end
	return
end

local function init()
	_annotate("init")

	settings.RegisterFunctionToListenForSettingName(handleUserSettingChanged, settingEnums.settingDefinitions.HIGHLIGHT_ON_RUN_COMPLETE_WARP.name, "drawRunResultGui")

	local highlightOnRunCompleteWarpSettingValue = settings.GetSettingByName(settingEnums.settingDefinitions.HIGHLIGHT_ON_RUN_COMPLETE_WARP.name)
	handleUserSettingChanged(highlightOnRunCompleteWarpSettingValue)

	settings.RegisterFunctionToListenForSettingName(handleUserSettingChanged, settingEnums.settingDefinitions.SHOW_RUN_RESULT_POPUPS.name, "drawRunResultGui")

	local popupsSettingValue = settings.GetSettingByName(settingEnums.settingDefinitions.SHOW_RUN_RESULT_POPUPS.name)
	handleUserSettingChanged(popupsSettingValue)

	settings.RegisterFunctionToListenForSettingName(handleUserSettingChanged, settingEnums.settingDefinitions.SHRINK_RUN_RESULT_POPUPS.name, "drawRunResultGui")

	local shrinkRunResultPopupsSettingValue = settings.GetSettingByName(settingEnums.settingDefinitions.SHRINK_RUN_RESULT_POPUPS.name)
	handleUserSettingChanged(shrinkRunResultPopupsSettingValue)

	settings.RegisterFunctionToListenForSettingName(handleUserSettingChanged, settingEnums.settingDefinitions.ONLY_HAVE_ONE_RUN_RESULT_POPUP_AT_A_TIME.name, "drawRunResultGui")

	local onlyHaveOneRunResultPopupAtATimeSettingValue = settings.GetSettingByName(settingEnums.settingDefinitions.ONLY_HAVE_ONE_RUN_RESULT_POPUP_AT_A_TIME.name)
	handleUserSettingChanged(onlyHaveOneRunResultPopupAtATimeSettingValue)

	settings.RegisterFunctionToListenForSettingName(handleUserSettingChanged, settingEnums.settingDefinitions.HIGHLIGHT_TIME_DIGITS_IN_RESULTS.name, "drawRunResultGui")

	local highlightTimeDigitsSettingValue = settings.GetSettingByName(settingEnums.settingDefinitions.HIGHLIGHT_TIME_DIGITS_IN_RESULTS.name)
	handleUserSettingChanged(highlightTimeDigitsSettingValue)

	_annotate("init done")
end

local module: Module = {
	DrawRunResultGui = drawRunResultGui,
	Init = init,
}

_annotate("end")
return module
