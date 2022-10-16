--!strict
--eval 9.25.22

--draw an action button row with hints along the bottom of the local screen (popular, new)

local PlayersService = game:GetService("Players")

local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local localPlayer = PlayersService.LocalPlayer
local colors = require(game.ReplicatedStorage.util.colors)
local gt = require(game.ReplicatedStorage.gui.guiTypes)
local module = {}
local vscdebug = require(game.ReplicatedStorage.vscdebug)
local toolTip = require(game.ReplicatedStorage.gui.toolTip)

local popularButton = require(game.StarterPlayer.StarterCharacterScripts.buttons.popularButton)
local newButton = require(game.StarterPlayer.StarterCharacterScripts.buttons.newButton)
local contestButtonGetter = require(game.StarterPlayer.StarterCharacterScripts.buttons.contestButtonGetter)
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

local actionButtonHeightPixels = 18
module.initActionButtons = function(lbframe: Frame, player: Player)
	local fr = Instance.new("Frame")
	fr.BorderMode = Enum.BorderMode.Inset
	fr.BorderSizePixel = 0
	fr.Size = UDim2.new(1, 0, 0, actionButtonHeightPixels)
	local h = Instance.new("UIListLayout")
	h.HorizontalAlignment = Enum.HorizontalAlignment.Right
	h.FillDirection = Enum.FillDirection.Horizontal
	h.Parent = fr
	local pgui = player.PlayerGui

	local bignum = 10000
	for ii, but in ipairs(actionButtons) do
		local color = colors.defaultGrey
		if but.getActive ~= nil then
			if not but.getActive() then
				color = colors.blueDone
			end
		end

		local buttonTb =
			guiUtil.getTb(tostring(bignum - ii) .. "." .. but.name, UDim2.new(0, but.widthPixels, 1, 0), 0, fr, color, 0)
		buttonTb.Text = but.shortName
		--reverse order they're listed in actionButtons above
		buttonTb.Name = tostring(bignum - ii)
		buttonTb.BackgroundTransparency = 0.5
		buttonTb.Parent.BackgroundTransparency = 0.5

		buttonTb.Activated:Connect(function()
			spawn(function()
				local userIds = {}
				for _, pl in ipairs(PlayersService:GetPlayers()) do
					table.insert(userIds, pl.UserId)
				end
				local content = but.contentsGetter(localPlayer, userIds)
				content.Parent = pgui
			end)
		end)
		toolTip.setupToolTip(localPlayer, buttonTb, but.hoverHint, UDim2.new(0, 200, 0, 40), false)
	end
	fr.Name = "zzzActionButtons"
	fr.BackgroundTransparency = 1
	fr.Parent = lbframe
end

return module
