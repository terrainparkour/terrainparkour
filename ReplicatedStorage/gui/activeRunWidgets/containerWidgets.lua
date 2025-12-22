--!strict
-- containerWidgets.lua (ReplicatedStorage/gui/activeRunWidgets/containerWidgets.lua)
-- Container widget implementations for grouping child widgets.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local colors = require(game.ReplicatedStorage.util.colors)
local fonts = require(game.StarterPlayer.StarterPlayerScripts.guis.fonts)
local widgetTypes = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetTypes)
local widgetStyles = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetStyles)

local module = {}

-- Dashboard bar - horizontal bar fixed to bottom of screen
local function createDashboardBar(): widgetTypes.Widget
	local container: Frame? = nil
	local contentArea: Frame? = nil

	return widgetTypes.createWidget({
		Create = function(parent: Frame, _position: UDim2?): Frame?
			local frame = Instance.new("Frame")
			frame.Name = "ContainerWidget_dashboard"
			frame.Position = UDim2.new(0, 0, 1, -70)
			frame.Size = UDim2.new(1, 0, 0, 70)
			frame.AnchorPoint = Vector2.new(0, 0)
			frame.BackgroundColor3 = widgetStyles.containerBackground
			frame.BackgroundTransparency = 0.1
			frame.BorderSizePixel = 0
			frame.ClipsDescendants = true
			frame.Parent = parent
			container = frame

			local topBorder = Instance.new("Frame")
			topBorder.Name = "TopBorder"
			topBorder.Size = UDim2.new(1, 0, 0, 2)
			topBorder.Position = UDim2.fromScale(0, 0)
			topBorder.BackgroundColor3 = colors.signColor
			topBorder.BorderSizePixel = 0
			topBorder.Parent = frame

			local content = Instance.new("Frame")
			content.Name = "Content"
			content.Size = UDim2.new(1, -20, 1, -6)
			content.Position = UDim2.fromOffset(10, 4)
			content.BackgroundTransparency = 1
			content.ClipsDescendants = false
			content.Parent = frame
			contentArea = content

			local layout = Instance.new("UIListLayout")
			layout.FillDirection = Enum.FillDirection.Horizontal
			layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			layout.VerticalAlignment = Enum.VerticalAlignment.Center
			layout.Padding = UDim.new(0, 15)
			layout.Parent = content

			return content
		end,

		Destroy = function()
			if container then
				container:Destroy()
				container = nil
			end
			contentArea = nil
		end,

		GetFrame = function(): Frame?
			return contentArea
		end,
	})
end

-- HUD frame - full-screen overlay with edge zones
local function createHudFrame(): widgetTypes.Widget
	local container: Frame? = nil
	local contentArea: Frame? = nil

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local frame = Instance.new("Frame")
			frame.Name = "ContainerWidget_hud"
			frame.Position = position or UDim2.fromScale(0.5, 0.5)
			frame.Size = UDim2.fromScale(0.96, 0.92)
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.BackgroundTransparency = 1
			frame.Parent = parent
			container = frame

			local cornerSize = 30
			local corners: { { pos: UDim2, anchor: Vector2 } } = {
				{ pos = UDim2.fromScale(0, 0), anchor = Vector2.new(0, 0) },
				{ pos = UDim2.fromScale(1, 0), anchor = Vector2.new(1, 0) },
				{ pos = UDim2.fromScale(0, 1), anchor = Vector2.new(0, 1) },
				{ pos = UDim2.fromScale(1, 1), anchor = Vector2.new(1, 1) },
			}

			for i, corner in ipairs(corners) do
				local hBar = Instance.new("Frame")
				hBar.Name = "Corner" .. i .. "H"
				hBar.Size = UDim2.fromOffset(cornerSize, 3)
				hBar.Position = corner.pos
				hBar.AnchorPoint = corner.anchor
				hBar.BackgroundColor3 = colors.signColor
				hBar.BackgroundTransparency = 0.3
				hBar.BorderSizePixel = 0
				hBar.Parent = frame

				local vBar = Instance.new("Frame")
				vBar.Name = "Corner" .. i .. "V"
				vBar.Size = UDim2.fromOffset(3, cornerSize)
				vBar.Position = corner.pos
				vBar.AnchorPoint = corner.anchor
				vBar.BackgroundColor3 = colors.signColor
				vBar.BackgroundTransparency = 0.3
				vBar.BorderSizePixel = 0
				vBar.Parent = frame
			end

			local content = Instance.new("Frame")
			content.Name = "Content"
			content.Size = UDim2.fromScale(1, 1)
			content.Position = UDim2.fromScale(0, 0)
			content.BackgroundTransparency = 1
			content.Parent = frame
			contentArea = content

			return content
		end,

		Destroy = function()
			if container then
				container:Destroy()
				container = nil
			end
			contentArea = nil
		end,

		GetFrame = function(): Frame?
			return contentArea
		end,
	})
