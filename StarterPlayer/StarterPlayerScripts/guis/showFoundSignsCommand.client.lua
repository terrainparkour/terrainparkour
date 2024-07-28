--!strict

--user types, server gets data, sends event, receive it, show ui.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local remotes = require(game.ReplicatedStorage.util.remotes)
local ShowSignProfileEvent = remotes.getRemoteEvent("ShowSignProfileEvent")
local tt = require(game.ReplicatedStorage.types.gametypes)

local function handle(data: tt.playerSignProfileData)
	print(data)
end

ShowSignProfileEvent.OnClientEvent:Connect(handle)
