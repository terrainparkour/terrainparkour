--!strict

-- usernameCache.lua :: ServerScriptService.usernameCache
-- Server-side cached username lookup by userId.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local enums = require(game.ReplicatedStorage.util.enums)

local PlayersService = game:GetService("Players")

local module = {}

local playerUsernamesCache: { [number]: string } = {}

module.GetUsernameByUserId = function(userId: number): string
	if not playerUsernamesCache[userId] then
		if userId < 0 then
			playerUsernamesCache[userId] = "TestUser" .. userId
			return playerUsernamesCache[userId]
		end
		if userId == 0 then
			userId = enums.objects.ShedletskyUserId
		end
		local res
		local s, e = pcall(function()
			res = PlayersService:GetNameFromUserIdAsync(userId)
		end)
		if not s then
			warn(e)
			return "Unknown Username for " .. userId
		end

		playerUsernamesCache[userId] = res
		return res
	end

	return playerUsernamesCache[userId]
end

_annotate("end")
return module

