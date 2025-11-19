--!strict

-- marathonsCommand.lua :: ReplicatedStorage.commands.marathonsCommand
-- SERVER-ONLY: Lists available marathon events.

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

local function getMarathonKinds(): string
	local request: tt.postRequest = {
		remoteActionName = "getMarathonKinds",
		data = {},
	}
	local res = rdb.MakePostRequest(request)
	return res
end

function module.Execute(player: Player, _parts: { string }): boolean
	commandUtils.GrantCmdlineBadge(player.UserId)
	local res = getMarathonKinds()
	commandUtils.SendMessage(res, player)
	return true
end

_annotate("end")
return module

