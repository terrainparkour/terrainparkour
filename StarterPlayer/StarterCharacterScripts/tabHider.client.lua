--!strict

--eval 9.25.22
-- hide chat window and leaderboard when the user hits tab.

local UserInputService = game:GetService("UserInputService")
local showLB: boolean = true
local showChat: boolean = true

local PlayersService = game:GetService("Players")
repeat game:GetService("RunService").RenderStepped:wait() until game.Players.LocalPlayer.Character ~= nil
local localPlayer = PlayersService.LocalPlayer

local function ToggleChat(intendedState: boolean)
	local ChatMain =
		require(game.Players.LocalPlayer.PlayerScripts:FindFirstChild("ChatScript"):WaitForChild("ChatMain"))
	ChatMain:SetVisible(intendedState)
end

local function ToggleLB(intendedState: boolean)
	local items = { localPlayer.PlayerGui:FindFirstChild("LeaderboardScreenGui") }
	for _, el in ipairs(items) do
		if el == nil then
			print("bad item.")
			continue
		end
		el.Enabled = intendedState
	end
end

local function KillPopups()
	for _, el in ipairs(localPlayer.PlayerGui:GetChildren()) do
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
		if el.Name == "EphemeralTooltip" then
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
			showLB = not showLB
			ToggleLB(showLB)
		end

		if inputObject.KeyCode == Enum.KeyCode.X then
			KillPopups()
		end
	end
end

UserInputService.InputBegan:Connect(onInputBegin)
