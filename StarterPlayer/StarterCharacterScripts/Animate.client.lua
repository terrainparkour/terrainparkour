--!strict

--mainly original animation script, but with some hacks to handle the dumb crouching animation
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local function setupValues()
	local em = Instance.new("BindableFunction")
	em.Parent = script
	em.Name = "PlayEmote"
	if false then
		local keys = {
			"cheer",
			"climb",
			"dance",
			"dance2",
			"dance3",
			"fall",
			"idle",
			"jump",
			-- "laugh",
			"point",
			"run",
			"sit",
			"swim",
			"swimidle",
			"toollunge",
			"toolnone",
			"toolslash",
			"walk",
			"wave",
		}
		for _, k in ipairs(keys) do
			local sv = Instance.new("StringValue")
			sv.Parent = script
			sv.Name = k
		end
		local sd = Instance.new("NumberValue")
		sd.Name = "StringDampeningPercent"
		sd.Value = 1
	end
end

setupValues()

local Character = script.Parent
local Humanoid: Humanoid = Character:WaitForChild("Humanoid")
local pose = "Standing"

local function setupStateChange()
	Humanoid.StateChanged:Connect(function(old, new)
		-- print(new)
	end)
end
setupStateChange()

local userNoUpdateOnLoopSuccess, userNoUpdateOnLoopValue = pcall(function()
	return UserSettings():IsUserFeatureEnabled("UserNoUpdateOnLoop")
end)
local userNoUpdateOnLoop = userNoUpdateOnLoopSuccess and userNoUpdateOnLoopValue

local userEmoteToRunThresholdChange
do
	local success, value = pcall(function()
		return UserSettings():IsUserFeatureEnabled("UserEmoteToRunThresholdChange")
	end)
	userEmoteToRunThresholdChange = success and value
end

local userPlayEmoteByIdAnimTrackReturn
do
	local success, value = pcall(function()
		return UserSettings():IsUserFeatureEnabled("UserPlayEmoteByIdAnimTrackReturn2")
	end)
	userPlayEmoteByIdAnimTrackReturn = success and value
end

local AnimationSpeedDampeningObject: IntValue = script:FindFirstChild("ScaleDampeningPercent")
local HumanoidHipHeight = 2

local EMOTE_TRANSITION_TIME = 0.1

local currentAnim = ""
local currentAnimInstance = nil
local currentAnimTrack = nil
local currentAnimKeyframeHandler = nil
local currentAnimSpeed = 1.0

local runAnimTrack = nil
local runAnimKeyframeHandler = nil

local PreloadedAnims = {}

local animTable = {}
local animNames = {
	idle = {
		-- { id = "http://www.roblox.com/asset/?id=507766666", weight = 1 },
		-- { id = "http://www.roblox.com/asset/?id=507766951", weight = 1 },
		{ id = "http://www.roblox.com/asset/?id=507766388", weight = 9 },
	},
	walk = {
		{ id = "http://www.roblox.com/asset/?id=507777826", weight = 10 },
	},
	run = {
		{ id = "http://www.roblox.com/asset/?id=507767714", weight = 10 },
	},
	swim = {
		{ id = "http://www.roblox.com/asset/?id=507784897", weight = 10 },
	},
	swimidle = {
		{ id = "http://www.roblox.com/asset/?id=507785072", weight = 10 },
	},
	jump = {
		--{ id = "http://www.roblox.com/asset/?id=507765000", weight = 10 }, --original jupm
		{ id = "http://www.roblox.com/asset/?id=507766388", weight = 9 }, --idle animation
		--{ id = "http://www.roblox.com/asset/?id=10135286354", weight = 10 }, --jump without last two keyframes
	},
	fall = {
		--{ id = "http://www.roblox.com/asset/?id=507767968", weight = 10 }, --original fall
		{ id = "http://www.roblox.com/asset/?id=507766388", weight = 9 }, --idle animation
	},
	climb = {
		{ id = "http://www.roblox.com/asset/?id=507765644", weight = 10 },
	},
	sit = {
		{ id = "http://www.roblox.com/asset/?id=2506281703", weight = 10 },
	},
	toolnone = {
		{ id = "http://www.roblox.com/asset/?id=507768375", weight = 10 },
	},
	toolslash = {
		{ id = "http://www.roblox.com/asset/?id=522635514", weight = 10 },
	},
	toollunge = {
		{ id = "http://www.roblox.com/asset/?id=522638767", weight = 10 },
	},
	wave = {
		{ id = "http://www.roblox.com/asset/?id=507770239", weight = 10 },
	},
	point = {
		{ id = "http://www.roblox.com/asset/?id=507770453", weight = 10 },
	},
	dance = {
		{ id = "http://www.roblox.com/asset/?id=507771019", weight = 10 },
		{ id = "http://www.roblox.com/asset/?id=507771955", weight = 10 },
		{ id = "http://www.roblox.com/asset/?id=507772104", weight = 10 },
	},
	dance2 = {
		{ id = "http://www.roblox.com/asset/?id=507776043", weight = 10 },
		{ id = "http://www.roblox.com/asset/?id=507776720", weight = 10 },
		{ id = "http://www.roblox.com/asset/?id=507776879", weight = 10 },
	},
	dance3 = {
		{ id = "http://www.roblox.com/asset/?id=507777268", weight = 10 },
		{ id = "http://www.roblox.com/asset/?id=507777451", weight = 10 },
		{ id = "http://www.roblox.com/asset/?id=507777623", weight = 10 },
	},
	-- laugh = {
	-- 	{ id = "http://www.roblox.com/asset/?id=507770818", weight = 10 },
	-- },
	cheer = {
		{ id = "http://www.roblox.com/asset/?id=507770677", weight = 10 },
	},
}

