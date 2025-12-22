--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayersService = game:GetService("Players")
local colors = require(game.ReplicatedStorage.util.colors)
local tt = require(game.ReplicatedStorage.types.gametypes)
local gt = require(game.ReplicatedStorage.gui.guiTypes)
local badgeSorts = require(game.ReplicatedStorage.util.badgeSorts)
local remotes = require(game.ReplicatedStorage.util.remotes)
local BadgeProgressFunction = remotes.getRemoteFunction("BadgeProgressFunction") :: RemoteFunction
local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)
local wt = require(game.StarterPlayer.StarterPlayerScripts.guis.windowsTypes)
local settings = require(game.ReplicatedStorage.settings)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)

local module = {}

-- Track current pinned badge for UI state
local currentPinnedBadge: string = ""

-- Filter state for badge popup
local currentFilterMode: string = "all" -- "all", "missingMe", "missingAnyone", "missingEveryone"
local badgeFilterMetaCache: { [string]: { missingMe: boolean, missingAnyone: boolean, missingEveryone: boolean } } = {}

local imageWidthPixels = 40
local sectionWidthsScale = { pin = 0.06, type = 0.14, badge = 0.30, people = 0.50 }
local rowHeightPixels = 40

-- Progress tile helper function
local function createProgressTile(progress: number?, baseNumber: number?, got: boolean, order: number): wt.tileSpec
	if got then
		return {
			name = "Got",
			order = order,
			width = UDim.new(1, 0),
			spec = {
				type = "text",
				text = "got",
				backgroundColor = colors.greenGo,
				textColor = colors.black,
				isBold = false,
				isMonospaced = false,
				textXAlignment = Enum.TextXAlignment.Center,
				textScaled = false,
			},
		}
	elseif not progress then
		return {
			name = "Nope",
			order = order,
			width = UDim.new(1, 0),
			spec = {
				type = "text",
				text = "nope",
				backgroundColor = colors.redStop,
				textColor = colors.black,
				isBold = false,
				isMonospaced = false,
				textXAlignment = Enum.TextXAlignment.Center,
				textScaled = false,
			},
		}
	else
		-- At this point progress is known to be truthy, and we need baseNumber
		local safeProgress: number = progress :: number
		local safeBaseNumber: number = baseNumber or 1
		local filledRatio = safeProgress / safeBaseNumber
		local remaining = safeBaseNumber - safeProgress

		return {
			name = "Partial",
			order = order,
			width = UDim.new(1, 0),
			spec = {
				type = "rowTile",
				name = "ProgressBar",
				tileSpecs = {
					{
						name = "Filled",
						order = 1,
						width = UDim.new(filledRatio, 0),
						spec = {
							type = "text",
							text = tostring(safeProgress),
							backgroundColor = colors.greenGo,
							textColor = colors.black,
							textXAlignment = Enum.TextXAlignment.Center,
							textScaled = false,
						},
					},
					{
						name = "Empty",
						order = 2,
						width = UDim.new(1 - filledRatio, 0),
						spec = {
							type = "text",
							text = tostring(remaining),
							backgroundColor = colors.redStop,
							textColor = colors.black,
							textXAlignment = Enum.TextXAlignment.Center,
							textScaled = false,
						},
					},
				},
			},
		}
	end
end

