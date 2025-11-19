--!strict

-- secretCommand.lua :: ReplicatedStorage.commands.secretCommand
-- SERVER-ONLY: Grants secret badge to player.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)
local grantBadge = require(game.ServerScriptService.grantBadge)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "private",
	ChannelRestriction = "any",
	AutocompleteVisible = false,
}

function module.Execute(player: Player, _parts: { string }): boolean
	local badgeGranted = (grantBadge :: any).GrantBadge(player.UserId, badgeEnums.badges.Secret)
	if badgeGranted then
		commandUtils.SendMessage(player.Name .. " has found the secret badge!", player)
	end
	return true
end

_annotate("end")
return module

