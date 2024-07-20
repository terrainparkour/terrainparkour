local module = {}
--FOR SETTING UP TODAY's PULSE amount and direction.
--this is global so that it doesn't change per server.
local seedTick = tick()

module.DoLaunchForPulse = function(character: Model, player: Player)
	-- local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: Part

	local seed = seedTick / 86400
	local pulseRandom = Random.new(seed) :: Random
	local verticalAngle = math.rad(pulseRandom:NextInteger(45, 90))
	local horizontalAngle = math.rad(pulseRandom:NextInteger(0, 359))
	local pulsePower = pulseRandom:NextInteger(400, 1600)
	local y = math.sin(verticalAngle)
	local horizontalComponent = math.cos(verticalAngle)
	local x = horizontalComponent * math.cos(horizontalAngle)
	local z = horizontalComponent * math.sin(horizontalAngle)

	local direction = Vector3.new(x, y, z).Unit
	local thisServerPulseVector = direction * pulsePower
	character.PrimaryPart.AssemblyLinearVelocity = thisServerPulseVector
end

return module