-- Existance in this list signifies that it is an emote, the value indicates if it is a looping emote
local loopEmote = {
	wave = true,
	point = true,
	dance = true,
	dance2 = true,
	dance3 = true,
	-- laugh = false,
	cheer = true,
}

math.randomseed(tick())

function findExistingAnimationInSet(set, anim)
	if set == nil or anim == nil then
		return 0
	end

	for idx = 1, set.count, 1 do
		if set[idx].anim.AnimationId == anim.AnimationId then
			return idx
		end
	end

	return 0
end

function configureAnimationSet(name, fileList)
	if animTable[name] ~= nil then
		for _, connection in pairs(animTable[name].connections) do
			connection:disconnect()
		end
	end
	animTable[name] = {}
	animTable[name].count = 0
	animTable[name].totalWeight = 0
	animTable[name].connections = {}

	local allowCustomAnimations = true

	local success, msg = pcall(function()
		allowCustomAnimations = game:GetService("StarterPlayer").AllowCustomAnimations
	end)
	if not success then
		allowCustomAnimations = true
	end

	-- check for config values
	local config = script:FindFirstChild(name)
	if allowCustomAnimations and config ~= nil then
		table.insert(
			animTable[name].connections,
			config.ChildAdded:connect(function(child)
				configureAnimationSet(name, fileList)
			end)
		)
		table.insert(
			animTable[name].connections,
			config.ChildRemoved:connect(function(child)
				configureAnimationSet(name, fileList)
			end)
		)

		local idx = 0
		for _, childPart in pairs(config:GetChildren()) do
			if childPart:IsA("Animation") then
				local newWeight = 1
				local weightObject: IntValue = childPart:FindFirstChild("Weight")
				if weightObject ~= nil then
					newWeight = weightObject.Value
				end
				animTable[name].count = animTable[name].count + 1
				idx = animTable[name].count
				animTable[name][idx] = {}
				animTable[name][idx].anim = childPart
				animTable[name][idx].weight = newWeight
				animTable[name].totalWeight = animTable[name].totalWeight + animTable[name][idx].weight
				table.insert(
					animTable[name].connections,
					childPart.Changed:connect(function(property)
						configureAnimationSet(name, fileList)
					end)
				)
				table.insert(
					animTable[name].connections,
					childPart.ChildAdded:connect(function(property)
						configureAnimationSet(name, fileList)
					end)
				)
				table.insert(
					animTable[name].connections,
					childPart.ChildRemoved:connect(function(property)
						configureAnimationSet(name, fileList)
					end)
				)
			end
		end
	end

	-- fallback to defaults
	if animTable[name].count <= 0 then
		for idx, anim in pairs(fileList) do
			animTable[name][idx] = {}
			animTable[name][idx].anim = Instance.new("Animation")
			animTable[name][idx].anim.Name = name
			animTable[name][idx].anim.AnimationId = anim.id
			animTable[name][idx].weight = anim.weight
			animTable[name].count = animTable[name].count + 1
			animTable[name].totalWeight = animTable[name].totalWeight + anim.weight
		end
	end

	-- preload anims
	for i, animType in pairs(animTable) do
		for idx = 1, animType.count, 1 do
			if PreloadedAnims[animType[idx].anim.AnimationId] == nil then
				-- print(animType[idx])
				Humanoid:LoadAnimation(animType[idx].anim)
				PreloadedAnims[animType[idx].anim.AnimationId] = true
			end
		end
	end
