--!strict

--eval 9.24.22
--will be required by various localscripts
--2023.03 loaded on client, receives and handles warps which are initiated by the server.

local annotationStart = tick()
local doAnnotation = true
local localPlayer = game.Players.LocalPlayer

local function annotate(s: string)
	if doAnnotation then
		if typeof(s) == "string" then
			print("warperClient: " .. string.format("%.1fs ", tick() - annotationStart) .. "text:" .. s)
		else
			print("warperClient.object: " .. string.format("%.1f ", tick() - annotationStart) .. " : " .. tostring(s))
			print(s)
		end
	end
end

local module = {}

local remotes = require(game.ReplicatedStorage.util.remotes)
local warpStartingBindableEvent = remotes.getBindableEvent("warpStartingBindableEvent")
local warpDoneBindableEvent = remotes.getBindableEvent("warpDoneBindableEvent")

local warpRequestFunction = remotes.getRemoteFunction("warpRequestFunction")
local serverWantsWarpFunction = remotes.getRemoteFunction("serverWantsWarpFunction")
local highlighting = require(game.StarterPlayer.StarterPlayerScripts.util.highlightingClient)

local isWarpingBlocked = false

--call other local deps registered methods, mark use runable to warp, warp from server, then unlock deps and mark free
--signid 0 means just cancel race, don't actually warp, that will be done on server.
-- could it be like this: client initiates, server starts process. server then puts user into blocked state.
--
module.requestWarpToSign = function(signId: number, highlightSignId: number?): boolean
	annotate("requestWarpToSign.")
	if isWarpingBlocked then
		annotate("fail cause warping blocked.")
		return false
	end
	highlighting.doHighlight(signId)
	isWarpingBlocked = true
	annotate("set warping blocked.")

	--tell everyone who cares that warping is happening now.
	warpStartingBindableEvent:Fire("requesting warp to sign.")

	--we block on the server returning from this function call.
	annotate("warpRequestFunction:InvokeServer")
	local succeededInWarp = warpRequestFunction:InvokeServer(signId)
	annotate("warpRequestFunction:InvokeServer.done with reqsult:" .. tostring(succeededInWarp))
	--i don't get why we go back and forth here at all.
	--what is even the intended patter?
	---action starts on the client? have to think about this?

	if succeededInWarp then
		if highlightSignId then
			highlighting.doHighlight(signId)
		end
		print("client side warp success")
	else
		print("client side warp failed")
	end
	--when we return, we are done.

	warpDoneBindableEvent:Fire()
	isWarpingBlocked = false
	annotate("unblocking warping.")
end

--external callers can use this to find out if the player is in an illegal state - already warping or not allowed to warp?
--wait which one is it?
module.isAlreadyWarping = function()
	annotate("isAlreadyWarping check: ." .. tostring(isWarpingBlocked))
	return isWarpingBlocked
end

--when the server wants me to warp, do the normal warp locking.
serverWantsWarpFunction.OnClientInvoke = function(signId: number): any
	annotate("received serverWants:")
	module.requestWarpToSign(signId, signId)
	annotate("received serverWants-done:")
end

module.init = function()
	--what are the rules of warping? This script is run once per player.
	localPlayer.CharacterAdded:Connect(function(char)
		---first : when they die, block warping.
		local humanoid = char:WaitForChild("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			isWarpingBlocked = true
		end)
		--every time I reset, I can warp again.
		isWarpingBlocked = false
	end)

	localPlayer.CharacterRemoving:Connect(function()
		--second, when they are leaving, block warping.
		isWarpingBlocked = true
	end)
end

return module
