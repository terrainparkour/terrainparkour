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

local SoundEventFolder: Folder = (function(): Folder
	local existingFolder = ReplicatedStorage:FindFirstChild(SOUND_EVENT_FOLDER_NAME)
	if existingFolder and existingFolder:IsA("Folder") then
		return existingFolder
	else
		local newFolder = Instance.new("Folder")
		newFolder.Name = SOUND_EVENT_FOLDER_NAME
		newFolder.Archivable = false
		newFolder.Parent = ReplicatedStorage
		return newFolder
	end
end)()

local DefaultServerSoundEvent = nil

local foundEvent = SoundEventFolder:FindFirstChild(DEFAULT_SERVER_SOUND_EVENT_NAME)
if foundEvent and foundEvent:IsA("RemoteEvent") then
	DefaultServerSoundEvent = foundEvent
else

	DefaultServerSoundEvent = Instance.new("RemoteEvent")
	DefaultServerSoundEvent.Name = DEFAULT_SERVER_SOUND_EVENT_NAME
	DefaultServerSoundEvent.Parent = SoundEventFolder
	DefaultServerSoundEvent.OnServerEvent:Connect(function() end)
end

local function CreateNewSound(name, id, looped, pitch, parent, volume: number?)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Name = name
	sound.Archivable = false
	sound.PlaybackSpeed = pitch
	sound.Looped = looped
	local finalVolume: number = volume or 0.65
	sound.Volume = finalVolume
	sound.Parent = parent

	if DefaultServerSoundEvent then
		local CharacterSoundEvent = Instance.new("RemoteEvent")
		CharacterSoundEvent.Name = "CharacterSoundEvent"
		CharacterSoundEvent.Parent = sound
		CharacterSoundEvent.OnServerEvent:Connect(function(player, playing, resetPosition)
			if type(playing) ~= "boolean" then
				return
			end
			if type(resetPosition) ~= "boolean" then
				return
			end

			-- script.Parent is the character at runtime (this script is in StarterCharacterScripts)
			if player.Character ~= (script.Parent :: any) then
				return
			end
			for _, p in pairs(Players:GetPlayers()) do
				if p ~= player then
					-- Connect to the dispatcher to check if the player has loaded.
					local soundDispatcher = SoundEventFolder:FindFirstChild("SoundDispatcher")
					if soundDispatcher and soundDispatcher:IsA("RemoteEvent") then
						soundDispatcher:FireClient(p, sound, playing, resetPosition)
					end
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
