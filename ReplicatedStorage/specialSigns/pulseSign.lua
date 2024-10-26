--!strict

-- pulseSign

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local specialSign = {}
local tt = require(game.ReplicatedStorage.types.gametypes)

local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer
local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
local _humanoid = character:WaitForChild("Humanoid") :: Humanoid

----------- GLOBALS -----------
local pulseLaunchDebounce = false

-------------- MAIN --------------
specialSign.InformRunEnded = function()
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
	local verticalAngle = math.rad(pulseRandom:NextInteger(30, 90))
	local horizontalAngle = math.rad(pulseRandom:NextInteger(0, 360))
	local pulsePower = pulseRandom:NextInteger(220, 1390)
	local y = math.sin(verticalAngle)
	local horizontalComponent = math.cos(verticalAngle)
	local x = horizontalComponent * math.cos(horizontalAngle)
	local z = horizontalComponent * math.sin(horizontalAngle)

	local direction = Vector3.new(x, y, z).Unit
	local thisServerPulseVector = direction * pulsePower
	character.PrimaryPart.AssemblyLinearVelocity = thisServerPulseVector
	pulseLaunchDebounce = false
end

specialSign.InformRetouch = function()
	if pulseLaunchDebounce then
		return
	end
	DoLaunchForPulse()
end

specialSign.InformRunStarting = function()
	pulseLaunchDebounce = false
	character = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	DoLaunchForPulse()
end

specialSign.CanRunEnd = function(): tt.runEndExtraDataForRacing
	return {
		canRunEndNow = true,
	}
end

specialSign.GetName = function()
	return "Pulse"
end

specialSign.InformSawFloorDuringRunFrom = function(floorMaterial: Enum.Material?) end
local module: tt.SpecialSignInterface = specialSign
_annotate("end")
return module
