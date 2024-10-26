--!strict

--why this naming? because the chat modules also have a script named 'util' which messes things up.
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local textUtil = require(game.ReplicatedStorage.util.textUtil)
local tt = require(game.ReplicatedStorage.types.gametypes)

local module = {}
local enums = require(game.ReplicatedStorage.util.enums)
local emojis = require(game.ReplicatedStorage.enums.emojis)

local PlayersService = game:GetService("Players")

-- either because it's not a valid sign or it's in the exclusion lists
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
--return nil if no match. Prefers shorter matches (i.e. exact matches first)

local allSignNamesAndAliasesShortToLong = {}
for signId, signName in pairs(enums.signId2name) do
	table.insert(allSignNamesAndAliasesShortToLong, { signName = signName, signId = signId })
end

for signName, signAlias in pairs(enums.signName2Alias) do
	table.insert(allSignNamesAndAliasesShortToLong, { signName = signAlias, signId = module.signName2SignId(signName) })
end

table.sort(allSignNamesAndAliasesShortToLong, function(a, b)
	if #a.signName == #b.signName then
		return a.signName < b.signName
	end
	return #a.signName < #b.signName
end)

module.looseSignName2SignId = function(signSearchText: string): number?
	--return exact if matches.
	if enums.namelower2signId[signSearchText:lower()] ~= nil then
		return enums.namelower2signId[signSearchText:lower()]
	end

	local len = #signSearchText

	-- if it's an incomplete match, match the shorter one first (at least for predictability.)
	-- e.g. calling this on "spira" will hit "spiral" before "spiral jump"
	for _, el in ipairs(allSignNamesAndAliasesShortToLong) do
		local item1 = string.sub(el.signName, 1, len):lower()
		if item1 == signSearchText:lower() then
			return el.signId
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

function module.formatDateGap(gapSeconds: number): (string, string)
	if gapSeconds >= 365 * 24 * 60 * 60 then
		return string.format("%.1fy", gapSeconds / (365 * 24 * 60 * 60)), "years"
	elseif gapSeconds >= 3 * 24 * 60 * 60 then
		return string.format("%.1fd", gapSeconds / (24 * 60 * 60)), "days"
	elseif gapSeconds >= 60 * 60 then
		return string.format("%.1fh", gapSeconds / (60 * 60)), "hours"
	elseif gapSeconds >= 60 then
		return string.format("%.1fm", gapSeconds / 60), "minutes"
	else
		return string.format("%.1fs", gapSeconds), "seconds"
	end
end

module.signId2signName = function(signId: number?): string
	if not signId then
		annotater.Error("no signId.")
		return ""
	end
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
	annotater.Error("no")
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

module.AttemptToParseRaceFromInput = function(message: string): tt.RaceParseResult
	--lookup a race (NAMEPREFIX-NAMEPREFIX) sign names
	local signParts = textUtil.stringSplit(message:lower(), "-")
	if #signParts == 2 then
		local s1prefix = signParts[1]
		local s2prefix = signParts[2]

		local signId1 = module.looseSignName2SignId(s1prefix)
		local signId2 = module.looseSignName2SignId(s2prefix)
		local sign1name = module.signId2signName(signId1)
		local sign2name = module.signId2signName(signId2)

		local theError = ""

		if signId1 == signId2 then
			theError = "Trol"
		end
		if signId1 == nil or signId2 == nil then
			theError = "Enter race name like A-B (where A and B are signs, and you can just enter the prefix too.)"
		end

		if theError ~= "" then
			local ret: tt.RaceParseResult = {
				signId1 = 0,
				signId2 = 0,
				signName1 = "",
				signName2 = "",
				error = error,
			}

			return ret
		end

		return {
			signId1 = signId1,
			signId2 = signId2,
			signName1 = sign1name,
			signName2 = sign2name,
			error = "",
		}
	else
		return {
			signId1 = 0,
			signId2 = 0,
			signName1 = "",
			signName2 = "",
			error = "Enter race name like A-B (where A and B are signs, and you can just enter the prefix too.)",
		}
	end
end

-- calculates the max number of decimal places present within a list of numbers, and returns math.min(that value,3)
-- Example: For the input {1.234, 5.6789, 3.1}, the function will return 3 since although there is a number with 4, there's a hardcoded limit 3
module.GetMaxDecimalPlaces = function(numbers: { number }): number
	local maxDecimals = 0
	for _, num in ipairs(numbers) do
		local _, fractionalPart = math.modf(num)
		local decimals = 0
		if fractionalPart ~= 0 then
			decimals = math.min(#tostring(fractionalPart) - 2, 3) -- Subtract 2 for "0.", max 3 digits
		end
		maxDecimals = math.max(maxDecimals, decimals)
	end
	print("drawing decimals: ", maxDecimals, " probably should be at min 1?")
	return maxDecimals
end

-- returns the max number of digits in the integer part of a list of numbers
module.GetMaxIntegerDigits = function(numbers: { number }): number
	local maxDigits = 0
	for _, num in ipairs(numbers) do
		local integerPart = math.floor(num)
		local digits = #tostring(integerPart)
		maxDigits = math.max(maxDigits, digits)
	end
	return maxDigits
end

_annotate("end")
return module
