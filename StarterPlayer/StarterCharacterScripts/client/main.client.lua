--!strict

-- client main loader. it loads (by requiring in order) all the client modulescripts in the client folder.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

-------- GENERAL CLIENT SETUP -----------
game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
game.Workspace.CurrentCamera.FieldOfView = (70 + (5 * 2))
game.Players.LocalPlayer.CameraMaxZoomDistance = 8999

---------- LOAD ALL THE MODULESCRIPTS WHICH WERE PREVIOUSLY LOCALSCRIPTS-----------
repeat
	game:GetService("RunService").RenderStepped:wait()
until game.Players.LocalPlayer.Character ~= nil

local movement = require(game.StarterPlayer.StarterCharacterScripts.client.movement)
local morphs = require(game.StarterPlayer.StarterCharacterScripts.client.morphs)
local particles = require(game.StarterPlayer.StarterCharacterScripts.client.particles)
local fallRespawn = require(game.StarterPlayer.StarterCharacterScripts.client.fallRespawn)
local banMonitor = require(game.StarterPlayer.StarterCharacterScripts.client.banMonitor)
local notifier = require(game.StarterPlayer.StarterCharacterScripts.client.notifier)
local serverEvents = require(game.StarterPlayer.StarterCharacterScripts.client.serverEvents)
local leaderboard = require(game.StarterPlayer.StarterCharacterScripts.client.leaderboard)
local monitor = require(game.StarterPlayer.StarterCharacterScripts.client.avatarEventMonitor)
local warper = require(game.StarterPlayer.StarterPlayerScripts.warper)
warper.Init()

-- you can't race til everything is set up.
local racing = require(game.StarterPlayer.StarterCharacterScripts.client.racing)

_annotate("end")
