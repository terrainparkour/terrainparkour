--!strict

-- leaderboardGui on client
-- drawing the LB rows and managing them

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local TweenService = game:GetService("TweenService")

local colors = require(game.ReplicatedStorage.util.colors)
local enums = require(game.ReplicatedStorage.util.enums)
local leaderboardEnums = require(game.StarterPlayer.StarterPlayerScripts.lb.leaderboardEnums)
local lt = require(game.StarterPlayer.StarterPlayerScripts.lb.leaderboardTypes)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local textUtil = require(game.ReplicatedStorage.util.textUtil)
local tpUtil: typeof(require(game.ReplicatedStorage.util.tpUtil)) = require(game.ReplicatedStorage.util.tpUtil)
local warper = require(game.StarterPlayer.StarterCharacterScripts.client.warper)
local drawFavoritesModal = require(game.ReplicatedStorage.gui.menu.drawFavoritesModal)
local settings = require(game.ReplicatedStorage.settings)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local PlayersService: Players = game:GetService("Players")
local tt = require(game.ReplicatedStorage.types.gametypes)
local badgeButton = require(game.ReplicatedStorage.gui.menu.badgeButton)
local toolTip = require(game.ReplicatedStorage.gui.toolTip)
local remotes = require(game.ReplicatedStorage.util.remotes)
local BadgeProgressFunction = remotes.getRemoteFunction("BadgeProgressFunction") :: RemoteFunction

-- Cache for local player's badge status (badge name -> has badge)
local localPlayerBadgeStatus: { [string]: boolean } = {}
local localPlayerBadgeStatusLoaded = false

-- Fetch local player's badge status asynchronously
task.spawn(function()
	local localPlayer = PlayersService.LocalPlayer
	if not localPlayer then
		return
	end
	local success, result = pcall(function()
		return BadgeProgressFunction:InvokeServer({ localPlayer.UserId }, "leaderboardGui.init")
	end)
	if success and result then
		local playerData = result[localPlayer.UserId] or result[tostring(localPlayer.UserId)]
		if playerData then
			for _, badgeProgress in ipairs(playerData) do
				if badgeProgress.badge and badgeProgress.badge.name then
					localPlayerBadgeStatus[badgeProgress.badge.name] = badgeProgress.got == true
				end
			end
		end
		localPlayerBadgeStatusLoaded = true
		_annotate("Loaded local player badge status")
	end
end)

-- Constants for warp permission feature
local WARP_PERMISSION_OPTIONS = { "none", "robloxFriends", "all" }
local WARP_PERMISSION_LABELS = { none = "off", robloxFriends = "friends", all = "all" }
local MIN_FINDS_FOR_WARP = 100

------------------FUNCTIONS--------------
module.CalculateCellWidths = function(enabledDescriptors: { [string]: boolean }): { [string]: number }
	local totalWidthWeightScale = 0
	local cellWidths: { [string]: number } = {}
	-- we add them up once, then use that for all rows.
	for _, lbUserCellDescriptor in pairs(leaderboardEnums.LbColumnDescriptors) do
		if enabledDescriptors[lbUserCellDescriptor.name] then
			totalWidthWeightScale += lbUserCellDescriptor.widthScaleImportance
		end
	end
	for _, lbUserCellDescriptor in pairs(leaderboardEnums.LbColumnDescriptors) do
		if enabledDescriptors[lbUserCellDescriptor.name] then
			cellWidths[lbUserCellDescriptor.name] = lbUserCellDescriptor.widthScaleImportance / totalWidthWeightScale
		end
	end
	_annotate("Cell widths", cellWidths)
	return cellWidths
end

