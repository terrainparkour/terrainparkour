--!strict

-- 9.05.22 start
-- draw a ui which appends uis on nearby found sign statuses

--used on client to kick off sending loops
--eval 9.24.22
--10.09 bugfixing why this breaks servers
local module={}

local actions={DYNAMIC_STOP="stop", DYNAMIC_START='start'}
module.ACTIONS=actions

return module