--!strict
--eval 9.25.22

--2022 remaining bug: sometimes you get fail.04 or fail.05 and permanent  shifting.
--2022.02.12 why is this so hard to get right? or rather why doesn't it just work out of the box?
--2022.02.24 revisiting to finally fix LB bugs.
local vscdebug = require(game.ReplicatedStorage.vscdebug)

local TweenService = game:GetService("TweenService")
local PlayersService = game:GetService("Players")
local leaderboardButtons = require(game.StarterPlayer.StarterCharacterScripts.leaderboardButtons)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local localPlayer = PlayersService.LocalPlayer
local StarterPlayer = game:GetService("StarterPlayer")

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local enums = require(game.ReplicatedStorage.util.enums)
local colors = require(game.ReplicatedStorage.util.colors)
local thumbnails = require(game.ReplicatedStorage.thumbnails)
local mt = require(game.StarterPlayer.StarterCharacterScripts.marathon.marathonTypes)
local tt = require(game.ReplicatedStorage.types.gametypes)
local remotes = require(game.ReplicatedStorage.util.remotes)

local toolTip = require(game.ReplicatedStorage.gui.toolTip)
local marathonClient = require(StarterPlayer.StarterCharacterScripts.marathon.marathonClient)
local mds = require(game.ReplicatedStorage.marathonDescriptors)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local lbEnums = require(game.ReplicatedStorage.enums.lbEnums)

local lbIsEnabled = true

local doAnnotation = localPlayer.UserId == enums.objects.TerrainParkour and false
local function annotate(s): nil
	if doAnnotation then
		print("lb.client: " .. string.format("%.0f", tick()) .. " : " .. s)
	end
end

--used to negative order items in lb
local bignum = 10000000

type userData = { [string]: number | string }

--returns changed keys and oldvalue
type userDataChange = { key: string, oldValue: number, newValue: number }

--map of { userId to {keyname:number}}
--note this is stored over time and serves as an in-user-memory re-usable cache.
local lbUserData: { [number]: userData } = {}

--test wrapping this here to force stronger typing
type rowFrameType = { frame: Frame }

--the user-focused rowFrames go  here.
-- {userId : rowFrame?}
local userId2rowframe: { [number]: rowFrameType } = {}

--the outer, created on time lbframe.
local lbframe: Frame

--active tracking
local lbRowCount = 0

--pixel heights.
local lbHeaderY = 19
local lbPlayerRowY = 24
local userLbRowCellWidth = 43
local lbwidth = 0

--descriptors used for user-LB rows for which the later ones, updates come up from server.
type lbUserCellDescriptorType = { name: string, num: number, width: number, userFacingName: string, tooltip: string }

--use num to artificially keep them separated
local lbUserCellDescriptors: { lbUserCellDescriptorType } = {
	{ name = "portrait", num = 1, width = lbPlayerRowY, userFacingName = "", tooltip = "" },
	{ name = "username", num = 3, width = 80, userFacingName = "", tooltip = "" },
	{
		name = "awardCount",
		num = 5,
		width = userLbRowCellWidth - 10,
		userFacingName = "awards",
		tooltip = "How many special awards you've earned from contests or other achievements.",
	},
	{
		name = "userTix",
		num = 7,
		width = userLbRowCellWidth,
		userFacingName = "tix",
		tooltip = "How many tix you've earned from your runs and finds and records.",
	},
	{
		name = "userTotalFindCount",
		num = 9,
		width = userLbRowCellWidth,
		userFacingName = "finds",
		tooltip = "How many signs you've found!",
	},
	{
		name = "findRank",
		num = 11,
		width = userLbRowCellWidth,
		userFacingName = "rank",
		tooltip = "Your rank of how many signs you've found.",
	},
	{
		name = "userCompetitiveWRCount",
		num = 13,
		width = userLbRowCellWidth - 8,
		userFacingName = "cwrs",
		tooltip = "How many World Records you hold in competitive races!",
	},
	{
		name = "userTotalWRCount",
		num = 15,
		width = userLbRowCellWidth,
		userFacingName = "wrs",
		tooltip = "How many World Records you hold right now.",
	},
	{
		name = "top10s",
		num = 18,
		width = userLbRowCellWidth,
		userFacingName = "top10s",
		tooltip = "How many of your runs are still in the top10.",
	},
	{
		name = "races",
		num = 23,
		width = userLbRowCellWidth,
		userFacingName = "races",
		tooltip = "How many distinct runs you've done.",
	},
	{
		name = "runs",
		num = 26,
		width = userLbRowCellWidth,
		userFacingName = "runs",
		tooltip = "How many runs you've done in total.",
	},
	{
		name = "badgeCount",
		num = 31,
		width = userLbRowCellWidth,
		userFacingName = "badges",
		tooltip = "Total game badges you have won.",
	},
}

