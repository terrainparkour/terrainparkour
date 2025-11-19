--!strict

-- pickleballSignFade.lua - Client-side script for distance-based fade of pickleball sign names
-- Rojo path: StarterPlayer.StarterCharacterScripts.client.pickleballSignFade
-- Fades out pickleball sign name text after 100 studs distance from player

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)

local PlayersService = game:GetService("Players")
local RunService = game:GetService("RunService")

local localPlayer: Player = PlayersService.LocalPlayer

-- Module internals
local FADE_START_DISTANCE = 0
local FADE_END_DISTANCE = 100
local pickleballSigns: { BasePart } = {}
local renderConnection: RBXScriptConnection? = nil

local function updatePickleballSignTransparency(sign: BasePart, distance: number)
	local billboardGui = sign:FindFirstChild("PickleballBillboard") :: BillboardGui?
	if not billboardGui then
		return
	end

	local textLabel = billboardGui:FindFirstChild("PickleballText") :: TextLabel?
	if not textLabel then
		textLabel = billboardGui:FindFirstChildOfClass("TextLabel") :: TextLabel?
	end

	if not textLabel then
		return
	end

	local transparency: number
	if distance <= FADE_START_DISTANCE then
		transparency = 0
	elseif distance >= FADE_END_DISTANCE then
		transparency = 1
	else
		local fadeRange = FADE_END_DISTANCE - FADE_START_DISTANCE
		local fadeProgress = (distance - FADE_START_DISTANCE) / fadeRange
		transparency = fadeProgress
	end

	textLabel.TextTransparency = transparency
	if textLabel.TextStrokeTransparency < 1 then
		textLabel.TextStrokeTransparency = math.min(transparency + 0.15, 1)
	end
end

local function findPickleballSigns()
	pickleballSigns = {}
	local signsFolder = game.Workspace:FindFirstChild("Signs") :: Folder?
	if not signsFolder then
		return
	end

	local pickleballSign = signsFolder:FindFirstChild("Pickleball") :: BasePart?
	if pickleballSign then
		local billboardGui = pickleballSign:FindFirstChild("PickleballBillboard") :: BillboardGui?
		if billboardGui then
			table.insert(pickleballSigns, pickleballSign)
		end
	end
end

local function onRenderStepped()
	local character = localPlayer.Character
	if not character then
		return
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoidRootPart then
		return
	end

	local playerPosition = humanoidRootPart.Position

	for _, sign in ipairs(pickleballSigns) do
		if not sign.Parent then
			continue
		end

		local distance = tpUtil.getDist(sign.Position, playerPosition)
		updatePickleballSignTransparency(sign, distance)
	end
end

local function setupRenderStepped()
	if renderConnection then
		renderConnection:Disconnect()
	end

	renderConnection = RunService.RenderStepped:Connect(onRenderStepped)
end

local function onSignDescendantAdded(descendant: Instance)
	if descendant.Name == "PickleballBillboard" and descendant:IsA("BillboardGui") then
		findPickleballSigns()
	end
end

local module = {}

module.Init = function()
	_annotate("init")

	local signsFolder = game.Workspace:WaitForChild("Signs", 10) :: Folder?
	if not signsFolder then
		_annotate("Signs folder not found")
		return
	end

	findPickleballSigns()

	local function onSignAdded(sign: Instance)
		if sign.Name == "Pickleball" and sign:IsA("BasePart") then
			local basePart = sign :: BasePart
			basePart.DescendantAdded:Connect(onSignDescendantAdded)
			local billboardGui = basePart:FindFirstChild("PickleballBillboard") :: BillboardGui?
			if billboardGui then
				findPickleballSigns()
			end
		end
	end
	signsFolder.ChildAdded:Connect(onSignAdded)
	for _, child in ipairs(signsFolder:GetChildren()) do
		if child:IsA("BasePart") and child.Name == "Pickleball" then
			child.DescendantAdded:Connect(onSignDescendantAdded)
		end
	end

	setupRenderStepped()

	_annotate("init done")
end

_annotate("end")
return module

