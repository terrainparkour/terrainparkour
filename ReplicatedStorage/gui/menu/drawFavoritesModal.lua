--!strict

-- localscript, drawer for the favorite races GUI

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local colors = require(game.ReplicatedStorage.util.colors)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local toolTip = require(game.ReplicatedStorage.gui.toolTip)
local tt = require(game.ReplicatedStorage.types.gametypes)
local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)
local localRdb = require(game.ReplicatedStorage.localRdb)
local wt = require(game.StarterPlayer.StarterPlayerScripts.guis.windowsTypes)
local warper = require(game.StarterPlayer.StarterPlayerScripts.warper)
local textUtil = require(game.ReplicatedStorage.util.textUtil)

local PlayersService = game:GetService("Players")

local localPlayer = PlayersService.LocalPlayer
local remotes = require(game.ReplicatedStorage.util.remotes)
local module = {}

local GenericClientUIFunction = remotes.getRemoteFunction("GenericClientUIFunction")

--------------------- GLOBALS --------------

local theLastGui: ScreenGui? = nil
local theLastGuiPosition: UDim2? = nil

local generalRowHeight = 36

----------------- SPEC CREATORS ---------------------

local function createTitleRow(userId: number): wt.rowSpec
	return {
		name = "TitleRow",
		order = 1,
		height = UDim.new(0, generalRowHeight),
		tileSpecs = {
			{
				name = "Title",
				order = 1,
				width = UDim.new(1, 0),
				spec = {
					type = "text",
					text = string.format("%s's Favorite Races", localRdb.GetUsernameByUserId(userId)),
					isBold = true,
					backgroundColor = colors.blueDone,
					textXAlignment = Enum.TextXAlignment.Center,
				},
			},
		},
	}
end

local function createDataRow(favoriteResponse: tt.serverFavoriteRacesResponse): wt.rowSpec
	if not favoriteResponse or not favoriteResponse.racesAndInfo then
		annotater.Error("no racesAndInfo")
		error("no racesAndInfo")
	end
	local totalFavorites = #favoriteResponse.racesAndInfo
	-- map of user => map of place => count
	local userPlaceCounts: { [number]: { [number]: number } } = {}
	for _, raceInfo in ipairs(favoriteResponse.racesAndInfo) do
		for _2, aResult in ipairs(raceInfo.theResults) do
			if not userPlaceCounts[aResult.userId] then
				userPlaceCounts[aResult.userId] = {}
			end
			local place = aResult.place
			if not place then
				continue
			end
			if userPlaceCounts[aResult.userId][place] then
				userPlaceCounts[aResult.userId][place] += 1
			else
				userPlaceCounts[aResult.userId][place] = 1
			end
		end
	end

	local placeText = "Your total results:\n"
	for position: number = 1, 100 do
		if userPlaceCounts and userPlaceCounts[favoriteResponse.targetUserId] then
			local count = userPlaceCounts[favoriteResponse.targetUserId][position] or 0
			if count and count > 0 then
				placeText = placeText .. string.format("%s: %d, ", tpUtil.getCardinalEmoji(position), count)
			end
		end
	end

	return {
		name = "DataRow",
		order = 2,
		height = UDim.new(0, 60),
		tileSpecs = {
			{
				name = "TotalFavorites",
				order = 1,
				spec = {
					type = "text",
					text = string.format("Favorite Races (%d / 100)", totalFavorites),
					textXAlignment = Enum.TextXAlignment.Center,
				},
			},
			{
				name = "FirstPlaceFavorites",
				order = 2,
				spec = {
					type = "text",
					text = placeText,
					textXAlignment = Enum.TextXAlignment.Left,
				},
			},
		},
	}
end

