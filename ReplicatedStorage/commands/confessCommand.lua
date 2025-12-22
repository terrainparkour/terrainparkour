--!strict

-- confessCommand.lua :: ReplicatedStorage.commands.confessCommand
-- SERVER-ONLY: Allows users to voluntarily confess about cheating or other violations.
-- Usage: /confess <your message>
-- 
-- PURPOSE: This is a voluntary amnesty tool. Players who have cheated can privately
-- request their record be cleaned (e.g., removing all their WR runs). This is handled
-- with discretion - no automatic action is taken. Admin reviews and decides response.
--
-- IMPORTANT: Confessions are NEVER used as evidence against the user.
--
-- If a user already has an unprocessed confession, their new message is appended
-- to the existing one (rather than creating a new entry).

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)
local rdb = require(game.ServerScriptService.rdb)
local textUtil = require(game.ReplicatedStorage.util.textUtil)
local tt = require(game.ReplicatedStorage.types.gametypes)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = false, -- Keep this private/discreet
}

function module.Execute(player: Player, parts: { string }): boolean
	if #parts == 0 then
		commandUtils.SendMessage("Usage: /confess <your message>", player)
		commandUtils.SendMessage("This command lets you privately confess about cheating or other issues.", player)
		commandUtils.SendMessage("Your record can then be cleaned (e.g., removing all your WRs).", player)
		commandUtils.SendMessage("This is voluntary and confidential. Confessions are never used as evidence.", player)
		commandUtils.SendMessage("You can add to an existing confession by using this command again.", player)
		return true
	end

	local message = textUtil.stringJoin(" ", parts)
	if #message == 0 then
		commandUtils.SendMessage("Usage: /confess <your message>", player)
		return true
	end

	local request: tt.postRequest = {
		remoteActionName = "submitConfession",
		data = {
			userId = player.UserId,
			message = message,
		},
	}

	_annotate(string.format("Submitting confession for user %d", player.UserId))
	local response: any = rdb.MakePostRequest(request)

	if not response then
		commandUtils.SendMessage("Failed to submit. Please try again later.", player)
		return false
	end

	if response.error then
		commandUtils.SendMessage(response.message or "Failed to submit confession.", player)
		return true
	end

	if response.success then
		if response.appended then
			commandUtils.SendMessage("Your message has been added to your existing confession.", player)
		else
			commandUtils.SendMessage("Your confession has been recorded.", player)
		end
		commandUtils.SendMessage("Thank you for your honesty. An admin will review it privately.", player)
		return true
	end

	commandUtils.SendMessage("Unexpected error submitting confession.", player)
	return false
end

_annotate("end")
return module

