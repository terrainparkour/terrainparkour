--!strict

--eval 9.24.22
--will be required by various localscripts

local module = {}

local rf = require(game.ReplicatedStorage.util.remotes)
local warpRequestFunction = rf.getRemoteFunction("WarpRequestFunction")
local serverWantsWarpFunction = rf.getRemoteFunction("ServerWantsWarpFunction")

local warpStartCallbacks = {}
local warpEndCallbacks = {}

--userscoped
local innerIsWarping = false

module.addCallbackToWarpStart = function(cb: (any) -> any)
	table.insert(warpStartCallbacks, cb)
end

module.addCallbackToWarpEnd = function(cb: (any) -> any)
	table.insert(warpEndCallbacks, cb)
end

module.blockWarping = function(msg: string)
	-- print("blocking warping."..msg)
	innerIsWarping = true
end

module.unblockWarping = function(msg: string)
	-- print("unblocking warping."..msg)
	innerIsWarping = false
end

--call other local deps registered methods, mark use runable to warp, warp from server, then unlock deps and mark free
--signid 0 means just cancel race, don't actually warp, that will be done on server.
module.requestWarpToSign = function(signId: number)
	innerIsWarping = true
	for _, cb in ipairs(warpStartCallbacks) do
		cb()
	end

	warpRequestFunction:InvokeServer(signId)

	for _, cb in ipairs(warpEndCallbacks) do
		cb()
	end
	innerIsWarping = false
end

module.isWarping = function()
	return innerIsWarping
end

--when the server wants me to warp, do the normal warp locking.
serverWantsWarpFunction.OnClientInvoke = function(signId: number): any
	module.requestWarpToSign(signId)
end

return module
