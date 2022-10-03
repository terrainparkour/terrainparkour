--!strict

--eval 9.21
--warning: 2022.10 sometimes needs to be loaded late for some reason.

local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local colors = require(game.ReplicatedStorage.util.colors)

local Players = game:GetService("Players")

local module = {}

module.enum = {}
module.enum.toolTipSize = {}
module.enum.toolTipSize.NormalText = UDim2.new(0, 350, 0, 80)
module.enum.toolTipSize.BigPane = UDim2.new(0, 450, 0, 320)

--right=they float right+down rather than left+down from cursor. default is right.
module.setupToolTip = function(localPlayer: Player, item: TextLabel, contents: string?, size: UDim2, right: boolean?)
	if right == nil then
		right = true
	end
	if contents == nil then
		return
	end
	assert(contents)
	local mouse: Mouse = localPlayer:GetMouse()

	local gui: ScreenGui
	item.MouseEnter:Connect(function()
		gui = Instance.new("ScreenGui")
		gui.Parent = localPlayer.PlayerGui
		gui.Name = "ToolTipGui"
		gui.Enabled = true
		gui.Parent = localPlayer.PlayerGui

		local frm = Instance.new("Frame")
		frm.Parent = gui
		frm.Size = size
		frm.Name = "EphemeralTooltip"
		local tl = guiUtil.getTl("Sgui", UDim2.new(1, 0, 1, 0), 2, frm, colors.defaultGrey, 1)
		tl.Text = contents
		tl.TextXAlignment = Enum.TextXAlignment.Left
		if right then
			frm.Position = UDim2.fromOffset(mouse.X + 10, mouse.Y + 10)
		else
			frm.Position = UDim2.fromOffset(mouse.X + 10 - size.X.Offset, mouse.Y + 10)
		end
	end)
	item.MouseLeave:Connect(function()
		if gui then
			gui:Destroy()
		end
	end)
end

return module
