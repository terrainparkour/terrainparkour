--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local tt = require(game.ReplicatedStorage.types.gametypes)
local mt = require(game.ReplicatedStorage.avatarEventTypes)
local remotes = require(game.ReplicatedStorage.util.remotes)
local colors = require(game.ReplicatedStorage.util.colors)
local settings = require(game.ReplicatedStorage.settings)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local particleEnums = require(game.StarterPlayer.StarterPlayerScripts.particleEnums)

local AvatarEventBindableEvent: BindableEvent = remotes.getBindableEvent("AvatarEventBindableEvent")

local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer

--- GLOBALS
local emitters: { [string]: ParticleEmitter } = {}

-- the string is a composition of ev.eventType and also possibly details such as the new state etc.
-- as long as the key is unique, we good
local myDescriptors: { [string]: tt.particleDescriptor } = {}

local particlesEnabledAtAll: boolean = true
local connection: RBXScriptConnection? = nil

---START

local createParticleEmitter = function(desc: tt.particleDescriptor)
	local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	local particleEmitter: ParticleEmitter = Instance.new("ParticleEmitter")

	particleEmitter.Acceleration = desc.acceleration
	particleEmitter.Brightness = desc.brightness
	if typeof(desc.color) == "ColorSequence" then
		particleEmitter.Color = desc.color
	elseif typeof(desc.color) == "Color3" then
		particleEmitter.Color = ColorSequence.new(desc.color)
	else
		warn(string.format("Unexpected color type: %s", typeof(desc.color)))
		particleEmitter.Color = ColorSequence.new(
			Color3.new(desc.color.R, desc.color.G, desc.color.B),
			Color3.new(desc.color.R, desc.color.G, desc.color.B)
		)
	end

	particleEmitter.Drag = desc.drag
	particleEmitter.EmissionDirection = desc.emissionDirection

	particleEmitter.Lifetime = desc.lifetime
	particleEmitter.Orientation = desc.orientation
	particleEmitter.Rate = desc.rate
	particleEmitter.Rotation = desc.rotation
	if desc.shape then
		particleEmitter.Shape = desc.shape
	end
	if desc.shapeInOut then
		particleEmitter.ShapeInOut = desc.shapeInOut
	end
	if desc.shapeStyle then
		particleEmitter.ShapeStyle = desc.shapeStyle
	end
	particleEmitter.Size = desc.size
	particleEmitter.Speed = desc.speed
	particleEmitter.SpreadAngle = desc.spreadAngle
	if desc.squash then
		particleEmitter.Squash = desc.squash
	end
	if desc.texture then
		particleEmitter.Texture = desc.texture
	end
	particleEmitter.Transparency = desc.transparency
	particleEmitter.VelocityInheritance = desc.velocityInheritance
	particleEmitter.ZOffset = desc.zOffset
	particleEmitter.RotSpeed = desc.rotSpeed
	particleEmitter.Enabled = false
	particleEmitter.Parent = humanoid.RootPart
	particleEmitter.Name = desc.name .. "_PlayerParticleEmitter." .. localPlayer.Name .. "."
	emitters[desc.name] = particleEmitter
end

local function doEmit(desc: tt.particleDescriptor, particleEmitter: ParticleEmitter)
	particleEmitter.Enabled = true
	particleEmitter.Parent = localPlayer.Character.Humanoid.RootPart
	particleEmitter.Rate = desc.rate

	task.spawn(function()
		local startTime = tick()
		local duration = desc.durationMETA
		local initialRate = particleEmitter.Rate
		-- if true then
		-- 	return
		-- end
		task.wait(duration)
		-- while tick() - startTime < duration do
		-- 	local elapsedTime = tick() - startTime
		-- 	local t = elapsedTime / duration
		-- 	local newRate = initialRate * (1 - t)
		-- 	particleEmitter.Rate = newRate
		-- 	task.wait(0.1) -- Update rate every 0.1 seconds
		-- 	-- linearly decrease rate to 0 until the duration is reached.
		-- end

		particleEmitter.Rate = 0
		particleEmitter.Enabled = false
	end)
end