end

------------------------------------------------------------------------------------------------------------

-- Setup animation objects
function scriptChildModified(child)
	local fileList = animNames[child.Name]
	if fileList ~= nil then
		configureAnimationSet(child.Name, fileList)
	end
end

script.ChildAdded:connect(scriptChildModified)
script.ChildRemoved:connect(scriptChildModified)

-- Clear any existing animation tracks
-- Fixes issue with characters that are moved in and out of the Workspace accumulating tracks
local animator = if Humanoid then Humanoid:FindFirstChildOfClass("Animator") else nil
if animator then
	local animTracks = animator:GetPlayingAnimationTracks()
	for _, track in ipairs(animTracks) do
		track:Stop(0)
		track:Destroy()
	end
end

--script to constantly print the newly playing animation
if false then
	task.spawn(function()
		local last = ""
		while true do
			task.wait()
			local exi = animator:GetPlayingAnimationTracks()
			if exi == nil then
				continue
			end
			if exi[1] == last then
				continue
			end
			-- print(exi[1])
			print(" anim tracks: " .. tostring(exi))
			print(exi)
			print(exi[1])
			last = exi[1]
		end
	end)
end

for name, fileList in pairs(animNames) do
	configureAnimationSet(name, fileList)
end

-- ANIMATION

-- declarations
local toolAnim = "None"
local toolAnimTime = 0

local jumpAnimTimeRemaining = 0
local jumpAnimDuration = 0.31

local toolTransitionTime = 0.1
local fallTransitionTime = 0.2

local currentlyPlayingEmote = false

-- functions

function stopAllAnimations()
	local oldAnim = currentAnim

	-- return to idle if finishing an emote
	if loopEmote[oldAnim] ~= nil and loopEmote[oldAnim] == false then
		oldAnim = "idle"
	end

	if currentlyPlayingEmote then
		oldAnim = "idle"
		currentlyPlayingEmote = false
	end

	currentAnim = ""
	currentAnimInstance = nil
	if currentAnimKeyframeHandler ~= nil then
		currentAnimKeyframeHandler:disconnect()
	end

	if currentAnimTrack ~= nil then
		currentAnimTrack:Stop()
		currentAnimTrack:Destroy()
		currentAnimTrack = nil
	end

	-- clean up walk if there is one
	if runAnimKeyframeHandler ~= nil then
		runAnimKeyframeHandler:disconnect()
	end

	if runAnimTrack ~= nil then
		runAnimTrack:Stop()
		runAnimTrack:Destroy()
		runAnimTrack = nil
	end

	return oldAnim
end

function getHeightScale()
	if Humanoid then
		if not Humanoid.AutomaticScalingEnabled then
			return 1
		end

		local scale = Humanoid.HipHeight / HumanoidHipHeight
		if AnimationSpeedDampeningObject == nil then
			AnimationSpeedDampeningObject = script:FindFirstChild("ScaleDampeningPercent")
		end
		if AnimationSpeedDampeningObject ~= nil then
			scale = 1
				+ (Humanoid.HipHeight - HumanoidHipHeight) * AnimationSpeedDampeningObject.Value / HumanoidHipHeight
		end
		return scale
	end
	return 1
end

local function rootMotionCompensation(speed)
	local speedScaled = speed * 1.25
	local heightScale = getHeightScale()
	local runSpeed = speedScaled / heightScale
	return runSpeed
end

local smallButNotZero = 0.0001
local function setRunSpeed(speed)
	local normalizedWalkSpeed = 0.5 -- established empirically using current `913402848` walk animation
	local normalizedRunSpeed = 1
	local runSpeed = rootMotionCompensation(speed)

	local walkAnimationWeight = smallButNotZero
	local runAnimationWeight = smallButNotZero
	local walkAnimationTimewarp = runSpeed / normalizedWalkSpeed
	local runAnimationTimerwarp = runSpeed / normalizedRunSpeed

	if runSpeed <= normalizedWalkSpeed then
		walkAnimationWeight = 1
	elseif runSpeed < normalizedRunSpeed then
		local fadeInRun = (runSpeed - normalizedWalkSpeed) / (normalizedRunSpeed - normalizedWalkSpeed)
		walkAnimationWeight = 1 - fadeInRun
		runAnimationWeight = fadeInRun
		walkAnimationTimewarp = 1
		runAnimationTimerwarp = 1
	else
		runAnimationWeight = 1
	end
	currentAnimTrack:AdjustWeight(walkAnimationWeight)
	runAnimTrack:AdjustWeight(runAnimationWeight)
	currentAnimTrack:AdjustSpeed(walkAnimationTimewarp)
	runAnimTrack:AdjustSpeed(runAnimationTimerwarp)
