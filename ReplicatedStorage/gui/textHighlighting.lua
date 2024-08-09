local module = {}

-- highlight signs or other text.
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local config = require(game.ReplicatedStorage.config)
local enums = require(game.ReplicatedStorage.util.enums)
local mt = require(game.ReplicatedStorage.avatarEventTypes)
local tt = require(game.ReplicatedStorage.types.gametypes)
local remotes = require(game.ReplicatedStorage.util.remotes)
local settings = require(game.ReplicatedStorage.settings)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()

local AvatarEventBindableEvent: BindableEvent = remotes.getBindableEvent("AvatarEventBindableEvent")

--------- CONSTANTS ----------------
local COLOR_CYCLE_TIME = 6
local TOTAL_LIFETIME = 40
local FADE_OUT_TIME = 6
local BILLBOARD_WIDTH_PER_LETTER = 15
local BILLBOARD_HEIGHT = 45
local BILLBOARD_OFFSET = Vector3.new(0, 2, 0)

---------GLOBALS ---------------
local currentHighlights = {}
local doHighlightAtAll = true

local function lerpColor(c1, c2, alpha)
	return Color3.new(c1.R + (c2.R - c1.R) * alpha, c1.G + (c2.G - c1.G) * alpha, c1.B + (c2.B - c1.B) * alpha)
end

local colorPattern = {
	Color3.fromRGB(255, 0, 0), -- Red
	Color3.fromRGB(255, 165, 0), -- Orange
	Color3.fromRGB(255, 255, 0), -- Yellow
	Color3.fromRGB(0, 255, 0), -- Green
	Color3.fromRGB(0, 0, 255), -- Blue
	Color3.fromRGB(255, 0, 255), -- Purple
}

module.KillAllExistingHighlights = function()
	_annotate("Killing all existing highlights")
	for _, el in pairs(currentHighlights) do
		if el then
			el:Destroy()
		end
	end
	currentHighlights = {}
end

