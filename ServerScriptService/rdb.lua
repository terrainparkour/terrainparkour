--!strict

-- RemoteDb Wrappers
-- ideally all things which require direct network calls should have sensible normal layers here incl caching
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local tt = require(game.ReplicatedStorage.types.gametypes)
local posting = require(game.ServerScriptService.posting)

local host
local hostS, c = pcall(function()
	host = require(game.ServerScriptService.hostSecret)
end)
if not hostS then
	_annotate(string.format("you are running the test version; host remote calls will not work."))
	host = nil
end

------------- STATE VARIABLES for the HttpService queue, requesting etc. --------------
local httpRemaining = 20
local httpPerMinMax = 470
local waitTime = 0.6
local httpaddPerSecond = math.floor(httpPerMinMax / 60)

-------------- ADJUST HOW MANY REQUESTS WE CAN DO ------------------------

local startHttpServiceRequestManager = function()
	task.spawn(function()
		while true do
			local waited = task.wait(1)
			httpRemaining = math.min(httpPerMinMax, httpRemaining + httpaddPerSecond * waited)
			-- _annotate(string.format("httpRemaining: %d", httpRemaining))
			task.wait(waitTime)
		end
	end)
end

-- we glom extra notification data onto the responses to random reqeuests. This broadcasts them out.
-- local function afterRemoteDbActions(afterData: tt.afterdata)
-- 	if afterData.actionResults == nil then
-- 		return
-- 	end
-- 	if #afterData.actionResults == 0 then
-- 		return
-- 	end
-- 	--we filter my action results out, because those will be handled in the main get/post call return
-- 	--(by addition to the main sign for results.)
-- 	local otherUserActionResults: { tt.actionResult } = {}
-- 	for _, el in ipairs(afterData.actionResults) do
-- 		--we only accept notifyAllExcept ARs.
-- 		-- this means only ones which exclude a single user.
-- 		if el.notifyAllExcept == true then
-- 			table.insert(otherUserActionResults, el)
-- 		else
-- 			table.insert(otherUserActionResults, el)
-- 		end
-- 	end

-- 	-- notify.handleActionResults(otherUserActionResults)
-- end

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
		_annotate(string.format("error making post request: %s", e))
		return
	end

	-- if false and res and not res.banned then
	-- 	task.spawn(function()
	-- 		afterRemoteDbActions(res.data)
	-- 	end)
	-- end
	_annotate(string.format("did http request, remaining = %d", httpRemaining))
	return res["res"]
end

------------------HELPER LOGICAL METHODS----------------------------

module.Init = function()
	startHttpServiceRequestManager()
end

_annotate(string.format("end"))
return module
