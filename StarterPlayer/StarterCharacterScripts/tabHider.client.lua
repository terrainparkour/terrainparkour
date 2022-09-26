--!strict

--eval 9.25.22
-- hide chat window and leaderboard when the user hits tab.

local UserInputService = game:GetService("UserInputService")
local showUI: boolean = true

local players = game:GetService("Players")
local localplayer = players.LocalPlayer

local function ToggleUI(intendedState: boolean)
	local items = { localplayer.PlayerGui:FindFirstChild("LeaderboardScreenGui") }
	for _, el in ipairs(items) do
		if el == nil then
			print("bad item.")
			continue
		end
		el.Enabled = intendedState
	end
	local ChatMain =
		require(game.Players.LocalPlayer.PlayerScripts:FindFirstChild("ChatScript"):WaitForChild("ChatMain"))
	ChatMain:SetVisible(intendedState)
	--ChatMain:ToggleVisibility()
end

local function KillPopups()
	for _, el in ipairs(localplayer.PlayerGui:GetChildren()) do
		if el.Name == "RaceResultSgui" then
			el:Destroy()
		end
		if el.Name == "EphemeralNotificationSgui" then
			el:Destroy()
		end
		if el.Name == "ToolTipGui" then
			el:Destroy()
		end
		if el.Name == "NewFindSgui" then
			el:Destroy()
		end
	end
end

local function onInputBegin(inputObject, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end

	if inputObject.UserInputType == Enum.UserInputType.Keyboard then
		if inputObject.KeyCode == Enum.KeyCode.Tab then
			showUI = not showUI
			ToggleUI(showUI)
		end

		if inputObject.KeyCode == Enum.KeyCode.X then
			KillPopups()
		end
	end
end

UserInputService.InputBegan:Connect(onInputBegin)
