--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)

local module = {}

local sounds = {
	["pulse_launch"] = 5020637878,
}

local soundFolder: Folder

-- setup shared sound folder.
local foundFolder: Instance? = game.ReplicatedStorage:FindFirstChild("Sounds")
if foundFolder and foundFolder:IsA("Folder") then
	soundFolder = foundFolder :: Folder
else
	soundFolder = Instance.new("Folder")
	soundFolder.Name = "Sounds"
	soundFolder.Parent = game.ReplicatedStorage
end

local function getSound(soundAssetId: number): Sound
	local soundInstance: Instance? = soundFolder:FindFirstChild(tostring(soundAssetId))
	if soundInstance and soundInstance:IsA("Sound") then
		return soundInstance :: Sound
	end
	local sound: Sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. tostring(soundAssetId)
	sound.Parent = soundFolder
	return sound
end

module.Init = function()
	for soundName, soundAssetId in pairs(sounds) do
		local sound: Sound = getSound(soundAssetId)
		sound.Name = soundName
		_annotate("preloading: " .. soundName)
		sound:Play() -- Preload the sound by playing it once
		sound:Stop() -- Immediately stop the sound to prevent it from being heard
	end
end

local function playSoundFromSign(sign: Part, soundName: string)
	local sound = getSound(sounds[soundName])
	sound.Name = soundName
	local exi: Sound? = sign:FindFirstChild(soundName) :: Sound
	if exi then
		_annotate(string.format("replaying old one. %s", sign.Name))
		exi:Play()
	else
		_annotate(string.format("adding and play.. %s", sign.Name))
		sound.Parent = sign
		sound:Play()
	end
end

module.playSoundFromSign = playSoundFromSign

_annotate("end")
return module