end

function setAnimationSpeed(speed)
	if currentAnim == "walk" then
		setRunSpeed(speed)
	else
		if speed ~= currentAnimSpeed then
			currentAnimSpeed = speed
			currentAnimTrack:AdjustSpeed(currentAnimSpeed)
		end
	end
end

function keyFrameReachedFunc(frameName)
	if frameName == "End" then
		if currentAnim == "walk" then
			if userNoUpdateOnLoop == true then
				if runAnimTrack.Looped ~= true then
					runAnimTrack.TimePosition = 0.0
				end
				if currentAnimTrack.Looped ~= true then
					currentAnimTrack.TimePosition = 0.0
				end
			else
				runAnimTrack.TimePosition = 0.0
				currentAnimTrack.TimePosition = 0.0
			end
		else
			local repeatAnim = currentAnim
			-- return to idle if finishing an emote
			if loopEmote[repeatAnim] ~= nil and loopEmote[repeatAnim] == false then
				repeatAnim = "idle"
			end

			if currentlyPlayingEmote then
				if currentAnimTrack.Looped then
					return
				end

				repeatAnim = "idle"
				currentlyPlayingEmote = false
			end

			local animSpeed = currentAnimSpeed
			playAnimation(repeatAnim, 0.15, Humanoid)
			setAnimationSpeed(animSpeed)
		end
	end
end

function rollAnimation(animName)
	local roll = math.random(1, animTable[animName].totalWeight)
	local origRoll = roll
	local idx = 1
	while roll > animTable[animName][idx].weight do
		roll = roll - animTable[animName][idx].weight
		idx = idx + 1
	end
	return idx
end

local function switchToAnim(anim, animName, transitionTime: number, humanoid)
	-- switch animation
	if
		animName == "idle"
		or animName == "walk"
		or animName == "jump"
		or animName == "run"
		or animName == "fall"
		or animName == "sit"
		or animName == "swim"
		or animName == "swimidle"
	then
	else
		print("skipping: " .. animName)
		return
	end

	if anim == currentAnimInstance then
		return
	end

	if currentAnimTrack ~= nil then
		currentAnimTrack:Stop()
		currentAnimTrack:Destroy()
	end

	if runAnimTrack ~= nil then
		runAnimTrack:Stop()
		runAnimTrack:Destroy()
		if userNoUpdateOnLoop == true then
			runAnimTrack = nil
		end
	end

	currentAnimSpeed = 1.0

	-- load it to the humanoid; get AnimationTrack
	currentAnimTrack = humanoid:LoadAnimation(anim)
	currentAnimTrack.Priority = Enum.AnimationPriority.Core

	-- play the animation
	currentAnimTrack:Play(transitionTime)
	currentAnim = animName
	currentAnimInstance = anim

	-- set up keyframe name triggers
	if currentAnimKeyframeHandler ~= nil then
		currentAnimKeyframeHandler:disconnect()
	end
	currentAnimKeyframeHandler = currentAnimTrack.KeyframeReached:connect(keyFrameReachedFunc)

	-- check to see if we need to blend a walk/run animation
	if animName == "walk" then
		local runAnimName = "run"
		local runIdx = rollAnimation(runAnimName)

		runAnimTrack = humanoid:LoadAnimation(animTable[runAnimName][runIdx].anim)
		runAnimTrack.Priority = Enum.AnimationPriority.Core
		runAnimTrack:Play(transitionTime)

		if runAnimKeyframeHandler ~= nil then
			runAnimKeyframeHandler:disconnect()
		end
		runAnimKeyframeHandler = runAnimTrack.KeyframeReached:connect(keyFrameReachedFunc)
	end
end

function playAnimation(animName, transitionTime, humanoid)
	local idx = rollAnimation(animName)
	local anim = animTable[animName][idx].anim

	switchToAnim(anim, animName, transitionTime, humanoid)
	currentlyPlayingEmote = false
