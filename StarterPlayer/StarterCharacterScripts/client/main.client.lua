--!strict

-- client main loader. it loads (by requiring in order) all the client modulescripts in the client folder.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
annotater.Init()

-------- GENERAL CLIENT SETUP -----------
game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
game.Workspace.CurrentCamera.FieldOfView = (70 + (5 * 2))
local localPlayer: Player = game:GetService("Players").LocalPlayer

localPlayer.CameraMaxZoomDistance = 11999

local movement = require(game.StarterPlayer.StarterCharacterScripts.client.movement)
local morphs = require(game.StarterPlayer.StarterCharacterScripts.client.morphs)
local particles = require(game.StarterPlayer.StarterCharacterScripts.client.particles)
local userData = require(game.StarterPlayer.StarterPlayerScripts.userData)
userData.Init()
local notifyClient = require(game.StarterPlayer.StarterCharacterScripts.client.notifyClient)
local serverEvents = require(game.StarterPlayer.StarterCharacterScripts.client.serverEvents)

local MovementLogger = require(game.ReplicatedStorage.ReplayModified.Replay)

local ChatUI = require(game.ReplicatedStorage.ChatSystem.Chat)

local userDataClient = require(game.StarterPlayer.StarterPlayerScripts.userDataClient)
local leaderboard = require(game.StarterPlayer.StarterCharacterScripts.lb.leaderboard)
local marathonClient = require(game.StarterPlayer.StarterCharacterScripts.client.marathonClient)
local avatarEventMonitor = require(game.StarterPlayer.StarterCharacterScripts.client.avatarEventMonitor)
local warper = require(game.StarterPlayer.StarterPlayerScripts.warper)
local clientCommands = require(game.StarterPlayer.StarterCharacterScripts.client.clientCommands)
local textHighlighting = require(game.ReplicatedStorage.gui.textHighlighting)
local settings = require(game.ReplicatedStorage.settings)
local racing = require(game.StarterPlayer.StarterCharacterScripts.client.racing)
-- local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait()
-- local humanoid: Humanoid = character:WaitForChild("Humanoid") :: Humanoid
local localSignClickability = require(game.StarterPlayer.StarterPlayerScripts.guis.localSignClickability)
-- local avatarManipulation = require(game.ReplicatedStorage.avatarManipulation)
local keyboard = require(game.StarterPlayer.StarterCharacterScripts.client.keyboard)
-- local aet = require(game.ReplicatedStorage.avatarEventTypes)
local resetCharacterSetup = require(game.StarterPlayer.StarterCharacterScripts.client.resetCharacterSetup)
local drawRunResultsGui = require(game.ReplicatedStorage.gui.runresults.drawRunResultsGui)
local drawWRHistoryProgressionGui = require(game.ReplicatedStorage.gui.menu.drawWRHistoryProgressionGui)
local contestButtonGetter = require(game.StarterPlayer.StarterPlayerScripts.buttons.contestButtonGetter)

---------- CALL INIT ON ALL THOSE THINGS SINCE THEY'RE STILL LOADED ONLY ONE TIME even if the user resets or dies etc. -----------
local setup = function()
	settings.Reset()

	-- character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	-- humanoid = character:WaitForChild("Humanoid") :: Humanoid
	userDataClient.Init()
	ChatUI:Initialize()
	movement.Init()
	morphs.Init()
	MovementLogger.Init()
	
	particles.Init()
	notifyClient.Init()
	serverEvents.Init()
	leaderboard.Init()
	marathonClient.Init()
	avatarEventMonitor.Init()
	warper.Init()
	clientCommands.Init()
	textHighlighting.Init()
	localSignClickability.Init()
	keyboard.Init()
	resetCharacterSetup.Init()
	drawRunResultsGui.Init()
	drawWRHistoryProgressionGui.Init()
	contestButtonGetter.Init()
	-- you can't race til everything is set up.
	racing.Init()
	_annotate("client main setup done.")
end

setup()

_annotate("end")