--!strict
--DEBUG in a breakpoint-preserving way.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local module = {}

module.debug = function()
	local _ = 42
end

_annotate("end")
return module
