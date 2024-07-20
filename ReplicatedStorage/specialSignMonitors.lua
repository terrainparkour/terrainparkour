--setups for super heavy, superjump, etc signs.
--important to keep them separated here - they don't really influence speed do they?
--hmm but they do.

local module = {}

local vscdebug = require(game.ReplicatedStorage.vscdebug)
local remotes = require(game.ReplicatedStorage.util.remotes)

local movementEnums = require(game.StarterPlayer.StarterPlayerScripts.movementEnums)
-- local signMovementEnums = require(game.ReplicatedStorage.enums.signMovementEnums)
-- local tt = require(game.ReplicatedStorage.types.gametypes)
local colors = require(game.ReplicatedStorage.util.colors)

local PlayersService = game:GetService("Players")
-- local UserInputService = game:GetService("UserInputService")

-- local particles = require(game.StarterPlayer.StarterPlayerScripts.particles)

local localPlayer = PlayersService.LocalPlayer

---------ANNOTATION----------------
local doAnnotation = false
	or localPlayer.Name == "TerrainParkour"
	or localPlayer.Name == "Player2"
	or localPlayer.Name == "Player1"
doAnnotation = true
-- doAnnotation = false
local annotationStart = tick()
local function annotate(s: string | any)
	if doAnnotation then
		if typeof(s) == "string" then
			print("specialSignMonitors. " .. string.format("%.0f", tick() - annotationStart) .. " : " .. s)
		else
			print("specialSignMonitors.object. " .. string.format("%.0f", tick() - annotationStart) .. " : ")
			print(s)
		end
	end
end

-------------TRACKING-------------

--boolean if they have touched the floor type at all.
local seenTerrainFloorTypes: { [Enum.Material]: boolean } = {}

--how many times someone has ever switched TO a floor type
local timesSeenTerrainFloorTypeCounts: { [Enum.Material]: number } = {}
local seenFloorCount = 0

--list of the types they've seen.
local allOrderedSeenFloorTypeSet: { [number]: Enum.Material } = {}

--TODO: fill out this guy's function.
local killClientRunBindableEvent = remotes.getBindableEvent("KillClientRunBindableEvent")

module.ResetFloorCounts = function()
	seenTerrainFloorTypes = {}
	timesSeenTerrainFloorTypeCounts = {}
	seenFloorCount = 0
	allOrderedSeenFloorTypeSet = {}
	shouldKillFloorMonitor = true
end

--setup a monitor which will kill the run if the limit is superceded
module.setupFloorTerrainMonitor = function(limit: number)
	shouldKillFloorMonitor = false
	spawn(function()
		while true do
			if shouldKillFloorMonitor then
				break
			end

			wait(0.1)
			if seenFloorCount > limit then
				local t = ""
				for k, _ in pairs(allOrderedSeenFloorTypeSet) do
					t = t .. "," .. k
				end
				killClientRunBindableEvent:Fire("superceded terrain limit by touching " .. t)
				break
			end
		end
	end)
end

module.setupNoGrassMonitor = function()
	shouldKillFloorMonitor = false
	spawn(function()
		while true do
			if shouldKillFloorMonitor then
				break
			end
			wait(0.1)
			for k, _ in pairs(seenTerrainFloorTypes) do
				if k == Enum.Material.Grass or k == Enum.Material.LeafyGrass then
					killClientRunBindableEvent:Fire("don't touch grass")
					break
				end
			end
		end
	end)
end

module.setupMold = function()
	local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	local bc: BodyColors = character:FindFirstChild("BodyColors")

	--yes this can really happen.
	if bc == nil then
		bc = Instance.new("BodyColors")
		bc.Parent = character
	end

	bc.HeadColor3 = colors.white
	bc.LeftArmColor3 = colors.white
	bc.RightArmColor3 = colors.white
	bc.LeftLegColor3 = colors.white
	bc.RightLegColor3 = colors.white
	bc.TorsoColor3 = colors.white

	shouldKillFloorMonitor = false
	spawn(function()
		while true do
			if shouldKillFloorMonitor then
				break
			end
			wait(0.1)
			for k, num in pairs(timesSeenTerrainFloorTypeCounts) do
				print(k)
				print(num)
				if k == Enum.Material.Slate then
					continue
				end
				if num > 1 then
					killClientRunBindableEvent:Fire("don't touch terrain twice")
					break
				end
			end
		end
	end)
end

--call this on 1) user joins game 2) once signal attached, floor changes.
local updateTerrainSeenBindableEvent = remotes.getBindableEvent("UpdateTerrainSeenBindableEvent")
module.CountNewFloorMaterial = function(fm)
	if fm == Enum.Material.Air then
		return
	end

	--don't count non-terrain **at all**
	if not movementEnums.nonMaterialEnumTypes[fm] then
		--track raw counts of seeing this terrain floor type
		if not timesSeenTerrainFloorTypeCounts[fm] then
			timesSeenTerrainFloorTypeCounts[fm] = 1
		else
			timesSeenTerrainFloorTypeCounts[fm] = timesSeenTerrainFloorTypeCounts[fm] + 1
		end

		--also track uniqueness and ordered unique set
		if not seenTerrainFloorTypes[fm] then
			seenTerrainFloorTypes[fm] = true
			seenFloorCount += 1
			table.insert(allOrderedSeenFloorTypeSet, fm)

			updateTerrainSeenBindableEvent:Fire(allOrderedSeenFloorTypeSet)
		end
	end
	-- annotate(string.format("New floor handled: %s", fm.Name))
end

return module
