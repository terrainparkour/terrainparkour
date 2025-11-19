--!strict

-- randomCommand.lua :: ReplicatedStorage.commands.randomCommand
-- SERVER-ONLY: Returns a random sign the player has found.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local playerData2 = require(game.ServerScriptService.playerData2)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = true,
}

local function getRandomFoundSignName(userId: number): string
	local items = playerData2.GetUserSignFinds(userId, "getRandomFoundSignName")
	local choices = {}
	for signId: number, found: boolean in pairs(items) do
		if found then
			table.insert(choices, signId)
		end
	end
	local signId = choices[math.random(#choices)]
	local signName = tpUtil.signId2signName(signId)
	if signName == nil or signName == "" then
		warn("bad.")
	end
	return signName or ""
end

function module.Execute(player: Player, _parts: { string }): boolean
	local rndSign = getRandomFoundSignName(player.UserId)
	local res = "Random Sign You've found: " .. rndSign .. "."
	commandUtils.SendMessage(res, player)
	commandUtils.GrantCmdlineBadge(player.UserId)
	return true
end

_annotate("end")
return module

