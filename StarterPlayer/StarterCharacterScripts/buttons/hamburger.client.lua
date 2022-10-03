--!strict

--eval 9.25.22
--the lower right S hamburger

local PlayersService = game:GetService("Players")

local localPlayer = PlayersService.LocalPlayer
local pgui: PlayerGui = PlayersService.LocalPlayer:WaitForChild("PlayerGui")
local menu = require(game.ReplicatedStorage.gui.menu.menu)
local gt = require(game.ReplicatedStorage.gui.guiTypes)

local badgeButton = require(game.ReplicatedStorage.gui.menu.badgeButton)

local surveyButton = require(game.ReplicatedStorage.gui.menu.surveyButton)
local howToPlayButton = require(game.ReplicatedStorage.gui.menu.howToPlayButton)

local userSettingsButton = require(game.ReplicatedStorage.gui.menu.userSettingsButton)

local buttons: { gt.button } = {
	howToPlayButton.howToPlayButton,
	badgeButton.badgeButton,
	surveyButton.surveySettingsButton,
	userSettingsButton.userSettingsButton,
}

local function setupMenu()
	local menuPopup: ScreenGui
	local ham = menu.getHamburger()
	local hamName = ham.Name
	ham.Parent = pgui
	local menuDisplayButton: TextButton = ham:FindFirstChild("hamburgerFrame"):FindFirstChild("button")
	local shown = false
	menuDisplayButton.Activated:Connect(function()
		--destroy if  this was a toggle off.
		--but otherwise just fall through to recreation
		if shown and menuPopup ~= nil and menuPopup.Parent ~= nil then
			menuPopup:Destroy()
			shown = false
			return
		end
		shown = true
		menuPopup = menu.getMenuList(localPlayer, buttons, pgui)
		menuPopup.Parent = pgui
	end)
end

setupMenu()
