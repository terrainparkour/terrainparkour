--!strict

-- client main loader. it loads (by requiring in order) all the client modulescripts in the client folder.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
annotater.Init()

local module = {}
local aet = require(game.ReplicatedStorage.avatarEventTypes)
local players = game:GetService("Players")
local localPlayer: Player = players.LocalPlayer
local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local fireEvent = avatarEventFiring.FireEvent

local function handleReset()
	fireEvent(aet.avatarEventTypes.AVATAR_RESET, { sender = "resetCharacterSetup" })
	local character = localPlayer.Character
	local humanoid = character and character:WaitForChild("Humanoid") :: Humanoid
	if character and humanoid then
		_annotate(string.format("killing player"))
		humanoid.Health = 0
	else
		warn("failed killing player")
	end
	local didDie = false
	if character then
		task.spawn(function()
			local currentCharacter: Model = character
			while true do
				local humanoidInstance = currentCharacter:WaitForChild("Humanoid")
				if not humanoidInstance or not humanoidInstance:IsA("Humanoid") then
					didDie = true
					task.wait(0.01)
				else
					local currentHumanoid: Humanoid = humanoidInstance :: Humanoid
					task.wait(0.01)
					if didDie and currentHumanoid.Health > 0 then
						break
					end
				end
			end
		end)
	end
end

local function setupResetCallback()
	-- Clear any existing BindableEvent
	local resetBindable: BindableEvent = Instance.new("BindableEvent")
	resetBindable.Event:Connect(handleReset)
	
	-- Set the callback when character spawns - CoreScripts need time to register ResetButtonCallback
	local starterGui = game:GetService("StarterGui")
	local runService = game:GetService("RunService")
	
	local maxRetries = 10
	local success = false
	
	for attempt = 1, maxRetries do
		success = pcall(function()
			starterGui:SetCore("ResetButtonCallback", resetBindable)
		end)
		if success then
			_annotate(string.format("Reset button callback set (attempt %d)", attempt))
			return
		end
		if attempt < maxRetries then
			runService.Heartbeat:Wait()
		end
	end
	
	-- If all retries failed, log error
	annotater.Error(string.format("Failed to set ResetButtonCallback after %d attempts", maxRetries))
	resetBindable:Destroy()
end

function module.Init()
	-- Set callback for existing character if present
	if localPlayer.Character then
		setupResetCallback()
	end

	-- Set callback when character spawns
	localPlayer.CharacterAdded:Connect(function()
		setupResetCallback()
	end)
end

_annotate(string.format("end"))
return module