--setup header row as first row in lbframe
module.MakeLeaderboardHeaderRow = function(enabledDescriptors: { [string]: boolean }, headerRowYOffsetFixed): Frame
	local headerRow = Instance.new("Frame")
	headerRow.BorderMode = Enum.BorderMode.Inset
	headerRow.BorderSizePixel = 0
	headerRow.Name = "LeaderboardHeaderRow"
	headerRow.Size = UDim2.new(1, -2, 0, math.min(headerRowYOffsetFixed, 80))
	headerRow.BackgroundColor3 = colors.blueDone
	headerRow.BackgroundTransparency = 0.2

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Horizontal
	listLayout.Name = "HeaderRow-hh"
	listLayout.Parent = headerRow

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = headerRow

	local cellWidths = module.CalculateCellWidths(enabledDescriptors)

	for _, lbUserCellDescriptor: lt.lbColumnDescriptor in pairs(leaderboardEnums.LbColumnDescriptors) do
		if not enabledDescriptors[lbUserCellDescriptor.name] then
			continue
		end
		local thisCellScale = cellWidths[lbUserCellDescriptor.name]

		-- Use TextButton (getPaddedButton) instead of TextLabel (getTl) so header cells are clickable for sorting
		local elb = guiUtil.getPaddedButton(
			string.format("%02d.header.%s", lbUserCellDescriptor.num, lbUserCellDescriptor.userFacingName),
			UDim2.fromScale(thisCellScale, 1),
			2, -- padding
			headerRow,
			colors.blueDone, -- Match header row background
			1, -- borderSizePixel
			0 -- transparency
		)
		elb.Text = lbUserCellDescriptor.userFacingName
		elb.ZIndex = lbUserCellDescriptor.num
		elb.TextXAlignment = Enum.TextXAlignment.Center
		elb.TextYAlignment = Enum.TextYAlignment.Center
		elb.AutoButtonColor = false -- Disable auto color change on hover

		-- Set LayoutOrder on the outer element (parent of inner) for proper UIListLayout sorting
		-- Also set border color to match header background so borders are invisible
		-- getPaddedButton returns the inner button; its parent is the outer TextButton
		do
			local parentInstance = elb.Parent
			if parentInstance and parentInstance:IsA("TextButton") then
				local outerButton = parentInstance :: TextButton
				outerButton.LayoutOrder = lbUserCellDescriptor.num
				outerButton.BorderColor3 = colors.blueDone
				outerButton.AutoButtonColor = false
			end
		end

		-- Add text size constraint like the original LLMGenerated code
		local textSizeConstraint = Instance.new("UITextSizeConstraint")
		textSizeConstraint.MaxTextSize = 18
		textSizeConstraint.MinTextSize = 8
		textSizeConstraint.Parent = elb

		local keyHolder = Instance.new("StringValue")
		keyHolder.Name = "key"
		keyHolder.Value = lbUserCellDescriptor.name
		keyHolder.Parent = elb
	end

	-- Adjust UIScale to fit content within 80 pixel height
	local function updateUIScale()
		local contentSize = headerRow.AbsoluteSize
		if contentSize.Y > 80 then
			uiScale.Scale = 80 / contentSize.Y
		else
			uiScale.Scale = 1
		end
	end

	-- Connect the function to the appropriate signals
	headerRow:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateUIScale)
	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateUIScale)

	-- Initial call to set the correct scale
	updateUIScale()

	return headerRow
end

module.DrawRaceWarper = function(rowFrame: Frame | nil, change: tt.leaderboardUserDataChange)
	if rowFrame == nil then
		return
	end

	local oldCell = rowFrame:FindFirstChild("Inner")
	if oldCell then
		oldCell:Destroy()
	end
	local newPinnedRaceRawValue: string = change.newValue :: string

	if newPinnedRaceRawValue == nil or newPinnedRaceRawValue == "" then
		local emptyLabel = guiUtil.getTl("Inner", UDim2.fromScale(1, 1), 2, rowFrame, colors.defaultGrey, 1, 0)
		emptyLabel.Text = ""
		return
	end

	local parts = textUtil.stringSplit(newPinnedRaceRawValue, "-")
	local signId1 = tonumber(parts[1])
	local signId2 = tonumber(parts[2])

	if not signId1 or not signId2 then
		local emptyLabel = guiUtil.getTl("Inner", UDim2.fromScale(1, 1), 2, rowFrame, colors.defaultGrey, 1, 0)
		emptyLabel.Text = ""
		return
	end

	local signName1 = tpUtil.signId2signName(signId1)
	local signName2 = tpUtil.signId2signName(signId2)

	if signName1 == "" or signName2 == "" then
		local emptyLabel = guiUtil.getTl("Inner", UDim2.fromScale(1, 1), 2, rowFrame, colors.defaultGrey, 1, 0)
		emptyLabel.Text = ""
		return
	end

	local innerFrame = guiUtil.getTl("Inner", UDim2.fromScale(1, 1), 2, rowFrame, colors.warpColor, 1, 0)
	local displayText = string.format("%s-%s", signName1, signName2)
	innerFrame.Text = displayText
	innerFrame.TextScaled = true
	innerFrame.RichText = true
	innerFrame.TextWrapped = true

	local warpButton = Instance.new("TextButton")
	warpButton.Name = "WarpButton"
	warpButton.Size = UDim2.fromScale(1, 1)
	warpButton.BackgroundTransparency = 1
	warpButton.Text = ""
	warpButton.Parent = innerFrame

	warpButton.Activated:Connect(function()
		warper.WarpToSignId(signId1, signId2)
	end)
end

