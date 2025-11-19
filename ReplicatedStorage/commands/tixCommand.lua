--!strict

-- tixCommand.lua :: ReplicatedStorage.commands.tixCommand
-- SERVER-ONLY: Checks ticket balance for a user.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local tt = require(game.ReplicatedStorage.types.gametypes)
local rdb = require(game.ServerScriptService.rdb)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = true,
}

local function getTixBalanceByUsername(username: string): { success: boolean, message: string? }
	local request: tt.postRequest = {
		remoteActionName = "getTixBalanceByUsername",
		data = { username = username },
	}
	local res = rdb.MakePostRequest(request)
	return res
end

function module.Execute(player: Player, parts: { string }): boolean
	local target: string
	if not parts or #parts == 0 then
		target = player.Name
	else
		target = parts[1]
	end
	local res = getTixBalanceByUsername(target)
	if res.success then
		if res.message then
			commandUtils.SendMessage(res.message, player)
		end
		commandUtils.GrantCmdlineBadge(player.UserId)
	end
	if not res.success then
		if res.message then
			commandUtils.SendMessage(res.message, player)
		end
	end
	return true
end

_annotate("end")
return module

