--!strict

--2022.03 pulled out commands from channel definitions

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local emojis = require(game.ReplicatedStorage.enums.emojis)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local tt = require(game.ReplicatedStorage.types.gametypes)
local signProfileGrindingGui = require(game.ReplicatedStorage.gui.signProfile.signProfileGrindingGui)
local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer

local signGrindUIScreenGui: ScreenGui = nil

-- for a list of relationships, creates a nice row with:"your results in this type of race from this sign including: your
-- placements at every place (first..10th, did not place) followed by also a list of unrun races. --which can be riskier since
-- you may not have even found the sign yet.
local createPlacementRowForSetOfRaces = function(
	sourceSignName: string,
	sourceContext: string,
	relationships: { tt.userSignSignRelationship },
	unruns: { tt.relatedRace },
	globalUnrunRaces: { tt.relatedRace }
): { tt.signProfileChipType }
	local placementChips: { tt.signProfileChipType } = {}
	local placementCounts = {}
	local placementRelatedRaces: { [number]: { tt.userSignSignRelationship } } = {}
	for _, rel: tt.userSignSignRelationship in ipairs(relationships) do
		-- we either use the place or 11 if it's null or higher than 10.
		local usingBestPlace = rel.bestPlace and rel.bestPlace < 10 and rel.bestPlace or 11
		if placementCounts[usingBestPlace] == nil then
			placementCounts[usingBestPlace] = 0
			placementRelatedRaces[usingBestPlace] = {}
		end
		placementCounts[usingBestPlace] += 1

		table.insert(placementRelatedRaces[usingBestPlace], rel)
	end
	local startSignId = tpUtil.signName2SignId(sourceSignName)
	local ii = 1

	-- now iterate over the places.
	while ii <= 11 do
		local useCount = placementCounts[ii] or 0
		local relationshipsForThisPlacementRank: { tt.userSignSignRelationship } = placementRelatedRaces[ii]

		if relationshipsForThisPlacementRank then
			table.sort(
				relationshipsForThisPlacementRank,
				function(a: tt.userSignSignRelationship, b: tt.userSignSignRelationship)
					if a.runCount ~= b.runCount then
						return a.runCount > b.runCount
					end
					return a.endSignName > b.endSignName
				end
			)
		end
		local term
		if ii < 11 then
			term = tpUtil.getCardinalEmoji(ii)
		else
			term = "DNP " .. emojis.emojis.BOMB
		end
		local clicker = Instance.new("TextButton")
		clicker.Name = string.format("%02d_signProfileChip_place", ii)
		clicker.Text = string.format("%s\n%d", term, useCount)
		clicker.Size = UDim2.new(1 / 13, 0, 1, 0)
		clicker.BackgroundTransparency = 1
		clicker.TextScaled = true
		clicker.TextSize = 14

		if relationshipsForThisPlacementRank and #relationshipsForThisPlacementRank > 0 then
			clicker.Activated:Connect(function()
				local fakeRrs: { tt.relatedRace } = {}
				for _, rel in ipairs(relationshipsForThisPlacementRank) do
					local tehFake: tt.relatedRace = {
						signName = rel.endSignName,
						totalRunnerCount = rel.runCount,
						signId = rel.endSignId,
						hasFoundSign = true, --the onlye signs that it's even possible we haven't found are the unrun ones.
					}
					table.insert(fakeRrs, tehFake)
				end
				local subwindowTitle =
					string.format("Grinding %s races from %s where you place %s", sourceContext, sourceSignName, term)
				local s = signProfileGrindingGui.MakeSignProfileGrindingGui(startSignId, subwindowTitle, fakeRrs)
				local playerGui: PlayerGui? = localPlayer:FindFirstChildOfClass("PlayerGui") :: PlayerGui
				if playerGui == nil then
					return
				end
				signGrindUIScreenGui = playerGui:FindFirstChild("SignGrindUIScreenGui")

				if not signGrindUIScreenGui then
					signGrindUIScreenGui = Instance.new("ScreenGui")
					signGrindUIScreenGui.Name = "SignGrindUIScreenGui"
					signGrindUIScreenGui.Parent = playerGui
					signGrindUIScreenGui.IgnoreGuiInset = true
				end
				signGrindUIScreenGui.Enabled = true

				s.Parent = signGrindUIScreenGui
			end)
		end
		ii += 1
		local theGuy: tt.signProfileChipType = {
			text = string.format("%s\n%d", term, useCount),
			clicker = clicker,
			widthWeight = 1,
		}
		table.insert(placementChips, theGuy)
	end

	-- accumulating the info on unrun.
	local yourUnrunClicker = Instance.new("TextButton")
	yourUnrunClicker.Name = "98_UnrunChip"
	yourUnrunClicker.Text = string.format("you never ran: %d", #unruns)
	yourUnrunClicker.Size = UDim2.new(1, 0, 1, 0)
	yourUnrunClicker.BackgroundTransparency = 1
	yourUnrunClicker.TextScaled = true
	yourUnrunClicker.TextSize = 14

	if unruns and #unruns > 0 then
		yourUnrunClicker.Activated:Connect(function()
			local subwindowTitle = string.format("Grinding your unrun %s from %s", sourceContext, sourceSignName)
			local s = signProfileGrindingGui.MakeSignProfileGrindingGui(startSignId, subwindowTitle, unruns)
			local playerGui: PlayerGui? = localPlayer:FindFirstChildOfClass("PlayerGui") :: PlayerGui
			if playerGui == nil then
				return
			end
			signGrindUIScreenGui = playerGui:FindFirstChild("SignGrindUIScreenGui") :: ScreenGui

			if not signGrindUIScreenGui then
				local theSignGrindUIScreenGui = Instance.new("ScreenGui")
				theSignGrindUIScreenGui.Name = "SignGrindUIScreenGui"
				theSignGrindUIScreenGui.Parent = playerGui
				theSignGrindUIScreenGui.IgnoreGuiInset = true
				signGrindUIScreenGui = theSignGrindUIScreenGui
			end
			signGrindUIScreenGui.Enabled = true
			s.Parent = signGrindUIScreenGui
		end)
	end

	local theGuy: tt.signProfileChipType = { text = "NONE", clicker = yourUnrunClicker, widthWeight = 1 }
	table.insert(placementChips, theGuy)

	-- local globalUnrunClicker = Instance.new("TextButton")
	-- globalUnrunClicker.Name = "99_GlobalUnrunChip"
	-- globalUnrunClicker.Text = string.format("nobody ever ran: %d", #unruns)
	-- globalUnrunClicker.Size = UDim2.new(1, 0, 1, 0)
	-- globalUnrunClicker.BackgroundTransparency = 1
	-- globalUnrunClicker.TextScaled = true
	-- globalUnrunClicker.TextSize = 14

	-- if globalUnrunRaces and #globalUnrunRaces > 0 then
	-- 	globalUnrunClicker.Activated:Connect(function()
	-- 		local subwindowTitle = string.format("Grinding global never run %s from %s ", sourceContext, sourceSignName)
	-- 		local s = signProfileGrindingGui.MakeSignProfileGrindingGui(startSignId, subwindowTitle, globalUnrunRaces)
	-- 		signGrindUIScreenGui = playerGui:FindFirstChild("SignGrindUIScreenGui")

	-- 		if not signGrindUIScreenGui then
	-- 			signGrindUIScreenGui = Instance.new("ScreenGui")
	-- 			signGrindUIScreenGui.Name = "SignGrindUIScreenGui"
	-- 			signGrindUIScreenGui.Parent = playerGui
	-- 			signGrindUIScreenGui.IgnoreGuiInset = true
	-- 		end
	-- 		signGrindUIScreenGui.Enabled = true
	-- 		s.Parent = signGrindUIScreenGui
	-- 	end)
	-- end

	-- local theGuy: tt.signProfileChipType = { text = "NONE", clicker = globalUnrunClicker, widthWeight = 1 }
	-- table.insert(placementChips, theGuy)

	return placementChips
end

-- it takes all sign relationships of you+the sign, filters for just the non-cwrs, and makes rows.
local signProfilePlacementRowMaker = function(data: tt.playerSignProfileData): { tt.signProfileChipType }
	local placementChips: { tt.signProfileChipType } = {}
	table.insert(placementChips, { text = "Your non-CWR performance", widthWeight = 4 })
	local relatedRelationships: { tt.userSignSignRelationship } = {}

	-- filtering just for cwrs here.
	for _, rel in ipairs(data.relationships) do
		if rel.isCwr then
			continue
		end
		table.insert(relatedRelationships, rel)
	end
	local otherChips = createPlacementRowForSetOfRaces(
		data.signName,
		"nonCWRs",
		relatedRelationships,
		data.unrunRaces,
		data.unrunRaces
	)
	for _, chip in ipairs(otherChips) do
		table.insert(placementChips, chip)
	end
	return placementChips
end

-- it takes all sign relationships of you+the sign, filters for just the cwrs, and makes rows.
local signProfileCRWRowMaker = function(data: tt.playerSignProfileData): { tt.signProfileChipType }
	local placementChips: { tt.signProfileChipType } = {}
	table.insert(placementChips, { text = "Your CWR performance", widthWeight = 4 })
	local relatedRelationships = {}
	for _, rel in ipairs(data.relationships) do
		if not rel.isCwr then
			continue
		end
		table.insert(relatedRelationships, rel)
	end
	local otherChips =
		createPlacementRowForSetOfRaces(data.signName, "CWRs", relatedRelationships, data.unrunCwrs, data.unrunCwrs)
	for _, chip in ipairs(otherChips) do
		table.insert(placementChips, chip)
	end
	return placementChips
end

local signProfileDistanceRowMaker = function(data: tt.playerSignProfileData): { tt.signProfileChipType }
	local dist = 0
	local res: { tt.signProfileChipType } = {}
	for _, rel in ipairs(data.relationships) do
		dist += rel.runCount * rel.dist
	end
	table.insert(res, { text = "Total distance ran from " .. data.signName, widthWeight = 2 })
	table.insert(res, { text = string.format("%0.0fd", dist) })
	return res
end

local signProfileGeneralInfoRowMaker = function(data: tt.playerSignProfileData): { tt.signProfileChipType }
	local totalRuns = 0

	-- this is important since iterating over the *relationships* will exclude ones where there
	-- is no relationship. Therefore we have to adjust this.
	local totalCwrs = #data.unrunCwrs
	local totalCwrLed = 0
	local longestRelationship: tt.userSignSignRelationship
	local mostRun: tt.userSignSignRelationship
	local res: { tt.signProfileChipType } = {}
	for _, rel in ipairs(data.relationships) do
		totalRuns += rel.runCount
		if rel.isCwr then
			totalCwrs += 1
		end
		if rel.isCwr and rel.bestPlace == 1 then
			totalCwrLed += 1
		end
		if longestRelationship == nil or longestRelationship.dist < rel.dist then
			longestRelationship = rel
		end
		if mostRun == nil or mostRun.runCount < mostRun.runCount then
			mostRun = rel
		end
	end

	table.insert(res, { text = string.format("Runs %d", totalRuns) })
	table.insert(res, { text = string.format("You hold %d/%d cwrs", totalCwrLed, totalCwrs) })
	if longestRelationship then
		table.insert(res, {
			text = string.format(
				"Your Longest run: %s (%0.0dd)",
				longestRelationship.endSignName,
				longestRelationship.dist
			),
		})
	end
	if mostRun then
		table.insert(res, {
			text = string.format(
				"Most frequent run: %s %d - (%0.0dd)",
				mostRun.endSignName,
				mostRun.runCount,
				mostRun.dist
			),
		})
	end
	table.insert(res, { text = string.format("Never run signs (%d)", #data.neverRunSignIds) })
	return res
end

local signProfileTimeCounter = function(data: tt.playerSignProfileData): { tt.signProfileChipType }
	local timeMs = 0
	local res: { tt.signProfileChipType } = {}
	for _, rel in ipairs(data.relationships) do
		timeMs += rel.runCount * rel.bestTimeMs
	end
	table.insert(res, { text = "Total time ran from " .. data.signName, widthWeight = 2 })
	table.insert(res, { text = string.format(">=%0.0fs", timeMs / 1000) })
	return res
end

local makeChip = function(chip: tt.signProfileChipType): TextButton | TextLabel
	if chip.clicker then
		return chip.clicker
	end
	local label = Instance.new("TextLabel")
	label.Name = "000_signProfileChip" .. chip.text
	label.Text = chip.text
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.BorderSizePixel = 1
	label.TextSize = 14
	return label
end

local function wrap(
	rowGenerator: (tt.playerSignProfileData) -> { tt.signProfileChipType }
): (tt.playerSignProfileData) -> { TextButton | TextLabel }
	local inner = function(data: tt.playerSignProfileData): { TextButton | TextLabel }
		local res: { tt.signProfileChipType } = rowGenerator(data)
		local out: { TextButton | TextLabel } = {}
		local total = 0
		for _, el in pairs(res) do
			if el.widthWeight then
				total += el.widthWeight
			else
				el.widthWeight = 1
				total += 1
			end
		end
		for _, el in pairs(res) do
			local btn = makeChip(el)
			btn.Size = UDim2.new(el.widthWeight / total, 0, 1, 0)
			table.insert(out, btn)
		end
		return out
	end
	return inner
end

local rowGenerators: { (tt.playerSignProfileData) -> { TextLabel | TextButton } } = {
	wrap(signProfileGeneralInfoRowMaker),
	wrap(signProfileDistanceRowMaker),
	wrap(signProfileTimeCounter),
	wrap(signProfileCRWRowMaker),
	wrap(signProfilePlacementRowMaker),
}

module.RowGenerators = rowGenerators

_annotate("end")
return module
