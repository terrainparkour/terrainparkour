--!strict

-- some terms:
-- "client" / player is the roblox client
-- server usually is either the roblox game server (where serverscripts can run)
-- but also might be my external, db server which runs python + mysql.
-- the roblox one will

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local config = require(game.ReplicatedStorage.config)
local testTpPlacementLogic = require(game.ReplicatedStorage.product.testTpPlacementLogic)

module.TestAll = function()
	if config.IsInStudio() then
		print("Running TPLogic tests:")
		testTpPlacementLogic.TestAll()
	end
end

_annotate("end")
return module
