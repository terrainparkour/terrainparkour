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
local tt = require(game.ReplicatedStorage.types.gametypes)
local settings = require(game.ReplicatedStorage.settings)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local leaderboardButtons = require(game.StarterPlayer.StarterPlayerScripts.buttons.leaderboardButtons)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local enums = require(game.ReplicatedStorage.util.enums)
local colors = require(game.ReplicatedStorage.util.colors)
local thumbnails = require(game.ReplicatedStorage.thumbnails)

local remotes = require(game.ReplicatedStorage.util.remotes)

local marathonClient = require(game.StarterPlayer.StarterCharacterScripts.client.marathonClient)
local localRdb = require(game.ReplicatedStorage.localRdb)
local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local TweenService = game:GetService("TweenService")

-------------------EVENTS ---------------------
-- we setup the event, but what if upstream playerjoinfunc is called first?
local leaderboardUpdateEvent = remotes.getRemoteEvent("LeaderboardUpdateEvent")

----------------- TYPES ---------------------

-- this covers all the different types of lbupdates that can be sent. for example, one is tt_afterrundata, another is tt_inital join data + username,
export type genericLeaderboardUpdateDataType = { [string]: number | string }

type LeaderboardUserData = { [number]: genericLeaderboardUpdateDataType }

local lbUserData: LeaderboardUserData = {}

export type lbUserCell = {
	name: string,
	num: number,
	widthScaleImportance: number,
	userFacingName: string,
	tooltip: string,
}

local lbUserCellDescriptors: { [string]: lbUserCell } = {
	portrait = { name = "portrait", num = 1, widthScaleImportance = 10, userFacingName = "", tooltip = "" },
	username = { name = "username", num = 3, widthScaleImportance = 25, userFacingName = "", tooltip = "" },
	awardCount = {
		name = "awardCount",
		num = 5,
		widthScaleImportance = 7,
		userFacingName = "awards",
		tooltip = "How many special awards you've earned from contests or other achievements.",
	},
	userTix = {
		name = "userTix",
		num = 7,
		widthScaleImportance = 18,
		userFacingName = "tix",
		tooltip = "How many tix you've earned from your runs and finds and records.",
	},
	userTotalFindCount = {
		name = "userTotalFindCount",
		num = 9,
		widthScaleImportance = 10,
		userFacingName = "finds",
		tooltip = "How many signs you've found!",
	},
	findRank = {
		name = "findRank",
		num = 11,
		widthScaleImportance = 8,
		userFacingName = "rank",
		tooltip = "Your rank of how many signs you've found.",
	},
	userCompetitiveWRCount = {
		name = "userCompetitiveWRCount",
		num = 13,
		widthScaleImportance = 12,
		userFacingName = "cwrs",
		tooltip = "How many World Records you hold in competitive races!",
	},
	userTotalWRCount = {
		name = "userTotalWRCount",
		num = 15,
		widthScaleImportance = 10,
		userFacingName = "wrs",
		tooltip = "How many World Records you hold right now.",
	},
	top10s = {
		name = "top10s",
		num = 18,
		widthScaleImportance = 8,
		userFacingName = "top10s",
		tooltip = "How many of your runs are still in the top10.",
	},
	races = {
		name = "races",
		num = 23,
		widthScaleImportance = 6,
		userFacingName = "races",
		tooltip = "How many distinct runs you've done.",
	},
	runs = {
		name = "runs",
		num = 26,
		widthScaleImportance = 6,
		userFacingName = "runs",
		tooltip = "How many runs you've done in total.",
	},
	badgeCount = {
		name = "badgeCount",
		num = 31,
		widthScaleImportance = 10,
		userFacingName = "badges",
		tooltip = "Total game badges you have won.",
	},
}

------------- GLOBAL STATIC OBJECTS ----------------

--used to do reverse ordering items in lb
local bignum: number = 10000000

-- GLOBAL DYNAMIC STATE VARS. EACH USER HAS JUST ONE LEADERBOARD. ----------------

local playerRowCount: number = 0

--one rowFrame for each user is stored in here.
local userId2rowframe: { [number]: Frame } = {}

