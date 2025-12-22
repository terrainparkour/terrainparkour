--!strict

-- particles.lua @ StarterPlayer.StarterCharacterScripts.client
-- Client-side particle system: emits particles in response to avatar events based on user settings.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local Players = game:GetService("Players")

local aet = require(game.ReplicatedStorage.avatarEventTypes)
local remotes = require(game.ReplicatedStorage.util.remotes)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local settings = require(game.ReplicatedStorage.settings)
local tpUtil: typeof(require(game.ReplicatedStorage.util.tpUtil)) = require(game.ReplicatedStorage.util.tpUtil)
local tt = require(game.ReplicatedStorage.types.gametypes)
local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local particleEnums = require(game.StarterPlayer.StarterPlayerScripts.particleEnums)

type Module = {
	Init: () -> (),
}

local module: Module

-- Module internals
local localPlayer: Player = Players.LocalPlayer
local AvatarEventBindableEvent: BindableEvent = remotes.getBindableEvent("AvatarEventBindableEvent")

local emitters: { [string]: ParticleEmitter } = {}
local particlesEnabledAtAll: boolean = true
local avatarEventConnection: RBXScriptConnection? = nil
local characterAddedConnection: RBXScriptConnection? = nil
local cachedCharacter: Model? = nil
local cachedHumanoid: Humanoid? = nil
local cachedRootPart: BasePart? = nil

local eventsWeCareAbout = {
	aet.avatarEventTypes.DO_SPEED_CHANGE,
	aet.avatarEventTypes.RUN_START,
	aet.avatarEventTypes.RETOUCH_SIGN,
	aet.avatarEventTypes.RUN_COMPLETE,
	aet.avatarEventTypes.RUN_CANCEL,
	aet.avatarEventTypes.AVATAR_RESET,
	aet.avatarEventTypes.AVATAR_DIED,
	aet.avatarEventTypes.GET_READY_FOR_WARP,
}

-- Sign-based particle emitters (persists during run from special signs)
-- Supports multiple emitters per sign
local signParticleEmitters: { ParticleEmitter } = {}
local activeSignParticleSourceSignId: number? = nil

-- Some signs have gameplay-relevant particles that must ignore the user's
-- SHOW_PARTICLES setting. Currently these are the 4 round signs:
-- ⊗=604, ⊕=605, ⊖=606, ⊘=607 (see `particleEnums.SignParticleDescriptors`).
local ALWAYS_ON_SIGN_PARTICLE_SIGN_IDS: { [number]: boolean } = {
	[604] = true,
	[605] = true,
	[606] = true,
	[607] = true,
}

local function isAlwaysOnSignParticleSignId(signId: number): boolean
	return ALWAYS_ON_SIGN_PARTICLE_SIGN_IDS[signId] == true
end

local eventTypeToKeyMap = {
	[aet.avatarEventTypes.DO_SPEED_CHANGE] = function(ev: aet.avatarEvent): string?
		local newSpeed = ev.details.newSpeed
		local oldSpeed = ev.details.oldSpeed
		if newSpeed and oldSpeed then
			return newSpeed > oldSpeed and "speedup" or "slowdown"
		end
		return nil
	end,
	[aet.avatarEventTypes.DO_JUMPPOWER_CHANGE] = function(): string
		return "jumppowerchange"
	end,
	[aet.avatarEventTypes.AVATAR_DIED] = function(): string
		return "died"
	end,
	[aet.avatarEventTypes.CHARACTER_ADDED] = function(): string
		return "added"
	end,
	[aet.avatarEventTypes.RETOUCH_SIGN] = function(): string
		return "retouch"
	end,
	[aet.avatarEventTypes.TOUCH_SIGN] = function(): string
		return "touch"
	end,
	[aet.avatarEventTypes.RUN_COMPLETE] = function(): string
		return "runcomplete"
	end,
	[aet.avatarEventTypes.RUN_CANCEL] = function(): string
		return "runkill"
	end,
	[aet.avatarEventTypes.AVATAR_RESET] = function(): string
		return "reset"
	end,
	[aet.avatarEventTypes.RUN_START] = function(): string
		return "runstart"
	end,
	[aet.avatarEventTypes.FLOOR_CHANGED] = function(): string
		return "floorchanged"
	end,
	[aet.avatarEventTypes.KEYBOARD_WALK] = function(): string
		return "keyboardwalk"
	end,
	[aet.avatarEventTypes.AVATAR_STARTED_MOVING] = function(): string
		return "startedmoving"
	end,
	[aet.avatarEventTypes.AVATAR_STOPPED_MOVING] = function(): string
		return "stoppedmoving"
	end,
	[aet.avatarEventTypes.GET_READY_FOR_WARP] = function(): string
		return "startwarp"
	end,
	[aet.avatarEventTypes.STATE_CHANGED] = function(ev: aet.avatarEvent): string?
		local newState = ev.details.newState
		if not newState then
			return nil
		end
		local stateMap = {
			[Enum.HumanoidStateType.FallingDown] = "fallingDown",
			[Enum.HumanoidStateType.Ragdoll] = "ragdoll",
			[Enum.HumanoidStateType.Jumping] = "jumping",
			[Enum.HumanoidStateType.PlatformStanding] = "platformstanding",
			[Enum.HumanoidStateType.Dead] = "dead",
			[Enum.HumanoidStateType.Running] = "running",
			[Enum.HumanoidStateType.Swimming] = "swimming",
			[Enum.HumanoidStateType.Freefall] = "freefall",
			[Enum.HumanoidStateType.Climbing] = "climbing",
			[Enum.HumanoidStateType.GettingUp] = "gettingup",
			[Enum.HumanoidStateType.Landed] = "landed",
			[Enum.HumanoidStateType.None] = "none",
			[Enum.HumanoidStateType.RunningNoPhysics] = "runningnophysics",
			[Enum.HumanoidStateType.StrafingNoPhysics] = "sitting",
		}
		return stateMap[newState]
	end,
}

