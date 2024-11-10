--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local playerData2 = require(game.ServerScriptService.playerData2)

local remotes = require(game.ReplicatedStorage.util.remotes)
local ShowSignsEvent = remotes.getRemoteEvent("ShowSignsEvent")

local ShowSigns = {}

-- Function to show signs based on command utilization
function ShowSigns.ShowSignCommand(player: Player, targetUserId: number?): boolean
	_annotate(string.format("ShowSignCommand for player %s, targetUserId: %s", player.Name, tostring(targetUserId)))

	local signIdsToShow: { [number]: boolean } = {}
	local extraText = ""

	if targetUserId then
		-- Get signs for the target user
		local hisSignIds: { [number]: boolean } = playerData2.GetUserSignFinds(targetUserId, "target+showSignCommand")
		-- Get signs for the current player
		local playerSignIds: { [number]: boolean } = playerData2.GetUserSignFinds(player.UserId, "playerSignIds+showSignCommand")

		local signIdsHeHasThatYouDontHave: { number } = {}
		local signIdsYouHaveThatHeDoesntHave: { number } = {}

		-- Determine signs exchange
		for signId, val in pairs(hisSignIds) do
			if val and not playerSignIds[signId] then
				table.insert(signIdsHeHasThatYouDontHave, signId)
			end
		end

		for signId, val in pairs(playerSignIds) do
			if val and not hisSignIds[signId] then
				-- Show intersection signs
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
		-- Get signs for the current player only
		local signIds: { [number]: boolean } = playerData2.GetUserSignFinds(player.UserId, "showSignCommand")
		for signId, val in pairs(signIds) do
			if val then
				signIdsToShow[signId] = true
			end
		end
	end

	-- Fire event to client to show signs
	ShowSignsEvent:FireClient(player, signIdsToShow, extraText)
	return true
end

-- Function to execute the command (to be called from CommandService)
function ShowSigns.Execute(player, targetUserId: number?)
	local success = ShowSigns.ShowSignCommand(player, targetUserId)

	if success then
		return "Sign display has been successfully executed!"
	else
		return "Failed to display signs."
	end
end

_annotate("end")
return ShowSigns