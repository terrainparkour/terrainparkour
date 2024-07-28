--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local rdb = require(game.ServerScriptService.rdb)
local tt = require(game.ReplicatedStorage.types.gametypes)

local remotes = require(game.ReplicatedStorage.util.remotes)
local ShowSignProfileEvent = remotes.getRemoteEvent("ShowSignProfileEvent")

local module = {}

module.showSignsCommand = function(player: Player)
	local data: { number } = rdb.getFoundSignIdsByUserId(player.UserId)
	if data then
		ShowSignProfileEvent:FireClient(player, data)
	end
end

_annotate("end")
return module
