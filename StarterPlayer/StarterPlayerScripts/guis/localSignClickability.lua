--!strict

-- localSignClickability.lua
-- Displays sign click popup UI with WR leader info and related races.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayersService = game:GetService("Players")

local colors = require(game.ReplicatedStorage.util.colors)
local enums = require(game.ReplicatedStorage.util.enums)
local emojis = require(game.ReplicatedStorage.enums.emojis)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local localRdb = require(game.ReplicatedStorage.localRdb)
local remotes = require(game.ReplicatedStorage.util.remotes)
local thumbnails = require(game.ReplicatedStorage.thumbnails)
local tpUtil: typeof(require(game.ReplicatedStorage.util.tpUtil)) = require(game.ReplicatedStorage.util.tpUtil)
local tt = require(game.ReplicatedStorage.types.gametypes)

local module = {}

-- Configuration constants
local BILLBOARD_WIDTH = 1000 -- pixels
local BILLBOARD_HEIGHT = 300 -- pixels
local BILLBOARD_MAX_DISTANCE = 50 -- studs before billboard fades
local CLICK_DETECTOR_DISTANCE = 40 -- studs for click activation
local AUTO_DISMISS_DISTANCE = 30 -- studs before popup auto-closes
local AUTO_DISMISS_CHECK_INTERVAL = 1 -- seconds

