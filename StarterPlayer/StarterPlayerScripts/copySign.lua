local oldName = "B"
local newName = "3d cube"
local signsFolder = game.Workspace:FindFirstChild("Signs")

local function makeSign(part)
	part.Name = newName
	part.Parent = signsFolder
	local child = part:GetChildren()
	for _, child in ipairs(child) do
		child.Name = "SignGui_" .. newName
		for _, c2: TextLabel in ipairs(child:GetChildren()) do
			c2.Text = newName
		end
	end
end

makeSign(game.Workspace:FindFirstChild(oldName))
