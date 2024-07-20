--!strict

--movement enums for movementV2, MOSTLY unreleased except for floop slipperiness

local defaultDensity = 0.7
local defaultFriction = 0.3
local defaulElasticity = 0.5

local module = {}

--the non-me defaults?
local DefaultPhysicalProperties = PhysicalProperties.new(defaultDensity, defaultFriction, defaulElasticity, 100, 1)
local NewDefaultPhysicalProperties = PhysicalProperties.new(defaultDensity, 0.2, defaulElasticity, 100, 1)
local IceProps = PhysicalProperties.new(defaultDensity, 0.01, defaulElasticity, 100, 1)
local GlacierProps = PhysicalProperties.new(defaultDensity, 0.001, defaulElasticity, 100, 1)
local GrassProps = PhysicalProperties.new(defaultDensity, defaultFriction + 0.1, defaulElasticity, 100, 1)
local WaterProps = PhysicalProperties.new(defaultDensity, 0.9, 1.0, 100, 100)
local MudProps = PhysicalProperties.new(defaultDensity, 0.9, 1.0, 100, 100)

export type terrainMovementSpec = {
	material: Enum.Material,
	acceleration: number,
	maxspeed: number,

	jumpheight: number,
	d: number,
	f: number,
	e: number,
	fweight: number,
	eweight: number,
}

--PhysicalProperties.new(density, friction, elasticity, frictionweight, elasticityweight)

module.GetIceProperties = function()
	return IceProps
end

module.GetPropertiesForFloor = function(activeFloor): PhysicalProperties
	if activeFloor == Enum.Material.Ice then
		return IceProps
	elseif activeFloor == Enum.Material.Glacier or activeFloor == Enum.Material.Snow then
		return GlacierProps
	elseif activeFloor == Enum.Material.Grass then
		return GrassProps
	elseif activeFloor == Enum.Material.Mud then
		return MudProps
	elseif activeFloor == Enum.Material.Water then
		return WaterProps
	else
		return NewDefaultPhysicalProperties
	end
end

local defaultJumpPowerMultiplier = 1.0

--jump more based on floor
--note that this applies to ALL floors, not just real terrain ones.
--i.e. superjump from sign!
module.GetJumpPowerByFloorMultipler = function(activeFloor): number
	if activeFloor == Enum.Material.Plastic then
		return 1.02
	end
	if activeFloor == Enum.Material.Granite then
		return 1.35
	end
	if activeFloor == Enum.Material.CrackedLava then
		return 1.15
	end
	if activeFloor == Enum.Material.Concrete then
		return 1
	end
	if activeFloor == Enum.Material.Cobblestone then
		return 1
	end
	if activeFloor == Enum.Material.WoodPlanks then
		return 1.1
	end
	if activeFloor == Enum.Material.Brick then
		return 1.2
	end
	if activeFloor == Enum.Material.Snow then
		return 1
	end
	if activeFloor == Enum.Material.Glacier or activeFloor == Enum.Material.Ice then
		return 1
	end
	if activeFloor == Enum.Material.Sand then
		return 1
	end
	return defaultJumpPowerMultiplier
end

export type movementData = { acceleration: number, jumppower: number, materialid: number }

--hack this for now.
local EnumIsTerrain = function(n: number): boolean
	--skip air
	if n >= 34 and n <= 55 then
		return true
	end
	return false
end
module.EnumIsTerrain = EnumIsTerrain

--excluded materials from counting as terrain.
local nonMaterialEnumTypes: { [Enum.Material]: boolean } = {}
nonMaterialEnumTypes[Enum.Material.Granite] = true --signs
nonMaterialEnumTypes[Enum.Material.Plastic] = true --spawn

module.nonMaterialEnumTypes = nonMaterialEnumTypes

-----THIS FUNCTIONS AS A HISTORY ITEM. THERE WILL BE JUST ONE AT EVERY TIMESTEP

