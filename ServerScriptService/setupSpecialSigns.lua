--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local enums = require(game.ReplicatedStorage.util.enums)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)

local module = {}

--just in case of parallelization?
local isWeirdSignSetupYet = {}

do
	local BILLBOARD_WIDTH = 60
	local BILLBOARD_HEIGHT = 10
	local BILLBOARD_OFFSET = Vector3.new(0, 2.5, 0)
	local PICKLEBALL_BILLBOARD_WIDTH = 120
	local PICKLEBALL_BILLBOARD_HEIGHT = 20
	local PICKLEBALL_BILLBOARD_OFFSET = Vector3.new(0, 7.5, 0)
	local MIN_TEXT_SIZE = 120

	local function configureLabel(label: TextLabel)
		label.AutomaticSize = Enum.AutomaticSize.None
		label.Size = UDim2.new(1, 0, 1, 0)
		label.Position = UDim2.new(0, 0, 0, 0)
		label.AnchorPoint = Vector2.new(0, 0)
		label.TextWrapped = false
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextYAlignment = Enum.TextYAlignment.Center
		if label.TextSize < MIN_TEXT_SIZE then
			label.TextSize = MIN_TEXT_SIZE
		end
		if label.Font ~= Enum.Font.GothamBlack and label.Font ~= Enum.Font.GothamBold then
			label.Font = Enum.Font.GothamBlack
		end
		if label.TextStrokeTransparency > 0.15 then
			label.TextStrokeTransparency = 0.15
		end
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.TextColor3 = Color3.new(1, 1, 1)
		label.BackgroundTransparency = 1
	end

	local function configureBillboard(sign: BasePart, billboardGui: BillboardGui, textLabelProperties: { Text: string?, AutoLocalize: boolean?, RichText: boolean?, TextColor3: Color3? }?, isPickleball: boolean?)
		billboardGui.Parent = sign
		billboardGui.Adornee = sign
		billboardGui.ExtentsOffsetWorldSpace = Vector3.new()
		billboardGui.StudsOffsetWorldSpace = Vector3.new()
		if isPickleball then
			billboardGui.StudsOffset = PICKLEBALL_BILLBOARD_OFFSET
			billboardGui.Size = UDim2.new(0, PICKLEBALL_BILLBOARD_WIDTH, 0, PICKLEBALL_BILLBOARD_HEIGHT)
		else
			billboardGui.StudsOffset = BILLBOARD_OFFSET
			billboardGui.Size = UDim2.new(0, BILLBOARD_WIDTH, 0, BILLBOARD_HEIGHT)
		end
		billboardGui.LightInfluence = 0
		billboardGui.ResetOnSpawn = false
		billboardGui.AlwaysOnTop = false

		local label = billboardGui:FindFirstChildOfClass("TextLabel") :: TextLabel?
		if not label then
			local newLabel = Instance.new("TextLabel")
			newLabel.Name = "PickleballText"
			newLabel.Parent = billboardGui
			label = newLabel
		end
		configureLabel(label :: TextLabel)

		if textLabelProperties then
			if textLabelProperties.Text ~= nil then
				label.Text = textLabelProperties.Text
			end
			if textLabelProperties.AutoLocalize ~= nil then
				label.AutoLocalize = textLabelProperties.AutoLocalize
			end
			if textLabelProperties.RichText ~= nil then
				label.RichText = textLabelProperties.RichText
			end
			if textLabelProperties.TextColor3 ~= nil then
				label.TextColor3 = textLabelProperties.TextColor3
			end
		end
	end

	enums.signNameToExtraVisualSetupCallback["Pickleball"] = function(sign: BasePart)
		local extractedText: string? = nil
		local extractedAutoLocalize: boolean? = nil
		local extractedRichText: boolean? = nil
		local extractedTextColor3: Color3? = nil

		for _, child in ipairs(sign:GetChildren()) do
			if child:IsA("SurfaceGui") then
				local surfaceGui = child :: SurfaceGui
				local textLabel = surfaceGui:FindFirstChildOfClass("TextLabel") :: TextLabel?
				if textLabel then
					extractedText = textLabel.Text
					extractedAutoLocalize = textLabel.AutoLocalize
					extractedRichText = textLabel.RichText
					extractedTextColor3 = textLabel.TextColor3
				end
				child:Destroy()
			end
		end

		if extractedAutoLocalize == nil then
			extractedAutoLocalize = true
		end
		if extractedRichText == nil then
			extractedRichText = true
		end

		local billboardGui = Instance.new("BillboardGui")
		billboardGui.Name = "PickleballBillboard"
		billboardGui.Parent = sign
		configureBillboard(sign, billboardGui, {
			Text = sign.Name,
			AutoLocalize = extractedAutoLocalize,
			RichText = extractedRichText,
			TextColor3 = extractedTextColor3,
		}, true)

		if isWeirdSignSetupYet[sign.Name] == nil then
			local r = require(game.ReplicatedStorage.util.signMovement)
			r.rotate(sign :: Part)
			isWeirdSignSetupYet[sign.Name] = true
		end

		sign.DescendantAdded:Connect(function(descendant: Instance)
			if descendant:IsA("TextLabel") then
				configureLabel(descendant :: TextLabel)
			elseif descendant:IsA("BillboardGui") then
				configureBillboard(sign, descendant :: BillboardGui, nil, true)
			end
		end)
	end
