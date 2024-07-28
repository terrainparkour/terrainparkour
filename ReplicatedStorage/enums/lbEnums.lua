--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

module.lbTransparency = 0.0
module.actionButtonHeightPixels = 26

_annotate("end")
return module
