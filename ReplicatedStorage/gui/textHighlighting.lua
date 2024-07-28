local module = {}

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local enums = require(game.ReplicatedStorage.util.enums)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)

local function lerpColor(c1, c2, alpha)
	return Color3.new(c1.R + (c2.R - c1.R) * alpha, c1.G + (c2.G - c1.G) * alpha, c1.B + (c2.B - c1.B) * alpha)
end

local currentHighlights = {}

local function killAllExistingHighlights()
	for _, el in pairs(currentHighlights) do
		if el then
			el:Destroy()
		end
	end
end

local colorPattern = {
	Color3.fromRGB(255, 0, 0), -- Red
	Color3.fromRGB(255, 165, 0), -- Orange
	Color3.fromRGB(255, 255, 0), -- Yellow
	Color3.fromRGB(0, 255, 0), -- Green
	Color3.fromRGB(0, 0, 255), -- Blue
	Color3.fromRGB(255, 0, 255), -- Purple
}

local function innerDoHighlight(sign: Part)
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
				connection:Disconnect()
			end
		end
	end)
	table.insert(currentHighlights, billboardGui)
end

module.doHighlight = function(signId: number)
	local sign = tpUtil.signId2Sign(signId)
	if not sign then
		warn("warping to highlight an unseen sign?")
		return
	end
	if not tpUtil.isSignPartValidRightNow(sign) then
		_annotate("cannot highlight invalid sign.")
		return
	end
	if enums.ExcludeSignNamesFromStartingAt[sign.Name] then
		_annotate("cannot highlight sign is forbidden knowledge")
		return
	end
	if enums.ExcludeSignNamesFromEndingAt[sign.Name] then
		_annotate("cannot highlight sign is forbidden knowledge")
		return
	end
	killAllExistingHighlights()
	local player = Players.LocalPlayer
	if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		local character = player.Character
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			local direction = (sign.Position - humanoidRootPart.Position).Unit
			humanoidRootPart.CFrame = CFrame.new(humanoidRootPart.Position, humanoidRootPart.Position + direction)
		end
	end

	local camera = workspace.CurrentCamera
	if camera then
		camera.CFrame = CFrame.new(camera.CFrame.Position, sign.Position)
	end
	return innerDoHighlight(sign)
end

module.doHighlightMultiple = function(signIds: { number })
	killAllExistingHighlights()
	for _, signId in pairs(signIds) do
		local sign = tpUtil.signId2Sign(signId)
		if not sign then
			continue
		end
		innerDoHighlight(sign)
	end
end

_annotate("end")
return module