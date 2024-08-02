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
local localFunctions = require(game.ReplicatedStorage.localFunctions)
local module = {}

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local leaderboardButtons = require(game.StarterPlayer.StarterPlayerScripts.buttons.leaderboardButtons)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local enums = require(game.ReplicatedStorage.util.enums)
local colors = require(game.ReplicatedStorage.util.colors)
local thumbnails = require(game.ReplicatedStorage.thumbnails)
local mt = require(game.StarterPlayer.StarterPlayerScripts.marathonTypes)
local tt = require(game.ReplicatedStorage.types.gametypes)
local remotes = require(game.ReplicatedStorage.util.remotes)

local marathonClient = require(game.StarterPlayer.StarterCharacterScripts.client.marathonClient)
local mds = require(game.ReplicatedStorage.marathonDescriptors)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)

local localRdb = require(game.ReplicatedStorage.localRdb)
local localPlayer = Players.LocalPlayer
local leaderboardUtil = require(game.StarterPlayer.StarterCharacterScripts.client.leaderboardUtil)
local draggability = require(game.StarterPlayer.StarterCharacterScripts.client.draggability)
local resizeability = require(game.StarterPlayer.StarterCharacterScripts.client.resizeability)
local minimizeability = require(game.StarterPlayer.StarterCharacterScripts.client.minimizeability)

-- this covers all the different types of lbupdates that can be sent. for example, one is tt_afterrundata, another is tt_inital join data + username,
export type genericLeaderboardUpdateDataType = { [string]: number | string }

type LeaderboardUserData = { [number]: genericLeaderboardUpdateDataType }

local lbUserData: LeaderboardUserData = {}

--[[
export type lbUserCell = {
	name: string,
	num: number,
	widthScaleImportance: number, -- this represents the proportion of the total scaleImportance to take up. For example if the total is 20 and this takes 1, it means this item should have its scale x set to 0.05,
	userFacingName: string,
	tooltip: string,
}]]

------------- GLOBAL STASTIC OBJECTS ----------------

--used to do reverse ordering items in lb
local bignum: number = 10000000

-- GLOBAL DYNAMIC STATE VARS. EACH USER HAS JUST ONE LEADERBOARD. ----------------

local lbRowCount: number = 0

--one rowFrame for each user is stored in here.
local userId2rowframe: { [number]: Frame } = {}

--the outer, created on time lbframe.
local lbframe: Frame? = nil
local lbIsEnabled: boolean = true

-- the initial width and height scales.
local initialWidthScale = 0.3
local initialHeightScale = 0.1
local headerRowShrinkFactor = 0.6

-- in general the text "lb" refers to leaderboard here.

local function calculateCellWidths(): { [string]: number }
	local totalWidthWeightScale = 0
	for _, lbUserCellDescriptor in pairs(leaderboardUtil.LbUserCellDescriptors) do
		totalWidthWeightScale += lbUserCellDescriptor.widthScaleImportance
	end

	local cellWidths: { [string]: number } = {}
	for _, lbUserCellDescriptor in pairs(leaderboardUtil.LbUserCellDescriptors) do
		local widthYScale = lbUserCellDescriptor.widthScaleImportance / totalWidthWeightScale
		cellWidths[lbUserCellDescriptor.name] = widthYScale
	end

	return cellWidths
end

