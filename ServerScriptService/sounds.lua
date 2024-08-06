--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)

local module = {}

local sounds = {
	["pulse_launch"] = 5020637878,
}

local soundFolder = nil

-- setup shared sound folder.
if game.ReplicatedStorage:FindFirstChild("Sounds") then
	soundFolder = game.ReplicatedStorage:FindFirstChild("Sounds")
else
	soundFolder = Instance.new("Folder")
	soundFolder.Name = "Sounds"
	soundFolder.Parent = game.ReplicatedStorage
end

local function getSound(soundAssetId: number): Sound
	local sound = soundFolder:FindFirstChild(tostring(soundAssetId))
	if sound == nil then
		sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://" .. soundAssetId
		sound.Parent = soundFolder
	end
	return sound
end

module.Init = function()
	for soundName, soundAssetId in pairs(sounds) do
		local sound: Sound = getSound(soundAssetId)
		sound.Name = soundName
		--_annotate("preloading: " .. soundName)
		sound:Play() -- Preload the sound by playing it once
		sound:Stop() -- Immediately stop the sound to prevent it from being heard
	end
end

local function playSoundFromSign(sign: Part, soundName: string)
	local sound = getSound(sounds[soundName])
	sound.Name = soundName
	local exi = sign:FindFirstChild(soundName) :: Sound
	if exi then
		--_annotate(string.format("replaying old one. %s", sign.Name))
		exi:Play()
	else
		--_annotate(string.format("adding and play.. %s", sign.Name))
		sound.Parent = sign
		sound:Play()
	end
end

module.playSoundFromSign = playSoundFromSign

_annotate("end")
return module
