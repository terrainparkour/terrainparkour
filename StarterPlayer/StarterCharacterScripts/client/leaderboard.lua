--!strict

--2022 remaining bug: sometimes you get fail.04 or fail.05 and permanent  shifting.
--2022.02.12 why is this so hard? or rather why doesn't it just work out of the box?
--2022.02.24 revisiting to finally fix LB bugs.

--2024 I'm struck by how when i left the game, this felt extremely complicated
--yet when I'm back now, it's very simple. Some huge too large functions hacking around with TLs, and otherwise a very simple loop of getting and updating data
--with some funk bits about local caching etc.
--but at a core level, this could pretty easily be redone and simplified, move the TL stuff out so the row management logic is visible
--really, why did I do this at all?
--it seems there also was an unused layer of deboucing for repeated quick joins, which was why there would occasionally be bugs?

-- OVERALL GOALS: make the entire leaderboard draggable smoothly and naturally.
-- And everything within it should lay itself out wonderfully.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

--TYPE
local tt = require(game.ReplicatedStorage.types.gametypes)

--UTIL
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)

local settings = require(game.ReplicatedStorage.settings)
local enums = require(game.ReplicatedStorage.util.enums)

local colors = require(game.ReplicatedStorage.util.colors)
local thumbnails = require(game.ReplicatedStorage.thumbnails)

local remotes = require(game.ReplicatedStorage.util.remotes)

local leaderboardButtons = require(game.StarterPlayer.StarterPlayerScripts.buttons.leaderboardButtons)

local marathonClient = require(game.StarterPlayer.StarterCharacterScripts.client.marathonClient)
local localRdb = require(game.ReplicatedStorage.localRdb)
local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local TweenService = game:GetService("TweenService")

-------------------EVENTS ---------------------
-- we setup the event, but what if upstream playerjoinfunc is called first?
local LeaderboardUpdateEvent = remotes.getRemoteEvent("LeaderboardUpdateEvent")

----------------- TYPES ---------------------

-- this covers all the different types of lbupdates that can be sent. for example, one is tt_afterrundata, another is tt_inital join data + username,
export type genericLeaderboardUpdateDataType = { [string]: number | string }

type LeaderboardUserData = { [number]: genericLeaderboardUpdateDataType }

local lbUserData: LeaderboardUserData = {}

export type lbUserCellDescriptor = {
	name: string,
	num: number,
	widthScaleImportance: number,
	userFacingName: string,
	tooltip: string,
}

local lbUserCellDescriptors: { [string]: lbUserCellDescriptor } = {
	portrait = { name = "portrait", num = 1, widthScaleImportance = 14, userFacingName = "portrait", tooltip = "" },
	username = { name = "username", num = 3, widthScaleImportance = 25, userFacingName = "username", tooltip = "" },
	awardCount = {
		name = "awardCount",
		num = 5,
		widthScaleImportance = 15,
		userFacingName = "awards",
		tooltip = "",
	},
	userTix = {
		name = "userTix",
		num = 7,
		widthScaleImportance = 18,
		userFacingName = "tix",
		tooltip = "",
	},
	findCount = {
		name = "findCount",
		num = 9,
		widthScaleImportance = 10,
		userFacingName = "finds",
		tooltip = "",
	},
	findRank = {
		name = "findRank",
		num = 11,
		widthScaleImportance = 8,
		userFacingName = "find rank",
		tooltip = "",
	},
	cwrs = {
		name = "cwrs",
		num = 13,
		widthScaleImportance = 12,
		userFacingName = "cwrs",
		tooltip = "",
	},
	cwrtop10s = {
		name = "cwrtop10s",
		num = 14,
		widthScaleImportance = 11,
		userFacingName = "cwr top10s",
		tooltip = "",
	},
	wrCount = {
		name = "wrCount",
		num = 15,
		widthScaleImportance = 10,
		userFacingName = "wrs",
		tooltip = "",
	},
	wrRank = {
		name = "wrRank",
		num = 16,
		widthScaleImportance = 8,
		userFacingName = "wr rank",
		tooltip = "",
	},
	top10s = {
		name = "top10s",
		num = 18,
		widthScaleImportance = 8,
		userFacingName = "top10s",
		tooltip = "",
	},
	races = {
		name = "races",
		num = 23,
		widthScaleImportance = 9,
		userFacingName = "races",
		tooltip = "",
	},
	runs = {
		name = "runs",
		num = 26,
		widthScaleImportance = 6,
		userFacingName = "runs",
		tooltip = "",
	},
	badgeCount = {
		name = "badgeCount",
		num = 31,
		widthScaleImportance = 10,
		userFacingName = "badges",
		tooltip = "",
	},
}

