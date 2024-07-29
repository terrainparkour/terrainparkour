--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local rdb = require(game.ServerScriptService.rdb)

local remotes = require(game.ReplicatedStorage.util.remotes)
local ShowSignsEvent = remotes.getRemoteEvent("ShowSignsEvent")

local module = {}

module.ShowSignCommand = function(player: Player): boolean
	_annotate(string.format("SeenSignCommand for player %s", player.Name))
	local signIds: { [number]: boolean } = rdb.getUserSignFinds(player.UserId)
	local actualSignIds = {}
	for signId, val in pairs(signIds) do
		if val then
			table.insert(actualSignIds, signId)
		end
	end

	ShowSignsEvent:FireClient(player, actualSignIds)
	return true
end

_annotate("end")
return module
