--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local refolder: Folder = ReplicatedStorage:WaitForChild("RemoteEvents")
local rffolder: RemoteFunction = ReplicatedStorage:WaitForChild("RemoteFunctions")
local befolder: Folder = ReplicatedStorage:WaitForChild("BindableEvents")

local module = {}

local debounce = false
local holder = ""

--problem: this is not shared between client and server.
local function getDebounce(name: string)
	if debounce then
		while debounce do
			task.wait(0.1)
		end
	else
	end
	holder = name
	debounce = true
end

local done = function(name: string)
	holder = ""
	debounce = false
end

local registerRemoteEvent = function(name: string): RemoteEvent
	if name:sub(-5) ~= "Event" then
		error("bad remote event name. " .. name)
	end

	local exi: RemoteEvent = refolder:FindFirstChild(name) :: RemoteEvent
	if exi == nil then
		local re = Instance.new("RemoteEvent")
		re.Name = name
		re.Parent = refolder
		done("exi" .. name)
		return re
	end
	done("new " .. name)
	return exi
end

local registerRemoteFunction = function(name: string): RemoteFunction
	if name:sub(-8) ~= "Function" then
		error("bad remote Function name. " .. name)
	end

	local exi: RemoteFunction = rffolder:FindFirstChild(name) :: RemoteFunction
	if exi == nil then
		local remotes = Instance.new("RemoteFunction")
		remotes.Name = name
		remotes.Parent = rffolder
		done("exi" .. name)
		return remotes
	end
	done("new " .. name)
	return exi
end

local registerBindableEvent = function(name: string): BindableEvent
	if name:sub(-13) ~= "BindableEvent" then
		error("bad bindable event name. " .. name)
	end

	local exi: BindableEvent = befolder:FindFirstChild(name) :: BindableEvent
	if exi == nil then
		local be = Instance.new("BindableEvent")
		be.Name = name
		be.Parent = befolder
		done("exi" .. name)
		return be
	end
	done("new " .. name)
	return exi
end

module.getRemoteEvent = function(name: string): RemoteEvent
	getDebounce("get " .. name)
	if name:sub(-5) ~= "Event" then
		error("bad remote event name. " .. name)
	end

	local exi = refolder:FindFirstChild(name) :: RemoteEvent
	if exi == nil then
		return registerRemoteEvent(name)
	end
	done(name)
	return exi
end

module.getRemoteFunction = function(name: string): RemoteFunction
	getDebounce("get " .. name)
	if name:sub(-8) ~= "Function" then
		error("bad remote Function name. " .. name)
	end

	local exi: RemoteFunction = rffolder:FindFirstChild(name) :: RemoteFunction
	if exi == nil then
		return registerRemoteFunction(name)
	end
	done(name)
	return exi
end

module.getBindableEvent = function(name: string): BindableEvent
	if name:sub(-13) ~= "BindableEvent" then
		error("bad remote event name. " .. name)
	end
	getDebounce("get " .. name)
	local exi = befolder:FindFirstChild(name) :: BindableEvent
	if exi == nil then
		return registerBindableEvent(name)
	end
	done(name)
	return exi
end

return module
