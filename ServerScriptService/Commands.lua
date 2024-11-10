local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ProcessCommand = ReplicatedStorage["RemoteFunctions"]["ProcessCommand"]
local CommandService = require(ReplicatedStorage.ChatSystem.CommandService)
local Remote = ReplicatedStorage.RemoteEvents.DisplaySystemMessage

Players.PlayerAdded:Connect(function(player: Player) Remote:FireAllClients("Player Joined: "..player.Name, "Racers") end)
Players.PlayerRemoving:Connect(function(player: Player) Remote:FireAllClients("Player Left: "..player.Name, "Racers") end)

ProcessCommand.OnServerInvoke = function(player, commandText)
	return CommandService:ProcessCommand(commandText, player)
end