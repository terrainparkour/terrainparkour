--!strict

--why this naming? because the chat modules also have a script named 'util' which messes things up.
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)


local textUtil = require(game.ReplicatedStorage.util.textUtil)

local module = {}
local enums = require(game.ReplicatedStorage.util.enums)
local emojis = require(game.ReplicatedStorage.enums.emojis)

local PlayersService = game:GetService("Players")

module.SignNameCanBeHighlighted = function(signName: string): boolean
	if not signName or signName == "" then
		return false
	end
	local sign = module.signName2Sign(signName)
	if not sign then
		return false
	end
	if not module.IsSignPartValidRightNow(sign) then
		return false
	end
	local signName = sign.Name
	for _, name in pairs(enums.ExcludeSignNamesFromStartingAt) do
		if signName == name then
			return false
		end
	end
	for _, name in pairs(enums.ExcludeSignNamesFromEndingAt) do
		if signName == name then
			return false
		end
	end
	return true
end

module.SignCanBeHighlighted = function(sign: Part?): boolean
	if not sign then
		return false
	end
	return module.SignNameCanBeHighlighted(sign.Name)
end

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
module.signId2Position = function(signId: number): Vector3 | nil
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

module.signName2SignId = function(signName: string): number
	return enums.namelower2signId[signName:lower()]
end

--stemming from the front, first match
--return nil if no match
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

	for signName, signAlias in pairs(enums.signName2Alias) do
		if string.sub(signAlias, 1, len):lower() == signSearchText:lower() then
			--we found the sign name.
			local signId = enums.namelower2signId[signName:lower()]
			return signId
		end
	end
	return nil
end

--also takes into account aliases.
module.looseSignName2Sign = function(signSearchText: string): Part?
	local signId = module.looseSignName2SignId(signSearchText)
	if signId == nil then
		return nil
	end
	return game.Workspace:WaitForChild("Signs"):FindFirstChild(enums.signId2name[signId])
end

module.signId2signName = function(signId: number): string
	local res = enums.signId2name[signId]
	return res
end

module.signId2Sign = function(signId: number): Part?
	if not signId then
		return nil
	end
	local signName = enums.signId2name[signId]
	if not signName then
		return nil
	end
	return game.Workspace:WaitForChild("Signs"):FindFirstChild(signName)
end

module.signName2Sign = function(signName: string): Part?
	return game.Workspace:WaitForChild("Signs"):FindFirstChild(signName)
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

local function digit2emoji(digit: number): string
	if digit == 0 then
		return emojis.emojis.DIGIT_ZERO
	end
	if digit == 1 then
		return emojis.emojis.DIGIT_ONE
	end
	if digit == 2 then
		return emojis.emojis.DIGIT_TWO
	end
	if digit == 3 then
		return emojis.emojis.DIGIT_THREE
	end
	if digit == 4 then
		return emojis.emojis.DIGIT_FOUR
	end
	if digit == 5 then
		return emojis.emojis.DIGIT_FIVE
	end
	if digit == 6 then
		return emojis.emojis.DIGIT_SIX
	end
	if digit == 7 then
		return emojis.emojis.DIGIT_SEVEN
	end
	if digit == 8 then
		return emojis.emojis.DIGIT_EIGHT
	end
	if digit == 9 then
		return emojis.emojis.DIGIT_NINE
	end
	error("no")
end

module.getNumberEmojis = function(number: number): string
	local res = ""
	while number > 0 do
		local digit = number % 10
		res = digit2emoji(digit) .. res
		number = math.floor(number / 10)
	end
	return res
end

--including medals for early places
module.getCardinalEmoji = function(place: number): string
	if place == nil then
		return ""
	end

	if place == 1 then
		return emojis.emojis.FIRST_PLACE
	end
	if place == 2 then
		return emojis.emojis.SECOND_PLACE
	end
	if place == 3 then
		return emojis.emojis.THIRD_PLACE
	end
	return module.getCardinal(place)
	-- local emojiNumber = module.getNumberEmojis(place)
	-- local stem = "th"

	-- local lastDigit = place % 10
	-- if lastDigit == 1 then
	-- 	stem = "st"
	-- end
	-- if lastDigit == 2 then
	-- 	stem = "nd"
	-- end
	-- if lastDigit == 3 then
	-- 	stem = "rd"
	-- end
	-- local smallPlace = place % 100
	-- if smallPlace == 11 then
	-- 	stem = "th"
	-- end
	-- if smallPlace == 12 then
	-- 	stem = "th"
	-- end
	-- if smallPlace == 13 then
	-- 	stem = "th"
	-- end
	-- return emojiNumber .. stem
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

-- generally you want to check serverUtil.UserCanInteractWithSign or the future client version of this which also takes
-- into account whether the user has found it.
module.IsSignPartValidRightNow = function(sign: Part): boolean
	local res = sign.CanCollide and sign.CanTouch and sign.CanQuery
	return res
end

module.AttemptToParseRaceFromInput = function(message: string): (number?, number?)	
	--lookup a race (NAMEPREFIX-NAMEPREFIX) sign names
	local signParts = textUtil.stringSplit(message:lower(), "-")
	if #signParts == 2 then
		local s1 = signParts[1]
		local s2 = signParts[2]

		local signId1 = module.looseSignName2SignId(s1)
		local signId2 = module.looseSignName2SignId(s2)

		if not signId1 or not signId1 then 
			return nil, nil 
		end
		return signId1, signId2
	end
end

_annotate("end")
return module
