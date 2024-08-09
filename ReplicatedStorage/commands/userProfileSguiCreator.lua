--!strict

--NOT working/finished - player profile creator.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local tt = require(game.ReplicatedStorage.types.gametypes)
local module = {}

module.createSgui = function(localPlayer: Player, data: tt.playerProfileData) end

_annotate("end")
return module
