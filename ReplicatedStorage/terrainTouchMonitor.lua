--!strict

--------------- RACING MODULE calls this, it's a singleton per user which is fed all floor changes.
-- thinking about it, it's still weird that this is not really closer to morphs, or really even another client modulescript
-- called specialSigns which just monitors the active sign, and then periodically updates that sign's text.
-- or even a folder of signs such that eahc one could be fed with info on terrain changes, location, etc and then would od things
-- hooking into the general movement.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local movementEnums = require(game.StarterPlayer.StarterPlayerScripts.movementEnums)
local activeRunSGui = require(game.ReplicatedStorage.gui.activeRunSGui)
local textUtil = require(game.ReplicatedStorage.util.textUtil)

local PlayersService = game:GetService("Players")
local localPlayer = PlayersService.LocalPlayer

local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local fireEvent = avatarEventFiring.FireEvent
local mt = require(game.ReplicatedStorage.avatarEventTypes)
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid: Humanoid = character:WaitForChild("Humanoid") :: Humanoid

local module = {}

------------- GLOBALS -------------

--boolean if they have touched the floor type at all.
local seenTerrainFloorTypes: { [string]: boolean } = {}

--how many times someone has ever switched TO a floor type
local timesSeenTerrainFloorTypeCounts: { [Enum.Material]: number } = {}
local seenFloorCount = 0
local currentRunSignName = ""
local lastSeenTerrain = nil

--list of the types they've seen.
local allOrderedSeenFloorTypeSet: { [number]: Enum.Material } = {}

------------- FUNCTIONS -------------

local ResetFloorCounts = function()
	seenTerrainFloorTypes = {}
	timesSeenTerrainFloorTypeCounts = {}
	seenFloorCount = 0
	currentRunSignName = ""
	allOrderedSeenFloorTypeSet = {}
	lastSeenTerrain = nil
end

module.initTracking = function(signName: string)
	ResetFloorCounts()
	currentRunSignName = signName
	if signName == nil then
		warn("initTracking: nil signName")
		return
	end
	_annotate(string.format("initTracking: %s", signName))
end

module.GetSeenTerrainTypesCountThisRun = function(): number
	return seenFloorCount
end

module.CountNewFloorMaterial = function(fm: Enum.Material?)
	--------- VALIDATION -------------
	if currentRunSignName == "" or not currentRunSignName then
		return
	end

	if fm == nil then
		error("nil touch.")
	end
	if movementEnums.nonMaterialEnumTypes[fm] then
		return
	end
	if not movementEnums.EnumIsTerrain(fm) then
		return
	end

	if fm == lastSeenTerrain then
		return
	end

	--------- COUNTING IT ---------------
	lastSeenTerrain = fm
	_annotate(string.format("Saw Terrain: %s", fm.Name))
	--track raw counts of seeing this terrain floor type
	if not timesSeenTerrainFloorTypeCounts[fm] then
		timesSeenTerrainFloorTypeCounts[fm] = 1
	else
		timesSeenTerrainFloorTypeCounts[fm] = timesSeenTerrainFloorTypeCounts[fm] + 1
	end
	if not seenTerrainFloorTypes[fm.Name] then
		seenTerrainFloorTypes[fm.Name] = true
		seenFloorCount += 1
		table.insert(allOrderedSeenFloorTypeSet, fm)
	end

	------regenerating running race sgui
	if currentRunSignName == "Triple" or currentRunSignName == "Quadruple" then
		local t = {}

		for terrain, n in pairs(seenTerrainFloorTypes) do
			if n then
				table.insert(t, terrain)
			end
		end

		local listOfSeenTerrains = textUtil.stringJoin(", ", t)

		activeRunSGui.UpdateMovementDetails(listOfSeenTerrains)
	elseif currentRunSignName == "cOld mOld on a sLate pLate" then
		local t: { string } = {}
		for a, b in pairs(movementEnums.AllTerrainNames) do
			if seenTerrainFloorTypes[b] then
				continue
			end
			table.insert(t, b)
		end
		table.sort(t)
		local remainingTouchables = textUtil.stringJoin(", ", t)
		local remainingTouchableTerrains = string.format("Remaining: %s", remainingTouchables)
		activeRunSGui.UpdateMovementDetails(remainingTouchableTerrains)
	end

	-------- KILLING RUN IF NECESSARY--------------
	if currentRunSignName == "cOld mOld on a sLate pLate" then
		for k, num in pairs(timesSeenTerrainFloorTypeCounts) do
			if num > 1 then
				fireEvent(mt.avatarEventTypes.RUN_CANCEL, { reason = "cold violation" })
				break
			end
		end
	elseif currentRunSignName == "Keep Off the Grass" then
		if fm == Enum.Material.LeafyGrass or fm == Enum.Material.Grass then
			fireEvent(mt.avatarEventTypes.RUN_CANCEL, { reason = "Keep off the grass terrainTouch" })
		end
	elseif currentRunSignName == "Triple" then
		if seenFloorCount > 3 then
			fireEvent(mt.avatarEventTypes.RUN_CANCEL, { reason = "triple terrainTouch" })
		end
	elseif currentRunSignName == "Quadruple" then
		if seenFloorCount > 4 then
			fireEvent(mt.avatarEventTypes.RUN_CANCEL, { reason = "quadruple terrainTouch" })
		end
	end
end

module.Init = function()
	character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	humanoid = character:WaitForChild("Humanoid")

	seenTerrainFloorTypes = {}

	timesSeenTerrainFloorTypeCounts = {}
	seenFloorCount = 0
	currentRunSignName = ""
	lastSeenTerrain = nil
end

_annotate("end")
return module