-- Player mode constants (what to show about the user's relationship to a race)
local YOULEAD = 1
local YOUPLACE = 2
local YOURAN = 3
local YOUNEVERRAN = 4

local localPlayer = PlayersService.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local ClickSignFunction = remotes.getRemoteFunction("ClickSignFunction")

-- Module state
local toggledOnSigns: { [number]: boolean } = {}
local signSetupStatus: { [string]: boolean } = {}

-- Sign item kind properties: color and display text
-- Using Color3 values directly from colors module
type KindProperties = { color: Color3, text: string }
local kindProperties: { [string]: KindProperties } = {
	nearestGlobalUnrun = { color = colors.warpColor, text = "Nobody ran" },
	MiddistGlobalUnrun = { color = colors.warpColor, text = "Nobody ran" },
	nearestPersonalUnrun = { color = colors.warpColor, text = "You never ran" },
	interesting = { color = colors.defaultGrey, text = "" },
	nearest = { color = colors.defaultGrey, text = "" },
	popular = { color = colors.warpColor, text = "Popular" },
	linked = { color = colors.warpColor, text = "Linked" },
}

local function getKindProperties(signItem: any): KindProperties
	if not signItem then
		annotater.Error("getKindProperties: nil signItem")
		return { color = colors.defaultGrey, text = "" }
	end
	local props = kindProperties[signItem.kind]
	if not props then
		annotater.Error(string.format("getKindProperties: unhandled kind '%s'", tostring(signItem.kind)))
		return { color = colors.defaultGrey, text = "" }
	end
	return props
end

local function generateRowForRelatedSign(sign: any, ct: number, youlead: boolean, yscale: number)
	local row = Instance.new("Frame")
	row.BorderMode = Enum.BorderMode.Inset
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, 0, yscale, 0)

	row.Name = string.format("%02d signRow", ct)
	local hh = Instance.new("UIListLayout")
	hh.FillDirection = Enum.FillDirection.Horizontal
	hh.Parent = row

	if sign.best_username == nil or sign.best_username == "" then
		-- No leader at all for this race
		local kindProps = getKindProperties(sign)
		local signNameLabel = guiUtil.getTl("01-signTile", UDim2.new(0.35, 0, 1, 0), 2, row, colors.signColor, 1)
		signNameLabel.Text = tpUtil.signId2signName(sign.signId)
		signNameLabel.TextColor3 = colors.signTextColor

		local statusLabel = guiUtil.getTl("03-nobody-ran", UDim2.new(0.35, 0, 1, 0), 2, row, kindProps.color, 1)
		statusLabel.Text = if #kindProps.text > 0 then kindProps.text else "Nobody ran"

		local distLabel = guiUtil.getTl("02nearsign-dist", UDim2.new(0.3, 0, 1, 0), 1, row, colors.defaultGrey, 1)
		distLabel.Text = string.format("%.0fd", sign.dist)
		return row
	end

	local tt = guiUtil.getTl("01-signname", UDim2.new(0.35, 0, 1, 0), 1, row, colors.signColor, 1)
	tt.Text = tpUtil.signId2signName(sign.signId)
	tt.TextColor3 = colors.signTextColor

	local timeSquare = Instance.new("Frame")
	timeSquare.BorderMode = Enum.BorderMode.Inset
	timeSquare.BorderSizePixel = 0
	timeSquare.Parent = row
	timeSquare.Size = UDim2.new(0.18, 0, 1, 0)
	timeSquare.Name = "03-timesquare"
	local hhv = Instance.new("UIListLayout")
	hhv.FillDirection = Enum.FillDirection.Vertical
	hhv.Parent = timeSquare

	--situations
	--never run - taken care of above, taking over whole row.

	local mode
	if youlead then
		mode = YOULEAD
	else
		if sign.your_place == nil then
			mode = YOUNEVERRAN
		else
			if sign.your_place == 0 then
				mode = YOURAN
			else
				mode = YOUPLACE
			end
		end
	end

	local includeLeadTime = false
	local includeYourTime = false
	local includeYourPlace = false
	local cells = 0
	if mode == YOULEAD then
		includeLeadTime = true
		cells = 1
	end
	if mode == YOUPLACE then
		includeLeadTime = true
		includeYourTime = true
		includeYourPlace = true
		cells = 2
	end
	if mode == YOURAN then
		includeLeadTime = true
		includeYourTime = true
		cells = 2
	end
	if mode == YOUNEVERRAN then
		includeLeadTime = true
		cells = 1
	end

	if includeLeadTime then
		--leadertime
		local leaderTimeSize = 1 / cells
		local useColor = colors.defaultGrey
		if youlead then
			useColor = colors.meColor
		end
		local lt =
			guiUtil.getTl("1-leadtime-timesquare", UDim2.new(1, 0, leaderTimeSize, 0), 1, timeSquare, useColor, 1)
		if sign.best_timems then
			lt.Text = tpUtil.fmtShort(sign.best_timems)
		end
	end
	if includeYourTime then
		local placeTime = 1 / cells
		local yt =
			guiUtil.getTl("2-yourtime-timesquare", UDim2.new(1, 0, placeTime, 0), 1, timeSquare, colors.meColor, 1)

		yt.Text = tpUtil.fmtShort(sign.your_timems)

		if includeYourPlace then
			if sign.your_place then
				if sign.your_place == 0 then
					yt.Text = yt.Text .. " " .. "11th+"
				else
					yt.Text = yt.Text .. " " .. tpUtil.getCardinalEmoji(sign.your_place)
				end
			end
		end
	end

	local im = Instance.new("ImageLabel")
	im.BorderMode = Enum.BorderMode.Inset
	im.Parent = row
	im.Size = UDim2.new(0.12, 0, 1, 0)
	im.Name = "02-image"
	if sign.best_userId then
		local content2 = thumbnails.getThumbnailContent(
			sign.best_userId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size420x420
		)
		im.Image = content2
	end
	if youlead then
		im.BackgroundColor3 = colors.meColor
	end

	-- Leader name and kind description
	local kindProps = getKindProperties(sign)
	local useColor = kindProps.color
	local useText = ""
	if sign.best_username then
		useText = sign.best_username
		if youlead then
			useColor = colors.meColor
		end
		if sign.kind == "personalUnrun" then
			useText = useText .. "\nyou never ran"
		end
		if #kindProps.text > 0 then
			useText = useText .. "\n" .. kindProps.text
		end
	end
	local descriptionLabel = guiUtil.getTl("04-description", UDim2.new(0.35, 0, 1, 0), 1, row, useColor, 1)
	descriptionLabel.Text = useText

	return row
end

local function addUsernames(chunks)
	for _, chunk in ipairs(chunks) do
		if chunk == nil then
			continue
		end
		for __, el in ipairs(chunk) do
			if el == nil then
				continue
			end
			local candidateUserId = el.best_userId or el.userId
			if candidateUserId == nil then
				continue
			else
				local actualUsername = localRdb.GetUsernameByUserId(candidateUserId)

				if el.best_userId == nil then
					el.username = actualUsername
				else
					el.best_username = actualUsername
				end
			end
		end
	end
end