-- Helper to create header row spec
local function createHeaderRow(orderedUserIds: { number }, userBadgeCounts: { [number]: number }): wt.rowSpec
	local tiles: { wt.tileSpec } = {}

	-- Badge icon column (fixed pixel width, no header text - just empty space)
	table.insert(tiles, {
		name = "Icon",
		order = 1,
		width = UDim.new(0, imageWidthPixels),
		spec = {
			type = "text",
			text = "",
			backgroundColor = colors.blueDone,
			textColor = colors.black,
			isBold = true,
			textXAlignment = Enum.TextXAlignment.Center,
		},
	})

	table.insert(tiles, {
		name = "Pin",
		order = 2,
		width = UDim.new(sectionWidthsScale.pin, 0),
		tooltipText = "Pin a badge to display on leaderboard",
		spec = {
			type = "text",
			text = "Pin",
			backgroundColor = colors.blueDone,
			textColor = colors.black,
			isBold = true,
			textXAlignment = Enum.TextXAlignment.Center,
		},
	})

	table.insert(tiles, {
		name = "Type",
		order = 3,
		width = UDim.new(sectionWidthsScale.type, 0),
		spec = {
			type = "text",
			text = "Type",
			backgroundColor = colors.blueDone,
			textColor = colors.black,
			isBold = true,
			textXAlignment = Enum.TextXAlignment.Center,
		},
	})

	table.insert(tiles, {
		name = "Badge",
		order = 4,
		width = UDim.new(sectionWidthsScale.badge, 0),
		spec = {
			type = "text",
			text = "Badge",
			backgroundColor = colors.blueDone,
			textColor = colors.black,
			isBold = true,
			textXAlignment = Enum.TextXAlignment.Center,
		},
	})

	local peopleWidthPerUser = 1 / #orderedUserIds -- Relative to container
	local peopleTiles: { wt.tileSpec } = {}

	for i, userId in ipairs(orderedUserIds) do
		local username = "..."
		local player = PlayersService:GetPlayerByUserId(userId)
		if player then
			username = player.Name
		end

		local count = userBadgeCounts[userId] or 0
		local headerText = string.format("%s\n(%d)", username, count)

		table.insert(peopleTiles, {
			name = "UserHeader_" .. userId,
			order = i,
			width = UDim.new(peopleWidthPerUser, 0),
			spec = {
				type = "rowTile",
				name = "UserHeader",
				tileSpecs = {
					{
						name = "Portrait",
						order = 1,
						width = UDim.new(0, 45),
						spec = {
							type = "portrait",
							userId = userId,
							doPopup = true,
							backgroundColor = (userId == PlayersService.LocalPlayer.UserId) and colors.meColor or colors.defaultGrey,
						},
					},
					{
						name = "Name",
						order = 2,
						width = UDim.new(1, -45),
						spec = {
							type = "text",
							text = headerText,
							backgroundColor = (userId == PlayersService.LocalPlayer.UserId) and colors.meColor or colors.defaultGrey,
							textXAlignment = Enum.TextXAlignment.Left,
							isMonospaced = false,
						},
					},
				},
			},
		})
	end

	table.insert(tiles, {
		name = "PeopleHeaders",
		order = 5,
		width = UDim.new(sectionWidthsScale.people, 0),
		spec = {
			type = "rowTile",
			name = "PeopleHeaderRow",
			tileSpecs = peopleTiles,
		},
	})

	return {
		name = "Header",
		order = 1,
		height = UDim.new(0, 45),
		tileSpecs = tiles,
	}
end

-- Helper to create pin tile spec for a badge
local function createPinTile(badgeName: string, isPinned: boolean, onPinToggle: (TextButton) -> ()): wt.tileSpec
	local buttonText = isPinned and "X" or "+"
	local buttonColor = isPinned and colors.meColor or colors.defaultGrey

	return {
		name = "PinButton",
		order = 2,
		width = UDim.new(sectionWidthsScale.pin, 0),
		spec = {
			type = "button",
			text = buttonText,
			backgroundColor = buttonColor,
			textColor = colors.black,
			textXAlignment = Enum.TextXAlignment.Center,
			onClick = function(_: InputObject, theButton: TextButton)
				onPinToggle(theButton)
			end,
		},
	}
end

-- Filter metadata type for each badge
type BadgeFilterMeta = {
	missingMe: boolean, -- local player doesn't have this badge
	missingAnyone: boolean, -- at least one player is missing this badge
	missingEveryone: boolean, -- all players are missing this badge
}

