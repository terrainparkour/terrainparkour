--!strict

-- particleEnums.lua
-- descriptors for particle emission from the player, with color, state etc.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local tt = require(game.ReplicatedStorage.types.gametypes)

---------- HERE IS THE TYPE DEFINITION INCLUDED ABOVE FOR YOUR CONVENIENCE. DO NOT MODIFY THIS PART. ------------------
-- each one has a specific use case, and the other particle aspects to it.
-- export type particleDescriptor = {
-- 	acceleration: Vector3,
-- 	brightness: number,
-- 	color: ColorSequence | Color3,
-- 	direction: Enum.NormalId,
-- 	drag: number,
-- 	durationMETA: number,
-- 	emissionDirection: Enum.NormalId,
-- 	-- duration: number,
-- 	-- falloff: number,
-- 	lifetime: NumberRange,
-- 	name: string,
-- 	orientation: Enum.ParticleOrientation,
-- 	rate: number,
-- 	rotation: NumberRange,
-- 	rotSpeed: NumberRange,
-- 	shape: Enum.ParticleEmitterShape?,
-- 	-- shapeColor: Color3?,
-- 	shapeInOut: Enum.ParticleEmitterShapeInOut?,
-- 	shapeStyle: Enum.ParticleEmitterShapeStyle?,
-- 	size: NumberSequence,
-- 	speed: NumberRange,
-- 	spreadAngle: Vector2,
-- 	squash: NumberSequence?,
-- 	texture: string?,
-- 	transparency: NumberSequence,
-- 	velocityInheritance: number,
-- 	zOffset: number,
-- 	lightEmission: number,
-- }

-- local BRIGHTNESS = 1
-- local DRAG = 0.5
-- local DURATION = 1
-- local LIFETIME = NumberRange.new(0.4, 0.6)
-- local ORIENTATION = Enum.ParticleOrientation.

