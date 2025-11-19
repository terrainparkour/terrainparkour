--!strict

-- marathonCommand.lua :: ReplicatedStorage.commands.marathonCommand
-- SERVER-ONLY: Shows details for a specific marathon.

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

local function getMarathonKindLeaders(marathonKind: string): string
	local request: tt.postRequest = {
		remoteActionName = "getMarathonKindLeaders",
		data = { marathonKind = marathonKind },
	}
	local res = rdb.MakePostRequest(request)
	return res
end

function module.Execute(player: Player, parts: { string }): boolean
	if not commandUtils.RequireArguments(parts, 1) then
		commandUtils.SendMessage("Usage: /marathon <name>", player)
		return true
	end
	local res = getMarathonKindLeaders(parts[1])
	if not res then
		res = "Couldn't find that marathon."
	end
	commandUtils.SendMessage(res, player)
	commandUtils.GrantCmdlineBadge(player.UserId)
	return true
end

_annotate("end")
return module

