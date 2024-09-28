if true then
	return
end

local function replacePartWithAir(part)
	local position = part.Position
	local size = part.Size
	if part.Shape == Enum.PartType.Ball then
		workspace.Terrain:FillBall(position, size, Enum.Material.Air)
	elseif part.Shape == Enum.PartType.Block then
		workspace.Terrain:FillBlock(position, size, Enum.Material.Asphalt)
	elseif part.Shape == Enum.PartType.Cylinder then
		local height = part.Size.Y
		local radius = part.Size.X / 2 -- Assuming X and Z are equal for a cylinder
		workspace.Terrain:FillCylinder(part.CFrame, height, radius, Enum.Material.Air)
	elseif part.Shape == Enum.PartType.Wedge then
		workspace.Terrain:FillWedge(CFrame.new(position), size, Enum.Material.Air)
	else
		return
	end
end

-- Example usage:
replacePartWithAir(game.workspace:FindFirstChild("Part"))

local allTerrain = {
	[0] = Enum.Material.WoodPlanks,
	[1] = Enum.Material.Slate,
	[2] = Enum.Material.Concrete,
	[3] = Enum.Material.Brick,
	[4] = Enum.Material.Cobblestone,
	[5] = Enum.Material.Rock,
	[6] = Enum.Material.Sandstone,
	[7] = Enum.Material.Basalt,
	[8] = Enum.Material.CrackedLava,
	[9] = Enum.Material.Limestone,
	[10] = Enum.Material.Pavement,
	[11] = Enum.Material.CorrodedMetal,
	[12] = Enum.Material.Grass,
	[13] = Enum.Material.LeafyGrass,
	[14] = Enum.Material.Sand,
	[15] = Enum.Material.Snow,
	[16] = Enum.Material.Mud,
	[17] = Enum.Material.Ground,
	[18] = Enum.Material.Asphalt,
	[19] = Enum.Material.Salt,
	[20] = Enum.Material.Ice,
	[21] = Enum.Material.Glacier,
}

local function randomizeTerrainAround4() end

local function randomizeTerrainAround2(pos)
	local radius = 10
	local step = 1

	for x = pos.X - radius, pos.X + radius, step do
		for z = pos.Z - radius, pos.Z + radius, step do
			local randomIndex = math.random(0, #allTerrain)
			local randomMateria = allTerrain[randomIndex]

			workspace.Terrain:FillBlock(CFrame.new(x, pos.Y, z), Vector3.new(step, step, step), randomMateria)
		end
	end
end

-- Example usage:
local part: Part = game.Workspace:FindFirstChild("Part")
randomizeTerrainAround2(part.Position)
