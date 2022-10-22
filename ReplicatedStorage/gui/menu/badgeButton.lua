--!strict

--eval 9.24.22

local PlayersService = game:GetService("Players")
local colors = require(game.ReplicatedStorage.util.colors)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local toolTip = require(game.ReplicatedStorage.gui.toolTip)
local tt = require(game.ReplicatedStorage.types.gametypes)
local gt = require(game.ReplicatedStorage.gui.guiTypes)
local badgeSorts = require(game.ReplicatedStorage.util.badgeSorts)

local remotes = require(game.ReplicatedStorage.util.remotes)
local badgeAttainmentsFunction = remotes.getRemoteFunction("BadgeAttainmentsFunction") :: RemoteFunction

local module = {}

local sectionWidthsScale = { type = 0.2, badge = 0.4, people = 0.4 }

local function makeBadgeRowFrame(
	localPlayer: Player,
	badge: tt.badgeDescriptor,
	attainments: { [number]: tt.badgeAttainment },
	n: number,
	resultSections: number
): Frame
	local fr = Instance.new("Frame")
	fr.Name = string.format("%04d", n) .. "Badge." .. badge.name
	fr.Size = UDim2.new(1, 0, 0, 30)
	local vv = Instance.new("UIListLayout")
	vv.FillDirection = Enum.FillDirection.Horizontal
	vv.SortOrder = Enum.SortOrder.Name
	vv.Parent = fr
	local label = guiUtil.getTl("00label", UDim2.new(sectionWidthsScale.type, 0, 1, 0), 1, fr, colors.defaultGrey, 1)
	-- label.TextScaled = false

	label.Text = badge.badgeClass
	-- label.FontSize = Enum.FontSize.Size12
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	local tl = guiUtil.getTl("01badgename", UDim2.new(sectionWidthsScale.badge, 0, 1, 0), 2, fr, colors.defaultGrey, 1)

	tl.Text = badge.name
	toolTip.setupToolTip(localPlayer, tl, badge.hint, toolTip.enum.toolTipSize.NormalText)

	tl.TextXAlignment = Enum.TextXAlignment.Left

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
	for ii, oAttainment in pairs(attainments) do
		progressCounter += 1
		if oAttainment.got then --full bar
			local restl = guiUtil.getTl(
				string.format("02.%02d-progress-%d", progressCounter, ii),
				UDim2.new(resultWidthScale, resultWidthPixel, 1, 0),
				2,
				subFrame,
				colors.greenGo,
				1
			)
			restl.Text = "got"
		else --progress bar
			if oAttainment.progress == -1 then
				local progressinTL, noprogressoutTL = guiUtil.getTl(
					string.format("02.%02d-progress-%d", progressCounter, ii),
					UDim2.new(resultWidthScale, resultWidthPixel, 1, 0),
					4,
					subFrame,
					colors.redStop,
					1
				)
				progressinTL.Text = "nope"
			else
				if not badge.baseNumber then
					warn("Err")
				end
				local prog = Instance.new("Frame")
				prog.Size = UDim2.new(resultWidthScale, resultWidthPixel, 1, 0)
				prog.Parent = subFrame
				prog.Name = string.format("02.%02d-progress-%d", progressCounter, ii)
				local hh = Instance.new("UIListLayout")
				hh.Parent = prog
				hh.FillDirection = Enum.FillDirection.Horizontal
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

