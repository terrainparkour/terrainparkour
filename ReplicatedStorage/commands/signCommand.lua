--!strict

-- signCommand.lua :: ReplicatedStorage.commands.signCommand
-- SERVER-ONLY: Shows sign profile details.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local signProfileCommand = require(game.ReplicatedStorage.commands.signProfileCommand)
local playerData2 = require(game.ServerScriptService.playerData2)
local textUtil = require(game.ReplicatedStorage.util.textUtil)
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
	if not commandUtils.RequireArguments(parts, 1) then
		commandUtils.SendMessage("Usage: /sign <signname> [username]", player)
		return true
	end

	local subjectUsername: string = player.Name
	local signName = textUtil.stringJoin(" ", parts)
	local signId = tpUtil.looseSignName2SignId(signName)

	if not signId then
		-- multi-word sign, take all the ones before last
		subjectUsername = parts[#parts]
		local signParts = {}
		for i = 1, #parts - 1 do
			table.insert(signParts, parts[i])
		end
		signName = textUtil.stringJoin(" ", signParts)
		signId = tpUtil.looseSignName2SignId(signName)
	end

	if not signId then
		signName = textUtil.stringJoin(" ", parts)
		signId = tpUtil.looseSignName2SignId(signName)
	end

	if signId and subjectUsername then
		if not playerData2.HasUserFoundSign(player.UserId, signId) then
			commandUtils.SendMessage("You haven't found that sign yet.", player)
			return true
		end
		commandUtils.GrantCmdlineBadge(player.UserId)
		signProfileCommand.signProfileCommand(subjectUsername, signId, player)
		return true
	else
		commandUtils.SendMessage("Could not find that sign.", player)
		return true
	end
end

_annotate("end")
return module