module.DrawShowFavoriteRacesButton = function(rowFrame: Frame, change: tt.leaderboardUserDataChange, targetUserId: number, requestingUserId: number)
	_annotate("calling show favorite racesbutton.")
	local newFavoriteRaceCount: number = change.newValue :: number

	local oldCell = rowFrame:FindFirstChild("070.favs")
	if oldCell then
		oldCell:Destroy()
	end

	local innerFrame = guiUtil.getTl("070.favs", UDim2.fromScale(1, 1), 2, rowFrame, colors.defaultGrey, 1, 0)
	innerFrame.Text = string.format("%d Favs", newFavoriteRaceCount)
	innerFrame.TextScaled = true

	local fb = Instance.new("TextButton")
	fb.Name = string.format("ShowFavoritesButtonFor_%d", targetUserId)
	fb.Size = UDim2.fromScale(1, 1)
	fb.BackgroundTransparency = 1
	fb.Text = ""
	fb.Parent = innerFrame

	local otherUserIds = {}
	for _, oplayer in ipairs(PlayersService:GetPlayers()) do
		if oplayer.UserId ~= targetUserId and oplayer.UserId ~= requestingUserId then
			table.insert(otherUserIds, oplayer.UserId)
		end
	end

	fb.Activated:Connect(function()
		drawFavoritesModal.DrawFavoriteRacesModal(targetUserId, requestingUserId, otherUserIds)
	end)
end

