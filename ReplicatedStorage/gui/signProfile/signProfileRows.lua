--!strict

--2022.03 pulled out commands from channel definitions

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local emojis = require(game.ReplicatedStorage.enums.emojis)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local tt = require(game.ReplicatedStorage.types.gametypes)
local signProfileStickyGui = require(game.ReplicatedStorage.gui.signProfile.signProfileStickyGui)
local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer

--[[

export type playerSignProfileData = {
    signName: string,
    signId: number,
    relationships: { userSignSignRelationship },
    unrunCwrs: { signName: string, runCount: number }, --limited selection. This is the signNames followed by parentheticals with the number of times they've been run total
    unrunRaces: { signName: string, runCount: number }, --EXCLUDES unrunCwrs. like, 'Wilson (10)'
    username: string,
    userId: number, --the SUBJECT userid.
    neverRunSignIds: { number },
}

--a chip that appears in a row for a placement level, DNP or unrun, for cwr races/noncwr races on sign profiles.
export type signProfileChipType = {
    text: string,
    relatedRaceData: { relatedRace } | nil,
    widthWeight: number?,
    bgcolor: Color3?,
}

    ]]
--
local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
local signGrindUIScreenGui: ScreenGui = Instance.new("ScreenGui")
signGrindUIScreenGui.Name = "AsignGrindUIScreenGui"
signGrindUIScreenGui.Parent = playerGui

-- for a list of relationships, creates a nice row.
local createPlacementRowForSetOfRaces = function(
	sourceSignName: string,
	sourceContext: string,
	relationships: { tt.userSignSignRelationship },
	unruns: { tt.relatedRace }
): { tt.signProfileChipType }
	local placementChips: { tt.signProfileChipType } = {}
	local placementCounts = {}
	local placementRelatedRaces: { [number]: { tt.userSignSignRelationship } } = {}
	for _, rel in ipairs(relationships) do
		if rel.bestPlace == nil or rel.bestPlace > 11 then
			rel.bestPlace = 11
		end
		if placementCounts[rel.bestPlace] == nil then
			placementCounts[rel.bestPlace] = 0
			placementRelatedRaces[rel.bestPlace] = {}
		end
		placementCounts[rel.bestPlace] += 1
		table.insert(placementRelatedRaces[rel.bestPlace], rel)
	end
	local startSignId = tpUtil.signName2SignId(sourceSignName)
	local ii = 1

	-- now iterate over the places.
	while ii <= 11 do
		local useCount = placementCounts[ii] or 0
		local guys: { tt.userSignSignRelationship } = placementRelatedRaces[ii]

		if guys then
			table.sort(guys, function(a: tt.userSignSignRelationship, b: tt.userSignSignRelationship)
				if a.runCount ~= b.runCount then
					return a.runCount < b.runCount
				end
				return a.endSignName < b.endSignName
			end)
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

		if guys and #guys > 0 then
			clicker.Activated:Connect(function()
				local fakeRrs: { tt.relatedRace } = {}
				for _, rel in ipairs(guys) do
					local tehFake: tt.relatedRace = {
						signName = rel.endSignName,
						totalRunnerCount = rel.runCount,
						signId = rel.endSignId,
					}
					table.insert(fakeRrs, tehFake)
				end
				local subwindowTitle = string.format("Grinding %s %s from %s", term, sourceContext, sourceSignName)
				local s = signProfileStickyGui.MakeSignProfileStickyGui(startSignId, subwindowTitle, fakeRrs)
				signGrindUIScreenGui.IgnoreGuiInset = true
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
	local clicker = Instance.new("TextButton")
	clicker.Name = "99_UnrunChip"
	clicker.Text = string.format("your unrun (%d)", #unruns)
	clicker.Size = UDim2.new(1, 0, 1, 0)
	clicker.BackgroundTransparency = 1
	clicker.TextScaled = true
	clicker.TextSize = 14

	if unruns and #unruns > 0 then
		clicker.Activated:Connect(function()
			local subwindowTitle = string.format("Grinding Unrun %s from %s", sourceContext, sourceSignName)
			local s = signProfileStickyGui.MakeSignProfileStickyGui(startSignId, subwindowTitle, unruns)
			signGrindUIScreenGui.IgnoreGuiInset = true
			s.Parent = signGrindUIScreenGui
		end)
	end

	local theGuy: tt.signProfileChipType = { text = "NONE", clicker = clicker, widthWeight = 1 }
	table.insert(placementChips, theGuy)

	return placementChips
end

-- it takes all sign relationships of you+the sign, filters for just the non-cwrs, and makes rows.
local signProfilePlacementRowMaker = function(data: tt.playerSignProfileData): { tt.signProfileChipType }
	local placementChips: { tt.signProfileChipType } = {}
	table.insert(placementChips, { text = "Your non-CWR results", widthWeight = 4 })
	local relatedRelationships: { tt.userSignSignRelationship } = {}
	for _, rel in ipairs(data.relationships) do
		if rel.isCwr then
			continue
		end
		table.insert(relatedRelationships, rel)
	end
	local otherChips = createPlacementRowForSetOfRaces(data.signName, "nonCWRs", relatedRelationships, data.unrunRaces)
	for _, chip in ipairs(otherChips) do
		table.insert(placementChips, chip)
	end
	return placementChips
end

-- it takes all sign relationships of you+the sign, filters for just the cwrs, and makes rows.
local signProfileCRWRowMaker = function(data: tt.playerSignProfileData): { tt.signProfileChipType }
	local placementChips: { tt.signProfileChipType } = {}
	table.insert(placementChips, { text = "Your CWR results", widthWeight = 4 })
	local relatedRelationships = {}
	for _, rel in ipairs(data.relationships) do
		if not rel.isCwr then
			continue
		end
		table.insert(relatedRelationships, rel)
	end
	local otherChips = createPlacementRowForSetOfRaces(data.signName, "CWRs", relatedRelationships, data.unrunCwrs)
	for _, chip in ipairs(otherChips) do
		table.insert(placementChips, chip)
	end
	return placementChips
end

local dist = 0
local signProfileDistanceRowMaker = function(data: tt.playerSignProfileData): { tt.signProfileChipType }
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