local function updateCharacterCache()
	cachedCharacter = localPlayer.Character
	if cachedCharacter then
		cachedHumanoid = cachedCharacter:FindFirstChildOfClass("Humanoid")
		if cachedHumanoid then
			cachedRootPart = cachedHumanoid.RootPart
		end
	end
end

local function createParticleEmitter(desc: tt.particleDescriptor)
	if not cachedRootPart then
		updateCharacterCache()
		if not cachedRootPart then
			warn("Cannot create particle emitter without character root part")
			return
		end
	end

	local particleEmitter = Instance.new("ParticleEmitter")
	particleEmitter.Acceleration = desc.acceleration
	particleEmitter.Brightness = desc.brightness

	if typeof(desc.color) == "ColorSequence" then
		particleEmitter.Color = desc.color
	elseif typeof(desc.color) == "Color3" then
		particleEmitter.Color = ColorSequence.new(desc.color)
	else
		warn(string.format("Unexpected color type: %s", typeof(desc.color)))
		particleEmitter.Color = ColorSequence.new(Color3.new(desc.color.R, desc.color.G, desc.color.B), Color3.new(desc.color.R, desc.color.G, desc.color.B))
	end

	particleEmitter.Drag = desc.drag
	particleEmitter.EmissionDirection = desc.emissionDirection
	particleEmitter.Lifetime = desc.lifetime
	particleEmitter.Orientation = desc.orientation
	particleEmitter.Rate = desc.rate
	particleEmitter.Rotation = desc.rotation
	particleEmitter.Size = desc.size
	particleEmitter.Speed = desc.speed
	particleEmitter.SpreadAngle = desc.spreadAngle
	particleEmitter.Transparency = desc.transparency
	particleEmitter.VelocityInheritance = desc.velocityInheritance
	particleEmitter.ZOffset = desc.zOffset
	particleEmitter.RotSpeed = desc.rotSpeed
	particleEmitter.Enabled = false

	if desc.shape then
		particleEmitter.Shape = desc.shape
	end
	if desc.shapeInOut then
		particleEmitter.ShapeInOut = desc.shapeInOut
	end
	if desc.shapeStyle then
		particleEmitter.ShapeStyle = desc.shapeStyle
	end
	if desc.squash then
		particleEmitter.Squash = desc.squash
	end
	if desc.texture then
		particleEmitter.Texture = desc.texture
	end

	particleEmitter.Name = desc.name .. "_PlayerParticleEmitter." .. localPlayer.Name .. "."
	particleEmitter.Parent = cachedRootPart
	emitters[desc.name] = particleEmitter
end

