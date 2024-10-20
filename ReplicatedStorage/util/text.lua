--!strict

--bunch of text block renderers, annoyingly coupled with some game logic (rdb)
--maybe shuuld be in a commands section instead?
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local rdb = require(game.ServerScriptService.rdb)
local playerData2 = require(game.ServerScriptService.playerData2)
local colors = require(game.ReplicatedStorage.util.colors)
local tt = require(game.ReplicatedStorage.types.gametypes)
local enums = require(game.ReplicatedStorage.util.enums)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local PlayersService = game:GetService("Players")
local textUtil = require(game.ReplicatedStorage.util.textUtil)

local module = {}

--describe the find status of a specific sign for everyone in the server.
module.describeChallenge = function(parts): string
	local toUse = textUtil.coalesceFrom(parts, 2)
	local signId = tpUtil.looseSignName2SignId(toUse)
	if not signId then
		return ""
	end

	local signName = enums.signId2name[signId]
	if not signName then
		return ""
	end
	local findCount = 0
	local missCount = 0
	local finders = {}
	local missers = {}
	for _, player in pairs(PlayersService:GetPlayers()) do
		local found = playerData2.HasUserFoundSign(player.UserId, signId)
		if found then
			findCount = findCount + 1
			table.insert(finders, player.Name)
		else
			missCount = missCount + 1
			table.insert(missers, player.Name)
		end
	end
	local message = ""
	if findCount < missCount then
		if missCount == 0 then
			message = "All " .. findCount .. " people here have found " .. signName .. "!"
		else
			if findCount == 0 then
				message = "Nobody here has found " .. signName .. "!"
			elseif findCount == 1 then
				message = "Only " .. finders[1] .. " has found " .. signName .. "!"
			else
				local findersText = table.concat(finders, ", ")
				message = "Only " .. findersText .. " have found " .. signName .. "!"
			end
		end
	else
		if missCount == 0 then
			message = "All " .. findCount .. " people here have found " .. signName .. "!"
		else
			local missersText = table.concat(missers, ", ")
			message = "Everyone has found " .. signName .. " except " .. missersText .. "!"
		end
	end
	return message
end

module.describeRemainingSigns = function(looseUsername: string, describeMissing: boolean, limit: number): string
	if not limit then
		limit = 40
	end
	local player = tpUtil.looseGetPlayerFromUsername(looseUsername)
	if not player then
		return ""
	end
	if not describeMissing then
		describeMissing = false
	end
	local seen
	local seenSigns = {}
	local missingSigns = {}
	local userId = player.UserId
	for signName, signId in pairs(enums.name2signId) do
		seen = playerData2.HasUserFoundSign(userId, signId)
		if seen then
			table.insert(seenSigns, signName)
		else
			table.insert(missingSigns, signName)
		end
	end
	table.sort(seenSigns)
	table.sort(missingSigns)
	local res = ""
	if describeMissing then
		if #missingSigns == 0 then
			res = player.Name .. " has found them all. For now."
		else
			res = player.Name .. " has not found " .. #missingSigns .. ":"
			for ii, signName in ipairs(missingSigns) do
				res = res .. " " .. signName .. ","
				if limit and ii >= limit then
					res = res .. " and " .. #missingSigns - limit .. " more."
					break
				end
			end
		end
	else
		res = "You have found " .. #seenSigns .. ":"
		for ii, signName in ipairs(seenSigns) do
			res = res .. " " .. signName .. ","
			if limit and ii >= limit then
				res = res .. ", and more."
				break
			end
		end
	end
	res = string.sub(res, 1, string.len(res) - 1) .. "."
	return res
end

type messageItem = { message: string, options: any, rank: number }

--highlight people in various ways (if in top list, or stragglers)
--with generic stats generating function
module.generateTextForRankedList = function(
	results: { tt.userRankedOrderItem },
	playersInServer: { [number]: boolean },
	speakerUserId: number,
	backupGetterForPeopleNotInInputData: (
		userId: number
	) -> { count: number, rank: number, signIds: { number } }
): { messageItem }
	local messageItems = {}
	local shownUserIds: { [number]: boolean } = {}
	for _, obj in pairs(results) do
		if obj.userId < 0 then
			obj.username = "TestUser_" .. obj.userId
		else
			obj.username = playerData2.GetUsernameByUserId(obj.userId)
		end
		local color = colors.white
		--the person in the top list also is in server, so highlight them.
		if playersInServer[obj.userId] ~= nil then
			local res = tpUtil.getCardinalEmoji(obj.rank) .. ":\t" .. obj.count .. " - " .. obj.username
			color = colors.greenGo
			if obj.userId == speakerUserId then
				color = colors.meColor
			end
			table.insert(messageItems, { message = res, options = { ChatColor = color } })
			shownUserIds[obj.userId] = true
			continue
		end

		--normal case: add the person
		local res = tpUtil.getCardinalEmoji(obj.rank) .. ":\t" .. obj.count .. " - " .. obj.username
		table.insert(messageItems, { message = res, options = { ChatColor = color } })
	end

	--fallback to display stats for the other people in the server too.
	local extraMessages: { messageItem } = {}
	for userIdInServer, _ in pairs(playersInServer) do
		if shownUserIds[userIdInServer] then
			continue
		end

		local username = playerData2.GetUsernameByUserId(userIdInServer)
		local stats = backupGetterForPeopleNotInInputData(userIdInServer)
		local res = tpUtil.getCardinalEmoji(stats.rank) .. ":\t" .. stats.count .. " - " .. username
		local color = colors.greenGo
		if userIdInServer == speakerUserId then
			color = colors.meColor
		end
		table.insert(extraMessages, { message = res, options = { ChatColor = color }, rank = stats.count })
	end

	--so that player in server lists make sense? hack.
	table.sort(extraMessages, function(a, b)
		return a.rank > b.rank
	end)
	for _, msg in ipairs(extraMessages) do
		table.insert(messageItems, msg)
	end

	return messageItems
end

_annotate("end")
return module
