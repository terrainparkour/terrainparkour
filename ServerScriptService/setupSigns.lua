--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayerService = game:GetService("Players")
local enums = require(game.ReplicatedStorage.util.enums)

local signInfo = require(game.ReplicatedStorage.signInfo)
local colors = require(game.ReplicatedStorage.util.colors)
local signMovement = require(game.ReplicatedStorage.util.signMovement)

local config = require(game.ReplicatedStorage.config)

local module = {}

--how often is player location modified? every frame I guess?
--this is used to investigate feasibility of using location rather than :touched as a sign touch modifier.
--actually, 2024, this may be useful to detect Feodora's hack where he temporarily disconnects, too?
if false then
	local pp = Vector3.new(0, 0, 0)
	task.spawn(function()
		local t = tick()
		while true do
			local player = PlayerService:GetPlayers()[1]
			wait(1 / 1000.0)

			if player == nil then
				continue
			end
			if player.Character == nil then
				continue
			end
			if player.Character.HumanoidRootPart == nil then
				continue
			end
			local tick = tick()
			local pos = player.Character.HumanoidRootPart.Position
			print(string.format("%0.10f %0.4f-%0.4f-%0.4f", tick - t, pp.X - pos.X, pp.Y - pos.Y, pp.Z - pos.Z))
			pp = pos
			t = tick
		end
	end)
end

local function SetupASignVisually(part: Part)
	if enums.unanchoredSignNames[part.Name] then
		part.Anchored = false
	else
		part.Anchored = true
	end

	part.Material = Enum.Material.Granite
	part.Color = Color3.fromRGB(255, 89, 89)

	local childs = part:GetChildren()
	for _, child in ipairs(childs) do
		child:Destroy()
	end

	local sguiName = "SignGui_" .. part.Name
	local sGui = Instance.new("SurfaceGui")
	sGui.Name = sguiName
	sGui.Parent = part

	local canvasSize: Vector2

	if enums.useLeftFaceSignNames[part.Name] then
		canvasSize = Vector2.new(part.Size.Y * 30, part.Size.X * 30)
		sGui.Face = Enum.NormalId.Left
	else
		canvasSize = Vector2.new(part.Size.Z * 30, part.Size.X * 30)
		sGui.Face = Enum.NormalId.Top
	end
	sGui.CanvasSize = canvasSize
	sGui.Brightness = 1.5

	sGui.Parent.TopSurface = Enum.SurfaceType.Smooth
	sGui.Parent.BottomSurface = Enum.SurfaceType.Smooth
	sGui.Parent.LeftSurface = Enum.SurfaceType.Smooth
	sGui.Parent.RightSurface = Enum.SurfaceType.Smooth
	sGui.Parent.FrontSurface = Enum.SurfaceType.Smooth
	sGui.Parent.BackSurface = Enum.SurfaceType.Smooth

	local children = sGui:GetChildren()
	for _, c in ipairs(children) do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end

	local textLabel = Instance.new("TextLabel")
	textLabel.Parent = sGui
	textLabel.AutoLocalize = true
	textLabel.Text = part.Name
	textLabel.Font = Enum.Font.Gotham
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.TextScaled = true
	textLabel.RichText = true
	textLabel.TextColor3 = colors.signTextColor
	--I shold add a touch sound TODO
	--i should add a touch visual +3 years good idea.
end

--for dev only, if you forgot this.
local function checkMissingSigns()
	local signFolder = game.Workspace:FindFirstChild("Signs")
	local badct = 0
	for signId, signName in ipairs(enums.signId2name) do
		local exiSign = signFolder:FindFirstChild(signName)
		if not exiSign then
			badct += 1
			if badct > 2 then
				break
			end
			if not config.isTestGame() then
				warn("did you remember to put the sign " .. signName .. " into workspace.Signs?")
			end
		end
	end
end

module.Init = function()
	signMovement.setupGrowingDistantPinnacle()

	for _, sign: Part in ipairs(game.Workspace:WaitForChild("Signs"):GetChildren()) do
		SetupASignVisually(sign)
		local signId = enums.name2signId[sign.Name]
		if signId == nil then
			warn("bad" .. tostring(sign.Name))
			continue
		end
		signInfo.storeSignPositionInMemory(signId, sign.Position)
	end

	--we set them up after all the normal stuff is done.

	checkMissingSigns()
end

_annotate("end")
return module
