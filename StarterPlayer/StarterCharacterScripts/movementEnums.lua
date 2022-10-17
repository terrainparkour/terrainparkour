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

local defaultJumpHeight = 7.2

--jump more based on floor
module.GetJumpHeightForFloor = function(activeFloor): number
	if activeFloor == Enum.Material.Plastic then
		return 9
	end
	if activeFloor == Enum.Material.CrackedLava then
		return 14
	end
	if activeFloor == Enum.Material.Concrete then
		return 6
	end
	if activeFloor == Enum.Material.Cobblestone then
		return 8
	end
	if activeFloor == Enum.Material.WoodPlanks then
		return 10
	end
	if activeFloor == Enum.Material.Brick then
		return 12
	end
	if activeFloor == Enum.Material.Snow then
		return 0
	end
	if activeFloor == Enum.Material.Glacier or activeFloor == Enum.Material.Ice then
		return 0
	end
	if activeFloor == Enum.Material.Sand then
		return 1
	end
	return defaultJumpHeight
end

--aggressively raycast to detect water and make player swim; also do the callback so outer layer knows about it.
module.SetWaterMonitoring = function(player: Player, waterCb: (() -> nil)?)
	player.CharacterAdded:Connect(function()
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid: Humanoid = character:WaitForChild("Humanoid")
		local raycastParams = RaycastParams.new()

		raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
		raycastParams.FilterDescendantsInstances = { character }

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		spawn(function()
			while true do
				local ii = 3.6
				local result: RaycastResult = nil

				while ii < 3.8 do
					result = workspace:Raycast(
						rootPart.Position,
						Vector3.new(0, -1 * ii, 0), -- you might need to make this longer/shorter
						raycastParams
					)
					if result ~= nil then
						if result.Material == Enum.Material.Water then
							-- print("water landing at dist. " .. tostring(ii))
							humanoid:ChangeState(Enum.HumanoidStateType.Swimming)
							if waterCb then
								waterCb()
							end
							break
						end
					end
					ii += 0.1
				end
				wait(0.05)
			end
		end)
	end)
end

local SpeedEventName2Id: { [string]: number } = {}
SpeedEventName2Id.JUMP = 1 --previously bumped speed down to 63 (from 68) for 3.5
SpeedEventName2Id.SMASH = 2 --hit the ground at high speed
SpeedEventName2Id.GETAIR = 3
SpeedEventName2Id.WATER = 4 --35 spd, for 4s
SpeedEventName2Id.LAVA = 5 --32 spd, for 3.5s
SpeedEventName2Id.TOUCHSIGN = 6 --reset to 68 spd
SpeedEventName2Id.FALLDOWN = 7 --reset to 68 spd
local Id2SpeedEventName: { [number]: string } = {}
for k, v in pairs(SpeedEventName2Id) do
	Id2SpeedEventName[v] = k
end

module.SpeedEventName2Id = SpeedEventName2Id
module.Id2SpeedEventName = Id2SpeedEventName

export type movementData = { acceleration: number, jumppower: number, materialid: number }

