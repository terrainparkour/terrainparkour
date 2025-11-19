--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayerService = game:GetService("Players")
local enums = require(game.ReplicatedStorage.util.enums)

local signInfo = require(game.ReplicatedStorage.signInfo)
local colors = require(game.ReplicatedStorage.util.colors)

local config = require(game.ReplicatedStorage.config)

local _ = require(game.ServerScriptService.setupSpecialSigns)

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

			-- if player == nil then
			-- 	continue
			-- end
			if player.Character == nil then
				continue
			end
			local character: Model? = player.Character
			if not character then
				continue
			end
			local rootPartInstance: Instance? = character:FindFirstChild("HumanoidRootPart")
			if not rootPartInstance or not rootPartInstance:IsA("BasePart") then
				continue
			end
			local rootPart: BasePart = rootPartInstance :: BasePart
			local tick = tick()
			local pos: Vector3 = rootPart.Position
			_annotate(string.format("%0.10f %0.4f-%0.4f-%0.4f", tick - t, pp.X - pos.X, pp.Y - pos.Y, pp.Z - pos.Z))
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

	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.LeftSurface = Enum.SurfaceType.Smooth
	part.RightSurface = Enum.SurfaceType.Smooth
	part.FrontSurface = Enum.SurfaceType.Smooth
	part.BackSurface = Enum.SurfaceType.Smooth

	local signGuiName = "SignGui_" .. part.Name
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = signGuiName
	surfaceGui.Parent = part

	local canvasSize: Vector2 = Vector2.new(part.Size.Z * 30, part.Size.X * 30)
	if enums.useLeftFaceSignNames[part.Name] then
		canvasSize = Vector2.new(part.Size.Y * 30, part.Size.X * 30)
		surfaceGui.Face = Enum.NormalId.Left
	elseif enums.usesBackFaceSignNames[part.Name] then
		canvasSize = Vector2.new(part.Size.Y * 30, part.Size.X * 30)
		surfaceGui.Face = Enum.NormalId.Back
	else
		canvasSize = Vector2.new(part.Size.Z * 30, part.Size.X * 30)
		if part.Name ~= "Zoom" then
			surfaceGui.Face = Enum.NormalId.Top
		end
	end

	surfaceGui.CanvasSize = canvasSize
	surfaceGui.Brightness = 1.5

	local children = surfaceGui:GetChildren()
	for _, c in ipairs(children) do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end

	local textLabel = Instance.new("TextLabel")
	textLabel.Parent = surfaceGui
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

	local extraSetupCallback = enums.signNameToExtraVisualSetupCallback[part.Name]
	if extraSetupCallback then
		extraSetupCallback(part)
	end
end

--for dev only, if you forgot this.
local function checkMissingSigns()
	local signFolder = game.Workspace:FindFirstChild("Signs")
	if signFolder == nil then
		annotater.Error("no sign folder")
		return
	end
	local badct = 0
	for signId, signName in pairs(enums.signId2name) do
		local exiSignInstance: Instance? = signFolder:FindFirstChild(signName)
		if not exiSignInstance or not exiSignInstance:IsA("Part") then
			badct += 1
			if badct > 1 then
				break
			end
			if not config.IsTestGame() then
				warn("did you remember to put the sign " .. signName .. " into workspace.Signs?")
			end
		end
	end
end

module.Init = function()
	_annotate("init")
	for _, signInstance: Instance in ipairs(game.Workspace:WaitForChild("Signs"):GetChildren()) do
		if not signInstance:IsA("Part") then
			continue
		end
		local sign: Part = signInstance :: Part
		if
			not sign:IsA("Part")
			and not sign:IsA("Model")
			and not sign:IsA("MeshPart")
			and not sign:IsA("UnionOperation")
		then
			warn("bad thing " .. sign.Name)
			continue
		end
		local signId = enums.name2signId[sign.Name]
		if signId == nil then
			warn("bad" .. tostring(sign.Name))
			continue
		end
		SetupASignVisually(sign)
		signInfo.storeSignPositionInMemory(signId, sign.Position)
	end

	--we set them up after all the normal stuff is done.

	checkMissingSigns()
	_annotate("init done")
end

_annotate("end")
return module
