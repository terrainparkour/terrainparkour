--!strict

--movement mode enums from particular signs. nojump etc.

local module = {}

export type movementModeMessage = { action: string }

local movementModes = {
	NOJUMP = "nojump",
	RESTORE = "restore",
	FASTER = "faster",
	THREETERRAIN = "threeterrain",
	FOURTERRAIN = "fourterrain",
	HIGHJUMP = "highjump",
	NOGRASS = "nograss",
	COLDMOLD = "coldmold",
}
module.movementModes = movementModes

return module
