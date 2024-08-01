--!strict

--2022.02.25 generic marathon descriptors
--TODO not working but would be nice if it were! it's close.
-- generate random user-side marathon descriptors for managing touch, etc.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local TweenService = game:GetService("TweenService")
local PlayersService = game:GetService("Players")

local enums = require(game.ReplicatedStorage.util.enums)
local colors = require(game.ReplicatedStorage.util.colors)
local marathonStatic = require(game.ReplicatedStorage.marathonStatic)
local marathonDescriptors = require(game.ReplicatedStorage.marathonDescriptors)
--global storage for user's lbframe

local mt = require(game.StarterPlayer.StarterPlayerScripts.marathonTypes)

local RRUpdateRow = function(desc: mt.marathonDescriptor, frame: Frame, foundSignName: string): nil
	local targetName = marathonStatic.getMarathonComponentName(desc, foundSignName)
	local exiTile: TextLabel = frame:FindFirstChild(targetName, true)
	if exiTile == nil then
		warn("bad.")
	end

	local bgcolor = colors.yellowFind
	exiTile.BackgroundColor3 = colors.greenGo
	local Tween = TweenService:Create(exiTile, TweenInfo.new(enums.greenTime), { BackgroundColor3 = bgcolor })
	Tween:Play()
end

--patching in to existing marathon system.
--note this isn't shipped yet
local pat: mt.marathonDescriptor = {
	kind = "",
	highLevelType = "randomrace",
	humanName = "",
	addDebounce = {},
	reportAsMarathon = true,
	finds = {},
	targets = {},
	orderedTargets = {},
	count = nil,
	requiredCount = 2,
	startTime = 0,
	killTimerSemaphore = false,
	runningTimeTileUpdater = false,
	timeTile = nil,
	IsDone = function(desc: mt.marathonDescriptor)
		return desc.count == 2
	end,
	AddSignToFinds = marathonDescriptors.DefaultAddSignToFinds,
	UpdateRow = RRUpdateRow,
	EvaluateFind = nil,
	SummarizeResults = marathonDescriptors.sequentialSummarizeResults,
	awardBadge = nil,
	chipPadding = 1,
	sequenceNumber = "zzzrandom",
}

module.CreateRandomRaceInMarathonUI = function(startSignName: string, endSignName: string): mt.marathonDescriptor
	local cdesc = {}
	for orig_key, orig_value in pairs(pat) do
		cdesc[orig_key] = orig_value
	end

	local desc = cdesc :: mt.marathonDescriptor

	desc.kind = "randomrace." .. startSignName .. "." .. endSignName
	desc.humanName = "Random Race"

	desc.EvaluateFind = function(desc: mt.marathonDescriptor, signName: string)
		return marathonDescriptors.evaluateFindInFixedOrder(desc, signName)
	end

	desc.orderedTargets = { startSignName, endSignName }
	return desc
end

_annotate("end")
return module
