--!strict

-- avatarManipulation is run on the client.
-- but, these things should really be relayed to the server so other people could see them!

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local tt = require(game.ReplicatedStorage.types.gametypes)
local remotes = require(game.ReplicatedStorage.util.remotes)

-- local GenericClientUIEvent = remotes.getRemoteEvent("GenericClientUIEvent")
local GenericClientUIFunction = remotes.getRemoteFunction("GenericClientUIFunction")

module.AnchorCharacter = function(_: Humanoid, character: Model)
	local rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart

	if rootPart then
		_annotate("anchoring character. rootPart position: " .. tostring(rootPart.Position))
		rootPart.Anchored = true
		_annotate(string.format("Character root part anchored for %s", character.Name))
	else
		_annotate(
			string.format("Failed to anchor character root part for %s: HumanoidRootPart not found", character.Name)
		)
	end
	_annotate("anchoring character done. rootPart position: " .. tostring(rootPart.Position))
end

module.UnAnchorCharacter = function(_: Humanoid, character: Model)
	local rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
	if rootPart then
		_annotate("unanchor. rootPart position: " .. tostring(rootPart.Position))
		rootPart.Anchored = false
	end
	_annotate("unanchor done. rootPart position: " .. tostring(rootPart.Position))
end

local resetMomentumDebounce = false
module.ResetMomentum = function(humanoid: Humanoid, character: Model)
	if resetMomentumDebounce then
		return
	end
	resetMomentumDebounce = true
	_annotate("\t\tresetMomentum")
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)

	-- 2024: is this effectively just the server version of resetting movement states?
	local rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart

	rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

	while true do
		local state = humanoid:GetState()
		if
			state == Enum.HumanoidStateType.GettingUp
			or state == Enum.HumanoidStateType.Running
			or state == Enum.HumanoidStateType.Freefall
			or state == Enum.HumanoidStateType.Dead
			or state == Enum.HumanoidStateType.Swimming
		then
			-- _annotate("state passed")
			break
		end

		task.wait(0.1)
		_annotate("waited.in resetMomentum")
	end
	_annotate("movement:\tmomentum has been reset.")
	resetMomentumDebounce = false
end

module.ResetAbnormalMomentum = function(humanoid: Humanoid, character: Model)
	while resetMomentumDebounce do
		_annotate("waiting to reset abnormal momentum.")
		task.wait(0.1)
	end
	resetMomentumDebounce = true
	_annotate("ResetAbnormalMomentum")
	local rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
	local state = humanoid:GetState()

	-- Cancel fling-like states
	if
		state == Enum.HumanoidStateType.FallingDown
		or state == Enum.HumanoidStateType.Seated
		or state == Enum.HumanoidStateType.PlatformStanding
	then
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end

	-- we figure out what to cap their velocity at.

	local actualY = rootPart.AssemblyLinearVelocity.Y
	local maxY = 100
	if actualY > 0 then
		actualY = math.min(actualY, maxY)
	else
		actualY = math.max(actualY, -1 * maxY)
	end

	-- local horizontalVelocity = rootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	-- local actualFlat = horizontalVelocity.Unit * humanoid.WalkSpeed
	-- 	+ Vector3.new(0, rootPart.AssemblyLinearVelocity.Y, 0)
	-- if horizontalVelocity.Magnitude > 100 then
	-- 	local capped = _annotate(string.format("setting capped horizontal velocity to %0.1f", tostring(capped)))
	-- 	rootPart.AssemblyLinearVelocity = capped
	-- end

	-- _annotate(
	-- 	string.format(
	-- 		"resetAbnormalMomentum: horizontalVelocity Mag: %0.1f and walkSpeed: %0.1f",
	-- 		horizontalVelocity.Magnitude,
	-- 		humanoid.WalkSpeed
	-- 	)
	-- )
	-- -- Cap vertical velocity
	-- if math.abs(rootPart.AssemblyLinearVelocity.Y) > 100 then
	-- 	rootPart.AssemblyLinearVelocity = horizontalVelocity
	-- 		+ Vector3.new(0, math.sign(rootPart.AssemblyLinearVelocity.Y) * 100, 0)
	-- end
	resetMomentumDebounce = false
end

module.SetCharacterTransparency = function(_: Player, target: number)
	_annotate("Player made transparent: " .. tostring(target))
	local data: tt.avatarMorphData = {
		transparency = target,
		scale = nil,
	}
	local event: tt.clientToServerRemoteEventOrFunction = {
		eventKind = "avatarMorph",
		data = data,
	}

	GenericClientUIFunction:InvokeServer(event)
	_annotate("done setting character transparency")
	-- return any
end

module.ResetPhysicalAvatarMorphs = function(humanoid: Humanoid, character: Model)
	-- i suppose these don't really need to be duplicated into the signs, but that does feel good.
	_annotate("resetting physical avatar morphs")
	if character:GetAttribute("scale") ~= 1 then
		character:ScaleTo(1)
	end
	local data: tt.avatarMorphData = {
		transparency = nil,
		scale = 1,
	}
	local event: tt.clientToServerRemoteEventOrFunction = {
		eventKind = "avatarMorph",
		data = data,
	}
	local changedAnythingOnServer = GenericClientUIFunction:InvokeServer(event)
	if changedAnythingOnServer then
		_annotate(
			"client has received response from request to change avatar traints on server, and they DID do something"
		)
	else
		_annotate("client has received response from request to change avatar traints on server, but they did NOTHING")
	end

	local state = humanoid:GetState()
	if
		state == Enum.HumanoidStateType.Ragdoll
		or state == Enum.HumanoidStateType.FallingDown
		or state == Enum.HumanoidStateType.PlatformStanding
	then
		_annotate("reset state yet char is in ragdoll.")
		--this happens because there is some lag in setting state
		--this can happen after warping
		--we should ban runs from this point, but don't currently.
		humanoid:ChangeState(Enum.HumanoidStateType.Running)
	end
	_annotate("done resetting physical avatar morphs")
end

_annotate("end")
return module
