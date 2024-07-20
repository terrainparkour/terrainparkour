--!strict

--user types, server gets data, sends event, receive it, show ui.

local remotes = require(game.ReplicatedStorage.util.remotes)
local showClientSignProfileEvent = remotes.getRemoteEvent("ShowClientSignProfileEvent")
local tt = require(game.ReplicatedStorage.types.gametypes)
local sg = require(game.ReplicatedStorage.commands.signProfileSguiCreator)

local function handle(data: tt.playerSignProfileData)
	sg.createSgui(game.Players.LocalPlayer, data)
end

showClientSignProfileEvent.OnClientEvent:Connect(handle)
