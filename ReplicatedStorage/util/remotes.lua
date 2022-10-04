--!strict

--eval 9.21

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local module = {}

module.registerRemoteFunction = function(name: string)
	if name:sub(-8) ~= "Function" then
		error("bad remote Function name. " .. name)
	end
	local rffolder: RemoteFunction = ReplicatedStorage:WaitForChild("RemoteFunctions")
	local exi = rffolder:FindFirstChild(name)
	if exi == nil then
		local rf = Instance.new("RemoteFunction")
		rf.Name = name
		rf.Parent = rffolder
	end
end

module.getRemoteFunction = function(name: string): RemoteFunction
	if name:sub(-8) ~= "Function" then
		error("bad remote Function name. " .. name)
	end
	local rffolder: Folder = ReplicatedStorage:WaitForChild("RemoteFunctions")
	local exi = rffolder:FindFirstChild(name)
	if exi == nil then
		error("no such remote function: " .. name)
	end

	return exi :: RemoteFunction
end

--seems to work better than the prior method
--todo convert everything.
module.registerRemoteEvent = function(name: string)
	if name:sub(-5) ~= "Event" then
		error("bad remote event name. " .. name)
	end
	local refolder: RemoteFunction = ReplicatedStorage:WaitForChild("RemoteEvents")
	local exi = refolder:FindFirstChild(name)
	if exi == nil then
		local rf = Instance.new("RemoteEvent")
		rf.Name = name
		rf.Parent = refolder
	end
end

module.getRemoteEvent = function(name: string): RemoteEvent
	if name:sub(-5) ~= "Event" then
		error("bad remote event name. " .. name)
	end
	local refolder: Folder = ReplicatedStorage:WaitForChild("RemoteEvents")
	local exi = refolder:FindFirstChild(name)
	if exi == nil then
		error("No such event.")
	end
	return exi :: RemoteEvent
end

return module
