--!strict
--eval 9.24.22

--splitting out sign position management

local module = {}
local positions: { [number]: Vector3 } = {}
local positionKnownSignIds = {}
local signCount = 0

--this just stores it in memory; distinct from updateSignPosition which re-sends them all to the server for BE calculations.
module.storeSignPositionInMemory = function(signId, position: Vector3)
	positions[signId] = position
	table.insert(positionKnownSignIds, signId)
	signCount = signCount + 1
end

module.getSignPosition = function(signId: number)
	return positions[signId]
end

module.getSignCountReal = function()
	return signCount
end

module.positionKnownSignIds = positionKnownSignIds

--total sign count, hiding one or more signs from users.
module.getSignCountInGameForUserConsumption = function()
	--yes we lie
	return signCount - 1
end

return module
