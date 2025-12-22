--!strict
-- adminHelpTools.lua @ StarterPlayer.StarterCharacterScripts.client.adminHelpTools
-- Studio-only admin panel with quick action buttons for development testing.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local colors = require(game.ReplicatedStorage.util.colors)
local config = require(game.ReplicatedStorage.config)
local enums = require(game.ReplicatedStorage.util.enums)
local movementEnums = require(game.StarterPlayer.StarterPlayerScripts.movementEnums)
local _particleEnums = require(game.StarterPlayer.StarterPlayerScripts.particleEnums)
local remotes = require(game.ReplicatedStorage.util.remotes)
local settings = require(game.ReplicatedStorage.settings)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local tt = require(game.ReplicatedStorage.types.gametypes)
local warper = require(game.StarterPlayer.StarterCharacterScripts.client.warper)
local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)
local wt = require(game.StarterPlayer.StarterPlayerScripts.guis.windowsTypes)

-- Module internals
local localPlayer = Players.LocalPlayer
local GenericClientUIFunction = remotes.getRemoteFunction("GenericClientUIFunction")
local activeGui: ScreenGui? = nil

-- Admin ability state
local flyEnabled = false
local flyConnection: RBXScriptConnection? = nil
local flyBodyVelocity: BodyVelocity? = nil
local flyBodyGyro: BodyGyro? = nil
local speedMultiplierActive = false
local superJumpActive = false
local randomParticleEmitters: { ParticleEmitter } = {}

-- Sign IDs for test race
local ORTHANC_SIGN_ID = tpUtil.signName2SignId("Orthanc")
local CRATER_SIGN_ID = tpUtil.signName2SignId("Crater")

-- Build list of last N added signs (highest sign IDs)
local WARP_SIGN_COUNT = 10
local function getLastAddedSignIds(): { { signId: number, signName: string } }
	local signIds: { number } = {}
	for _, signId in pairs(enums.name2signId) do
		table.insert(signIds, signId)
	end
	table.sort(signIds, function(a, b)
		return a > b
	end)
	local result: { { signId: number, signName: string } } = {}
	for i = 1, math.min(WARP_SIGN_COUNT, #signIds) do
		local signId = signIds[i]
		local signName = enums.signId2name[signId] or "?"
		table.insert(result, { signId = signId, signName = signName })
	end
	return result
end

local lastAddedSigns = getLastAddedSignIds()

-- Data request helpers
local function requestRunResults(startSignId: number, endSignId: number)
	local success = GenericClientUIFunction:InvokeServer({
		eventKind = "runResultsRequest",
		data = {
			userId = localPlayer.UserId,
			startSignId = startSignId,
			endSignId = endSignId,
		},
	})
	if not success then
		warn("Failed to request run results")
	end
end

local function requestWRProgressionChart(startSignId: number, endSignId: number)
	local success = GenericClientUIFunction:InvokeServer({
		eventKind = "wrProgressionChartRequest",
		data = {
			startSignId = startSignId,
			endSignId = endSignId,
		},
	})
	if not success then
		warn("Failed to request WR progression chart")
	end
end

local function requestLogSignData()
	_annotate("Requesting sign data export...")
	local success = GenericClientUIFunction:InvokeServer({
		eventKind = "logSignDataRequest",
		data = {},
	})
	if success then
		_annotate("Sign data export complete - check Output window")
	else
		warn("Failed to export sign data")
	end
end

-- Nuke test user: deletes all DB data for TerrainParkour, resetting to new user state
-- Only works in Studio, only for the hardcoded test user
local function requestNukeTestUser()
	-- Safety check on client side too (server has its own checks)
	if not config.IsInStudio() then
		warn("NukeTestUser rejected: not in Studio")
		return
	end
	if localPlayer.UserId ~= enums.objects.TerrainParkourUserId then
		warn(string.format("NukeTestUser rejected: userId %d != %d", localPlayer.UserId, enums.objects.TerrainParkourUserId))
		return
	end

	_annotate("NUKING TEST USER - deleting all database history...")
	local result = GenericClientUIFunction:InvokeServer({
		eventKind = "nukeTestUserRequest",
		data = {},
	})

	if result and result.res then
		_annotate(string.format("NUKE COMPLETE: deleted %d records. Rejoin game to see fresh state.", result.totalDeleted or 0))
		print(string.format("=== NUKE COMPLETE: deleted %d records ===", result.totalDeleted or 0))
		print("Rejoin the game to see fresh user state.")
	else
		local errMsg = result and result.error or "unknown error"
		warn(string.format("NUKE FAILED: %s", errMsg))
	end
end

-- Avatar ability helpers
local function getHumanoidAndRoot(): (Humanoid?, BasePart?)
	local character = localPlayer.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return humanoid, rootPart
end

local function enableFly()
	local humanoid, rootPart = getHumanoidAndRoot()
	if not humanoid or not rootPart then
		warn("Cannot enable fly: no character")
		return
	end

	flyEnabled = true
	humanoid.PlatformStand = true

	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bv.Velocity = Vector3.zero
	bv.Parent = rootPart
	flyBodyVelocity = bv

	local bg = Instance.new("BodyGyro")
	bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	bg.P = 10000
	bg.D = 500
	bg.Parent = rootPart
	flyBodyGyro = bg

	local flySpeed = 100

	flyConnection = RunService.RenderStepped:Connect(function()
		if not flyEnabled then
			return
		end
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end

		local moveDirection = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			moveDirection = moveDirection + camera.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			moveDirection = moveDirection - camera.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			moveDirection = moveDirection - camera.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			moveDirection = moveDirection + camera.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.E) then
			moveDirection = moveDirection + Vector3.new(0, 1, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Q) then
			moveDirection = moveDirection - Vector3.new(0, 1, 0)
		end

		if moveDirection.Magnitude > 0 then
			moveDirection = moveDirection.Unit * flySpeed
		end

		if flyBodyVelocity then
			flyBodyVelocity.Velocity = moveDirection
		end
		if flyBodyGyro then
			flyBodyGyro.CFrame = CFrame.new(Vector3.zero, camera.CFrame.LookVector)
		end
	end)

	_annotate("Fly enabled")