local lbFrame: Frame? = nil
local lbIsEnabled: boolean = true

-- the initial width and height scales.
local initialWidthScale = 0.45
local initialHeightScale = 0.11
local headerRowShrinkFactor = 0.6

------------------FUNCTIONS--------------
local function calculateCellWidths(): { [string]: number }
	local totalWidthWeightScale = 0
	for _, lbUserCellDescriptor in pairs(lbUserCellDescriptors) do
		totalWidthWeightScale += lbUserCellDescriptor.widthScaleImportance
	end

	local cellWidths: { [string]: number } = {}
	for _, lbUserCellDescriptor in pairs(lbUserCellDescriptors) do
		local widthYScale = lbUserCellDescriptor.widthScaleImportance / totalWidthWeightScale
		cellWidths[lbUserCellDescriptor.name] = widthYScale
	end

	return cellWidths
end

--setup header row as first row in lbframe
local function makeTitleRow(): Frame
	local titleRow = Instance.new("Frame")
	titleRow.Parent = lbFrame
	titleRow.BorderMode = Enum.BorderMode.Inset
	titleRow.BorderSizePixel = 0
	titleRow.Name = "0000000LeaderboardHeaderRow"
	local yScaleProportion = 1 / (playerRowCount + headerRowShrinkFactor)
	titleRow.Size = UDim2.fromScale(1, yScaleProportion)
	titleRow.BackgroundColor3 = colors.greenGo
	titleRow.BackgroundTransparency = 0.2
	local hh = Instance.new("UIListLayout")
	hh.FillDirection = Enum.FillDirection.Horizontal
	hh.Parent = titleRow
	hh.Name = "HeaderRow-hh"

	local cellWidths = calculateCellWidths()

	for _, lbUserCellDescriptor: lbUserCell in pairs(lbUserCellDescriptors) do
		local myWidthScale = cellWidths[lbUserCellDescriptor.name]

		local el = guiUtil.getTl(
			string.format("%02d.header.%s", lbUserCellDescriptor.num, lbUserCellDescriptor.userFacingName),
			UDim2.fromScale(myWidthScale, 1),
			2,
			titleRow,
			colors.defaultGrey,
			0
		)
		el.Text = lbUserCellDescriptor.userFacingName
		el.ZIndex = lbUserCellDescriptor.num
		el.TextXAlignment = Enum.TextXAlignment.Center
		el.TextYAlignment = Enum.TextYAlignment.Center
		el.TextScaled = true
	end
	return titleRow
end