end

function playEmote(emoteAnim, transitionTime, humanoid)
	switchToAnim(emoteAnim, emoteAnim.Name, transitionTime, humanoid)
	currentlyPlayingEmote = true
end

-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

local toolAnimName = ""
local toolAnimTrack = nil
local toolAnimInstance = nil
local currentToolAnimKeyframeHandler = nil

function toolKeyFrameReachedFunc(frameName)
	if frameName == "End" then
		playToolAnimation(toolAnimName, 0.0, Humanoid)
	end
end

function playToolAnimation(animName, transitionTime, humanoid, priority)
	local idx = rollAnimation(animName)
	local anim = animTable[animName][idx].anim

	if toolAnimInstance ~= anim then
		if toolAnimTrack ~= nil then
			toolAnimTrack:Stop()
			toolAnimTrack:Destroy()
			transitionTime = 0
		end

		-- load it to the humanoid; get AnimationTrack
		toolAnimTrack = humanoid:LoadAnimation(anim)
		if priority then
			toolAnimTrack.Priority = priority
		end

		-- play the animation
		toolAnimTrack:Play(transitionTime)
		toolAnimName = animName
		toolAnimInstance = anim

		currentToolAnimKeyframeHandler = toolAnimTrack.KeyframeReached:connect(toolKeyFrameReachedFunc)
	end
end

function stopToolAnimations()
	local oldAnim = toolAnimName

	if currentToolAnimKeyframeHandler ~= nil then
		currentToolAnimKeyframeHandler:disconnect()
	end

	toolAnimName = ""
	toolAnimInstance = nil
	if toolAnimTrack ~= nil then
		toolAnimTrack:Stop()
		toolAnimTrack:Destroy()
		toolAnimTrack = nil
	end

	return oldAnim
end

-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------
-- STATE CHANGE HANDLERS

function onRunning(speed)
	local movedDuringEmote = userEmoteToRunThresholdChange
		and currentlyPlayingEmote
		and Humanoid.MoveDirection == Vector3.new(0, 0, 0)
	local speedThreshold = movedDuringEmote and Humanoid.WalkSpeed or 0.75
	if speed > speedThreshold then
		local scale = 16.0
		playAnimation("walk", 0.2, Humanoid)
		setAnimationSpeed(speed / scale)
		pose = "Running"
	else
		if loopEmote[currentAnim] == nil and not currentlyPlayingEmote then
			playAnimation("idle", 0.2, Humanoid)
			pose = "Standing"
		end
	end
end

function onDied()
	pose = "Dead"
end

function onJumping()
	-- print("onJumping")
	playAnimation("jump", 0.1, Humanoid)
	jumpAnimTimeRemaining = jumpAnimDuration
	pose = "Jumping"
end

function onClimbing(speed)
	-- print("onClimbing")
	-- local scale = 5.0
	-- playAnimation("climb", 0.1, Humanoid)
	-- setAnimationSpeed(speed / scale)
	pose = "Climbing"
end

function onGettingUp()
	-- print("onGettingUp")
	pose = "GettingUp"
end

function onFreeFall()
	-- print("onFreeFall")
	if jumpAnimTimeRemaining <= 0 then
		playAnimation("fall", fallTransitionTime, Humanoid)
	end
	pose = "FreeFall"
end

function onFallingDown()
	-- print("onFallingDown")
	pose = "FallingDown"
end

function onSeated()
	pose = "Seated"
end

function onPlatformStanding()
	-- print("onPlatformStanding")
	pose = "PlatformStanding"
end

-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

function onLanding(speed)
	-- print("landed " .. tostring(speed))
	stopAllAnimations()
end

function onSwimming(speed)
	if speed > 1.00 then
		local scale = 10.0
		playAnimation("swim", 0.4, Humanoid)
		setAnimationSpeed(speed / scale)
		pose = "Swimming"
	else
		playAnimation("swimidle", 0.4, Humanoid)
		pose = "Standing"
	end
end

function animateTool()
	if toolAnim == "None" then
		playToolAnimation("toolnone", toolTransitionTime, Humanoid, Enum.AnimationPriority.Idle)
		return
	end

	if toolAnim == "Slash" then
		playToolAnimation("toolslash", 0, Humanoid, Enum.AnimationPriority.Action)
		return
	end

	if toolAnim == "Lunge" then
		playToolAnimation("toollunge", 0, Humanoid, Enum.AnimationPriority.Action)
		return
	end
end

