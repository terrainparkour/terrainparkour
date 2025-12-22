--!strict
-- leaderboardButtons.lua on client.
-- Draw action buttons below the leaderboard, aligned to bottom-right.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayersService = game:GetService("Players")

local standardButton = require(game.ReplicatedStorage.gui.standardButton)
local editDomainSettingsButton = require(game.ReplicatedStorage.gui.menu.editDomainSettingsButton)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)
local runUIButton = require(game.ReplicatedStorage.gui.menu.runUIButton)
local serverEventButton = require(game.ReplicatedStorage.gui.menu.serverEventButton)

local module = {}

local BUTTON_HEIGHT = 22

-- Button config type
type ButtonConfig = {
	name: string,
	tooltip: string?,
	isRunUI: boolean?,
	isServerEvent: boolean?,
	domain: string?,
	style: "default" | "primary" | "danger" | "success"?,
}

-- All buttons to show on the row (expanded names for clarity)
-- Note: Tooltips omitted as they were rendering with choppy refresh rate. Button names are self-explanatory.
local buttonConfigs: { ButtonConfig } = {
	{ name = "Run UI", isRunUI = true, style = "default" },
	{ name = "Marathon", domain = settingEnums.settingDomains.MARATHONS, style = "default" },
	{ name = "Leaderboard", domain = settingEnums.settingDomains.LEADERBOARD, style = "default" },
	{ name = "User", domain = settingEnums.settingDomains.USERSETTINGS, style = "default" },
	{ name = "Event", isServerEvent = true, style = "default" },
}

module.initActionButtons = function(lbOuterFrame: Frame)
	local actionButtonFrame = Instance.new("Frame")
	actionButtonFrame.BorderSizePixel = 0
	-- Position 15px left of right edge to leave space for resize handle
	actionButtonFrame.Position = UDim2.new(1, -15, 1, 0)
	actionButtonFrame.AnchorPoint = Vector2.new(1, 0)
	actionButtonFrame.Name = "LeaderboardActionButtonFrame"
	actionButtonFrame.BackgroundTransparency = 1
	actionButtonFrame.Parent = lbOuterFrame
	actionButtonFrame.Size = UDim2.fromOffset(400, BUTTON_HEIGHT)

	local listLayout = Instance.new("UIListLayout")
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	listLayout.FillDirection = Enum.FillDirection.Horizontal
	listLayout.Padding = UDim.new(0, 1)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = actionButtonFrame

	local playerGui = PlayersService.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui

	for i, config in ipairs(buttonConfigs) do
		local function handleClick()
			if config.isRunUI then
				runUIButton.Click({ PlayersService.LocalPlayer.UserId })
			elseif config.isServerEvent then
				serverEventButton.Click({ PlayersService.LocalPlayer.UserId })
			elseif config.domain then
				local guiSpec = editDomainSettingsButton.CreateGenericSettingsEditor(config.domain)
				local desiredSize = editDomainSettingsButton.CalculateSettingsEditorSize(config.domain)
				local theSguiResult = windows.CreatePopup(guiSpec, config.name .. " Settings", true, true, false, false, true, false, desiredSize)
				local theSgui = theSguiResult.sgui
				local outerFrame = theSgui:FindFirstChildOfClass("Frame")
				if outerFrame then
					outerFrame.Position = UDim2.fromScale(0.25, 0.25)
				end
				theSgui.Parent = playerGui
			end
		end

		local button = standardButton.Create({
			text = config.name,
			onClick = handleClick,
			style = config.style,
			tooltip = config.tooltip,
			autoSize = true,
			padding = 5, -- uniform padding around text
		})
		button.LayoutOrder = i
		button.Parent = actionButtonFrame
	end
end

_annotate("end")
return module
