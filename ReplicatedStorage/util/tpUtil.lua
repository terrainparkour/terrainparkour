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

-- Forward declarations
local signName2Sign
local IsSignPartValidRightNow

-- either because it's not a valid sign or it's in the exclusion lists
local function SignNameCanBeHighlighted(signName: string): boolean
	if not signName or signName == "" then
		return false
	end
	local sign = signName2Sign(signName)
	if not sign then
		return false
	end
	if not IsSignPartValidRightNow(sign) then
		return false
	end
	local signNameFromSign = sign.Name
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
module.SignNameCanBeHighlighted = SignNameCanBeHighlighted

local function SignCanBeHighlighted(sign: Part?): boolean
	if not sign then
		return false
	end
	return SignNameCanBeHighlighted(sign.Name)
end
module.SignCanBeHighlighted = SignCanBeHighlighted

local function fmtms(float: number): string
	return string.format("%.3f", float / 1000)
end
module.fmtms = fmtms

local function noe(n: number): number
	return math.ceil(n * 100000) / 100000
end
module.noe = noe

local function getDist(pos1: Vector3, pos2: Vector3): number
	local dst = Vector3.new(pos1.X - pos2.X, pos1.Y - pos2.Y, pos1.Z - pos2.Z)
	return dst.Magnitude
end
module.getDist = getDist

local function fmt(float: number): string
	return string.format("%.3f", float / 1000)
end
module.fmt = fmt

local function fmtShort(float: number): string
	return string.format("%.2f", float / 1000)
end
module.fmtShort = fmtShort

--this should use global since signs are actually streamed in and most won't be visible.
local function signId2Position(signId: number): Vector3 | nil
	local name = enums.signId2name[signId]
	if name == nil then
		name = enums.signId2name[signId]
	end
	if name == nil then
		return nil
	end
	local sign: Instance? = game.Workspace:WaitForChild("Signs"):FindFirstChild(name)
	if not sign or not sign:IsA("Part") then
		return nil
	end
	return (sign :: Part).Position
end
module.signId2Position = signId2Position

local function signName2SignId(signName: string): number
	return enums.namelower2signId[signName:lower()]
end
module.signName2SignId = signName2SignId

--stemming from the front, first match
--return nil if no match. Prefers shorter matches (i.e. exact matches first)

local allSignNamesAndAliasesShortToLong = {}
for signId, signName in pairs(enums.signId2name) do
	table.insert(allSignNamesAndAliasesShortToLong, { signName = signName, signId = signId })
end

for signName, signAlias in pairs(enums.signName2Alias) do
	table.insert(allSignNamesAndAliasesShortToLong, { signName = signAlias, signId = signName2SignId(signName) })
end

table.sort(allSignNamesAndAliasesShortToLong, function(a, b)
	if #a.signName == #b.signName then
		return a.signName < b.signName
	end
	return #a.signName < #b.signName
end)

local function looseSignName2SignId(signSearchText: string): number?
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
module.looseSignName2SignId = looseSignName2SignId

--also takes into account aliases.
local function looseSignName2Sign(signSearchText: string): Part?
	local signId = looseSignName2SignId(signSearchText)
	if signId == nil then
		return nil
	end
	local sign: Instance? = game.Workspace:WaitForChild("Signs"):FindFirstChild(enums.signId2name[signId])
	if sign and sign:IsA("Part") then
		return sign :: Part
	end
	return nil
end
module.looseSignName2Sign = looseSignName2Sign

local function formatDateGap(gapSeconds: number): (string, string)
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
module.formatDateGap = formatDateGap

local function signId2signName(signId: number?): string
	if not signId then
		annotater.Error("signId is null?")
		return ""
	end
	local res = enums.signId2name[signId]
	return res
end
module.signId2signName = signId2signName

local function signId2Sign(signId: number): Part?
	if not signId then
		return nil
	end
	local signName = enums.signId2name[signId]
	if not signName then
		return nil
	end
	local sign: Instance? = game.Workspace:WaitForChild("Signs"):FindFirstChild(signName)
	if sign and sign:IsA("Part") then
		return sign :: Part
	end
	return nil
end
module.signId2Sign = signId2Sign

-- Defined here but assigned to module earlier or later?
-- Actually I can just define it local and assign it to module at the end if I want, but I'm mixing styles.
-- I'll stick to "define local, assign immediately to module" but use the local reference internally.