local function doEmit(desc: tt.particleDescriptor, emitter: ParticleEmitter, ev: aet.avatarEvent)
	if not cachedRootPart then
		updateCharacterCache()
		if not cachedRootPart then
			return
		end
	end

	emitter.Enabled = true
	emitter.Parent = cachedRootPart

	if ev.eventType == aet.avatarEventTypes.DO_SPEED_CHANGE then
		local newSpeed = ev.details.newSpeed
		local oldSpeed = ev.details.oldSpeed
		if not newSpeed or not oldSpeed then
			return
		end
		local speedChange = math.abs(newSpeed - oldSpeed)
		local mult = 650
		local usingNewRate = speedChange * mult
		emitter.Rate = usingNewRate

		task.spawn(function()
			task.wait(desc.durationMETA)
			emitter.Rate = 0
		end)
	elseif desc.name == "retouch" or desc.name == "runstart" or desc.name == "runcomplete" then
		local signId: number?
		if desc.name == "retouch" or desc.name == "runstart" then
			signId = ev.details.startSignId
		elseif desc.name == "runcomplete" then
			signId = ev.details.endSignId
		end

		if not signId then
			return
		end

		local sign = tpUtil.signId2Sign(signId)
		if not sign then
			return
		end

		local exactPos = ev.details.exactPositionOfHit
		if not exactPos then
			return
		end

		local attachmentName = "attachmentEmitter_" .. desc.name .. "_" .. sign.Name
		local existingAttachment = sign:FindFirstChild(attachmentName)
		local attachment: Attachment

		if existingAttachment and existingAttachment:IsA("Attachment") then
			attachment = existingAttachment
		else
			attachment = Instance.new("Attachment")
			attachment.Parent = sign
			attachment.Visible = false
			attachment.Name = attachmentName
		end

		_annotate(string.format("assigned emitter %s to sign for %s at %s", attachmentName, sign.Name, tostring(attachment.Position)))
		attachment.Position = sign.CFrame:PointToObjectSpace(exactPos)
		emitter.Parent = attachment
		emitter.Shape = Enum.ParticleEmitterShape.Box
		emitter.Rate = desc.rate
		emitter.Enabled = true

		task.spawn(function()
			task.wait(desc.durationMETA)
			emitter.Rate -= desc.rate
			emitter.Rate = math.max(0, emitter.Rate)
		end)
	else
		local usingNewRate2 = desc.rate
		emitter.Rate += usingNewRate2
		task.spawn(function()
			task.wait(desc.durationMETA)
			emitter.Rate -= usingNewRate2
			emitter.Rate = math.max(0, emitter.Rate)
		end)
	end
end

local SIGN_PARTICLE_FADE_TIME = 10

local function destroySignParticleEmitters()
	if #signParticleEmitters == 0 then
		activeSignParticleSourceSignId = nil
		return
	end

	-- Stop emitting but keep emitters alive for fade-out
	local emittersToDestroy = signParticleEmitters
	for _, emitter in ipairs(emittersToDestroy) do
		emitter.Enabled = false
		emitter.Rate = 0
	end
	_annotate(string.format("Sign particle emitters stopped, fading for %ds", SIGN_PARTICLE_FADE_TIME))

	-- Clear the tracking immediately so new runs can create new emitters
	signParticleEmitters = {}
	activeSignParticleSourceSignId = nil

	-- Destroy after fade time
	task.delay(SIGN_PARTICLE_FADE_TIME, function()
		for _, emitter in ipairs(emittersToDestroy) do
			if emitter and emitter.Parent then
				emitter:Destroy()
			end
		end
		_annotate("Sign particle emitters destroyed after fade")
	end)
end