end

local function disableFly()
	flyEnabled = false

	if flyConnection then
		flyConnection:Disconnect()
		flyConnection = nil
	end
	if flyBodyVelocity then
		flyBodyVelocity:Destroy()
		flyBodyVelocity = nil
	end
	if flyBodyGyro then
		flyBodyGyro:Destroy()
		flyBodyGyro = nil
	end

	local humanoid, _ = getHumanoidAndRoot()
	if humanoid then
		humanoid.PlatformStand = false
	end

	_annotate("Fly disabled")
end

local function toggleFly()
	if flyEnabled then
		disableFly()
	else
		enableFly()
	end
end

local function toggle2xSpeed()
	local humanoid, _ = getHumanoidAndRoot()
	if not humanoid then
		return
	end

	speedMultiplierActive = not speedMultiplierActive
	if speedMultiplierActive then
		humanoid.WalkSpeed = movementEnums.constants.globalDefaultRunSpeed * 2
		_annotate("2x speed enabled")
	else
		humanoid.WalkSpeed = movementEnums.constants.globalDefaultRunSpeed
		_annotate("2x speed disabled")
	end
end

local function toggleSuperJump()
	local humanoid, _ = getHumanoidAndRoot()
	if not humanoid then
		return
	end

	superJumpActive = not superJumpActive
	if superJumpActive then
		humanoid.JumpPower = movementEnums.constants.globalDefaultJumpPower * 4
		_annotate("Superjump (4x) enabled")
	else
		humanoid.JumpPower = movementEnums.constants.globalDefaultJumpPower
		_annotate("Superjump disabled")
	end
end

local function resetAllAbilities()
	if flyEnabled then
		disableFly()
	end
	speedMultiplierActive = false
	superJumpActive = false
	local humanoid, _ = getHumanoidAndRoot()
	if humanoid then
		humanoid.WalkSpeed = movementEnums.constants.globalDefaultRunSpeed
		humanoid.JumpPower = movementEnums.constants.globalDefaultJumpPower
	end
	for _, emitter in ipairs(randomParticleEmitters) do
		emitter:Destroy()
	end
	randomParticleEmitters = {}
	_annotate("All admin abilities reset")
end

