--!strict

-- client main loader. it loads (by requiring in order) all the client modulescripts in the client folder.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
annotater.Init()

local module = {}
local aet = require(game.ReplicatedStorage.avatarEventTypes)
local localPlayer: Player = game.Players.LocalPlayer
local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local fireEvent = avatarEventFiring.FireEvent

-- Store the current BindableEvent
local resetBindable: BindableEvent? = nil

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
	task.spawn(function()
		while true do
			humanoid = character:WaitForChild("Humanoid") :: Humanoid
			if not humanoid then
				didDie = true
				task.wait(0.01)
			end
			task.wait(0.01)
			if didDie and humanoid.Health > 0 then
				break
			end
		end
	end)
end

function module.Init()
	-- Clear any existing BindableEvent
	if resetBindable then
		resetBindable:Destroy()
	end

	-- Create a new BindableEvent
	resetBindable = Instance.new("BindableEvent")
	resetBindable.Event:Connect(handleReset)

	-- Set the new callback
	game:GetService("StarterGui"):SetCore("ResetButtonCallback", resetBindable)

	_annotate(string.format("Reset button callback set"))
end

_annotate(string.format("end"))
return module
