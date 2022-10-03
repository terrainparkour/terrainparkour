--!strict
--eval 9.25.22

--draw an action button row with hints along the bottom of the local screen (popular, new)

local PlayersService = game:GetService("Players")

local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local localPlayer = PlayersService.LocalPlayer
local colors = require(game.ReplicatedStorage.util.colors)
local gt = require(game.ReplicatedStorage.gui.guiTypes)
local module = {}

local popularButton = require(game.StarterPlayer.StarterCharacterScripts.buttons.popularButton)
local newButton = require(game.StarterPlayer.StarterCharacterScripts.buttons.newButton)
local contestButtonGetter = require(game.StarterPlayer.StarterCharacterScripts.buttons.contestButtonGetter)
local contestButtons = contestButtonGetter.getContestButtons({ localPlayer.UserId })
local marathonSettingsButton = require(game.ReplicatedStorage.gui.menu.marathonSettingsButton)

local actionButtons: { gt.actionButton } = {
	marathonSettingsButton.marathonSettingsButton,
	popularButton.popularButton,
	newButton.newButton,
}

for ii, contestButton in ipairs(contestButtons) do
	table.insert(actionButtons, contestButton)
end

module.initActionButtons = function(lbframe: Frame, player: Player)
	local fr = Instance.new("Frame")
	fr.BorderMode = Enum.BorderMode.Inset
	fr.BorderSizePixel = 0
	fr.BorderSizePixel = 0
	fr.Size = UDim2.new(1, 0, 0, 30)
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
		local buttonTb = guiUtil.getTb(tostring(bignum - ii) .. "." .. but.name, UDim2.new(0, 60, 1, 0), 3, fr, color)
		buttonTb.Text = but.shortName
		--reverse order they're listed in actionButtons above
		buttonTb.Name = tostring(bignum - ii)
		buttonTb.Activated:Connect(function()
			spawn(function()
				local userIds = {}
				for _, player in ipairs(PlayersService:GetPlayers()) do
					table.insert(userIds, player.UserId)
				end
				local content = but.contentsGetter(localPlayer, userIds)
				content.Parent = pgui
			end)
		end)
	end
	fr.Name = "zzzActionButtons"
	fr.BackgroundTransparency = 1
	fr.Parent = lbframe
end

return module
