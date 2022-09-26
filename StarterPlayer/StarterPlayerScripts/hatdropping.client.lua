--wilsoneee
local function dropHats()
	local localPlayer = game:GetService("Players").LocalPlayer
	if localPlayer and localPlayer.Character then
		for _, obj in pairs(localPlayer.Character:GetChildren()) do
			if obj:IsA("Accoutrement") then
				obj.Parent = game.Workspace
			end
		end
	end
end

game:GetService("UserInputService").InputBegan:connect(function(inputObject, gameProcessedEvent)
	if not gameProcessedEvent then
		if inputObject.KeyCode == Enum.KeyCode.Equals then
			dropHats()
		end
	end
end)