-- Get next warp permission in cycle
local function getNextWarpPermission(current: string): string
	for i, option in ipairs(WARP_PERMISSION_OPTIONS) do
		if option == current then
			return WARP_PERMISSION_OPTIONS[(i % #WARP_PERMISSION_OPTIONS) + 1]
		end
	end
	return WARP_PERMISSION_OPTIONS[1]
end

-- Check if requester can warp to target based on their permission
local function canWarpToPlayer(targetUserId: number, targetPermission: string, _requesterUserId: number): boolean
	if targetPermission == "none" then
		return false
	end
	if targetPermission == "all" then
		return true
	end
	if targetPermission == "robloxFriends" then
		local localPlayer = PlayersService.LocalPlayer
		if localPlayer then
			local success, isFriend = pcall(function()
				return localPlayer:IsFriendsWith(targetUserId)
			end)
			return success and isFriend
		end
	end
	-- TODO: Add TP friends check when TP friends system is implemented
	-- if targetPermission == "tpFriends" then
	-- 	return tpFriends.IsFriendWith(requesterUserId, targetUserId)
	-- end
	return false
end

-- Warp to another player (sends userId to server for validation)
local function warpToPlayer(targetUserId: number)
	warper.WarpToPlayer(targetUserId)
end

-- Draw the warpTo cell for a player
module.DrawWarpToCell = function(rowFrame: Frame, targetUserId: number, targetWarpPermission: string, localUserId: number, localFindCount: number)
	_annotate(string.format("DrawWarpToCell: targetUserId=%d localUserId=%d permission=%s", targetUserId, localUserId, tostring(targetWarpPermission)))

	local oldCell = rowFrame:FindFirstChild("WarpToInner")
	if oldCell then
		oldCell:Destroy()
	end

	local isOwnRow = targetUserId == localUserId
	local bgcolor = if isOwnRow then colors.meColor else colors.defaultGrey

	-- Check if local player has enough finds to use warp feature
	local hasEnoughFinds = localFindCount >= MIN_FINDS_FOR_WARP

	if isOwnRow then
		-- Own row: show current permission and allow toggling
		local currentPermission = targetWarpPermission or "none"
		local displayLabel = WARP_PERMISSION_LABELS[currentPermission] or "off"
		_annotate(string.format("DrawWarpToCell: OWN ROW - currentPermission=%s displayLabel=%s", currentPermission, displayLabel))

		local innerFrame = guiUtil.getTl("WarpToInner", UDim2.fromScale(1, 1), 2, rowFrame, bgcolor, 1, 0)
		innerFrame.Text = displayLabel
		innerFrame.TextScaled = true
		innerFrame.TextWrapped = true

		-- Create toggle button as sibling to innerFrame (not child) to ensure it receives input
		-- Parent to innerFrame's parent (the outer TextLabel created by getTl)
		local outerLabel = innerFrame.Parent
		if not outerLabel then
			annotater.Error("DrawWarpToCell: outerLabel is nil, cannot create toggle button")
			return
		end
		_annotate(string.format("DrawWarpToCell: outerLabel=%s class=%s", outerLabel.Name, outerLabel.ClassName))

		local toggleButton = Instance.new("TextButton")
		toggleButton.Name = "WarpPermissionToggle"
		toggleButton.Size = UDim2.fromScale(1, 1)
		toggleButton.Position = UDim2.fromScale(0, 0)
		toggleButton.BackgroundTransparency = 1
		toggleButton.Text = ""
		toggleButton.ZIndex = 10 -- Ensure button is above all labels
		toggleButton.Active = true -- Explicitly enable
		toggleButton.Parent = outerLabel

		_annotate(string.format("DrawWarpToCell: Created toggle button, parent=%s, Active=%s", tostring(toggleButton.Parent and toggleButton.Parent.Name), tostring(toggleButton.Active)))

		-- Log input events for debugging
		toggleButton.InputBegan:Connect(function(input)
			_annotate(string.format("WarpPermissionToggle.InputBegan: type=%s", tostring(input.UserInputType)))
		end)

		toggleButton.MouseButton1Click:Connect(function()
			_annotate("WarpPermissionToggle.MouseButton1Click fired!")
		end)

		toggleButton.Activated:Connect(function()
			_annotate("WarpPermissionToggle.Activated fired!")
			local nextPermission = getNextWarpPermission(currentPermission)
			_annotate(string.format("Toggling warp permission: %s -> %s", currentPermission, nextPermission))
			local newSetting: tt.userSettingValue = {
				name = settingEnums.settingDefinitions.WARP_TO_PERMISSION.name,
				domain = settingEnums.settingDomains.USERSETTINGS,
				kind = settingEnums.settingKinds.STRING,
				stringValue = nextPermission,
			}
			local result = settings.SetSetting(newSetting)
			_annotate(string.format("settings.SetSetting result: %s", tostring(result)))
		end)

		_annotate("DrawWarpToCell: Toggle button setup complete for own row")
	else
		-- Other player's row
		if not hasEnoughFinds then
			-- Show locked message
			local innerFrame = guiUtil.getTl("WarpToInner", UDim2.fromScale(1, 1), 2, rowFrame, colors.defaultGrey, 1, 0)
			innerFrame.Text = "100 finds"
			innerFrame.TextScaled = true
			innerFrame.TextWrapped = true
			innerFrame.TextColor3 = colors.grey
		else
			local canWarp = canWarpToPlayer(targetUserId, targetWarpPermission or "none", localUserId)
			if canWarp then
				-- Show warp button using standard warp styling
				local innerFrame = guiUtil.getTl("WarpToInner", UDim2.fromScale(1, 1), 2, rowFrame, colors.warpColor, 1, 0)
				innerFrame.Text = "warp"
				innerFrame.TextScaled = true
				innerFrame.TextWrapped = true

				local warpButton = Instance.new("TextButton")
				warpButton.Name = "WarpToPlayerButton"
				warpButton.Size = UDim2.fromScale(1, 1)
				warpButton.BackgroundTransparency = 1
				warpButton.Text = ""
				warpButton.Parent = innerFrame

				warpButton.Activated:Connect(function()
					warpToPlayer(targetUserId)
				end)
			else
				-- Target doesn't allow warping - show empty cell
				local innerFrame = guiUtil.getTl("WarpToInner", UDim2.fromScale(1, 1), 2, rowFrame, colors.defaultGrey, 1, 0)
				innerFrame.Text = "-"
				innerFrame.TextScaled = true
				innerFrame.TextWrapped = true
			end
		end
	end
end

-- Draw the find percentage cell with green flash animation on improvement
module.DrawFindPercentCell = function(rowFrame: Frame, findCount: number, totalSigns: number, bgcolor: Color3?)
	local effectiveBgColor = bgcolor or colors.defaultGrey

	local percent = 0
	if totalSigns > 0 then
		percent = (findCount / totalSigns) * 100
	end

	local newText = string.format("%.1f%%", percent)
	local oldPercentRaw = rowFrame:GetAttribute("_prevFindPercent")
	local oldPercent: number = if type(oldPercentRaw) == "number" then oldPercentRaw else 0
	local isFirstDraw = oldPercentRaw == nil
	local improvement = not isFirstDraw and percent > oldPercent

	-- Store new value for next comparison
	rowFrame:SetAttribute("_prevFindPercent", percent)

	-- Find or create the inner label (matching getTl structure: outer TextLabel with "Inner" child)
	local existingOuter = rowFrame:FindFirstChild("FindPercentInner")
	local outerLabel: TextLabel
	local innerLabel: TextLabel

	if existingOuter and existingOuter:IsA("TextLabel") then
		outerLabel = existingOuter :: TextLabel
		local existingInner = outerLabel:FindFirstChild("Inner")
		if existingInner and existingInner:IsA("TextLabel") then
			innerLabel = existingInner :: TextLabel
		else
			-- Structure mismatch, recreate
			existingOuter:Destroy()
			innerLabel = guiUtil.getTl("FindPercentInner", UDim2.fromScale(1, 1), 2, rowFrame, effectiveBgColor, 1, 0)
			local parent = innerLabel.Parent
			if parent and parent:IsA("TextLabel") then
				outerLabel = parent :: TextLabel
			else
				outerLabel = innerLabel -- fallback
			end
		end
	else
		if existingOuter then
			existingOuter:Destroy()
		end
		innerLabel = guiUtil.getTl("FindPercentInner", UDim2.fromScale(1, 1), 2, rowFrame, effectiveBgColor, 1, 0)
		local parent = innerLabel.Parent
		if parent and parent:IsA("TextLabel") then
			outerLabel = parent :: TextLabel
		else
			outerLabel = innerLabel -- fallback
		end
	end

	innerLabel.TextScaled = true
	innerLabel.TextWrapped = true

	if improvement then
		-- Show intermediate text with improvement indicator
		local gap = percent - oldPercent
		local intermediateText = string.format("%s\n(+%.1f)", newText, gap)
		innerLabel.Text = intermediateText
		innerLabel.BackgroundColor3 = colors.greenGo
		outerLabel.BackgroundColor3 = colors.greenGo

		-- After greenTime, show final text
		task.spawn(function()
			task.wait(enums.greenTime)
			if innerLabel and innerLabel.Parent then
				innerLabel.Text = newText
			end
		end)

		-- Tween background back to default color
		local tweenInfo = TweenInfo.new(enums.greenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween1 = TweenService:Create(innerLabel, tweenInfo, { BackgroundColor3 = effectiveBgColor })
		local tween2 = TweenService:Create(outerLabel, tweenInfo, { BackgroundColor3 = effectiveBgColor })
		tween1:Play()
		tween2:Play()
	else
		innerLabel.Text = newText
		innerLabel.BackgroundColor3 = effectiveBgColor
		outerLabel.BackgroundColor3 = effectiveBgColor
	end
end

-- Similarity factors with display names
local similarityFactors = {
	{ key = "findCount", weight = 3, displayName = "finds" },
	{ key = "userTix", weight = 2, displayName = "tix" },
	{ key = "wrCount", weight = 2, displayName = "WRs" },
	{ key = "top10s", weight = 1, displayName = "top10s" },
	{ key = "cwrs", weight = 1, displayName = "CWRs" },
	{ key = "userTotalRunCount", weight = 1, displayName = "runs" },
	{ key = "daysInGame", weight = 1, displayName = "days" },
}

-- Calculate statistical similarity between two players (0-1 scale) and return breakdown
local function calculateSimilarityWithBreakdown(myStats: { [string]: any }, theirStats: { [string]: any }): (number, string)
	local totalWeight = 0
	local weightedDiffSum = 0
	local breakdownLines: { string } = {}

	for _, factor in ipairs(similarityFactors) do
		local myVal = tonumber(myStats[factor.key]) or 0
		local theirVal = tonumber(theirStats[factor.key]) or 0
		local maxVal = math.max(myVal, theirVal, 1)
		local diff = math.abs(myVal - theirVal) / maxVal
		local factorSimilarity = math.floor((1 - diff) * 100)
		weightedDiffSum = weightedDiffSum + (diff * factor.weight)
		totalWeight = totalWeight + factor.weight

		-- Build breakdown line: "finds: 150 vs 200 (75%)"
		table.insert(breakdownLines, string.format("%s: %d vs %d (%d%%)", factor.displayName, myVal, theirVal, factorSimilarity))
	end

	local avgDiff = weightedDiffSum / totalWeight
	local overallSimilarity = 1 - avgDiff

	-- Build full breakdown text
	local breakdownText = table.concat(breakdownLines, "\n")

	return overallSimilarity, breakdownText
end

-- Get color for similarity value
local function getSimilarityColor(similarity: number): Color3
	if similarity >= 0.9 then
		return Color3.fromRGB(0, 200, 0) -- Green - very similar
	elseif similarity >= 0.7 then
		return Color3.fromRGB(200, 200, 0) -- Yellow - somewhat similar
	elseif similarity >= 0.5 then
		return Color3.fromRGB(255, 165, 0) -- Orange - different
	else
		return Color3.fromRGB(200, 50, 50) -- Red - very different
	end
end

-- Draw the similarity cell with detailed tooltip
module.DrawSimilarityCell = function(rowFrame: Frame, myStats: { [string]: any }, theirStats: { [string]: any }, isOwnRow: boolean)
	local oldCell = rowFrame:FindFirstChild("SimilarityInner")
	if oldCell then
		oldCell:Destroy()
	end

	if isOwnRow then
		local innerFrame = guiUtil.getTl("SimilarityInner", UDim2.fromScale(1, 1), 2, rowFrame, colors.meColor, 1, 0)
		innerFrame.Text = "you"
		innerFrame.TextScaled = true
		innerFrame.TextWrapped = true
		return
	end

	local similarity, breakdownText = calculateSimilarityWithBreakdown(myStats, theirStats)
	local simColor = getSimilarityColor(similarity)
	local simPercent = math.floor(similarity * 100)

	local innerFrame = guiUtil.getTl("SimilarityInner", UDim2.fromScale(1, 1), 2, rowFrame, simColor, 1, 0)
	innerFrame.Text = string.format("%d%%", simPercent)
	innerFrame.TextScaled = true
	innerFrame.TextWrapped = true

	-- Add tooltip with detailed breakdown
	local tooltipText = string.format("Similarity: %d%%\n\n%s", simPercent, breakdownText)
	toolTip.setupToolTip(innerFrame, tooltipText, toolTip.enum.toolTipSize.BigPane, true)
end

-- pinnedBadge is handled by DrawPinnedBadgeCell (interactive column)

-- Draw the idle time cell
module.DrawIdleTimeCell = function(rowFrame: Frame, lastActivityTimestamp: number?, shareIdleStatus: boolean?, isOwnRow: boolean)
	local oldCell = rowFrame:FindFirstChild("IdleTimeInner")
	if oldCell then
		oldCell:Destroy()
	end

	local bgcolor = colors.defaultGrey
	local displayText = "-"

	if isOwnRow then
		displayText = "you"
		bgcolor = colors.meColor
	elseif shareIdleStatus and lastActivityTimestamp then
		local idleSeconds = tick() - lastActivityTimestamp
		if idleSeconds < 60 then
			displayText = "active"
			bgcolor = Color3.fromRGB(0, 200, 0)
		elseif idleSeconds < 300 then
			displayText = string.format("%dm", math.floor(idleSeconds / 60))
		elseif idleSeconds < 3600 then
			displayText = string.format("%dm", math.floor(idleSeconds / 60))
			bgcolor = Color3.fromRGB(200, 200, 0)
		else
			displayText = string.format("%dh", math.floor(idleSeconds / 3600))
			bgcolor = Color3.fromRGB(200, 100, 100)
		end
	end

	local innerFrame = guiUtil.getTl("IdleTimeInner", UDim2.fromScale(1, 1), 2, rowFrame, bgcolor, 1, 0)
	innerFrame.Text = displayText
	innerFrame.TextScaled = true
	innerFrame.TextWrapped = true
end

-- Helper: look up badge descriptor by name
local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)

local function getBadgeByName(badgeName: string): any?
	for _, badge in pairs(badgeEnums.badges) do
		if badge.name == badgeName then
			return badge
		end
	end
	return nil
end

-- Helper: format time ago from ISO timestamp string
local function formatTimeAgo(isoTimestamp: string?): string
	if not isoTimestamp then
		return ""
	end
	-- Parse ISO timestamp (e.g., "2024-12-15T10:30:00")
	-- Extract date parts using pattern matching
	local year, month, day = isoTimestamp:match("(%d+)-(%d+)-(%d+)")
	if not year then
		return ""
	end
	-- Get current time and calculate difference
	local nowDate = os.date("!*t")
	local yearNum = tonumber(year) or 0
	local monthNum = tonumber(month) or 1
	local dayNum = tonumber(day) or 1
	local earnedDate = { year = yearNum, month = monthNum, day = dayNum, hour = 0, min = 0, sec = 0 }
	local nowTime = os.time(nowDate :: any)
	local earnedTime = os.time(earnedDate :: any)
	local diffSeconds = nowTime - earnedTime
	local diffDays = math.floor(diffSeconds / 86400)
	if diffDays == 0 then
		return "today"
	elseif diffDays == 1 then
		return "1d ago"
	else
		return string.format("%dd ago", diffDays)
	end
end

-- Helper: create a visual badge tooltip frame
local function createBadgeTooltipFrame(badge: any, badgeName: string, earnedAt: string?): Frame
	local IMAGE_SIZE = 120
	local PADDING = 8
	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "BadgeTooltipContent"
	contentFrame.Size = UDim2.fromScale(1, 1) -- Fill the tooltip
	contentFrame.BackgroundTransparency = 1
	contentFrame.ZIndex = 11

	-- Badge image (big, left aligned)
	local badgeImage = Instance.new("ImageLabel")
	badgeImage.Name = "BadgeImage"
	badgeImage.Size = UDim2.fromOffset(IMAGE_SIZE, IMAGE_SIZE)
	badgeImage.Position = UDim2.fromOffset(PADDING, PADDING)
	badgeImage.BackgroundTransparency = 1
	badgeImage.Image = string.format("rbxassetid://%d", badge.iconImageId)
	badgeImage.ScaleType = Enum.ScaleType.Fit
	badgeImage.ZIndex = 12
	badgeImage.Parent = contentFrame

	-- Badge name (below image, left aligned)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "BadgeName"
	nameLabel.Size = UDim2.new(1, -PADDING * 2, 0, 18)
	nameLabel.Position = UDim2.fromOffset(PADDING, IMAGE_SIZE + PADDING + 4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = badgeName
	nameLabel.TextColor3 = colors.black
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 14
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextWrapped = true
	nameLabel.ZIndex = 12
	nameLabel.Parent = contentFrame

	-- Earned status for local player (below name, left aligned)
	local earnedLabel = Instance.new("TextLabel")
	earnedLabel.Name = "EarnedStatus"
	earnedLabel.Size = UDim2.new(1, -PADDING * 2, 0, 16)
	earnedLabel.Position = UDim2.fromOffset(PADDING, IMAGE_SIZE + PADDING + 24)
	earnedLabel.BackgroundTransparency = 1
	earnedLabel.Font = Enum.Font.Gotham
	earnedLabel.TextSize = 12
	earnedLabel.TextXAlignment = Enum.TextXAlignment.Left
	earnedLabel.TextColor3 = colors.black
	earnedLabel.ZIndex = 12
	earnedLabel.Parent = contentFrame

	if localPlayerBadgeStatusLoaded then
		local hasIt = localPlayerBadgeStatus[badgeName]
		if hasIt then
			earnedLabel.Text = "You have this"
		else
			earnedLabel.Text = "You don't have this"
		end
	else
		earnedLabel.Text = ""
	end

	return contentFrame
end

-- Draw the pinned badge cell (badge icon with tooltip showing name)
module.DrawPinnedBadgeCell = function(rowFrame: Frame, badgeName: string?, isOwnRow: boolean)
	-- Clear any previous content
	local oldContent = rowFrame:FindFirstChild("PinnedBadgeContent")
	if oldContent then
		oldContent:Destroy()
	end

	local bgcolor = if isOwnRow then colors.meColor else colors.defaultGrey

	-- Create container frame with background
	local containerFrame = Instance.new("Frame")
	containerFrame.Name = "PinnedBadgeContent"
	containerFrame.Size = UDim2.fromScale(1, 1)
	containerFrame.BackgroundColor3 = bgcolor
	containerFrame.BorderSizePixel = 1
	containerFrame.Parent = rowFrame

	-- If no pinned badge, show empty cell with "no badge pinned" tooltip
	if not badgeName or badgeName == "" then
		toolTip.setupToolTip(containerFrame, "no badge pinned", toolTip.enum.toolTipSize.NormalText, true)
		return
	end

	-- Look up badge to get icon
	local badge = getBadgeByName(badgeName)
	if not badge or not badge.iconImageId then
		-- Fallback: show text and tooltip
		local fallbackLabel = Instance.new("TextLabel")
		fallbackLabel.Name = "FallbackText"
		fallbackLabel.Size = UDim2.new(1, -4, 1, -4)
		fallbackLabel.Position = UDim2.fromOffset(2, 2)
		fallbackLabel.BackgroundTransparency = 1
		fallbackLabel.Text = "?"
		fallbackLabel.TextScaled = true
		fallbackLabel.Font = Enum.Font.Gotham
		fallbackLabel.TextColor3 = colors.black
		fallbackLabel.Parent = containerFrame
		toolTip.setupToolTip(containerFrame, badgeName, toolTip.enum.toolTipSize.NormalText, true)
		return
	end

	-- Create badge icon image (centered)
	local badgeIcon = Instance.new("ImageLabel")
	badgeIcon.Name = "BadgeIcon"
	badgeIcon.Size = UDim2.new(1, -4, 1, -4)
	badgeIcon.Position = UDim2.fromOffset(2, 2)
	badgeIcon.BackgroundTransparency = 1
	badgeIcon.Image = string.format("rbxassetid://%d", badge.iconImageId)
	badgeIcon.ScaleType = Enum.ScaleType.Fit
	badgeIcon.Parent = containerFrame

	-- Visual tooltip with badge image, name, and earned status
	local tooltipContent = createBadgeTooltipFrame(badge, badgeName, nil)
	toolTip.setupToolTip(badgeIcon, tooltipContent, UDim2.fromOffset(150, 180), true)
end

-- Draw the latest badge cell (badge icon with tooltip showing name and time)
module.DrawLatestBadgeCell = function(rowFrame: Frame, badgeName: string?, earnedAt: string?, isOwnRow: boolean)
	-- Clear any previous content
	local oldContent = rowFrame:FindFirstChild("LatestBadgeContent")
	if oldContent then
		oldContent:Destroy()
	end

	local bgcolor = if isOwnRow then colors.meColor else colors.defaultGrey

	-- Create container frame with background
	local containerFrame = Instance.new("Frame")
	containerFrame.Name = "LatestBadgeContent"
	containerFrame.Size = UDim2.fromScale(1, 1)
	containerFrame.BackgroundColor3 = bgcolor
	containerFrame.BorderSizePixel = 1
	containerFrame.Parent = rowFrame

	-- If no latest badge, show empty cell with "not gotten yet" tooltip
	if not badgeName or badgeName == "" then
		toolTip.setupToolTip(containerFrame, "no badge yet", toolTip.enum.toolTipSize.NormalText, true)
		return
	end

	-- Look up badge to get icon
	local badge = getBadgeByName(badgeName)
	if not badge or not badge.iconImageId then
		-- Fallback: show text and tooltip
		local fallbackLabel = Instance.new("TextLabel")
		fallbackLabel.Name = "FallbackText"
		fallbackLabel.Size = UDim2.new(1, -4, 1, -4)
		fallbackLabel.Position = UDim2.fromOffset(2, 2)
		fallbackLabel.BackgroundTransparency = 1
		fallbackLabel.Text = "?"
		fallbackLabel.TextScaled = true
		fallbackLabel.Font = Enum.Font.Gotham
		fallbackLabel.TextColor3 = colors.black
		fallbackLabel.Parent = containerFrame
		toolTip.setupToolTip(containerFrame, badgeName, toolTip.enum.toolTipSize.NormalText, true)
		return
	end

	-- Create badge icon image (centered)
	local badgeIcon = Instance.new("ImageLabel")
	badgeIcon.Name = "BadgeIcon"
	badgeIcon.Size = UDim2.new(1, -4, 1, -4)
	badgeIcon.Position = UDim2.fromOffset(2, 2)
	badgeIcon.BackgroundTransparency = 1
	badgeIcon.Image = string.format("rbxassetid://%d", badge.iconImageId)
	badgeIcon.ScaleType = Enum.ScaleType.Fit
	badgeIcon.Parent = containerFrame

	-- Visual tooltip with badge image, name, and earned status
	local tooltipContent = createBadgeTooltipFrame(badge, badgeName, earnedAt)
	toolTip.setupToolTip(badgeIcon, tooltipContent, UDim2.fromOffset(150, 180), true)
end

-- Draw the badge count cell (clickable to open badge viewer)
module.DrawBadgeCountCell = function(rowFrame: Frame, badgeCount: number, isOwnRow: boolean)
	local oldCell = rowFrame:FindFirstChild("BadgeCountInner")
	if oldCell then
		oldCell:Destroy()
	end

	local bgcolor = if isOwnRow then colors.meColor else colors.defaultGrey

	local innerFrame = guiUtil.getTl("BadgeCountInner", UDim2.fromScale(1, 1), 2, rowFrame, bgcolor, 1, 0)
	innerFrame.Text = tostring(badgeCount)
	innerFrame.TextScaled = true
	innerFrame.TextWrapped = true

	-- Make clickable to open badge viewer
	local clickButton = Instance.new("TextButton")
	clickButton.Name = "OpenBadgeViewerButton"
	clickButton.Size = UDim2.fromScale(1, 1)
	clickButton.Position = UDim2.fromScale(0, 0)
	clickButton.BackgroundTransparency = 1
	clickButton.Text = ""
	clickButton.ZIndex = 10
	clickButton.Active = true
	clickButton.Parent = innerFrame.Parent -- Parent to outer label

	clickButton.Activated:Connect(function()
		_annotate("Opening badge viewer from leaderboard click")
		local localPlayer = PlayersService.LocalPlayer
		local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
		if playerGui then
			local existingPopup = playerGui:FindFirstChild("BadgeStatusPopup")
			if existingPopup then
				existingPopup:Destroy()
			end
			local popup = badgeButton.getBadgeStatusModal(localPlayer)
			popup.Parent = playerGui
		end
	end)
end

_annotate("end")
return module
