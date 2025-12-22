--!strict

-- localscript, drawer for the favorite races GUI

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local colors = require(game.ReplicatedStorage.util.colors)
local standardButton = require(game.ReplicatedStorage.gui.standardButton)
local tpUtil: typeof(require(game.ReplicatedStorage.util.tpUtil)) = require(game.ReplicatedStorage.util.tpUtil)
local toolTip = require(game.ReplicatedStorage.gui.toolTip)
local tt = require(game.ReplicatedStorage.types.gametypes)
local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)
local localRdb = require(game.ReplicatedStorage.localRdb)
local wt = require(game.StarterPlayer.StarterPlayerScripts.guis.windowsTypes)
local warper = require(game.StarterPlayer.StarterCharacterScripts.client.warper)
local textUtil = require(game.ReplicatedStorage.util.textUtil)

local PlayersService = game:GetService("Players")

local localPlayer = PlayersService.LocalPlayer
local remotes = require(game.ReplicatedStorage.util.remotes)
local module = {}

local GenericClientUIFunction = remotes.getRemoteFunction("GenericClientUIFunction")

--------------------- GLOBALS --------------


local generalRowHeight = 36

type ViewMode = "TargetOnly" | "TargetAndMe" | "Everyone"

local portraitWidthPixels = generalRowHeight
local placementGradientMaxPlace = 150
local viewToggleTileName = "FavoritesViewToggleContainer"
local startColumnScale = 1
local endColumnScale = 1
local warpColumnScale = 0.8
local playerColumnScale = 1.5
local topPlaceColor = Color3.fromRGB(46, 213, 115)
local bottomPlaceColor = Color3.fromRGB(85, 85, 85)

local viewModeOrder: { ViewMode } = {
	"TargetOnly" :: ViewMode,
	"TargetAndMe" :: ViewMode,
	"Everyone" :: ViewMode,
}
local viewModeLabels: { [ViewMode]: string } = {
	TargetOnly = "Player",
	TargetAndMe = "Player+You",
	Everyone = "All",
}

local function cloneNumberArray(values: { number }): { number }
	local result: { number } = {}
	for _, value in ipairs(values) do
		table.insert(result, value)
	end
	return result
end

local function dedupeUserIds(userIds: { number }): { number }
	local seen: { [number]: boolean } = {}
	local result: { number } = {}
	for _, userId in ipairs(userIds) do
		if userId ~= nil and not seen[userId] then
			table.insert(result, userId)
			seen[userId] = true
		end
	end
	return result
end

local function getFilteredUserIds(viewMode: ViewMode, targetUserId: number, requestingUserId: number, baseUserIds: { number }): { number }
	if viewMode == "TargetOnly" then
		return { targetUserId }
	elseif viewMode == "TargetAndMe" then
		local result: { number } = { targetUserId }
		if requestingUserId ~= targetUserId then
			table.insert(result, requestingUserId)
		end
		return dedupeUserIds(result)
	end
	return cloneNumberArray(baseUserIds)
end

local function lerpColor3(a: Color3, b: Color3, alpha: number): Color3
	alpha = math.clamp(alpha, 0, 1)
	return Color3.new(a.R + (b.R - a.R) * alpha, a.G + (b.G - a.G) * alpha, a.B + (b.B - a.B) * alpha)
end

local function getPlaceHighlightColor(place: number?): Color3
	if not place or place <= 0 then
		return bottomPlaceColor
	end
	local maxSteps = math.max(placementGradientMaxPlace - 1, 1)
	local clampedPlace = math.clamp(place, 1, placementGradientMaxPlace)
	local alpha = (clampedPlace - 1) / maxSteps
	return lerpColor3(topPlaceColor, bottomPlaceColor, alpha)
end

