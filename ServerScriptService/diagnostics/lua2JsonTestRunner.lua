--!strict
-- rojo/ServerScriptService/diagnostics/lua2JsonTestRunner.lua
-- Periodically executes lua2Json regression tests to surface serialization drift.
-- Emits timing and success-rate telemetry through annotater for lightweight monitoring.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

annotater.Init()

local lua2JsonTests = require(game.ReplicatedStorage.util.lua2JsonTests)

type SuiteResult = {
	totalCount: number,
	successCount: number,
	failureDetails: { { name: string, message: string } },
}

local RUN_INTERVAL_SECONDS = 900
local INITIAL_DELAY_SECONDS = 5

local totalRuns = 0
local cumulativeSuccessCount = 0
local cumulativeTotalCount = 0

local function formatPercent(value: number): string
	if value ~= value or value == math.huge or value == -math.huge then
		return "0.0%"
	end
	return string.format("%.1f%%", value * 100)
end

local function emitFailures(result: SuiteResult, elapsedSeconds: number)
	local failureSummaries = {}
	for _, failure in ipairs(result.failureDetails) do
		table.insert(failureSummaries, string.format("%s -> %s", failure.name, failure.message))
	end

	annotater.Error(
		string.format(
			"lua2Json tests FAIL %s (%d/%d) in %.3fs",
			formatPercent(result.successCount / math.max(1, result.totalCount)),
			result.successCount,
			result.totalCount,
			elapsedSeconds
		),
		{
			failures = failureSummaries,
			elapsedSeconds = elapsedSeconds,
			successCount = result.successCount,
			totalCount = result.totalCount,
			runIndex = totalRuns,
		}
	)
end

local function emitSuccess(result: SuiteResult, elapsedSeconds: number, averageRate: number)
	local message = string.format(
		"lua2Json tests PASS %s (%d/%d) in %.3fs | avg %s across %d runs",
		formatPercent(result.successCount / math.max(1, result.totalCount)),
		result.successCount,
		result.totalCount,
		elapsedSeconds,
		formatPercent(averageRate),
		totalRuns
	)
	print(message)
	_annotate(message)
end

local function runSuiteOnce()
	local startedClock = os.clock()
	local result = lua2JsonTests.RunSuite()
	local elapsedSeconds = os.clock() - startedClock

	totalRuns += 1
	cumulativeSuccessCount += result.successCount
	cumulativeTotalCount += result.totalCount

	local averageRate = 0
	if cumulativeTotalCount > 0 then
		averageRate = cumulativeSuccessCount / cumulativeTotalCount
	end

	if result.successCount == result.totalCount then
		emitSuccess(result, elapsedSeconds, averageRate)
		return
	end

	emitFailures(result, elapsedSeconds)
end

local function scheduleNextRun()
	task.delay(RUN_INTERVAL_SECONDS, function()
		runSuiteOnce()
		scheduleNextRun()
	end)
end

task.delay(INITIAL_DELAY_SECONDS, function()
	runSuiteOnce()
	scheduleNextRun()
end)

_annotate("end")
