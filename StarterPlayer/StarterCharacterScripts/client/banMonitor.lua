--!strict

--zoomlevel, jump base etc.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local remotes = require(game.ReplicatedStorage.util.remotes)

local module = {}

--2022.04 unclear if works.
task.spawn(function()
	while true do
		local lastBanLevel = 0

		local getBanStatusRemoteFunction = remotes.getRemoteFunction("GetBanStatusRemoteFunction")
		if getBanStatusRemoteFunction then
			local banLevel = getBanStatusRemoteFunction:InvokeServer()
			if banLevel ~= nil then
				if banLevel == 0 and banLevel ~= lastBanLevel then
					--
				elseif banLevel == 1 then
					-- runSpeed = 16
					-- walkSpeed = 43
					-- afterJumpRunSpeed = 37
					-- afterSwimmingRunSpeed = 30
				elseif banLevel == 2 then
					-- runSpeed = 4
					-- walkSpeed = 12
					-- afterJumpRunSpeed = 27
					-- afterSwimmingRunSpeed = 20
					--TODO this is broken.
				end
			end
			lastBanLevel = banLevel
		end
		wait(20)
	end
end)

_annotate("end")
return module