--floormaterialId to movementData
local defaultJumpPower = 55
local Grass: movementData = {
	acceleration = 1,
	jumppower = defaultJumpPower,
	materialid = tonumber(Enum.Material.Grass.Value),
}
local LeafyGrass: movementData = {
	acceleration = 1,
	jumppower = defaultJumpPower,
	materialid = tonumber(Enum.Material.LeafyGrass.Value),
}
local Concrete: movementData = {
	acceleration = 1.1,
	jumppower = defaultJumpPower * 1.4,
	materialid = tonumber(Enum.Material.Concrete.Value),
}
local Slate: movementData = {
	acceleration = 1,
	jumppower = defaultJumpPower * 1.01,
	materialid = tonumber(Enum.Material.Slate.Value),
}
local Ice: movementData = {
	acceleration = 0.95,
	jumppower = defaultJumpPower,
	materialid = tonumber(Enum.Material.Ice.Value),
}
local Brick: movementData = {
	acceleration = 0.96,
	jumppower = defaultJumpPower,
	materialid = tonumber(Enum.Material.Brick.Value),
}
local Sand: movementData = {
	acceleration = 0.7,
	jumppower = defaultJumpPower * 0.8,
	materialid = tonumber(Enum.Material.Sand.Value),
}
local WoodPlanks: movementData = {
	acceleration = 1.05,
	jumppower = defaultJumpPower * 1.0,
	materialid = tonumber(Enum.Material.WoodPlanks.Value),
}
local Cobblestone: movementData = {
	acceleration = 1.12,
	jumppower = defaultJumpPower * 1.1,
	materialid = tonumber(Enum.Material.Cobblestone.Value),
}
local Asphalt: movementData = {
	acceleration = 1.1,
	jumppower = defaultJumpPower,
	materialid = tonumber(Enum.Material.Asphalt.Value),
}
local Basalt: movementData = {
	acceleration = 1.05,
	jumppower = defaultJumpPower,
	materialid = tonumber(Enum.Material.Basalt.Value),
}
local CrackedLava: movementData = {
	acceleration = 1.5,
	jumppower = defaultJumpPower * 1.2,
	materialid = tonumber(Enum.Material.CrackedLava.Value),
}
local Glacier: movementData = {
	acceleration = 1,
	jumppower = defaultJumpPower,
	materialid = tonumber(Enum.Material.Glacier.Value),
}
local Ground: movementData = {
	acceleration = 1.11,
	jumppower = defaultJumpPower,
	materialid = tonumber(Enum.Material.Ground.Value),
}
local Limestone: movementData = {
	acceleration = 1.13,
	jumppower = defaultJumpPower,
	materialid = tonumber(Enum.Material.Limestone.Value),
}
local Mud: movementData = {
	acceleration = 0.9,
	jumppower = defaultJumpPower,
	materialid = tonumber(Enum.Material.Mud.Value),
}
local Pavement: movementData = {
	acceleration = 1.2,
	jumppower = defaultJumpPower,
	materialid = tonumber(Enum.Material.Pavement.Value),
}
local Rock: movementData = {
	acceleration = 1.3,
	jumppower = defaultJumpPower,
	materialid = tonumber(Enum.Material.Rock.Value),
}
local Salt: movementData = {
	acceleration = 1.1,
	jumppower = defaultJumpPower,
	materialid = tonumber(Enum.Material.Salt.Value),
}
local Sandstone: movementData = {
	acceleration = 0.99,
	jumppower = defaultJumpPower,
	materialid = tonumber(Enum.Material.Sandstone.Value),
}
local Snow: movementData = {
	acceleration = 1.01,
	jumppower = defaultJumpPower * 0.8,
	materialid = tonumber(Enum.Material.Snow.Value),
}

local floor2movementData: { [number]: movementData } = {}
floor2movementData[Grass.materialid] = Grass
floor2movementData[LeafyGrass.materialid] = LeafyGrass
floor2movementData[Grass.materialid] = Grass
floor2movementData[Concrete.materialid] = Concrete
floor2movementData[Slate.materialid] = Slate
floor2movementData[Ice.materialid] = Ice
floor2movementData[Brick.materialid] = Brick
floor2movementData[Sand.materialid] = Sand
floor2movementData[WoodPlanks.materialid] = WoodPlanks
floor2movementData[Cobblestone.materialid] = Cobblestone
floor2movementData[Asphalt.materialid] = Asphalt
floor2movementData[Basalt.materialid] = Basalt
floor2movementData[CrackedLava.materialid] = CrackedLava
floor2movementData[Glacier.materialid] = Glacier
floor2movementData[Ground.materialid] = Ground
floor2movementData[Limestone.materialid] = Limestone
floor2movementData[Mud.materialid] = Mud
floor2movementData[Pavement.materialid] = Pavement
floor2movementData[Rock.materialid] = Rock
floor2movementData[Salt.materialid] = Salt
floor2movementData[Sandstone.materialid] = Sandstone
floor2movementData[Snow.materialid] = Snow

module.floor2movementData = floor2movementData

return module
