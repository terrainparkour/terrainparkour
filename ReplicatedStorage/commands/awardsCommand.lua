--!strict

-- awardsCommand.lua :: ReplicatedStorage.commands.awardsCommand
-- SERVER-ONLY: Fetches contest awards for a user.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local tt = require(game.ReplicatedStorage.types.gametypes)
local rdb = require(game.ServerScriptService.rdb)
local textUtil = require(game.ReplicatedStorage.util.textUtil)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = true,
}

function module.Execute(player: Player, parts: { string }): boolean
	local username: string = player.Name
	if #parts > 0 then
		username = parts[1]
	end

	local request: tt.postRequest = {
		remoteActionName = "getAwardsByUser",
		data = { username = username, userId = player.UserId },
	}
	local data: { tt.userAward } = rdb.MakePostRequest(request)
	local res = {}

	if #data > 0 then
		table.insert(res, "Awards for " .. username)
		for ii, el in ipairs(data) do
			local item = string.format("%d - %s in %s", ii, el.awardName, el.contestName)
			table.insert(res, item)
		end
	else
		table.insert(res, "No awards for that person.")
	end

	local msg = textUtil.stringJoin("\n", res)
	commandUtils.SendMessage(msg, player)
	commandUtils.GrantCmdlineBadge(player.UserId)
	return true
end

_annotate("end")
return module
