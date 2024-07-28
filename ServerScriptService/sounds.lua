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

local function getSound(soundAssetId: number)
	local sound = soundFolder:FindFirstChild(tostring(soundAssetId))
	if sound == nil then
		sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://" .. soundAssetId
		sound.Parent = soundFolder
	end
	return sound
end

local function init()
	for soundName, soundAssetId in pairs(sounds) do
		local sound = getSound(soundAssetId)
		sound.Name = soundName
		_annotate("preloading: " .. soundName)
		sound:Play() -- Preload the sound by playing it once
		sound:Stop() -- Immediately stop the sound to prevent it from being heard
	end
end

module.init = init

local function playSoundFromSign(sign: Part, soundName: string)
	local sound = getSound(sounds[soundName])
	sound.Name = soundName
	local exi = sign:FindFirstChild(soundName) :: Sound
	if exi then
		_annotate("replaying old one.", sign.Name)
		exi:Play()
	else
		_annotate("adding and play..", sign.Name)
		sound.Parent = sign
		sound:Play()
	end
end

module.playSoundFromSign = playSoundFromSign

_annotate("end")
return module
