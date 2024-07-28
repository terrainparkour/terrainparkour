--!strict

--2022.03 pulled out commands from channel definitions

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local textUtil = require(game.ReplicatedStorage.util.textUtil)
local enums = require(game.ReplicatedStorage.util.enums)
local emojis = require(game.ReplicatedStorage.enums.emojis)

local config = require(game.ReplicatedStorage.config)

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local tt = require(game.ReplicatedStorage.types.gametypes)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local colors = require(game.ReplicatedStorage.util.colors)

local module = {}

local placementProfiler = function(data: tt.playerSignProfileData): { tt.chipType }
	local res: { tt.chipType } = {}
	table.insert(res, { text = "Results from " .. data.signName, widthWeight = 4 })
	local counts = {}
	local names = {}
	for _, rel in ipairs(data.relationships) do
		if rel.bestPlace == nil or rel.bestPlace > 11 then
			rel.bestPlace = 11
		end
		if counts[rel.bestPlace] == nil then
			counts[rel.bestPlace] = 0
			names[rel.bestPlace] = {}
		end
		counts[rel.bestPlace] += 1
		table.insert(names[rel.bestPlace], rel.endSignName)
	end

	local ii = 1
	local term = ""
	while ii <= 11 do
		local useCount = counts[ii] or 0
		local chunk = names[ii]
		local joined = ""
		if chunk then
			table.sort(chunk)
			joined = textUtil.stringJoin(", ", chunk)
		end
		if ii < 11 then
			term = tpUtil.getCardinalEmoji(ii)
		else
			term = "DNP " .. emojis.emojis.BOMB
		end
		table.insert(res, { text = string.format("%s\n%d", term, useCount), toolTip = joined })
		ii += 1
	end

	local joined = textUtil.stringJoin(", ", data.unrunSigns)
	table.insert(res, { text = string.format("%s\n%d", "unrun", #data.unrunSigns), toolTip = joined })

	return res
end

local cwrProfiler = function(data: tt.playerSignProfileData): { tt.chipType }
	local res: { tt.chipType } = {}
	table.insert(res, { text = "CWR results from " .. data.signName, widthWeight = 4 })
	local counts = {}
	local names = {}
	for _, rel in ipairs(data.relationships) do
		if not rel.isCwr then
			continue
		end
		if rel.bestPlace == nil or rel.bestPlace > 11 then
			rel.bestPlace = 11
		end
		if counts[rel.bestPlace] == nil then
			counts[rel.bestPlace] = 0
			names[rel.bestPlace] = {}
		end
		counts[rel.bestPlace] += 1
		table.insert(names[rel.bestPlace], rel.endSignName)
	end

	local ii = 1

	while ii <= 11 do
		local useCount = counts[ii] or 0
		local chunk = names[ii]
		local joined = ""
		if chunk then
			table.sort(chunk)
			joined = textUtil.stringJoin(", ", chunk)
		end
		local term
		if ii < 11 then
			term = tpUtil.getCardinalEmoji(ii)
		else
			term = "DNP " .. emojis.emojis.BOMB
		end
		table.insert(res, { text = string.format("%s\n%d", term, useCount), toolTip = joined })
		ii += 1
	end

	local joined = textUtil.stringJoin(", ", data.unrunCwrs)
	table.insert(res, { text = string.format("%s\n%d", "unrun", #data.unrunCwrs), toolTip = joined })

	return res
end

local distanceCounter = function(data: tt.playerSignProfileData)
	local dist = 0
	local res: { tt.chipType } = {}
	for _, rel in ipairs(data.relationships) do
		dist += rel.runCount * rel.dist
	end
	table.insert(res, { text = "Total distance ran from " .. data.signName, widthWeight = 2 })
	table.insert(res, { text = string.format("%0.0fd", dist) })
	return res
end

local generalInfoCounter = function(data: tt.playerSignProfileData)
	local totalRuns = 0
	local totalCwrs = 0
	local totalCwrLed = 0
	local longestRelationship: tt.userSignSignRelationship
	local mostRun: tt.userSignSignRelationship
	local res: { tt.chipType } = {}
	for _, rel in ipairs(data.relationships) do
		totalRuns += rel.runCount
		totalCwrs += rel.isCwr and 1 or 0
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
	return res
end
local timeCounter = function(data: tt.playerSignProfileData)
	local timeMs = 0
	local res: { tt.chipType } = {}
	for _, rel in ipairs(data.relationships) do
		timeMs += rel.runCount * rel.bestTimeMs
	end
	table.insert(res, { text = "Total time ran from " .. data.signName, widthWeight = 2 })
	table.insert(res, { text = string.format(">=%0.0fs", timeMs / 1000) })
	return res
end

local rowGenerators: { tt.rowDescriptor } = {}
table.insert(rowGenerators, generalInfoCounter)
table.insert(rowGenerators, distanceCounter)
table.insert(rowGenerators, timeCounter)
table.insert(rowGenerators, placementProfiler)
table.insert(rowGenerators, cwrProfiler)

module.rowGenerators = rowGenerators

_annotate("end")
return module
