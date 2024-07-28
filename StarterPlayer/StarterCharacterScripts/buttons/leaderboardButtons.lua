--!strict

--draw an action button row with hints along the bottom of the local screen (popular, new)

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

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
local lbEnums = require(game.ReplicatedStorage.enums.lbEnums)

local actionButtons: { gt.actionButton } = {
	marathonSettingsButton.marathonSettingsButton,
	popularButton.popularButton,
	newButton.newButton,
	serverEventButton.serverEventButton,
}

for _, contestButton in ipairs(contestButtons) do
	table.insert(actionButtons, contestButton)
end

module.initActionButtons = function(lbframe: Frame, player: Player)
	local fr = Instance.new("Frame")
	fr.BorderMode = Enum.BorderMode.Inset
	fr.BorderSizePixel = 0
	fr.Size = UDim2.new(1, -3, 0, lbEnums.actionButtonHeightPixels)
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

		local buttonName = tostring(bignum - ii) .. "." .. but.name
		local buttonTb = guiUtil.getTb(buttonName, UDim2.new(0, but.widthPixels, 1, 0), 2, fr, color, 1)
		buttonTb.Text = but.shortName
		--reverse order they're listed in actionButtons above
		buttonTb.Name = tostring(bignum - ii)
		buttonTb.BackgroundTransparency = 1
		local par: TextLabel = buttonTb.Parent
		par.BackgroundTransparency = lbEnums.lbTransparency

		buttonTb.Activated:Connect(function()
			task.spawn(function()
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

_annotate("end")
return module
