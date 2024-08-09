--!strict

-- client main loader. it loads (by requiring in order) all the client modulescripts in the client folder.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

-------- GENERAL CLIENT SETUP -----------
game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
game.Workspace.CurrentCamera.FieldOfView = (70 + (5 * 2))
local localPlayer: Player = game.Players.LocalPlayer

localPlayer.CameraMaxZoomDistance = 8999

local movement = require(game.StarterPlayer.StarterCharacterScripts.client.movement)
local morphs = require(game.StarterPlayer.StarterCharacterScripts.client.morphs)
local particles = require(game.StarterPlayer.StarterCharacterScripts.client.particles)

local notifier = require(game.StarterPlayer.StarterCharacterScripts.client.notifier)
local serverEvents = require(game.StarterPlayer.StarterCharacterScripts.client.serverEvents)

local leaderboard = require(game.StarterPlayer.StarterCharacterScripts.client.leaderboard)
local marathonClient = require(game.StarterPlayer.StarterCharacterScripts.client.marathonClient)
local avatarEventMonitor = require(game.StarterPlayer.StarterCharacterScripts.client.avatarEventMonitor)
local warper = require(game.StarterPlayer.StarterPlayerScripts.warper)
local commands = require(game.StarterPlayer.StarterCharacterScripts.client.commands)
local textHighlighting = require(game.ReplicatedStorage.gui.textHighlighting)
local settings = require(game.ReplicatedStorage.settings)
local racing = require(game.StarterPlayer.StarterCharacterScripts.client.racing)
local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid: Humanoid = character:WaitForChild("Humanoid") :: Humanoid

local keyboard = require(game.StarterPlayer.StarterCharacterScripts.client.keyboard)
local mt = require(game.ReplicatedStorage.avatarEventTypes)

---------- CALL INIT ON ALL THOSE THINGS SINCE THEY'RE STILL LOADED ONLY ONE TIME even if the user resets or dies etc. -----------
local setup = function()
	character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	movement.Init()
	morphs.Init()
	particles.Init()
	notifier.Init()
	settings.Reset()
	serverEvents.Init()
	leaderboard.Init()
	marathonClient.Init()
	avatarEventMonitor.Init()
	warper.Init()
	commands.Init()
	textHighlighting.Init()
	keyboard.Init()
	serverEvents.Init()

	-- you can't race til everything is set up.
	racing.Init()
	print("client main setup done.")
end

setup()

local resetBindable = Instance.new("BindableEvent")
resetBindable.Event:Connect(function()
	local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
	local fireEvent = avatarEventFiring.FireEvent
	fireEvent(mt.avatarEventTypes.AVATAR_RESET, {})
	-- _annotate("the player reset now.")
	if character and humanoid then
		-- print("killin player")
		humanoid.Health = 0
	else
		warn("failed killin player")
	end
	local didDie = false
	while true do
		humanoid = character:WaitForChild("Humanoid") :: Humanoid
		if not humanoid then
			didDie = true
			wait(0.01)
		end
		wait(0.01)
		if didDie then
			if humanoid.Health > 0 then
				break
			end
		end
	end
	setup()
end)

-- This will remove the current behavior for when the reset button
-- is pressed and just fire resetBindable instead.
game:GetService("StarterGui"):SetCore("ResetButtonCallback", resetBindable)

_annotate("end")
