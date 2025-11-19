--!strict

-- RemoteDb Wrappers
-- ideally all things which require direct network calls should have sensible normal layers here incl caching
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local tt = require(game.ReplicatedStorage.types.gametypes)
local posting = require(game.ServerScriptService.posting)

local host
local hostS, hostLoad = pcall(function()
	host = require(game.ServerScriptService.hostSecret)
end)
if not hostS then
	_annotate(string.format("you are running the test version; host remote calls will not work."))
	host = nil
end

------------- STATE VARIABLES for the HttpService queue, requesting etc. --------------
local httpRemaining = 20
local httpPerMinMax = 470
local waitTime = 0.03
local httpaddPerSecond = math.floor(httpPerMinMax / 60)

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
	while httpRemaining <= 0 do
		_annotate(string.format("waiting for http service capacity"))
		task.wait(waitTime)
	end
	local res
	local s, e = pcall(function()
		res = posting.MakePostRequest(request)
		httpRemaining -= 1
	end)

	if not s then
		annotater.Error(
			"error making post request",
			{ remoteActionName = request.remoteActionName, error = tostring(e) }
		)
		return { error = "network_error", message = tostring(e) }
	end

	if not res or not res["res"] then
		annotater.Error(
			"post request returned invalid response structure",
			{ remoteActionName = request.remoteActionName, res = res }
		)
		return { error = "parse_error", message = "Invalid response structure from backend" }
	end

	_annotate(string.format("did http request, remaining = %d", httpRemaining))
	return res["res"]
end

------------------HELPER LOGICAL METHODS----------------------------

module.Init = function()
	startHttpServiceRequestManager()
end

_annotate(string.format("end"))
return module
