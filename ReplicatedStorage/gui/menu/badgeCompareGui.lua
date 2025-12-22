--!strict

-- badgeCompareGui.lua
-- CLIENT-ONLY: Renders the badge comparison popup between two players.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local colors = require(game.ReplicatedStorage.util.colors)
local tt = require(game.ReplicatedStorage.types.gametypes)
local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)
local wt = require(game.StarterPlayer.StarterPlayerScripts.guis.windowsTypes)

local module = {}

local TITLE_HEIGHT = 34
local SUMMARY_HEIGHT = 76
local LIST_HEADER_HEIGHT = 28
local ROW_HEIGHT = 52
local MAX_VISIBLE_BADGE_ROWS = 6

local function formatLatestBadge(latestBadgeName: string?): string
	if latestBadgeName and latestBadgeName ~= "" then
		return "Latest: " .. latestBadgeName
	end
	return "Latest: (none)"
end

local function buildSummaryTile(user: tt.badgeCompareUserSummary, order: number): wt.tileSpec
	return {
		name = "Summary_" .. tostring(user.userId),
		order = order,
		width = UDim.new(0.45, 0),
		spec = {
			type = "rowTile",
			name = "SummaryRow",
			tileSpecs = {
				{
					name = "Portrait",
					order = 1,
					width = UDim.new(0, 60),
					spec = {
						type = "portrait",
						userId = user.userId,
						doPopup = true,
						backgroundColor = colors.defaultGrey,
					},
				},
				{
					name = "SummaryText",
					order = 2,
					width = UDim.new(1, -60),
					spec = {
						type = "text",
						text = string.format("%s\nBadges: %d\n%s", user.username, user.badgeCount, formatLatestBadge(user.latestBadgeName)),
						backgroundColor = colors.defaultGrey,
						textColor = colors.black,
						isBold = true,
						textWrapped = true,
						textScaled = false,
						textSize = 18,
						leftPadding = 6,
					},
				},
			},
		},
	}
end

local function buildListHeader(label: string): wt.rowSpec
	return {
		name = "ListHeader_" .. label,
		order = 1,
		height = UDim.new(0, LIST_HEADER_HEIGHT),
		tileSpecs = {
			{
				name = "IconHeader",
				order = 1,
				width = UDim.new(0, 50),
				spec = {
					type = "text",
					text = "",
					backgroundColor = colors.blueDone,
					textColor = colors.white,
				},
			},
			{
				name = "NameHeader",
				order = 2,
				width = UDim.new(1, -50),
				spec = {
					type = "text",
					text = label,
					backgroundColor = colors.blueDone,
					textColor = colors.white,
					isBold = true,
					textXAlignment = Enum.TextXAlignment.Left,
					leftPadding = 6,
				},
			},
		},
	}
end

local function buildBadgeRows(badges: { tt.badgeCompareBadgeEntry }): { wt.rowSpec }
	if #badges == 0 then
		return {
			{
				name = "NoneRow",
				order = 1,
				height = UDim.new(0, ROW_HEIGHT),
				searchText = "none",
				tileSpecs = {
					{
						name = "NoneCell",
						order = 1,
						width = UDim.new(1, 0),
						spec = {
							type = "text",
							text = "None",
							backgroundColor = colors.defaultGrey,
							textColor = colors.black,
							textXAlignment = Enum.TextXAlignment.Center,
						},
					},
				},
			},
		}
	end

	local rows: { wt.rowSpec } = {}
	for i, badge in ipairs(badges) do
		table.insert(rows, {
			name = "Badge_" .. tostring(badge.assetId),
			order = i,
			height = UDim.new(0, ROW_HEIGHT),
			searchText = string.format("%s %s", badge.name, badge.badgeClass),
			tileSpecs = {
				{
					name = "Icon",
					order = 1,
					width = UDim.new(0, 50),
					tooltipText = badge.hint or badge.name,
					spec = {
						type = "image",
						imageId = badge.iconImageId,
						scaleType = Enum.ScaleType.Fit,
						doPopup = true,
						backgroundColor = colors.defaultGrey,
					},
				},
				{
					name = "Name",
					order = 2,
					width = UDim.new(1, -50),
					tooltipText = badge.hint or badge.name,
					spec = {
						type = "text",
						text = string.format("%s (%s)", badge.name, badge.badgeClass),
						backgroundColor = colors.defaultGrey,
						textColor = colors.black,
						textXAlignment = Enum.TextXAlignment.Left,
						textWrapped = true,
						textScaled = false,
						textSize = 18,
						leftPadding = 6,
					},
				},
			},
		})
	end
	return rows
end

