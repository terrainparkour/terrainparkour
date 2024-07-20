--!strict

--copied onto signs which rotate.
--eval 9.24.22

local sendMessageModule = require(game.ReplicatedStorage.chat.sendMessage)
local sm = sendMessageModule.sendMessage
local channeldefinitions = require(game.ReplicatedStorage.chat.channeldefinitions)
local channel = channeldefinitions.getChannel("All")
local config = require(game.ReplicatedStorage.config)

local module = {}

module.rotate = function(sign: Part)
	if not sign and not config.isInStudio() then
		warn("no sign2")
		return
	end
	spawn(function()
		while true do
			for deg = 0, 360 do
				sign.Rotation = Vector3.new(0, -1 * deg, 0)
				wait()
			end
		end
	end)
end

module.rotateMeshpart = function(sign: MeshPart)
	if not sign and not config.isInStudio() then
		warn("no sign3")
		return
	end
	spawn(function()
		while true do
			for deg = 0, 360 do
				sign.Rotation = Vector3.new(0, -1 * deg, 0)
				wait()
			end
		end
	end)
end

module.riseandspin = function(sign: Part)
	if not sign and config.isInStudio() then
		warn("no sign4")
		return
	end
	spawn(function()
		local orig = sign.Position
		local vec = Vector3.new(0, 200, 0)
		sign.Position = Vector3.new(orig.X + vec.X, orig.Y + vec.Y, orig.Z + vec.Z)
		local adjustedOrig = sign.Position
		while true do
			for deg = 0, 360 do
				sign.Rotation = Vector3.new(0, -1 * deg, 0)
				local frac = (deg / 360) * 2 * math.pi
				local val = math.sin(frac)
				sign.Position = adjustedOrig + Vector3.new(val * vec.X, val * vec.Y, val * vec.Z)
				--TODO this should be physics stepped.
				wait(1 / 60)
			end
		end
	end)
end

--following for 007 mystery sign.
module.fadeInSign = function(sign: Part)
	if not sign and config.isInStudio() then
		warn("no sign5")
		return
	end
	spawn(function()
		while sign.Transparency > 0 do
			sign.Transparency -= 0.01
			wait(0.03)
		end
	end)
	sign.CanCollide = true
	sign.CanTouch = true
	-- cdholder.Parent = sign
	local sg = sign:FindFirstChildOfClass("SurfaceGui")
	if sg == nil then
		return
	end
	assert(sg)
	sg.Enabled = true
	sm(channel, "007 has appeared")
end

module.fadeOutSign = function(sign: Part?, first: boolean)
	if not sign then
		return
	end
	assert(sign)
	local sg = sign:FindFirstChildOfClass("SurfaceGui")
	if sg == nil then
		return
	end
	assert(sg)
	sg.Enabled = false

	spawn(function()
		while sign.Transparency < 1 do
			sign.Transparency += 0.01
			wait(0.03)
		end
	end)

	sign.CanCollide = false
	sign.CanTouch = false
	if not first then
		sm(channel, "007 has disappeared")
	end
end

local terrainChoices = {
	Enum.Material.Cobblestone,
	Enum.Material.Cobblestone,
	Enum.Material.Cobblestone,
	Enum.Material.Asphalt,
	Enum.Material.Asphalt,
	Enum.Material.Asphalt,
	Enum.Material.Concrete,
	Enum.Material.Ground,
}

local function rndTerrain()
	local res = terrainChoices[math.random(#terrainChoices)]
	return res
end

local angleMap = {}
angleMap[Enum.Material.Cobblestone] = Vector3.new(10, 0, 0)
angleMap[Enum.Material.Asphalt] = Vector3.new(-5, 0, 0)
angleMap[Enum.Material.Concrete] = Vector3.new(5, 0, 0)
angleMap[Enum.Material.Ground] = Vector3.new(-10, 0, 0)
angleMap[Enum.Material.Ice] = Vector3.new(15, 0, 0)

module.setupGrowingDistantPinnacle = function()
	local doNotCheckInGameIdentifier = require(game.ReplicatedStorage:FindFirstChild("doNotCheckInGameIdentifier"))
	local target = Vector3.new(861.401, -129.206, 6254.898)
	local addVector = Vector3.new(3, 1, 17)
	local ballSize = 10
	local waitTime = 1
	local mult = 1
	local maxAdditions = 1000
	if doNotCheckInGameIdentifier.useTestDb() then --test game
		target = Vector3.new(836.921, 3.393, -635.989)
		addVector = Vector3.new(3, 1, 17) / 5
		ballSize = 14
		waitTime = 0.2
		mult = 2.3
		-- mult = 10
	else --prod game, grows near equal temperament.
		target = Vector3.new(874.401, -134.206, 6254.898)
		addVector = Vector3.new(17, 1, 3) / 5
		ballSize = 14
		waitTime = 1.6
		mult = 0.01
	end

	spawn(function()
		local additions = 0
		while true do
			local ter = rndTerrain()
			target += addVector
			--don't permanently change basis.
			local extra = angleMap[ter] * mult
				+ Vector3.new(math.sin(target.X / 1000) * 10, math.cos(target.Y / 6), math.tan(target.Z / 70))
			workspace.Terrain:FillBall(target + extra, ballSize, ter)
			additions += 1
			if additions > maxAdditions then
				break
			end
			wait(waitTime)
		end
	end)
end

return module