-- Helper to create badge row spec
local function createBadgeRow(badge: tt.badgeDescriptor, badgeAttainments: { [number]: tt.badgeProgress }, orderedUserIds: { number }, rowIndex: number, onPinToggle: (string, TextButton) -> (), filterMeta: BadgeFilterMeta): wt.rowSpec
	local tiles: { wt.tileSpec } = {}

	-- Badge icon (first column, fixed width, with hover popup)
	-- No backgroundColor = transparent, since badges are circular
	table.insert(tiles, {
		name = "BadgeIcon",
		order = 1,
		width = UDim.new(0, imageWidthPixels),
		tooltipText = badge.hint or (badge.name .. " badge"),
		spec = {
			type = "image",
			imageId = badge.iconImageId,
			scaleType = Enum.ScaleType.Fit,
			doPopup = true,
		},
	})

	-- Pin button
	local isPinned = currentPinnedBadge == badge.name
	table.insert(
		tiles,
		createPinTile(badge.name, isPinned, function(theButton: TextButton)
			onPinToggle(badge.name, theButton)
		end)
	)

	-- Badge Class
	table.insert(tiles, {
		name = "Class",
		order = 3,
		width = UDim.new(sectionWidthsScale.type, 0),
		spec = {
			type = "text",
			text = badge.badgeClass,
			backgroundColor = colors.defaultGrey,
			textColor = colors.black,
			textXAlignment = Enum.TextXAlignment.Center,
		},
	})

	-- Badge Name
	table.insert(tiles, {
		name = "BadgeInfo",
		order = 4,
		width = UDim.new(sectionWidthsScale.badge, 0),
		tooltipText = badge.hint or (badge.name .. " badge"),
		spec = {
			type = "text",
			text = badge.name,
			backgroundColor = colors.defaultGrey,
			textColor = colors.black,
			textXAlignment = Enum.TextXAlignment.Left,
			leftPadding = 8,
		},
	})

	-- User Progress Columns
	-- badgeAttainments[i] corresponds to orderedUserIds[i] (ordered during pivot)
	local peopleTiles: { wt.tileSpec } = {}

	for i, _userId in ipairs(orderedUserIds) do
		local att = badgeAttainments[i]
		if att then
			table.insert(peopleTiles, createProgressTile(att.progress, badge.baseNumber, att.got, i))
		else
			-- Should not happen if logic is correct, but handle gracefully
			table.insert(peopleTiles, {
				name = "Missing",
				order = i,
				width = UDim.new(1, 0),
				spec = {
					type = "text",
					text = "-",
					backgroundColor = colors.defaultGrey,
				},
			})
		end
	end

	table.insert(tiles, {
		name = "PeopleProgress",
		order = 5,
		width = UDim.new(sectionWidthsScale.people, 0),
		spec = {
			type = "rowTile",
			name = "PeopleProgressRow",
			tileSpecs = peopleTiles,
		},
	})

	return {
		name = "Badge_" .. badge.name,
		order = rowIndex,
		height = UDim.new(0, rowHeightPixels),
		searchText = string.format("%s %s", badge.badgeClass, badge.name),
		tileSpecs = tiles,
	}
end