signName2Sign = function(signName: string): Part?
	local sign: Instance? = game.Workspace:WaitForChild("Signs"):FindFirstChild(signName)
	if sign and sign:IsA("Part") then
		return sign :: Part
	end
	return nil
end
module.signName2Sign = signName2Sign

local function looseGetPlayerFromUsername(playerName: string): Player?
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
module.looseGetPlayerFromUsername = looseGetPlayerFromUsername

local function getPlayerByUserId(userId: number): Player?
	return PlayersService:GetPlayerByUserId(userId)
end
module.getPlayerByUserId = getPlayerByUserId

local function getPlayerForUsername(username: string): Player?
	for _, player: Player in ipairs(PlayersService:GetPlayers()) do
		if player.Name == username then
			return player
		end
	end
	return nil
end
module.getPlayerForUsername = getPlayerForUsername

local function GetUserIdsInServer(): { number }
	local res = {}
	for _, player: Player in ipairs(PlayersService:GetPlayers()) do
		table.insert(res, player.UserId)
	end
	return res
end
module.GetUserIdsInServer = GetUserIdsInServer

local function getCardinal(place: number): string
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
module.getCardinal = getCardinal

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
	return ""
end

local function getNumberEmojis(number: number): string
	local res = ""
	while number > 0 do
		local digit = number % 10
		res = digit2emoji(digit) .. res
		number = math.floor(number / 10)
	end
	return res
end
module.getNumberEmojis = getNumberEmojis

--including medals for early places
local function getCardinalEmoji(place: number): string
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
	return getCardinal(place)
end
module.getCardinalEmoji = getCardinalEmoji

local function getPlaceText(place: number): string
	if place == 0 then
		return "*"
	end
	if place > 10 then
		return "-"
	end
	return getCardinal(place) .. " Place"
end
module.getPlaceText = getPlaceText

-- generally you want to check serverUtil.UserCanInteractWithSign or the future client version of this which also takes
-- into account whether the user has found it.
IsSignPartValidRightNow = function(sign: Part): boolean
	local res = sign.CanCollide and sign.CanTouch and sign.CanQuery
	return res
end
module.IsSignPartValidRightNow = IsSignPartValidRightNow

local function AttemptToParseRaceFromInput(message: string): tt.RaceParseResult
	--lookup a race (NAMEPREFIX-NAMEPREFIX) sign names
	local signParts = textUtil.stringSplit(message:lower(), "-")
	if #signParts == 2 then
		local s1prefix = signParts[1]
		local s2prefix = signParts[2]

		local signId1 = looseSignName2SignId(s1prefix)
		local signId2 = looseSignName2SignId(s2prefix)

		local theError = ""

		if signId1 == signId2 then
			theError = "Trol"
		end
		if not signId1 or not signId2 then
			theError = "Enter race name like A-B (where A and B are signs, and you can just enter the prefix too.)"
		end

		if theError ~= "" or not signId1 or not signId2 then
			local ret: tt.RaceParseResult = {
				signId1 = 0,
				signId2 = 0,
				signName1 = "",
				signName2 = "",
				error = theError,
			}

			return ret
		end

		-- Logic to get names AFTER validating IDs are present
		local sign1name = signId2signName(signId1)
		local sign2name = signId2signName(signId2)

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
module.AttemptToParseRaceFromInput = AttemptToParseRaceFromInput

-- calculates the max number of decimal places present within a list of numbers, and returns math.min(that value,3)
-- Example: For the input {1.234, 5.6789, 3.1}, the function will return 3 since although there is a number with 4, there's a hardcoded limit 3
local function GetMaxDecimalPlaces(numbers: { number }): number
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
module.GetMaxDecimalPlaces = GetMaxDecimalPlaces

-- returns the max number of digits in the integer part of a list of numbers
local function GetMaxIntegerDigits(numbers: { number }): number
	local maxDigits = 0
	for _, num in ipairs(numbers) do
		local integerPart = math.floor(num)
		local digits = #tostring(integerPart)
		maxDigits = math.max(maxDigits, digits)
	end
	return maxDigits
end
module.GetMaxIntegerDigits = GetMaxIntegerDigits

_annotate("end")
return module
