local colors = require(game.ReplicatedStorage.util.colors)

local module = {}

--the one in the lower left, where you can cancel out of a race.
local debounceCreateRunProgressSgui = false
module.CreateRunProgressSgui = function(killClientRun, playerGui)
	if debounceCreateRunProgressSgui then
		return
	end
	debounceCreateRunProgressSgui = true
	local sgui: ScreenGui = playerGui:FindFirstChild("RunningRunSgui") :: ScreenGui
	if not sgui then
		sgui = Instance.new("ScreenGui")
		sgui.Parent = playerGui
		sgui.Name = "RunningRunSgui"
		sgui.Enabled = true
	end

	local exi = sgui:FindFirstChild("RaceRunningButton")
	if exi then
		exi:Destroy()
	end

	local tb = Instance.new("TextButton")
	tb.Parent = sgui
	tb.Name = "RaceRunningButton"
	tb.Size = UDim2.new(0.57, 0, 0.1, 0)
	tb.Position = UDim2.new(0.0, 0, 0.9, 0)
	tb.TextTransparency = 0
	tb.BackgroundTransparency = 1
	tb.TextScaled = true
	tb.TextColor3 = colors.yellow
	tb.TextXAlignment = Enum.TextXAlignment.Left
	tb.Text = ""
	tb.Font = Enum.Font.RobotoCondensed
	tb.TextTransparency = 0
	tb.Activated:Connect(function()
		killClientRun("unclick progress")
	end)
	debounceCreateRunProgressSgui = false
end

return module