------------- GLOBAL STATIC OBJECTS ----------------

--used to do reverse ordering items in lb
local bignum: number = 10000000

-- GLOBAL DYNAMIC STATE VARS. EACH USER HAS JUST ONE LEADERBOARD. ----------------

local playerRowCount: number = 0

--one rowFrame for each user is stored in here.
local userId2rowframe: { [number]: Frame } = {}

local lbUserRowFrame: Frame? = nil
local lbIsEnabled: boolean = true

-- the initial width and height scales.
local initialWidthScale = 0.40
local initialHeightScale = 0.08
local headerRowYOffsetFixed = 24
-- local headerRowShrinkFactor = 0.6

local enabledDescriptors: { [string]: boolean } = {}

-- this will block things like adding rows.
local loadedSettings = false

------------------FUNCTIONS--------------
local function calculateCellWidths(): { [string]: number }
	local totalWidthWeightScale = 0
	local cellWidths: { [string]: number } = {}
	for _, lbUserCellDescriptor in pairs(lbUserCellDescriptors) do
		if enabledDescriptors[lbUserCellDescriptor.name] then
			totalWidthWeightScale += lbUserCellDescriptor.widthScaleImportance
		end
	end
	for _, lbUserCellDescriptor in pairs(lbUserCellDescriptors) do
		if enabledDescriptors[lbUserCellDescriptor.name] then
			cellWidths[lbUserCellDescriptor.name] = lbUserCellDescriptor.widthScaleImportance / totalWidthWeightScale
		end
	end
	_annotate(cellWidths)
	return cellWidths
end

--setup header row as first row in lbframe
local function makeLeaderboardHeaderRow(): Frame
	local headerRow = Instance.new("Frame")
	headerRow.BorderMode = Enum.BorderMode.Inset
	headerRow.BorderSizePixel = 1
	headerRow.Name = "LeaderboardHeaderRow"
	headerRow.Size = UDim2.new(1, 0, 0, headerRowYOffsetFixed)
	headerRow.BackgroundColor3 = colors.greenGo
	headerRow.BackgroundTransparency = 0.2
	local hh = Instance.new("UIListLayout")
	hh.FillDirection = Enum.FillDirection.Horizontal
	hh.Parent = headerRow
	hh.Name = "HeaderRow-hh"

	local cellWidths = calculateCellWidths()

	for _, lbUserCellDescriptor: lbUserCellDescriptor in pairs(lbUserCellDescriptors) do
		if not enabledDescriptors[lbUserCellDescriptor.name] then
			continue
		end
		local myWidthScale = cellWidths[lbUserCellDescriptor.name]

		local el = guiUtil.getTl(
			string.format("%02d.header.%s", lbUserCellDescriptor.num, lbUserCellDescriptor.userFacingName),
			UDim2.fromScale(myWidthScale, 1),
			2,
			headerRow,
			colors.defaultGrey,
			0
		)
		el.Text = lbUserCellDescriptor.userFacingName
		el.ZIndex = lbUserCellDescriptor.num
		el.TextXAlignment = Enum.TextXAlignment.Center
		el.TextYAlignment = Enum.TextYAlignment.Center
		el.TextScaled = true
	end
	return headerRow
end

