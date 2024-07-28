--!strict

-- 2024.07. it just monitors everything that happens to the player on clientside and then sends
-- events to all the other monitoring player localScripts.
-- RULE: everybody local script who wants to know anything about a user's avatar movement, position, posture etc changes
-- must hook into signals sent by this.
-- Overall plan: nobody directly subscribes to user actions except this one
-- (although the racing module can accept sign clicks to cancel, and other UI / local sGui clicks)
-- everyone else just has to monitor the stream of these events to get info on what to do.
-- honestly why do I even have multiple scripts? why not just have them all "broadcast" or at least "detected" in one file?
-- as well as acted upon? This current "broadcast once, receive multiple times" approach seems good during development,
-- but will it work in practice, when there are potentially complex interactions between the scripts?  also, how efficient are bindableEvents?

--- RULES for this to make sense:
--- ALL monitoring of everything must be done here
--- nobody is allowed to monitor roblox stuff personally.
--- they can only monitor this event stream.
--- but, they can send out subsidiary events too.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local remotes = require(game.ReplicatedStorage.util.remotes)

local enums = require(game.ReplicatedStorage.util.enums)

local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local fireEvent = avatarEventFiring.FireEvent

local mt = require(game.ReplicatedStorage.avatarEventTypes)
--pick a random direction as their current vector. it will constantly change as they move, anyway.
local oldMoveDirection = Vector3.new(0, 0, 0)

--[[

FYI here are the types we are handling here:
 
export type avatarEventDetails = {
	relatedSignId: number?,
	relatedSignName: string?,
	floorMaterial: Enum.Material?, --this is either a terrain or a non-terrain, you need to check.
	newMoveDirection: Vector3?,
	oldMoveDirection: Vector3?,
	newState: Enum.HumanoidStateType?,
	oldState: Enum.HumanoidStateType?,
	warpSourceSignName: string?,
	warpDestinationSignName: string?,
	oldSpeed: number?,
	newSpeed: number?,
	oldJumpPower: number?,
	newJumpPower: number?,
}

export type avatarEvent = {
	eventType: number,
	timestamp: number,
	details: avatarEventDetails?,
}

]]

------------------ SETUP ------------------
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid: Humanoid = character:WaitForChild("Humanoid") :: Humanoid

-- humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
-- humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
-- humanoid:SetStateEnabled(Enum.HumanoidStateType.Flying, false)

------------------ FIRE INITIAL CHAR ADDED EVENT ------------------
fireEvent(mt.avatarEventTypes.CHARACTER_ADDED, {})

_annotate(string.format("detectAndSendBindableEventsForAllChanges.%s", localPlayer.Name))

---------------------- FLOOR -------------------

local lastMaterial = humanoid.FloorMaterial
humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
	local currentMaterial = humanoid.FloorMaterial
	if currentMaterial ~= lastMaterial then
		local details: mt.avatarEventDetails = {
			floorMaterial = currentMaterial,
		}

		_annotate(string.format("Floor material changed from %s to %s", lastMaterial.Name, currentMaterial.Name))
		fireEvent(mt.avatarEventTypes.FLOOR_CHANGED, details)
		lastMaterial = currentMaterial
	end
end)

local nextTouchLegalityMustBeGreaterThan = 0
local bufferTimeAfterRunUntilYouCanTouchASignAgain = 0.8

-- we implement a buffer so that if you end a race, there is a 0.8s gap
-- during which we won't send any new sign touches.
-- this is actually important, otherwise when you'd finish a run to sign X, you'd also
-- immediately end up starting a new run from it. It's more natural to touch and "end"
-- and then have the choice to do that yourself.
-- why handle it here rather than racing? unclear. The prior system was over there.
local receiveAvatarEvent = function(ev: mt.avatarEvent)
	if ev.eventType == mt.avatarEventTypes.RUN_COMPLETE then
		nextTouchLegalityMustBeGreaterThan = tick() + bufferTimeAfterRunUntilYouCanTouchASignAgain
	end
end

local AvatarEventBindableEvent: BindableEvent = remotes.getBindableEvent("AvatarEventBindableEvent")
AvatarEventBindableEvent.Event:Connect(receiveAvatarEvent)

------- FIRE TOUCH SIGN ------------------
humanoid.Touched:Connect(function(hit)
	if tick() < nextTouchLegalityMustBeGreaterThan then
		return
	end
	if hit.ClassName == "Terrain" then
		return
	elseif hit.ClassName == "SpawnLocation" then
		return
	elseif hit.ClassName == "Part" or hit.ClassName == "MeshPart" or hit.ClassName == "UnionOperation" then
		if hit.ClassName == "MeshPart" then
			if hit.Parent.ClassName ~= "Folder" then
				return
			end
			if hit.Parent.Name ~= "Signs" then
				return
			end
			--double safe.
		end

		-- god forbid i ever add a sign whose name overlaps with the name of a bodypart.
		local signId = enums.name2signId[hit.Name]

		if signId == nil then
			_annotate("weird. missing sign thing? " .. hit.Name)
			return
		end
		local details: mt.avatarEventDetails = {
			relatedSignId = signId,
			relatedSignName = hit.Name,
		}
		fireEvent(mt.avatarEventTypes.TOUCH_SIGN, details)
	end
end)

------------------ AVATAR STATES ---------------

humanoid.Died:Connect(function()
	fireEvent(mt.avatarEventTypes.DIED, {})
end)

localPlayer.CharacterRemoving:Connect(function(a0: Model)
	fireEvent(mt.avatarEventTypes.CHARACTER_REMOVING, {})
end)

