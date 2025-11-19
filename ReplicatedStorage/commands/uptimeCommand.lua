--!strict

-- uptimeCommand.lua :: ReplicatedStorage.commands.uptimeCommand
-- SERVER-ONLY: Displays server uptime. Requires boot time from CommandService.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)
local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = true,
}

local _bootTime = tick()

function module.Execute(player: Player, _parts: { string }): boolean
	local uptimeTicks = tick() - _bootTime
	local days = 0
	local hours = 0
	local minutes = 0

	if uptimeTicks >= 86400 then
		days = math.floor(uptimeTicks / 86400)
		uptimeTicks = uptimeTicks - days * 86400
	end

	if uptimeTicks >= 3600 then
		hours = math.floor(uptimeTicks / 3600)
		uptimeTicks = uptimeTicks - hours * 3600
	end

	if uptimeTicks >= 60 then
		minutes = math.floor(uptimeTicks / 60)
		uptimeTicks = uptimeTicks - minutes * 60
	end

	local message =
		string.format("Server Uptime:  - %d days %d hours %d minutes %d seconds", days, hours, minutes, uptimeTicks)

	commandUtils.SendMessage(message, player)
	commandUtils.GrantUndocumentedCommandBadge(player.UserId)

	return true
end

_annotate("end")
return module
