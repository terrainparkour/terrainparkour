--!strict

--eval 9.21
local vscdebug = require(game.ReplicatedStorage.vscdebug)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local module = {}

module.registerRemoteFunction = function(name: string): RemoteFunction
	if name:sub(-8) ~= "Function" then
		error("bad remote Function name. " .. name)
	end
	local rffolder: RemoteFunction = ReplicatedStorage:WaitForChild("RemoteFunctions")
	local exi: RemoteFunction = rffolder:FindFirstChild(name) :: RemoteFunction
	if exi == nil then
		local rf = Instance.new("RemoteFunction")
		rf.Name = name
		rf.Parent = rffolder
		return rf
	end
	return exi
end

module.getRemoteFunction = function(name: string): RemoteFunction
	if name:sub(-8) ~= "Function" then
		error("bad remote Function name. " .. name)
	end
	local rffolder: Folder = ReplicatedStorage:WaitForChild("RemoteFunctions")
	local exi: RemoteFunction = rffolder:FindFirstChild(name) :: RemoteFunction
	if exi == nil then
		error("no such remote function: " .. name)
	end

	return exi
end

--seems to work better than the prior method
--todo convert everything.
module.registerRemoteEvent = function(name: string): RemoteEvent
	if name:sub(-5) ~= "Event" then
		error("bad remote event name. " .. name)
	end
	local refolder: Folder = ReplicatedStorage:WaitForChild("RemoteEvents")

	local exi: RemoteEvent = refolder:FindFirstChild(name) :: RemoteEvent
	if exi == nil then
		local re = Instance.new("RemoteEvent")
		re.Name = name
		re.Parent = refolder
		return re
	end
	return exi
end

module.getRemoteEvent = function(name: string): RemoteEvent
	if name:sub(-5) ~= "Event" then
		error("bad remote event name. " .. name)
	end
	local refolder: Folder = ReplicatedStorage:WaitForChild("RemoteEvents")
	local exi = refolder:FindFirstChild(name) :: RemoteEvent
	if exi == nil then
		error("No such event.")
	end
	return exi
end

module.registerBindableEvent = function(name: string): BindableEvent
	if name:sub(-13) ~= "BindableEvent" then
		error("bad bindable event name. " .. name)
	end
	local befolder: Folder = ReplicatedStorage:WaitForChild("BindableEvents")
	local exi: BindableEvent = befolder:FindFirstChild(name) :: BindableEvent
	if exi == nil then
		local be = Instance.new("BindableEvent")
		be.Name = name
		be.Parent = befolder
		return be
	end
	return exi
end

module.getBindableEvent = function(name: string): BindableEvent
	if name:sub(-13) ~= "BindableEvent" then
		error("bad remote event name. " .. name)
	end
	local refolder: Folder = ReplicatedStorage:WaitForChild("BindableEvents")
	local exi = refolder:FindFirstChild(name) :: BindableEvent
	if exi == nil then
		error("No such event.")
	end
	return exi
end

return module
