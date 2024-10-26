--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayersService = game:GetService("Players")
local colors = require(game.ReplicatedStorage.util.colors)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local toolTip = require(game.ReplicatedStorage.gui.toolTip)
local tt = require(game.ReplicatedStorage.types.gametypes)
local gt = require(game.ReplicatedStorage.gui.guiTypes)
local badgeSorts = require(game.ReplicatedStorage.util.badgeSorts)
local thumbnails = require(game.ReplicatedStorage.thumbnails)
local remotes = require(game.ReplicatedStorage.util.remotes)
local BadgeProgressFunction = remotes.getRemoteFunction("BadgeProgressFunction") :: RemoteFunction

local module = {}

local sectionWidthsScale = { type = 0.2, badge = 0.3, people = 0.5 }

local rowHeightPixels = 60

local function makeBadgeRowFrame(
	localPlayer: Player,
	badge: tt.badgeDescriptor,
	badgeProgress: { [number]: tt.badgeProgress },
	n: number,
	resultSections: number
): Frame
	local fr = Instance.new("Frame")
	fr.Name = string.format("%04d", n) .. "Badge." .. badge.name
	fr.Size = UDim2.new(1, 0, 0, rowHeightPixels)
	local vv = Instance.new("UIListLayout")
	vv.FillDirection = Enum.FillDirection.Horizontal
	vv.SortOrder = Enum.SortOrder.Name
	vv.Parent = fr
	local badgeClassLabel =
		guiUtil.getTl("00label", UDim2.new(sectionWidthsScale.type, 0, 1, 0), 1, fr, colors.defaultGrey, 1)
	-- label.TextScaled = false

	badgeClassLabel.Text = badge.badgeClass

	badgeClassLabel.TextXAlignment = Enum.TextXAlignment.Center
	badgeClassLabel.TextYAlignment = Enum.TextYAlignment.Center

	------making the badge name section which now should have the image too.

	local badgeNameFrame = Instance.new("Frame")
	badgeNameFrame.Name = "02badgeNameFrame"
	badgeNameFrame.Parent = fr
	badgeNameFrame.Size = UDim2.new(sectionWidthsScale.badge, 0, 1, 0)
	local badgeNameHH = Instance.new("UIListLayout")
	badgeNameHH.FillDirection = Enum.FillDirection.Horizontal
	badgeNameHH.SortOrder = Enum.SortOrder.Name
	badgeNameHH.Parent = badgeNameFrame

	local img = Instance.new("ImageLabel")
	img.Name = "01.Badge.Image"
	img.BorderMode = Enum.BorderMode.Inset
	img.Size = UDim2.new(0, rowHeightPixels, 1, 0)
	img.Parent = badgeNameFrame

	local badgeImageContent = thumbnails.getBadgeAssetThumbnailContent(badge.assetId)
	img.Image = badgeImageContent

	img.BorderSizePixel = 0
	img.BackgroundColor3 = colors.grey

	local badgeNameLabel = guiUtil.getTl(
		"02.Badge.Name",
		UDim2.new(1, -1 * rowHeightPixels, 1, 0),
		2,
		badgeNameFrame,
		colors.defaultGrey,
		1
	)

	badgeNameLabel.Text = badge.name
	toolTip.setupToolTip(badgeNameLabel, badge.hint or "", toolTip.enum.toolTipSize.NormalText)

	badgeNameLabel.TextXAlignment = Enum.TextXAlignment.Left

	local subFrame = Instance.new("Frame")
	subFrame.Name = "03_subframe" .. badge.name
	subFrame.Size = UDim2.new(sectionWidthsScale.people, 0, 1, 0)
	subFrame.Parent = fr
	local hh = Instance.new("UIListLayout")
	hh.FillDirection = Enum.FillDirection.Horizontal
	hh.SortOrder = Enum.SortOrder.Name
	hh.Parent = subFrame
	local resultWidthScale = 1 / resultSections
	local resultWidthPixel = -1 * 10 / resultSections

	-- for _, oUserId in ipairs(orderedUserIds) do
	local progressCounter = 0
	for ii, oAttainment in pairs(badgeProgress) do
		progressCounter += 1
		local progressTileName = string.format("02.%02d-progress-%d", progressCounter, ii)
		if oAttainment.got then --full bar
			local restl = guiUtil.getTl(
				progressTileName,
				UDim2.new(resultWidthScale, resultWidthPixel, 1, 0),
				2,
				subFrame,
				colors.greenGo,
				1
			)
			restl.Text = "got"
		else --progress bar
			if not oAttainment.progress then
				local progressinTL = guiUtil.getTl(
					progressTileName,
					UDim2.new(resultWidthScale, resultWidthPixel, 1, 0),
					4,
					subFrame,
					colors.redStop,
					1
				)
				progressinTL.Text = "nope"
			else
				if not badge.baseNumber then
					annotater.Error("bad badge baseNumber")
					error("bad badge baseNumber")
				end
				local prog = Instance.new("Frame")
				prog.Size = UDim2.new(resultWidthScale, resultWidthPixel, 1, 0)
				prog.Parent = subFrame
				prog.Name = progressTileName
				local hh3 = Instance.new("UIListLayout")
				hh3.Parent = prog
				hh3.FillDirection = Enum.FillDirection.Horizontal
				local remaining = badge.baseNumber - oAttainment.progress
				local fsize = UDim2.new(oAttainment.progress / badge.baseNumber, 0, 1, 0)
				local esize = UDim2.new(remaining / badge.baseNumber, 0, 1, 0)

				local filled = guiUtil.getTl("02filled", fsize, 1, prog, colors.greenGo, 1)
				local empty = guiUtil.getTl("03empty", esize, 1, prog, colors.redStop, 1)
				filled.Text = tostring(oAttainment.progress)
				empty.Text = tostring(remaining)
			end
		end
	end

	return fr
