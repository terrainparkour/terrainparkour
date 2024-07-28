--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local tt = require(game.ReplicatedStorage.types.gametypes)
local mt = require(game.StarterPlayer.StarterCharacterScripts.marathon.marathonTypes)
local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)
local marathonstatic = require(game.StarterPlayer.StarterCharacterScripts.marathon["marathon.static"])
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local enums = require(game.ReplicatedStorage.util.enums)
local config = require(game.ReplicatedStorage.config)
local TweenService = game:GetService("TweenService")
local colors = require(game.ReplicatedStorage.util.colors)
local textUtil = require(game.ReplicatedStorage.util.textUtil)
local module = {}

--return if you have found a sign of this length yet.
local SignsOfLengthEvaluateFind = function(desc: mt.marathonDescriptor, signName: string): mt.userFoundSignResult
	local len = utf8.len(signName)
	if len > 19 then --too long or short
		return { added = false, marathonDone = false, started = false }
	end
	local hasSeenThisLength: boolean = false
	for _, find in ipairs(desc.finds) do
		if string.len(find.signName) == len then
			hasSeenThisLength = true
			break
		end
	end
	if not hasSeenThisLength then
		local didAdd = desc.AddSignToFinds(desc, signName)
		if not didAdd then
			return { added = false, marathonDone = false, started = false }
		end
		local marathonDone = desc.IsDone(desc)
		return { added = true, marathonDone = marathonDone, started = desc.count == 1 }
	end
	return { added = false, marathonDone = false, started = false }
end

local AlphaFreeEvaluateFind = function(desc: mt.marathonDescriptor, signName: string): mt.userFoundSignResult
	local firstLetterOfSign = textUtil.getFirstCodepointAsString(signName):lower()
	if not string.find(firstLetterOfSign, "[a-z]") then
		return { added = false, marathonDone = false, started = false }
	end
	local hasSeenThisFirstLetter: boolean = false
	for _, find in ipairs(desc.finds) do
		local findFirstLetter = textUtil.getFirstCodepointAsString(find.signName):lower()
		if findFirstLetter == firstLetterOfSign then
			hasSeenThisFirstLetter = true
			break
		end
	end
	if not hasSeenThisFirstLetter then
		local didAdd = desc.AddSignToFinds(desc, signName)
		if not didAdd then
			return { added = false, marathonDone = false, started = false }
		end
		local marathonDone = desc.IsDone(desc)
		return { added = true, marathonDone = marathonDone, started = desc.count == 1 }
	end
	return { added = false, marathonDone = false, started = false }
end

--evaluate a find and accept it if necessary, purely considering if its new to the list of finds.
local function EvaluteFindBasedOnIfItsNewOrNot(desc, signName): mt.userFoundSignResult
	for _, find in ipairs(desc) do
		if find.signName == signName then
			return { added = false, marathonDone = false, started = false }
		end
	end
	local didAdd = desc.AddSignToFinds(desc, signName)
	if not didAdd then
		return { added = false, marathonDone = false, started = false }
	end
	local marathonDone = desc.IsDone(desc)
	return { added = true, marathonDone = marathonDone, started = desc.count == 1 }
end