local function adjustRowScales()
	if not lbFrame then
		return
	end
	--_annotate("adjusting row scales.")

	local totalYWeight = headerRowShrinkFactor + playerRowCount

	local normalizedHeaderRowYScale = headerRowShrinkFactor / totalYWeight
	local normalizedPlayerRowYScale = 1 / totalYWeight
	--_annotate("playerRowCount" .. playerRowCount)
	--_annotate("headerRowHeightScale" .. normalizedHeaderRowYScale)
	--_annotate("normalRowHeightScale" .. normalizedPlayerRowYScale)

	local headerRow: Frame = lbFrame:FindFirstChild("0000000LeaderboardHeaderRow")
	if headerRow then
		headerRow.Size = UDim2.fromScale(1, normalizedHeaderRowYScale)
	end

	for _, child: Frame in ipairs(lbFrame:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "0000000LeaderboardHeaderRow" then
			child.Size = UDim2.fromScale(1, normalizedPlayerRowYScale)
		end
	end
end

--important to use all lbUserCellParams here to make the row complete
--even if an update comes before the loading of full stats.

local function createRowForUser(userId: number, username: string): Frame?
	--remember, this user may not actually be present in the server!
	local rowFrame: Frame = Instance.new("Frame")
	local userDataFromCache = lbUserData[userId]
	if not username then
		username = localRdb.getUsernameByUserId(userId)
	end
	if userDataFromCache == nil then
		--_annotate("createRowForUser called with no userDataFromCache for userId: " .. tostring(userId))
		return
	end
	--we need this to get ordering before tix are known.
	if userDataFromCache.userTix == nil then
		userDataFromCache.userTix = 0
	end

	local userTixCount: number = userDataFromCache.userTix :: number
	local rowName = string.format("%s_A_PlayerRow_%s", tostring(bignum - userTixCount), username)
	rowFrame.Name = rowName
	-- local rowYScale = 1 / (playerRowCount + 2) -- +1 for header, +1 for new row
	-- rowFrame.Size = UDim2.fromScale(1, rowYScale)
	rowFrame.BorderMode = Enum.BorderMode.Inset
	rowFrame.BorderSizePixel = 0
	rowFrame.BackgroundTransparency = 0.1
	local horizontalLayout = Instance.new("UIListLayout")
	horizontalLayout.FillDirection = Enum.FillDirection.Horizontal
	horizontalLayout.Parent = rowFrame
	horizontalLayout.Name = "LeaderboardUserRowHH"
	rowFrame.Parent = lbFrame

	local bgcolor = colors.defaultGrey
	if userId == localPlayer.UserId then
		bgcolor = colors.meColor
	end

	local cellWidths = calculateCellWidths()

	for _, lbUserCellDescriptor: lbUserCell in pairs(lbUserCellDescriptors) do
		local widthYScale = cellWidths[lbUserCellDescriptor.name]

		if lbUserCellDescriptor.name == "portrait" then
			local portraitContainer = Instance.new("Frame")
			portraitContainer.Size = UDim2.fromScale(widthYScale, 1)
			portraitContainer.BackgroundTransparency = 1
			portraitContainer.Name = string.format("%02d.%s", lbUserCellDescriptor.num, lbUserCellDescriptor.name)
			portraitContainer.Parent = rowFrame

			local img = Instance.new("ImageLabel")
			img.Size = UDim2.new(1, 0, 1, 0)
			local content = thumbnails.getThumbnailContent(userId, Enum.ThumbnailType.HeadShot)
			img.Image = content
			img.BackgroundColor3 = colors.defaultGrey
			img.Name = "PortraitImage"
			img.Parent = portraitContainer
			img.BorderMode = Enum.BorderMode.Outline
			img.ScaleType = Enum.ScaleType.Stretch

			-- Add mouseover functionality so that when you mouseover the portrait cell (the 1st one) to the left of it,
			-- a larger portrait appears.  It has no effectonthe row.
			local largeAvatarImage = Instance.new("ImageLabel")
			largeAvatarImage.Size = UDim2.new(0, 200, 0, 200)
			largeAvatarImage.Position = UDim2.new(0, -220, 0, 0)
			largeAvatarImage.AnchorPoint = Vector2.new(1, 0)
			largeAvatarImage.Visible = false
			largeAvatarImage.ZIndex = 10
			largeAvatarImage.Parent = portraitContainer

			local largeContent = thumbnails.getThumbnailContent(userId, Enum.ThumbnailType.HeadShot, 420)
			largeAvatarImage.Image = largeContent

			local showAvatarDebounce = false
			local function showLargeAvatar()
				if not showAvatarDebounce then
					showAvatarDebounce = true
					largeAvatarImage.Position = UDim2.new(0, -30, 0, 0)
					largeAvatarImage.Visible = true
					largeAvatarImage.ImageTransparency = 1
					showAvatarDebounce = false
				end
			end

			local function hideLargeAvatar()
				largeAvatarImage.Visible = false
			end

			-- in general mouseenter can fire before mouseleave. which means sometimes the avatar image gets stuck
			portraitContainer.MouseEnter:Connect(showLargeAvatar)
			portraitContainer.MouseLeave:Connect(hideLargeAvatar)
			img.BorderSizePixel = 1
		else --it's a textlabel whatever we're generating anyway.
			local tl = guiUtil.getTl(
				string.format("%02d.value", lbUserCellDescriptor.num),
				UDim2.fromScale(widthYScale, 1),
				2,
				rowFrame,
				bgcolor,
				1,
				0
			)

			--find text for value.
			if lbUserCellDescriptor.name == "findRank" then
				local foundRank = userDataFromCache.findRank
				if foundRank ~= nil then
					tl.Text = tpUtil.getCardinalEmoji(foundRank)
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
	adjustRowScales()
	return rowFrame
end

local function completelyResetUserLB()
	--_annotate("completely reset? lb")
	--make initial row only. then as things happen (people join, or updates come in, apply them in-place)
	local pgui: PlayerGui = localPlayer:WaitForChild("PlayerGui")

	local oldLbSgui: ScreenGui? = pgui:FindFirstChild("LeaderboardScreenGui") :: ScreenGui?
	if oldLbSgui ~= nil then
		oldLbSgui:Destroy()
	end

	if not lbIsEnabled then
		--_annotate("reset lb and it's disabled now so just end.")
		return
	end

	local lbSgui: ScreenGui = Instance.new("ScreenGui")
	lbSgui.Name = "LeaderboardScreenGui"
	lbSgui.Parent = pgui
	lbSgui.IgnoreGuiInset = true

	local lbOuterFrame = Instance.new("Frame")
	lbOuterFrame.Name = "LeaderboardOuterFrame"
	lbOuterFrame.Parent = lbSgui
	lbOuterFrame.Size = UDim2.new(initialWidthScale, 0, initialHeightScale, 0)
	-- lbOuterFrame.BackgroundTransparency = 1
	lbOuterFrame.Position = UDim2.fromScale(1 - initialWidthScale, 0)
	-- Change the position to upper right

	local lbServerEventFrame = Instance.new("Frame")
	lbServerEventFrame.Name = "3LeaderboardServerEventFrame"
	lbServerEventFrame.Parent = lbOuterFrame
	-- lbServerEventFrame.Size = UDim2.new(1, -200, 0, 120)
	-- lbServerEventFrame.Position = UDim2.new(0, 0, 0, 0)
	-- lbServerEventFrame.BackgroundTransparency = 1
	lbServerEventFrame.BorderMode = Enum.BorderMode.Inset
	lbServerEventFrame.Parent = lbOuterFrame

	local vv = Instance.new("UIListLayout")
	vv.Name = "leaderboardServerEvent-vv"
	vv.Parent = lbServerEventFrame
	vv.FillDirection = Enum.FillDirection.Vertical
	vv.Parent = lbServerEventFrame

	lbFrame = Instance.new("Frame")
	lbFrame.BorderMode = Enum.BorderMode.Inset
	lbFrame.BorderSizePixel = 0
	lbFrame.Size = UDim2.new(1, 0, 1, 0)
	lbFrame.Name = "1LeaderboardFrame"
	lbFrame.BackgroundTransparency = 0.1
	lbFrame.BackgroundColor3 = colors.defaultGrey
	lbFrame.Parent = lbOuterFrame

	local leaderboardUILayout = Instance.new("UIListLayout")
	leaderboardUILayout.Name = "LeaderboardUILayout"
	leaderboardUILayout.Wraps = false

	leaderboardUILayout.HorizontalAlignment = Enum.HorizontalAlignment.Right

	leaderboardUILayout.SortOrder = Enum.SortOrder.Name
	leaderboardUILayout.Parent = lbFrame
	leaderboardUILayout.FillDirection = Enum.FillDirection.Vertical
	leaderboardUILayout.Parent = lbOuterFrame

	-- for sorting the leaderboard rows.
	local leaderboardNameSorter: UIListLayout = Instance.new("UIListLayout")
	leaderboardNameSorter.SortOrder = Enum.SortOrder.Name
	leaderboardNameSorter.Name = "LeaderboardNameSorter"
	leaderboardNameSorter.Parent = lbFrame

	local titleRow = makeTitleRow()
	titleRow.Parent = lbFrame

	playerRowCount = 0
	--_annotate("reset playerrowCount to zero.")

	leaderboardButtons.initActionButtons(lbOuterFrame)
	local marathonFrame = pgui:FindFirstChild("2LeaderboardMarathonFrame", true)
	if marathonFrame ~= nil then
		marathonFrame:Destroy()
	end
	marathonFrame = Instance.new("Frame")
	marathonFrame.Name = "2LeaderboardMarathonFrame"
	marathonFrame.Parent = lbFrame.Parent
	marathonFrame.BackgroundTransparency = 1
	local hh = Instance.new("UIListLayout")
	hh.Name = "marathonFrame-hh"
	hh.Parent = marathonFrame
	hh.FillDirection = Enum.FillDirection.Vertical
	hh.SortOrder = Enum.SortOrder.Name

	marathonClient.Init()
	if #userId2rowframe > 0 then
		--_annotate("resetting but userId2rowframe not empty?")
	end

	windows.SetupDraggability(lbOuterFrame)
	local resizer = windows.SetupResizeability(lbOuterFrame)
	windows.SetupMinimizeability(lbOuterFrame, {
		lbFrame,
		resizer,
		marathonFrame,
		lbOuterFrame:FindFirstChild("3LeaderboardServerEventFrame"),
		lbOuterFrame:FindFirstChild("4LeaderboardActionButtonFrame"),
	})

	userId2rowframe = {}
	for _, player in pairs(Players:GetPlayers()) do
		local created = createRowForUser(player.UserId, player.Name)
		if created then
			userId2rowframe[player.UserId] = created
			playerRowCount = playerRowCount + 1
			--_annotate("in completely regen, resetting everybody's userid2rowframe")
		end
	end

	adjustRowScales()
	--_annotate("end setup, position is: " .. tostring(lbFrame.Position.X.Scale))
end

--after receiving an lb update, figure out what changed relative to known data
--store it and return a userDataChange for rendering into the LB
local function StoreUserData(userId: number, data: genericLeaderboardUpdateDataType): { tt.leaderboardUserDataChange }
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
	return res
end

-- store the data in-memory.
local debounceUpdateUserLeaderboardRow = {}
local function updateUserLeaderboardRow(userData: genericLeaderboardUpdateDataType): ()
	if debounceUpdateUserLeaderboardRow[userData.userId] then
		--_annotate(string.format("waiting for user %s to finish receiving their lb update", userData.userId))
		wait(0.1)
	end
	debounceUpdateUserLeaderboardRow[userData.userId] = true
	if not lbIsEnabled then
		debounceUpdateUserLeaderboardRow[userData.userId] = nil
		return
	end
	local subjectUserId = userData.userId
	local receivedUserData = ""
	for a, b in pairs(userData) do
		receivedUserData = receivedUserData .. string.format("\t%s=%s ", tostring(a), tostring(b))
	end
	--_annotate(string.format("got info about: %s: %s", tostring(subjectUserId), receivedUserData))

	--check if this client's user has any lbframe.
	if subjectUserId == nil then
		warn("nil userid for update.")
		debounceUpdateUserLeaderboardRow[userData.userId] = nil
		return
	end

	if lbFrame == nil then
		--_annotate("compoletely reset them cause no lbframe.")
		completelyResetUserLB()
	elseif lbFrame.Parent == nil then
		--_annotate("compoletely reset them cause lbframe parent is nil.")
		completelyResetUserLB()
	end

	--first check if there is anything worthwhile to draw - anything changed.

	local userDataChanges: { tt.leaderboardUserDataChange } = StoreUserData(subjectUserId, userData)
	if userDataChanges == nil or #userDataChanges == 0 then
		--_annotate(
		-- 	string.format(
		-- 		"looks like we received information again which we already had, so the storeOperation returned nothing. Here is the data: %s",
		-- 		receivedUserData
		-- 	)
		-- )
		debounceUpdateUserLeaderboardRow[userData.userId] = nil
		return
	end

	--patch things up if needed.
	--_annotate("patching up existing rowframe with new data")
	local userRowFrame: Frame = userId2rowframe[subjectUserId]
	print("updateing for " .. tostring(subjectUserId))
	if userRowFrame == nil or userRowFrame.Parent == nil then
		if userRowFrame == nil then
			--_annotate("remaking userRowFrame cause it was nil")
		else
			--_annotate("destroyed userRowFrame cause its parent is nil")
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
		userRowFrame.Parent = lbFrame
		playerRowCount = playerRowCount + 1
		--_annotate("increased playerrowCount to: " .. tostring(playerRowCount))
	end

	local bgcolor = colors.defaultGrey
	if subjectUserId == localPlayer.UserId then
		bgcolor = colors.meColor
	end

	for _, change: tt.leaderboardUserDataChange in pairs(userDataChanges) do
		-- find the userCellDescriptor corresponding to it.

		local descriptor = nil
		for _, lbUserCellDescriptor in pairs(lbUserCellDescriptors) do
			if lbUserCellDescriptor.name == change.key then
				descriptor = lbUserCellDescriptor
				break
			end
		end

		--if we receive a tix update, update rowframe. This is because we order by tix count.
		if change.key == "userTix" then
			local username = localRdb.getUsernameByUserId(subjectUserId)
			local newName = string.format("%s_PlayerRow_%s", tostring(bignum - change.newValue), username)
			userRowFrame.Name = newName
			userRowFrame.Name = newName
		end

		--if no descriptor, quit. effectively the same as name doesn't appear in: updateUserLbRowKeys
		--note: this can happen because lbupdates have full BE stats in them, not all of which we render into LB
		if descriptor == nil then
			--_annotate("we don't have a descriptor for: " .. change.key)
			continue
		end
		--_annotate("applying data about: " .. change.key)
		local targetName = string.format("%02d.value", descriptor.num)
		--it's important this targetname matches via interpolatino
		local oldTextLabelParent: TextLabel = userRowFrame:FindFirstChild(targetName) :: TextLabel
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

	adjustRowScales()
	debounceUpdateUserLeaderboardRow[userData.userId] = nil
end

local removeDebouncers = {}
local function removeUserLBRow(userId: number): ()
	if removeDebouncers[userId] then
		return
	end
	--_annotate("removeUserLBRow called for userId: " .. tostring(userId))
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
			--_annotate("decreasing playerRowCount, it is now: " .. tostring(playerRowCount))
		else
			warn("okay, clear error here. lbRowcount too low" .. tostring(playerRowCount))
		end
	end
	adjustRowScales()
	--_annotate("done with remove UserLbRow")
	removeDebouncers[userId] = nil
end

--data is a list of kvs for update data. if any change, redraw the row (and highlight that cell.)
--First keyed to receive data about a userId. But later overloading data to just be blobs  of things of specific types to display in leaderboard.
local receiveDataDebouncer = false
module.ClientReceiveNewLeaderboardData = function(lbUpdateData: genericLeaderboardUpdateDataType)
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
		--_annotate("got lbupdate of known good kind: " .. lbUpdateData.kind)
	else
		--_annotate("got lbupdate of unknown kind: " .. lbUpdateData.kind)
	end
	updateUserLeaderboardRow(lbUpdateData)
	adjustRowScales()
	receiveDataDebouncer = false
end

--user changed marathon settings in UI - uses registration to monitor it.
--note there is an init call here so user settings _will_ show up here and we should
--be careful not to mistakenly reinit LB needlessly.
local function handleUserSettingChanged(setting: tt.userSettingValue, initial: boolean)
	if setting.name == settingEnums.settingNames.HIDE_LEADERBOARD and not initial then
		if setting.value then
			lbIsEnabled = false
			marathonClient.CloseAllMarathons()
			completelyResetUserLB()
		else
			lbIsEnabled = true
			completelyResetUserLB()
			marathonClient.Init()
		end
	end
end

module.Init = function()
	localPlayer = Players.LocalPlayer
	playerRowCount = 0
	--the user-focused rowFrames go here.
	userId2rowframe = {}
	--the outer, created on time lbframe.
	lbFrame = nil
	lbIsEnabled = true

	settings.RegisterFunctionToListenForSettingName(function(item: tt.userSettingValue): any
		return handleUserSettingChanged(item)
	end, settingEnums.settingNames.HIDE_LEADERBOARD)
	handleUserSettingChanged(settings.getSettingByName(settingEnums.settingNames.HIDE_LEADERBOARD), true)
	leaderboardUpdateEvent.OnClientEvent:Connect(function(data)
		module.ClientReceiveNewLeaderboardData(data, false)
	end)
end

_annotate("end")

return module
