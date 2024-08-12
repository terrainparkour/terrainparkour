--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local tt = require(game.ReplicatedStorage.types.gametypes)

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local PLAYER_GROUP = "Players"

PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
PhysicsService:CollisionGroupSetCollidable(PLAYER_GROUP, PLAYER_GROUP, false)

-------------------TEMP-------------------------
local createParticleEmitter = function(player: Player, desc: tt.particleDescriptor)
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	local particleEmitter: ParticleEmitter = Instance.new("ParticleEmitter")

	particleEmitter.Brightness = desc.brightness
	local colorSequence: ColorSequence = ColorSequence.new(desc.color)
	particleEmitter.Color = colorSequence
	particleEmitter.Drag = desc.drag
	particleEmitter.EmissionDirection = desc.direction

	particleEmitter.Lifetime = desc.lifetime
	particleEmitter.Name = "PlayerParticleEmitter." .. player.Name .. "." .. desc.name
	particleEmitter.Orientation = desc.orientation
	particleEmitter.Rate = desc.rate
	particleEmitter.Rotation = desc.rotation
	particleEmitter.Shape = desc.shape
	particleEmitter.ShapeStyle = desc.shapeStyle
	particleEmitter.Size = desc.size
	particleEmitter.SpreadAngle = desc.spreadAngle
	particleEmitter.VelocityInheritance = desc.velocityInheritance
	particleEmitter.Parent = humanoid.RootPart
	particleEmitter.Enabled = true
	while true do
		particleEmitter:Emit(100)
		wait(1)
		print("emitting")
	end
end
-------------------TEMP-------------------------

local function setPlayerCollisionGroup(character)
	for _, part: BasePart in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = PLAYER_GROUP
		end
	end
end

local function onCharacterAdded(character)
	setPlayerCollisionGroup(character)
	character.DescendantAdded:Connect(function(descendant: BasePart)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = PLAYER_GROUP
		end
	end)
end

--[[
export type particleDescriptor = {
	brightness: number,
	color: Color3,
	direction: Enum.NormalId,
	drag: number,
	duration: number,
	falloff: number,
	name: string,
	lifetime: NumberRange,
	orientation: Enum.ParticleOrientation,
	rate: number,
	rotation: NumberRange,
	shape: Enum.ParticleEmitterShape,
	shapeColor: Color3,
	shapeStyle: Enum.ParticleEmitterShapeStyle,
	size: NumberSequence,
	spreadAngle: Vector2,
	velocityInheritance: number,
}]]

-- local xx: tt.particleDescriptor = {
-- 	brightness = 1,
-- 	color = Color3.new(1, 0, 0),
-- 	direction = Enum.NormalId.Back,
-- 	drag = 0,
-- 	duration = 0.5,
-- 	falloff = 1,
-- 	name = "test",
-- 	lifetime = NumberRange.new(1, 1),
-- 	orientation = Enum.ParticleOrientation.VelocityParallel,
-- 	rate = 1,
-- 	rotation = NumberRange.new(1, 1),
-- 	shape = Enum.ParticleEmitterShape.Sphere,
-- 	shapeColor = Color3.new(0.11, 0.312, 0.874),
-- 	shapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
-- 	size = NumberSequence.new(1, 7),
-- 	spreadAngle = Vector2.new(1, 10),
-- 	velocityInheritance = 1,
-- }

-- local xx2: tt.particleDescriptor = {
-- 	brightness = 14,
-- 	color = Color3.new(0.11, 0.312, 0.874),
-- 	direction = Enum.NormalId.Left,
-- 	drag = 0.6,
-- 	duration = 4,
-- 	falloff = 1,
-- 	name = "test2",
-- 	lifetime = NumberRange.new(7, 10),
-- 	orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
-- 	rate = 7,
-- 	rotation = NumberRange.new(1, 100),
-- 	shape = Enum.ParticleEmitterShape.Cylinder,
-- 	shapeColor = Color3.new(0.76, 0.312, 0.164),
-- 	shapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
-- 	size = NumberSequence.new(3, 4),
-- 	spreadAngle = Vector2.new(90, 90),
-- 	velocityInheritance = 0.5,
-- }

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(onCharacterAdded)
	-- if player.UserId == -1 then
	-- 	createParticleEmitter(player, xx)
	-- end
	-- if player.UserId == -2 then
	-- 	createParticleEmitter(player, xx2)
	-- end
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- Handle existing players
for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

module.Init = function() end

_annotate("end")
return module
