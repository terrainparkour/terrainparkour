--!strict
--DEBUG in a breakpoint-preserving way.

local module = {}

module.debug = function()
	local _ = 42
end

return module
