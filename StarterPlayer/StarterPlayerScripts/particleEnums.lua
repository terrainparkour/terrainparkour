--!strict

-- particleEnums.lua
-- descriptors for particle emission from the player, with color, state etc.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}
local avatarEventTypes = require(game.ReplicatedStorage.avatarEventTypes)

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

local OTHERTEXTURE = "rbxassetid://138530670729336"

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

local floorchanged: tt.particleDescriptor = AddDefaults({
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

local runkill: tt.particleDescriptor = AddDefaults({
	name = "runkill",
	brightness = 1,
	color = Color3.new(0.1, 0.1, 0.1),
	rotation = NumberRange.new(0, 360),
	rotSpeed = NumberRange.new(-45, -45),
	spreadAngle = Vector2.new(30, 30),
	size = NumberSequence.new(4, 5),
	durationMETA = 0.2,
})

local stoppedmoving: tt.particleDescriptor = AddDefaults({
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
			_annotate(
				string.format(
					"%s: NumberSequence(%f, %f)",
					key,
					value.Keypoints[1].Value,
					value.Keypoints[#value.Keypoints].Value
				)
			)
		elseif typeof(value) == "Vector2" then
			_annotate(string.format("%s: Vector2(%f, %f)", key, value.X, value.Y))
		elseif typeof(value) == "EnumItem" then
			_annotate(string.format("%s: %s", key, tostring(value)))
		else
			_annotate(string.format("%s: %s", key, tostring(value)))
		end
	end
end

local random: Random = Random.new(time())
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
		orientation = Enum.ParticleOrientation:GetEnumItems()[random:NextInteger(
			1,
			#Enum.ParticleOrientation:GetEnumItems()
		)],
		rate = random:NextNumber(1, 100),
		rotation = NumberRange.new(c, d),
		rotSpeed = NumberRange.new(g, h),
		shape = Enum.ParticleEmitterShape:GetEnumItems()[random:NextInteger(
			1,
			#Enum.ParticleEmitterShape:GetEnumItems()
		)],
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

_annotate("end")

return module
