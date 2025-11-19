--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local refolder: Folder = ReplicatedStorage:WaitForChild("RemoteEvents") :: Folder
local rffolder: Folder = ReplicatedStorage:WaitForChild("RemoteFunctions") :: Folder
local befolder: Folder = ReplicatedStorage:WaitForChild("BindableEvents") :: Folder

local module = {}

local debounce = false
local _holder = ""

--problem: this is not shared between client and server.
local function getDebounce(name: string)
	if debounce then
		while debounce do
			task.wait(0.1)
		end
	else
	end
	_holder = name
	debounce = true
end

local done = function(name: string)
	_holder = ""
	debounce = false
end

local registerRemoteEvent = function(name: string): RemoteEvent
	if name:sub(-5) ~= "Event" then
		error("bad remote event name. " .. name)
	end

	local exiInstance: Instance? = refolder:FindFirstChild(name)
	local exi: RemoteEvent? = if exiInstance and exiInstance:IsA("RemoteEvent") then exiInstance :: RemoteEvent else nil
	if not exi then
		local re = Instance.new("RemoteEvent")
		re.Name = name
		re.Parent = refolder
		done("exi" .. name)
		return re
	end
	done("new " .. name)
	return exi :: RemoteEvent
end

local registerRemoteFunction = function(name: string): RemoteFunction
	if name:sub(-8) ~= "Function" then
		error("bad remote Function name. " .. name)
	end

	local exiInstance: Instance? = rffolder:FindFirstChild(name)
	local exi: RemoteFunction? = if exiInstance and exiInstance:IsA("RemoteFunction") then exiInstance :: RemoteFunction else nil
	if not exi then
		local remotes = Instance.new("RemoteFunction")
		remotes.Name = name
		remotes.Parent = rffolder
		done("exi" .. name)
		return remotes
	end
	done("new " .. name)
	return exi :: RemoteFunction
end

local registerBindableEvent = function(name: string): BindableEvent
	if name:sub(-13) ~= "BindableEvent" then
		error("bad bindable event name. " .. name)
	end

	local exiInstance: Instance? = befolder:FindFirstChild(name)
	local exi: BindableEvent? = if exiInstance and exiInstance:IsA("BindableEvent") then exiInstance :: BindableEvent else nil
	if not exi then
		local be = Instance.new("BindableEvent")
		be.Name = name
		be.Parent = befolder
		done("exi" .. name)
		return be
	end
	done("new " .. name)
	return exi :: BindableEvent
end

module.getRemoteEvent = function(name: string): RemoteEvent
	getDebounce("get " .. name)
	if name:sub(-5) ~= "Event" then
		error("bad remote event name. " .. name)
	end

	local exiInstance: Instance? = refolder:FindFirstChild(name)
	local exi: RemoteEvent? = if exiInstance and exiInstance:IsA("RemoteEvent") then exiInstance :: RemoteEvent else nil
	if not exi then
		return registerRemoteEvent(name)
	end
	done(name)
	return exi :: RemoteEvent
end

module.getRemoteFunction = function(name: string): RemoteFunction
	getDebounce("get " .. name)
	if name:sub(-8) ~= "Function" then
		error("bad remote Function name. " .. name)
	end

	local exiInstance: Instance? = rffolder:FindFirstChild(name)
	local exi: RemoteFunction? = if exiInstance and exiInstance:IsA("RemoteFunction") then exiInstance :: RemoteFunction else nil
	if not exi then
		return registerRemoteFunction(name)
	end
	done(name)
	return exi :: RemoteFunction
end

module.getBindableEvent = function(name: string): BindableEvent
	if name:sub(-13) ~= "BindableEvent" then
		error("bad remote event name. " .. name)
	end
	getDebounce("get " .. name)
	local exiInstance: Instance? = befolder:FindFirstChild(name)
	local exi: BindableEvent? = if exiInstance and exiInstance:IsA("BindableEvent") then exiInstance :: BindableEvent else nil
	if not exi then
		return registerBindableEvent(name)
	end
	done(name)
	return exi :: BindableEvent
end

return module