local function createScrollingFrameHeaderRow(
	targetUserId: number,
	requestingUserId: number,
	otherUserIds: { number },
	favoriteResponse: tt.serverFavoriteRacesResponse
): wt.rowSpec
	local raceSpec: wt.tileSpec = {
		name = "FavoriteRaces",
		order = 1,
		width = UDim.new(1, 0),
		spec = {
			type = "text",
			text = "Race",
			textXAlignment = Enum.TextXAlignment.Center,
		},
	}
	local warpLabelSpec: wt.tileSpec = {
		name = "WarpLabel",
		order = 2,
		spec = {
			type = "text",
			text = "Warp",
			textXAlignment = Enum.TextXAlignment.Center,
			backgroundColor = colors.blueDone,
			textColor = colors.black,
		},
	}

	local theHeaderTileSpecs: { wt.tileSpec } = {
		raceSpec,
		warpLabelSpec,
	}

	for n, theUserId in ipairs(otherUserIds) do
		local useColor = colors.defaultGrey
		if theUserId == requestingUserId then
			useColor = colors.meColor
		end

		local portraitPart: wt.portraitTileSpec = {
			type = "portrait",
			userId = theUserId,
			doPopup = false,
			width = UDim.new(0, generalRowHeight),
			backgroundColor = useColor,
		}

		local namePart: wt.textTileSpec = {
			type = "text",
			text = localRdb.GetUsernameByUserId(theUserId),
			backgroundColor = useColor,
			textXAlignment = Enum.TextXAlignment.Center,
		}

		local playerHeaderPortraitAndNameTileSpec: wt.rowTileSpec = {
			type = "rowTile",
			name = string.format("playerHeader_%s", localRdb.GetUsernameByUserId(theUserId)),
			tileSpecs = {
				{
					name = "playerHeaderTile",
					order = 1,
					userId = theUserId,
					doPopup = false,

					spec = portraitPart,
					width = UDim.new(0, 50),
				},
				{
					name = "playerHeaderName",
					order = 2,
					spec = namePart,
				},
			},
		}

		local playerHeaderTile: wt.tileSpec = {
			name = string.format("playerHeader_%s", localRdb.GetUsernameByUserId(theUserId)),
			order = n + 1,
			spec = playerHeaderPortraitAndNameTileSpec,
		}
		table.insert(theHeaderTileSpecs, playerHeaderTile)
	end

	return {
		name = "ScrollingFrameHeaderRow",
		order = 1,
		height = UDim.new(0, generalRowHeight),
		tileSpecs = theHeaderTileSpecs,
	}
end