--just adds sign if not a duplicate.
local function DefaultAddSignToFinds(desc: mt.marathonDescriptor, signName: string): boolean
	-- _annotate("DefaultAddSignToFinds.start. " .. desc.kind .. signName)
	local key = desc.kind .. "__" .. signName
	if desc.addDebounce[key] then
		-- _annotate("DefaultAddSignToFinds.debounce. " .. desc.kind .. signName)
		return false
	end
	desc.addDebounce[key] = true

	for _, el in ipairs(desc.finds) do
		if el.signName == signName then
			-- _annotate("DefaultAddSignToFinds.doible try. " .. desc.kind .. signName)
			return false
		end
	end
	desc.count += 1
	local targetFind = {
		signName = signName,
		findTicks = tick(),
		findOrder = desc.count,
	}
	table.insert(desc.finds, targetFind)
	-- _annotate("DefaultAddSignToFinds.added-. " .. desc.kind .. signName .. " NOw have; " .. #desc.finds)
	desc.addDebounce[key] = false
	return true
end

module.DefaultAddSignToFinds = DefaultAddSignToFinds

--evaluate a find given a desc's state and a required order
local evaluateFindInFixedOrder = function(desc: mt.marathonDescriptor, signName: string): mt.userFoundSignResult
	--iterate through all keys til you get to the first null
	--then check if the find matches.
	local targetOrder = desc.orderedTargets
	for index, key in ipairs(targetOrder) do
		local targetFind = desc.finds[index]
		if targetFind ~= nil then
			continue
		end

		if signName == key then
			desc.AddSignToFinds(desc, signName)
			local marathonDone = desc.IsDone(desc)
			return { added = true, marathonDone = marathonDone, started = desc.count == 1 }
		end

		--you touched an irrelevant sign.
		return { added = false, marathonDone = false, started = false }
	end
	warn("should not get here.")
end

local evaluateFindInFixedOrderByFirstLetter = function(
	desc: mt.marathonDescriptor,
	signName: string
): mt.userFoundSignResult
	local targetOrder = desc.orderedTargets
	local firstLetterOfSign = textUtil.getFirstCodepointAsString(signName):lower()
	--iterate through all keys til you get to the first null
	--then check if the find matches.
	for index, key in ipairs(targetOrder) do
		local targetFind = desc.finds[index]
		if targetFind ~= nil then
			continue
		end

		if firstLetterOfSign == key then
			desc.AddSignToFinds(desc, signName)
			local marathonDone = desc.IsDone(desc)
			return { added = true, marathonDone = marathonDone, started = desc.count == 1 }
		end

		--you touched an irrelevant sign.
		return { added = false, marathonDone = false, started = false }
	end
	warn("should not get here.")
end

--the most naive method of pairing up signids after a marathon is done.
local sequentialSummarizeResults = function(desc: mt.marathonDescriptor): { string }
	local od = {}
	for _, find in ipairs(desc.finds) do
		local signId = tpUtil.looseSignName2SignId(find.signName)
		table.insert(od, signId)
	end
	return od
end

local FindNUpdateRow = function(desc: mt.marathonDescriptor, frame: Frame, foundSignName: string): nil
	--get the tl
	local targetName = marathonstatic.getMarathonComponentName(desc, desc.humanName)
	local exiTile: TextLabel = frame:FindFirstChild(targetName, true)
	if exiTile == nil then
		warn("bad.FindNUpdateRow" .. " could not find: " .. targetName)
		return
	end
	local inner: TextLabel = exiTile:FindFirstChild("Inner")
	inner.Text = desc.count .. " / " .. desc.requiredCount
	inner.TextScaled = true
	local bgcolor = colors.yellowFind
	inner.BackgroundColor3 = colors.greenGo
	local Tween = TweenService:Create(inner, TweenInfo.new(enums.greenTime), { BackgroundColor3 = bgcolor })
	Tween:Play()
end

local SignsOfEveryLengthUpdateRow = function(desc: mt.marathonDescriptor, frame: Frame, foundSignName: string): nil
	local ll = utf8.len(foundSignName)
	local targetName = marathonstatic.getMarathonComponentName(desc, string.format("%02d", ll))
	local exiTile: TextLabel = frame:FindFirstChild(targetName, true)
	if exiTile == nil then
		warn("bad.AlphaUpdateRow" .. foundSignName)
		return
	end
	local inner: TextLabel = exiTile:FindFirstChild("Inner")

	local bgcolor = colors.yellowFind
	exiTile.BackgroundColor3 = colors.greenGo
	inner.BackgroundColor3 = colors.greenGo
	local Tween = TweenService:Create(exiTile, TweenInfo.new(enums.greenTime), { BackgroundColor3 = bgcolor })
	Tween:Play()
	local Tween2 = TweenService:Create(inner, TweenInfo.new(enums.greenTime), { BackgroundColor3 = bgcolor })
	Tween2:Play()
end

local AlphaUpdateRow = function(desc: mt.marathonDescriptor, frame: Frame, foundSignName: string): nil
	-- local firstLetterOfSign = string.lower(string.sub(foundSignName, 1, 1))
	local firstLetterOfSign = textUtil.getFirstCodepointAsString(foundSignName):lower()
	local targetName = marathonstatic.getMarathonComponentName(desc, firstLetterOfSign)
	local exiTile: TextLabel = frame:FindFirstChild(targetName, true)
	if exiTile == nil then
		--this is okay since non-alphanumeric chars won't count.
		return
	end
	local inner: TextLabel = exiTile:FindFirstChild("Inner")
	local bgcolor = colors.yellowFind
	inner.BackgroundColor3 = colors.greenGo
	exiTile.BackgroundColor3 = colors.greenGo
	local Tween = TweenService:Create(exiTile, TweenInfo.new(enums.greenTime), { BackgroundColor3 = bgcolor })
	Tween:Play()
	local Tween2 = TweenService:Create(inner, TweenInfo.new(enums.greenTime), { BackgroundColor3 = bgcolor })
	Tween2:Play()
end

local FindSetUpdateRow = function(desc: mt.marathonDescriptor, frame: Frame, foundSignName: string): nil
	local targetName = marathonstatic.getMarathonComponentName(desc, foundSignName)
	local exiTile: TextLabel = frame:FindFirstChild(targetName, true)
	if exiTile == nil then
		warn("bad.FindSetUpdateRow")
	end
	local inner: TextLabel = exiTile:FindFirstChild("Inner")
	local bgcolor = colors.yellowFind
	exiTile.BackgroundColor3 = colors.greenGo
	inner.BackgroundColor3 = colors.greenGo
	local Tween = TweenService:Create(exiTile, TweenInfo.new(enums.greenTime), { BackgroundColor3 = bgcolor })
	Tween:Play()
	local Tween2 = TweenService:Create(inner, TweenInfo.new(enums.greenTime), { BackgroundColor3 = bgcolor })
	Tween2:Play()
end

local findSetEvaluateFind = function(desc: mt.marathonDescriptor, signName: string): mt.userFoundSignResult
	local signIsInTargetSet: boolean = false
	for _, target in ipairs(desc.targets) do
		if target == signName then
			signIsInTargetSet = true
			break
		end
	end
	if not signIsInTargetSet then
		return { added = false, marathonDone = false, started = false }
	end
	local hasSeenAlready: boolean = false
	for _, find in ipairs(desc.finds) do
		if find.signName == signName then
			hasSeenAlready = true
			break
		end
	end
	if hasSeenAlready then
		return { added = false, marathonDone = false, started = false }
	end

	local didAdd = desc.AddSignToFinds(desc, signName)
	if not didAdd then
		return { added = false, marathonDone = false, started = false }
	end
	local marathonDone = desc.IsDone(desc)
	return { added = true, marathonDone = marathonDone, started = desc.count == 1 }
end

local mkFindSetMarathon = function(
	slug: string,
	humanName: string,
	signNames: { string },
	badge: tt.badgeDescriptor,
	overrideRequiredCount: number?
): mt.marathonDescriptor
	local joined = textUtil.stringJoin(", ", signNames)
	local requiredCount = overrideRequiredCount
	if overrideRequiredCount == nil then
		requiredCount = #signNames
	end
	local inner: mt.marathonDescriptor = {
		kind = "findset" .. slug,
		highLevelType = "findSet",
		humanName = humanName,
		hint = "Find in any order: " .. joined,
		addDebounce = {},
		reportAsMarathon = true,
		finds = {},
		targets = signNames,
		orderedTargets = nil,
		count = 0,
		requiredCount = requiredCount,
		startTime = 0,
		killTimerSemaphore = false,
		runningTimeTileUpdater = false,
		timeTile = nil,
		IsDone = function(desc: mt.marathonDescriptor)
			return desc.count == desc.requiredCount
		end,
		AddSignToFinds = DefaultAddSignToFinds,
		UpdateRow = FindSetUpdateRow,
		EvaluateFind = findSetEvaluateFind,
		SummarizeResults = sequentialSummarizeResults,
		awardBadge = badge,
		chipPadding = 1,
		sequenceNumber = humanName,
	}
	return inner
end

local signsOfEveryLength: mt.marathonDescriptor = {
	kind = "signsofeverylength",
	highLevelType = "signsOfEveryLength",
	humanName = "Signs of every length",
	hint = "Find signs with length 1,2,3,4, all the way up to 19, in any order.",
	addDebounce = {},
	reportAsMarathon = true,
	finds = {},
	targets = {
		"01",
		"02",
		"03",
		"04",
		"05",
		"06",
		"07",
		"08",
		"09",
		"10",
		"11",
		"12",
		"13",
		"14",
		"15",
		"16",
		"17",
		"18",
		"19",
	},
	orderedTargets = nil,
	count = 0,
	requiredCount = 19,
	startTime = 0,
	killTimerSemaphore = false,
	runningTimeTileUpdater = false,
	timeTile = nil,
	IsDone = function(desc: mt.marathonDescriptor)
		return config.isInStudio() and desc.count == 6 or desc.count == desc.requiredCount
	end,
	AddSignToFinds = DefaultAddSignToFinds,
	UpdateRow = SignsOfEveryLengthUpdateRow,
	EvaluateFind = SignsOfLengthEvaluateFind,
	SummarizeResults = sequentialSummarizeResults,
	awardBadge = badgeEnums.badges.MarathonCompletionFindEveryLength,
	chipPadding = 1,
	sequenceNumber = "Signs of every length",
}

local alphaFree: mt.marathonDescriptor = {
	kind = "alphafree",
	highLevelType = "alphabetical",
	hint = "Find signs with every first letter in the alphabet, in any order.",
	humanName = "Alpha Free",
	addDebounce = {},
	reportAsMarathon = true,
	finds = {},
	targets = marathonstatic.alphaKeys,
	orderedTargets = nil,
	count = 0,
	requiredCount = 26,
	startTime = 0,
	killTimerSemaphore = false,
	runningTimeTileUpdater = false,
	timeTile = nil,
	IsDone = function(desc: mt.marathonDescriptor)
		return config.isInStudio() and desc.count == 3 or desc.count == desc.requiredCount
	end,
	AddSignToFinds = DefaultAddSignToFinds,
	UpdateRow = AlphaUpdateRow,
	EvaluateFind = AlphaFreeEvaluateFind,
	SummarizeResults = sequentialSummarizeResults,
	awardBadge = badgeEnums.badges.MarathonCompletionAlphaFree,
	chipPadding = 1,
	sequenceNumber = "Alpha Free",
}

local alphaOrdered: mt.marathonDescriptor = {
	kind = "alphaordered",
	highLevelType = "alphabetical",
	humanName = "Alpha Ordered",
	hint = "Find signs starting with the letters of the alphabet, from A to Z.",
	addDebounce = {},
	reportAsMarathon = true,
	finds = {},
	targets = {},
	orderedTargets = marathonstatic.alphaKeys,
	count = 0,
	requiredCount = 26,
	startTime = 0,
	killTimerSemaphore = false,
	runningTimeTileUpdater = false,
	timeTile = nil,
	IsDone = function(desc: mt.marathonDescriptor)
		return config.isInStudio() and desc.count == 3 or desc.count == desc.requiredCount
	end,
	AddSignToFinds = DefaultAddSignToFinds,
	UpdateRow = AlphaUpdateRow,
	EvaluateFind = function(desc: mt.marathonDescriptor, signName: string)
		return evaluateFindInFixedOrderByFirstLetter(desc, signName)
	end,
	SummarizeResults = sequentialSummarizeResults,
	awardBadge = badgeEnums.badges.MarathonCompletionAlphaOrdered,
	chipPadding = 1,
	sequenceNumber = "Signs of every length",
}

module.sequentialSummarizeResults = sequentialSummarizeResults
module.evaluateFindInFixedOrderByFirstLetter = evaluateFindInFixedOrderByFirstLetter
module.evaluateFindInFixedOrder = evaluateFindInFixedOrder

local alphaReverse: mt.marathonDescriptor = {
	kind = "alphareverse",
	highLevelType = "alphabetical",
	humanName = "Alpha Reverse",
	hint = "Touch signs starting with Z, Y, X, ..., A in that order.",
	addDebounce = {},
	reportAsMarathon = true,
	finds = {},
	targets = {},
	orderedTargets = marathonstatic.alphaKeysReverse,
	count = 0,
	requiredCount = 26,
	startTime = 0,
	killTimerSemaphore = false,
	runningTimeTileUpdater = false,
	timeTile = nil,
	IsDone = function(desc: mt.marathonDescriptor)
		return config.isInStudio() and desc.count == 3 or desc.count == desc.requiredCount
	end,
	AddSignToFinds = DefaultAddSignToFinds,
	UpdateRow = AlphaUpdateRow,
	EvaluateFind = function(desc: mt.marathonDescriptor, signName: string)
		return evaluateFindInFixedOrderByFirstLetter(desc, signName)
	end,
	SummarizeResults = sequentialSummarizeResults,
	awardBadge = badgeEnums.badges.MarathonCompletionAlphaReverse,
	chipPadding = 1,
	sequenceNumber = "Alpha Reverse",
}

local function mkFindN(n: number, badge: tt.badgeDescriptor?): mt.marathonDescriptor
	local inner: mt.marathonDescriptor = {
		kind = string.format("find%d", n),
		highLevelType = "findn",
		humanName = string.format("Find %d", n),
		hint = string.format("Touch %d signs in any order.", n),
		addDebounce = {},
		reportAsMarathon = true,
		finds = {},
		targets = {},
		orderedTargets = {},
		count = 0,
		requiredCount = n,
		startTime = 0,
		killTimerSemaphore = false,
		runningTimeTileUpdater = false,
		timeTile = nil,
		IsDone = function(desc: mt.marathonDescriptor)
			return config.isInStudio() and desc.count == 4 or desc.count == desc.requiredCount
		end,
		AddSignToFinds = DefaultAddSignToFinds,
		UpdateRow = FindNUpdateRow,
		EvaluateFind = function(desc: mt.marathonDescriptor, signName: string)
			return EvaluteFindBasedOnIfItsNewOrNot(desc, signName)
		end,
		SummarizeResults = sequentialSummarizeResults,
		awardBadge = badge,
		chipPadding = 0,
		sequenceNumber = string.format("%04d", n),
	}
	return inner
end

--check input func<signName>, if so, then check for newness.
local function NewnessPlusOtherChecker(
	desc: mt.marathonDescriptor,
	signName: string,
	otherChecker: (desc: mt.marathonDescriptor, signName: string) -> boolean
): mt.userFoundSignResult
	if not otherChecker(desc, signName) then
		return { added = false, marathonDone = false, started = false }
	end
	return EvaluteFindBasedOnIfItsNewOrNot(desc, signName)
end

local function firstLetterCheckerMaker(targetLetter: string): (desc: mt.marathonDescriptor, signName: string) -> boolean
	local function inner(desc: mt.marathonDescriptor, signName)
		local firstLetterOfSign = textUtil.getFirstCodepointAsString(signName):lower()
		return firstLetterOfSign == targetLetter
	end
	return inner
end

local find10s: mt.marathonDescriptor = {
	kind = "find10s",
	highLevelType = "findn",
	humanName = "Find 10 S*",
	hint = "Touch 10 signs starting with 'S' in any order.",
	addDebounce = {},
	finds = {},
	targets = {},
	orderedTargets = {},
	reportAsMarathon = true,
	count = 0,
	requiredCount = 10,
	startTime = 0,
	killTimerSemaphore = false,
	runningTimeTileUpdater = false,
	timeTile = nil,
	IsDone = function(desc: mt.marathonDescriptor)
		return config.isInStudio() and desc.count == 5 or desc.count == desc.requiredCount
	end,
	AddSignToFinds = DefaultAddSignToFinds,
	UpdateRow = FindNUpdateRow,
	EvaluateFind = function(desc: mt.marathonDescriptor, signName: string)
		return NewnessPlusOtherChecker(desc, signName, firstLetterCheckerMaker("s"))
	end,
	SummarizeResults = sequentialSummarizeResults,
	awardBadge = badgeEnums.badges.MarathonCompletionFind10S,
	chipPadding = 0,
	sequenceNumber = "10s",
}

local find10t: mt.marathonDescriptor = {
	kind = "find10t",
	highLevelType = "findn",
	humanName = "Find 10 T*",
	hint = "Touch 10 signs starting with 'T' in any order.",
	addDebounce = {},
	finds = {},
	targets = {},
	orderedTargets = {},
	reportAsMarathon = true,
	count = 0,
	requiredCount = 10,
	startTime = 0,
	killTimerSemaphore = false,
	runningTimeTileUpdater = false,
	timeTile = nil,
	IsDone = function(desc: mt.marathonDescriptor)
		return config.isInStudio() and desc.count == 5 or desc.count == desc.requiredCount
	end,
	AddSignToFinds = DefaultAddSignToFinds,
	UpdateRow = FindNUpdateRow,
	EvaluateFind = function(desc: mt.marathonDescriptor, signName: string)
		return NewnessPlusOtherChecker(desc, signName, firstLetterCheckerMaker("t"))
	end,
	SummarizeResults = sequentialSummarizeResults,
	awardBadge = badgeEnums.badges.MarathonCompletionFind10T,
	chipPadding = 0,
	sequenceNumber = "10t",
}

local function countFullLengthOfFoundSigns(desc: mt.marathonDescriptor)
	local ret = 0
	for ii, find: mt.findInMarathonRun in ipairs(desc.finds) do
		ret += utf8.len(find.signName)
	end
	return ret
end
local FindLetterCountUpdateRow = function(
	desc: mt.marathonDescriptor,
	frame: Frame,
	foundSignName: string,
	limit: number
): nil
	--get the tl
	local targetName = marathonstatic.getMarathonComponentName(desc, desc.humanName)
	local exiTile: TextLabel = frame:FindFirstChild(targetName, true)
	if exiTile == nil then
		warn("bad.FindNUpdateRow")
		return
	end
	local inner: TextLabel = exiTile:FindFirstChild("Inner")
	local ct = countFullLengthOfFoundSigns(desc)
	inner.Text = ct .. " / " .. limit
	inner.TextScaled = true
	local bgcolor = colors.yellowFind
	exiTile.BackgroundColor3 = colors.greenGo
	inner.BackgroundColor3 = colors.greenGo
	local Tween = TweenService:Create(exiTile, TweenInfo.new(enums.greenTime), { BackgroundColor3 = bgcolor })
	Tween:Play()
	local Tween2 = TweenService:Create(inner, TweenInfo.new(enums.greenTime), { BackgroundColor3 = bgcolor })
	Tween2:Play()
end

--evaluate a find and accept it if necessary, purely considering if its new to the list of finds.
local function EvaluteFindBasedOnIfItsLetterCountIsUnderLimit(
	desc: mt.marathonDescriptor,
	signName: string,
	limit: number
): mt.userFoundSignResult
	for _, find in ipairs(desc) do
		if find.signName == signName then
			return { added = false, marathonDone = false, started = false }
		end
	end
	local tot = countFullLengthOfFoundSigns(desc)
	local signLength = utf8.len(signName)
	if signLength + tot > limit then
		return { added = false, marathonDone = false, started = false }
	end
	if signLength + tot <= limit then
		local didAdd = desc.AddSignToFinds(desc, signName)

		if not didAdd then
			return { added = false, marathonDone = false, started = false }
		end
		local marathonDone = desc.IsDone(desc)
		return { added = true, marathonDone = marathonDone, started = desc.count == 1 }
	end
	warn("don't get here.")
end

local function mkLetterMarathon(limit: number, badge: tt.badgeDescriptor)
	local item: mt.marathonDescriptor = {
		kind = "exactly" .. tostring(limit) .. "letters",
		highLevelType = "findnletters",
		humanName = "Exactly " .. tostring(limit) .. " letters",
		hint = string.format("Touch signs totaling %d letters in total, including spaces.", limit),
		addDebounce = {},
		finds = {},
		targets = {},
		orderedTargets = {},
		reportAsMarathon = true,
		count = 0,
		requiredCount = 0,
		startTime = 0,
		killTimerSemaphore = false,
		runningTimeTileUpdater = false,
		timeTile = nil,
		IsDone = function(desc: mt.marathonDescriptor)
			return countFullLengthOfFoundSigns(desc) == limit
		end,
		AddSignToFinds = DefaultAddSignToFinds,
		UpdateRow = function(desc: mt.marathonDescriptor, exi: Frame, signName: string)
			return FindLetterCountUpdateRow(desc, exi, signName, limit)
		end,
		EvaluateFind = function(desc: mt.marathonDescriptor, signName: string)
			return EvaluteFindBasedOnIfItsLetterCountIsUnderLimit(desc, signName, limit)
		end,
		SummarizeResults = sequentialSummarizeResults,
		awardBadge = badge,
		chipPadding = 1,
		sequenceNumber = string.format("%04d", limit),
	}
	return item
end

local function isNonAlphabeticalSignCharacters(c: string)
	if string.match(c, "%l") == c then
		return false
	end
	return true
end

--produce map {letter:boolean for all letters in all sign found names}
local function getLetterCoverage(desc: mt.marathonDescriptor, excludeSignName: string): { [string]: boolean }
	local seen: { [string]: boolean } = {}
	local ct = 0
	for ii, find in ipairs(desc.finds) do
		if find.signName:lower() == excludeSignName:lower() then
			continue
		end
		for _, c in ipairs(find.signName:lower():split("")) do
			if isNonAlphabeticalSignCharacters(c) then
				continue
			end
			c = c:lower()
			if seen[c] == nil then
				seen[c] = true
				ct += 1
				if ct == 26 then
					return seen
				end
			end
		end
	end
	return seen
end

--find if you have complete alphabetical coverage
local function signsHaveEveryLetter(desc: mt.marathonDescriptor): boolean
	local coverage = getLetterCoverage(desc, "")
	local ct = 0
	for let, _ in pairs(coverage) do
		ct += 1
	end
	if ct == 26 then
		return true
	end
	return false
end

local function evaluateIfSignHasAnyNewLetters(desc: mt.marathonDescriptor, signName: string): boolean
	local coverage = getLetterCoverage(desc, "") --dont exclude anything since its not added yet.
	for _, c in ipairs(signName:split("")) do
		c = c:lower()
		if isNonAlphabeticalSignCharacters(c) then
			continue
		end
		if coverage[c] == nil then
			return true
		end
	end
	return false
end

--for an sign you just hit, figure out what new alpha chips you should highlight.
local FindAlphabeticalAndAddAllChipsRow = function(
	desc: mt.marathonDescriptor,
	frame: Frame,
	foundSignName: string
): nil
	local coverage = getLetterCoverage(desc, foundSignName)
	for _, c in ipairs(foundSignName:split("")) do
		c = c:lower()
		if isNonAlphabeticalSignCharacters(c) then
			continue
		end
		if coverage[c] ~= nil then
			continue
		end
		local targetName = marathonstatic.getMarathonComponentName(desc, c)
		local exiTile: TextLabel = frame:FindFirstChild(targetName, true)
		if exiTile == nil then
			warn("bad.foundSignName")
		end
		local inner: TextLabel = exiTile:FindFirstChild("Inner")

		local bgcolor = colors.yellowFind
		exiTile.BackgroundColor3 = colors.greenGo
		inner.BackgroundColor3 = colors.greenGo
		local Tween = TweenService:Create(exiTile, TweenInfo.new(enums.greenTime), { BackgroundColor3 = bgcolor })
		Tween:Play()
		local Tween2 = TweenService:Create(inner, TweenInfo.new(enums.greenTime), { BackgroundColor3 = bgcolor })
		Tween2:Play()
	end
end

local alphabeticalAllLetters: mt.marathonDescriptor = {
	kind = "alphabeticalallletters",
	highLevelType = "alphabetical",
	humanName = "Find all letters",
	hint = "Touch signs containing all letters of the alphabet, in any order.",
	addDebounce = {},
	finds = {},
	targets = marathonstatic.alphaKeys,
	orderedTargets = {},
	reportAsMarathon = true,
	count = 0,
	requiredCount = 0,
	startTime = 0,
	killTimerSemaphore = false,
	runningTimeTileUpdater = false,
	timeTile = nil,
	IsDone = signsHaveEveryLetter,
	AddSignToFinds = DefaultAddSignToFinds,
	UpdateRow = FindAlphabeticalAndAddAllChipsRow,
	EvaluateFind = function(desc: mt.marathonDescriptor, signName: string)
		return NewnessPlusOtherChecker(desc, signName, evaluateIfSignHasAnyNewLetters)
	end,
	SummarizeResults = sequentialSummarizeResults,
	awardBadge = badgeEnums.badges.MarathonCompletionAlphaLetters,
	chipPadding = 1,
	sequenceNumber = "Find all letters",
}

local function getSignsWithTrait(trait): { string }
	local res = {}
	local enums = require(game.ReplicatedStorage.util.enums)
	local signFolder = game.Workspace:FindFirstChild("Signs")
	for signName, signId in pairs(enums.name2signId) do
		if not trait(signName) then
			continue
		end
		local candidateSign = tpUtil.looseSignName2Sign(signName)
		if candidateSign == nil then
			continue
		end
		if not tpUtil.isSignPartValidRightNow(candidateSign) then
			continue
		end

		if candidateSign ~= nil then
			table.insert(res, signName)
		end
	end
	return res
end

module.find4 = mkFindN(4)
module.find10 = mkFindN(10, badgeEnums.badges.MarathonCompletionFind10)
module.find20 = mkFindN(20, badgeEnums.badges.MarathonCompletionFind20)
module.find40 = mkFindN(40, badgeEnums.badges.MarathonCompletionFind40)
module.find100 = mkFindN(100, badgeEnums.badges.MarathonCompletionFind100)
module.find200 = mkFindN(200, badgeEnums.badges.MarathonCompletionFind200)
module.find300 = mkFindN(300, badgeEnums.badges.MarathonCompletionFind300)
module.find380 = mkFindN(380, badgeEnums.badges.MarathonCompletionFind380)
module.find500 = mkFindN(500, badgeEnums.badges.MarathonCompletionFind500)

module.find10s = find10s
module.find10t = find10t

module.exactly40letters = mkLetterMarathon(40, badgeEnums.badges.MarathonCompletionExactly40)
module.exactly100letters = mkLetterMarathon(100, badgeEnums.badges.MarathonCompletionExactly100)
module.exactly200letters = mkLetterMarathon(200, badgeEnums.badges.MarathonCompletionExactly200)
module.exactly500letters = mkLetterMarathon(500, badgeEnums.badges.MarathonCompletionExactly500)
module.exactly1000letters = mkLetterMarathon(1000, badgeEnums.badges.MarathonCompletionExactly1000)

module.alphafree = alphaFree
module.alphaordered = alphaOrdered
module.alphareverse = alphaReverse

module.alphabeticalallletters = alphabeticalAllLetters

module.signsofeverylength = signsOfEveryLength
module.findsetevolution = mkFindSetMarathon(
	"evolution",
	"Evolution",
	{ "Darwin", "Fisher", "Haldane", "Helix", "Mutation", "Natural Selection" },
	badgeEnums.badges.MarathonCompletionEvolution
)

module.findsetfirstcontest = mkFindSetMarathon("firstevent", "First Event Marathon", {
	"Fisher",
	"Meme",
	"World Turtle",
	"Moranis",
	"Mango",
	"Dwarf Fortress",
	"Mud Theater",
	"Stepping Stone",
	"Joist",
	"Symmetry",
}, badgeEnums.badges.FirstContestParticipation)

module.findsetsingleletter = mkFindSetMarathon(
	"singleletter",
	"Single-Letters",
	getSignsWithTrait(function(s)
		return utf8.len(s) == 1
	end),
	badgeEnums.badges.MarathonCompletionSingleLetter
)

module.findsetlegacy = mkFindSetMarathon("legacy", "Legacy", {
	"Barrows",
	"Close",
	"Frigate",
	"Monolith",
	"Mud Theater",
	"Orthanc",
	"Plains",
	"Spaghett",
	"Start",
	"Ziggurat",
}, badgeEnums.badges.MarathonCompletionLegacy)

module.findsetcave = mkFindSetMarathon("cave", "Caves", {
	"Cave",
	"Cave of Forgotten Dreams",
	"Ice Cave",
	"Lava Tube",
}, badgeEnums.badges.MarathonCompletionCave)

local findsetAOfB = getSignsWithTrait(function(s)
	--the sign has to be <something> of <something else> so check for that.
	local split = s:split(" of ")
	if #split ~= 2 then
		return false
	end
	return true
end)

module.findsetaofb = mkFindSetMarathon("aofb", "A of B", findsetAOfB, badgeEnums.badges.MarathonCompletionAOfB)

module.findsetthreeletter = mkFindSetMarathon(
	"threeletter",
	"Find ten 3-letter signs",
	getSignsWithTrait(function(s)
		return utf8.len(s) == 3
	end),
	badgeEnums.badges.MarathonCompletionThreeLetter,
	10
)

_annotate("end")
return module
