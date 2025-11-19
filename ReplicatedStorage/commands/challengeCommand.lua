--!strict

-- challengeCommand.lua :: ReplicatedStorage.commands.challengeCommand
-- SERVER-ONLY: Issues a sign challenge.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local MessageFormatter = require(game.ReplicatedStorage.ChatSystem.messageFormatter)
local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local text = require(game.ReplicatedStorage.util.text)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = true,
}

function module.Execute(player: Player, parts: { string }): boolean
	if not parts or #parts == 0 or parts[1] == "" then
		commandUtils.SendMessage(MessageFormatter.usageCommandDesc, player)
		return true
	end
	local res = text.describeChallenge(parts)
	if res ~= "" then
		commandUtils.SendMessage(res, player)
		commandUtils.GrantCmdlineBadge(player.UserId)
		return true
	else
		commandUtils.SendMessage(MessageFormatter.usageCommandDesc, player)
		return false
	end
end

_annotate("end")
return module
