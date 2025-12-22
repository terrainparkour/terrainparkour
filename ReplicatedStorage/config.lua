--!strict
-- config.lua @ ReplicatedStorage.config
-- Game-global configuration flags and environment detection helpers.

local module = {}

-- Module internals
module.ENABLE_RUN_DATA_COLLECTION = false
module.ENABLE_LUA2JSON_DIAGNOSTICS = false
module.ENABLE_SERVER_TIMING = true -- Send run starts to server for timing security analysis
module.AUTO_OPEN_WIDGET_PICKER = false -- Automatically open run widget picker on game start (dev toggle)

module.IsInStudio = function()
	local forceProd = false
	if forceProd then
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

module.IsTestGame = function()
	local gameName = game.Name
	local hasDevPlace = string.find(gameName, "Dev Place", 1, true) ~= nil
	if hasDevPlace then
		return true
	end
	return false
end

return module
