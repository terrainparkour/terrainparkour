--!strict

-- leaderboardButtons.lua on client.
-- draw buttons along the bottom of the local screen for marathon settings, lb settings, and user settings.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayersService = game:GetService("Players")
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local colors = require(game.ReplicatedStorage.util.colors)
local toolTip = require(game.ReplicatedStorage.gui.toolTip)

local editDomainSettingsButton = require(game.ReplicatedStorage.gui.menu.editDomainSettingsButton)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)

-- Add these new imports
-- local popularButton = require(game.ReplicatedStorage.gui.popularButton)
-- local newButton = require(game.ReplicatedStorage.gui.newButton)
local serverEventButton = require(game.ReplicatedStorage.gui.menu.serverEventButton)
-- local contestButtonGetter = require(game.ReplicatedStorage.gui.contestButtonGetter)

local module = {}

local settingButtons = {
	{
		name = "Marathon Settings",
		domain = settingEnums.settingDomains.MARATHONS,
		hoverHint = "Configure Marathon Settings",
	},
	{
		name = "Leaderboard Settings",
		domain = settingEnums.settingDomains.LEADERBOARD,
		hoverHint = "Configure Leaderboard Settings",
	},
	{
		name = "User Settings",
		domain = settingEnums.settingDomains.USERSETTINGS,
		hoverHint = "Configure User Settings",
	},
}

local actionButtons = {
	-- popularButton.popularButton,
	-- newButton.newButton,
	serverEventButton,
	-- contestButtonGetter.contestButtonGetter,
}

module.initActionButtons = function(lbOuterFrame: Frame)
	local actionButtonFrame = Instance.new("Frame")
	actionButtonFrame.BorderMode = Enum.BorderMode.Inset
	actionButtonFrame.BorderSizePixel = 0
	actionButtonFrame.Position = UDim2.new(0.4, 0, 1, 0)
	actionButtonFrame.Name = "LeaderboardActionButtonFrame"
	actionButtonFrame.BackgroundTransparency = 1
	actionButtonFrame.Parent = lbOuterFrame
	actionButtonFrame.Size = UDim2.new(0.6, 0, 0, 20)

	local h = Instance.new("UIListLayout")
	h.HorizontalAlignment = Enum.HorizontalAlignment.Right
	h.FillDirection = Enum.FillDirection.Horizontal
	h.Parent = actionButtonFrame

	local totalButtons = #settingButtons + #actionButtons
	local buttonWidth = (1 / totalButtons) * 0.8

	-- Create setting buttons
	for i, buttonInfo in ipairs(settingButtons) do
		local buttonTb =
			guiUtil.getTb(buttonInfo.name, UDim2.new(buttonWidth, 0, 1, 0), 2, actionButtonFrame, colors.defaultGrey, 1)
		buttonTb.Text = buttonInfo.name
		buttonTb.Name = string.format("%d.%s_inner", i, buttonInfo.name)
		buttonTb.BackgroundTransparency = 1
		local parentInstance = buttonTb.Parent
		if parentInstance and parentInstance:IsA("TextLabel") then
			local parentLabel: TextLabel = parentInstance
			parentLabel.BackgroundTransparency = 0
		end

		buttonTb.Activated:Connect(function()
			local guiSpec = editDomainSettingsButton.CreateGenericSettingsEditor(buttonInfo.domain)
			local desiredSize = editDomainSettingsButton.CalculateSettingsEditorSize(buttonInfo.domain)
			local theSgui = windows.CreatePopup(
				guiSpec,
				buttonInfo.name .. " Editor",
				true,
				true,
				false,
				false,
				true,
				false,
				desiredSize
			)
			local outerFrame = theSgui:FindFirstChildOfClass("Frame")
			if outerFrame then
				outerFrame.Position = UDim2.new(0.25, 0, 0.25, 0)
			end
			local playerGui = PlayersService.LocalPlayer:WaitForChild("PlayerGui")
			theSgui.Parent = playerGui
		end)

		toolTip.setupToolTip(buttonTb, buttonInfo.hoverHint, UDim2.new(0, 200, 0, 40), false)
	end

	for i, buttonModule in ipairs(actionButtons) do
		local buttonTb = guiUtil.getTb(
			buttonModule.Name,
			UDim2.new(buttonWidth, 0, 1, 0),
			2,
			actionButtonFrame,
			colors.defaultGrey,
			1
		)
		buttonTb.Text = buttonModule.Name
		buttonTb.Name = string.format("%d.%s_inner", i + #settingButtons, buttonModule.Name)
		buttonTb.BackgroundTransparency = 1
		local parentInstance = buttonTb.Parent
		if parentInstance and parentInstance:IsA("TextLabel") then
			local parentLabel: TextLabel = parentInstance
			parentLabel.BackgroundTransparency = 0
		end

		buttonTb.Activated:Connect(function(_input: InputObject?, _clickCount: number?)
			buttonModule.Click({ PlayersService.LocalPlayer.UserId })
		end)

		if buttonModule.HoverHint then
			toolTip.setupToolTip(buttonTb, buttonModule.HoverHint, UDim2.new(0, 200, 0, 40), false)
		end
	end
end

_annotate("end")
return module