local MOVEMENT_HISTORY_ENUM: { [string]: number } = {
	RESET = 1,
	JUMPING = 2,
	RUN = 3,
	WALK = 4,
	WARP = 5,
	SWIMMING = 6,
	NOT_JUMPING = 7,
	NOT_SWIMMING = 8,
	FALLING_DOWN = 9,
	FALLING_DOWN_INACTIVE = 10,
	GETTING_UP = 11,
	GETTING_UP_INACTIVE = 12,
	RAGDOLL = 13,
	RAGDOLL_INACTIVE = 14,

	--TOUCH SPECIAL SIGN HERE
	NO_JUMP = 16,
	FASTER = 17,
	THREE_TERRAIN = 18,
	FOUR_TERRAIN = 19,
	HIGH_JUMP = 20,
	NO_GRASS = 21,
	COLD_MOLD = 22,
	SLIPPERY = 23,

	--TOUCH EACH TERRAIN TYPE HERE
	AIR = 33,
	ASPHALT = 34, --REAL TERRAIN TYPES >=34
	BASALT = 35,
	BRICK = 36,
	COBBLESTONE = 37,
	CONCRETE = 38,
	CRACKED_LAVA = 39,
	GLACIER = 40,
	GRASS = 41,
	GROUND = 42,
	ICE = 43,
	LEAFY_GRASS = 44,
	LIMESTONE = 45,
	MUD = 46,
	PAVEMENT = 47,
	ROCK = 48,
	SALT = 49,
	SAND = 50,
	SANDSTONE = 51,
	SLATE = 52,
	SNOW = 53,
	WATER = 54,
	WOOD_PLANKS = 55, --REAL TERRAIN TYPES END <=55

	--
	PLASTIC = 66, --SPAWN
	SIGN = 67, --SIGNS ARE GRANITE (NOW)
	--OTHER ITEMS EXIST BUT WE DON'T COUNT THEM and they should throw errors.

	START_MOVING = 79,
	STOP_MOVING = 80, --when the player stops moving entirely, such as by completely releasing the keyboard.
	CRASH_LAND = 85, --150-220
	CRASH_LAND2 = 85, -->=220

	PULSED = 86, --received impulse from touching PULSE sign.
	UNUSED = 87, --use this as the initial default.
}

module.MOVEMENT_HISTORY_ENUM = MOVEMENT_HISTORY_ENUM

local REVERSED_MOVEMENT_HISTORY_ENUM = {}
for a, b in pairs(MOVEMENT_HISTORY_ENUM) do
	REVERSED_MOVEMENT_HISTORY_ENUM[b] = a
end

module.REVERSED_MOVEMENT_HISTORY_ENUM = REVERSED_MOVEMENT_HISTORY_ENUM

local TerrainEnum2MovementEnum: { [Enum.Material]: number } = {}
TerrainEnum2MovementEnum[Enum.Material.Air] = MOVEMENT_HISTORY_ENUM.AIR
TerrainEnum2MovementEnum[Enum.Material.Asphalt] = MOVEMENT_HISTORY_ENUM.ASPHALT
TerrainEnum2MovementEnum[Enum.Material.Basalt] = MOVEMENT_HISTORY_ENUM.BASALT
TerrainEnum2MovementEnum[Enum.Material.Brick] = MOVEMENT_HISTORY_ENUM.BRICK
TerrainEnum2MovementEnum[Enum.Material.Cobblestone] = MOVEMENT_HISTORY_ENUM.COBBLESTONE
TerrainEnum2MovementEnum[Enum.Material.Concrete] = MOVEMENT_HISTORY_ENUM.CONCRETE
TerrainEnum2MovementEnum[Enum.Material.CrackedLava] = MOVEMENT_HISTORY_ENUM.CRACKED_LAVA
TerrainEnum2MovementEnum[Enum.Material.Glacier] = MOVEMENT_HISTORY_ENUM.GLACIER
TerrainEnum2MovementEnum[Enum.Material.Grass] = MOVEMENT_HISTORY_ENUM.GRASS
TerrainEnum2MovementEnum[Enum.Material.Ground] = MOVEMENT_HISTORY_ENUM.GROUND
TerrainEnum2MovementEnum[Enum.Material.Ice] = MOVEMENT_HISTORY_ENUM.ICE
TerrainEnum2MovementEnum[Enum.Material.LeafyGrass] = MOVEMENT_HISTORY_ENUM.LEAFY_GRASS
TerrainEnum2MovementEnum[Enum.Material.Limestone] = MOVEMENT_HISTORY_ENUM.LIMESTONE
TerrainEnum2MovementEnum[Enum.Material.Mud] = MOVEMENT_HISTORY_ENUM.MUD
TerrainEnum2MovementEnum[Enum.Material.Pavement] = MOVEMENT_HISTORY_ENUM.PAVEMENT
TerrainEnum2MovementEnum[Enum.Material.Rock] = MOVEMENT_HISTORY_ENUM.ROCK
TerrainEnum2MovementEnum[Enum.Material.Salt] = MOVEMENT_HISTORY_ENUM.SALT
TerrainEnum2MovementEnum[Enum.Material.Sand] = MOVEMENT_HISTORY_ENUM.SAND
TerrainEnum2MovementEnum[Enum.Material.Sandstone] = MOVEMENT_HISTORY_ENUM.SANDSTONE
TerrainEnum2MovementEnum[Enum.Material.Slate] = MOVEMENT_HISTORY_ENUM.SLATE
TerrainEnum2MovementEnum[Enum.Material.Snow] = MOVEMENT_HISTORY_ENUM.SNOW
TerrainEnum2MovementEnum[Enum.Material.Water] = MOVEMENT_HISTORY_ENUM.WATER
TerrainEnum2MovementEnum[Enum.Material.WoodPlanks] = MOVEMENT_HISTORY_ENUM.WOOD_PLANKS
module.TerrainEnum2MovementEnum = TerrainEnum2MovementEnum

return module
