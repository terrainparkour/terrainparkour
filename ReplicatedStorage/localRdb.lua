--!strict

-- this is local rdb.
-- this is a client or server both usable version of getUsernameByUserId
-- YES there will be value duplication on client, NO that doesn't matter really.
--2024 todo?

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayersService = game:GetService("Players")

local module = {}

local playerUsernames = {}
module.GetUsernameByUserId = function(userId: number): string
	if not playerUsernames[userId] then
		--just shortcut this to save time on async lookup.
		if userId < 0 then
			playerUsernames[userId] = "TestUser " .. userId
			return playerUsernames[userId]
		end
		if userId == 0 then
			--missing userid escalate to shedletsky
			userId = 261
		end
		local res
		local s, e = pcall(function()
			res = PlayersService:GetNameFromUserIdAsync(userId)
		end)
		if not s then
			warn(e)
			return "Unknown Username for " .. userId
		end

		playerUsernames[userId] = res
		return res
	end

	return playerUsernames[userId]
end

_annotate("end")
return module
