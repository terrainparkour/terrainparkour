--!strict

-- anyBanCommand.lua :: ReplicatedStorage.commands.anyBanCommand
-- SERVER-ONLY: Admin moderation commands (ban/unban/softban/hardban).

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)

local banning = require(game.ServerScriptService.banning)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "private",
	ChannelRestriction = "any",
	AutocompleteVisible = false,
}

function module.Execute(player: Player, parts: { string }): boolean
	if #parts < 1 then
		return false
	end
	local cmd = parts[1]
	local object = ""
	if #parts >= 2 then
		object = parts[2]
	end

	local target = tpUtil.looseGetPlayerFromUsername(object)
	if not target then
		return false
	end
	if cmd == "unban" then
		banning.unBanUser(target.UserId)
	end
	if cmd == "softban" or cmd == "ban" then
		banning.softBanUser(target.UserId)
	end
	if cmd == "hardban" then
		banning.hardBanUser(target.UserId)
	end
	return true
end

_annotate("end")
return module