--setup header row as first row in lbframe
local function makeTitleRow(): Frame
	local userRowFrame = Instance.new("Frame")
	userRowFrame.Parent = lbframe
	userRowFrame.BorderMode = Enum.BorderMode.Inset
	userRowFrame.BorderSizePixel = 0
	userRowFrame.Name = "00000000-title-row"
	local yScaleProportion = 1 / (lbRowCount + headerRowShrinkFactor)
	userRowFrame.Size = UDim2.fromScale(1, yScaleProportion)
	userRowFrame.BackgroundColor3 = colors.leafGreen
	userRowFrame.BackgroundTransparency = 0.2
	local uu = Instance.new("UIListLayout")
	uu.FillDirection = Enum.FillDirection.Horizontal
	uu.Parent = userRowFrame

	local cellWidths = calculateCellWidths()

	for _, lbUserCellDescriptor: leaderboardUtil.lbUserCell in pairs(leaderboardUtil.LbUserCellDescriptors) do
		local myWidthScale = cellWidths[lbUserCellDescriptor.name]

		local el = guiUtil.getTl(
			string.format("%02d.header.%s", lbUserCellDescriptor.num, lbUserCellDescriptor.userFacingName),
			UDim2.fromScale(myWidthScale, 1),
			2,
			userRowFrame,
			colors.defaultGrey,
			0
		)
		el.Text = lbUserCellDescriptor.userFacingName
		el.ZIndex = lbUserCellDescriptor.num
		el.TextXAlignment = Enum.TextXAlignment.Center
		el.TextYAlignment = Enum.TextYAlignment.Center
		el.TextScaled = true
	end
	return userRowFrame
end

