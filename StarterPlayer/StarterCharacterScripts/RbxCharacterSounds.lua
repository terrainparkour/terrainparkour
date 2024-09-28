--!strict

--[[
	Author: @spotco
	This script creates sounds which are placed under the character head.
	These sounds are used by the "LocalSound" script.

	To modify this script, copy it to your "StarterPlayer/StarterCharacterScripts" folder keeping the same script name ("Sound").
	The default Sound script loaded for every character will then be replaced with your copy of the script.
]]

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local SOUND_EVENT_FOLDER_NAME = "DefaultSoundEvents"
local DEFAULT_SERVER_SOUND_EVENT_NAME = "DefaultServerSoundEvent"

local SoundEventFolder: Folder = ReplicatedStorage:FindFirstChild(SOUND_EVENT_FOLDER_NAME)
local DefaultServerSoundEvent = nil

if not SoundEventFolder then
	SoundEventFolder = Instance.new("Folder")
	SoundEventFolder.Name = SOUND_EVENT_FOLDER_NAME
	SoundEventFolder.Archivable = false
	SoundEventFolder.Parent = ReplicatedStorage
end

DefaultServerSoundEvent = SoundEventFolder:FindFirstChild(DEFAULT_SERVER_SOUND_EVENT_NAME)

if not DefaultServerSoundEvent then
	DefaultServerSoundEvent = Instance.new("RemoteEvent", SoundEventFolder)

	DefaultServerSoundEvent.Name = DEFAULT_SERVER_SOUND_EVENT_NAME
	DefaultServerSoundEvent.OnServerEvent:Connect(function() end)
end

local function CreateNewSound(name, id, looped, pitch, parent, volume: number?)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Name = name
	sound.archivable = false
	sound.Pitch = pitch
	sound.Looped = looped
	sound.MinDistance = 5
	sound.MaxDistance = 150
	if volume == nil then
		volume = 0.65
	end
	sound.Volume = volume
	sound.Parent = parent

	if DefaultServerSoundEvent then
		local CharacterSoundEvent = Instance.new("RemoteEvent", sound)
		CharacterSoundEvent.Name = "CharacterSoundEvent"
		CharacterSoundEvent.OnServerEvent:Connect(function(player, playing, resetPosition)
			if type(playing) ~= "boolean" then
				return
			end
			if type(resetPosition) ~= "boolean" then
				return
			end

			if player.Character ~= script.Parent then
				return
			end
			for _, p in pairs(Players:GetPlayers()) do
				if p ~= player then
					-- Connect to the dispatcher to check if the player has loaded.
					local soundDispatcher = SoundEventFolder:FindFirstChild("SoundDispatcher")
					soundDispatcher:Fire(p, sound, playing, resetPosition)
				end
			end
		end)
	end
	return sound
end

local head = script.Parent:FindFirstChild("Head")
if not head then
	annotater.Error("Sound script parent has no child Head.")
	return
end

local audio = require(game.ReplicatedStorage.util.audio)

CreateNewSound("GettingUp", "rbxasset://sounds/action_get_up.mp3", false, 1, head)
CreateNewSound("Died", "rbxassetid://" .. tostring(audio.audios.oof.assetId), false, 1, head)
CreateNewSound("FreeFalling", "rbxasset://sounds/action_falling.mp3", true, 1, head)
CreateNewSound("Jumping", "rbxasset://sounds/action_jump.mp3", false, 1, head)
CreateNewSound("Landing", "rbxasset://sounds/action_jump_land.mp3", false, 1, head)
CreateNewSound("Splash", "rbxasset://sounds/impact_water.mp3", false, 1, head)
CreateNewSound("Running", "rbxassetid://" .. tostring(audio.audios.runningConcrete.assetId), true, 1, head)
CreateNewSound("Swimming", "rbxassetid://" .. tostring(audio.audios.runningMuddy.assetId), true, 1, head, 0.15)
CreateNewSound("Climbing", "rbxasset://sounds/action_footsteps_plastic.mp3", true, 1, head)
_annotate("end")
