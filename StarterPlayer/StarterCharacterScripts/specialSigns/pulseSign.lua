--!strict

-- pulseSign

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer
local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

----------- GLOBALS -----------
local pulseLaunchDebounce = false

-------------- MAIN --------------
module.InformRunEnded = function()
	pulseLaunchDebounce = false
end

local DoLaunchForPulse = function()
	if pulseLaunchDebounce then
		return
	end
	pulseLaunchDebounce = true

	local daysSince1970 = os.difftime(
		os.time(),
		os.time({ year = 1970, month = 1, day = 1, hour = 0, min = 0, sec = 0, isdst = false })
	) / 86400
	local seed = math.floor(daysSince1970)
	local pulseRandom = Random.new(seed) :: Random
	local verticalAngle = math.rad(pulseRandom:NextInteger(45, 90))
	local horizontalAngle = math.rad(pulseRandom:NextInteger(0, 359))
	local pulsePower = pulseRandom:NextInteger(200, 1300)
	local y = math.sin(verticalAngle)
	local horizontalComponent = math.cos(verticalAngle)
	local x = horizontalComponent * math.cos(horizontalAngle)
	local z = horizontalComponent * math.sin(horizontalAngle)

	local direction = Vector3.new(x, y, z).Unit
	local thisServerPulseVector = direction * pulsePower
	character.PrimaryPart.AssemblyLinearVelocity = thisServerPulseVector
	pulseLaunchDebounce = false
end

module.InformRetouch = function()
	if pulseLaunchDebounce then
		return
	end
	DoLaunchForPulse()
end

module.InformRunStarting = function()
	pulseLaunchDebounce = false
	character = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	DoLaunchForPulse()
end

module.InformSawFloorDuringRunFrom = function(floorMaterial: Enum.Material?) end

_annotate("end")
return module