--[[
local a: tt.particleDescriptor = {
    acceleration = Vector3.new(random:NextNumber(-10, 10), random:NextNumber(-10, 10), random:NextNumber(-10, 10)),
    brightness = BRIGHTNESS,
    color = colors.,
    direction = Enum.NormalId:GetEnumItems()[random:NextInteger(1, #Enum.NormalId:GetEnumItems())],
    drag = DRAG,
    durationMETA = DURATION,
    emissionDirection = Enum.NormalId:GetEnumItems()[random:NextInteger(1, #Enum.NormalId:GetEnumItems())],
    lifetime = LIFETIME
    name = key,
    orientation = Enum.ParticleOrientation:GetEnumItems()[random:NextInteger(
        1,
        #Enum.ParticleOrientation:GetEnumItems()
    )],
    rate = random:NextNumber(1, 100),
    rotation = NumberRange.new(c, d),
    rotSpeed = NumberRange.new(g, h),
    shape = Enum.ParticleEmitterShape:GetEnumItems()[random:NextInteger(1, #Enum.ParticleEmitterShape:GetEnumItems())],
    shapeColor = Color3.new(random:NextNumber(0, 1), random:NextNumber(0, 1), random:NextNumber(0, 1)),
    shapeInOut = Enum.ParticleEmitterShapeInOut:GetEnumItems()[random:NextInteger(
        1,
        #Enum.ParticleEmitterShapeInOut:GetEnumItems()
    )],
    shapeStyle = Enum.ParticleEmitterShapeStyle:GetEnumItems()[random:NextInteger(
        1,
        #Enum.ParticleEmitterShapeStyle:GetEnumItems()
    )],
    size = NumberSequence.new(random:NextNumber(0.1, 10), random:NextNumber(0.1, 10)),
    speed = NumberRange.new(e, f),
    spreadAngle = Vector2.new(random:NextNumber(0, 180), random:NextNumber(0, 180)),
    squash = NumberSequence.new(random:NextNumber(0.1, 10), random:NextNumber(0.1, 10)),
    texture = nil,
    -- texture = "rbxassetid://" .. random:NextInteger(1, 10000000),
    transparency = NumberSequence.new(random:NextNumber(0, 1), random:NextNumber(0, 1)),
    velocityInheritance = random:NextNumber(0, 1),
    zOffset = random:NextNumber(-10, 10),
}]]

local LIGHTEMISSION = 10
local ACCELERATION = Vector3.new(0, 0, 0)
local TRANSPARENCY = NumberSequence.new(0.2)
local VELOCITYINHERITANCE = 0.03
local LIGHTINFLUENCE = 0
local ORIENTATION = Enum.ParticleOrientation.FacingCamera
local ZOFFSET = 0
local EMISSIONDIRECTION = Enum.NormalId.Back
local LIFETIME = NumberRange.new(0.1, 1.2)
local RATE = 1500
local SIZE = NumberSequence.new(0.5)
local SPEED = NumberRange.new(0, 5)
local DRAG = 1
local DURATIONMETA = 0.1
local TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SHAPE = Enum.ParticleEmitterShape.Sphere
local SHAPEINOUT = Enum.ParticleEmitterShapeInOut.Outward
local SHAPESTYLE = Enum.ParticleEmitterShapeStyle.Surface

local _OTHERTEXTURE = "rbxassetid://138530670729336"

local function AddDefaults(input: any): tt.particleDescriptor
	if input.shape == nil then
		input.shape = SHAPE
	end
	if input.shapeInOut == nil then
		input.shapeInOut = SHAPEINOUT
	end
	if input.shapeStyle == nil then
		input.shapeStyle = SHAPESTYLE
	end
	if input.lifetime == nil then
		input.lifetime = LIFETIME
	end
	if input.lightEmission == nil then
		input.lightEmission = LIGHTEMISSION
	end
	if input.velocityInheritance == nil then
		input.velocityInheritance = VELOCITYINHERITANCE
	end
	if input.orientation == nil then
		input.orientation = ORIENTATION
	end
	if input.emissionDirection == nil then
		input.emissionDirection = EMISSIONDIRECTION
	end
	if input.rate == nil then
		input.rate = RATE
	end
	if input.size == nil then
		input.size = SIZE
	end
	if input.speed == nil then
		input.speed = SPEED
	end
	if input.drag == nil then
		input.drag = DRAG
	end
	if input.durationMETA == nil then
		input.durationMETA = DURATIONMETA
	end
	if input.acceleration == nil then
		input.acceleration = ACCELERATION
	end
	if input.transparency == nil then
		input.transparency = TRANSPARENCY
	end
	if input.zOffset == nil then
		input.zOffset = ZOFFSET
	end
	if input.texture == nil then
		input.texture = TEXTURE
	end
	if input.lightInfluence == nil then
		input.lightInfluence = LIGHTINFLUENCE
	end
	return input
end

local speedup: tt.particleDescriptor = AddDefaults({
	brightness = 1.6,
	color = Color3.new(0.4, 1, 0.4), -- Light green
	name = "speedup",
	rotation = NumberRange.new(0, 0),
	rotSpeed = NumberRange.new(0, 0),
	spreadAngle = Vector2.new(0, 0),
	size = NumberSequence.new(0.6),
	transparency = NumberSequence.new(0, 1),
	durationMETA = 0.08,
	rate = 0,
	drag = 0.25,
	velocityInheritance = 0.1,
	speed = NumberRange.new(0),
	-- texture = OTHERTEXTURE,
})

-- local csp = ColorSequenceKeypoint.new(0, Color3.new(1, 0.4, 0.4))
local slowdown: tt.particleDescriptor = AddDefaults({
	brightness = 1.6,
	color = Color3.new(1, 0.4, 0.4),
	name = "slowdown",
	rotation = NumberRange.new(0, 0),
	rotSpeed = NumberRange.new(0.0),
	spreadAngle = Vector2.new(0, 0),
	size = NumberSequence.new(0.9),
	transparency = NumberSequence.new(0, 1),
	durationMETA = 0.08,
	rate = 0,
	drag = 0.5,
	velocityInheritance = 0.1,
	speed = NumberRange.new(0),
})

local runstart: tt.particleDescriptor = AddDefaults({
	name = "runstart",
	brightness = 1.2,
	rate = 10,
	velocityInheritance = -0.3,
	durationMETA = 0.2,
	texture = "rbxassetid://1266170131",
	transparency = NumberSequence.new(0, 1),
	lifetime = NumberRange.new(1.5),
	color = Color3.new(1, 1, 0.7),
	size = NumberSequence.new(1.8),
	zOffset = 10,
	rotation = NumberRange.new(-20, -10),
	rotSpeed = NumberRange.new(10, 90),
	spreadAngle = Vector2.new(2, 5),
	speed = NumberRange.new(0, 0.1),
	acceleration = Vector3.new(0, 0, 0),
})

local retouch: tt.particleDescriptor = AddDefaults({
	name = "retouch",
	brightness = 1.2,
	rate = 10,
	velocityInheritance = -0.3,
	durationMETA = 0.2,
	texture = "rbxassetid://1266170131",
	transparency = NumberSequence.new(0, 1),
	lifetime = NumberRange.new(1.5),
	color = Color3.new(1, 1, 0.7),
	size = NumberSequence.new(1.8),
	zOffset = 10,
	rotation = NumberRange.new(-20, -10),
	rotSpeed = NumberRange.new(10, 90),
	spreadAngle = Vector2.new(2, 5),
	speed = NumberRange.new(0, 0.1),
	acceleration = Vector3.new(0, 0, 0),
})

local _floorchanged: tt.particleDescriptor = AddDefaults({
	name = "floorchanged",
	brightness = 0.5,
	rate = 100,
	velocityInheritance = 0,
	durationMETA = 0.05,
	transparency = NumberSequence.new(0, 0.25),
	lifetime = NumberRange.new(0.1, 0.2),
	color = Color3.new(0.654901, 0.513725, 0.282352),
	size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 0.1),
	}),
	rotation = NumberRange.new(0, 0),
	rotSpeed = NumberRange.new(0, 0),
	spreadAngle = Vector2.new(90, 90),
	speed = NumberRange.new(7, 20),
})

local _runkill: tt.particleDescriptor = AddDefaults({
	name = "runkill",
	brightness = 1,
	color = Color3.new(0.1, 0.1, 0.1),
	rotation = NumberRange.new(0, 360),
	rotSpeed = NumberRange.new(-45, -45),
	spreadAngle = Vector2.new(30, 30),
	size = NumberSequence.new(4, 5),
	durationMETA = 0.2,
})

local _stoppedmoving: tt.particleDescriptor = AddDefaults({
	name = "stoppedmoving",
	brightness = 0.5,
	color = Color3.new(0.1, 0.1, 0.1),
	rotation = NumberRange.new(0, 360),
	rotSpeed = NumberRange.new(-45, -45),
	spreadAngle = Vector2.new(30, 30),
	size = NumberSequence.new(0.2, 0.3),
	durationMETA = 0.05,
	velocityInheritance = 0,
})

local runcomplete: tt.particleDescriptor = AddDefaults({
	name = "runcomplete",
	color = Color3.new(0.4, 0.7, 1),
	brightness = 2,
	rate = 100,
	velocityInheritance = 0,
	durationMETA = 3,
	texture = "rbxassetid://1266170131",
	transparency = NumberSequence.new(0, 1.0),
	speed = NumberRange.new(0, 9),
	lifetime = NumberRange.new(0.5),
	size = NumberSequence.new(3),
	rotation = NumberRange.new(0, 0),
	acceleration = Vector3.new(0, 10, 0),
	rotSpeed = NumberRange.new(0, 10),
	spreadAngle = Vector2.new(30, 30),
})

local particleDescriptors: { [string]: tt.particleDescriptor } = {}
particleDescriptors["speedup"] = speedup
particleDescriptors["slowdown"] = slowdown
particleDescriptors["runstart"] = runstart
particleDescriptors["runcomplete"] = runcomplete
-- particleDescriptors["runkill"] = runkill
particleDescriptors["retouch"] = retouch
-- particleDescriptors["stoppedmoving"] = stoppedmoving
-- particleDescriptors["floorchanged"] = floorchanged

local function printParticleDescriptor(desc: tt.particleDescriptor)
	-- Print out the specific keys and random values
	for key, value in pairs(desc) do
		if typeof(value) == "Vector3" then
			_annotate(string.format("%s: Vector3(%f, %f, %f)", key, value.X, value.Y, value.Z))
		elseif typeof(value) == "Color3" then
			_annotate(string.format("%s: Color3(%f, %f, %f)", key, value.R, value.G, value.B))
		elseif typeof(value) == "NumberRange" then
			_annotate(string.format("%s: NumberRange(%f, %f)", key, value.Min, value.Max))
		elseif typeof(value) == "NumberSequence" then
			_annotate(string.format("%s: NumberSequence(%f, %f)", key, value.Keypoints[1].Value, value.Keypoints[#value.Keypoints].Value))
		elseif typeof(value) == "Vector2" then
			_annotate(string.format("%s: Vector2(%f, %f)", key, value.X, value.Y))
		elseif typeof(value) == "EnumItem" then
			_annotate(string.format("%s: %s", key, tostring(value)))
		else
			_annotate(string.format("%s: %s", key, tostring(value)))
		end
	end
end

local _random: Random = Random.new(time())
local function getPairs(minn, maxx)
	local a = math.random(minn, maxx)
	local b = math.random(minn, maxx)
	a, b = math.min(a, b), math.max(a, b)
	return a, b
end

local function getRandomParticleDescriptor(userId: number, key: string): tt.particleDescriptor
	local random: Random = Random.new(time())
	local a, b = getPairs(1, 10)
	local c, d = getPairs(0, 360)
	local e, f = getPairs(0, 50)
	local g, h = getPairs(0, 500)

	local randomParticleDescriptor: tt.particleDescriptor = {
		acceleration = Vector3.new(random:NextNumber(-10, 10), random:NextNumber(-10, 10), random:NextNumber(-10, 10)),
		brightness = random:NextNumber(0, 100),
		color = Color3.new(random:NextNumber(0, 1), random:NextNumber(0, 1), random:NextNumber(0, 1)),
		direction = Enum.NormalId:GetEnumItems()[random:NextInteger(1, #Enum.NormalId:GetEnumItems())],
		drag = random:NextNumber(0, 5),
		durationMETA = random:NextNumber(0, 10),
		emissionDirection = Enum.NormalId:GetEnumItems()[random:NextInteger(1, #Enum.NormalId:GetEnumItems())],
		lifetime = NumberRange.new(a, b),
		name = key,
		orientation = Enum.ParticleOrientation:GetEnumItems()[random:NextInteger(1, #Enum.ParticleOrientation:GetEnumItems())],
		rate = random:NextNumber(1, 100),
		rotation = NumberRange.new(c, d),
		rotSpeed = NumberRange.new(g, h),
		shape = Enum.ParticleEmitterShape:GetEnumItems()[random:NextInteger(1, #Enum.ParticleEmitterShape:GetEnumItems())],
		shapeInOut = Enum.ParticleEmitterShapeInOut:GetEnumItems()[random:NextInteger(1, #Enum.ParticleEmitterShapeInOut:GetEnumItems())],
		shapeStyle = Enum.ParticleEmitterShapeStyle:GetEnumItems()[random:NextInteger(1, #Enum.ParticleEmitterShapeStyle:GetEnumItems())],
		size = NumberSequence.new(random:NextNumber(0.1, 10), random:NextNumber(0.1, 10)),
		speed = NumberRange.new(e, f),
		spreadAngle = Vector2.new(random:NextNumber(0, 180), random:NextNumber(0, 180)),
		squash = NumberSequence.new(random:NextNumber(0.1, 10), random:NextNumber(0.1, 10)),
		texture = "rbxassetid://" .. random:NextInteger(1, 10000000),
		transparency = NumberSequence.new(random:NextNumber(0, 1), random:NextNumber(0, 1)),
		velocityInheritance = random:NextNumber(0, 1),
		zOffset = random:NextNumber(-10, 10),
		lightEmission = random:NextNumber(0, 1),
	}

	printParticleDescriptor(randomParticleDescriptor)
	return randomParticleDescriptor
end

module.getRandomParticleDescriptor = getRandomParticleDescriptor
module.ParticleDescriptors = particleDescriptors

-- Sign-based particle descriptors (active during runs from these signs)
-- Sign IDs: ⊘=607, ⊖=606, ⊕=605, ⊗=604
-- Each sign can have multiple particle emitters (array of descriptors)
local signParticleDescriptors: { [number]: { tt.particleDescriptor } } = {
	-- ⊘ (607)
	[607] = {
		{
			acceleration = Vector3.new(4.3205, -4.0860, 9.5761),
			brightness = 47.64,
			color = Color3.new(0.6145, 0.9016, 0.3908),
			direction = Enum.NormalId.Right,
			drag = 3.864,
			durationMETA = 999,
			emissionDirection = Enum.NormalId.Left,
			lifetime = NumberRange.new(1.4589, 3.1767),
			lightEmission = 0.07,
			name = "sign_particle_607_1",
			orientation = Enum.ParticleOrientation.VelocityParallel,
			rate = 40.03,
			rotSpeed = NumberRange.new(91.0085, 172.1816),
			rotation = NumberRange.new(254.4663, 339.9989),
			shape = Enum.ParticleEmitterShape.Box,
			shapeInOut = Enum.ParticleEmitterShapeInOut.InAndOut,
			shapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			size = NumberSequence.new(0.4678, 4.2947),
			speed = NumberRange.new(23.3959, 44.5136),
			spreadAngle = Vector2.new(34.0261, 86.3894),
			squash = NumberSequence.new(6.4305, 4.2185),
			texture = "rbxassetid://2273224484",
			transparency = NumberSequence.new(0.1343, 0.9079),
			velocityInheritance = 0.6133,
			zOffset = 9.448,
		},
		{
			acceleration = Vector3.new(-8.1972, 7.8342, 0.5508),
			brightness = 23.21,
			color = Color3.new(0.7480, 0.3531, 0.8365),
			direction = Enum.NormalId.Front,
			drag = 2.432,
			durationMETA = 999,
			emissionDirection = Enum.NormalId.Right,
			lifetime = NumberRange.new(1.4605, 3.8706),
			lightEmission = 0.166,
			name = "sign_particle_607_2",
			orientation = Enum.ParticleOrientation.VelocityParallel,
			rate = 27.74,
			rotSpeed = NumberRange.new(423.7399, 491.5471),
			rotation = NumberRange.new(117.5208, 142.2278),
			shape = Enum.ParticleEmitterShape.Cylinder,
			shapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
			shapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			size = NumberSequence.new(3.4614, 3.3388),
			speed = NumberRange.new(13.3276, 48.0637),
			spreadAngle = Vector2.new(56.4482, 58.1097),
			squash = NumberSequence.new(1.6971, 1.6567),
			texture = "rbxassetid://243098098",
			transparency = NumberSequence.new(0.5165, 0.4557),
			velocityInheritance = 0.814,
			zOffset = 8.731,
		},
	},
	-- ⊖ (606)
	[606] = {
		{
			acceleration = Vector3.new(4.8669, -7.0839, -1.1914),
			brightness = 17.28,
			color = Color3.new(0.6980, 0.8862, 0.6897),
			direction = Enum.NormalId.Front,
			drag = 2.316,
			durationMETA = 999,
			emissionDirection = Enum.NormalId.Left,
			lifetime = NumberRange.new(2.9091, 9.6466),
			lightEmission = 0.643,
			name = "sign_particle_606_1",
			orientation = Enum.ParticleOrientation.FacingCamera,
			rate = 14.12,
			rotSpeed = NumberRange.new(62.3265, 422.9982),
			rotation = NumberRange.new(55.2625, 263.3374),
			shape = Enum.ParticleEmitterShape.Cylinder,
			shapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
			shapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			size = NumberSequence.new(3.7618, 2.0653),
			speed = NumberRange.new(1.2182, 22.0431),
			spreadAngle = Vector2.new(2.7770, 108.8738),
			squash = NumberSequence.new(6.1853, 2.8346),
			texture = "rbxassetid://243132757",
			transparency = NumberSequence.new(0.1648, 0.7284),
			velocityInheritance = 0.176,
			zOffset = 2.23,
		},
		{
			acceleration = Vector3.new(-2.0131, -7.5104, 6.4715),
			brightness = 6.71,
			color = Color3.new(0.5871, 0.8850, 0.3401),
			direction = Enum.NormalId.Front,
			drag = 1.252,
			durationMETA = 999,
			emissionDirection = Enum.NormalId.Front,
			lifetime = NumberRange.new(4.7832, 9.2219),
			lightEmission = 0.154,
			name = "sign_particle_606_2",
			orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
			rate = 13.99,
			rotSpeed = NumberRange.new(453.9211, 463.3255),
			rotation = NumberRange.new(13.9738, 288.3514),
			shape = Enum.ParticleEmitterShape.Disc,
			shapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
			shapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			size = NumberSequence.new(4.4633, 8.0188),
			speed = NumberRange.new(11.1958, 23.7690),
			spreadAngle = Vector2.new(24.2420, 157.2351),
			squash = NumberSequence.new(1.7372, 1.0852),
			texture = "rbxassetid://243098098",
			transparency = NumberSequence.new(0.9043, 0.8429),
			velocityInheritance = 0.773,
			zOffset = 1.986,
		},
	},
	-- ⊕ (605)
	[605] = {
		{
			acceleration = Vector3.new(9.8407, -1.1444, -0.8676),
			brightness = 91.01,
			color = Color3.new(0.9487, 0.9736, 0.3792),
			direction = Enum.NormalId.Right,
			drag = 4.07,
			durationMETA = 999,
			emissionDirection = Enum.NormalId.Right,
			lifetime = NumberRange.new(4.1946, 4.3412),
			lightEmission = 0.884,
			name = "sign_particle_605_1",
			orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			rate = 36.50,
			rotSpeed = NumberRange.new(353.4473, 490.2559),
			rotation = NumberRange.new(36.2788, 323.1079),
			shape = Enum.ParticleEmitterShape.Cylinder,
			shapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
			shapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			size = NumberSequence.new(1.6399, 0.5190),
			speed = NumberRange.new(8.8496, 29.2701),
			spreadAngle = Vector2.new(148.0176, 113.8599),
			squash = NumberSequence.new(2.8642, 8.4310),
			texture = "rbxassetid://2273224484",
			transparency = NumberSequence.new(0.5234, 0.5675),
			velocityInheritance = 0.803,
			zOffset = 7.218,
		},
		{
			acceleration = Vector3.new(-2.0131, -7.5104, 6.4715),
			brightness = 6.71,
			color = Color3.new(0.5871, 0.8850, 0.3401),
			direction = Enum.NormalId.Front,
			drag = 1.252,
			durationMETA = 999,
			emissionDirection = Enum.NormalId.Front,
			lifetime = NumberRange.new(4.7832, 9.2219),
			lightEmission = 0.154,
			name = "sign_particle_605_2",
			orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
			rate = 13.99,
			rotSpeed = NumberRange.new(453.9211, 463.3255),
			rotation = NumberRange.new(13.9738, 288.3514),
			shape = Enum.ParticleEmitterShape.Disc,
			shapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
			shapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			size = NumberSequence.new(4.4633, 8.0188),
			speed = NumberRange.new(11.1958, 23.7690),
			spreadAngle = Vector2.new(24.2420, 157.2351),
			squash = NumberSequence.new(1.7372, 1.0852),
			texture = "rbxassetid://243098098",
			transparency = NumberSequence.new(0.9043, 0.8429),
			velocityInheritance = 0.773,
			zOffset = 1.986,
		},
	},
	-- ⊗ (604)
	[604] = {
		{
			acceleration = Vector3.new(-7.2943, 2.3281, 0.9169),
			brightness = 58.39,
			color = Color3.new(0.5366, 0.9353, 0.5893),
			direction = Enum.NormalId.Right,
			drag = 3.864,
			durationMETA = 999,
			emissionDirection = Enum.NormalId.Left,
			lifetime = NumberRange.new(5.7643, 7.0032),
			lightEmission = 0.706,
			name = "sign_particle_604_1",
			orientation = Enum.ParticleOrientation.VelocityParallel,
			rate = 37.93,
			rotSpeed = NumberRange.new(394.0891, 430.0026),
			rotation = NumberRange.new(52.4936, 251.2701),
			shape = Enum.ParticleEmitterShape.Sphere,
			shapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
			shapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			size = NumberSequence.new(2.2843, 8.4146),
			speed = NumberRange.new(16.3228, 22.8043),
			spreadAngle = Vector2.new(156.6320, 143.3159),
			squash = NumberSequence.new(2.4629, 3.3113),
			texture = "rbxassetid://2273224484",
			transparency = NumberSequence.new(0.8713, 0.3657),
			velocityInheritance = 0.766,
			zOffset = -8.244,
		},
		{
			acceleration = Vector3.new(-2.0131, -7.5104, 6.4715),
			brightness = 6.71,
			color = Color3.new(0.5871, 0.8850, 0.3401),
			direction = Enum.NormalId.Front,
			drag = 1.252,
			durationMETA = 999,
			emissionDirection = Enum.NormalId.Front,
			lifetime = NumberRange.new(4.7832, 9.2219),
			lightEmission = 0.154,
			name = "sign_particle_604_2",
			orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
			rate = 13.99,
			rotSpeed = NumberRange.new(453.9211, 463.3255),
			rotation = NumberRange.new(13.9738, 288.3514),
			shape = Enum.ParticleEmitterShape.Disc,
			shapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
			shapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			size = NumberSequence.new(4.4633, 8.0188),
			speed = NumberRange.new(11.1958, 23.7690),
			spreadAngle = Vector2.new(24.2420, 157.2351),
			squash = NumberSequence.new(1.7372, 1.0852),
			texture = "rbxassetid://243098098",
			transparency = NumberSequence.new(0.9043, 0.8429),
			velocityInheritance = 0.773,
			zOffset = 1.986,
		},
	},
}

module.SignParticleDescriptors = signParticleDescriptors

_annotate("end")

return module