-- also raycast for water. this has never been tested very thoroughly
-- but towards the end of 2022 this improved water detection quite
-- a bit by forcing the player ot swimming state more when on thin water, for example.
-- overall: the actual SWIM_ACTIVE is
local artificiallyCheckForSwimming = function(character)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: Part
	if not rootPart or not rootPart:IsA("BasePart") then
		_annotate("no rootpart.")
		return
	end
	task.spawn(function()
		local ii = 3.2
		local result: RaycastResult = nil
		local humanoid: Humanoid = character:WaitForChild("Humanoid") :: Humanoid

		while ii < 4.8 do
			local oldState = humanoid:GetState()
			if oldState == Enum.HumanoidStateType.Swimming then
				break
			end
			if not rootPart then
				break
			end
			if not rootPart.Position then
				break
			end
			result = workspace:Raycast(rootPart.Position, Vector3.new(0, -1 * ii, 0), raycastParams)

			--despite the warning, nil raycast happens all the time.  Doh.
			--and raycasting appears not to work at all anyway.

			if result and result.Material == Enum.Material.Water then
				_annotate("faking swimming changestate.")

				local det = {
					oldState = oldState,
					newState = Enum.HumanoidStateType.Swimming,
				}
				fireEvent(mt.avatarEventTypes.STATE_CHANGED, det)
				break
			end
			ii += 0.1
		end
	end)
end

-- this has a different sensitivity than the general changestate.
-- so we coerce this up to just another state changed thingie, and don't store it directly.
humanoid.Swimming:Connect(function(active)
	local currentState = humanoid:GetState()

	-- swimming just turned on
	if active then
		if currentState == Enum.HumanoidStateType.Swimming then
			--_annotate("swimming active fired but state already swimming, bailing.")
			return
		end

		-- humanoid:ChangeState(Enum.HumanoidStateType.Swimming)
		_annotate("force swimming.")
		--this should fire one right so we are picked up elsewhere?
	else --swimming just turned off
		if currentState ~= Enum.HumanoidStateType.Swimming then
			_annotate("swimming inactive fired but we are already not swimming, bailing.")
			return
		end

		_annotate(
			"swimming turned off and we awere already swimming; turn it off asap. problem is, what to turn it to?"
		)
		return
	end
end)

humanoid.StateChanged:Connect(function(old, new)
	if old == new then
		warn("repeated statechanged in the call from roblox itself?")
		return
	end

	local currentState = humanoid:GetState()
	if currentState ~= new then
		--- TODO remove this after debugging
		warn(
			string.format(
				"got state changed, but we allegedly changed from %s to %s but our state is %s",
				old.Name,
				new.Name,
				currentState.Name
			)
		)
	end

	fireEvent(mt.avatarEventTypes.STATE_CHANGED, {
		oldState = old,
		newState = new,
	})
end)

-- The Roblox property `MoveDirection` of the `Humanoid` class represents the direction the character is moving in the world.
-- It is a Vector3 that indicates the direction the character is moving, with a magnitude that indicates the speed of movement.
-- This property is updated based on the user's input, such as pressing the arrow keys or WASD keys, but it also takes into account
-- other factors like physics, animations, and constraints that might affect the character's movement.
-- Therefore, `MoveDirection` is a representation of the character's actual movement in the world, rather than the user's input intention.
-- For example, if the user presses the forward key, but the character is blocked by a wall, the `MoveDirection` will be zero, indicating no movement.
-- On the other hand, if the user presses the forward key and the character is on a slope, the `MoveDirection` will reflect the character's movement down the slope,
-- even if the user intended to move forward. This property is useful for detecting changes in the character's movement, such as starting or stopping,
-- as well as changes in direction, which can be used to trigger events or animations in the game.

humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
	--fire if they change DIRECTION
	local currentMoveDirection = humanoid.MoveDirection
	if currentMoveDirection ~= oldMoveDirection then
		fireEvent(mt.avatarEventTypes.CHANGE_DIRECTION, {
			newMoveDirection = currentMoveDirection,
			oldMoveDirection = oldMoveDirection,
		})
		oldMoveDirection = currentMoveDirection
	end
end)

----------------------- USER INPUT ----------------------

--wow this even detects mouseovers anywhere in the visible screen!
local InputChanged = function(input: InputObject, gameProcessedEvent: boolean, kind: string)
	if gameProcessedEvent then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end

	if input.KeyCode == Enum.KeyCode.LeftShift then
		local theType = input.UserInputState == Enum.UserInputState.Begin and mt.avatarEventTypes.KEYBOARD_WALK
			or mt.avatarEventTypes.KEYBOARD_RUN
		_annotate("typed, kind: " .. tostring(mt.avatarEventTypesReverse[theType]))
		fireEvent(theType)
	end
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
	InputChanged(input, gameProcessedEvent, "began input")
end)
UserInputService.InputChanged:Connect(function(input: InputObject, gameProcessedEvent: boolean)
	InputChanged(input, gameProcessedEvent, "changed input")
end)
UserInputService.InputEnded:Connect(function(input: InputObject, gameProcessedEvent: boolean)
	InputChanged(input, gameProcessedEvent, "end input")
end)

_annotate(string.format("detectAndSendBindableEventsForAllChanges.DONE.%s", localPlayer.Name))

-------- start artificial swimming check. -----------------
task.spawn(function()
	while true do
		wait(1 / 30)
		artificiallyCheckForSwimming(character)
	end
end)

_annotate("end")
return {}