local getOrCreateDescriptor = function(key: string): tt.particleDescriptor
	if not myDescriptors[key] then
		myDescriptors[key] = particleEnums.getRandomParticleDescriptor(localPlayer.UserId, key)
	end
	return myDescriptors[key]
end

local eventsWeCareAbout = {
	mt.avatarEventTypes.DO_SPEED_CHANGE,

	mt.avatarEventTypes.RUN_START,
	mt.avatarEventTypes.RETOUCH_SIGN,

	-- mt.avatarEventTypes.RUN_COMPLETE,
	-- mt.avatarEventTypes.RUN_CANCEL,

	-- mt.avatarEventTypes.TOUCH_SIGN,
	-- mt.avatarEventTypes.RESET_CHARACTER,
	-- mt.avatarEventTypes.CHARACTER_ADDED,
	-- mt.avatarEventTypes.FLOOR_CHANGED,
	-- mt.avatarEventTypes.STATE_CHANGED,
	-- mt.avatarEventTypes.AVATAR_CHANGED_DIRECTION, --this happens too much, it will be a LOT.
	-- mt.avatarEventTypes.AVATAR_STARTED_MOVING,
	-- mt.avatarEventTypes.AVATAR_STOPPED_MOVING,
}

local eventIsATypeWeCareAbout = function(ev: mt.avatarEvent): boolean
	for _, value in pairs(eventsWeCareAbout) do
		if value == ev.eventType then
			return true
		end
	end
	return false
end

