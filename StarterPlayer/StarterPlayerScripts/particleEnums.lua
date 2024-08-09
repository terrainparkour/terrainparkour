--!strict

-- particleEnums.lua
-- descriptors for particle emission from the player, with color, state etc.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

type particleDescriptor = {
	name: string,
	color: Color3,
	duration: number,
	
	state: string,
	size: number,
	speed: number,
	spread: number,
	gravity: number,
}

local particles = {}

_annotate("end")
return module
