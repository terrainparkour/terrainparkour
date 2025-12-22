--!strict
-- velocityWidgets.lua (ReplicatedStorage/gui/activeRunWidgets/velocityWidgets.lua)
-- Velocity display widgets showing actual physics velocity.
--
-- VELOCITY SOURCE: HumanoidRootPart.AssemblyLinearVelocity (Roblox physics engine)
-- This is NOT WalkSpeed. AssemblyLinearVelocity is the instantaneous physics velocity
-- including gravity, collisions, and momentum.
--
-- Velocity widgets are always on, self-updating independently of run state.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local colors = require(game.ReplicatedStorage.util.colors)
local fonts = require(game.StarterPlayer.StarterPlayerScripts.guis.fonts)
local widgetStyles = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetStyles)
local widgetTypes = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetTypes)

local localPlayer = Players.LocalPlayer

local module = {}

-- Velocity color (cyan/blue to distinguish from yellow speed)
local VELOCITY_COLOR = colors.blueDone

--------------------------------------------------------------------------------
-- Velocity Source: HumanoidRootPart.AssemblyLinearVelocity
--------------------------------------------------------------------------------
local function getCharacterVelocity(): number
	local character = localPlayer.Character
	if not character then
		return 0
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return 0
	end
	return hrp.AssemblyLinearVelocity.Magnitude
end

--------------------------------------------------------------------------------
-- Number: Numeric velocity display showing total 3D velocity
--------------------------------------------------------------------------------
local function createNumber(): widgetTypes.Widget
	local velocityLabel: TextLabel? = nil
	local cleanupFn: (() -> ())? = nil
	local updateConnection: RBXScriptConnection? = nil

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local result = widgetStyles.createTransparentLabel({
				name = "VelocityWidget_number",
				size = UDim2.fromOffset(140, 36),
				position = position,
				text = "0.0d/s",
				textColor = VELOCITY_COLOR,
				fontSize = 24,
				fontMono = true,
				fontBold = true,
				xAlignment = Enum.TextXAlignment.Center,
			})
			result.frame.Parent = parent
			velocityLabel = result.label
			cleanupFn = result.cleanup

			updateConnection = RunService.Heartbeat:Connect(function()
				if velocityLabel then
					velocityLabel.Text = string.format("%.1fd/s", getCharacterVelocity())
				end
			end)

			return result.frame
		end,

		Destroy = function()
			if updateConnection then
				updateConnection:Disconnect()
				updateConnection = nil
			end
			if cleanupFn then
				cleanupFn()
				cleanupFn = nil
			end
			velocityLabel = nil
		end,
	})
end

--------------------------------------------------------------------------------
-- Large: Large transparent velocity display
--------------------------------------------------------------------------------
local function createLarge(): widgetTypes.Widget
	local velocityLabel: TextLabel? = nil
	local cleanupFn: (() -> ())? = nil
	local updateConnection: RBXScriptConnection? = nil

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local result = widgetStyles.createTransparentLabel({
				name = "VelocityWidget_large",
				size = UDim2.fromOffset(160, 50),
				position = position,
				text = "0.0d/s",
				textColor = VELOCITY_COLOR,
				fontSize = 36,
				fontMono = true,
				fontBold = true,
				xAlignment = Enum.TextXAlignment.Center,
			})
			result.frame.Parent = parent
			velocityLabel = result.label
			cleanupFn = result.cleanup

			updateConnection = RunService.Heartbeat:Connect(function()
				if velocityLabel then
					velocityLabel.Text = string.format("%.1fd/s", getCharacterVelocity())
				end
			end)

			return result.frame
		end,

		Destroy = function()
			if updateConnection then
				updateConnection:Disconnect()
				updateConnection = nil
			end
			if cleanupFn then
				cleanupFn()
				cleanupFn = nil
			end
			velocityLabel = nil
		end,
	})
end

--------------------------------------------------------------------------------
-- Small: Small transparent velocity display
--------------------------------------------------------------------------------
local function createSmall(): widgetTypes.Widget
	local velocityLabel: TextLabel? = nil
	local cleanupFn: (() -> ())? = nil
	local updateConnection: RBXScriptConnection? = nil

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local result = widgetStyles.createTransparentLabel({
				name = "VelocityWidget_small",
				size = UDim2.fromOffset(90, 26),
				position = position,
				text = "0.0d/s",
				textColor = VELOCITY_COLOR,
				fontSize = 16,
				fontMono = true,
				fontBold = true,
				xAlignment = Enum.TextXAlignment.Center,
			})
			result.frame.Parent = parent
			velocityLabel = result.label
			cleanupFn = result.cleanup

			updateConnection = RunService.Heartbeat:Connect(function()
				if velocityLabel then
					velocityLabel.Text = string.format("%.1fd/s", getCharacterVelocity())
				end
			end)

			return result.frame
		end,

		Destroy = function()
			if updateConnection then
				updateConnection:Disconnect()
				updateConnection = nil
			end
			if cleanupFn then
				cleanupFn()
				cleanupFn = nil
			end
			velocityLabel = nil
		end,
	})
end

