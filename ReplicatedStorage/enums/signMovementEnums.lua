--!strict

--movement mode enums from particular signs. nojump etc.

local module = {}

export type movementModeMessage = { action: string, reason: string }

--these are the special signs that if you touch them, they change the way you move, or sometimes reset your runs if you violate the rule.
local movementModes = {
	NOJUMP = "nojump",
	RESTORE = "restore",
	FASTER = "faster",
	THREETERRAIN = "threeterrain",
	FOURTERRAIN = "fourterrain",
	HIGHJUMP = "highjump",
	NOGRASS = "nograss",
	COLD_MOLD = "cold_mold",
	SLIPPERY = "slippery",
	PULSED = "pulsed",
	SHRINK = "shrink",
	ENLARGE = "enlarge",
	GHOST = "ghost",
}
module.movementModes = movementModes

return module
