--!strict

-- marathonStatic. 2024 Not sure why this is organized this way.
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local colors = require(game.ReplicatedStorage.util.colors)
local mt = require(game.StarterPlayer.StarterPlayerScripts.marathon.marathonTypes)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)

-------NAMES----------

--for a given component (chip in the badgeStatus list for a marathon), get a name.
--this is so creators and later finders can genericize.
module.getMarathonComponentName = function(desc: mt.marathonDescriptor, componentKey: string): string
	local targetName = "Chip_" .. desc.kind .. "_" .. componentKey
	return targetName
end

-----------LOOKUPS-------------
module.alphaKeys = {
	"a",
	"b",
	"c",
	"d",
	"e",
	"f",
	"g",
	"h",
	"i",
	"j",
	"k",
	"l",
	"m",
	"n",
	"o",
	"p",
	"q",
	"r",
	"s",
	"t",
	"u",
	"v",
	"w",
	"x",
	"y",
	"z",
}

module.alphaKeysReverse = {
	"z",
	"y",
	"x",
	"w",
	"v",
	"u",
	"t",
	"s",
	"r",
	"q",
	"p",
	"o",
	"n",
	"m",
	"l",
	"k",
	"j",
	"i",
	"h",
	"g",
	"f",
	"e",
	"d",
	"c",
	"b",
	"a",
}

--its important to use the module naming method to get the name because
--that will be used later to find the way to toggle it on again.
--e.g. make chips for marathon subcomponent achievements
module.makeChipForSubcomponent = function(
	desc: mt.marathonDescriptor,
	key: string,
	xscale: number,
	zindex: number
): TextLabel
	local name = module.getMarathonComponentName(desc, key)
	local fakeParent = Instance.new("Frame")
	local chipPadding: number? = desc.chipPadding
	local usePadding: number = 0
	if chipPadding ~= nil then
		usePadding = chipPadding :: number
	end
	local tl = guiUtil.getTl(name, UDim2.new(0, xscale, 1, 0), usePadding, fakeParent, colors.defaultGrey, 1, 0)
	-- tl.Parent.BorderMode = Enum.BorderMode.Outline

	--TODO fix this - override hack because keys are 2digit numbers and for display in this case we want to fix.
	if desc.highLevelType == "signsOfEveryLength" then
		local numKey = tonumber(key)
		if numKey then
			key = tostring(numKey)
		end
		tl.TextScaled = true
	end
	if desc.highLevelType == "findSet" then
		tl.TextScaled = true
	end
	tl.Text = key
	tl.ZIndex = zindex
	local chipLabelCandidate = fakeParent:FindFirstChild(name)
	if not chipLabelCandidate or not chipLabelCandidate:IsA("TextLabel") then
		error("getMarathonComponentName: missing chip label " .. name)
	end
	local chipLabel = chipLabelCandidate :: TextLabel
	chipLabel.ZIndex = zindex
	return chipLabel
end

module.getChipFrame = function(desc: mt.marathonDescriptor): Frame
	--types for which we should make a chip for every item in targets or orderedTargets
	if
		desc.highLevelType == "alphabetical"
		or desc.highLevelType == "signsOfEveryLength"
		or desc.highLevelType == "findSet"
	then
		-- local remainingLetterWidth = areaForChips
		local effectiveTargets = desc.targets
		if #effectiveTargets == 0 then
			effectiveTargets = desc.orderedTargets
		end
		if #effectiveTargets == 0 then
			warn("error in marathon setup.")
		end
		local totalLetterLength = 0
		for ii, k in ipairs(effectiveTargets) do
			totalLetterLength += string.len(k)
		end

		local perLetter = 1.0 / totalLetterLength
		local frame = Instance.new("Frame")
		frame.Name = "02-chipHolder"
		frame.Size = UDim2.new(1, -78, 1, 0)

		local hh = Instance.new("UIListLayout")
		hh.Parent = frame
		hh.Name = "chipOrder"
		hh.FillDirection = Enum.FillDirection.Horizontal
		hh.HorizontalFlex = Enum.UIFlexAlignment.Fill
		hh.VerticalAlignment = Enum.VerticalAlignment.Top
		hh.HorizontalAlignment = Enum.HorizontalAlignment.Left
		hh.SortOrder = Enum.SortOrder.Name

		for ii, k in ipairs(effectiveTargets) do
			local thisWidthScale = string.len(k) * perLetter
			local tl = module.makeChipForSubcomponent(desc, k, thisWidthScale, ii)
			tl.Parent = frame
		end
		return frame
	elseif desc.highLevelType == "findnletters" then
		local frame = Instance.new("Frame")
		frame.Name = "02-chipHolder"
		frame.Size = UDim2.new(1, -78, 1, 0)
		local tl = module.makeChipForSubcomponent(desc, desc.humanName, 0, 6)
		tl.Text = desc.humanName
		tl.Size = UDim2.new(1, 0, 1, 0)
		tl.Parent = frame
		return frame
	elseif desc.highLevelType == "findn" then
		local frame = Instance.new("Frame")
		frame.Name = "02-chipHolder"
		frame.Size = UDim2.new(1, -78, 1, 0)

		local innerFrame = Instance.new("Frame")
		innerFrame.Name = module.getMarathonComponentName(desc, desc.humanName)
		innerFrame.Size = UDim2.new(1, 0, 1, 0)
		innerFrame.Parent = frame

		-- we manage these by putting in two tiles, named Yes and No, which grow/shrink
		local hh = Instance.new("UIListLayout")
		hh.Parent = frame
		hh.Name = "chipOrder"
		hh.FillDirection = Enum.FillDirection.Horizontal
		hh.HorizontalFlex = Enum.UIFlexAlignment.Fill
		hh.VerticalAlignment = Enum.VerticalAlignment.Top
		hh.HorizontalAlignment = Enum.HorizontalAlignment.Left
		hh.SortOrder = Enum.SortOrder.Name
		hh.Parent = innerFrame
		local usePadding = 0
		local fakeParent = Instance.new("Frame")
		local yesTl = guiUtil.getTl("01-Yes", UDim2.new(0, 0, 1, 0), usePadding, fakeParent, colors.defaultGrey, 1, 0)
		local noTl = guiUtil.getTl("03-No", UDim2.new(0, 0, 1, 0), usePadding, fakeParent, colors.defaultGrey, 1, 0)
		yesTl.Text = ""
		noTl.Text = "Find " .. tostring(desc.requiredCount)

		local yesParent = yesTl.Parent
		local noParent = noTl.Parent
		if yesParent and noParent then
			yesParent.Parent = innerFrame
			noParent.Parent = innerFrame
		else
			warn("marathonStatic: yesTl or noTl missing Parent")
		end

		return frame
	else
		warn("Missed kind in setting up tiles. this will definitely fail.")
		local errorFrame = Instance.new("Frame")
		errorFrame.Name = "error"
		return errorFrame
	end

	-- reconsiderOffsetXInTilesAsScale(tiles)
end

------------END STATIC

_annotate("end")
return module
