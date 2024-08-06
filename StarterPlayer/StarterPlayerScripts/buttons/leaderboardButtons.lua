--!strict

--draw an action button row with hints along the bottom of the local screen (popular, new)

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local PlayersService = game:GetService("Players")

local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)

local localPlayer = PlayersService.LocalPlayer
local colors = require(game.ReplicatedStorage.util.colors)
local gt = require(game.ReplicatedStorage.gui.guiTypes)

local vscdebug = require(game.ReplicatedStorage.vscdebug)
local toolTip = require(game.ReplicatedStorage.gui.toolTip)

local popularButton = require(game.StarterPlayer.StarterPlayerScripts.buttons.popularButton)
local newButton = require(game.StarterPlayer.StarterPlayerScripts.buttons.newButton)
local contestButtonGetter = require(game.StarterPlayer.StarterPlayerScripts.buttons.contestButtonGetter)
local contestButtons = contestButtonGetter.getContestButtons({ localPlayer.UserId })
local marathonSettingsButton = require(game.ReplicatedStorage.gui.menu.marathonSettingsButton)
local serverEventButton = require(game.ReplicatedStorage.gui.menu.serverEventButton)

local actionButtons: { gt.actionButton } = {
	marathonSettingsButton.marathonSettingsButton,
	popularButton.popularButton,
	newButton.newButton,
	serverEventButton.serverEventButton,
}

for _, contestButton in ipairs(contestButtons) do
	table.insert(actionButtons, contestButton)
end

module.initActionButtons = function(lbOuterFrame: Frame)
	local actionButtonFrame = Instance.new("Frame")
	actionButtonFrame.BorderMode = Enum.BorderMode.Inset
	actionButtonFrame.BorderSizePixel = 0
	actionButtonFrame.Position = UDim2.new(0.7, 0, 1, 0)
	actionButtonFrame.Name = "4LeaderboardActionButtonFrame"
	actionButtonFrame.BackgroundTransparency = 1
	actionButtonFrame.Parent = lbOuterFrame

	actionButtonFrame.Size = UDim2.new(0.3, 0, 0, 40)

	local h = Instance.new("UIListLayout")
	h.HorizontalAlignment = Enum.HorizontalAlignment.Right
	h.FillDirection = Enum.FillDirection.Horizontal
	h.Parent = actionButtonFrame

	local pgui = localPlayer:FindFirstChildOfClass("PlayerGui")

	local bignum = 10000
	for ii, but in ipairs(actionButtons) do
		local color = colors.defaultGrey
		if but.getActive ~= nil then
			if not but.getActive() then
				color = colors.blueDone
			end
		end

		local buttonName = tostring(bignum - ii) .. "." .. but.name
		local buttonTb = guiUtil.getTb(buttonName, UDim2.new(but.widthXScale, 0, 1, 0), 2, actionButtonFrame, color, 1)
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
