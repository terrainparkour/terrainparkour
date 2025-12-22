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
			task.wait(1 / 1000.0)

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

--[[
	Sign Label Positioning via Attributes (for MeshParts and unusual shapes):
	
	Add these attributes to a sign in Studio to customize label placement:
	- LabelOffset (Vector3): Offset from sign center for BillboardGui placement
	- LabelSize (Vector2): Billboard size in studs (default: 6x1.5)
	- LabelRotation (Vector3): Euler angles for label orientation (optional, for fixed labels)
	
	Example for a pyramid:
	- LabelOffset = Vector3.new(0, -1.5, 2) -- down from apex, forward on face
	- LabelSize = Vector2.new(8, 2)
	
	When LabelOffset is present, uses BillboardGui instead of SurfaceGui.
]]

local DEFAULT_LABEL_SIZE = Vector2.new(6, 1.5)

local function createBillboardLabel(sign: BasePart, offset: Vector3, labelSize: Vector2?)
	local size = labelSize or DEFAULT_LABEL_SIZE

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SignBillboard_" .. sign.Name
	billboard.Adornee = sign
	billboard.StudsOffset = offset
	billboard.Size = UDim2.new(0, size.X * 10, 0, size.Y * 10) -- Scale for pixel density
	billboard.LightInfluence = 0
	billboard.AlwaysOnTop = false
	billboard.ResetOnSpawn = false
	billboard.Parent = sign

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "SignText"
	textLabel.Parent = billboard
	textLabel.Text = sign.Name
	textLabel.Font = Enum.Font.Gotham
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.TextScaled = true
	textLabel.RichText = true
	textLabel.TextColor3 = colors.signTextColor
	textLabel.TextStrokeTransparency = 0.15
	textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
end

local function SetupASignVisually(sign: BasePart)
	if enums.unanchoredSignNames[sign.Name] then
		sign.Anchored = false
	else
		sign.Anchored = true
	end

	sign.Material = Enum.Material.Granite
	sign.Color = Color3.fromRGB(255, 89, 89)

	-- Remove existing GUI children
	for _, child in ipairs(sign:GetChildren()) do
		if child:IsA("SurfaceGui") or child:IsA("BillboardGui") then
			child:Destroy()
		end
	end

	-- Check for custom label positioning via attributes
	local labelOffset = sign:GetAttribute("LabelOffset") :: Vector3?
	if labelOffset then
		local labelSize = sign:GetAttribute("LabelSize") :: Vector2?
		createBillboardLabel(sign, labelOffset, labelSize)

		-- Still run extra setup callback if present
		local extraSetupCallback = enums.signNameToExtraVisualSetupCallback[sign.Name]
		if extraSetupCallback then
			extraSetupCallback(sign)
		end
		return
	end

	-- MeshParts without LabelOffset attribute: use billboard at center-top
	if sign:IsA("MeshPart") then
		local halfHeight = sign.Size.Y / 2
		createBillboardLabel(sign, Vector3.new(0, halfHeight + 1, 0), nil)

		local extraSetupCallback = enums.signNameToExtraVisualSetupCallback[sign.Name]
		if extraSetupCallback then
			extraSetupCallback(sign)
		end
		return
	end

	-- Standard Part: use SurfaceGui on appropriate face
	local part = sign :: Part
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
		-- Skip disabled signs - they don't need physical instances
		if enums.disabledSignNames[signName:lower()] then
			continue
		end
		local exiSignInstance: Instance? = signFolder:FindFirstChild(signName)
		-- Accept Part, MeshPart, or any BasePart type
		if not exiSignInstance or not exiSignInstance:IsA("BasePart") then
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
		-- Accept Part, MeshPart, or any BasePart type
		if not signInstance:IsA("BasePart") then
			continue
		end
		local sign: BasePart = signInstance :: BasePart
		local signId = enums.name2signId[sign.Name]
		if signId == nil then
			warn("bad" .. tostring(sign.Name))
			continue
		end

		-- Skip visual setup for disabled signs - they should be invisible and untouchable
		if enums.disabledSignNames[sign.Name:lower()] then
			sign.Transparency = 1
			sign.CanCollide = false
			sign.CanTouch = false
			sign.CanQuery = false
			-- Remove any existing children (SurfaceGuis, etc.)
			for _, child in ipairs(sign:GetChildren()) do
				child:Destroy()
			end
			continue
		end

		-- Setup visual label for Parts and MeshParts
		if sign:IsA("Part") or sign:IsA("MeshPart") then
			SetupASignVisually(sign)
		end
		signInfo.storeSignPositionInMemory(signId, sign.Position)
	end

	--we set them up after all the normal stuff is done.

	checkMissingSigns()
	_annotate("init done")
end

_annotate("end")
return module