local function createScrollingFrameDataRows(
	targetUserId: number,
	requestingUserId: number,
	otherUserIds: { number },
	favoriteResponse: tt.serverFavoriteRacesResponse
): { wt.rowSpec }
	local dataRows: { wt.rowSpec } = {}

	for i, thisRaceInfo in ipairs(favoriteResponse.racesAndInfo) do
		local theTiles: { wt.tileSpec } = {}
		local sp = textUtil.stringSplit(thisRaceInfo.theRace.raceName, "-")
		local sn = sp[1]
		local en = sp[2]
		local signSpecStart: wt.textTileSpec = {
			type = "text",
			text = sn,
			backgroundColor = colors.signColor,
			textColor = colors.white,
			textXAlignment = Enum.TextXAlignment.Center,
		}
		local signSpecEnd: wt.textTileSpec = {
			type = "text",
			text = en,
			backgroundColor = colors.signColor,
			textColor = colors.white,
			textXAlignment = Enum.TextXAlignment.Center,
		}

		local sTile: wt.tileSpec = {
			name = "Start",
			order = 1,
			width = UDim.new(0.5, 0),
			spec = signSpecStart,
			includeTextSizeConstraint = false,
		}

		local eTile: wt.tileSpec = {
			name = "End",
			order = 2,
			width = UDim.new(0.5, 0),
			spec = signSpecEnd,
			includeTextSizeConstraint = false,
		}

		local warpTileButtonSpec: wt.buttonTileSpec = {
			type = "button",
			text = "Warp",
			backgroundColor = colors.defaultGrey,
			isBold = false,
			onClick = function()
				warper.WarpToSignId(thisRaceInfo.theRace.startSignId, thisRaceInfo.theRace.endSignId)
			end,
		}

		local theWarpTile: wt.tileSpec = {
			name = "Warp",
			order = 2,
			width = UDim.new(1, 0),
			spec = warpTileButtonSpec,
			textXAlignment = Enum.TextXAlignment.Center,
			-- backgroundColor = colors.warpColor,
			textColor = colors.black,
		}

		table.insert(theTiles, sTile)
		table.insert(theTiles, eTile)

		table.insert(theTiles, theWarpTile)
		for n, theColumnUserId in ipairs(otherUserIds) do
			local theResult = nil
			for _, result in ipairs(thisRaceInfo.theResults) do
				if result.userId == theColumnUserId then
					theResult = result
					break
				end
			end
			local useColor = colors.defaultGrey
			if theColumnUserId == requestingUserId then
				useColor = colors.meColor
			end
			if theResult then
				local usePlaceText = ""
				if theResult.place and theResult.place > 0 then
					usePlaceText = tpUtil.getCardinal(theResult.place)
				else
					usePlaceText = " - "
				end

				local thePlaceRank: wt.textTileSpec = {
					type = "text",
					text = usePlaceText,
					backgroundColor = useColor,
					textXAlignment = Enum.TextXAlignment.Center,
				}
				local theTimeMs: wt.textTileSpec = {
					type = "text",
					text = string.format("%0.3fs", theResult.runMilliseconds / 1000),
					backgroundColor = useColor,
					textXAlignment = Enum.TextXAlignment.Center,
				}
				local thePlaceTile: wt.tileSpec = {
					name = "name",
					order = 1,
					width = UDim.new(1, 0),
					spec = thePlaceRank,
					textXAlignment = Enum.TextXAlignment.Center,
				}
				local theTimeTile: wt.tileSpec = {
					name = "time",
					order = 2,
					width = UDim.new(1, 0),
					spec = theTimeMs,
					textXAlignment = Enum.TextXAlignment.Center,
				}

				local theRowTileSpec: wt.rowTileSpec = {
					type = "rowTile",
					name = string.format("results_%s", localRdb.GetUsernameByUserId(theColumnUserId)),
					tileSpecs = { thePlaceTile, theTimeTile },
				}

				local theRowTile: wt.tileSpec = {
					order = n + 4,
					name = string.format("results_outer_%s", localRdb.GetUsernameByUserId(theColumnUserId)),
					spec = theRowTileSpec,
				}

				table.insert(theTiles, theRowTile)
			else
				local blankTile: wt.tileSpec = {
					name = tostring(theColumnUserId),
					order = n + 4,
					width = UDim.new(1, 0),
					spec = {
						type = "text",
						text = "",
						backgroundColor = useColor,
					},
				}
				table.insert(theTiles, blankTile)
			end
		end

		local rowSpec: wt.rowSpec = {
			name = string.format("DataRow_%d", i),
			order = i,
			height = UDim.new(0, generalRowHeight),
			horizontalAlignment = Enum.HorizontalAlignment.Left,
			tileSpecs = theTiles,
		}

		table.insert(dataRows, rowSpec)
	end

	return dataRows
end

-------------------- DRAWING FUNCTION ---------------------