local function adjustRowScales()
	if not lbframe then
		return
	end
	_annotate("adjusting row scales.")
	local totalPlayerRows = lbRowCount
	local headerRowHeight = headerRowShrinkFactor / (totalPlayerRows + headerRowShrinkFactor)
	local normalRowHeight = 1 / (totalPlayerRows + headerRowShrinkFactor)

	-- Adjust header row
	local headerRow: Frame = lbframe:FindFirstChild("00000000-title-row")
	if headerRow then
		headerRow.Size = UDim2.fromScale(1, headerRowHeight)
	end

	-- Adjust all other rows
	for _, child: Frame in ipairs(lbframe:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "00000000-title-row" then
			child.Size = UDim2.fromScale(1, normalRowHeight)
		end
	end
end

local function completelyResetUserLB()
	_annotate("copmletely reset? lb")
	--make initial row only. then as things happen (people join, or updates come in, apply them in-place)
	local pgui: PlayerGui = localPlayer:WaitForChild("PlayerGui")

	local oldLbSgui: ScreenGui? = pgui:FindFirstChild("LeaderboardScreenGui") :: ScreenGui?
	if oldLbSgui ~= nil then
		oldLbSgui:Destroy()
	end

	if not lbIsEnabled then
		_annotate("reset lb and it's disabled now so just end.")
		return
	end

	local lbSgui: ScreenGui = Instance.new("ScreenGui")
	lbSgui.Name = "LeaderboardScreenGui"
	lbSgui.Parent = pgui

	lbframe = Instance.new("Frame")
	lbframe.BorderMode = Enum.BorderMode.Inset
	lbframe.BorderSizePixel = 0
	lbframe.Size = UDim2.new(initialWidthScale, 0, initialHeightScale, 0)
	-- Change the position to upper right
	lbframe.Position = UDim2.fromScale(1, 0)
	_annotate("in setup, position is: " .. tostring(lbframe.Position.Y.Scale))
	lbframe.AnchorPoint = Vector2.new(1, 0)
	lbframe.Name = "LeaderboardFrame"
	lbframe.BackgroundTransparency = 0.1
	lbframe.BackgroundColor3 = colors.sandBeige
	lbframe.Parent = lbSgui

	-- for sorting the leaderboard rows.
	local listLayout: UIListLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.Name
	listLayout.Parent = lbframe

	local titleRow = makeTitleRow()
	titleRow.Parent = lbframe

	draggability.SetupDraggability(lbframe)
	resizeability.SetupResizeability(lbframe)
	minimizeability.SetupMinimizeability(lbframe)
	lbRowCount = 0

	leaderboardButtons.initActionButtons(lbframe, localPlayer)

	marathonClient.ReInitActiveMarathons()
	adjustRowScales()
	_annotate("end setup, position is: " .. tostring(lbframe.Position.X.Scale))
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
	--we need this to get ordering before tix are known.
	if userDataFromCache.userTix == nil then
		userDataFromCache.userTix = 0
	end

	local userTixCount: number = userDataFromCache.userTix :: number
	local rowName = string.format("%s_PlayerRow_%s", tostring(bignum - userTixCount), username)
	rowFrame.Name = rowName
	local rowYScale = 1 / (lbRowCount + 2) -- +1 for header, +1 for new row
	rowFrame.Size = UDim2.fromScale(1, rowYScale)
	rowFrame.BorderMode = Enum.BorderMode.Inset
	rowFrame.BorderSizePixel = 0
	rowFrame.BackgroundTransparency = 0.1
	local horizontalLayout = Instance.new("UIListLayout")
	horizontalLayout.FillDirection = Enum.FillDirection.Horizontal
	horizontalLayout.Parent = rowFrame
	rowFrame.Parent = lbframe

	local bgcolor = colors.stoneGray
	if userId == localPlayer.UserId then
		bgcolor = colors.waterBlue
	end

	local cellWidths = calculateCellWidths()

	for _, lbUserCellDescriptor: leaderboardUtil.lbUserCell in pairs(leaderboardUtil.LbUserCellDescriptors) do
		local widthYScale = cellWidths[lbUserCellDescriptor.name]

		if lbUserCellDescriptor.name == "portrait" then
			local portraitContainer = Instance.new("Frame")
			portraitContainer.Size = UDim2.fromScale(widthYScale, 1)
			portraitContainer.BackgroundTransparency = 1
			portraitContainer.Name = string.format("%02d.value", lbUserCellDescriptor.num)
			portraitContainer.Parent = rowFrame

			local img = Instance.new("ImageLabel")
			img.Size = UDim2.new(1, 0, 1, 0)
			local content = thumbnails.getThumbnailContent(userId, Enum.ThumbnailType.HeadShot)
			img.Image = content
			img.BackgroundColor3 = bgcolor
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
					task.delay(0.1, function()
						-- Check if the large avatar would go off the bottom of the screen
						local viewportSize = workspace.CurrentCamera.ViewportSize
						local absolutePosition = portraitContainer.AbsolutePosition
						local yPosition = math.min(absolutePosition.Y, viewportSize.Y - 220)

						largeAvatarImage.Position = UDim2.new(0, -20, 0, yPosition - absolutePosition.Y)
						largeAvatarImage.Visible = true
						largeAvatarImage.ImageTransparency = 1
						local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
						local tween = TweenService:Create(largeAvatarImage, tweenInfo, { ImageTransparency = 0 })
						tween:Play()
						showAvatarDebounce = false
					end)
				end
			end

			local function hideLargeAvatar()
				largeAvatarImage.Visible = false
			end

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
		_annotate(string.format("waiting for user %s to finish receiving their lb update", userData.userId))
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
		receivedUserData = receivedUserData .. string.format("\t%s=%s ", a, b)
	end
	_annotate(string.format("got info about: %s: %s", subjectUserId, receivedUserData))

	--check if this client's user has any lbframe.
	if subjectUserId == nil then
		warn("nil userid for update.")
		debounceUpdateUserLeaderboardRow[userData.userId] = nil
		return
	end

	if lbframe == nil then
		_annotate("compoletely reset them cause no lbframe.")
		completelyResetUserLB()
	elseif lbframe.Parent == nil then
		_annotate("compoletely reset them cause lbframe parent is nil.")
		completelyResetUserLB()
	end

	--first check if there is anything worthwhile to draw - anything changed.

	local userDataChanges: { tt.leaderboardUserDataChange } = StoreUserData(subjectUserId, userData)
	if userDataChanges == nil or #userDataChanges == 0 then
		_annotate(
			string.format(
				"looks like we received information again which we already had, so the storeOperation returned nothing. Here is the data: %s",
				receivedUserData
			)
		)
		debounceUpdateUserLeaderboardRow[userData.userId] = nil
		return
	end

	--patch things up if needed.
	_annotate("patching up existing rowframe with new data.")
	local userRowFrame: Frame = userId2rowframe[subjectUserId]
	if userRowFrame == nil or userRowFrame.Parent == nil then
		if userRowFrame == nil then
			_annotate("remaking userRowFrame cause it was nil")
		else
			_annotate("destroyed userRowFrame cause its parent is nil")
			userRowFrame:Destroy()
		end
		userId2rowframe[subjectUserId] = nil
		local candidateRowFrame: Frame = createRowForUser(subjectUserId, userData.name)
		if candidateRowFrame == nil then --case when the user is gone already.
			debounceUpdateUserLeaderboardRow[userData.userId] = nil
			return
		end
		lbRowCount = lbRowCount + 1
		userRowFrame = candidateRowFrame
		userId2rowframe[subjectUserId] = userRowFrame
		userRowFrame.Parent = lbframe
	end

	local bgcolor = colors.stoneGray
	if subjectUserId == localPlayer.UserId then
		bgcolor = colors.waterBlue
	end

	for _, change: tt.leaderboardUserDataChange in pairs(userDataChanges) do
		-- find the userCellDescriptor corresponding to it.

		local descriptor = nil
		for _, lbUserCellDescriptor in pairs(leaderboardUtil.LbUserCellDescriptors) do
			if lbUserCellDescriptor.name == change.key then
				descriptor = lbUserCellDescriptor
				break
			end
		end

		--if we receive a tix update, update rowframe. This is because we order by tix count.
		if change.key == "userTix" then
			local username = localRdb.getUsernameByUserId(subjectUserId)
			local newName = tostring(bignum - change.newValue) .. username
			userRowFrame.Name = newName
			userRowFrame.Name = newName
		end

		--if no descriptor, quit. effectively the same as name doesn't appear in: updateUserLbRowKeys
		--note: this can happen because lbupdates have full BE stats in them, not all of which we render into LB
		if descriptor == nil then
			_annotate("we don't have a descriptor for: " .. change.key)
			continue
		end
		_annotate("applying data about: " .. change.key)
		local targetName = string.format("%02d.value", descriptor.num)
		--it's important this targetname matches via interpolatino
		local oldTextLabelParent: TextLabel = userRowFrame:FindFirstChild(targetName) :: TextLabel
		local oldTextLabel = oldTextLabelParent:FindFirstChild("Inner")

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

		--so this basically means, if you're trying to do initial user setup, and then you find that
		-- one of the changes you're intending to apply is actually an overwrite, don't do it.
		-- i'm not sure how this is supposed to work - probably legacy from when I didn't have tix
		-- separated out. what's actually happening is that tix is showing up as loaded already
		-- probably because the main user data stuff is slower than the tix load stuff.

		--phase to new color if needed
		if newIntermediateText == nil then
			oldTextLabel.Text = newFinalText
			oldTextLabel.BackgroundColor3 = bgcolor
			oldTextLabel.Parent.BackgroundColor3 = bgcolor
		else
			if improvement then
				oldTextLabel.BackgroundColor3 = colors.leafGreen
				oldTextLabel.Parent.BackgroundColor3 = colors.leafGreen
			else
				oldTextLabel.BackgroundColor3 = colors.waterBlue
				oldTextLabel.Parent.BackgroundColor3 = colors.waterBlue
			end
			oldTextLabel.Text = newIntermediateText
			task.spawn(function()
				wait(enums.greenTime)
				oldTextLabel.Text = newFinalText
			end)
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

			-- Add a subtle scale animation by expanding the green then shrinking it.
			-- also have to hit the inner box too not just the outer. hmm wonder why this is messed up?

			-- Add a subtle wiggle animation
			local originalPosition = oldTextLabel.Position
			local wiggleTween = TweenService:Create(
				oldTextLabel,
				TweenInfo.new(enums.greenTime / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true),
				{ Position = originalPosition + UDim2.new(0, 5, 0, 0) }
			)
			wiggleTween:Play()

			-- Apply the same wiggle to the parent frame
			local parentOriginalPosition = oldTextLabel.Parent.Position
			local parentWiggleTween = TweenService:Create(
				oldTextLabel.Parent,
				TweenInfo.new(enums.greenTime / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true),
				{ Position = parentOriginalPosition + UDim2.new(0, 50, 0, 50) }
			)
			parentWiggleTween:Play()

			local scaleTween = TweenService:Create(
				oldTextLabel,
				TweenInfo.new(enums.greenTime, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
				{ Size = oldTextLabel.Size }
			)
			oldTextLabel.Size = UDim2.fromScale(oldTextLabel.Size.X.Scale * 1.1, 1)
			scaleTween:Play()
		end
	end
	debounceUpdateUserLeaderboardRow[userData.userId] = nil
end

local removeDebouncers = {}
local function removeUserLBRow(userId: number): ()
	if removeDebouncers[userId] then
		return
	end
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
		if lbRowCount > 0 then
			lbRowCount = math.min(0, lbRowCount - 1)
		else
			warn("okay, clear error here. lbRowcount too low" .. tostring(lbRowCount))
		end
	end
	adjustRowScales()
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
		_annotate("got lbupdate of known good kind: " .. lbUpdateData.kind)
	else
		_annotate("got lbupdate of unknown kind: " .. lbUpdateData.kind)
	end
	updateUserLeaderboardRow(lbUpdateData)
	adjustRowScales()
	receiveDataDebouncer = false
end

--user changed marathon settings in UI - uses registration to monitor it.
--note there is an init call here so user settings _will_ show up here and we should
--be careful not to mistakenly reinit LB needlessly.
local function handleUserSettingChanged(setting: tt.userSettingValue)
	if setting.name == settingEnums.settingNames.HIDE_LEADERBOARD then
		if setting.value then
			lbIsEnabled = false
			marathonClient.CloseAllMarathons()
			completelyResetUserLB()
		else
			if not lbIsEnabled then
				lbIsEnabled = true
				completelyResetUserLB()
			end
		end
	end
end

--ideally filter at the registration layer but whatever.
--also why is this being done here rather than in marathon client?
local function HandleMarathonSettingsChanged(setting: tt.userSettingValue)
	_annotate("Handle marathon settings changed")
	if setting.domain ~= settingEnums.settingDomains.MARATHONS then
		return
	end
	local key = string.split(setting.name, " ")[2]
	local targetMarathon: mt.marathonDescriptor = mds[key]
	if targetMarathon == nil then
		warn("bad setting probably legacy bad naming, shouldn't be many and no effect." .. key)
		return
	end
	if setting.value then
		marathonClient.InitMarathon(targetMarathon, true)
	else
		marathonClient.DisableMarathon(targetMarathon)
	end
end

local hideLb = localFunctions.getSettingByName(settingEnums.settingNames.HIDE_LEADERBOARD)
if hideLb.value then
	lbIsEnabled = false
else
	lbIsEnabled = true
end

function module.Init(): ()
	localPlayer = Players.LocalPlayer

	lbRowCount = 0
	--the user-focused rowFrames go here.
	userId2rowframe = {}
	--the outer, created on time lbframe.
	lbframe = nil
	lbIsEnabled = true
	localFunctions.RegisterLocalSettingChangeReceiver(function(item: tt.userSettingValue): any
		return handleUserSettingChanged(item)
	end, settingEnums.settingNames.HIDE_LEADERBOARD)

	localFunctions.RegisterLocalSettingChangeReceiver(function(item: tt.userSettingValue): any
		_annotate("inner registerHandleMarathon settings changed")
		return HandleMarathonSettingsChanged(item)
	end, "HandleMarathonSettingsChanged")

	-- we setup the event, but what if upstream playerjoinfunc is called first?
	local leaderboardUpdateEvent = remotes.getRemoteEvent("LeaderboardUpdateEvent")
	leaderboardUpdateEvent.OnClientEvent:Connect(module.ClientReceiveNewLeaderboardData)

	-- listen to racestart, raceendevent
	marathonClient.Init()
	local initialMarathonSettings = localFunctions.getSettingByDomain(settingEnums.settingDomains.MARATHONS)

	-- load marathons according to the users settings
	for _, userSetting in pairs(initialMarathonSettings) do
		HandleMarathonSettingsChanged(userSetting)
	end

	-- this seems overkill? we already have marathon setup above right
	local userSettings = localFunctions.getSettingByDomain(settingEnums.settingDomains.USERSETTINGS)

	for _, userSetting in pairs(userSettings) do
		handleUserSettingChanged(userSetting)
	end
end

_annotate("end")

return module
