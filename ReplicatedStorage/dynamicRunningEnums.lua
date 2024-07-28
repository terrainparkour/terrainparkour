--!strict

-- draw a ui which appends uis on nearby found sign statuses

--used on client to kick off sending loops
--10.09 bugfixing why this breaks servers

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local actions = { DYNAMIC_STOP = "stop", DYNAMIC_START = "start" }
module.ACTIONS = actions

_annotate("end")
return module
