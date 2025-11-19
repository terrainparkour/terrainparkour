--!strict

-- hintCommand.lua :: ReplicatedStorage.commands.hintCommand
-- SERVER-ONLY: Lists remaining signs for a player.

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
	if #parts == 0 then
		target = player.Name
	elseif #parts == 1 then
		local ctarget = tpUtil.looseGetPlayerFromUsername(parts[1])
		if ctarget == nil then
			commandUtils.SendMessage("Could not find that player.", player)
			return true
		end
		target = ctarget.Name
	else
		error(string.format("the count of parts here should be exactly 0 or 1. hmm. got %d", #parts))
	end

	if target then
		local res = text.describeRemainingSigns(target, true, 100)
		if res ~= "" then
			commandUtils.SendMessage(res, player)
			commandUtils.GrantCmdlineBadge(player.UserId)
			return true
		end
	end

	if not target then
		local res = "Player not found in server."
		commandUtils.SendMessage(res, player)
		return true
	end

	return false
end

_annotate("end")
return module