local function DisplaySignRelatedData(signRelatedData: any, sign: Instance)
	local leaderdata = signRelatedData.signWRLeaderData.ordered_tops
	local nearestdata = signRelatedData.relatedSignData.nearest
	local scopeddata = signRelatedData.relatedSignData.scoped
	local interestingdata = signRelatedData.relatedSignData.interesting

	addUsernames({ leaderdata, nearestdata, interestingdata, scopeddata }) --ClickSignFunction

	-- Set up billboard GUI and main frame
	local bbg = Instance.new("BillboardGui")
	bbg.Parent = sign
	bbg.Name = "LeaderGuiFrame"
	bbg.Active = true
	bbg.Adornee = sign
	bbg.MaxDistance = BILLBOARD_MAX_DISTANCE
	bbg.AlwaysOnTop = true
	bbg.Size = UDim2.new(0, BILLBOARD_WIDTH, 0, BILLBOARD_HEIGHT)
	bbg.StudsOffset = Vector3.new(0, 10, 0)

	local mainFrame = Instance.new("Frame")
	mainFrame.BorderMode = Enum.BorderMode.Inset
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = bbg
	mainFrame.Size = UDim2.new(1, 0, 1, 0)
	mainFrame.Name = "MainFrame"
	local ll = Instance.new("UIListLayout")
	ll.FillDirection = Enum.FillDirection.Horizontal
	ll.Parent = mainFrame

	local leftFrame = Instance.new("Frame")
	leftFrame.BorderMode = Enum.BorderMode.Inset
	leftFrame.BorderSizePixel = 0
	leftFrame.Parent = mainFrame
	leftFrame.Size = UDim2.new(0.15, 0, 1, 0)
	leftFrame.Name = "01-left-leader"
	local vv = Instance.new("UIListLayout")
	vv.Parent = leftFrame
	vv.Name = "vv"
	vv.SortOrder = Enum.SortOrder.Name
	vv.FillDirection = Enum.FillDirection.Vertical
	------display leader

	if leaderdata == nil or #leaderdata == 0 then
		return bbg
	else
		local leader = leaderdata[1]
		local wrRelatedBgColor = colors.grey
		-- LocalPlayer is guaranteed to exist in a LocalScript
		if leader.userId and localPlayer.UserId == leader.userId then
			wrRelatedBgColor = colors.meColor
		end

		--header
		local header =
			guiUtil.getTl("01-leader-announcement", UDim2.new(1, 0, 0.1, 0), 1, leftFrame, wrRelatedBgColor, 1)
		header.Text = "WR Leader" .. emojis.emojis.CROWN

		--signname+wrcount
		local ff = Instance.new("Frame")
		ff.BorderMode = Enum.BorderMode.Inset
		ff.BorderSizePixel = 0
		ff.Parent = leftFrame
		ff.Name = "02-leaderline"
		ff.Size = UDim2.new(1, 0, 0.1, 0)

		local hh = Instance.new("UIListLayout")
		hh.Parent = ff
		hh.Name = "hh"
		hh.SortOrder = Enum.SortOrder.Name
		hh.FillDirection = Enum.FillDirection.Horizontal

		local name = guiUtil.getTl("01-LeaderLine", UDim2.new(0.5, 0, 1, 0), 1, ff, wrRelatedBgColor, 1)
		name.Text = leader.count .. " WRs"

		local name2 = guiUtil.getTl("02-LeaderLine", UDim2.new(0.5, 0, 1, 0), 1, ff, colors.signColor, 1)
		name2.Text = sign.Name
		name2.TextColor3 = colors.signTextColor

		local header2 = guiUtil.getTl("03-leader-username", UDim2.new(1, 0, 0.1, 0), 1, leftFrame, wrRelatedBgColor, 1)
		header2.Text = leader.username

		local img = Instance.new("ImageLabel")
		img.BorderMode = Enum.BorderMode.Inset
		img.Parent = leftFrame
		img.Size = UDim2.new(1, 0, 0.7, 0)
		--later make this user-scoped.
		local content =
			thumbnails.getThumbnailContent(leader.userId, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size420x420)
		img.Position = UDim2.new(0, 0, 0.3, 0)
		img.Image = content
		img.Name = "04image."
		img.BackgroundColor3 = wrRelatedBgColor
	end

	--right, others section
	local otherLeadersSecondFrame = Instance.new("Frame")
	otherLeadersSecondFrame.BorderMode = Enum.BorderMode.Inset
	otherLeadersSecondFrame.BorderSizePixel = 0
	otherLeadersSecondFrame.Name = "02-middle"
	otherLeadersSecondFrame.Parent = mainFrame
	otherLeadersSecondFrame.Size = UDim2.new(0.15, 0, 1, 0)
	local vert = Instance.new("UIListLayout")
	vert.Parent = otherLeadersSecondFrame
	vert.VerticalAlignment = Enum.VerticalAlignment.Top
	vert.FillDirection = Enum.FillDirection.Vertical

	if leaderdata ~= nil then
		local rightRowCount = #leaderdata - 1
		local rightScaleY = 1.0 / rightRowCount
		local rank = 1
		for index, el in ipairs(leaderdata) do
			if index == 1 then
				continue
			end
			if el == nil then
				warn("nill")
				continue
			end
			rank = rank + 1
			local leaderRowFrame = Instance.new("Frame")
			leaderRowFrame.BorderMode = Enum.BorderMode.Inset
			leaderRowFrame.BorderSizePixel = 0
			leaderRowFrame.Name = string.format("%02dframe-%s", rank, el.username)
			leaderRowFrame.Size = UDim2.new(1, 0, rightScaleY, 0)
			leaderRowFrame.Parent = otherLeadersSecondFrame
			local layout2 = Instance.new("UIListLayout")
			layout2.FillDirection = Enum.FillDirection.Horizontal
			layout2.Parent = leaderRowFrame

			--headshot icon
			local img2 = Instance.new("ImageLabel")
			img2.BorderMode = Enum.BorderMode.Inset
			img2.Size = UDim2.new(0.15, 0, 1, 0)
			--later make this user-scoped.
			local content2 =
				thumbnails.getThumbnailContent(el.userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
			img2.Image = content2
			img2.Parent = leaderRowFrame
			img2.Name = "2"
			if localPlayer.UserId == el.userId then
				img2.BackgroundColor3 = colors.meColor
			end

			local useColor = colors.defaultGrey
			if localPlayer.UserId == el.userId then
				useColor = colors.meColor
			end
			local wrHeader = guiUtil.getTl("1", UDim2.new(0.10, 0, 1, 0), 1, leaderRowFrame, useColor, 1)
			wrHeader.TextXAlignment = Enum.TextXAlignment.Center
			wrHeader.TextYAlignment = Enum.TextYAlignment.Center
			wrHeader.Text = el.count

			local yourUseColor = colors.defaultGrey
			if localPlayer.UserId == el.userId then
				yourUseColor = colors.meColor
			end
			local yourHeader = guiUtil.getTl("3", UDim2.new(0.75, 0, 1, 0), 1, leaderRowFrame, yourUseColor, 1)
			yourHeader.TextXAlignment = Enum.TextXAlignment.Center
			yourHeader.TextYAlignment = Enum.TextYAlignment.Center
			yourHeader.Text = el.username
		end
	end

	--panel 3 and 4
	local datasets = { nearestdata, scopeddata, interestingdata }
	local descriptions = { "Nearby races", "Scoped races", "Related races" }

	for ii, dataset in ipairs(datasets) do
		if dataset == nil or #dataset == 0 then
			continue
		end
		local yscale = 1 / (#dataset + 1)
		local rightFrame = Instance.new("Frame")
		rightFrame.BorderMode = Enum.BorderMode.Inset
		rightFrame.BorderSizePixel = 0
		rightFrame.Parent = mainFrame
		rightFrame.Size = UDim2.new((1 - 0.3) / #datasets, 0, 1, 0)
		rightFrame.Name = tostring(03 + ii) .. "-right-" .. descriptions[ii]

		local rightLayout = Instance.new("UIListLayout")
		rightLayout.FillDirection = Enum.FillDirection.Vertical
		rightLayout.Parent = rightFrame
		local tl = guiUtil.getTl("0", UDim2.new(1, 0, yscale, 0), 1, rightFrame, colors.blueDone, 1)
		tl.Text = descriptions[ii]

		local ct = 0

		for _, signToDisplay in pairs(dataset) do
			ct = ct + 1
			local youlead = false

			if signToDisplay.best_userId == localPlayer.UserId then
				youlead = true
			end
			local myct = ct
			task.spawn(function()
				local s, e = pcall(function()
					local row = generateRowForRelatedSign(signToDisplay, myct, youlead, yscale)
					row.Parent = rightFrame
				end)
				if not s then
					annotater.Error("failed to generate row for related sign" .. e, signToDisplay)
				end
			end)
		end
	end

	return bbg
end

local function rightClickSign(signId, sign)
	local signClickMessage: tt.signClickMessage =
		{ leftClick = false, signId = signId, userId = localPlayer.UserId }
	ClickSignFunction:InvokeServer(signClickMessage)
end

local function leftClickSign(signId: number, sign: Part)
	if toggledOnSigns[signId] == true then
		toggledOnSigns[signId] = false
		local gg = sign:FindFirstChild("LeaderGuiFrame")
		if gg == nil then
			return
		end
		gg:Destroy()
		return
	end
	--also destroy it here.
	local gg = sign:FindFirstChild("LeaderGuiFrame")
	if gg ~= nil then
		gg:Destroy()
	end

	local signClickMessage: tt.signClickMessage =
		{ leftClick = true, signId = signId, userId = localPlayer.UserId }
	local signRelatedData = ClickSignFunction:InvokeServer(signClickMessage)
	DisplaySignRelatedData(signRelatedData, sign)

	toggledOnSigns[signId] = true

	task.spawn(function()
		while true do
			-- Check if we've been reset
			if not toggledOnSigns[signId] then
				local gg = sign:FindFirstChild("LeaderGuiFrame")
				if gg ~= nil then
					gg:Destroy()
				end
				break
			end

			local char = localPlayer.Character
			if not char or not char.PrimaryPart then
				break
			end

			local dist = tpUtil.getDist(sign.Position, char.PrimaryPart.Position)

			if dist > AUTO_DISMISS_DISTANCE then
				local existingGui = sign:FindFirstChild("LeaderGuiFrame")
				if existingGui then
					existingGui:Destroy()
				end
				toggledOnSigns[signId] = false
				break
			end
			task.wait(AUTO_DISMISS_CHECK_INTERVAL)
		end
	end)
end

--2022 signs stream in as you move around, so need to run this periodically.
--2022 POST streaming enabled disablement is that true?
local function SetupSigns()
	--when the response from the click with data to display comes back.
	--set up each sign to be clickable by this user individually.
	for _, signInstance in ipairs(game.Workspace:WaitForChild("Signs"):GetChildren()) do
		local sign = signInstance :: Part
		if signSetupStatus[sign.Name] then
			continue
		end

		-- Skip disabled signs - they are not clickable
		if enums.disabledSignNames[sign.Name:lower()] then
			signSetupStatus[sign.Name] = true
			continue
		end

		local surfacegui = Instance.new("SurfaceGui")
		surfacegui.Parent = playerGui
		surfacegui.Adornee = sign
		surfacegui.Name = "clickSg" .. sign.Name

		local cd = Instance.new("ClickDetector")
		local signId = tpUtil.looseSignName2SignId(sign.Name)
		if not signId then
			continue
		end
		cd.MaxActivationDistance = CLICK_DETECTOR_DISTANCE
		cd.Parent = sign
		cd.Name = sign.Name .. tostring(signId)

		cd.MouseClick:Connect(function(_e)
			return leftClickSign(signId, sign)
		end)
		cd.RightMouseClick:Connect(function(_e)
			return rightClickSign(signId, sign)
		end)
		signSetupStatus[sign.Name] = true
	end
end


module.Reset = function()
	_annotate("Resetting localSignClickability UIs")
	local signsFolder = game.Workspace:FindFirstChild("Signs")
	if not signsFolder then
		return
	end
	
	for _, sign in ipairs(signsFolder:GetChildren()) do
		-- Clear UI
		local gg = sign:FindFirstChild("LeaderGuiFrame")
		if gg then
			gg:Destroy()
		end
		
		-- Clear ClickDetectors so we can re-bind them
		for _, child in ipairs(sign:GetChildren()) do
			if child:IsA("ClickDetector") then
				child:Destroy()
			end
		end
	end
	toggledOnSigns = {}
	signSetupStatus = {}
end

module.Init = function()
	_annotate("init")
	module.Reset()
	SetupSigns()
	_annotate("init done")
end

_annotate("end")
return module