end

--loop repeatedly, enabling new day of week signs when they come online.
local function setupDayOfWeekSigns()
	local daySigns = { "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" }
	task.spawn(function()
		local outerDayOfWeek
		local n = 600
		while true do
			local theTick = tick()
			local dayOfWeek = os.date("%A", theTick)
			if dayOfWeek == outerDayOfWeek and outerDayOfWeek ~= nil then
				wait(n)
				continue
			end
			for _, signName in pairs(daySigns) do
				local sign = tpUtil.looseSignName2Sign(signName) :: Part
				if not sign then
					continue
				end
				if signName == dayOfWeek then
					sign.Transparency = 0
					sign.CanCollide = true
					sign.CanTouch = true
					local surfaceGui = sign:FindFirstChildOfClass("SurfaceGui")
					if surfaceGui then
						surfaceGui.Enabled = true
					end
				else
					sign.Transparency = 1
					sign.CanCollide = false
					sign.CanTouch = false
					local surfaceGui = sign:FindFirstChildOfClass("SurfaceGui")
					if surfaceGui then
						surfaceGui.Enabled = false
					end
				end
			end
			--passed update time.
			outerDayOfWeek = dayOfWeek

			wait(n)
		end
	end)
end

module.Init = function()
	_annotate("init")
	task.spawn(function()
		local signFolder = game.Workspace:WaitForChild("Signs") :: Folder
		local coldMold = signFolder:WaitForChild("cOld mOld on a sLate pLate", 2)
		if coldMold and coldMold:IsA("BasePart") then
			(coldMold :: BasePart).Material = Enum.Material.Slate
		end

		local ghost = signFolder:WaitForChild("👻", 2)
		if ghost and ghost:IsA("BasePart") then
			local ghostPart = ghost :: BasePart
			local ghostTextTransparency = 0.7
			ghostPart.Color = Color3.fromRGB(255, 255, 255)
			ghostPart.Transparency = 1
			local label = ghostPart:FindFirstChild("TextLabel")
			if label and label:IsA("TextLabel") then
				(label :: TextLabel).TextTransparency = ghostTextTransparency
			end
		end

		setupDayOfWeekSigns()

		--rotate the meme sign.
		local meme = signFolder:WaitForChild("Meme", 2)
		if meme and meme:IsA("Part") then
			local memePart = meme :: Part
			if isWeirdSignSetupYet[memePart.Name] == nil then
				local r = require(game.ReplicatedStorage.util.signMovement)
				r.rotate(memePart)
				isWeirdSignSetupYet[memePart.Name] = true
			end
		end

		local osign = signFolder:WaitForChild("O", 2)
		if osign and osign:IsA("MeshPart") then
			local meshPart = osign :: MeshPart
			if isWeirdSignSetupYet[meshPart.Name] == nil then
				local r = require(game.ReplicatedStorage.util.signMovement)
				r.rotateMeshpart(meshPart)
				isWeirdSignSetupYet[meshPart.Name] = true
			end
		end

		local chiralitySign = signFolder:WaitForChild("Chirality", 2)
		if chiralitySign and chiralitySign:IsA("Part") then
			local chiralityPart = chiralitySign :: Part
			if isWeirdSignSetupYet[chiralityPart.Name] == nil then
				local r = require(game.ReplicatedStorage.util.signMovement)
				r.riseandspin(chiralityPart)
				isWeirdSignSetupYet[chiralityPart.Name] = true
			end
		end

		-- set up 007 sign.
		task.spawn(function()
			local doubleO7Instance = signFolder:WaitForChild("007", 2)
			if not doubleO7Instance or not doubleO7Instance:IsA("Part") then
				return
			end
			local doubleO7Sign = doubleO7Instance :: Part
			local r = require(game.ReplicatedStorage.util.signMovement)
			r.fadeOutSign(doubleO7Sign, true)
			local signVisible = false
			while true do
				local minute = os.date("%M", tick())
				local minnum = tonumber(minute)
				if minnum == 7 then
					if not signVisible then
						signVisible = true
						r.fadeInSign(doubleO7Sign)
					end
				else
					if signVisible then
						r.fadeOutSign(doubleO7Sign, false)
						signVisible = false
					end
				end

				wait(1)
			end
		end)
	end)
	_annotate("init done")
end

_annotate("end")
return module
