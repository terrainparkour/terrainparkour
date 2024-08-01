--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local rdb = require(game.ServerScriptService.rdb)

local remotes = require(game.ReplicatedStorage.util.remotes)
local ShowSignsEvent = remotes.getRemoteEvent("ShowSignsEvent")

local module = {}

module.ShowSignCommand = function(player: Player, targetUserId: number?): boolean
	_annotate(string.format("SeenSignCommand for player %s, targetUserId: %s", player.Name, tostring(targetUserId)))
	local usingTarget = targetUserId
	local actualSignIds = {}
	local extraText = ""
	if usingTarget then
		local hisSignIds: { [number]: boolean } = rdb.getUserSignFinds(usingTarget)
		local playerSignIds: { [number]: boolean } = rdb.getUserSignFinds(player.UserId)
		local heHasThatYouDontHave = {}
		local youHaveThatHeDoesntHave = {}
		for signId, val in pairs(hisSignIds) do
			if not playerSignIds[signId] then
				table.insert(heHasThatYouDontHave, signId)
			end
		end
		for signId, val in pairs(playerSignIds) do
			actualSignIds[signId] = val
			if not hisSignIds[signId] then
				table.insert(youHaveThatHeDoesntHave, signId)
			end
		end
		extraText = string.format(
			"You have %d signs he doesn't have, and he has %d signs you don't have. Displaying signs you have.",
			#youHaveThatHeDoesntHave,
			#heHasThatYouDontHave
		)
	else
		local signIds: { [number]: boolean } = rdb.getUserSignFinds(player.UserId)
		for signId, val in pairs(signIds) do
			actualSignIds[signId] = val
		end
	end

	for signId, val in pairs(actualSignIds) do
		if val then
			table.insert(actualSignIds, signId)
		end
	end

	ShowSignsEvent:FireClient(player, actualSignIds, extraText)
	return true
end

_annotate("end")
return module
