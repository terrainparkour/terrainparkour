--!strict

--eval 9.21

local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local colors = require(game.ReplicatedStorage.util.colors)

local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer

local mouse: Mouse = localPlayer:GetMouse()

local module = {}

module.enum = {}
module.enum.toolTipSize = {}
module.enum.toolTipSize.NormalText = UDim2.new(0, 350, 0, 80)
module.enum.toolTipSize.BigPane = UDim2.new(0, 450, 0, 320)

module.setupToolTip = function(localPlayer: Player, item: TextLabel, contents: string?, size: UDim2)
	if contents == nil then
		return
	end
	assert(contents)
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
		local tl = guiUtil.getTl("Sgui", UDim2.new(1, 0, 1, 0), 2, frm, colors.defaultGrey, 1)
		tl.Text = contents
		tl.TextXAlignment = Enum.TextXAlignment.Left
		frm.Position = UDim2.new(0, mouse.X + 10, 0, mouse.Y + 10)
	end)
	item.MouseLeave:Connect(function()
		if gui then
			gui:Destroy()
		end
	end)
end

return module