--cells which need updating in a user-lb-row.

local function resetLbHeight(): nil
	lbframe.Size = UDim2.new(0, lbwidth, 0, lbHeaderY + lbPlayerRowY * lbRowCount)
end

--setup header row as first row in lbframe
--call once per character creation - the outer frame which has rows added/removed from it.
local function makeLBHeaderRowFrame(): Frame
	local headerFrame = Instance.new("Frame")
	headerFrame.Parent = lbframe
	headerFrame.BorderMode = Enum.BorderMode.Inset
	headerFrame.BorderSizePixel = 0
	headerFrame.Name = "00000000-lb-headerframe"
	headerFrame.Size = UDim2.new(1, 0, 0, lbHeaderY)
	headerFrame.BackgroundTransparency = 1
	local uu = Instance.new("UIListLayout")
	uu.FillDirection = Enum.FillDirection.Horizontal
	uu.Parent = headerFrame

	--create initial tiles for top of LB
	for _, lbUserCellDescriptor: lbUserCellDescriptorType in pairs(lbUserCellDescriptors) do
		local el = guiUtil.getTl(
			string.format("%02d.header.%s", lbUserCellDescriptor.num, lbUserCellDescriptor.userFacingName),
			UDim2.new(0, lbUserCellDescriptor.width, 1, 0),
			2,
			headerFrame,
			colors.defaultGrey,
			0
		)
		if lbUserCellDescriptor.tooltip ~= "" then
			toolTip.setupToolTip(localPlayer, el, lbUserCellDescriptor.tooltip, UDim2.fromOffset(300, 40), false)
		end
		el.Text = lbUserCellDescriptor.userFacingName
		el.ZIndex = lbUserCellDescriptor.num
		el.TextXAlignment = Enum.TextXAlignment.Center
		el.TextYAlignment = Enum.TextYAlignment.Center
		-- if lbUserCellDescriptor.name == "portrait" or lbUserCellDescriptor.name == "username" then
		el.BackgroundTransparency = 1
		el.Parent.BackgroundTransparency = 1
		-- end
	end
	return headerFrame
end

--problem: we also need to artificially trigger a user 'rejoin' to do this right.
--this basically works, except if you toggle the setting we do not know to re-send/reload in-server players.
local function completelyResetUserLB()
	--make initial row only. then as things happen (people join, or updates come in, apply them in-place)

	local pgui: PlayerGui = PlayersService.LocalPlayer:WaitForChild("PlayerGui")
	local oldLbSgui: ScreenGui? = pgui:FindFirstChild("LeaderboardScreenGui")
	if oldLbSgui ~= nil then
		oldLbSgui:Destroy()
	end
	if not lbIsEnabled then
		annotate("reset lb and it's disabled now so just end.")
		return
	end
	local lbSgui: ScreenGui = Instance.new("ScreenGui")
	lbSgui.Name = "LeaderboardScreenGui"
	lbSgui.Parent = pgui
	lbframe = Instance.new("Frame")
	lbframe.BorderMode = Enum.BorderMode.Inset
	lbframe.BorderSizePixel = 0
	lbframe.Parent = lbSgui
	lbframe.Size = UDim2.new(0, 0.2, 0, 0)
	lbframe.Position = UDim2.new(1, -1 * lbwidth - 3, 0, -36)
	lbframe.Name = "LeaderboardFrame"
	lbframe.BackgroundTransparency = 1
	local uu = Instance.new("UIListLayout")
	uu.FillDirection = Enum.FillDirection.Vertical
	uu.Name = "lbUIListLayout"
	uu.Parent = lbframe
	uu.HorizontalAlignment = Enum.HorizontalAlignment.Right

	lbRowCount = 0
	resetLbHeight()

	local headerFrame = makeLBHeaderRowFrame()
	headerFrame.Parent = lbframe

	leaderboardButtons.initActionButtons(lbframe, localPlayer)

	marathonClient.ReInitActiveMarathons()
end

--important to use all lbUserCellParams here to make the row complete
--even if an update comes before the initial loading of full stats.

