--!strict

-- leaderboardButtons.lua on client.
-- draw an action button row with hints along the bottom of the local screen (popular, new, marathon settings, lb settings, random race.)

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local PlayersService = game:GetService("Players")

local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)

local colors = require(game.ReplicatedStorage.util.colors)

--TYPE
local gt = require(game.ReplicatedStorage.gui.guiTypes)

-- local vscdebug = require(game.ReplicatedStorage.vscdebug)
local toolTip = require(game.ReplicatedStorage.gui.toolTip)

local popularButton = require(game.StarterPlayer.StarterPlayerScripts.buttons.popularButton)
local newButton = require(game.StarterPlayer.StarterPlayerScripts.buttons.newButton)
local contestButtonGetter = require(game.StarterPlayer.StarterPlayerScripts.buttons.contestButtonGetter)

local editDomainSettingsButton = require(game.ReplicatedStorage.gui.menu.editDomainSettingsButton)
local serverEventButton = require(game.ReplicatedStorage.gui.menu.serverEventButton)

local localPlayer = PlayersService.LocalPlayer
local contestButtons = contestButtonGetter.getContestButtons({ localPlayer.UserId })

local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)

-- MAIN ----------------------------

local actionButtons: { gt.actionButton } = {
	editDomainSettingsButton.getGenericSettingsEditor(settingEnums.settingDomains.MARATHONS),
	editDomainSettingsButton.getGenericSettingsEditor(settingEnums.settingDomains.LEADERBOARD),
	editDomainSettingsButton.getGenericSettingsEditor(settingEnums.settingDomains.USERSETTINGS),
	popularButton.popularButton,
	newButton.newButton,
	serverEventButton.serverEventButton,
}

-- if any contests are enabled, add them as action buttons.

for _, contestButton in ipairs(contestButtons) do
	table.insert(actionButtons, contestButton)
end

module.initActionButtons = function(lbOuterFrame: Frame)
	local actionButtonFrame = Instance.new("Frame")
	actionButtonFrame.BorderMode = Enum.BorderMode.Inset
	actionButtonFrame.BorderSizePixel = 0
	actionButtonFrame.Position = UDim2.new(0.4, 0, 1, 0)
	actionButtonFrame.Name = "LeaderboardActionButtonFrame"
	actionButtonFrame.BackgroundTransparency = 1
	actionButtonFrame.Parent = lbOuterFrame

	actionButtonFrame.Size = UDim2.new(0.6, 0, 0, 17)

	local h = Instance.new("UIListLayout")
	h.HorizontalAlignment = Enum.HorizontalAlignment.Right
	h.FillDirection = Enum.FillDirection.Horizontal
	h.Parent = actionButtonFrame

	local pgui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local totalXWeights = 0
	for _, but in ipairs(actionButtons) do
		totalXWeights = totalXWeights + but.widthXScale
	end

	local bignum = 10000
	for ii, but in ipairs(actionButtons) do
		local myXScale = but.widthXScale / totalXWeights
		local color = colors.defaultGrey
		if but.getActive ~= nil then
			if not but.getActive() then
				color = colors.blueDone
			end
		end

		local buttonName = tostring(bignum - ii) .. "." .. but.name
		local buttonTb = guiUtil.getTb(buttonName, UDim2.new(myXScale, 0, 1, 0), 2, actionButtonFrame, color, 1)
		buttonTb.Text = but.shortName

		--reverse order they're listed in actionButtons above
		buttonTb.Name = tostring(bignum - ii) .. "." .. but.name .. "_inner."
		buttonTb.BackgroundTransparency = 1
		local par: TextLabel = buttonTb.Parent
		par.BackgroundTransparency = 0

		buttonTb.Activated:Connect(function()
			task.spawn(function()
				local userIds = {}
				for _, pl in ipairs(PlayersService:GetPlayers()) do
					table.insert(userIds, pl.UserId)
				end
				local content = but.contentsGetter(localPlayer, userIds)
				if not content then
					return
				end
				content.Parent = pgui
			end)
		end)
		toolTip.setupToolTip(buttonTb, but.hoverHint, UDim2.new(0, 200, 0, 40), false)
	end
end

_annotate("end")
return module
