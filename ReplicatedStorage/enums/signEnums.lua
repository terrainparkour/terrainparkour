--!strict

--used for signs special behavior - both movement, appearance, etc. anything that i'm not going to store in the world file itself.

local module = {}

local signs = {
	COLD_MOLD = "cOld mOld on a sLate pLate",
	HYPERGRAVITY = "Hypergravity",
	GRASS = "Keep Off the Grass",
	QUADRUPLE = "Quadruple",
	TRIPLE = "Triple",
	GHOST = "👻",
	BIG = "Big",
	SMALL = "Small",
	PULSE = "Pulse",
}
module.signs = signs

return module