module.DrawFavoriteRacesModal = function(targetUserId: number?, requestingUserId: number?, otherUserIds: { number })
	local pgui = localPlayer:WaitForChild("PlayerGui")
	if targetUserId == nil then
		error("bad nil targetUser")
	end

	if requestingUserId == nil then
		error("bad nil requestingUser")
	end

	local favoriteResponse: tt.serverFavoriteRacesResponse = GenericClientUIFunction:InvokeServer({
		eventKind = "favoriteRacesRequest",
		data = {
			targetUserId = targetUserId,
			requestingUserId = requestingUserId,
			otherUserIds = otherUserIds,
		},
	})

	local favoritesScreenGui = pgui:FindFirstChild("FavoritesGui")
	if favoritesScreenGui then
		favoritesScreenGui:Destroy()
	end

	local titleRow = createTitleRow(targetUserId)
	local dataRow = createDataRow(favoriteResponse)

	-- for the purposes of UI drawing, if the requesting user isn't the target user, then stick them into other Userids.

	local requesterIsInOthers = false
	local targetUserIsInOthers = false
	for _, otherUserId in pairs(otherUserIds) do
		if otherUserId == requestingUserId then
			requesterIsInOthers = true
		end
		if otherUserId == targetUserId then
			targetUserIsInOthers = true
		end
	end

	-- the target should be the first col, and the requester (if different) in the 2nd
	if not (targetUserIsInOthers == requesterIsInOthers) then
		table.insert(otherUserIds, 1, requestingUserId)
	end
	if not targetUserIsInOthers then
		table.insert(otherUserIds, 1, targetUserId)
	end

	local scrollingFrameHeaderRow =
		createScrollingFrameHeaderRow(targetUserId, requestingUserId, otherUserIds, favoriteResponse)
	local scrollingFrameDataRows =
		createScrollingFrameDataRows(targetUserId, requestingUserId, otherUserIds, favoriteResponse)

	local scrollingFrameSpec: wt.scrollingFrameTileSpec = {
		type = "scrollingFrameTileSpec",
		name = "FavoritesScrollingFrame",
		headerRow = scrollingFrameHeaderRow,
		dataRows = scrollingFrameDataRows,
		stickyRows = {},
		rowHeight = generalRowHeight,
		howManyRowsToShow = 12,
	}

	local scrollingFrameRowSpec: wt.rowSpec = {
		name = "ScrollingFrameRow",
		order = 3,
		height = UDim.new(1, 0),
		horizontalAlignment = Enum.HorizontalAlignment.Center,
		tileSpecs = {
			{
				name = "ScrollingFrame",
				order = 1,
				width = UDim.new(1, 0),
				spec = scrollingFrameSpec,
			},
		},
	}

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

	local closeRow = {
		name = "CloseButtonRow",
		order = 4,
		height = UDim.new(0, generalRowHeight),
		horizontalAlignment = Enum.HorizontalAlignment.Center,
		tileSpecs = { closeButtonLeavingroom },
	}

	local guiSpec: wt.guiSpec = {
		name = "FavoritesModal",
		rowSpecs = {
			titleRow,
			dataRow,
			scrollingFrameRowSpec,
			closeRow,
		},
	}

	local maxIntendedRowsOfScrollingFrameToShow = 12

	local actualRowsAvailable = #favoriteResponse.racesAndInfo
	local usingHowManyRowsToShow = math.min(actualRowsAvailable + 1, maxIntendedRowsOfScrollingFrameToShow)
	-- +1 for the header
	local scrollFramePixelHeight: number = usingHowManyRowsToShow * generalRowHeight

	scrollingFrameSpec.howManyRowsToShow = usingHowManyRowsToShow
	_annotate(string.format("set howManyRowsToShow to %d", usingHowManyRowsToShow))

	local totalHeight = scrollFramePixelHeight + 136

	local xScale = math.min(0.9, math.min(0.7, 0.3 + 0.06 * #otherUserIds))
	_annotate(
		string.format(
			"all details on the size calculation: \nxScale: %0.1f, \n%d other userIds. \nactualRowsAvailable: %d, \nmaxRowsVisibleByDefault: %d, \nrowsToShow: %d, \nfinalAbsolutelyFavoriteWindowHeightYPixels: %d",
			xScale,
			#otherUserIds,
			actualRowsAvailable,
			maxIntendedRowsOfScrollingFrameToShow,
			usingHowManyRowsToShow,
			totalHeight
		)
	)
	local theGui = windows.CreatePopup(
		guiSpec,
		"FavoritesGui",
		true, --draggable
		false, --resizable
		false, --minimizable
		true, --pinnable
		true, --dismissableWithX
		false, --dismissableByClick
		UDim2.new(xScale, 0, 0, totalHeight),
		usingHowManyRowsToShow
	)
	local outerFrame = theGui:FindFirstChildOfClass("Frame")
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
			outerFrame.Position = UDim2.new(0.15, 0, 0.28, 0) --the default.
			_annotate("\tRunResult positioning: outerFrame.Position to default")
		end
	else
		_annotate("\tRunResult positioning: no outerFrame found")
	end

	-- if globalSettingOnlyHaveOneRunResultPopupAtATime then
	-- 	if theLastGui then
	-- 		_annotate("\tRunResult positioning: destroy lastGui")
	-- 		theLastGui:Destroy()
	-- 		theLastGui = nil
	-- 	end
	-- end

	if theLastGui then
		local outerFrame2 = theGui:FindFirstChildOfClass("Frame")
		if outerFrame2 then
			_annotate("\tRunResult positioning: set lastGuiPosition to", outerFrame2.Position)
			theLastGuiPosition = outerFrame2.Position
		end
	end

	_annotate("\tRunResult positioning: set lastGui to", theGui.Name)
	theLastGui = theGui

	local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	theGui.Parent = playerGui
end

_annotate("end")

return module
