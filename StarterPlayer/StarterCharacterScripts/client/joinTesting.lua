--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local config = require(game.ReplicatedStorage.config)

if config.IsTestGame() then
	-- Test code can be added here if needed
end

_annotate("end")

return module