local function buildPlaceSummaryText(favoriteResponse: tt.serverFavoriteRacesResponse): (string, number)
	-- map of user => map of place => count
	local userPlaceCounts: { [number]: { [number]: number } } = {}
	for _, raceInfo in ipairs(favoriteResponse.racesAndInfo) do
		for _, aResult in ipairs(raceInfo.theResults) do
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

	local placeTokens: { string } = {}
	for position: number = 1, 150 do
		if userPlaceCounts and userPlaceCounts[favoriteResponse.targetUserId] then
			local count = userPlaceCounts[favoriteResponse.targetUserId][position] or 0
			if count and count > 0 then
				table.insert(placeTokens, string.format("%s: %d", tpUtil.getCardinalEmoji(position), count))
			end
		end
	end

	if #placeTokens == 0 then
		return "Your total results:\n(no placed results yet)", 2
	end

	local placeLines: { string } = { "Your total results:" }
	local chunkSize = 4
	for i = 1, #placeTokens do
		local chunkIndex = math.floor((i - 1) / chunkSize) + 2
		if not placeLines[chunkIndex] then
			placeLines[chunkIndex] = ""
		end
		local separator = if placeLines[chunkIndex] == "" then "" else "    "
		placeLines[chunkIndex] ..= separator .. placeTokens[i]
	end
	local placeText = table.concat(placeLines, "\n")
	return placeText, #placeLines
end

local function ensureCorner(guiObject: GuiObject, radiusPixels: number)
	local existingCorner = guiObject:FindFirstChildOfClass("UICorner")
	if not existingCorner then
		local newCorner = Instance.new("UICorner")
		newCorner.Name = "FavoritesUICorner"
		newCorner.Parent = guiObject
		existingCorner = newCorner
	end
	local corner = existingCorner :: UICorner
	corner.CornerRadius = UDim.new(0, radiusPixels)
end

local function addToggleStroke(toggleFrame: GuiObject)
	local existingStroke = toggleFrame:FindFirstChild("FavoritesToggleStroke")
	if existingStroke and existingStroke:IsA("UIStroke") then
		return existingStroke
	end
	local stroke = Instance.new("UIStroke")
	stroke.Name = "FavoritesToggleStroke"
	stroke.Color = colors.black
	stroke.Thickness = 1
	stroke.Parent = toggleFrame
	return stroke
end

local function matchesWindowGeneratedName(instanceName: string, baseName: string): boolean
	if instanceName == baseName then
		return true
	end
	local underscoreIndex = string.find(instanceName, "_", 1, true)
	if not underscoreIndex then
		return false
	end
	return string.sub(instanceName, underscoreIndex + 1) == baseName
end

local function findDescendantByBaseName(root: Instance, baseName: string): Instance?
	for _, descendant in ipairs(root:GetDescendants()) do
		if matchesWindowGeneratedName(descendant.Name, baseName) then
			return descendant
		end
	end
	return nil
end

local function styleViewToggleContainer(screenGui: ScreenGui)
	local wrapperContainer = findDescendantByBaseName(screenGui, viewToggleTileName .. "_Wrapper")
	if wrapperContainer and wrapperContainer:IsA("Frame") then
		wrapperContainer.BackgroundTransparency = 1
		local wrapperPadding = wrapperContainer:FindFirstChildOfClass("UIPadding")
		if not wrapperPadding then
			local newPadding = Instance.new("UIPadding")
			newPadding.Parent = wrapperContainer
			wrapperPadding = newPadding
		end
		local wrapperPaddingInstance = wrapperPadding :: UIPadding
		wrapperPaddingInstance.PaddingTop = UDim.new(0, 8)
		wrapperPaddingInstance.PaddingBottom = UDim.new(0, 8)
		wrapperPaddingInstance.PaddingLeft = UDim.new(0, 8)
		wrapperPaddingInstance.PaddingRight = UDim.new(0, 8)
	end

	local toggleContainer = findDescendantByBaseName(screenGui, viewToggleTileName)
	if not toggleContainer or not toggleContainer:IsA("Frame") then
		return
	end

	toggleContainer.BackgroundColor3 = colors.white
	toggleContainer.BackgroundTransparency = 0
	toggleContainer.BorderSizePixel = 0
	ensureCorner(toggleContainer, 16)
	local stroke = addToggleStroke(toggleContainer)
	stroke.Thickness = 2
	stroke.Color = colors.black

	local padding = toggleContainer:FindFirstChildOfClass("UIPadding")
	if not padding then
		local newPadding = Instance.new("UIPadding")
		newPadding.Parent = toggleContainer
		padding = newPadding
	end
	local paddingInstance = padding :: UIPadding
	paddingInstance.PaddingTop = UDim.new(0, 6)
	paddingInstance.PaddingBottom = UDim.new(0, 6)
	paddingInstance.PaddingLeft = UDim.new(0, 8)
	paddingInstance.PaddingRight = UDim.new(0, 8)

	local layout = toggleContainer:FindFirstChildOfClass("UIListLayout") :: UIListLayout?
	if layout then
		layout.Padding = UDim.new(0, 6)
	end

	for _, child in ipairs(toggleContainer:GetChildren()) do
		if child:IsA("TextButton") then
			child.BorderSizePixel = 0
			child.AutoButtonColor = false
			ensureCorner(child, 12)
		end
	end
