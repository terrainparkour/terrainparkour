--!strict

--user types, server gets data, sends event, receive it, show ui.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local remotes = require(game.ReplicatedStorage.util.remotes)
local ShowClientSignProfileEvent = remotes.getRemoteEvent("ShowClientSignProfileEvent")
local tt = require(game.ReplicatedStorage.types.gametypes)
local signProfileSguiCreator = require(game.ReplicatedStorage.commands.signProfileSguiCreator)

local function handle(data: tt.playerSignProfileData)
	signProfileSguiCreator.createSgui(game.Players.LocalPlayer, data)
end

ShowClientSignProfileEvent.OnClientEvent:Connect(handle)
