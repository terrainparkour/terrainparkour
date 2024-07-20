--!strict

-- this is a client or server both usable version of getUsernameByUserId
-- YES there will be value duplication on client, NO that doesn't matter really.

local PlayersService = game:GetService("Players")

local module = {}

--this is only available on the server unfortunately.
local playerUsernames = {}
module.getUsernameByUserId = function(userId: number)
	if not playerUsernames[userId] then
		--just shortcut this to save time on async lookup.
		if userId < 0 then
			playerUsernames[userId] = "test user " .. userId
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

return module