end

local function createViewToggleTileSpec(currentViewMode: ViewMode, setViewMode: (ViewMode) -> ()): wt.tileSpec
	local buttons: { wt.tileSpec } = {}
	local perButtonWidth = 1 / #viewModeOrder
	for order = 1, #viewModeOrder do
		local viewMode: ViewMode = viewModeOrder[order]
		local buttonSpec: wt.buttonTileSpec = {
			type = "button",
			text = viewModeLabels[viewMode],
			isBold = true,
			backgroundColor = if viewMode == currentViewMode then colors.lightGreen else colors.lightGrey,
			textColor = colors.black,
			textXAlignment = Enum.TextXAlignment.Center,
			onClick = function(_: InputObject, _: TextButton)
				setViewMode(viewMode)
			end,
		}
		table.insert(buttons, {
			name = string.format("Toggle_%s", viewMode),
			order = order,
			width = UDim.new(perButtonWidth, 0),
			spec = buttonSpec,
		})
	end

	local viewToggleRowTileSpec: wt.rowTileSpec = {
		type = "rowTile",
		name = viewToggleTileName,
		tileSpecs = buttons,
	}

	local wrapperRowTileSpec: wt.rowTileSpec = {
		type = "rowTile",
		name = viewToggleTileName .. "_Wrapper",
		tileSpecs = {
			{
				name = viewToggleTileName,
				order = 1,
				width = UDim.new(1, -16),
				spec = viewToggleRowTileSpec,
			},
		},
	}

	return {
		name = viewToggleTileName .. "_Outer",
		order = 1,
		width = UDim.new(0.25, 0),
		spec = wrapperRowTileSpec,
	}
end

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

local function createControlsRow(totalFavorites: number, viewToggleTileSpec: wt.tileSpec): wt.rowSpec
	if not viewToggleTileSpec then
		error("missing viewToggleTileSpec")
	end
	local viewToggleTileSpecSized: wt.tileSpec = {
		name = viewToggleTileSpec.name,
		order = viewToggleTileSpec.order,
		width = UDim.new(0.4, 0),
		spec = viewToggleTileSpec.spec,
	}
	return {
		name = "ControlsRow",
		order = 2,
		height = UDim.new(0, generalRowHeight),
		tileSpecs = {
			viewToggleTileSpecSized,
			{
				name = "TotalFavorites",
				order = 2,
				width = UDim.new(0.6, 0),
				spec = {
					type = "text",
					text = string.format("Favorite Races (%d / 150)", totalFavorites),
					isBold = true,
					textColor = colors.black,
					backgroundColor = colors.warpColor,
					textXAlignment = Enum.TextXAlignment.Center,
				},
			},
		},
	}
end

local function createSummaryRow(placeText: string, placeLineCount: number): wt.rowSpec
	-- Avoid microscopic multi-line text: use fixed TextSize + top alignment.
	local clampedLines = math.clamp(placeLineCount, 2, 5)
	local summaryHeightPixels = (clampedLines * 18) + 12
	return {
		name = "SummaryRow",
		order = 3,
		height = UDim.new(0, summaryHeightPixels),
		tileSpecs = {
			{
				name = "PlaceSummary",
				order = 1,
				width = UDim.new(1, 0),
				spec = {
					type = "text",
					text = placeText,
					isMonospaced = true,
					backgroundColor = colors.lightGrey,
					textColor = colors.black,
					textXAlignment = Enum.TextXAlignment.Left,
					textYAlignment = Enum.TextYAlignment.Top,
					textWrapped = false,
					leftPadding = 8,
					rightPadding = 8,
					topPadding = 6,
					bottomPadding = 6,
				},
			},
		},
	}
end

