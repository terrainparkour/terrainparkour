--!strict

-- nonwrsCommand.lua :: ReplicatedStorage.commands.nonwrsCommand
-- SERVER-ONLY: Lists non-WR races to/from a sign.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local MessageFormatter = require(game.ReplicatedStorage.ChatSystem.messageFormatter)
local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local tt = require(game.ReplicatedStorage.types.gametypes)
local playerData2 = require(game.ServerScriptService.playerData2)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local textUtil = require(game.ReplicatedStorage.util.textUtil)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "data_only",
	AutocompleteVisible = true,
}

function module.Execute(player: Player, parts: { string }): boolean
	if not commandUtils.RequireArguments(parts, 2) then
		commandUtils.SendMessage("Usage: /nonwrs <to|from|both> <signname>", player)
		return true
	end

	local to = parts[1]
	local signName = textUtil.stringJoin(" ", { parts[2] })
	if #parts > 2 then
		signName = textUtil.stringJoin(" ", { parts[2], parts[3] })
	end

	local signId = tpUtil.looseSignName2SignId(signName)
	if signId == nil then
		commandUtils.SendMessage("Could not find that sign.", player)
		return true
	end

	local signNameFormatted = tpUtil.signId2signName(signId)
	local totext = to
	if to == "both" then
		totext = "to/from"
	end
	commandUtils.SendMessage("NonWR races " .. totext .. " " .. signNameFormatted .. " for: " .. player.Name, player)
	local data: tt.getNonTop10RacesByUser =
		playerData2.getNonWRsByToSignIdAndUserId(to, signId, player.UserId, "nonwr_command")
	for _, runDesc in ipairs(data.raceDescriptions) do
		local formatted = MessageFormatter.formatWithFont(" * " .. runDesc, "Code")
		commandUtils.SendMessage(formatted, player)
	end
	commandUtils.GrantCmdlineBadge(player.UserId)
	return true
end

_annotate("end")
return module