getBadgeStatusModal = function(localPlayer: Player): ScreenGui
	local sg = Instance.new("ScreenGui")
	sg.Name = "badgeStatusFrame"

	local outerFrame = Instance.new("Frame")
	outerFrame.Parent = sg
	outerFrame.Position = UDim2.new(0.2, 0, 0.3, 0)
	outerFrame.Size = UDim2.new(0.6, 0, 0.5, 0)
	outerFrame.Name = "03badgeStatusOuterFrame"
	local vv = Instance.new("UIListLayout")
	vv.Parent = outerFrame
	vv.FillDirection = Enum.FillDirection.Vertical

	------------------------HEADER----------------------------
	local headerFrame = Instance.new("Frame")
	headerFrame.Parent = outerFrame
	headerFrame.Name = "02badgeHeader"
	headerFrame.Size = UDim2.new(1, -10, 0, 60)
	local vv = Instance.new("UIListLayout")
	vv.FillDirection = Enum.FillDirection.Horizontal
	vv.Parent = headerFrame
	local tl = guiUtil.getTl(
		"1",
		UDim2.new(sectionWidthsScale.type, sectionWidthsScale.type * 10, 1, 0),
		4,
		headerFrame,
		colors.blueDone,
		1
	)
	tl.Text = "Type"

	local tl = guiUtil.getTl(
		"2",
		UDim2.new(sectionWidthsScale.badge, sectionWidthsScale.badge * 10, 1, 0),
		4,
		headerFrame,
		colors.blueDone,
		1
	)
	tl.Text = "Badge"

	local usernameSection = Instance.new("Frame")
	usernameSection.Name = "3.header.username"
	usernameSection.Parent = headerFrame
	usernameSection.Size = UDim2.new(sectionWidthsScale.people, sectionWidthsScale.people * 10, 1, 0)
	local hh = Instance.new("UIListLayout")
	hh.Parent = usernameSection
	hh.FillDirection = Enum.FillDirection.Horizontal

	------------------------DATA----------------------------

	local orderedUserIdsInServer: { number } = { localPlayer.UserId }

	--fill in with other players.
	for _, player in ipairs(PlayersService:GetPlayers()) do
		if player.UserId ~= localPlayer.UserId then
			table.insert(orderedUserIdsInServer, player.UserId)
		end
	end

	local playerCount = #orderedUserIdsInServer

	--make labels
	local perPlayerWidthScale = 1 / playerCount
	local perPlayerWidthHidePixel = -1 / playerCount*10
	for ii, userId in ipairs(orderedUserIdsInServer) do
		local username = "usernameFor" .. tostring(userId)
		local s, e = pcall(function()
			local player = PlayersService:GetPlayerByUserId(userId)
			username = player.Name
		end)
		if e then
			warn(e)
		end

		--also add columns for them.
		local useColor = colors.defaultGrey
		if userId == localPlayer.UserId then
			useColor = colors.meColor
		end
		local frame = Instance.new("Frame")
		local hh = Instance.new("UIListLayout")
		hh.Parent = frame
		hh.FillDirection = Enum.FillDirection.Horizontal
		
		frame.Name = "badges-UserSection-Header-" .. username
		frame.Size = UDim2.new(perPlayerWidthScale, perPlayerWidthHidePixel, 1, 0)
		frame.Parent = usernameSection

		local usernameChip =
			guiUtil.getTl(string.format("%02d", ii) .. username, UDim2.new(0.8, 0, 1, 0), 1, frame, useColor, 1)
		usernameChip.Text = username
		local par = usernameChip.Parent :: TextLabel
		par.AutomaticSize = Enum.AutomaticSize.X
		local thumbnails = require(game.ReplicatedStorage.thumbnails)
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.new(0.2, 0, 1, 0)
		local content = thumbnails.getThumbnailContent(userId, Enum.ThumbnailType.HeadShot)
		img.Image = content
		img.BackgroundColor3 = useColor
		img.Name = string.format("02.%s.badgePortrait", username)
		img.Parent = frame
		img.BorderMode = Enum.BorderMode.Outline
	end
	local badgeInfo: { [number]: { tt.badgeAttainment } } =
		badgeAttainmentsFunction:InvokeServer(orderedUserIdsInServer, "badgeButtonSetup.")

	--note the individual attainments ARE in teh right order here.

	--------------------------SCROLLINGFRAME-------------------------
	local badgeScrollingFrame = Instance.new("ScrollingFrame")
	badgeScrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	badgeScrollingFrame.ScrollBarThickness = 10
	local frameName = "05badgeScrollingFrame"
	badgeScrollingFrame.Name = frameName
	badgeScrollingFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	badgeScrollingFrame.Parent = outerFrame
	badgeScrollingFrame.Size = UDim2.new(1, 0, 1, 0)

	local vv = Instance.new("UIListLayout")
	vv.FillDirection = Enum.FillDirection.Vertical
	vv.Parent = badgeScrollingFrame

	----------PIVOT user=>attainments to badge=> {userId:status}--------
	local badgeAttainmentMap: { [string]: { badge: tt.badgeDescriptor, attainments: { [number]: tt.badgeAttainment } } } =
		{}
	local resultSections = 0

	--listify and convert to match input order
	local sortedUserBadgeAttainments: { { userId: number, att: { tt.badgeAttainment } } } = {}
	for _, requestedOrder in ipairs(orderedUserIdsInServer) do
		for theUserId, item in pairs(badgeInfo) do
			if requestedOrder == tonumber(theUserId) then
				table.insert(sortedUserBadgeAttainments, { userId = tonumber(theUserId), att = item })
				break
			end
		end
	end

	-- for oUserId, oUserAttainments: { tt.badgeAttainment } in pairs(badgeInfo) do
	for _, el in ipairs(sortedUserBadgeAttainments) do
		local oUserAttainments = el.att
		resultSections += 1
		for _, oUserAttainment: tt.badgeAttainment in ipairs(oUserAttainments) do
			if badgeAttainmentMap[oUserAttainment.badge.name] == nil then
				-- print("clearing " .. oUserAttainment.badge.name)
				badgeAttainmentMap[oUserAttainment.badge.name] = { badge = oUserAttainment.badge, attainments = {} }
			end
			table.insert(badgeAttainmentMap[oUserAttainment.badge.name].attainments, oUserAttainment)
		end
	end
	local badgeResultsRowNumber = 0

	--convert map to badge-ordered list.
	local ordered: { { badge: tt.badgeDescriptor, attainments: { [number]: tt.badgeAttainment } } } = {}

	for _: string, obj in pairs(badgeAttainmentMap) do
		table.insert(ordered, { badge = obj.badge, attainments = obj.attainments })
	end

	table.sort(ordered, function(a, b)
		return badgeSorts.BadgeSort(a.badge, b.badge)
	end)

	for _, el in ipairs(ordered) do
		local theBadge = el.badge
		local theAttainments = el.attainments
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
		sg:Destroy()
	end)

	return sg
end

local badgeButton: gt.button = {
	name = "Badges",
	contentsGetter = getBadgeStatusModal,
}

module.badgeButton = badgeButton

return module
