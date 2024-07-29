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
local banMonitor = require(game.StarterPlayer.StarterCharacterScripts.client.banMonitor)
local notifier = require(game.StarterPlayer.StarterCharacterScripts.client.notifier)
local serverEvents = require(game.StarterPlayer.StarterCharacterScripts.client.serverEvents)
local leaderboard = require(game.StarterPlayer.StarterCharacterScripts.client.leaderboard)
local avatarEventMonitor = require(game.StarterPlayer.StarterCharacterScripts.client.avatarEventMonitor)
local warper = require(game.StarterPlayer.StarterPlayerScripts.warper)
local commands = require(game.StarterPlayer.StarterCharacterScripts.client.commands)
local textHighlighting = require(game.ReplicatedStorage.gui.textHighlighting)
local racing = require(game.StarterPlayer.StarterCharacterScripts.client.racing)
local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid: Humanoid = character:WaitForChild("Humanoid") :: Humanoid
local keyboard = require(game.StarterPlayer.StarterCharacterScripts.client.keyboard)

---------- CALL INIT ON ALL THOSE THINGS SINCE THEY'RE STILL LOADED ONLY ONE TIME even if the user resets or dies etc. -----------
local setup = function()
	character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	movement.Init()
	morphs.Init()
	particles.Init()
	notifier.Init()

	serverEvents.Init()
	leaderboard.Init()
	avatarEventMonitor.Init()
	warper.Init()
	commands.Init()
	textHighlighting.Init()
	keyboard.Init()

	-- you can't race til everything is set up.
	racing.Init()
	print("client main setup done.")
end

_annotate("outer layer of main.client.")
setup()

--- UGH handling resetting avatars is super nasty. why?----------------------
local resetBindable = Instance.new("BindableEvent")
resetBindable.Event:Connect(function()
	print("the player reset now.")
	if character and humanoid then
		print("killin player")
		humanoid.Health = 0
	else
		print("failed killin player")
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
