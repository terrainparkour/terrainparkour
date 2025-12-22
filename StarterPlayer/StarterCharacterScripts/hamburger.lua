--!strict

-- hamburger.lua :: StarterPlayer.StarterCharacterScripts.hamburger
-- The lower right S hamburger menu which contains info screens "ways to play", "badges", "surveys" and also the settings UI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayersService = game:GetService("Players")

local annotater = require(ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local adminToolsButton = require(ReplicatedStorage.gui.menu.adminToolsButton)
local badgeButton = require(ReplicatedStorage.gui.menu.badgeButton)
local cameraControlsButton = require(ReplicatedStorage.gui.menu.cameraControlsButton)
local config = require(ReplicatedStorage.config)
local contestButtonGetter = require(game.StarterPlayer.StarterPlayerScripts.buttons.contestButtonGetter)
local enums = require(ReplicatedStorage.util.enums)
local gt = require(ReplicatedStorage.gui.guiTypes)
local guiUtil = require(ReplicatedStorage.gui.guiUtil)
local howToPlayButton = require(ReplicatedStorage.gui.menu.howToPlayButton)
local keyboardShortcutsButton = require(ReplicatedStorage.gui.menu.keyboardShortcutsButton)
local menu = require(ReplicatedStorage.gui.menu.menu)
local newButton = require(game.StarterPlayer.StarterPlayerScripts.buttons.newButton)
local popularButton = require(game.StarterPlayer.StarterPlayerScripts.buttons.popularButton)
local surveyButton = require(ReplicatedStorage.gui.menu.surveyButton)

type Module = {
	Init: () -> (),
}

local module: Module = {} :: Module

local initialized = false

local colors = require(ReplicatedStorage.util.colors)

-- Create a simple "no content" screen for when a feature has no data
local function createNoContentScreen(message: string): ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "NoContentGui"
	screenGui.IgnoreGuiInset = true
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0.3, 0, 0.15, 0)
	frame.Position = UDim2.new(0.35, 0, 0.4, 0)
	frame.BackgroundColor3 = colors.defaultGrey
	frame.Parent = screenGui
	local tl = guiUtil.getTl("Message", UDim2.new(1, 0, 0.7, 0), 1, frame, colors.defaultGrey, 1)
	tl.Text = message
	tl.TextColor3 = colors.black
	local closeBtn = guiUtil.getTbSimple()
	closeBtn.Size = UDim2.new(1, 0, 0.3, 0)
	closeBtn.Position = UDim2.new(0, 0, 0.7, 0)
	closeBtn.Text = "Close"
	closeBtn.Parent = frame
	closeBtn.Activated:Connect(function()
		screenGui:Destroy()
	end)
	return screenGui
end

-- Wrapper to adapt actionButton contentsGetter (takes userIds) to button contentsGetter (no userIds)
local function wrapActionButton(actionButton: gt.actionButton): gt.button
	return {
		name = actionButton.shortName or actionButton.name,
		contentsGetter = function(player: Player): ScreenGui
			return actionButton.contentsGetter(player, {})
		end,
	}
end

function module.Init()
	if initialized then
		return
	end
	initialized = true

	local localPlayer = PlayersService.LocalPlayer
	local pgui: PlayerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

	-- Build button list
	local buttons: { gt.button } = {
		howToPlayButton.howToPlayButton,
		badgeButton.badgeButton,
		surveyButton.surveySettingsButton,
		keyboardShortcutsButton.keyboardShortcutsButton,
		cameraControlsButton.cameraControlsButton,
	}

	-- Add popular races button
	table.insert(buttons, wrapActionButton(popularButton.popularButton))

	-- Add new races button
	table.insert(buttons, wrapActionButton(newButton.newButton))

	-- Add contest button (checks at click-time since it loads asynchronously)
	local contestButton: gt.button = {
		name = "Contests",
		contentsGetter = function(player: Player): ScreenGui
			local ab = contestButtonGetter.contestButton
			if ab then
				return ab.contentsGetter(player, {})
			else
				-- No active contest - show archived contests picker
				return contestButtonGetter.getArchivedContestsUI(player)
			end
		end,
	}
	table.insert(buttons, contestButton)

	-- Add admin tools button for TerrainParkour in Studio only
	if config.IsInStudio() and localPlayer.UserId == enums.objects.TerrainParkourUserId then
		table.insert(buttons, adminToolsButton.adminToolsButton)
		_annotate("Added admin tools button to hamburger menu")
	end

	local menuPopup: ScreenGui? = nil
	local ham = menu.getHamburger()
	ham.Parent = pgui

	local hamFrame = ham:WaitForChild("hamburgerFrame")
	local menuDisplayButton: TextButton = hamFrame:WaitForChild("button") :: TextButton
	local shown = false

	menuDisplayButton.Activated:Connect(function()
		if shown and menuPopup and menuPopup.Parent then
			menuPopup:Destroy()
			shown = false
			return
		end
		shown = true
		local popup = menu.getMenuList(localPlayer, buttons, pgui)
		popup.Parent = pgui
		menuPopup = popup
	end)

	_annotate("initialized")
end

_annotate("end")
return module