local function innerDoHighlight(sign: Part)
	if not sign then
		if config.isTestGame() then
			_annotate("trying to highlight a nil sign?")
		else
			warn("trying to highlight a nil sign?")
		end
		return
	end
	if not tpUtil.SignCanBeHighlighted(sign) then
		_annotate("cannot highlight sign from tputil." .. sign.Name)
		return
	end
	_annotate(string.format("highlighting: %s", sign.Name))
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "FloatingText"
	billboardGui.AlwaysOnTop = true
	local useSize = #sign.Name * BILLBOARD_WIDTH_PER_LETTER
	billboardGui.Size = UDim2.new(0, useSize, 0, BILLBOARD_HEIGHT)
	billboardGui.StudsOffset = BILLBOARD_OFFSET

	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.Text = sign.Name
	textLabel.TextColor3 = Color3.new(1, 1, 1) -- White text
	textLabel.TextScaled = true
	textLabel.ZIndex = 89
	textLabel.Font = Enum.Font.GothamBold

	-- Parent objects
	textLabel.Parent = billboardGui
	billboardGui.Parent = sign

	-- Create UIStroke for outline effect
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = Color3.new(1, 1, 1)
	uiStroke.Thickness = 2
	uiStroke.Parent = textLabel

	local startTime = tick()
	local colorCycleTime = COLOR_CYCLE_TIME -- Time to cycle through all colors
	-- local pulseTime = 1 -- Time for one pulse cycle
	local totalLifetime = TOTAL_LIFETIME -- Total lifetime of the effect in seconds
	local fadeOutTime = FADE_OUT_TIME -- Time it takes to fade out at the end

	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsedTime = tick() - startTime
		if localPlayer and character then
			-- Color cycling
			local colorAlpha = (elapsedTime % colorCycleTime) / colorCycleTime
			local colorIndex = math.floor(colorAlpha * (#colorPattern - 1)) + 1
			local nextColorIndex = colorIndex % #colorPattern + 1
			local localAlpha = (colorAlpha * (#colorPattern - 1)) % 1

			local currentColor = lerpColor(colorPattern[colorIndex], colorPattern[nextColorIndex], localAlpha)
			textLabel.TextColor3 = currentColor
			uiStroke.Color = Color3.new(1 - currentColor.R, 1 - currentColor.G, 1 - currentColor.B) -- Contrasting outline color

			-- Fade out effect
			if elapsedTime > (totalLifetime - fadeOutTime) then
				local fadeAlpha = math.clamp((totalLifetime - elapsedTime) / fadeOutTime, 0, 1)
				textLabel.TextTransparency = 1 - fadeAlpha
				uiStroke.Transparency = 1 - fadeAlpha
			end

			-- Remove the effect after the total lifetime
			if elapsedTime > totalLifetime then
				billboardGui:Destroy()
				_annotate(string.format("killing highlighting: %s", sign.Name))
				connection:Disconnect()
			end
		end
	end)
	table.insert(currentHighlights, billboardGui)
end

module.PointHumanoidAtSignId = function(signId: number)
	local sign: Part? = tpUtil.signId2Sign(signId)
	if not sign then
		return
	end
	_annotate("pointing player at sign" .. sign.Name)
	------------ point the player at the target -------------------
	_annotate(string.format("pointing player at sign: %s", sign.Name))
	local humanoidRootPart: Part? = nil
	if localPlayer and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
		local character = localPlayer.Character
		humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			local direction = (sign.Position - humanoidRootPart.Position).Unit
			humanoidRootPart.CFrame = CFrame.new(humanoidRootPart.Position, humanoidRootPart.Position + direction)
		end
	end
end

module.RotateCameraToFaceSignId = function(signId: number?)
	if not signId then
		_annotate("trying to rotate camera to face sign that doesnt exist2")
		return
	end
	------ point the camera at the location. ------------
	character = localPlayer.Character
	local humanoidRootPart: Part? = nil
	humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera

	if camera then
		local sign = tpUtil.signId2Sign(signId)
		if not sign then
			_annotate("trying to rotate camera to face sign that doesnt exist")
			return
		else
			_annotate(string.format("Rotating camera to face sign: %s", sign.Name))
		end
		if humanoidRootPart then
			-- Calculate the direction from the humanoid to the sign
			local direction = (sign.Position - humanoidRootPart.Position).Unit

			-- Create a new CFrame that faces the sign but keeps the current position
			local newCFrame = CFrame.new(humanoidRootPart.Position, humanoidRootPart.Position + direction)

			-- Set only the rotation of the humanoid, keeping its current position
			camera.CFrame = CFrame.new(humanoidRootPart.Position) * (newCFrame - newCFrame.Position)
		end
	end
end

module.DoHighlightSingleSignId = function(signId: number)
	if not doHighlightAtAll then
		return
	end
	local sign: Part? = tpUtil.signId2Sign(signId)

	if not sign then
		if not config.isTestGame() then
			warn("trying to highlight an unseen sign? id=" .. tostring(signId))
		end
		return
	end

	_annotate(string.format("Highlighting Single sign at: %s", sign.Name))
	if not tpUtil.SignCanBeHighlighted(sign) then
		return
	end
	innerDoHighlight(sign)
end

module.DoHighlightMultiple = function(signIds: { number })
	_annotate(string.format("Highlighting multiple signs: %s", table.concat(signIds, ", ")))
	for _, signId in pairs(signIds) do
		local sign: Part? = tpUtil.signId2Sign(signId)
		innerDoHighlight(sign)
	end
end

local function handleAvatarEvent(event: mt.avatarEvent)
	_annotate("handleAvatarEvent " .. avatarEventFiring.DescribeEvent(event.eventType, event.details))
	if
		event.eventType == mt.avatarEventTypes.AVATAR_DIED
		or event.eventType == mt.avatarEventTypes.GET_READY_FOR_WARP
		or event.eventType == mt.avatarEventTypes.RUN_COMPLETE
		or event.eventType == mt.avatarEventTypes.RUN_KILL
	then
		module.KillAllExistingHighlights()
	end
end

local function handleUserSettingChanged(userSetting: tt.userSettingValue)
	if userSetting.name == settingEnums.settingNames.HIGHLIGHT_AT_ALL then
		doHighlightAtAll = userSetting.value
	end
end

module.Init = function()
	character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	humanoid = character:WaitForChild("Humanoid")

	AvatarEventBindableEvent.Event:Connect(handleAvatarEvent)

	handleUserSettingChanged(settings.getSettingByName(settingEnums.settingNames.HIGHLIGHT_AT_ALL))
	-- handleUserSettingChanged(
	-- 	settings.getSettingByName(settingEnums.settingNames.ROTATE_PLAYER_ON_WARP_WHEN_DESTINATION)
	-- )

	settings.RegisterFunctionToListenForSettingName(
		handleUserSettingChanged,
		settingEnums.settingNames.HIGHLIGHT_AT_ALL
	)
	-- settings.RegisterLocalSettingChangeReceiver(
	-- 	handleUserSettingChanged,
	-- 	settingEnums.settingNames.ROTATE_PLAYER_ON_WARP_WHEN_DESTINATION
	-- )
end

_annotate("end")
return module
