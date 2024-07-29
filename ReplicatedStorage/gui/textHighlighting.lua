local module = {}

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local config = require(game.ReplicatedStorage.config)
local enums = require(game.ReplicatedStorage.util.enums)
local mt = require(game.ReplicatedStorage.avatarEventTypes)
local tt = require(game.ReplicatedStorage.types.gametypes)
local remotes = require(game.ReplicatedStorage.util.remotes)
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local AvatarEventBindableEvent: BindableEvent = remotes.getBindableEvent("AvatarEventBindableEvent")

local localFunctions = require(game.ReplicatedStorage.localFunctions)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)

---------GLOBALS ---------------
local currentHighlights = {}
local doHighlightAtAll = false

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
end

local function innerDoHighlight(sign: Part)
	if not sign then
		if not config.isTestGame() then
			warn("trying to highlight a nil sign?")
		end
		return
	end
	if not tpUtil.isSignPartValidRightNow(sign) then
		_annotate("cannot highlight invalid sign." .. sign.Name)
		return
	end
	if enums.ExcludeSignNamesFromStartingAt[sign.Name] then
		_annotate("cannot highlight sign is ExcludeSignNamesFromStartingAt" .. sign.Name)
		return
	end
	if enums.ExcludeSignNamesFromEndingAt[sign.Name] then
		_annotate("cannot highlight sign is ExcludeSignNamesFromEndingAt" .. sign.Name)
		return
	end
	_annotate(string.format("highlighting: %s", sign.Name))
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "FloatingText"
	billboardGui.AlwaysOnTop = true
	billboardGui.Size = UDim2.new(0, 100, 0, 40)
	billboardGui.StudsOffset = Vector3.new(0, 2, 0) -- Adjust this to change height above the part

	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.Text = sign.Name
	textLabel.TextColor3 = Color3.new(1, 1, 1) -- White text
	textLabel.TextScaled = true
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
	local colorCycleTime = 6 -- Time to cycle through all colors
	-- local pulseTime = 1 -- Time for one pulse cycle
	local totalLifetime = 30 -- Total lifetime of the effect in seconds
	local fadeOutTime = 10 -- Time it takes to fade out at the end

	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsedTime = tick() - startTime
		local player = Players.LocalPlayer
		if player and player.Character and player.Character:FindFirstChild("Head") then
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

local function pointPlayerAtSign(sign: Part)
	if not sign then
		return
	end
	_annotate("pointing player at sign" .. sign.Name)
	local humanoidRootPart: Part? = nil
	if localPlayer and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
		local character = localPlayer.Character
		humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			local direction = (sign.Position - humanoidRootPart.Position).Unit
			humanoidRootPart.CFrame = CFrame.new(humanoidRootPart.Position, humanoidRootPart.Position + direction)
		end
	end

	------ point the camera at the location. ------------
	local camera = workspace.CurrentCamera
	if camera then
		-- camera.CFrame = CFrame.new(camera.CFrame.Position, sign.Position)
		if humanoidRootPart then
			camera.CFrame = humanoidRootPart.CFrame
		end
	end
end

module.doHighlightSingle = function(signId: number)
	module.KillAllExistingHighlights()
	if not doHighlightAtAll then
		return
	end
	local sign: Part? = tpUtil.signId2Sign(signId)
	if not sign then
		if not config.isTestGame() then
			warn("trying to highlight an unseen sign?")
		end
		return
	end
	pointPlayerAtSign(sign)
	innerDoHighlight(sign)
end

module.doHighlightMultiple = function(signIds: { number })
	module.KillAllExistingHighlights()
	for _, signId in pairs(signIds) do
		local sign: Part? = tpUtil.signId2Sign(signId)
		innerDoHighlight(sign)
	end

	-- when a player does /rr we reuse the multi-highlight showSignCommand.
	if signIds and #signIds == 1 then
		local sign: Part? = tpUtil.signId2Sign(signIds[1])
		pointPlayerAtSign(sign)
	end
end

local function receiveAvatarEvent(event: mt.avatarEvent)
	if
		event.eventType == mt.avatarEventTypes.DIED
		or event.eventType == mt.avatarEventTypes.GET_READY_FOR_WARP
		or event.eventType == mt.avatarEventTypes.RUN_COMPLETE
		or event.eventType == mt.avatarEventTypes.RUN_KILL
	then
		module.KillAllExistingHighlights()
	end
end

local function handleUserSettingChanged(userSetting: tt.userSettingValue)
	doHighlightAtAll = userSetting.value
end

module.Init = function()
	AvatarEventBindableEvent.Event:Connect(receiveAvatarEvent)
	local userSettingValue = localFunctions.getSettingByName(settingEnums.settingNames.HIGHLIGHT_AT_ALL)
	handleUserSettingChanged(userSettingValue)
	localFunctions.registerLocalSettingChangeReceiver(
		handleUserSettingChanged,
		settingEnums.settingNames.HIGHLIGHT_AT_ALL
	)
end

_annotate("end")
return module
