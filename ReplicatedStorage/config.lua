--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

-- controlling which server endpoints/debugging status should be used.
module.isInStudio = function()
	local forceProd = false
	if forceProd then
		print("FORCE PROD....")
		return false
	end

	local isInStudio = false
	if game.JobId == "" then
		isInStudio = true
	end
	if game.JobId == "00000000-0000-0000-0000-000000000000" then
		isInStudio = true
	end
	return isInStudio
end

module.isTestGame = function()
	if string.gmatch(game.Name, "Terrain Parkour Dev Place") then
		return true
	end
	return false
end

_annotate("end")
return module
