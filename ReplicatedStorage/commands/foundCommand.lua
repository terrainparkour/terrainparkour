--!strict

-- foundCommand.lua :: ReplicatedStorage.commands.foundCommand
-- SERVER-ONLY: Lists signs a player has found.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local text = require(game.ReplicatedStorage.util.text)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = true,
}

function module.Execute(player: Player, parts: { string }): boolean
	local target: string?
	if not parts or #parts == 0 then
		target = player.Name
	else
		local targetPlayer: Player? = tpUtil.looseGetPlayerFromUsername(parts[1])
		if targetPlayer then
			target = targetPlayer.Name
		end
		if not target then
			local res = "Could not find that."
			commandUtils.SendMessage(res, player)
			return true
		end
	end
	if target == nil then
		return false
	end
	local res = text.describeRemainingSigns(target :: string, false, 500)
	if res ~= "" then
		commandUtils.SendMessage(res, player)
		commandUtils.GrantCmdlineBadge(player.UserId)
		return true
	end
	return false
end

_annotate("end")
return module