end

-- Minimal panel - compact floating panel
local function createMinimalPanel(): widgetTypes.Widget
	local container: Frame? = nil
	local contentArea: Frame? = nil

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local frame = Instance.new("Frame")
			frame.Name = "ContainerWidget_minimal"
			frame.Position = position or UDim2.fromScale(0.5, 0.12)
			frame.Size = UDim2.fromOffset(220, 160)
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.BackgroundColor3 = widgetStyles.containerBackground
			frame.BackgroundTransparency = 0.1
			frame.BorderSizePixel = widgetStyles.containerBorderSize
			frame.BorderColor3 = widgetStyles.containerBorderColor
			frame.ClipsDescendants = true
			frame.Parent = parent
			container = frame

			local content = Instance.new("Frame")
			content.Name = "Content"
			content.Size = UDim2.new(1, -8, 1, -8)
			content.Position = UDim2.fromOffset(4, 4)
			content.BackgroundTransparency = 1
			content.ClipsDescendants = false
			content.Parent = frame
			contentArea = content

			local layout = Instance.new("UIListLayout")
			layout.FillDirection = Enum.FillDirection.Vertical
			layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			layout.VerticalAlignment = Enum.VerticalAlignment.Top
			layout.Padding = UDim.new(0, 4)
			layout.Parent = content

			return content
		end,

		Destroy = function()
			if container then
				container:Destroy()
				container = nil
			end
			contentArea = nil
		end,

		GetFrame = function(): Frame?
			return contentArea
		end,
	})
end

-- Retro arcade style frame
local function createRetroArcade(): widgetTypes.Widget
	local container: Frame? = nil
	local contentArea: Frame? = nil

	return widgetTypes.createWidget({
		Create = function(parent: Frame, position: UDim2?): Frame?
			local frame = Instance.new("Frame")
			frame.Name = "ContainerWidget_retro"
			frame.Position = position or UDim2.fromScale(0.5, 0.12)
			frame.Size = UDim2.fromOffset(400, 80)
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.BackgroundColor3 = colors.black
			frame.BackgroundTransparency = 0
			frame.BorderSizePixel = 4
			frame.BorderColor3 = colors.signColor
			frame.ClipsDescendants = true
			frame.Parent = parent
			container = frame

			local innerBorder = Instance.new("Frame")
			innerBorder.Name = "InnerBorder"
			innerBorder.Size = UDim2.new(1, -8, 1, -8)
			innerBorder.Position = UDim2.fromOffset(4, 4)
			innerBorder.BackgroundTransparency = 1
			innerBorder.BorderSizePixel = 2
			innerBorder.BorderColor3 = colors.meColor
			innerBorder.Parent = frame

			local titleLabel = Instance.new("TextLabel")
			titleLabel.Name = "Title"
			titleLabel.Size = UDim2.new(1, -16, 0, 16)
			titleLabel.Position = UDim2.fromOffset(8, 6)
			titleLabel.BackgroundTransparency = 1
			titleLabel.TextColor3 = colors.meColor
			titleLabel.FontFace = fonts.GetFont(true, true)
			titleLabel.TextSize = 14
			titleLabel.TextXAlignment = Enum.TextXAlignment.Center
			titleLabel.Text = "◄ RETRO ARCADE ►"
			titleLabel.Parent = frame

			local content = Instance.new("Frame")
			content.Name = "Content"
			content.Size = UDim2.new(1, -16, 1, -28)
			content.Position = UDim2.fromOffset(8, 24)
			content.BackgroundTransparency = 1
			content.ClipsDescendants = false
			content.Parent = frame
			contentArea = content

			local layout = Instance.new("UIListLayout")
			layout.FillDirection = Enum.FillDirection.Horizontal
			layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			layout.VerticalAlignment = Enum.VerticalAlignment.Center
			layout.Padding = UDim.new(0, 12)
			layout.Parent = content

			return content
		end,

		Destroy = function()
			if container then
				container:Destroy()
				container = nil
			end
			contentArea = nil
		end,

		GetFrame = function(): Frame?
			return contentArea
		end,
	})
end

function module.Register(composer: { RegisterWidget: (string, string, () -> any) -> () })
	local category = widgetTypes.CATEGORIES.CONTAINER
	composer.RegisterWidget(category, widgetTypes.CONTAINER_STYLES.DASHBOARD_BAR, createDashboardBar)
	composer.RegisterWidget(category, widgetTypes.CONTAINER_STYLES.HUD_FRAME, createHudFrame)
	composer.RegisterWidget(category, widgetTypes.CONTAINER_STYLES.MINIMAL_PANEL, createMinimalPanel)
	composer.RegisterWidget(category, widgetTypes.CONTAINER_STYLES.RETRO_ARCADE, createRetroArcade)
	_annotate("Registered container widgets")
end

_annotate("end")
return module