--------------------------------------------------------------------------------
-- Compact: Small velocity display with dark background
--------------------------------------------------------------------------------
local function createCompact(): widgetTypes.Widget
	local velocityLabel: TextLabel? = nil
	local updateConnection: RBXScriptConnection? = nil

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local frame = Instance.new("Frame")
			frame.Name = "VelocityWidget_compact"
			frame.Position = position or UDim2.fromScale(0.5, 0.5)
			frame.Size = UDim2.fromOffset(90, 26)
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.BackgroundColor3 = colors.black
			frame.BackgroundTransparency = 0.2
			frame.BorderSizePixel = 1
			frame.BorderColor3 = colors.signColor
			frame.Parent = parent

			local label = Instance.new("TextLabel")
			label.Name = "VelocityLabel"
			label.Size = UDim2.fromScale(1, 1)
			label.Position = UDim2.fromScale(0, 0)
			label.BackgroundTransparency = 1
			label.TextColor3 = VELOCITY_COLOR
			label.FontFace = fonts.GetFont(true, true)
			label.TextSize = 16
			label.Text = "0.0d/s"
			label.TextStrokeTransparency = 0.5
			label.TextStrokeColor3 = colors.black
			label.Parent = frame
			velocityLabel = label

			updateConnection = RunService.Heartbeat:Connect(function()
				if velocityLabel then
					velocityLabel.Text = string.format("%.1fd/s", getCharacterVelocity())
				end
			end)

			return frame
		end,

		Destroy = function()
			if updateConnection then
				updateConnection:Disconnect()
				updateConnection = nil
			end
			velocityLabel = nil
		end,
	})
end

--------------------------------------------------------------------------------
-- Bar: Horizontal bar gauge showing total 3D velocity
--------------------------------------------------------------------------------
local function createBar(): widgetTypes.Widget
	local fillFrame: Frame? = nil
	local velocityLabel: TextLabel? = nil
	local updateConnection: RBXScriptConnection? = nil

	local MAX_VELOCITY = 150

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local frame = Instance.new("Frame")
			frame.Name = "VelocityWidget_bar"
			frame.Position = position or UDim2.fromScale(0.5, 0.92)
			frame.Size = UDim2.fromOffset(280, 36)
			frame.AnchorPoint = Vector2.new(0.5, 0)
			frame.BackgroundColor3 = colors.black
			frame.BackgroundTransparency = 0.05
			frame.BorderSizePixel = 1
			frame.BorderColor3 = colors.signColor
			frame.Parent = parent

			local label = Instance.new("TextLabel")
			label.Name = "VelocityLabel"
			label.Size = UDim2.fromOffset(75, 30)
			label.Position = UDim2.fromOffset(4, 3)
			label.BackgroundTransparency = 1
			label.TextColor3 = VELOCITY_COLOR
			label.FontFace = fonts.GetFont(true, true)
			label.TextSize = 20
			label.TextXAlignment = Enum.TextXAlignment.Center
			label.Text = "0.0d/s"
			label.TextStrokeTransparency = 0.3
			label.TextStrokeColor3 = colors.black
			label.ZIndex = 6
			label.Parent = frame
			velocityLabel = label

			local barBg = Instance.new("Frame")
			barBg.Name = "BarBackground"
			barBg.Size = UDim2.fromOffset(190, 30)
			barBg.Position = UDim2.fromOffset(82, 3)
			barBg.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
			barBg.BackgroundTransparency = 0
			barBg.BorderSizePixel = 1
			barBg.BorderColor3 = colors.defaultGrey
			barBg.ClipsDescendants = true
			barBg.Parent = frame

			local fill = Instance.new("Frame")
			fill.Name = "Fill"
			fill.Size = UDim2.fromScale(0, 1)
			fill.Position = UDim2.fromScale(0, 0)
			fill.BackgroundColor3 = VELOCITY_COLOR
			fill.BorderSizePixel = 0
			fill.ZIndex = 2
			fill.Parent = barBg
			fillFrame = fill

			updateConnection = RunService.Heartbeat:Connect(function()
				local total = getCharacterVelocity()

				if fillFrame then
					local pct = math.clamp(total / MAX_VELOCITY, 0, 1)
					TweenService:Create(fillFrame, TweenInfo.new(0.1), { Size = UDim2.fromScale(pct, 1) }):Play()

					if total >= 100 then
						fillFrame.BackgroundColor3 = colors.meColor
					elseif total >= 68 then
						fillFrame.BackgroundColor3 = colors.lightGreen
					elseif total >= 40 then
						fillFrame.BackgroundColor3 = VELOCITY_COLOR
					else
						fillFrame.BackgroundColor3 = colors.defaultGrey
					end
				end

				if velocityLabel then
					velocityLabel.Text = string.format("%.1fd/s", total)
				end
			end)

			return frame
		end,

		Destroy = function()
			if updateConnection then
				updateConnection:Disconnect()
				updateConnection = nil
			end
			fillFrame = nil
			velocityLabel = nil
		end,
	})
end

--------------------------------------------------------------------------------
-- Register all velocity widgets
--------------------------------------------------------------------------------
function module.Register(composer: { RegisterWidget: (string, string, () -> any) -> () })
	local category = widgetTypes.CATEGORIES.VELOCITY
	composer.RegisterWidget(category, widgetTypes.VELOCITY_STYLES.NUMBER, createNumber)
	composer.RegisterWidget(category, widgetTypes.VELOCITY_STYLES.LARGE, createLarge)
	composer.RegisterWidget(category, widgetTypes.VELOCITY_STYLES.SMALL, createSmall)
	composer.RegisterWidget(category, widgetTypes.VELOCITY_STYLES.COMPACT, createCompact)
	composer.RegisterWidget(category, widgetTypes.VELOCITY_STYLES.BAR, createBar)
	_annotate("Registered velocity widgets")
end

_annotate("end")
return module