local function setSize()
	if not lbUserRowFrame then
		_annotate("No lbUserRowFrame1?")
		return
	end

	local normalizedPlayerRowYScale = 1 / playerRowCount

	for _, child: Frame in ipairs(lbUserRowFrame:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "LeaderboardHeaderRow" then
			child.Size = UDim2.fromScale(1, normalizedPlayerRowYScale)
		end
	end
	_annotate("adjusted row scales.")
end

--important to use all lbUserCellParams here to make the row complete
--even if an update comes before the loading of full stats.

local function getNameForDescriptor(descriptor: lbUserCellDescriptor): string
	return string.format("%02d.cell.%s", descriptor.num, descriptor.name)
end

local deb = false
local function createRowForUser(userId: number, username: string): Frame?
	if deb then
		return
	end
	deb = true
	--remember, this user may not actually be present in the server!
	local userRowFrame: Frame = Instance.new("Frame")
	local userDataFromCache = lbUserData[userId]
	if not username then
		username = localRdb.getUsernameByUserId(userId)
	end
	if userDataFromCache == nil then
		_annotate("createRowForUser called with no userDataFromCache for userId: " .. tostring(userId))
		deb = false
		return
	end
	--we need this to get ordering before tix are known.
	if userDataFromCache.userTix == nil then
		userDataFromCache.userTix = 0
	end

	local userTixCount: number = userDataFromCache.userTix :: number
	local rowName = string.format("%s_PlayerRow_%s", tostring(bignum - userTixCount), username)
	userRowFrame.Name = rowName
	-- local rowYScale = 1 / (playerRowCount + 2) -- +1 for header, +1 for new row
	-- rowFrame.Size = UDim2.fromScale(1, rowYScale)
	userRowFrame.BorderMode = Enum.BorderMode.Inset
	userRowFrame.BorderSizePixel = 0
	userRowFrame.BackgroundTransparency = 0.1
	local horizontalLayout = Instance.new("UIListLayout")
	horizontalLayout.FillDirection = Enum.FillDirection.Horizontal
	horizontalLayout.Parent = userRowFrame
	horizontalLayout.Name = "LeaderboardUserRowHH"
	userRowFrame.Parent = lbUserRowFrame

	local bgcolor = colors.defaultGrey
	if userId == localPlayer.UserId then
		bgcolor = colors.meColor
	end

	local cellWidths = calculateCellWidths()

	for _, lbUserCellDescriptor: lbUserCellDescriptor in pairs(lbUserCellDescriptors) do
		if not enabledDescriptors[lbUserCellDescriptor.name] then
			_annotate('skipping adding col: "' .. lbUserCellDescriptor.name .. '"')
			continue
		end
		_annotate("adding col: " .. lbUserCellDescriptor.name)
		local widthYScale = cellWidths[lbUserCellDescriptor.name]

		if lbUserCellDescriptor.name == "portrait" then
			local portraitCell = Instance.new("Frame")
			portraitCell.Size = UDim2.fromScale(widthYScale, 1)
			portraitCell.BackgroundTransparency = 1
			portraitCell.Name = getNameForDescriptor(lbUserCellDescriptor)
			portraitCell.Parent = userRowFrame

			local img = Instance.new("ImageLabel")
			img.Size = UDim2.new(1, 0, 1, 0)
			img.BackgroundColor3 = colors.defaultGrey
			img.Name = "PortraitImage"
			img.Parent = portraitCell
			img.BorderMode = Enum.BorderMode.Outline
			img.ScaleType = Enum.ScaleType.Stretch
			img.BorderSizePixel = 1
			local content =
				thumbnails.getThumbnailContent(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
			img.Image = content

			-- Add mouseover functionality so that when you mouseover the portrait cell (the 1st one) to the left of it,
			-- a larger portrait appears.  It has no effect on the row.

			local avatarImages = Instance.new("Frame")
			avatarImages.Size = UDim2.new(0, 420, 0, 420)
			avatarImages.Position = UDim2.new(0, -440, 0, 0)
			avatarImages.Parent = portraitCell
			avatarImages.Visible = false
			local vv = Instance.new("UIListLayout")
			vv.FillDirection = Enum.FillDirection.Vertical
			vv.Parent = avatarImages
			local allContents = {
				thumbnails.getThumbnailContent(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420),
			}
			for _, content in pairs(allContents) do
				local img = Instance.new("ImageLabel")
				img.Size = UDim2.new(1, 0, 1, 0)
				img.BackgroundColor3 = colors.defaultGrey
				img.Visible = false
				img.ZIndex = 10
				img.Image = content
				img.Visible = true
				img.Name = "LargeAvatarImage_" .. tostring(userId)
				img.Parent = avatarImages
			end

			-- in general mouseenter can fire before mouseleave. which means sometimes the avatar image gets stuck
			portraitCell.MouseEnter:Connect(function()
				avatarImages.Visible = true
			end)
			portraitCell.MouseLeave:Connect(function()
				avatarImages.Visible = false
			end)
		else --it's a textlabel whatever we're generating anyway.
			local cellName = getNameForDescriptor(lbUserCellDescriptor)
			local tl: TextLabel =
				guiUtil.getTl(cellName, UDim2.fromScale(widthYScale, 1), 2, userRowFrame, bgcolor, 1, 0)

			--find text for value.
			if lbUserCellDescriptor.name == "findRank" then
				local foundRank = userDataFromCache.findRank
				if foundRank ~= nil then
					tl.Text = tpUtil.getCardinalEmoji(foundRank)
				end
			elseif lbUserCellDescriptor.name == "wrRank" then
				local wrRank = userDataFromCache.wrRank
				if wrRank ~= nil then
					tl.Text = tpUtil.getCardinalEmoji(wrRank)
				end
			elseif lbUserCellDescriptor.name == "username" then
				tl.Text = username
			elseif lbUserCellDescriptor.name == "badges" then
				tl.Text = "..."
			else
				local candidateTextValue = userDataFromCache[lbUserCellDescriptor.name]
				local textValue: string = if candidateTextValue ~= nil then tostring(candidateTextValue) else ""
				tl.Text = textValue
			end

			tl.TextScaled = true
		end
	end
	deb = false
	return userRowFrame
end

local comdeb = false
local function completelyResetUserLB(forceResize: boolean)
	if comdeb then
		return
	end
	comdeb = true
	_annotate(string.format("completely reset? lb, forceResize: %s", tostring(forceResize)))
	--make initial row only. then as things happen (people join, or updates come in, apply them in-place)
	local pgui: PlayerGui = localPlayer:WaitForChild("PlayerGui")

	local oldLbSgui: ScreenGui = pgui:FindFirstChild("LeaderboardScreenGui") :: ScreenGui?
	local oldSize
	local oldPosition
	if oldLbSgui ~= nil then
		local old: Frame = oldLbSgui:FindFirstChild("outer_lb")
		if old then
			oldSize = old.Size
			oldPosition = old.Position
		end
		oldLbSgui:Destroy()
	end

	if not lbIsEnabled then
		_annotate("reset lb and it's disabled now so just end.")
		comdeb = false
		return
	end

	local existingSgui = pgui:FindFirstChild("LeaderboardScreenGui")
	if existingSgui ~= nil then
		existingSgui:Destroy()
	end
	local lbSgui: ScreenGui = Instance.new("ScreenGui")
	lbSgui.Name = "LeaderboardScreenGui"
	lbSgui.Parent = pgui
	lbSgui.IgnoreGuiInset = true

	--previous lb frame items now just are floating independently and adjustable freely.

	local lbSystemFrames = windows.SetupFrame("lb", true, true, true)
	local lbOuterFrame = lbSystemFrames.outerFrame
	local lbContentFrame = lbSystemFrames.contentFrame

	if forceResize then
		_annotate("forced resize of LB.")
		lbOuterFrame.Size = UDim2.new(initialWidthScale, 0, initialHeightScale, 0)
		lbOuterFrame.Position = UDim2.fromScale(1 - initialWidthScale, 0)
	else
		if oldSize then
			_annotate("using old size: " .. tostring(oldSize))
			lbOuterFrame.Size = oldSize
			lbOuterFrame.Position = oldPosition
		else
			_annotate("tried to not erset size but there was no old size loaded?")
			lbOuterFrame.Size = UDim2.new(initialWidthScale, 0, initialHeightScale, 0)
			lbOuterFrame.Position = UDim2.fromScale(1 - initialWidthScale, 0)
		end
	end
	lbOuterFrame.Parent = lbSgui

	local headerRow = makeLeaderboardHeaderRow()
	headerRow.Parent = lbContentFrame
	headerRow.Position = UDim2.new(0, 0, 0, 0)

	lbUserRowFrame = Instance.new("Frame")
	lbUserRowFrame.Parent = lbContentFrame
	lbUserRowFrame.BorderMode = Enum.BorderMode.Inset
	lbUserRowFrame.BorderSizePixel = 0
	lbUserRowFrame.Size = UDim2.new(1, 0, 1, -1 * headerRowYOffsetFixed)
	lbUserRowFrame.Position = UDim2.new(0, 0, 0, headerRowYOffsetFixed)
	lbUserRowFrame.Name = "lbUserRowFrame"
	lbUserRowFrame.BackgroundTransparency = 1
	lbUserRowFrame.BackgroundColor3 = colors.defaultGrey

	local leaderboardNameSorter: UIListLayout = Instance.new("UIListLayout")
	leaderboardNameSorter.SortOrder = Enum.SortOrder.Name
	leaderboardNameSorter.Name = "LeaderboardNameSorter"
	leaderboardNameSorter.Parent = lbUserRowFrame
	leaderboardButtons.initActionButtons(lbOuterFrame)
	playerRowCount = 0

	if #userId2rowframe > 0 then
		_annotate("resetting but userId2rowframe not empty?")
	end

	userId2rowframe = {}
	for _, player in pairs(Players:GetPlayers()) do
		local created = createRowForUser(player.UserId, player.Name)

		if created then
			created.Parent = lbUserRowFrame
			setSize()
			userId2rowframe[player.UserId] = created
			playerRowCount = playerRowCount + 1
			_annotate("created user lb row for: " .. player.Name)
		else
			_annotate("no lbUserRowFrame?")
		end
	end

	setSize()
	_annotate("end setup, position is: ")
	comdeb = false
end

--after receiving an lb update, figure out what changed relative to known data
--store it and return a userDataChange for rendering into the LB
local sdeb = false
local function StoreUserData(userId: number, data: genericLeaderboardUpdateDataType): { tt.leaderboardUserDataChange }
	while sdeb do
		wait(0.1)
	end
	sdeb = true
	local res: { tt.leaderboardUserDataChange } = {}
	if lbUserData[userId] == nil then --received new data.
		lbUserData[userId] = {}
	end

	--TODO is there ever a case where there's out of order in time data/
	-- like, I shouldn't update to a value that's earlier than the value for a key i've got already.
	for key: string, newValue in pairs(data) do
		if newValue == nil then
			--don't know why this would happen, probably impossible.
			warn("no newvalue " .. key)
			continue
		end
		local oldValue = lbUserData[userId][key]
		if newValue ~= oldValue then
			--reset source of truth to the new data that came in.
			local change: tt.leaderboardUserDataChange = { key = key, oldValue = oldValue, newValue = newValue }
			lbUserData[userId][key] = newValue
			table.insert(res, change)
		end
	end
	sdeb = false
	return res
end

-- store the data in-memory.
local debounceUpdateUserLeaderboardRow = {}
local function updateUserLeaderboardRow(userData: genericLeaderboardUpdateDataType): ()
	while not loadedSettings do
		wait(0.1)
		_annotate("waiting for settings to load for updateUserLeaderboardRow")
	end
	while debounceUpdateUserLeaderboardRow[userData.userId] do
		_annotate(string.format("waiting for user %s to finish receiving their lb update", userData.userId))
		wait(0.1)
	end
	debounceUpdateUserLeaderboardRow[userData.userId] = true
	if not lbIsEnabled then
		debounceUpdateUserLeaderboardRow[userData.userId] = nil
		return
	end
	local subjectUserId = userData.userId
	-- local receivedUserData = ""
	-- for a, b in pairs(userData) do
	-- 	receivedUserData = receivedUserData .. string.format("\t%s=%s ", tostring(a), tostring(b))
	-- end
	-- 2_annotate(string.format("got info about: %s: %s", tostring(subjectUserId), receivedUserData))

	--check if this client's user has any lbframe.
	if subjectUserId == nil then
		warn("nil userid for update.")
		debounceUpdateUserLeaderboardRow[userData.userId] = nil
		return
	end

	if lbUserRowFrame == nil then
		--2_annotate("compoletely reset them cause no lbframe.")
		completelyResetUserLB(false)
	end

	--first check if there is anything worthwhile to draw - anything changed.

	local userDataChanges: { tt.leaderboardUserDataChange } = StoreUserData(subjectUserId, userData)
	if userDataChanges == nil or #userDataChanges == 0 then
		--2_annotate(
		-- 	string.format(
		-- 		"looks like we received information again which we already had, so the storeOperation returned nothing. Here is the data: %s",
		-- 		receivedUserData
		-- 	)
		-- )
		debounceUpdateUserLeaderboardRow[userData.userId] = nil
		return
	end

	--patch things up if needed.
	--2_annotate("patching up existing rowframe with new data")
	local userRowFrame: Frame = userId2rowframe[subjectUserId]
	if userRowFrame == nil or userRowFrame.Parent == nil then
		if userRowFrame == nil then
			--2_annotate("remaking userRowFrame cause it was nil")
		else
			--2_annotate("destroyed userRowFrame cause its parent is nil")
			userRowFrame:Destroy()
		end
		userId2rowframe[subjectUserId] = nil
		local candidateRowFrame: Frame = createRowForUser(subjectUserId, userData.name)
		if candidateRowFrame == nil then --case when the user is gone already.
			debounceUpdateUserLeaderboardRow[userData.userId] = nil
			return
		end

		userRowFrame = candidateRowFrame
		userId2rowframe[subjectUserId] = userRowFrame
		userRowFrame.Parent = lbUserRowFrame
		playerRowCount = playerRowCount + 1
		setSize()
		--2_annotate("increased playerrowCount to: " .. tostring(playerRowCount))
	end

	local bgcolor = colors.defaultGrey
	if subjectUserId == localPlayer.UserId then
		bgcolor = colors.meColor
	end

	for _, change: tt.leaderboardUserDataChange in pairs(userDataChanges) do
		-- find the userCellDescriptor corresponding to it.
		-- we just hide these always.
		if change.key == "kind" or change.key == "userId" or change.key == "totalSignCount" then
			continue
		end

		local ovt = change.oldValue and tostring(change.oldValue) or ""
		_annotate(
			string.format(
				"trying to update lb for change %s %s=>%s",
				tostring(change.key),
				tostring(ovt),
				tostring(change.newValue)
			)
		)
		if enabledDescriptors[change.key] == nil then
			_annotate("missing descriptor status at all for received change for: " .. tostring(change.key))
			return
		end

		if not enabledDescriptors[change.key] then
			_annotate("showing this is not enabled for this user.")
			break
		end

		local descriptor = lbUserCellDescriptors[change.key]
		if not descriptor then
			-- this can be okay. for example, we also return values such as "kind" of the update, and "userId" in the row value.
			-- those don't all need to be shown.
			_annotate("werror, this descriptor should not be missing. " .. change.key)
			continue
		end

		--if we receive a tix update, update rowframe. This is because we order by tix count.
		if change.key == "userTix" then
			local username = localRdb.getUsernameByUserId(subjectUserId)
			local newName = string.format("%s_PlayerRow_%s", tostring(bignum - change.newValue), username)
			userRowFrame.Name = newName
			userRowFrame.Name = newName
		end

		local targetName = getNameForDescriptor(descriptor)
		--it's important this targetname matches via interpolatino
		local oldTextLabelParent: TextLabel = userRowFrame:FindFirstChild(targetName) :: TextLabel
		if oldTextLabelParent == nil then
			-- this user isn't displaying that data.
			-- still, we have stored it so if they re-enable it we are good.
			continue
		end
		local oldTextLabel: TextLabel = oldTextLabelParent:FindFirstChild("Inner")

		if oldTextLabel == nil then
			warn("Missing old label to put in - this should not happen " .. descriptor.num)
			error(descriptor)
		end

		--if this exists, do green fade
		local newIntermediateText: string? = nil

		--what do we have to do.
		--we have old number and new number.
		--if not findRank, calculate the intermediate text and set up greenfade.
		--and in either case, do a green fade.
		local newFinalText = tostring(change.newValue)
		if descriptor.name == "findRank" then
			newFinalText = tpUtil.getCardinalEmoji(change.newValue)
		end

		local improvement = false

		--oldValue may be nil indicating nothing known.
		if change.oldValue then
			local gap = change.newValue - change.oldValue
			local sign = ""
			if gap > 0 then
				improvement = true
				sign = "+"
			end
			--findrank (rank decrease) is always semantically positive
			if change.key == "findRank" then
				improvement = not improvement
				sign = ""
			end
			if gap ~= 0 then
				newIntermediateText = string.format("%s\n(%s%s)", newFinalText, sign, gap)
			end
		end

		--phase to new color if needed
		if newIntermediateText == nil then
			oldTextLabel.Text = newFinalText
			oldTextLabel.BackgroundColor3 = bgcolor
			oldTextLabel.Parent.BackgroundColor3 = bgcolor
		else
			if improvement then
				oldTextLabel.BackgroundColor3 = colors.greenGo
				oldTextLabel.Parent.BackgroundColor3 = colors.greenGo
			else
				oldTextLabel.BackgroundColor3 = colors.blueDone
				oldTextLabel.Parent.BackgroundColor3 = colors.blueDone
			end
			oldTextLabel.Text = newIntermediateText

			-- while it's flashing, show the intermediate text, the new value followed by the diff improvement (i.e. ' (+1)')
			task.spawn(function()
				wait(enums.greenTime)
				oldTextLabel.Text = newFinalText
			end)

			--phase the cell and the parent back to the default color.
			local tween = TweenService:Create(
				oldTextLabel,
				TweenInfo.new(enums.greenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ BackgroundColor3 = bgcolor }
			)
			tween:Play()

			local tween2 = TweenService:Create(
				oldTextLabel.Parent,
				TweenInfo.new(enums.greenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ BackgroundColor3 = bgcolor }
			)
			tween2:Play()

			--we had more tweens before.
		end
	end

	setSize()
	debounceUpdateUserLeaderboardRow[userData.userId] = nil
end

local removeDebouncers = {}
local function removeUserLBRow(userId: number): ()
	if removeDebouncers[userId] then
		return
	end
	--2_annotate("removeUserLBRow called for userId: " .. tostring(userId))
	removeDebouncers[userId] = true
	if not lbIsEnabled then
		removeDebouncers[userId] = nil
		return
	end
	local row: Frame = userId2rowframe[userId]
	userId2rowframe[userId] = nil
	lbUserData[userId] = nil
	if row ~= nil then
		pcall(function()
			if row ~= nil then
				row:Destroy()
			end
		end)
		if playerRowCount > 0 then
			playerRowCount = math.max(0, playerRowCount - 1)
			--2_annotate("decreasing playerRowCount, it is now: " .. tostring(playerRowCount))
		else
			warn("okay, clear error here. lbRowcount too low" .. tostring(playerRowCount))
		end
	end
	setSize()
	--2_annotate("done with remove UserLbRow")
	removeDebouncers[userId] = nil
end

--data is a list of kvs for update data. if any change, redraw the row (and highlight that cell.)
--First keyed to receive data about a userId. But later overloading data to just be blobs  of things of specific types to display in leaderboard.
local receiveDataDebouncer = false
module.ClientReceiveNewLeaderboardData = function(lbUpdateData: genericLeaderboardUpdateDataType)
	while not loadedSettings do
		_annotate("waiting for user's leaderboard settings to load.")
		wait(0.1)
	end
	if receiveDataDebouncer then
		wait(0.1)
	end
	receiveDataDebouncer = true
	lbUpdateData.userId = tonumber(lbUpdateData.userId)

	if lbUpdateData.kind == "leave" then
		lbUserData[lbUpdateData.userId] = nil
		removeUserLBRow(lbUpdateData.userId)
		receiveDataDebouncer = false
		return
	end

	if
		lbUpdateData.kind == "update other about joiner"
		or lbUpdateData.kind == "update joiner lb"
		or lbUpdateData.kind == "joiner update other lb"
		or lbUpdateData.kind == "badge update"
		or lbUpdateData.kind == "Update from run"
	then
		--2_annotate("got lbupdate of known good kind: " .. lbUpdateData.kind)
	else
		--2_annotate("got lbupdate of unknown kind: " .. lbUpdateData.kind)
	end
	updateUserLeaderboardRow(lbUpdateData)
	setSize()
	receiveDataDebouncer = false
end

--user changed marathon settings in UI - uses registration to monitor it.
--note there is an init call here so user settings _will_ show up here and we should
--be careful not to mistakenly reinit LB needlessly.
local function handleUserSettingChanged(setting: tt.userSettingValue, initial: boolean)
	while not initial and not loadedSettings do
		wait(0.1)
		_annotate("waiting for settings to load for updateUserLeaderboardRow")
	end
	if setting.name == settingEnums.settingNames.HIDE_LEADERBOARD and not initial then
		if setting.value then
			lbIsEnabled = false
			marathonClient.CloseAllMarathons()
			completelyResetUserLB(true)
		else
			lbIsEnabled = true
			completelyResetUserLB(true)
			marathonClient.Init()
		end
	end

	if setting.domain == settingEnums.settingDomains.LEADERBOARD then
		if setting.name == settingEnums.settingNames.LEADERBOARD_ENABLE_PORTRAIT then
			enabledDescriptors["portrait"] = setting.value
		elseif setting.name == settingEnums.settingNames.LEADERBOARD_ENABLE_USERNAME then
			enabledDescriptors["username"] = setting.value
		elseif setting.name == settingEnums.settingNames.LEADERBOARD_ENABLE_AWARDS then
			enabledDescriptors["awardCount"] = setting.value
		elseif setting.name == settingEnums.settingNames.LEADERBOARD_ENABLE_TIX then
			enabledDescriptors["userTix"] = setting.value
		elseif setting.name == settingEnums.settingNames.LEADERBOARD_ENABLE_FINDS then
			enabledDescriptors["findCount"] = setting.value
		elseif setting.name == settingEnums.settingNames.LEADERBOARD_ENABLE_FINDRANK then
			enabledDescriptors["findRank"] = setting.value
		elseif setting.name == settingEnums.settingNames.LEADERBOARD_ENABLE_WRRANK then
			enabledDescriptors["wrRank"] = setting.value
		elseif setting.name == settingEnums.settingNames.LEADERBOARD_ENABLE_WRS then
			enabledDescriptors["wrCount"] = setting.value
		elseif setting.name == settingEnums.settingNames.LEADERBOARD_ENABLE_CWRS then
			enabledDescriptors["cwrs"] = setting.value
		elseif setting.name == settingEnums.settingNames.LEADERBOARD_ENABLE_CWRTOP10S then
			enabledDescriptors["cwrtop10s"] = setting.value
		elseif setting.name == settingEnums.settingNames.LEADERBOARD_ENABLE_TOP10S then
			enabledDescriptors["top10s"] = setting.value
		elseif setting.name == settingEnums.settingNames.LEADERBOARD_ENABLE_RACES then
			enabledDescriptors["races"] = setting.value
		elseif setting.name == settingEnums.settingNames.LEADERBOARD_ENABLE_RUNS then
			enabledDescriptors["runs"] = setting.value
		elseif setting.name == settingEnums.settingNames.LEADERBOARD_ENABLE_BADGES then
			enabledDescriptors["badgeCount"] = setting.value
		else
			warn("unknown leaderboard setting: " .. tostring(setting.name))
		end
	end
	_annotate(string.format("accepted setting: %s=%s", tostring(setting.name), tostring(setting.value)))
	if not initial then
		_annotate("completely resetting userLB cause setting changed")
		completelyResetUserLB(false)
	end
end

module.Init = function()
	loadedSettings = false
	enabledDescriptors = {}
	playerRowCount = 0
	--the user-focused rowFrames go here.
	userId2rowframe = {}
	--the outer, created on time lbframe.
	lbUserRowFrame = nil
	lbIsEnabled = true

	localPlayer = Players.LocalPlayer

	-- load initial default userSetting values.

	handleUserSettingChanged(settings.getSettingByName(settingEnums.settingNames.HIDE_LEADERBOARD), true)

	for _, userSetting in pairs(settings.getSettingByDomain(settingEnums.settingDomains.LEADERBOARD)) do
		handleUserSettingChanged(userSetting, true)
	end

	-- all column settings are loaded so we can draw the LB.

	--initial load at game start.
	completelyResetUserLB(true)
	loadedSettings = true
	-- now we hook up to listen to user data events
	LeaderboardUpdateEvent.OnClientEvent:Connect(function(data)
		module.ClientReceiveNewLeaderboardData(data)
	end)

	-- now we listen for subsequent setting changes.
	settings.RegisterFunctionToListenForSettingName(function(item: tt.userSettingValue): any
		return handleUserSettingChanged(item, false)
	end, settingEnums.settingNames.HIDE_LEADERBOARD)

	settings.RegisterFunctionToListenForDomain(function(item: tt.userSettingValue): any
		return handleUserSettingChanged(item, false)
	end, settingEnums.settingDomains.LEADERBOARD)
end

_annotate("end")

return module