end

local getBadgeStatusModal = function(localPlayer: Player): ScreenGui
	local orderedUserIdsInServer: { number } = { localPlayer.UserId }

	--fill in with other players.
	--get data asap.
	for _, player in ipairs(PlayersService:GetPlayers()) do
		if player.UserId ~= localPlayer.UserId then
			table.insert(orderedUserIdsInServer, player.UserId)
		end
	end

	local badgeProgressInfo: { [number]: { tt.badgeProgress } } =
		BadgeProgressFunction:InvokeServer(orderedUserIdsInServer, "badgeButtonSetup.")

	local screenGui = Instance.new("ScreenGui")
	screenGui.IgnoreGuiInset = true
	screenGui.Name = "badgeStatusFrame"

	local outerFrame = Instance.new("Frame")
	outerFrame.Parent = screenGui
	outerFrame.Position = UDim2.new(0.2, 0, 0.3, 0)
	outerFrame.Size = UDim2.new(0.6, 0, 0.5, 0)
	outerFrame.Name = "03badgeStatusOuterFrame"
	local vv = Instance.new("UIListLayout")
	vv.Parent = outerFrame
	vv.FillDirection = Enum.FillDirection.Vertical

	------------------------HEADER----------------------------
	local headerFrame = Instance.new("Frame")
	headerFrame.Parent = outerFrame
	headerFrame.Name = "01.badges.HeaderRow"
	headerFrame.Size = UDim2.new(1, 0, 0, 45)
	local vv = Instance.new("UIListLayout")
	vv.FillDirection = Enum.FillDirection.Horizontal
	vv.Parent = headerFrame
	local typeLabelTl =
		guiUtil.getTl("1.header.type", UDim2.new(sectionWidthsScale.type, 0, 1, 0), 4, headerFrame, colors.blueDone, 1)
	typeLabelTl.Text = "Type"

	local badgeLabelTl = guiUtil.getTl(
		"2.header.badgename",
		UDim2.new(sectionWidthsScale.badge, 0, 1, 0),
		4,
		headerFrame,
		colors.blueDone,
		1
	)
	badgeLabelTl.Text = "Badge"

	local allUserLabelSectionFrame = Instance.new("Frame")
	allUserLabelSectionFrame.Name = "3.header.allUserLabelSectionFrame"
	allUserLabelSectionFrame.Parent = headerFrame
	allUserLabelSectionFrame.Size = UDim2.new(sectionWidthsScale.people, 0, 0, 45)

	local hh = Instance.new("UIListLayout")
	hh.Parent = allUserLabelSectionFrame
	hh.FillDirection = Enum.FillDirection.Horizontal

	------------------------DATA----------------------------

	local playerCount = #orderedUserIdsInServer

	--make labels
	local perPlayerWidthScale = 1 / playerCount
	local userBadgeCounts = {}
	for userId, chunk in pairs(badgeProgressInfo) do
		userBadgeCounts[tonumber(userId)] = 0
		for _, ba in ipairs(chunk) do
			if ba.got then
				userBadgeCounts[tonumber(userId)] = userBadgeCounts[tonumber(userId)] + 1
			end
		end
	end

	for ii, userId in ipairs(orderedUserIdsInServer) do
		local username = "usernameFor:" .. tostring(userId)

		local s, e = pcall(function()
			local player = PlayersService:GetPlayerByUserId(userId)
			if player ~= nil then
				username = player.Name
			end
		end)
		if e then
			warn(e)
		end

		--also add columns for them.
		local useColor = colors.defaultGrey
		if userId == localPlayer.UserId then
			useColor = colors.meColor
		end
		local thisUserFrame = Instance.new("Frame")
		local hh = Instance.new("UIListLayout")
		hh.Parent = thisUserFrame
		hh.FillDirection = Enum.FillDirection.Horizontal

		thisUserFrame.Name = string.format("%02d-thisUserFrame-Header-%s", ii, username)
		thisUserFrame.Size = UDim2.new(perPlayerWidthScale, 0, 1, 0)
		thisUserFrame.Parent = allUserLabelSectionFrame

		local unframe = Instance.new("Frame")
		unframe.Parent = thisUserFrame
		unframe.Size = UDim2.new(1, -45 - 10 / #orderedUserIdsInServer, 0, 45)

		local usernameChip = guiUtil.getTl(
			string.format("%02d-username-chip-%s", ii, username),
			UDim2.new(1, 0, 1, 0),
			1,
			unframe,
			useColor,
			1
		)
		usernameChip.Text = string.format("%s (%d)", username, userBadgeCounts[userId])
		local par = usernameChip.Parent :: TextLabel
		par.AutomaticSize = Enum.AutomaticSize.X

		local img = Instance.new("ImageLabel")

		img.Size = UDim2.new(0, 45, 0, 45)
		local content =
			thumbnails.getThumbnailContent(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		img.Image = content
		img.BackgroundColor3 = useColor
		img.Name = string.format("02.%s.badgePortrait", username)
		img.Parent = thisUserFrame
		img.BorderMode = Enum.BorderMode.Outline
		toolTip.setupToolTip(img, localPlayer.Name, UDim2.new(0, 200, 0, 60))
	end

	--note the individual badgeStatus ARE in teh right order here.

	--------------------------SCROLLINGFRAME-------------------------
	local badgeScrollingFrame = Instance.new("ScrollingFrame")
	badgeScrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	badgeScrollingFrame.ScrollBarThickness = 10
	local frameName = "05.badge.ScrollingFrame"
	badgeScrollingFrame.Name = frameName
	badgeScrollingFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	badgeScrollingFrame.Parent = outerFrame
	badgeScrollingFrame.Size = UDim2.new(1, 0, 1, 0)

	local vv = Instance.new("UIListLayout")
	vv.FillDirection = Enum.FillDirection.Vertical
	vv.Parent = badgeScrollingFrame

	----------PIVOT user=>badgeStatus to badge=> {userId:status}--------
	local badgeAttainmentMap: { [string]: { badge: tt.badgeDescriptor, badgeStatus: { [number]: tt.badgeProgress } } } =
		{}
	local resultSections = 0

	--listify and convert to match input order
	local sortedUserBadgeStatus: { [number]: { tt.badgeProgress } } = {}
	for _, requestedUserIdInOrder in ipairs(orderedUserIdsInServer) do
		for theUserId, item in pairs(badgeProgressInfo) do
			theUserId = tonumber(theUserId)
			if requestedUserIdInOrder == theUserId then
				sortedUserBadgeStatus[theUserId] = item
				break
			end
		end
	end

	for _, userId in ipairs(orderedUserIdsInServer) do
		local oUserAttainments = sortedUserBadgeStatus[userId]
		resultSections += 1
		if oUserAttainments then
			for _, oUserAttainment: tt.badgeProgress in ipairs(oUserAttainments) do
				if badgeAttainmentMap[oUserAttainment.badge.name] == nil then
					badgeAttainmentMap[oUserAttainment.badge.name] = { badge = oUserAttainment.badge, badgeStatus = {} }
				end
				table.insert(badgeAttainmentMap[oUserAttainment.badge.name].badgeStatus, oUserAttainment)
			end
		end
	end
	local badgeResultsRowNumber = 0

	--convert map to badge-ordered list.
	local orderedBadges: { { badge: tt.badgeDescriptor, badgeStatus: { [number]: tt.badgeProgress } } } = {}

	for _: string, obj in pairs(badgeAttainmentMap) do
		table.insert(orderedBadges, { badge = obj.badge, badgeStatus = obj.badgeStatus })
	end

	table.sort(orderedBadges, function(a, b)
		return badgeSorts.BadgeSort(a.badge, b.badge)
	end)

	for _, el in ipairs(orderedBadges) do
		local theBadge = el.badge
		local theAttainments = el.badgeStatus
		badgeResultsRowNumber += 1
		local rowFrame = makeBadgeRowFrame(localPlayer, theBadge, theAttainments, badgeResultsRowNumber, resultSections)
		rowFrame.Parent = badgeScrollingFrame
	end

	local tb = guiUtil.getTbSimple()
	tb.Text = "Close"
	tb.Name = "09BadgeCloseButton"
	tb.Size = UDim2.new(1, 0, 0, 30)
	tb.BackgroundColor3 = colors.redStop
	tb.Parent = outerFrame
	tb.Activated:Connect(function()
		screenGui:Destroy()
	end)

	return screenGui
end

local badgeButton: gt.button = {
	name = "Badges",
	contentsGetter = getBadgeStatusModal,
}

module.badgeButton = badgeButton

_annotate("end")
return module
