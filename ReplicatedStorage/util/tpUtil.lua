--!strict

--eval 9.21

--why this naming? because the chat modules also have a script named 'util' which messes things up.

local module = {}
local enums = require(game.ReplicatedStorage.util.enums)

local PlayersService = game:GetService("Players")

module.fmtms = function(float: number): string
	return string.format("%.3f", float / 1000)
end

module.noe = function(n: number): number
	return math.ceil(n * 100000) / 100000
end

module.getDist = function(pos1: Vector3, pos2: Vector3): number
	local dst = Vector3.new(pos1.X - pos2.X, pos1.Y - pos2.Y, pos1.Z - pos2.Z)
	return dst.Magnitude
end

module.fmt = function(float: number): string
	return string.format("%.3f", float / 1000)
end

module.fmtShort = function(float: number): string
	return string.format("%.2f", float / 1000)
end

--this should use global since signs are actually streamed in and most won't be visible.
module.signId2Position = function(signId: number): Vector3?
	local name = enums.signId2name[signId]
	if name == nil then
		name = enums.signId2name[signId]
	end
	if name == nil then
		return nil
	end
	local sign: Part = game.Workspace:WaitForChild("Signs"):FindFirstChild(name)
	if not sign then
		return nil
	end
	return sign.Position
end

module.signName2SignId = function(signName: string)
	return enums.namelower2signId[signName:lower()]
end

--stemming from the front, first match
module.looseSignName2SignId = function(signSearchText: string): number?
	--return exact if matches.
	if enums.namelower2signId[signSearchText:lower()] ~= nil then
		return enums.namelower2signId[signSearchText:lower()]
	end

	local len = #signSearchText
	--this probably works for utf anyway.
	for signId, signName in ipairs(enums.signId2name) do
		if string.sub(signName, 1, len):lower() == signSearchText:lower() then
			return signId
		end
	end
	return nil
end

module.signId2signName = function(signId: number): string
	local res = enums.signId2name[signId]
	return res
end

module.looseGetPlayerFromUsername = function(playerName: string): Player?
	playerName = playerName:lower()
	--if there happen to be two players with subsetted names.
	for _, player: Player in ipairs(PlayersService:GetPlayers()) do
		if player.Name:lower() == playerName then
			return player
		end
	end
	for _, player: Player in ipairs(PlayersService:GetPlayers()) do
		if string.sub(player.Name, 1, #playerName):lower() == playerName then
			return player
		end
	end
	return nil
end

module.getPlayerByUserId = function(userId: number): Player
	return PlayersService:GetPlayerByUserId(userId)
end

module.getPlayerForUsername = function(username: string): Player?
	for _, player: Player in ipairs(PlayersService:GetPlayers()) do
		if player.Name == username then
			return player
		end
	end
	return nil
end

module.GetUserIdsInServer = function(): { number }
	local res = {}
	for _, player: Player in ipairs(PlayersService:GetPlayers()) do
		table.insert(res, player.UserId)
	end
	return res
end

module.getCardinal = function(place: number): string
	if place == nil then
		return ""
	end
	local smallPlace = place % 100
	if smallPlace == 11 then
		return place .. "th"
	end
	if smallPlace == 12 then
		return place .. "th"
	end
	if smallPlace == 13 then
		return place .. "th"
	end

	local singlePlace = smallPlace % 10
	local stem = "th"
	if singlePlace == 1 then
		stem = "st"
	end
	if singlePlace == 2 then
		stem = "nd"
	end
	if singlePlace == 3 then
		stem = "rd"
	end

	return tostring(place) .. stem
end

module.getPlaceText = function(place: number): string
	if place == 0 then
		return "*"
	end
	if place > 10 then
		return "-"
	end
	return module.getCardinal(place) .. " Place"
end

return module
