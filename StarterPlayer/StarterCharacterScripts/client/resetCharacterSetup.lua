--!strict

-- resetCharacterSetup.lua - StarterPlayer/StarterCharacterScripts/client
-- Routes Reset button presses through avatar events and enforces respawn.
-- client main loader. it loads (by requiring in order) all the client modulescripts in the client folder.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate: (string, any?) -> () = annotater.getAnnotater(script)
annotater.Init()

local players: Players = game:GetService("Players")
local runService: RunService = game:GetService("RunService")
local starterGui: StarterGui = game:GetService("StarterGui")

local aet = require(game.ReplicatedStorage.avatarEventTypes)
local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)

type AvatarEventDetails = aet.avatarEventDetails
type FireEventFn = (avatarEventType: number, details: AvatarEventDetails) -> ()
type Module = {
	Init: () -> (),
}

local module: Module = {
	Init = function() end,
}
local localPlayer: Player = players.LocalPlayer
local fireEvent: FireEventFn = avatarEventFiring.FireEvent
local resetSequence = 0

local function getHumanoid(targetCharacter: Model?): Humanoid?
	if not targetCharacter then
		-- target may no longer exist if character already despawned
		return nil
	end

	local humanoidInstance = targetCharacter:FindFirstChild("Humanoid")
	if humanoidInstance and humanoidInstance:IsA("Humanoid") then
		return humanoidInstance
	end

	local waitedHumanoid: Instance? = targetCharacter:WaitForChild("Humanoid")
	if waitedHumanoid and waitedHumanoid:IsA("Humanoid") then
		return waitedHumanoid
	end

	return nil
end

local function handleReset()
	resetSequence += 1
	_annotate(string.format("handleReset start seq=%d", resetSequence))
	local resetEventDetails: AvatarEventDetails = { sender = "resetCharacterSetup" }
	fireEvent(aet.avatarEventTypes.AVATAR_RESET, resetEventDetails)

	local character: Model? = localPlayer.Character
	local humanoid: Humanoid? = getHumanoid(character)

	if character and humanoid then
		_annotate(string.format("killing player seq=%d", resetSequence))
		humanoid.Health = 0
	else
		_annotate(string.format("failed killing player seq=%d character=%s humanoid=%s", resetSequence, tostring(character ~= nil), tostring(humanoid ~= nil)))
	end

	if not character then
		_annotate(string.format("handleReset end seq=%d (no character)", resetSequence))
		return
	end

	local didDie = false
	local currentCharacter: Model = character

	task.spawn(function()
		while true do
			local humanoidInstance = currentCharacter:FindFirstChild("Humanoid")
			if not humanoidInstance or not humanoidInstance:IsA("Humanoid") then
				didDie = true
				_annotate(string.format("handleReset seq=%d waiting for respawn (no humanoid)", resetSequence))
				task.wait(0.01)
			else
				local currentHumanoid: Humanoid = humanoidInstance
				task.wait(0.01)
				if didDie and currentHumanoid.Health > 0 then
					_annotate(string.format("handleReset seq=%d respawn detected health=%0.1f", resetSequence, currentHumanoid.Health))
					break
				end
			end
		end
		_annotate(string.format("handleReset end seq=%d", resetSequence))
	end)
end

local function setupResetCallback()
	-- Clear any existing BindableEvent
	local resetBindable: BindableEvent = Instance.new("BindableEvent")
	resetBindable.Event:Connect(handleReset)

	-- Set the callback when character spawns - CoreScripts need time to register ResetButtonCallback
	local maxRetries = 10
	local success = false
	local lastError: any = nil

	for attempt = 1, maxRetries do
		success, lastError = pcall(function()
			starterGui:SetCore("ResetButtonCallback", resetBindable)
		end)
		if success then
			_annotate(string.format("Reset button callback set (attempt %d)", attempt))
			return
		end
		_annotate(string.format("Reset button callback attempt %d failed: %s", attempt, tostring(lastError)))
		if attempt < maxRetries then
			runService.Heartbeat:Wait()
		end
	end

	-- If all retries failed, log error
	annotater.Error(
		string.format(
			"Failed to set ResetButtonCallback after %d attempts (last error: %s)",
			maxRetries,
			tostring(lastError)
		)
	)
	resetBindable:Destroy()
end

function module.Init()
	-- Set callback for existing character if present
	if localPlayer.Character then
		setupResetCallback()
	end

	-- Set callback when character spawns
	localPlayer.CharacterAdded:Connect(function()
		_annotate("CharacterAdded -> setupResetCallback")
		setupResetCallback()
	end)
end

_annotate("end")
return module
