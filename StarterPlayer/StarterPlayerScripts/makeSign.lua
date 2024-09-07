if true then
	return
end

local oldName = "Talladgea"
local newName = "Talladega"
local signsFolder = game.workspace.Signs

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

makeSign(game.workspace:FindFirstChild(oldName))
