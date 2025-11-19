--!strict

-- describeSingleSignCommand.lua :: ReplicatedStorage.commands.describeSingleSignCommand
-- SERVER-ONLY: Helper function to describe a single sign (not a direct command).

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayersService = game:GetService("Players")

local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local MessageFormatter = require(game.ReplicatedStorage.ChatSystem.messageFormatter)
local config = require(game.ReplicatedStorage.config)
local enums = require(game.ReplicatedStorage.util.enums)
local tt = require(game.ReplicatedStorage.types.gametypes)
local colors = require(game.ReplicatedStorage.util.colors)
local playerData2 = require(game.ServerScriptService.playerData2)
local rdb = require(game.ServerScriptService.rdb)

type DescribeSignFunction = (player: Player, signId: number) -> ()

local module: { Execute: DescribeSignFunction } = {} :: { Execute: DescribeSignFunction }

function module.Execute(player: Player, signId: number): ()
	local userIdsInServer: { [number]: boolean } = {}
	for _, serverPlayer in ipairs(PlayersService:GetPlayers()) do
		userIdsInServer[serverPlayer.UserId] = true
	end
	if config.IsInStudio() then
		userIdsInServer[enums.objects.BrouhahahaUserId] = true
	end
	local request: tt.postRequest = {
		remoteActionName = "getTotalFindCountBySign",
		data = { signId = signId },
	}
	local signTotalFindsResponse: { count: number } = rdb.MakePostRequest(request) :: { count: number }
	local signTotalFinds: number = signTotalFindsResponse.count
	local signName: string = enums.signId2name[signId] :: string
	if not playerData2.HasUserFoundSign(player.UserId, signId) then
		local ret = string.format(
			"You haven't found %s yet, so can't look up information on it. But %d people have found it.",
			signName,
			signTotalFinds
		)
		commandUtils.SendMessage(ret, player)
		return
	end

	type signLeader = { userId: number, count: number }

	local request2: tt.postRequest = {
		remoteActionName = "getSignStartLeader",
		data = { signId = signId },
	}
	local fromleaders: { signLeader } = rdb.MakePostRequest(request2)
	local request3: tt.postRequest = {
		remoteActionName = "getSignEndLeader",
		data = { signId = signId },
	}
	local toleaders: { signLeader } = rdb.MakePostRequest(request3)

	local countsByUserId: { [number]: { to: number, from: number, username: string, inServer: boolean, userId: number } } = {}
	local leaderText = "\nSign Leader for "
		.. signName
		.. "!\n"
		.. tostring(signTotalFinds)
		.. " players have found "
		.. signName
		.. "\nrank name total (from/to)"
	commandUtils.SendMessage(leaderText, player)

	for _, leader in ipairs(fromleaders) do
		local userId = leader.userId
		if countsByUserId[userId] == nil then
			local username: string
			if userId < 0 then
				username = "TestUser" .. userId
			else
				username = playerData2.GetUsernameByUserId(userId)
			end
			countsByUserId[userId] = { to = 0, from = 0, username = username, inServer = false, userId = userId }
		end
		if userIdsInServer[userId] then
			countsByUserId[userId].inServer = true
		end
		countsByUserId[userId].from = countsByUserId[userId].from + leader.count
	end

	for _, leader in ipairs(toleaders) do
		local userId = leader.userId
		if countsByUserId[userId] == nil then
			local username: string
			if userId < 0 then
				username = "TestUser" .. userId
			else
				username = playerData2.GetUsernameByUserId(userId)
			end
			countsByUserId[userId] = { to = 0, from = 0, username = username, inServer = false, userId = userId }
		end
		if userIdsInServer[userId] then
			countsByUserId[userId].inServer = true
		end
		countsByUserId[userId].to = countsByUserId[userId].to + leader.count
	end
	type LeaderEntry = { to: number, from: number, username: string, inServer: boolean, userId: number }
	local tbl: { LeaderEntry } = {}
	for _, item in pairs(countsByUserId) do
		table.insert(tbl, item)
	end
	table.sort(tbl, function(a, b)
		return a.to + a.from > b.to + b.from
	end)

	for ii, item in ipairs(tbl) do
		local line = string.format("%d. %s - %d (%d/%d)", ii, item.username, item.to + item.from, item.from, item.to)
		if item.inServer then
			line = MessageFormatter.formatWithColor(line, colors.greenGo)
		else
			line = MessageFormatter.formatWithColor(line, colors.white)
		end
		commandUtils.SendMessage(line, player)
	end
end

_annotate("end")
return module