local function createSignParticleEmitters(signId: number)
	if not cachedRootPart then
		updateCharacterCache()
		if not cachedRootPart then
			warn("Cannot create sign particle emitters: no root part")
			return
		end
	end

	local descriptors = particleEnums.SignParticleDescriptors[signId]
	if not descriptors then
		return
	end

	-- Destroy any existing sign particle emitters
	destroySignParticleEmitters()
	activeSignParticleSourceSignId = signId

	for _, desc in ipairs(descriptors) do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = desc.name
		emitter.Acceleration = desc.acceleration
		emitter.Brightness = desc.brightness
		if typeof(desc.color) == "ColorSequence" then
			emitter.Color = desc.color
		elseif typeof(desc.color) == "Color3" then
			emitter.Color = ColorSequence.new(desc.color)
		end
		emitter.Drag = desc.drag
		emitter.EmissionDirection = desc.emissionDirection
		emitter.Lifetime = desc.lifetime
		emitter.Orientation = desc.orientation
		emitter.Rate = desc.rate
		emitter.Rotation = desc.rotation
		emitter.Size = desc.size
		emitter.Speed = desc.speed
		emitter.SpreadAngle = desc.spreadAngle
		emitter.Transparency = desc.transparency
		emitter.VelocityInheritance = desc.velocityInheritance
		emitter.ZOffset = desc.zOffset
		emitter.RotSpeed = desc.rotSpeed
		emitter.LightEmission = desc.lightEmission or 0
		if desc.shape then
			emitter.Shape = desc.shape
		end
		if desc.shapeInOut then
			emitter.ShapeInOut = desc.shapeInOut
		end
		if desc.shapeStyle then
			emitter.ShapeStyle = desc.shapeStyle
		end
		if desc.squash then
			emitter.Squash = desc.squash
		end
		if desc.texture then
			emitter.Texture = desc.texture
		end

		emitter.Enabled = true
		emitter.Parent = cachedRootPart
		table.insert(signParticleEmitters, emitter)
	end

	_annotate(string.format("Created %d sign particle emitters for signId %d", #descriptors, signId))
end

local function handleSignParticleEvent(ev: aet.avatarEvent)
	local eventType = ev.eventType

	if eventType == aet.avatarEventTypes.RUN_START then
		local startSignId = ev.details.startSignId
		if not startSignId then
			return
		end

		-- If the player has disabled particles, only allow "always on" sign particles.
		if not particlesEnabledAtAll and not isAlwaysOnSignParticleSignId(startSignId) then
			return
		end

		if particleEnums.SignParticleDescriptors[startSignId] then
			createSignParticleEmitters(startSignId)
		end
	elseif eventType == aet.avatarEventTypes.RETOUCH_SIGN then
		-- Keep existing emitters, do nothing
	elseif eventType == aet.avatarEventTypes.RUN_COMPLETE or eventType == aet.avatarEventTypes.RUN_CANCEL or eventType == aet.avatarEventTypes.AVATAR_RESET or eventType == aet.avatarEventTypes.AVATAR_DIED or eventType == aet.avatarEventTypes.GET_READY_FOR_WARP then
		destroySignParticleEmitters()
	end
end

local function shouldProcessAnyParticlesForEvent(ev: aet.avatarEvent): boolean
	if particlesEnabledAtAll then
		return true
	end

	-- When particles are disabled, we still need to:
	-- - Create sign particles for "always on" signs on RUN_START
	-- - Destroy active sign particles on end/run-cancel/reset/death/warp events
	if ev.eventType == aet.avatarEventTypes.RUN_START then
		local startSignId = ev.details.startSignId
		return startSignId ~= nil and isAlwaysOnSignParticleSignId(startSignId)
	end

	if #signParticleEmitters > 0 and activeSignParticleSourceSignId ~= nil then
		-- We're in a run with sign particles active; we must keep handling lifecycle.
		return true
	end

	return false
end

local function emitParticleForEvent(ev: aet.avatarEvent)
	local keyFunc = eventTypeToKeyMap[ev.eventType]
	if not keyFunc then
		return
	end

	local key = keyFunc(ev)
	if not key then
		return
	end

	-- Only emit particles for events that have defined descriptors.
	-- Events like RUN_CANCEL, GET_READY_FOR_WARP etc. are in eventsWeCareAbout
	-- for sign particle lifecycle management, but shouldn't emit their own particles.
	local myDescriptor = particleEnums.ParticleDescriptors[key]
	if not myDescriptor then
		return
	end

	_annotate(string.format("particles received event and using key: %s", key))

	if key == "runstart" or key == "retouch" then
		for _, emitter in pairs(emitters) do
			emitter.Rate = 0
		end
	end

	local emitter = emitters[myDescriptor.name]
	if not emitter then
		createParticleEmitter(myDescriptor)
		emitter = emitters[myDescriptor.name]
	end

	if emitter then
		doEmit(myDescriptor, emitter, ev)
	end
end

local function handleAvatarEvent(ev: aet.avatarEvent)
	if not avatarEventFiring.EventIsATypeWeCareAbout(ev, eventsWeCareAbout) then
		return
	end

	if not shouldProcessAnyParticlesForEvent(ev) then
		return
	end

	_annotate("handling:  " .. avatarEventFiring.DescribeEvent(ev))

	-- Handle sign-based persistent particles
	handleSignParticleEvent(ev)

	-- Normal particles obey the user's SHOW_PARTICLES setting.
	if particlesEnabledAtAll then
		emitParticleForEvent(ev)
	end
end

local function handleShowParticleSettingChange(setting: tt.userSettingValue)
	_annotate("handleShowParticleSettingChange: " .. (setting and setting.name or "nil") .. " " .. tostring(setting and setting.booleanValue or "nil"))

	if setting and setting.name == settingEnums.settingDefinitions.SHOW_PARTICLES.name then
		particlesEnabledAtAll = if setting.booleanValue ~= nil then setting.booleanValue else true

		if particlesEnabledAtAll then
			_annotate("enabled")
		else
			_annotate("disabled (sign particles may still run for always-on signs)")

			-- Stop any non-sign emitters immediately.
			for _, emitter in pairs(emitters) do
				emitter.Rate = 0
			end

			-- If we're currently emitting sign particles from a non-always-on sign,
			-- shut those down too. (Always-on sign particles must continue.)
			if activeSignParticleSourceSignId ~= nil and not isAlwaysOnSignParticleSignId(activeSignParticleSourceSignId) then
				destroySignParticleEmitters()
			end
		end
	end
	return
end

local function ensureCharacterLifecycleHooks()
	if characterAddedConnection then
		return
	end
	characterAddedConnection = localPlayer.CharacterAdded:Connect(function()
		_annotate("Player.CharacterAdded received; re-initting particles")
		module.Init()
	end)
end

module = {
	Init = function()
		_annotate("init")

		ensureCharacterLifecycleHooks()

		annotater.Profile("particles.updateCharacterCache", function()
			updateCharacterCache()
		end)

		annotater.Profile("particles.CharacterAdded:Connect", function()
			localPlayer.CharacterAdded:Connect(updateCharacterCache)
		end)

		annotater.Profile("particles.RegisterFunctionToListenForSettingName", function()
			settings.RegisterFunctionToListenForSettingName(handleShowParticleSettingChange, settingEnums.settingDefinitions.SHOW_PARTICLES.name, "particles")
		end)

		-- Always listen for avatar events so we can run sign particle lifecycle even when the
		-- user disables particles (some sign effects are intentionally always-on).
		if avatarEventConnection then
			avatarEventConnection:Disconnect()
			avatarEventConnection = nil
		end
		avatarEventConnection = AvatarEventBindableEvent.Event:Connect(handleAvatarEvent)

		annotater.Profile("particles.GetSettingByName", function()
			handleShowParticleSettingChange(settings.GetSettingByName(settingEnums.settingDefinitions.SHOW_PARTICLES.name))
		end)

		_annotate("init done")
	end,
}

_annotate("end")
return module

--[[
================================================================================
PRODUCT SPEC: Round sign run particles ignore "show particles"
================================================================================

Requirement:
- The 4 round signs (⊗=604, ⊕=605, ⊖=606, ⊘=607) emit particles during runs
  that originate from them.
- This sign-based particle effect MUST ignore the user's SHOW_PARTICLES setting.

Scope:
- Only the sign-based persistent particle system (SignParticleDescriptors) bypasses
  the setting, and only for the sign IDs listed above.
- All other particle effects continue to obey SHOW_PARTICLES.
================================================================================
]]

--[[
================================================================================
PRODUCT SPEC: v412 Server-Side Particle Broadcasting
================================================================================

STATUS: Not yet implemented

GOAL: Other players should see particle effects (run start, run complete, 
retouch sparkles) from nearby players.

CURRENT STATE:
- This file is entirely client-side
- Uses local BindableEvents (AvatarEventBindableEvent)
- Only the local player sees their own particles
- particleDescriptor type exists in gametypes.lua

ARCHITECTURE (Option 2 - chosen):
1. Client fires RemoteEvent to server when emitting particles
2. Server validates the request
3. Server broadcasts to other clients in range
4. Receiving clients create local ParticleEmitters on source player's character

IMPLEMENTATION NOTES:
- Add SHOW_OTHER_PLAYER_PARTICLES user setting (settingEnums.lua)
- Reuse existing particleDescriptor type from gametypes.lua
- Only broadcast significant events: RUN_START, RUN_COMPLETE, RETOUCH_SIGN
- Consider range limiting to avoid network spam

RELATED FILES:
- gametypes.lua (particleDescriptor type)
- settingEnums.lua (new setting needed)
- Server script needed (new file)
- remotes.lua (new RemoteEvent needed)

See also: docs/TODO.md
================================================================================
]]
