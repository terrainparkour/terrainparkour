--!strict

-- RemoteDb Wrappers
-- ideally all things which require direct network calls should have sensible normal layers here incl caching
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local tt = require(game.ReplicatedStorage.types.gametypes)
local posting = require(game.ServerScriptService.posting)
local config = require(game.ReplicatedStorage.config)

local _host: any
local hostS, _hostLoad = pcall(function()
	_host = require(game.ServerScriptService.hostSecret)
end)
if not hostS then
	_annotate("you are running the test version; host remote calls will not work.")
	_host = nil
end

------------- STATE VARIABLES for the HttpService queue, requesting etc. --------------
local httpRemaining = 20
local httpPerMinMax = 470
local waitTime = 0.03
local httpaddPerSecond = math.floor(httpPerMinMax / 60)
local slowRequestThresholdSeconds = 0.5
local logAllRequests = config.IsInStudio() or config.IsTestGame()

local getRequestUserId = function(data: any): number?
	if typeof(data) ~= "table" then
		return nil
	end

	local candidate = data.userId or data.userid
	if typeof(candidate) == "number" then
		return candidate
	end
	if typeof(candidate) == "string" then
		local parsed = tonumber(candidate)
		if parsed then
			return parsed
		end
	end
	return nil
end

-------------- ADJUST HOW MANY REQUESTS WE CAN DO ------------------------

local startHttpServiceRequestManager = function()
	task.spawn(function()
		while true do
			local waited = task.wait(1)
			httpRemaining = math.min(httpPerMinMax, httpRemaining + httpaddPerSecond * waited)
			if httpRemaining < 2 then
				_annotate(string.format("httpRemaining: %d, waiting.", httpRemaining))
				task.wait(waitTime)
			end
		end
	end)
end

-- local debouncePosting = false
module.MakePostRequest = function(request: tt.postRequest): any
	local remoteActionName = request.remoteActionName or "missingRemoteAction"
	local waitedForCapacityStart: number? = nil

	while httpRemaining <= 0 do
		if waitedForCapacityStart == nil then
			waitedForCapacityStart = tick()
			_annotate(string.format("rdb.%s WAITING_FOR_CAPACITY (remaining=%d)", remoteActionName, httpRemaining))
		end
		task.wait(waitTime)
	end

	local waitedForCapacity = 0
	if waitedForCapacityStart ~= nil then
		waitedForCapacity = tick() - waitedForCapacityStart
	end

	local requestUserId = getRequestUserId(request.data)
	if logAllRequests then
		_annotate(
			string.format(
				"rdb.%s START (waitedForTokens=%.3fs, remaining=%d, userId=%s)",
				remoteActionName,
				waitedForCapacity,
				httpRemaining,
				requestUserId and tostring(requestUserId) or "n/a"
			)
		)
	end

	local requestStartTick = tick()
	local res
	local s, e = pcall(function()
		res = posting.MakePostRequest(request)
		httpRemaining -= 1
	end)
	local elapsed = tick() - requestStartTick

	if not s then
		annotater.Error("error making post request", {
			remoteActionName = request.remoteActionName,
			error = tostring(e),
			elapsedSeconds = elapsed,
			userId = requestUserId,
		})
	else
		local logLabel = "DONE"
		if elapsed >= slowRequestThresholdSeconds then
			logLabel = "SLOW"
		end

		if logAllRequests or elapsed >= slowRequestThresholdSeconds then
			_annotate(
				string.format(
					"rdb.%s %s (elapsed=%.3fs, waitedForTokens=%.3fs, remaining=%d, userId=%s)",
					remoteActionName,
					logLabel,
					elapsed,
					waitedForCapacity,
					httpRemaining,
					requestUserId and tostring(requestUserId) or "n/a"
				)
			)
		end
	end

	if not s then
		return { res = false, error = "network_error: " .. tostring(e) }
	end

	if not res or not res["res"] then
		annotater.Error("post request returned invalid response structure", {
			remoteActionName = request.remoteActionName,
			res = res,
			elapsedSeconds = elapsed,
			userId = requestUserId,
		})
		return { res = false, error = "Invalid response from backend" }
	end

	if not logAllRequests and elapsed < slowRequestThresholdSeconds then
		_annotate(string.format("did http request, remaining = %d", httpRemaining))
	end

	-- Return res["res"] - the actual response payload
	-- Normalize boolean responses to setSettingResponse format for consistency
	local payload = res["res"]
	if typeof(payload) == "boolean" then
		return { res = payload, error = "" }
	end
	return payload
end

------------------HELPER LOGICAL METHODS----------------------------

module.Init = function()
	startHttpServiceRequestManager()
end

_annotate("end")
return module