function getToolAnim(tool)
	for _, c in ipairs(tool:GetChildren()) do
		if c.Name == "toolanim" and c.className == "StringValue" then
			return c
		end
	end
	return nil
end

local lastTick = 0

local lastPose = pose

--apparently never used
function stepAnimate(currentTime)
	local dodoprint = false
	local doprint = true
	if pose ~= lastPose then
		-- print("StepAnimate pose: " .. tostring(pose))
		lastPose = pose
		doprint = true
	end
	if not dodoprint then
		doprint = false
	end
	local deltaTime = currentTime - lastTick
	lastTick = currentTime

	if jumpAnimTimeRemaining > 0 then
		jumpAnimTimeRemaining = jumpAnimTimeRemaining - deltaTime
	end

	if pose == "Seated" then
		playAnimation("sit", 0.5, Humanoid)
		return
	elseif pose == "Running" then
		if doprint then
			print("\trunning.")
		end
		playAnimation("walk", 0.0, Humanoid)
	elseif
		pose == "Dead"
		or pose == "GettingUp"
		or pose == "FallingDown"
		or pose == "Seated"
		or pose == "PlatformStanding"
		-- or pose == "Standing" --added this 7.7.22. it
	then
		if doprint then
			print("\tstop all" .. pose)
		end
		stopAllAnimations()
	else
		if doprint then
			print("\tdoing nothing")
		end
	end

	-- Tool Animation handling
	local tool = Character:FindFirstChildOfClass("Tool")
	if tool and tool:FindFirstChild("Handle") then
		local animStringValueObject = getToolAnim(tool)

		if animStringValueObject then
			toolAnim = animStringValueObject.Value
			-- message recieved, delete StringValue
			animStringValueObject.Parent = nil
			toolAnimTime = currentTime + 0.3
		end

		if currentTime > toolAnimTime then
			toolAnimTime = 0
			toolAnim = "None"
		end

		animateTool()
	else
		stopToolAnimations()
		toolAnim = "None"
		toolAnimInstance = nil
		toolAnimTime = 0
	end
end

--------------------CONNECT EVENTS--------------------------
Humanoid.Died:Connect(onDied)
Humanoid.Running:Connect(onRunning)
Humanoid.Jumping:Connect(onJumping)
Humanoid.Climbing:Connect(onClimbing)
Humanoid.GettingUp:Connect(onGettingUp)
Humanoid.FreeFalling:Connect(onFreeFall)
Humanoid.FallingDown:Connect(onFallingDown)
Humanoid.Seated:Connect(onSeated)
Humanoid.PlatformStanding:Connect(onPlatformStanding)
Humanoid.Swimming:Connect(onSwimming)
-- Humanoid.Landing:Connect(onLanding)

-- setup emote chat hook
game:GetService("Players").LocalPlayer.Chatted:Connect(function(msg)
	local emote = ""
	if string.sub(msg, 1, 3) == "/e " then
		emote = string.sub(msg, 4)
	elseif string.sub(msg, 1, 7) == "/emote " then
		emote = string.sub(msg, 8)
	end

	if pose == "Standing" and loopEmote[emote] ~= nil then
		playAnimation(emote, EMOTE_TRANSITION_TIME, Humanoid)
	end
end)

-- emote bindable hook
local em: BindableFunction = script:WaitForChild("PlayEmote") :: BindableFunction

em.OnInvoke = function(emote): any
	-- Only play emotes when idling
	if pose ~= "Standing" then
		return
	end

	if loopEmote[emote] ~= nil then
		-- Default emotes
		playAnimation(emote, EMOTE_TRANSITION_TIME, Humanoid)

		if userPlayEmoteByIdAnimTrackReturn then
			return true, currentAnimTrack
		else
			return true
		end
	elseif typeof(emote) == "Instance" and emote:IsA("Animation") then
		-- Non-default emotes
		playEmote(emote, EMOTE_TRANSITION_TIME, Humanoid)

		if userPlayEmoteByIdAnimTrackReturn then
			return true, currentAnimTrack
		else
			return true
		end
	end

	-- Return false to indicate that the emote could not be played
	return false
end

if Character.Parent ~= nil then
	-- initialize to idle
	playAnimation("idle", 0.1, Humanoid)
	pose = "Standing"
end

-- loop to handle timed state transitions and tool animations
while Character.Parent ~= nil do
	local _, currentGameTime = wait(0.1)
	stepAnimate(currentGameTime)
end
_annotate("end")
