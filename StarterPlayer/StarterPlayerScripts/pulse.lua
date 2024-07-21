local module = {}
--FOR SETTING UP TODAY's PULSE amount and direction.
--this is global so that it doesn't change per server.

module.DoLaunchForPulse = function(character: Model, player: Player)
	-- local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: Part
	local daysSince1970 = os.difftime(
		os.time(),
		os.time({ year = 1970, month = 1, day = 1, hour = 0, min = 0, sec = 0, isdst = false })
	) / 86400
	local seed = math.floor(daysSince1970)
	local pulseRandom = Random.new(seed) :: Random
	local verticalAngle = math.rad(pulseRandom:NextInteger(45, 90))
	local horizontalAngle = math.rad(pulseRandom:NextInteger(0, 359))
	local pulsePower = pulseRandom:NextInteger(400, 2600)
	print("pulsePower: " .. tostring(pulsePower))
	local y = math.sin(verticalAngle)
	local horizontalComponent = math.cos(verticalAngle)
	local x = horizontalComponent * math.cos(horizontalAngle)
	local z = horizontalComponent * math.sin(horizontalAngle)

	local direction = Vector3.new(x, y, z).Unit
	local thisServerPulseVector = direction * pulsePower
	character.PrimaryPart.AssemblyLinearVelocity = thisServerPulseVector
end

return module