local lbadderUserIdDebounce = {}
local function addUserToLB(userId: number): rowFrameType?
	if lbadderUserIdDebounce[userId] then
		return
	end
	lbadderUserIdDebounce[userId] = true
	local rowplayer = PlayersService:GetPlayerByUserId(userId)
	if rowplayer == nil then
		return nil
	end

	local rowFrame: rowFrameType = { frame = Instance.new("Frame") }
	local userDataFromCache = lbUserData[userId]
	--we need this to get ordering before tix are known.
	if userDataFromCache.userTix == nil then
		userDataFromCache.userTix = 0
	end

	local ut: number = userDataFromCache.userTix :: number
	assert(ut)
	rowFrame.frame.Name = tostring((bignum - ut) .. rowplayer.Name)
	rowFrame.frame.Size = UDim2.new(1, 0, 0, lbPlayerRowY)
	rowFrame.frame.BorderMode = Enum.BorderMode.Inset
	rowFrame.frame.BorderSizePixel = 0
	rowFrame.frame.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Parent = rowFrame.frame
	rowFrame.frame.Parent = lbframe
	local bgcolor = colors.grey
	if userId == localPlayer.UserId then
		bgcolor = colors.meColor
	end

	for _, lbUserCellDescriptor: lbUserCellDescriptorType in pairs(lbUserCellDescriptors) do
		if lbUserCellDescriptor.name == "portrait" then
			local img = Instance.new("ImageLabel")
			img.Size = UDim2.new(0, lbUserCellDescriptor.width, 1, 0)
			local content = thumbnails.getThumbnailContent(userId, Enum.ThumbnailType.HeadShot)
			img.Image = content
			img.BackgroundColor3 = bgcolor
			img.Name = string.format("%02d.value", lbUserCellDescriptor.num)
			img.Parent = rowFrame.frame
			img.BorderMode = Enum.BorderMode.Outline

			if false then --disabled user thumbnail mouseover TODO
				local content2 = thumbnails.getThumbnailContent(userId, Enum.ThumbnailType.HeadShot, 256, 256)
				local innerImg = Instance.new("ImageLabel")
				innerImg.Size = UDim2.new(1, 0, 1, 0)
				innerImg.Image = content2
				innerImg.BackgroundColor3 = bgcolor
				innerImg.Name = string.format("%02d.inner.bigImg", lbUserCellDescriptor.num)
				toolTip.setupToolTip(localPlayer, img, innerImg, UDim2.fromOffset(200, 200), true)
			end
			img.BackgroundTransparency = lbEnums.lbTransparency
			img.BorderSizePixel = 0
		else --it's a textlabel whatever we're generating anyway.
			local tl = guiUtil.getTl(
				string.format("%02d.value", lbUserCellDescriptor.num),
				UDim2.new(0, lbUserCellDescriptor.width - 3, 1, 0),
				2,
				rowFrame.frame,
				bgcolor,
				0
			)
			if lbUserCellDescriptor.num < 31 then
				local placeholderTl = guiUtil.getTl(
					string.format("%02d.value", lbUserCellDescriptor.num + 1),
					UDim2.new(0, 1, 1, 0),
					0,
					rowFrame.frame,
					colors.defaultGrey,
					0
				)
				placeholderTl.Text = ""
				placeholderTl.BackgroundTransparency = 1
				placeholderTl.Parent.BackgroundTransparency = lbEnums.lbTransparency
			end

			--find text for initial value.
			--note that depending on what the user does first, userDataFromCache may have missing values.
			if lbUserCellDescriptor.name == "findRank" then
				local rr = userDataFromCache.findRank
				if rr ~= nil then
					tl.Text = tpUtil.getCardinal(rr)
				end
			elseif lbUserCellDescriptor.name == "username" then
				tl.Text = rowplayer.Name
			elseif lbUserCellDescriptor.name == "badges" then
				tl.Text = "..."
			else
				local candidateTextValue = userDataFromCache[lbUserCellDescriptor.name]

				local textValue: string
				if candidateTextValue == nil then
					textValue = ""
				else
					textValue = tostring(candidateTextValue)
				end
				tl.Text = textValue
			end
			tl.BackgroundTransparency = 1
			tl.Parent.BackgroundTransparency = lbEnums.lbTransparency
		end
	end
	lbadderUserIdDebounce[userId] = true
	return rowFrame
end

