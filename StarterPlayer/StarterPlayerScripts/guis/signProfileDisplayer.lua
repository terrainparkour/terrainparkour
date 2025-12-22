--!strict

-- signProfileDisplayer.lua :: StarterPlayer.StarterPlayerScripts.guis.signProfileDisplayer
-- Receives sign profile data from server and displays the UI.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local Players = game:GetService("Players")

local remotes = require(game.ReplicatedStorage.util.remotes)
local tt = require(game.ReplicatedStorage.types.gametypes)
local signProfileSguiCreator = require(game.ReplicatedStorage.gui.signProfile.signProfileSguiCreator)

local module = {}

local connection: RBXScriptConnection? = nil

local function handle(data: tt.playerSignProfileData)
	signProfileSguiCreator.CreateSignProfileSGui(Players.LocalPlayer, data)
end

function module.Init()
	-- Disconnect existing connection if any (idempotent)
	if connection then
		connection:Disconnect()
	end
	
	local ShowClientSignProfileEvent = remotes.getRemoteEvent("ShowClientSignProfileEvent")
	connection = ShowClientSignProfileEvent.OnClientEvent:Connect(handle)
	_annotate("initialized")
end

_annotate("end")
return module

