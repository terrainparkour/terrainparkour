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
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local tt = require(game.ReplicatedStorage.types.gametypes)
local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local particleEnums = require(game.StarterPlayer.StarterPlayerScripts.particleEnums)

type Module = {
	Init: () -> (),
}

-- Module internals
local localPlayer: Player = Players.LocalPlayer
local AvatarEventBindableEvent: BindableEvent = remotes.getBindableEvent("AvatarEventBindableEvent")

local emitters: { [string]: ParticleEmitter } = {}
local myDescriptors: { [string]: tt.particleDescriptor } = {}
local particlesEnabledAtAll: boolean = true
local avatarEventConnection: RBXScriptConnection? = nil
local cachedCharacter: Model? = nil
local cachedHumanoid: Humanoid? = nil
local cachedRootPart: BasePart? = nil

local eventsWeCareAbout = {
	aet.avatarEventTypes.DO_SPEED_CHANGE,
	aet.avatarEventTypes.RUN_START,
	aet.avatarEventTypes.RETOUCH_SIGN,
	aet.avatarEventTypes.RUN_COMPLETE,
}

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

		_annotate(
			string.format(
				"assigned emitter %s to sign for %s at %s",
				attachmentName,
				sign.Name,
				tostring(attachment.Position)
			)
		)
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

local function getOrCreateDescriptor(key: string): tt.particleDescriptor
	if not myDescriptors[key] then
		myDescriptors[key] = particleEnums.getRandomParticleDescriptor(localPlayer.UserId, key)
	end
	return myDescriptors[key]
end

local function emitParticleForEvent(ev: aet.avatarEvent)
	local keyFunc = eventTypeToKeyMap[ev.eventType]
	if not keyFunc then
		warn("no key mapping for event type")
		return
	end

	local key = keyFunc(ev)
	if not key then
		warn("no key")
		return
	end

	_annotate(string.format("particles received event and using key: %s", key))

	if key == "runstart" or key == "retouch" then
		for _, emitter in pairs(emitters) do
			emitter.Rate = 0
		end
	end

	local myDescriptor: tt.particleDescriptor
	local emitter: ParticleEmitter

	if particleEnums.ParticleDescriptors[key] then
		myDescriptor = particleEnums.ParticleDescriptors[key]
		emitter = emitters[myDescriptor.name]
		if not emitter then
			createParticleEmitter(myDescriptor)
			emitter = emitters[myDescriptor.name]
			_annotate("got normal emitter from descriptor.")
		end
	else
		myDescriptor = getOrCreateDescriptor(key)
		emitter = emitters[myDescriptor.name]
		if not emitter then
			createParticleEmitter(myDescriptor)
			emitter = emitters[myDescriptor.name]
			_annotate("using random emitter.")
		end
	end

	if emitter then
		doEmit(myDescriptor, emitter, ev)
	end
end

local function handleAvatarEvent(ev: aet.avatarEvent)
	if not avatarEventFiring.EventIsATypeWeCareAbout(ev, eventsWeCareAbout) then
		return
	end
	_annotate("handling:  " .. avatarEventFiring.DescribeEvent(ev))
	emitParticleForEvent(ev)
end

local function handleShowParticleSettingChange(setting: tt.userSettingValue)
	_annotate("handleShowParticleSettingChange: " .. (setting and setting.name or "nil") .. " " .. tostring(setting and setting.booleanValue or "nil"))

	if setting and setting.name == settingEnums.settingDefinitions.SHOW_PARTICLES.name then
		particlesEnabledAtAll = if setting.booleanValue ~= nil then setting.booleanValue else true

		if particlesEnabledAtAll then
			_annotate("enabled, connecting")
			if avatarEventConnection then
				avatarEventConnection:Disconnect()
				avatarEventConnection = nil
			end
			avatarEventConnection = AvatarEventBindableEvent.Event:Connect(handleAvatarEvent)
		else
			_annotate("disabled, disconnecting")
			for _, emitter in pairs(emitters) do
				emitter.Rate = 0
			end

			if avatarEventConnection then
				avatarEventConnection:Disconnect()
				avatarEventConnection = nil
			end
		end
	end
	return
end

local module: Module = {
	Init = function()
		_annotate("init")

		annotater.Profile("particles.updateCharacterCache", function()
			updateCharacterCache()
		end)

		annotater.Profile("particles.CharacterAdded:Connect", function()
			localPlayer.CharacterAdded:Connect(updateCharacterCache)
		end)

		annotater.Profile("particles.RegisterFunctionToListenForSettingName", function()
			settings.RegisterFunctionToListenForSettingName(
				handleShowParticleSettingChange,
				settingEnums.settingDefinitions.SHOW_PARTICLES.name,
				"particles"
			)
		end)

		annotater.Profile("particles.GetSettingByName", function()
			handleShowParticleSettingChange(settings.GetSettingByName(settingEnums.settingDefinitions.SHOW_PARTICLES.name))
		end)

		_annotate("init done")
	end,
}

_annotate("end")
return module