--after receiving an lb update, figure out what changed relative to known data
--store it and return a userDataChange for rendering into the LB
local function storeUserData(userId: number, data: userData): { userDataChange }
	local res: { userDataChange } = {}
	if lbUserData[userId] == nil then --received new data.
		lbUserData[userId] = {}
	end
	for key: string, newValue in pairs(data) do
		if newValue == nil then
			--don't know why this would happen, probably impossible.
			warn("no newvalue " .. key)
			continue
		end
		local oldValue = lbUserData[userId][key]

		--if oldvalue is nil then we DO do this.

		--what if ov shows up nil?
		--how to distinguish between "0 you should show" and "0 that is no diff?")
		if newValue ~= oldValue then
			--reset source of truth to the new data that came in.
			local change: userDataChange = { key = key, oldValue = oldValue, newValue = newValue }
			lbUserData[userId][key] = newValue
			table.insert(res, change)
		end
	end
	return res
end

--1.
--q: what happens if you receive multiple of these at the same time? how to debounce this?
--a: just let it happen. most significant ones won't collide.
local function receivedLBUpdateForUser(userData: userData, initial: boolean): nil
	if not lbIsEnabled then
		return
	end
	local userId = userData.userId
	--check if this client's user has any lbframe.
	if userId == nil then
		warn("nil userid for update. initial: " .. tostring(initial))
		warn(userData)
		return
	end

	if lbframe == nil then
		completelyResetUserLB()
	elseif lbframe.Parent == nil then
		completelyResetUserLB()
	end

	--first check if there is anything worthwhile to draw - anything changed.

	local userDataChanges = storeUserData(userId, userData)
	if userDataChanges == {} then
		warn("redrawUserLBRow.die since not different for target: " .. userId)
		return
	end

	--patch things up if needed.
	local rowFrame: rowFrameType = userId2rowframe[userId]
	if rowFrame == nil or rowFrame.frame.Parent == nil then
		if rowFrame == nil then
		else
			rowFrame.frame:Destroy()
		end
		userId2rowframe[userId] = nil
		local candidateRowFrame = addUserToLB(userId)
		if candidateRowFrame == nil then --case when the user is gone already.
			return
		end
		rowFrame = candidateRowFrame :: rowFrameType
		lbRowCount = lbRowCount + 1
		resetLbHeight()
		userId2rowframe[userId] = candidateRowFrame :: rowFrameType
		rowFrame.frame.Parent = lbframe
	end

	local bgcolor = colors.grey
	if userId == localPlayer.UserId then
		bgcolor = colors.meColor
	end

	for _, change in pairs(userDataChanges) do
		-- find the userCellDescriptor corresponding to it.

		local descriptor = nil
		for _, lbUserCellDescriptor in ipairs(lbUserCellDescriptors) do
			if lbUserCellDescriptor.name == change.key then
				descriptor = lbUserCellDescriptor
				break
			end
		end

		--if we receive a tix update, update rowframe.
		if change.key == "userTix" then
			local newName = tostring(bignum - change.newValue) .. localPlayer.Name
			rowFrame.frame.Name = newName
		end

		--if no descriptor, quit. effectively the same as name doesn't appear in: updateUserLbRowKeys
		--note: this can happen because lbupdates have full BE stats in them, not all of which we render into LB
		if descriptor == nil then
			continue
		end

		local targetName = string.format("%02d.value", descriptor.num)
		--it's important this targetname matches via interpolatino
		local oldTextLabel: TextLabel = rowFrame.frame:FindFirstChild(targetName) :: TextLabel
		if oldTextLabel == nil then
			warn("Missing old label to put in - this should not happen " .. descriptor.num)
			warn(descriptor)
		end
		if oldTextLabel ~= nil then
			oldTextLabel:Destroy()
		end

		--if this exists, do green fade
		local newIntermediateText: string? = nil

		--what do we have to do.
		--we have old number and new number.
		--if not findRank, calculate the intermediate text a nd set up greenfade.
		--and in either case, do a green fade.
		local newFinalText = tostring(change.newValue)
		if descriptor.name == "findRank" then
			newFinalText = tpUtil.getCardinal(change.newValue)
		end

		local improvement = false

		--oldValue may be nil indicating nothing known.
		if change.oldValue and not initial then
			local gap = change.newValue - change.oldValue
			local sign = ""
			if gap > 0 then
				improvement = true
				sign = "+"
			end
			--findrank (rank decrease) is always semantically positive
			if change.key == "findRank" then
				improvement = true
				sign = "+"
			end
			if gap ~= 0 then
				newIntermediateText = newFinalText .. "\n(" .. sign .. gap .. ")"
			end
		end

		local newTL = guiUtil.getTl(
			string.format("%02d.value", descriptor.num),
			UDim2.new(0, descriptor.width, 1, 0),
			2,
			rowFrame.frame,
			bgcolor,
			0
		)

		newTL.BackgroundTransparency = 1
		newTL.Parent.BackgroundTransparency = lbEnums.lbTransparency

		--phase to new color if needed
		if newIntermediateText == nil then
			newTL.Text = newFinalText
			newTL.BackgroundColor3 = bgcolor
		else
			if improvement then
				newTL.BackgroundColor3 = colors.greenGo
			else
				newTL.BackgroundColor3 = colors.lightRed
			end
			newTL.Text = newIntermediateText
			spawn(function()
				wait(enums.greenTime)
				newTL.Text = newFinalText
			end)
			local Tween = TweenService:Create(newTL, TweenInfo.new(enums.greenTime), { BackgroundColor3 = bgcolor })
			Tween:Play()
			local Tween2 =
				TweenService:Create(newTL.Parent, TweenInfo.new(enums.greenTime), { BackgroundColor3 = bgcolor })
			Tween2:Play()
		end
	end
	-- annotate("redrawUserLBRow.end")