local getBadgeStatusModal = function(localPlayer: Player): ScreenGui
	-- Load current pinned badge from settings
	local pinnedBadgeSetting = settings.GetSettingByName(settingEnums.settingDefinitions.PINNED_BADGE.name)
	currentPinnedBadge = pinnedBadgeSetting and pinnedBadgeSetting.stringValue or ""

	local orderedUserIdsInServer: { number } = { localPlayer.UserId }

	for _, player in ipairs(PlayersService:GetPlayers()) do
		if player.UserId ~= localPlayer.UserId then
			table.insert(orderedUserIdsInServer, player.UserId)
		end
	end

	local badgeProgressInfo: { [number]: { tt.badgeProgress } } = BadgeProgressFunction:InvokeServer(orderedUserIdsInServer, "badgeButtonSetup.")

	-- Calculate user badge counts
	local userBadgeCounts: { [number]: number } = {}
	for userId, chunk in pairs(badgeProgressInfo) do
		local numericUserId = tonumber(userId)
		if numericUserId then
			userBadgeCounts[numericUserId] = 0
			for _, ba in ipairs(chunk) do
				if ba.got then
					userBadgeCounts[numericUserId] = userBadgeCounts[numericUserId] + 1
				end
			end
		end
	end

	-- Pivot data
	local badgeAttainmentMap: { [string]: { badge: tt.badgeDescriptor, badgeStatus: { [number]: tt.badgeProgress } } } = {}

	-- We must ensure we process user data in the same order as columns
	local sortedUserBadgeStatus: { [number]: { tt.badgeProgress } } = {}
	for _, requestedUserIdInOrder in ipairs(orderedUserIdsInServer) do
		for theUserId, item in pairs(badgeProgressInfo) do
			local numericUserId = tonumber(theUserId)
			if numericUserId and requestedUserIdInOrder == numericUserId then
				sortedUserBadgeStatus[numericUserId] = item
				break
			end
		end
	end

	for _, userId in ipairs(orderedUserIdsInServer) do
		local oUserAttainments = sortedUserBadgeStatus[userId]
		if oUserAttainments then
			for _, oUserAttainment: tt.badgeProgress in ipairs(oUserAttainments) do
				if badgeAttainmentMap[oUserAttainment.badge.name] == nil then
					badgeAttainmentMap[oUserAttainment.badge.name] = { badge = oUserAttainment.badge, badgeStatus = {} }
				end
				table.insert(badgeAttainmentMap[oUserAttainment.badge.name].badgeStatus, oUserAttainment)
			end
		end
	end

	-- Convert map to ordered list
	local orderedBadges: { { badge: tt.badgeDescriptor, badgeStatus: { [number]: tt.badgeProgress } } } = {}
	for _: string, obj in pairs(badgeAttainmentMap) do
		table.insert(orderedBadges, { badge = obj.badge, badgeStatus = obj.badgeStatus })
	end

	table.sort(orderedBadges, function(a, b)
		return badgeSorts.BadgeSort(a.badge, b.badge)
	end)

	-- Build Windows Specs
	local headerRow = createHeaderRow(orderedUserIdsInServer, userBadgeCounts)
	local badgeRows = {}

	-- Track all pin buttons for UI updates when selection changes
	local pinButtonsByBadgeName: { [string]: TextButton } = {}

	-- Pin toggle callback - updates setting and refreshes UI state
	local function onPinToggle(badgeName: string, clickedButton: TextButton)
		-- Register button if not already tracked
		pinButtonsByBadgeName[badgeName] = clickedButton

		local previousPinned = currentPinnedBadge
		local newPinnedBadge = ""
		if currentPinnedBadge == badgeName then
			-- Unpin
			newPinnedBadge = ""
		else
			-- Pin this badge
			newPinnedBadge = badgeName
		end
		currentPinnedBadge = newPinnedBadge

		-- Update clicked button
		clickedButton.Text = newPinnedBadge == badgeName and "X" or "+"
		clickedButton.BackgroundColor3 = newPinnedBadge == badgeName and colors.meColor or colors.defaultGrey

		-- If we had a previously pinned badge, reset its button
		if previousPinned ~= "" and previousPinned ~= badgeName then
			local prevButton = pinButtonsByBadgeName[previousPinned]
			if prevButton then
				prevButton.Text = "+"
				prevButton.BackgroundColor3 = colors.defaultGrey
				_annotate(string.format("Updated previous pinned badge button: %s", previousPinned))
			else
				local registeredBadges = {}
				for name, _ in pairs(pinButtonsByBadgeName) do
					table.insert(registeredBadges, name)
				end
				annotater.Error(string.format("Previous pinned badge button not found in registry: %s. Registered badges: %s", previousPinned, table.concat(registeredBadges, ", ")))
			end
		end

		-- Save to settings
		settings.SetSetting({
			name = settingEnums.settingDefinitions.PINNED_BADGE.name,
			domain = settingEnums.settingDefinitions.PINNED_BADGE.domain,
			kind = settingEnums.settingDefinitions.PINNED_BADGE.kind,
			stringValue = newPinnedBadge,
		})
		_annotate(string.format("Pinned badge changed to: %s", newPinnedBadge == "" and "(none)" or newPinnedBadge))
	end

	-- Clear filter cache and compute filter metadata for each badge
	badgeFilterMetaCache = {}
	local localUserId = localPlayer.UserId

	for i, el in ipairs(orderedBadges) do
		-- Compute filter metadata for this badge
		local missingMe = false
		local missingAnyone = false
		local gotCount = 0

		for j, userId in ipairs(orderedUserIdsInServer) do
			local att = el.badgeStatus[j]
			if att and att.got then
				gotCount += 1
			else
				missingAnyone = true
				if userId == localUserId then
					missingMe = true
				end
			end
		end

		local missingEveryone = (gotCount == 0)

		local filterMeta = {
			missingMe = missingMe,
			missingAnyone = missingAnyone,
			missingEveryone = missingEveryone,
		}
		badgeFilterMetaCache[el.badge.name] = filterMeta

		table.insert(badgeRows, createBadgeRow(el.badge, el.badgeStatus, orderedUserIdsInServer, i, onPinToggle, filterMeta))
	end

	-- Calculate rows to show based on actual content (max 10)
	local maxRowsToShow = 10
	local actualBadgeCount = #badgeRows
	local rowsToShow = math.min(actualBadgeCount + 1, maxRowsToShow) -- +1 for header
	rowsToShow = math.max(rowsToShow, 2) -- At least header + 1 data row

	local scrollingFrameSpec: wt.scrollingFrameTileSpec = {
		type = "scrollingFrameTileSpec",
		name = "BadgesScrollingFrame",
		headerRow = headerRow,
		dataRows = badgeRows,
		stickyRows = {},
		rowHeight = rowHeightPixels,
		howManyRowsToShow = rowsToShow,
		searchConfig = {
			placeholderText = "Search badges...",
			countNoun = "badges",
			autoFocus = true,
		},
	}

	-- Calculate popup height based on actual content
	local titleHeight = 36
	local searchHeight = 30 -- windows.CreatePopup injects a search row when scrollingFrameSpec.searchConfig is set
	local filterButtonHeight = 26
	local closeButtonHeight = 30
	local scrollingFrameHeight = rowsToShow * rowHeightPixels
	local totalHeight = titleHeight + searchHeight + scrollingFrameHeight + filterButtonHeight + closeButtonHeight

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
					text = "  Badges  ",
					isMonospaced = false,
					isBold = true,
					backgroundColor = colors.signColor,
					textColor = colors.white,
					textXAlignment = Enum.TextXAlignment.Center,
				},
			},
		},
	}

	-- Filter row buttons
	local filterRowSpec: wt.rowSpec = {
		name = "FilterRow",
		order = 3,
		height = UDim.new(0, filterButtonHeight),
		tileSpecs = {
			{
				name = "FilterLabel",
				order = 1,
				width = UDim.new(0.15, 0),
				spec = {
					type = "text",
					text = "Filter:",
					backgroundColor = colors.defaultGrey,
					textColor = colors.black,
					textXAlignment = Enum.TextXAlignment.Right,
					rightPadding = 4,
				},
			},
			{
				name = "FilterAll",
				order = 2,
				width = UDim.new(0.15, 0),
				spec = {
					type = "button",
					text = "All",
					backgroundColor = colors.meColor, -- Active by default
					textColor = colors.black,
					textXAlignment = Enum.TextXAlignment.Center,
					onClick = function(_: InputObject, _theButton: TextButton) end, -- Placeholder, hooked after creation
				},
			},
			{
				name = "FilterMissingMe",
				order = 3,
				width = UDim.new(0.23, 0),
				tooltipText = "Show badges you don't have yet",
				spec = {
					type = "button",
					text = "My Missing",
					backgroundColor = colors.defaultGrey,
					textColor = colors.black,
					textXAlignment = Enum.TextXAlignment.Center,
					onClick = function(_: InputObject, _theButton: TextButton) end,
				},
			},
			{
				name = "FilterMissingAnyone",
				order = 4,
				width = UDim.new(0.24, 0),
				tooltipText = "Show badges where at least one player is missing",
				spec = {
					type = "button",
					text = "Anyone Missing",
					backgroundColor = colors.defaultGrey,
					textColor = colors.black,
					textXAlignment = Enum.TextXAlignment.Center,
					onClick = function(_: InputObject, _theButton: TextButton) end,
				},
			},
			{
				name = "FilterMissingEveryone",
				order = 5,
				width = UDim.new(0.23, 0),
				tooltipText = "Show badges nobody in the server has yet",
				spec = {
					type = "button",
					text = "Nobody Has",
					backgroundColor = colors.defaultGrey,
					textColor = colors.black,
					textXAlignment = Enum.TextXAlignment.Center,
					onClick = function(_: InputObject, _theButton: TextButton) end,
				},
			},
		},
	}

	-- rowSpec.height uses UDim where:
	--   UDim.new(0, pixels) = fixed pixel height (not resizable)
	--   UDim.new(weight, 0) = proportional weight (resizable)
	-- For weight-based rows, windows.applyProportionalHeights normalizes all weights to sum to 1.
	-- Example: weights 400, 30, 30 become proportions 0.87, 0.065, 0.065.
	-- DO NOT confuse weight values with pixel values—UDim.new(400, 0) means "weight 400", not "400px".
	local guiSpec: wt.guiSpec = {
		name = "BadgeStatus",
		rowSpecs = {
			titleRowSpec,
			{
				name = "ScrollingFrameRow",
				order = 2,
				height = UDim.new(scrollingFrameHeight, 0), -- Weight-based: gets most vertical space
				tileSpecs = {
					{
						name = "ScrollingFrame",
						order = 1,
						width = UDim.new(1, 0),
						spec = scrollingFrameSpec,
					},
				},
			},
			filterRowSpec,
			{
				name = "CloseButtonRow",
				order = 4,
				height = UDim.new(0, closeButtonHeight),
				tileSpecs = { windows.StandardCloseButton },
			},
		},
	}

	local popupResult = windows.CreatePopup(
		guiSpec,
		"BadgeStatusPopup",
		true, -- draggable
		true, -- resizable
		false, -- minimizable
		true, -- pinnable
		true, -- dismissableWithX
		false, -- dismissableByClick - standard modal behavior: only close button closes
		UDim2.new(0.6, 0, 0, totalHeight),
		rowsToShow
	)
	local popup = popupResult.sgui

	-- Register all pin buttons and set up filters after popup is created
	-- Use retry logic with waits to handle timing issues where popup structure isn't ready yet
	task.defer(function()
		local maxRetries = 10
		local retryDelay = 0.1

		local outerFrame: Frame? = nil
		local contentFrame: Frame? = nil
		local scrollingFrameContainer: Frame? = popupResult.builtContent["ScrollingFrameRow"]
		local scrollingFrame: Frame? = nil
		local stickyContainerFrame: Frame? = nil
		local stickyScrollingFrame: ScrollingFrame? = nil

		-- Retry finding the popup structure
		for attempt = 1, maxRetries do
			outerFrame = popup:FindFirstChild("outer_BadgeStatusPopup") :: Frame?
			if not outerFrame then
				if attempt < maxRetries then
					task.wait(retryDelay)
					continue
				else
					annotater.Error("Badge popup: outer frame not found after retries")
					return
				end
			end
			local outerFrameSafe = outerFrame :: Frame

			contentFrame = outerFrameSafe:FindFirstChild("content_BadgeStatusPopup") :: Frame?
			if not contentFrame then
				if attempt < maxRetries then
					task.wait(retryDelay)
					continue
				else
					annotater.Error("Badge popup: content frame not found after retries")
					return
				end
			end
			-- scrollingFrameContainer is already set from builtContent["ScrollingFrameRow"]
			if not scrollingFrameContainer then
				annotater.Error("Badge popup: scrolling frame container not found in builtContent")
				return
			end
			local scrollingFrameContainerSafe = scrollingFrameContainer :: Frame

			-- The scrolling frame is renamed to "0001_ScrollingFrame" when placed in the row
			scrollingFrame = scrollingFrameContainerSafe:FindFirstChild("0001_ScrollingFrame") :: Frame?
			if not scrollingFrame then
				if attempt < maxRetries then
					task.wait(retryDelay)
					continue
				else
					annotater.Error("Badge popup: scrolling frame not found after retries")
					return
				end
			end
			local scrollingFrameSafe = scrollingFrame :: Frame

			-- Find the sticky scrolling frame manager's frame (ContainerFrame)
			stickyContainerFrame = scrollingFrameSafe:FindFirstChild("BadgesScrollingFrame_StickyFrame") :: Frame?
			if not stickyContainerFrame then
				if attempt < maxRetries then
					task.wait(retryDelay)
					continue
				else
					annotater.Error("Badge popup: sticky container frame not found after retries")
					return
				end
			end
			local stickyContainerFrameSafe = stickyContainerFrame :: Frame

			-- The rows are actually children of the ScrollingFrame inside the ContainerFrame
			stickyScrollingFrame = stickyContainerFrameSafe:FindFirstChild("StickyScrollingFrame") :: ScrollingFrame?
			if not stickyScrollingFrame then
				if attempt < maxRetries then
					task.wait(retryDelay)
					continue
				else
					annotater.Error("Badge popup: sticky scrolling frame not found after retries")
					return
				end
			end

			-- All elements found, break out of retry loop
			break
		end

		-- Verify we have all required elements before proceeding
		if not outerFrame or not contentFrame or not scrollingFrameContainer or not scrollingFrame or not stickyContainerFrame or not stickyScrollingFrame then
			return
		end

		-- Build a map of badge rows for filtering, and register pin buttons
		local badgeRowsByName: { [string]: Frame } = {}

		for _, badgeData in ipairs(orderedBadges) do
			local badgeName = badgeData.badge.name
			for _, rowFrame in stickyScrollingFrame:GetChildren() do
				if not rowFrame:IsA("Frame") then
					continue
				end
				local badgeInfoTile = rowFrame:FindFirstChild("0004_BadgeInfo") :: TextLabel?
				if badgeInfoTile and badgeInfoTile.Text == badgeName then
					badgeRowsByName[badgeName] = rowFrame

					-- Set filter attributes from cache
					local filterMeta = badgeFilterMetaCache[badgeName]
					if filterMeta then
						rowFrame:SetAttribute("BadgeMissingMe", if filterMeta.missingMe then 1 else 0)
						rowFrame:SetAttribute("BadgeMissingAnyone", if filterMeta.missingAnyone then 1 else 0)
						rowFrame:SetAttribute("BadgeMissingEveryone", if filterMeta.missingEveryone then 1 else 0)
					end

					-- Register pin button
					local pinButton = rowFrame:FindFirstChild("0002_PinButton") :: TextButton?
					if pinButton then
						pinButtonsByBadgeName[badgeName] = pinButton
						_annotate(string.format("Registered pin button for badge: %s", badgeName))
					end
					break
				end
			end
		end

		-- Find filter buttons (note: order gets shifted due to search chrome row injection)
		-- Original order 3 becomes order 4 after search chrome is inserted at order 2
		local filterRow = contentFrame:FindFirstChild("0004_FilterRow") :: Frame?
		if not filterRow then
			annotater.Error("Badge popup: filter row not found")
			return
		end

		local filterAllBtn = filterRow:FindFirstChild("0002_FilterAll") :: TextButton?
		local filterMissingMeBtn = filterRow:FindFirstChild("0003_FilterMissingMe") :: TextButton?
		local filterMissingAnyoneBtn = filterRow:FindFirstChild("0004_FilterMissingAnyone") :: TextButton?
		local filterMissingEveryoneBtn = filterRow:FindFirstChild("0005_FilterMissingEveryone") :: TextButton?

		if not filterAllBtn or not filterMissingMeBtn or not filterMissingAnyoneBtn or not filterMissingEveryoneBtn then
			annotater.Error("Badge popup: one or more filter buttons not found")
			return
		end

		-- Find search box for combining with custom filters
		local searchChromeRow = contentFrame:FindFirstChild("0002_SearchChrome_BadgesScrollingFrame") :: Frame?
		local searchBox: TextBox? = nil
		if searchChromeRow then
			searchBox = searchChromeRow:FindFirstChild("SearchBox") :: TextBox?
		end

		-- Find count value instances for updating the search chrome display
		local shownCountValue = scrollingFrame:FindFirstChild("SearchShownCount_BadgesScrollingFrame") :: IntValue?
		local totalCountValue = scrollingFrame:FindFirstChild("SearchTotalCount_BadgesScrollingFrame") :: IntValue?

		-- Filter application function - combines search and custom filter
		local function applyFilters()
			local searchQuery = ""
			if searchBox then
				searchQuery = string.lower(searchBox.Text)
			end

			local shownCount = 0
			local totalCount = 0

			for badgeName, rowFrame in pairs(badgeRowsByName) do
				totalCount += 1
				local shouldShow = true

				-- Apply search filter
				if searchQuery ~= "" then
					local searchText = string.lower(badgeName)
					local filterMeta = badgeFilterMetaCache[badgeName]
					if filterMeta then
						local badge = nil
						for _, bd in ipairs(orderedBadges) do
							if bd.badge.name == badgeName then
								badge = bd.badge
								break
							end
						end
						if badge then
							searchText = string.lower(badge.badgeClass .. " " .. badgeName)
						end
					end
					if not string.find(searchText, searchQuery, 1, true) then
						shouldShow = false
					end
				end

				-- Apply custom filter
				if shouldShow and currentFilterMode ~= "all" then
					local filterMeta = badgeFilterMetaCache[badgeName]
					if filterMeta then
						if currentFilterMode == "missingMe" and not filterMeta.missingMe then
							shouldShow = false
						elseif currentFilterMode == "missingAnyone" and not filterMeta.missingAnyone then
							shouldShow = false
						elseif currentFilterMode == "missingEveryone" and not filterMeta.missingEveryone then
							shouldShow = false
						end
					end
				end

				rowFrame:SetAttribute("FilteredOut", if shouldShow then 0 else 1)
				if shouldShow then
					shownCount += 1
				end
			end

			-- Update count values for the search chrome to display
			if shownCountValue then
				shownCountValue.Value = shownCount
			end
			if totalCountValue then
				totalCountValue.Value = totalCount
			end

			-- Update count label if present
			local countLabel = searchChromeRow and searchChromeRow:FindFirstChild("CountLabel") :: TextLabel?
			if countLabel then
				if searchQuery ~= "" or currentFilterMode ~= "all" then
					countLabel.Visible = true
					countLabel.Text = string.format("showing %d of %d badges", shownCount, totalCount)
				else
					countLabel.Visible = false
				end
			end

			-- Refresh the sticky scrolling frame by triggering its adjustVisibility
			-- The stickyScrollingFrame listens for _triggerRefresh attribute changes
			local stickyContainer = scrollingFrame:FindFirstChild("BadgesScrollingFrame_StickyFrame")
			if stickyContainer then
				stickyContainer:SetAttribute("_triggerRefresh", tick())
			end
		end

		-- Helper to update filter button appearances
		local function updateFilterButtonAppearances()
			filterAllBtn.BackgroundColor3 = if currentFilterMode == "all" then colors.meColor else colors.defaultGrey
			filterMissingMeBtn.BackgroundColor3 = if currentFilterMode == "missingMe" then colors.meColor else colors.defaultGrey
			filterMissingAnyoneBtn.BackgroundColor3 = if currentFilterMode == "missingAnyone" then colors.meColor else colors.defaultGrey
			filterMissingEveryoneBtn.BackgroundColor3 = if currentFilterMode == "missingEveryone" then colors.meColor else colors.defaultGrey
		end

		-- Wire up filter buttons
		filterAllBtn.Activated:Connect(function()
			currentFilterMode = "all"
			updateFilterButtonAppearances()
			applyFilters()
		end)

		filterMissingMeBtn.Activated:Connect(function()
			currentFilterMode = "missingMe"
			updateFilterButtonAppearances()
			applyFilters()
		end)

		filterMissingAnyoneBtn.Activated:Connect(function()
			currentFilterMode = "missingAnyone"
			updateFilterButtonAppearances()
			applyFilters()
		end)

		filterMissingEveryoneBtn.Activated:Connect(function()
			currentFilterMode = "missingEveryone"
			updateFilterButtonAppearances()
			applyFilters()
		end)

		-- Hook into search box changes to re-apply combined filters
		-- Use task.defer to run after the built-in search handler completes
		if searchBox then
			searchBox:GetPropertyChangedSignal("Text"):Connect(function()
				task.defer(function()
					applyFilters()
				end)
			end)
		end

		-- Initial filter application
		currentFilterMode = "all"
		updateFilterButtonAppearances()
	end)

	return popup
end

local badgeButton: gt.button = {
	name = "Badges",
	contentsGetter = getBadgeStatusModal,
}

module.badgeButton = badgeButton

-- Export the modal getter for external callers (e.g., leaderboard badge count click)
module.getBadgeStatusModal = getBadgeStatusModal

_annotate("end")
return module