local function printParticleDescriptorToOutput(desc: tt.particleDescriptor)
	print("=== RANDOM PARTICLE CONFIG ===")
	local keys = {}
	for key in pairs(desc :: any) do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		local value = (desc :: any)[key]
		if typeof(value) == "Vector3" then
			print(string.format("  %s = Vector3.new(%.4f, %.4f, %.4f)", key, value.X, value.Y, value.Z))
		elseif typeof(value) == "Color3" then
			print(string.format("  %s = Color3.new(%.4f, %.4f, %.4f)", key, value.R, value.G, value.B))
		elseif typeof(value) == "NumberRange" then
			print(string.format("  %s = NumberRange.new(%.4f, %.4f)", key, value.Min, value.Max))
		elseif typeof(value) == "NumberSequence" then
			local kp = value.Keypoints
			print(string.format("  %s = NumberSequence.new(%.4f, %.4f)", key, kp[1].Value, kp[#kp].Value))
		elseif typeof(value) == "Vector2" then
			print(string.format("  %s = Vector2.new(%.4f, %.4f)", key, value.X, value.Y))
		elseif typeof(value) == "EnumItem" then
			print(string.format("  %s = %s", key, tostring(value)))
		else
			print(string.format("  %s = %s", key, tostring(value)))
		end
	end
	print("=== END CONFIG ===")
end

-- Valid Roblox particle textures (default and built-in)
local VALID_PARTICLE_TEXTURES = {
	"rbxassetid://6891091908", -- default spark
	"rbxassetid://243098098", -- circle
	"rbxassetid://241779220", -- smoke
	"rbxassetid://243132757", -- star
	"rbxassetid://288981766", -- heart
	"rbxassetid://241685484", -- sparkle
	"rbxassetid://2273224484", -- soft glow
	"rbxassetid://1084969997", -- trail
	"", -- empty = default white square
}

local particleAddCounter = 0

-- Spherical/round shapes only
local ROUND_SHAPES = {
	Enum.ParticleEmitterShape.Sphere,
	Enum.ParticleEmitterShape.Cylinder,
	Enum.ParticleEmitterShape.Disc,
}

local function getVisibleRandomParticleDescriptor(): tt.particleDescriptor
	particleAddCounter += 1
	local random = Random.new(tick() + particleAddCounter * 1000)

	local function getPairs(minn: number, maxx: number): (number, number)
		local a = random:NextNumber(minn, maxx)
		local b = random:NextNumber(minn, maxx)
		return math.min(a, b), math.max(a, b)
	end

	local lifetimeMin, lifetimeMax = getPairs(1, 10)
	local rotMin, rotMax = getPairs(0, 360)
	local speedMin, speedMax = getPairs(0, 50)
	local rotSpeedMin, rotSpeedMax = getPairs(0, 500)

	-- Ensure visible color (not too dark)
	local r = random:NextNumber(0.3, 1)
	local g = random:NextNumber(0.3, 1)
	local b = random:NextNumber(0.3, 1)

	-- Size: full range (0.1 to 10)
	local sizeStart = random:NextNumber(0.1, 10)
	local sizeEnd = random:NextNumber(0.1, 10)

	-- Transparency: full range (0 to 1)
	local transpStart = random:NextNumber(0, 1)
	local transpEnd = random:NextNumber(0, 1)

	-- Squash closer to 1 for rounder particles (0.5 to 2 instead of 0.1 to 10)
	local squashStart = random:NextNumber(0.5, 2)
	local squashEnd = random:NextNumber(0.5, 2)

	local desc: tt.particleDescriptor = {
		acceleration = Vector3.new(random:NextNumber(-10, 10), random:NextNumber(-10, 10), random:NextNumber(-10, 10)),
		brightness = random:NextNumber(0, 100),
		color = Color3.new(r, g, b),
		direction = Enum.NormalId:GetEnumItems()[random:NextInteger(1, #Enum.NormalId:GetEnumItems())],
		drag = random:NextNumber(0, 5),
		durationMETA = 999,
		emissionDirection = Enum.NormalId:GetEnumItems()[random:NextInteger(1, #Enum.NormalId:GetEnumItems())],
		lifetime = NumberRange.new(lifetimeMin, lifetimeMax),
		name = string.format("admin_random_%d", particleAddCounter),
		orientation = Enum.ParticleOrientation:GetEnumItems()[random:NextInteger(1, #Enum.ParticleOrientation:GetEnumItems())],
		rate = random:NextNumber(1, 100),
		rotation = NumberRange.new(rotMin, rotMax),
		rotSpeed = NumberRange.new(rotSpeedMin, rotSpeedMax),
		shape = ROUND_SHAPES[random:NextInteger(1, #ROUND_SHAPES)],
		shapeInOut = Enum.ParticleEmitterShapeInOut.Outward, -- Always shoot outward
		shapeStyle = Enum.ParticleEmitterShapeStyle:GetEnumItems()[random:NextInteger(1, #Enum.ParticleEmitterShapeStyle:GetEnumItems())],
		size = NumberSequence.new(sizeStart, sizeEnd),
		speed = NumberRange.new(speedMin, speedMax),
		spreadAngle = Vector2.new(random:NextNumber(0, 180), random:NextNumber(0, 180)),
		squash = NumberSequence.new(squashStart, squashEnd),
		texture = VALID_PARTICLE_TEXTURES[random:NextInteger(1, #VALID_PARTICLE_TEXTURES)],
		transparency = NumberSequence.new(transpStart, transpEnd),
		velocityInheritance = random:NextNumber(0, 1),
		zOffset = random:NextNumber(-10, 10),
		lightEmission = random:NextNumber(0, 1),
	}

	return desc
end

local function createEmitterFromDescriptor(desc: tt.particleDescriptor, rootPart: BasePart): ParticleEmitter
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
	emitter.Parent = rootPart
	return emitter
end

local function addOneRandomParticle()
	local _, rootPart = getHumanoidAndRoot()
	if not rootPart then
		warn("Cannot create random particle: no character root part")
		return
	end

	local desc = getVisibleRandomParticleDescriptor()
	print(string.format("\n=== ADDING PARTICLE #%d ===", #randomParticleEmitters + 1))
	printParticleDescriptorToOutput(desc)
	local emitter = createEmitterFromDescriptor(desc, rootPart)
	table.insert(randomParticleEmitters, emitter)
	print(string.format("Total active emitters: %d", #randomParticleEmitters))
end

local function clearAllRandomParticles()
	local count = #randomParticleEmitters
	for _, emitter in ipairs(randomParticleEmitters) do
		emitter:Destroy()
	end
	randomParticleEmitters = {}
	particleAddCounter = 0
	print(string.format("=== CLEARED %d PARTICLE EMITTERS ===", count))
end

-- Section padding constant
local SECTION_PADDING = 5

-- Helper to create a spacer row for vertical separation between sections
local function createSectionSpacer(order: number): wt.rowSpec
	return {
		name = string.format("Spacer_%d", order),
		order = order,
		height = UDim.new(0, SECTION_PADDING),
		tileSpecs = {
			{
				name = "SpacerFill",
				order = 1,
				width = UDim.new(1, 0),
				spec = {
					type = "text",
					text = "",
					backgroundColor = colors.defaultGrey,
				} :: wt.textTileSpec,
			},
		},
	}
end

-- Helper to create a section header row
local function createSectionHeader(text: string, order: number): wt.rowSpec
	return {
		name = "Header_" .. text,
		order = order,
		height = UDim.new(0, 24),
		tileSpecs = {
			{
				name = "HeaderText",
				order = 1,
				width = UDim.new(1, 0),
				spec = {
					type = "text",
					text = text,
					isMonospaced = false,
					isBold = true,
					backgroundColor = colors.blueDone,
					textColor = colors.black,
					textXAlignment = Enum.TextXAlignment.Center,
					leftPadding = SECTION_PADDING,
					rightPadding = SECTION_PADDING,
				},
			},
		},
	}
end

-- Helper to create a row of compact buttons with 5px padding on each side
local function createButtonRow(buttons: { { text: string, onClick: () -> (), color: Color3? } }, order: number): wt.rowSpec
	local tileSpecs: { wt.tileSpec } = {}

	-- Left spacer for padding
	table.insert(tileSpecs, {
		name = "LeftSpacer",
		order = 0,
		width = UDim.new(0, SECTION_PADDING),
		spec = {
			type = "text",
			text = "",
			backgroundColor = colors.defaultGrey,
		} :: wt.textTileSpec,
	})

	-- Buttons (share remaining width equally)
	local buttonWidthScale = 1 / #buttons
	for i, btn in ipairs(buttons) do
		local buttonSpec: wt.buttonTileSpec = {
			type = "button",
			text = btn.text,
			backgroundColor = btn.color or colors.WRProgressionColor,
			textColor = colors.black,
			isMonospaced = false,
			isBold = false,
			textXAlignment = Enum.TextXAlignment.Center,
			onClick = function()
				_annotate(string.format("Admin button: %s", btn.text))
				btn.onClick()
			end,
		}
		table.insert(tileSpecs, {
			name = string.format("Btn_%d", i),
			order = i,
			width = UDim.new(buttonWidthScale, -SECTION_PADDING * 2 / #buttons), -- Reduce to account for spacers
			spec = buttonSpec,
		})
	end

	-- Right spacer for padding
	table.insert(tileSpecs, {
		name = "RightSpacer",
		order = #buttons + 1,
		width = UDim.new(0, SECTION_PADDING),
		spec = {
			type = "text",
			text = "",
			backgroundColor = colors.defaultGrey,
		} :: wt.textTileSpec,
	})

	return {
		name = string.format("ButtonRow_%d", order),
		order = order,
		height = UDim.new(0, 32),
		tileSpecs = tileSpecs,
	}
end

-- Helper to create warp button row with 5px padding on each side
local function createWarpButtonRow(signs: { { signId: number, signName: string } }, order: number): wt.rowSpec
	local tileSpecs: { wt.tileSpec } = {}

	-- Left spacer for padding
	table.insert(tileSpecs, {
		name = "LeftSpacer",
		order = 0,
		width = UDim.new(0, SECTION_PADDING),
		spec = {
			type = "text",
			text = "",
			backgroundColor = colors.defaultGrey,
		} :: wt.textTileSpec,
	})

	-- Warp buttons (share remaining width equally)
	local buttonWidthScale = 1 / #signs
	for i, signData in ipairs(signs) do
		local buttonSpec: wt.buttonTileSpec = {
			type = "button",
			text = signData.signName,
			backgroundColor = colors.warpColor,
			textColor = colors.black,
			isMonospaced = false,
			isBold = false,
			textXAlignment = Enum.TextXAlignment.Center,
			onClick = function()
				_annotate(string.format("Warping to: %s", signData.signName))
				warper.WarpToSignId(signData.signId)
			end,
		}
		table.insert(tileSpecs, {
			name = string.format("Warp_%d", signData.signId),
			order = i,
			width = UDim.new(buttonWidthScale, -SECTION_PADDING * 2 / #signs), -- Reduce to account for spacers
			spec = buttonSpec,
		})
	end

	-- Right spacer for padding
	table.insert(tileSpecs, {
		name = "RightSpacer",
		order = #signs + 1,
		width = UDim.new(0, SECTION_PADDING),
		spec = {
			type = "text",
			text = "",
			backgroundColor = colors.defaultGrey,
		} :: wt.textTileSpec,
	})

	return {
		name = string.format("WarpRow_%d", order),
		order = order,
		height = UDim.new(0, 32),
		tileSpecs = tileSpecs,
	}
end

local function showAdminPanel()
	if activeGui then
		activeGui:Destroy()
		activeGui = nil
	end

	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end

	local rowSpecs: { wt.rowSpec } = {}

	-- Title row
	table.insert(rowSpecs, {
		name = "TitleRow",
		order = 1,
		height = UDim.new(0, 32),
		tileSpecs = {
			{
				name = "Title",
				order = 1,
				width = UDim.new(1, 0),
				spec = {
					type = "text",
					text = "Admin Tools (Studio)",
					isMonospaced = false,
					isBold = true,
					backgroundColor = colors.signColor,
					textColor = colors.white,
					textXAlignment = Enum.TextXAlignment.Center,
					leftPadding = SECTION_PADDING,
					rightPadding = SECTION_PADDING,
				},
			},
		},
	})

	-- Show by default toggle row
	local showByDefaultSetting = settings.GetSettingByName(settingEnums.settingDefinitions.SHOW_ADMIN_TOOLS_BY_DEFAULT.name)
	local currentShowByDefault = if showByDefaultSetting and showByDefaultSetting.booleanValue ~= nil then showByDefaultSetting.booleanValue else true
	table.insert(rowSpecs, {
		name = "ShowByDefaultRow",
		order = 2,
		height = UDim.new(0, 28),
		tileSpecs = {
			{
				name = "LeftSpacer",
				order = 0,
				width = UDim.new(0, SECTION_PADDING),
				spec = {
					type = "text",
					text = "",
					backgroundColor = colors.defaultGrey,
				} :: wt.textTileSpec,
			},
			{
				name = "ShowByDefaultLabel",
				order = 1,
				width = UDim.new(0.7, -SECTION_PADDING),
				spec = {
					type = "text",
					text = "Show by default on startup:",
					isMonospaced = false,
					isBold = false,
					backgroundColor = colors.defaultGrey,
					textColor = colors.white,
					textXAlignment = Enum.TextXAlignment.Left,
					leftPadding = SECTION_PADDING,
				},
			},
			{
				name = "ShowByDefaultToggle",
				order = 2,
				width = UDim.new(0.3, -SECTION_PADDING),
				spec = {
					type = "button",
					text = if currentShowByDefault then "ON" else "OFF",
					backgroundColor = if currentShowByDefault then colors.lightGreen else colors.lightRed,
					textColor = colors.black,
					isMonospaced = false,
					isBold = true,
					textXAlignment = Enum.TextXAlignment.Center,
					onClick = function()
						local newValue = not currentShowByDefault
						local newSetting: tt.userSettingValue = {
							name = settingEnums.settingDefinitions.SHOW_ADMIN_TOOLS_BY_DEFAULT.name,
							domain = settingEnums.settingDefinitions.SHOW_ADMIN_TOOLS_BY_DEFAULT.domain,
							kind = settingEnums.settingKinds.BOOLEAN,
							booleanValue = newValue,
						}
						settings.SetSetting(newSetting)
						_annotate(string.format("Show admin tools by default: %s", tostring(newValue)))
						-- Rebuild the panel to reflect the change
						showAdminPanel()
					end,
				} :: wt.buttonTileSpec,
			},
			{
				name = "RightSpacer",
				order = 3,
				width = UDim.new(0, SECTION_PADDING),
				spec = {
					type = "text",
					text = "",
					backgroundColor = colors.defaultGrey,
				} :: wt.textTileSpec,
			},
		},
	})

	-- Section: Data Export (with spacer before)
	table.insert(rowSpecs, createSectionSpacer(3))
	table.insert(rowSpecs, createSectionHeader("Data Export", 4))

	table.insert(
		rowSpecs,
		createButtonRow({
			{
				text = "Export Sign Data",
				onClick = requestLogSignData,
				color = colors.defaultGrey,
			},
		}, 5)
	)

	-- Section: Race Data (with spacer before)
	table.insert(rowSpecs, createSectionSpacer(6))
	table.insert(rowSpecs, createSectionHeader("Race Data", 7))

	table.insert(
		rowSpecs,
		createButtonRow({
			{
				text = "Res: Orthanc-Crater",
				onClick = function()
					requestRunResults(ORTHANC_SIGN_ID, CRATER_SIGN_ID)
				end,
			},
			{
				text = "WR Chart: Orthanc-Crater",
				onClick = function()
					requestWRProgressionChart(ORTHANC_SIGN_ID, CRATER_SIGN_ID)
				end,
			},
		}, 8)
	)

	-- Section: Avatar Powers (with spacer before)
	table.insert(rowSpecs, createSectionSpacer(9))
	table.insert(rowSpecs, createSectionHeader("Avatar Powers", 10))

	table.insert(
		rowSpecs,
		createButtonRow({
			{ text = "Fly", onClick = toggleFly, color = colors.lightGreen },
			{ text = "2x Speed", onClick = toggle2xSpeed, color = colors.lightGreen },
			{ text = "4x Jump", onClick = toggleSuperJump, color = colors.lightGreen },
			{ text = "Reset", onClick = resetAllAbilities, color = colors.lightRed },
		}, 11)
	)

	table.insert(
		rowSpecs,
		createButtonRow({
			{ text = "+1 Particle", onClick = addOneRandomParticle, color = colors.magenta },
			{ text = "Clear Particles", onClick = clearAllRandomParticles, color = colors.lightRed },
		}, 12)
	)

	-- Section: Recent Signs (with spacer before)
	table.insert(rowSpecs, createSectionSpacer(13))
	table.insert(rowSpecs, createSectionHeader("Recent Signs (last 10)", 14))

	-- Add warp button rows (5 buttons per row)
	local buttonsPerRow = 5
	local currentOrder = 15
	for i = 1, #lastAddedSigns, buttonsPerRow do
		local rowSigns: { { signId: number, signName: string } } = {}
		for j = i, math.min(i + buttonsPerRow - 1, #lastAddedSigns) do
			table.insert(rowSigns, lastAddedSigns[j])
		end
		table.insert(rowSpecs, createWarpButtonRow(rowSigns, currentOrder))
		currentOrder += 1
	end

	-- Section: Danger Zone (only for TerrainParkour test user)
	if localPlayer.UserId == enums.objects.TerrainParkourUserId then
		table.insert(rowSpecs, createSectionSpacer(currentOrder))
		currentOrder += 1
		table.insert(rowSpecs, createSectionHeader("DANGER ZONE", currentOrder))
		currentOrder += 1

		table.insert(
			rowSpecs,
			createButtonRow({
				{
					text = "NUKE TerrainParkour (delete this user DB data)",
					onClick = requestNukeTestUser,
					color = Color3.fromRGB(200, 50, 50), -- dark red
				},
			}, currentOrder)
		)
		currentOrder += 1
	end

	-- Close button row (not a section - standard footer, full width)
	table.insert(rowSpecs, {
		name = "CloseRow",
		order = currentOrder,
		height = UDim.new(0, 28),
		tileSpecs = { windows.StandardCloseButton },
	})

	local guiSpec: wt.guiSpec = {
		name = "AdminTools",
		rowSpecs = rowSpecs,
	}

	-- Calculate height dynamically based on actual rows: sum all row heights
	local totalHeight = 0
	for _, rowSpec in ipairs(rowSpecs) do
		totalHeight = totalHeight + rowSpec.height.Offset
	end

	local popupResult = windows.CreatePopup(
		guiSpec,
		"AdminToolsPopup",
		true, -- draggable
		true, -- resizable
		false, -- minimizable
		false, -- pinnable
		true, -- dismissableWithX
		false, -- dismissableByClick
		UDim2.fromOffset(400, totalHeight),
		nil, -- intendedRowsOfScrollingFrameToShow - nil means use default behavior for fixed-row layouts
		{
			settingName = "ADMIN_TOOLS_GUI_LAYOUT",
			settingKey = "position",
			saveSize = true,
			sizeKey = "size",
			clampOnLoad = true,
			defaultPosition = UDim2.fromScale(0.01, 0.35), -- middle-left of screen
		}
	)
	local popup = popupResult.sgui

	activeGui = popup
	popup.Parent = playerGui
	_annotate("Admin tools panel shown")
end

local function hideAdminPanel()
	if activeGui then
		activeGui:Destroy()
		activeGui = nil
		_annotate("Admin tools panel hidden")
	end
end

-- Module API
type Module = {
	Init: () -> (),
	Show: () -> (),
	Hide: () -> (),
	Toggle: () -> (),
}

local module: Module = {} :: Module

module.Init = function()
	if not config.IsInStudio() then
		_annotate("Not in Studio, skipping admin tools")
		return
	end

	_annotate("Initializing admin tools (Studio only)")
	task.defer(function()
		local showByDefaultSetting = settings.GetSettingByName(settingEnums.settingDefinitions.SHOW_ADMIN_TOOLS_BY_DEFAULT.name)
		local shouldShow = if showByDefaultSetting and showByDefaultSetting.booleanValue ~= nil then showByDefaultSetting.booleanValue else true -- default to true if setting not found
		if shouldShow then
			showAdminPanel()
		else
			_annotate("Admin tools panel hidden by user setting; access via hamburger menu")
		end
	end)
end

module.Show = function()
	if not config.IsInStudio() then
		return
	end
	showAdminPanel()
end

module.Hide = function()
	hideAdminPanel()
end

module.Toggle = function()
	if not config.IsInStudio() then
		return
	end

	if activeGui then
		hideAdminPanel()
	else
		showAdminPanel()
	end
end

_annotate("end")
return module
