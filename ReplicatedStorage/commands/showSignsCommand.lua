--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local playerData2 = require(game.ServerScriptService.playerData2)

local remotes = require(game.ReplicatedStorage.util.remotes)
local ShowSignsEvent = remotes.getRemoteEvent("ShowSignsEvent")

local module = {}

module.ShowSignCommand = function(player: Player, targetUserId: number?): boolean
	_annotate(string.format("SeenSignCommand for player %s, targetUserId: %s", player.Name, tostring(targetUserId)))
	local usingTarget = targetUserId
	local signIdsToShow: { [number]: boolean } = {}
	local extraText = ""
	if usingTarget then
		local hisSignIds: { [number]: boolean } = playerData2.GetUserSignFinds(usingTarget, "target+showSignCommand")
		local playerSignIds: { [number]: boolean } =
			playerData2.GetUserSignFinds(player.UserId, "playerSignIds+showSignCommand")
		local signIdsHeHasThatYouDontHave: { number } = {}
		local signIdsYouHaveThatHeDoesntHave: { number } = {}
		for signId, val in pairs(hisSignIds) do
			if not playerSignIds[signId] then
				table.insert(signIdsHeHasThatYouDontHave, signId)
			end
		end
		for signId, val in pairs(playerSignIds) do
			if hisSignIds[signId] then
				-- we only show intersection
				signIdsToShow[signId] = true
			else
				table.insert(signIdsYouHaveThatHeDoesntHave, signId)
			end
		end
		extraText = string.format(
			"You have %d signs he doesn't have, and he has %d signs you don't have. Displaying the signs you both have now.",
			#signIdsYouHaveThatHeDoesntHave,
			#signIdsHeHasThatYouDontHave
		)
	else
		local signIds: { [number]: boolean } = playerData2.GetUserSignFinds(player.UserId, "showSignCommand")
		for signId, val in pairs(signIds) do
			if val then
				table.insert(signIdsToShow, signId)
			end
		end
	end

	ShowSignsEvent:FireClient(player, signIdsToShow, extraText)
	return true
end

_annotate("end")
return module