local function buildBadgeListTile(title: string, badges: { tt.badgeCompareBadgeEntry }, order: number, enableSearch: boolean): wt.tileSpec
	local rows = buildBadgeRows(badges)
	local rowsToShow = math.min(MAX_VISIBLE_BADGE_ROWS, #rows + 1)
	local scrollingFrameSpec: wt.scrollingFrameTileSpec = {
		type = "scrollingFrameTileSpec",
		name = "BadgeList_" .. title,
		headerRow = buildListHeader(title),
		dataRows = rows,
		stickyRows = {},
		rowHeight = ROW_HEIGHT,
		howManyRowsToShow = rowsToShow,
		searchConfig = if enableSearch
			then {
				placeholderText = "Search badges...",
				countNoun = "badges",
			}
			else nil,
	}

	return {
		name = "ListTile_" .. title,
		order = order,
		width = UDim.new(0.5, -4),
		spec = scrollingFrameSpec,
	}
end

local function buildGuiSpec(notification: tt.badgeCompareNotification): wt.guiSpec
	local titleText = string.format("Badge comparison: %s vs %s", notification.userA.username, notification.userB.username)
	local rows: { wt.rowSpec } = {}

	table.insert(rows, {
		name = "TitleRow",
		order = 1,
		height = UDim.new(0, TITLE_HEIGHT),
		tileSpecs = {
			{
				name = "Title",
				order = 1,
				width = UDim.new(1, 0),
				spec = {
					type = "text",
					text = titleText,
					isBold = true,
					textXAlignment = Enum.TextXAlignment.Center,
					backgroundColor = colors.signColor,
					textColor = colors.white,
				},
			},
		},
	})

	table.insert(rows, {
		name = "SummaryRow",
		order = 2,
		height = UDim.new(0, SUMMARY_HEIGHT),
		tileSpecs = {
			buildSummaryTile(notification.userA, 1),
			{
				name = "Shared",
				order = 2,
				width = UDim.new(0.1, 0),
				spec = {
					type = "text",
					text = string.format("Shared:\n%d", notification.sharedBadgeCount),
					backgroundColor = colors.defaultGrey,
					textColor = colors.black,
					isBold = true,
					textXAlignment = Enum.TextXAlignment.Center,
					textYAlignment = Enum.TextYAlignment.Center,
					textWrapped = true,
					textScaled = false,
					textSize = 18,
				},
			},
			buildSummaryTile(notification.userB, 3),
		},
	})

	table.insert(rows, {
		name = "ListRow",
		order = 3,
		height = UDim.new(0, (ROW_HEIGHT * MAX_VISIBLE_BADGE_ROWS) + LIST_HEADER_HEIGHT),
		tileSpecs = {
			buildBadgeListTile("Badges only " .. notification.userA.username, notification.onlyA, 1, true),
			buildBadgeListTile("Badges only " .. notification.userB.username, notification.onlyB, 2, false),
		},
	})

	table.insert(rows, {
		name = "CloseRow",
		order = 4,
		height = UDim.new(0, 32),
		tileSpecs = { windows.StandardCloseButton },
	})

	return {
		name = "BadgeCompareGui",
		rowSpecs = rows,
	}
end

function module.ShowBadgeCompare(notification: tt.badgeCompareNotification)
	local totalRowsLeft = math.max(#notification.onlyA, 1)
	local totalRowsRight = math.max(#notification.onlyB, 1)
	local estimatedRowsToShow = math.clamp(math.max(totalRowsLeft, totalRowsRight, 3), 3, MAX_VISIBLE_BADGE_ROWS)
	local totalHeight = TITLE_HEIGHT + SUMMARY_HEIGHT + LIST_HEADER_HEIGHT + (estimatedRowsToShow * ROW_HEIGHT) + 32

	local guiSpec = buildGuiSpec(notification)

	local _ = windows.CreatePopup(
		guiSpec,
		"BadgeComparePopup",
		true, -- draggable
		true, -- resizable
		false, -- minimizable
		false, -- pinnable
		true, -- dismissableWithX
		false, -- dismissableByClick
		UDim2.new(0.62, 0, 0, totalHeight),
		estimatedRowsToShow
	)
end

_annotate("end")
return module

--[[ SPEC
Feature: /badgecompare <A> <B> (or single-arg where A is the requester)
Goal: Show a side-by-side badge comparison popup for two users.
Behavior:
- Title: "Badge comparison: A vs B"
- Each side shows: portrait, username, total badges, latest badge name.
- Shared count displayed between sides.
- Lists show badges only A has and only B has (name + icon + class), searchable and scrollable.
- Close button at bottom.
]]--