local function createDataRow(favoriteResponse: tt.serverFavoriteRacesResponse, viewToggleTileSpec: wt.tileSpec): { wt.rowSpec }
	if not favoriteResponse or not favoriteResponse.racesAndInfo then
		annotater.Error("no racesAndInfo", { userId = localPlayer.UserId })
		error("no racesAndInfo")
	end
	if not viewToggleTileSpec then
		error("missing viewToggleTileSpec")
	end
	local totalFavorites = #favoriteResponse.racesAndInfo
	local placeText, placeLineCount = buildPlaceSummaryText(favoriteResponse)
	local controlsRow = createControlsRow(totalFavorites, viewToggleTileSpec)
	local summaryRow = createSummaryRow(placeText, placeLineCount)
	return { controlsRow, summaryRow }
end

local function createScrollingFrameHeaderRow(
	targetUserId: number,
	requestingUserId: number,
	otherUserIds: { number },
	favoriteResponse: tt.serverFavoriteRacesResponse
): wt.rowSpec
	local startHeaderTile: wt.tileSpec = {
		name = "FavoriteRaceStart",
		order = 1,
		width = UDim.new(startColumnScale, 0),
		spec = {
			type = "text",
			text = "Start",
			backgroundColor = colors.signColor,
			textColor = colors.white,
			textXAlignment = Enum.TextXAlignment.Center,
		},
	}
	local endHeaderTile: wt.tileSpec = {
		name = "FavoriteRaceEnd",
		order = 2,
		width = UDim.new(endColumnScale, 0),
		spec = {
			type = "text",
			text = "End",
			backgroundColor = colors.signColor,
			textColor = colors.white,
			textXAlignment = Enum.TextXAlignment.Center,
		},
	}

	local warpLabelSpec: wt.tileSpec = {
		name = "WarpLabel",
		order = 3,
		width = UDim.new(warpColumnScale, 0),
		spec = {
			type = "text",
			text = "Warp",
			textXAlignment = Enum.TextXAlignment.Center,
			backgroundColor = colors.blueDone,
			textColor = colors.black,
		},
	}

	local theHeaderTileSpecs: { wt.tileSpec } = {
		startHeaderTile,
		endHeaderTile,
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
			width = UDim.new(0, portraitWidthPixels),
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
					width = UDim.new(0, portraitWidthPixels),
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
			order = n + 3,
			width = UDim.new(playerColumnScale, 0),
			spec = playerHeaderPortraitAndNameTileSpec,
		}
		table.insert(theHeaderTileSpecs, playerHeaderTile)
	end

	return {
		name = "ScrollingFrameHeaderRow",
		order = 1,
		height = UDim.new(0, generalRowHeight),
		tileSpecs = theHeaderTileSpecs,
		bottomBorderColor = colors.black,
		bottomBorderThickness = 2,
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
			includeTextSizeConstraint = false,
		}
		local signSpecEnd: wt.textTileSpec = {
			type = "text",
			text = en,
			backgroundColor = colors.signColor,
			textColor = colors.white,
			textXAlignment = Enum.TextXAlignment.Center,
			includeTextSizeConstraint = false,
		}

		local sTile: wt.tileSpec = {
			name = "Start",
			order = 1,
			width = UDim.new(startColumnScale, 0),
			spec = signSpecStart,
		}

		local eTile: wt.tileSpec = {
			name = "End",
			order = 2,
			width = UDim.new(endColumnScale, 0),
			spec = signSpecEnd,
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
			order = 3,
			width = UDim.new(warpColumnScale, 0),
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
			local timeBackgroundColor = colors.defaultGrey
			if theColumnUserId == requestingUserId then
				timeBackgroundColor = colors.meColor
			end

			local usePlaceText = " - "
			local placeBackgroundColor = getPlaceHighlightColor(nil)
			local runTimeText = ""

			if theResult then
				if theResult.place and theResult.place > 0 then
					usePlaceText = tpUtil.getCardinal(theResult.place)
				end
				placeBackgroundColor = getPlaceHighlightColor(theResult.place)
				runTimeText = string.format("%0.3fs", theResult.runMilliseconds / 1000)
			else
				runTimeText = ""
			end

			local thePlaceRank: wt.textTileSpec = {
				type = "text",
				text = usePlaceText,
				backgroundColor = placeBackgroundColor,
				textColor = colors.black,
				textXAlignment = Enum.TextXAlignment.Center,
			}
			local theTimeMs: wt.textTileSpec = {
				type = "text",
				text = runTimeText,
				backgroundColor = timeBackgroundColor,
				textXAlignment = Enum.TextXAlignment.Center,
			}
			local thePlaceTile: wt.tileSpec = {
				name = "name",
				order = 1,
				width = UDim.new(0, portraitWidthPixels),
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
				order = n + 3,
				width = UDim.new(playerColumnScale, 0),
				name = string.format("results_outer_%s", localRdb.GetUsernameByUserId(theColumnUserId)),
				spec = theRowTileSpec,
			}

			table.insert(theTiles, theRowTile)
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
	local playerGui = localPlayer:WaitForChild("PlayerGui")
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

	if favoriteResponse and favoriteResponse.success == false then
		annotater.Error("favorite races request failed", {
			userId = localPlayer.UserId,
			error = favoriteResponse.error,
			message = favoriteResponse.message,
			targetUserId = targetUserId,
			requestingUserId = requestingUserId,
		})

		local guiSpec: wt.guiSpec = {
			name = "FavoritesErrorModal",
			rowSpecs = {
				{
					name = "Title",
					order = 1,
					height = UDim.new(0, generalRowHeight),
					tileSpecs = {
						{
							name = "TitleText",
							order = 1,
							width = UDim.new(1, 0),
							spec = {
								type = "text",
								text = "Favorites (error)",
								isBold = true,
								backgroundColor = colors.signColor,
								textColor = colors.white,
								textXAlignment = Enum.TextXAlignment.Center,
							},
						},
					},
				},
				{
					name = "Body",
					order = 2,
					height = UDim.new(0, 70),
					tileSpecs = {
						{
							name = "BodyText",
							order = 1,
							width = UDim.new(1, 0),
							spec = {
								type = "text",
								text = string.format(
									"Backend request failed: %s",
									tostring(favoriteResponse.message or favoriteResponse.error)
								),
								backgroundColor = colors.defaultGrey,
								textColor = colors.black,
								textXAlignment = Enum.TextXAlignment.Left,
								leftPadding = 8,
							},
						},
					},
				},
				{
					name = "CloseButtonRow",
					order = 3,
					height = UDim.new(0, 30),
					tileSpecs = { windows.StandardCloseButton },
				},
			},
		}

		local errorGuiResult = windows.CreatePopup(guiSpec, "FavoritesGui", true, true, false, true, true, false, UDim2.new(0.45, 0, 0, 150))
		errorGuiResult.sgui.Parent = playerGui
		return
	end

	if not favoriteResponse or not favoriteResponse.racesAndInfo then
		annotater.Error("favorite races response missing racesAndInfo", { userId = localPlayer.UserId })
		local guiSpec: wt.guiSpec = {
			name = "FavoritesErrorModalMissing",
			rowSpecs = {
				{
					name = "Title",
					order = 1,
					height = UDim.new(0, generalRowHeight),
					tileSpecs = {
						{
							name = "TitleText",
							order = 1,
							width = UDim.new(1, 0),
							spec = {
								type = "text",
								text = "Favorites (error)",
								isBold = true,
								backgroundColor = colors.signColor,
								textColor = colors.white,
								textXAlignment = Enum.TextXAlignment.Center,
							},
						},
					},
				},
				{
					name = "Body",
					order = 2,
					height = UDim.new(0, 70),
					tileSpecs = {
						{
							name = "BodyText",
							order = 1,
							width = UDim.new(1, 0),
							spec = {
								type = "text",
								text = "Backend response was malformed (missing racesAndInfo).",
								backgroundColor = colors.defaultGrey,
								textColor = colors.black,
								textXAlignment = Enum.TextXAlignment.Left,
								leftPadding = 8,
							},
						},
					},
				},
				{
					name = "CloseButtonRow",
					order = 3,
					height = UDim.new(0, 30),
					tileSpecs = { windows.StandardCloseButton },
				},
			},
		}
		local errorGuiResult = windows.CreatePopup(guiSpec, "FavoritesGui", true, true, false, true, true, false, UDim2.new(0.45, 0, 0, 150))
		errorGuiResult.sgui.Parent = playerGui
		return
	end

	local displayUserIds = cloneNumberArray(otherUserIds)
	-- for the purposes of UI drawing, if the requesting user isn't the target user, then stick them into other Userids.
	local requesterIsInOthers = false
	local targetUserIsInOthers = false
	for _, otherUserId in ipairs(displayUserIds) do
		if otherUserId == requestingUserId then
			requesterIsInOthers = true
		end
		if otherUserId == targetUserId then
			targetUserIsInOthers = true
		end
	end

	-- the target should be the first col, and the requester (if different) in the 2nd
	if not (targetUserIsInOthers == requesterIsInOthers) then
		table.insert(displayUserIds, 1, requestingUserId)
	end
	if not targetUserIsInOthers then
		table.insert(displayUserIds, 1, targetUserId)
	end

	local baseUserIds = dedupeUserIds(displayUserIds)
	local currentViewMode: ViewMode = "Everyone"
	local renderFavoritesWindow: () -> () = function() end

	local function setViewMode(nextMode: ViewMode)
		if nextMode == currentViewMode then
			return
		end
		currentViewMode = nextMode
		renderFavoritesWindow()
	end

	-- Custom close button
	local closeButtonTileSpec = windows.CreateCloseButtonTileSpec(nil)

	renderFavoritesWindow = function()
		local filteredUserIds = getFilteredUserIds(currentViewMode, targetUserId, requestingUserId, baseUserIds)

		local titleRow = createTitleRow(targetUserId)
		local viewToggleTileSpec = createViewToggleTileSpec(currentViewMode, setViewMode)
		local dataRows = createDataRow(favoriteResponse, viewToggleTileSpec)

		local scrollingFrameHeaderRow = createScrollingFrameHeaderRow(targetUserId, requestingUserId, filteredUserIds, favoriteResponse)
		local scrollingFrameDataRows = createScrollingFrameDataRows(targetUserId, requestingUserId, filteredUserIds, favoriteResponse)

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
			order = 4,
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
			order = 5,
			height = UDim.new(0, generalRowHeight),
			horizontalAlignment = Enum.HorizontalAlignment.Center,
			tileSpecs = { closeButtonTileSpec },
		}

		local allRowSpecs: { wt.rowSpec } = { titleRow }
		for _, rowSpec in ipairs(dataRows) do
			table.insert(allRowSpecs, rowSpec)
		end
		table.insert(allRowSpecs, scrollingFrameRowSpec)
		table.insert(allRowSpecs, closeRow)

		local guiSpec: wt.guiSpec = {
			name = "FavoritesModal",
			rowSpecs = allRowSpecs,
		}

		local maxIntendedRowsOfScrollingFrameToShow = 12
		local actualRowsAvailable = #favoriteResponse.racesAndInfo
		local usingHowManyRowsToShow = math.min(actualRowsAvailable + 1, maxIntendedRowsOfScrollingFrameToShow)
		local scrollFramePixelHeight: number = usingHowManyRowsToShow * generalRowHeight

		scrollingFrameSpec.howManyRowsToShow = usingHowManyRowsToShow
		_annotate(string.format("set howManyRowsToShow to %d", usingHowManyRowsToShow))

		local fixedRowsPixels = 0
		for _, rowSpec in ipairs(allRowSpecs) do
			if rowSpec.height.Scale <= 0 then
				fixedRowsPixels += rowSpec.height.Offset
			end
		end
		local totalHeight = scrollFramePixelHeight + fixedRowsPixels + 4

		local filteredCount = #filteredUserIds
		local xScale = math.min(0.9, math.min(0.7, 0.3 + 0.06 * filteredCount))
		_annotate(
			string.format(
				"favorites size calc -> xScale: %0.1f, visibleUserIds: %d, actualRowsAvailable: %d, maxRowsVisibleByDefault: %d, rowsToShow: %d, finalFavoriteWindowHeightYPixels: %d",
				xScale,
				filteredCount,
				actualRowsAvailable,
				maxIntendedRowsOfScrollingFrameToShow,
				usingHowManyRowsToShow,
				totalHeight
			)
		)

		local theGuiResult = windows.CreatePopup(
			guiSpec,
			"FavoritesGui",
			true, --draggable
			true, --resizable
			false, --minimizable
			true, --pinnable
			true, --dismissableWithX
			false, --dismissableByClick
			UDim2.new(xScale, 0, 0, totalHeight),
			usingHowManyRowsToShow,
			{
				settingName = "FAVORITES_GUI_LAYOUT",
				settingKey = "position",
				saveSize = true,
				sizeKey = "favorites_size",
				clampOnLoad = true,
			},
			nil,
			{
				key = "FavoritesGui",
			}
		)
		local theGui = theGuiResult.sgui
		-- Position is automatically loaded by windowFunctions persistence system

		styleViewToggleContainer(theGui)
		theGui.Parent = playerGui
	end

	renderFavoritesWindow()
end

_annotate("end")

return module
