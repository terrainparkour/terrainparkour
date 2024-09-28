--!strict

--movement enums for movementV2, MOSTLY unreleased except for floop slipperiness
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

------ GLOBAL DEFAULTS ------

local defaultDensity = 0.7
local defaultFriction = 0.3
local defaulElasticity = 0.5

--------- SHARED CONSTANTS --------------
local constants = {}
module.constants = constants

constants.globalDefaultRunSpeed = 68
constants.globalDefaultWalkSpeed = 16
constants.globalDefaultJumpPower = 55

------------- unless overridden ----------------
local DefaultPhysicalProperties = PhysicalProperties.new(defaultDensity, 0.2, defaulElasticity, 100, 1)
module.constants.DefaultPhysicalProperties = DefaultPhysicalProperties

local GlacierProps = PhysicalProperties.new(defaultDensity, 0.001, defaulElasticity, 100, 1)
local GrassProps = PhysicalProperties.new(defaultDensity, defaultFriction + 0.1, defaulElasticity, 100, 1)
local WaterProps = PhysicalProperties.new(defaultDensity, 1, 1.0, 100, 100)
local MudProps = PhysicalProperties.new(defaultDensity, defaultFriction, defaulElasticity, 100, 100)

local defaultJumpPowerMultiplier = 1.0

module.IceProps = PhysicalProperties.new(defaultDensity, 0.01, defaulElasticity, 100, 1)

module.GetPropertiesForFloor = function(activeFloor): { prop: PhysicalProperties, name: string }
	if activeFloor == Enum.Material.Ice then
		return { prop = module.IceProps, name = "ice" }
	elseif activeFloor == Enum.Material.Glacier or activeFloor == Enum.Material.Snow then
		return { prop = GlacierProps, name = "glacier" }
	elseif activeFloor == Enum.Material.Grass then
		return { prop = GrassProps, name = "grass" }
	elseif activeFloor == Enum.Material.Mud then
		return { prop = MudProps, name = "mud" }
	elseif activeFloor == Enum.Material.Water then
		return { prop = WaterProps, name = "water" }
	else
		return { prop = DefaultPhysicalProperties, name = "default" }
	end
end

--jump more based on floor
--note that this applies to ALL floors, not just real terrain ones.
--i.e. superjump from sign!
module.GetJumpPowerByFloorMultipler = function(activeFloor): number
	if activeFloor == Enum.Material.Plastic then
		return 1.02
	elseif activeFloor == Enum.Material.Granite then
		return 1.35
	elseif activeFloor == Enum.Material.CrackedLava then
		return 1.15
	elseif activeFloor == Enum.Material.Concrete then
		return 1.05
	elseif activeFloor == Enum.Material.Cobblestone then
		return 1
	elseif activeFloor == Enum.Material.WoodPlanks then
		return 1.1
	elseif activeFloor == Enum.Material.Brick then
		return 1.2
	elseif activeFloor == Enum.Material.Snow then
		return 1
	elseif activeFloor == Enum.Material.Rock then
		return 1
	elseif activeFloor == Enum.Material.Glacier then
		return 1
	elseif activeFloor == Enum.Material.Ice then
		return 1
	elseif activeFloor == Enum.Material.Sand then
		return 0.96
	elseif activeFloor == Enum.Material.Mud then
		return 0.87
	end
	return defaultJumpPowerMultiplier
end

local terrainEnumIds: { number } = {
	528,
	788,
	800,
	804,
	816,
	820,
	836,
	848,
	880,
	896,
	912,
	1040,
	1280,
	1284,
	1296,
	1328,
	1344,
	1360,
	1376,
	1392,
	1536,
	1552,
}
local allTerrainNames: { string } = {}

for _, material: Enum.Material in ipairs(Enum.Material:GetEnumItems()) do
	if table.find(terrainEnumIds, material.Value) then
		table.insert(allTerrainNames, material.Name)
	end
end

module.AllTerrainNames = allTerrainNames

local terrainEnumSet = {}
for _, id in ipairs(terrainEnumIds) do
	terrainEnumSet[id] = true
end

-- excluding AIR.
local EnumIsTerrain = function(mat: Enum.Material?): boolean
	if mat == nil then
		warn("weirdly checkikng nonterrain.")
		return false
	end

	if not mat then
		return false
	end
	--skip air
	if mat == Enum.Material.Air then
		return false
	end

	if terrainEnumSet[mat.Value] ~= nil then
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

local allTerrain = {
	Enum.Material.WoodPlanks,
	Enum.Material.Slate,
	Enum.Material.Concrete,
	Enum.Material.Brick,
	Enum.Material.Cobblestone,
	Enum.Material.Rock,
	Enum.Material.Sandstone,
	Enum.Material.Basalt,
	Enum.Material.CrackedLava,
	Enum.Material.Limestone,
	Enum.Material.Pavement,
	Enum.Material.CorrodedMetal,
	Enum.Material.Grass,
	Enum.Material.LeafyGrass,
	Enum.Material.Sand,
	Enum.Material.Snow,
	Enum.Material.Mud,
	Enum.Material.Ground,
	Enum.Material.Asphalt,
	Enum.Material.Salt,
	Enum.Material.Ice,
	Enum.Material.Glacier,
}

_annotate("end")
return module
