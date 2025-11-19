--!strict

-- commonCommand.lua :: ReplicatedStorage.commands.commonCommand
-- SERVER-ONLY: Lists signs everyone in server has found.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local playerData2 = require(game.ServerScriptService.playerData2)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = true,
}

function module.Execute(player: Player, _parts: { string }): boolean
	local signNames = playerData2.getCommonFoundSignNames()
	local res = "Signs everyone in server has found: "

	for _, signName in ipairs(signNames) do
		res = res .. signName .. ", "
	end
	commandUtils.SendMessage(res, player)
	commandUtils.GrantCmdlineBadge(player.UserId)
	return true
end

_annotate("end")
return module

