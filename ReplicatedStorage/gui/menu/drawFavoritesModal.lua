--!strict

-- Player localscripts call this to generate a raceresult UI.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local enums = require(game.ReplicatedStorage.util.enums)
local colors = require(game.ReplicatedStorage.util.colors)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local tt = require(game.ReplicatedStorage.types.gametypes)
local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)
local localRdb = require(game.ReplicatedStorage.localRdb)
local wt = require(game.StarterPlayer.StarterPlayerScripts.guis.windowsTypes)
local warper = require(game.StarterPlayer.StarterPlayerScripts.warper)

local PlayersService = game:GetService("Players")

local localPlayer = PlayersService.LocalPlayer
local remotes = require(game.ReplicatedStorage.util.remotes)
local module = {}

local GenericClientUIFunction = remotes.getRemoteFunction("GenericClientUIFunction")

local rowHeightPixel = 35

local function createTitleRow(userId: number): wt.rowSpec
	return {
		name = "TitleRow",
		order = 1,
		height = UDim.new(0, rowHeightPixel),
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

	local placeText = ""

	for position: number = 1, 100 do
		if userPlaceCounts and userPlaceCounts[favoriteResponse.targetUserId] then
			local count = userPlaceCounts[favoriteResponse.targetUserId][position] or 0
			if count and count > 0 then
				placeText = placeText .. string.format("%s: %d\n", tpUtil.getCardinalEmoji(position), count)
			end
		end
	end

	placeText = "Your total results:\n" .. placeText

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
					textXAlignment = Enum.TextXAlignment.Center,
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
		width = UDim.new(2.5, 0),
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
			width = UDim.new(0, 50),
			backgroundColor = useColor,
		}

		local namePart: wt.textTileSpec = {
			type = "text",
			text = localRdb.GetUsernameByUserId(theUserId),
			backgroundColor = useColor,
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
		height = UDim.new(0, 70),
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
		local theRaceNameTextTileSpec: wt.textTileSpec = {
			type = "text",
			text = thisRaceInfo.theRace.raceName,
			backgroundColor = colors.signColor,
			textColor = colors.white,
			textXAlignment = Enum.TextXAlignment.Center,
		}

		local theRacenameTile: wt.tileSpec = {
			name = "RaceName",
			order = 1,
			width = UDim.new(2.5, 0),
			spec = theRaceNameTextTileSpec,
		}
		local warpTileButtonSpec: wt.buttonTileSpec = {
			type = "button",
			text = "Warp",
			backgroundColor = colors.warpColor,
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

		table.insert(theTiles, theRacenameTile)

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
			height = UDim.new(0, 25),
			horizontalAlignment = Enum.HorizontalAlignment.Left,
			tileSpecs = theTiles,
		}

		table.insert(dataRows, rowSpec)
	end

	return dataRows
end

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
		type = "scrollingFrame",
		name = "FavoritesScrollingFrame",
		headerRow = scrollingFrameHeaderRow,
		dataRows = scrollingFrameDataRows,
		rowHeight = 25,
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
	local closeRow = {
		name = "CloseButtonRow",
		order = 4,
		height = UDim.new(0, 40),
		horizontalAlignment = Enum.HorizontalAlignment.Center,
		tileSpecs = { windows.StandardCloseButton },
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

	local xScale = math.min(0.7, 0.3 + 0.06 * #otherUserIds)
	local yScale = math.min(0.2, 0.2 + 0.15 * #favoriteResponse.racesAndInfo)

	local screenGui = windows.CreatePopup(
		guiSpec,
		"FavoritesGui",
		true,
		true,
		false,
		true,
		true,
		false,
		UDim2.new(xScale, 0, yScale, 135),
		11
	)

	screenGui.Parent = pgui
end

_annotate("end")

return module