end

local function removeUserLBRow(userId: number)
	if not lbIsEnabled then
		return
	end
	local row: rowFrameType = userId2rowframe[userId]
	userId2rowframe[userId] = nil
	lbUserData[userId] = nil
	if row ~= nil then
		row.frame:Destroy()
		lbRowCount = lbRowCount - 1
	end
	resetLbHeight()
end

--data is a list of kvs for update data. if any change, redraw the row (and highlight that cell.)
--initially keyed to receive data about a userId. But later overloading data to just be blobs  of things of specific types to display in leaderboard.
local function clientReceiveNewLeaderboardData(userData: userData)
	userData.userId = tonumber(userData.userId)

	if userData.kind == "leave" then
		lbUserData[userData.userId] = nil
		removeUserLBRow(userData.userId)
		return
	end

	--figure out if this is an initial update
	local initial = false
	if
		userData.kind == "update other about joiner"
		or userData.kind == "update joiner lb"
		or userData.kind == "joiner update other lb"
	then
		initial = true
	end

	receivedLBUpdateForUser(userData, initial)
end

--user changed marathon settings in UI - uses registration to monitor it.
--note there is an init call here so user initial settings _will_ show up here and we should
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
local function handleMarathonSettingsChanged(setting: tt.userSettingValue)
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

local function init()
	game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)

	for _, lbUserCellDescriptor in pairs(lbUserCellDescriptors) do
		lbwidth = lbwidth + lbUserCellDescriptor.width
	end
	local localFunctions = require(game.ReplicatedStorage.localFunctions)
	local hideLb = localFunctions.getSettingByName(settingEnums.settingNames.HIDE_LEADERBOARD)
	if hideLb.value then
		lbIsEnabled = false
	else
		lbIsEnabled = true
	end

	localFunctions.registerLocalSettingChangeReceiver(function(item: tt.userSettingValue): any
		return handleUserSettingChanged(item)
	end, "leaderboardSettingListener")

	localFunctions.registerLocalSettingChangeReceiver(function(item: tt.userSettingValue): any
		return handleMarathonSettingsChanged(item)
	end, "handleMarathonSettingsChanged")

	completelyResetUserLB()

	--we setup the event, but what if upstream playerjoinfunc is called first?
	local leaderboardUpdateEvent = remotes.getRemoteEvent("LeaderboardUpdateEvent")
	leaderboardUpdateEvent.OnClientEvent:Connect(clientReceiveNewLeaderboardData)

	--listen to racestart, raceendevent

	marathonClient.Init()
	local initialMarathonSettings = localFunctions.getSettingByDomain(settingEnums.settingDomains.MARATHONS)

	--load marathons according to the users settings
	for _, userSetting in pairs(initialMarathonSettings) do
		handleMarathonSettingsChanged(userSetting)
	end

	local userSettings = localFunctions.getSettingByDomain(settingEnums.settingDomains.USERSETTINGS)

	for _, userSetting in pairs(userSettings) do
		handleUserSettingChanged(userSetting)
	end
end

init()