-- okay, so this guy monitors all character avatar events.
-- if any of them happen, we currently make a random descriptor for that event and use it to emit a particle
-- then as I am going, I'm going to keep doing this, maybe periodically resetting these. Then as I see good ones,
-- I'll pull them into the particleEnums descriptors for these keys (which are a refinement of a subset of avatarEventTypes)
-- (arguably we should extrapolate that up, but that's not generically possible so just eat the choice)
-- then later remove some of these cause it's insane.
local emitParticleForEvent = function(ev: mt.avatarEvent)
	local key: string
	if ev.eventType == mt.avatarEventTypes.DO_SPEED_CHANGE then
		if ev.details.newSpeed > ev.details.oldSpeed then
			key = "speedup"
		else
			key = "slowdown"
		end
	elseif ev.eventType == mt.avatarEventTypes.DO_JUMPPOWER_CHANGE then
		key = "jumppowerchange"
	elseif ev.eventType == mt.avatarEventTypes.AVATAR_DIED then
		key = "died"
	elseif ev.eventType == mt.avatarEventTypes.CHARACTER_ADDED then
		key = "added"
	elseif ev.eventType == mt.avatarEventTypes.RETOUCH_SIGN then
		key = "retouch"
	elseif ev.eventType == mt.avatarEventTypes.TOUCH_SIGN then
		key = "touch"
	elseif ev.eventType == mt.avatarEventTypes.RUN_COMPLETE then
		key = "runcomplete"
	elseif ev.eventType == mt.avatarEventTypes.RUN_CANCEL then
		key = "runkill"
	elseif ev.eventType == mt.avatarEventTypes.AVATAR_RESET then
		key = "reset"
	elseif ev.eventType == mt.avatarEventTypes.RUN_START then
		key = "runstart"
	elseif ev.eventType == mt.avatarEventTypes.FLOOR_CHANGED then
		key = "floorchanged"
	elseif ev.eventType == mt.avatarEventTypes.AVATAR_RESET then
		key = "reset"
	elseif ev.eventType == mt.avatarEventTypes.KEYBOARD_WALK then
		key = "keyboardwalk"
	elseif ev.eventType == mt.avatarEventTypes.AVATAR_STARTED_MOVING then
		key = "startedmoving"
	elseif ev.eventType == mt.avatarEventTypes.AVATAR_STOPPED_MOVING then
		key = "stoppedmoving"
	-- elseif ev.eventType == mt.avatarEventTypes.AVATAR_CHANGED_DIRECTION then
	-- 	key = "changeddirection"
	elseif ev.eventType == mt.avatarEventTypes.AVATAR_STARTED_MOVING then
		key = "startedmoving"
	elseif ev.eventType == mt.avatarEventTypes.AVATAR_STOPPED_MOVING then
		key = "stoppedmoving"
	elseif ev.eventType == mt.avatarEventTypes.GET_READY_FOR_WARP then
		key = "startwarp"
	elseif ev.eventType == mt.avatarEventTypes.STATE_CHANGED then
		if ev.details.newState == Enum.HumanoidStateType.FallingDown then
			key = "fallingDown"
		elseif ev.details.newState == Enum.HumanoidStateType.Ragdoll then
			key = "ragdoll"
		elseif ev.details.newState == Enum.HumanoidStateType.Jumping then
			key = "jumping"
		elseif ev.details.newState == Enum.HumanoidStateType.PlatformStanding then
			key = "platformstanding"
		elseif ev.details.newState == Enum.HumanoidStateType.Dead then
			key = "dead"
		elseif ev.details.newState == Enum.HumanoidStateType.Running then
			key = "running"
		elseif ev.details.newState == Enum.HumanoidStateType.Swimming then
			key = "swimming"
		elseif ev.details.newState == Enum.HumanoidStateType.Freefall then
			key = "freefall"
		elseif ev.details.newState == Enum.HumanoidStateType.Climbing then
			key = "climbing"
		elseif ev.details.newState == Enum.HumanoidStateType.GettingUp then
			key = "gettingup"
		elseif ev.details.newState == Enum.HumanoidStateType.Landed then
			key = "landed"
		elseif ev.details.newState == Enum.HumanoidStateType.None then
			key = "none"
		elseif ev.details.newState == Enum.HumanoidStateType.RunningNoPhysics then
			key = "runningnophysics"
		elseif ev.details.newState == Enum.HumanoidStateType.StrafingNoPhysics then
			key = "sitting"
		else
			warn("no key")
		end
	else
		warn("no ke2y")
	end

	_annotate(string.format("particles received event and using key: %s", key))

	if key == "runstart" or key == "retouch" then
		--let's just kill the other emitters momentarily shall we?
		for _, emitter in pairs(emitters) do
			emitter.Rate = 0
		end
	end

	local emitter: ParticleEmitter
	local myDescriptor: tt.particleDescriptor
	if particleEnums.ParticleDescriptors[key] then
		myDescriptor = particleEnums.ParticleDescriptors[key]
		emitter = emitters[myDescriptor.name]
		if not emitter then
			createParticleEmitter(myDescriptor)
			emitter = emitters[myDescriptor.name]
			_annotate("got normal emitter from descriptor.")
		end
	else
		--we fall through to random.
		if true then
			myDescriptor = getOrCreateDescriptor(key)
			emitter = emitters[myDescriptor.name]
			if not emitter then
				createParticleEmitter(myDescriptor)
				emitter = emitters[myDescriptor.name]
				_annotate("using random emitter.")
			end
		end
	end
	if emitter ~= nil then
		doEmit(myDescriptor, emitter)
	end
end

-- 2024: we monitor all incoming events and for ones which we care about, emit a particle.
local handleAvatarEvent = function(ev: mt.avatarEvent)
	if not eventIsATypeWeCareAbout(ev) then
		return
	end
	_annotate("handling:  " .. avatarEventFiring.DescribeEvent(ev.eventType, ev.details))
	emitParticleForEvent(ev)
end

local function handleShowParticleSettingChange(setting: tt.userSettingValue)
	_annotate("handleShowParticleSettingChange: " .. setting.name .. " " .. tostring(setting.value))

	if setting.name == settingEnums.settingNames.SHOW_PARTICLES then
		particlesEnabledAtAll = setting.value

		if particlesEnabledAtAll then
			_annotate("enabled, connecting")
			connection = AvatarEventBindableEvent.Event:Connect(handleAvatarEvent)
		else
			_annotate("disabled, disconnecting")
			for _, emitter in pairs(emitters) do
				emitter.Rate = 0
			end

			if connection then
				connection:Disconnect()
				connection = nil
			end
		end
	end
end

module.Init = function()
	_annotate("init")
	settings.RegisterFunctionToListenForSettingName(
		handleShowParticleSettingChange,
		settingEnums.settingNames.SHOW_PARTICLES
	)

	handleShowParticleSettingChange(settings.getSettingByName(settingEnums.settingNames.SHOW_PARTICLES))
	_annotate("init done")
end

_annotate("end")
return module
