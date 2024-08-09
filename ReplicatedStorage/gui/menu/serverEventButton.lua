--!strict

-- GUI on client for server event.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local colors = require(game.ReplicatedStorage.util.colors)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local gt = require(game.ReplicatedStorage.gui.guiTypes)
local serverEventEnums = require(game.ReplicatedStorage.enums.serverEventEnums)
local remotes = require(game.ReplicatedStorage.util.remotes)
local PlayersService = game:GetService("Players")
local localPlayer = PlayersService.LocalPlayer

local ServerEventRemoteFunction = remotes.getRemoteFunction("ServerEventRemoteFunction")

local module = {}

--create server event, wait for ui to pop, then display a simple modal for success or failure.

--TODO make this into an ephemeral notification.
local CreateServerEventButtonClicked = function(): ScreenGui | nil
	local userId = localPlayer.UserId
	ServerEventRemoteFunction:InvokeServer(serverEventEnums.messageTypes.CREATE, { userId = userId })
end

local serverEventButton: gt.actionButton = {
	name = "Create Server Event",
	contentsGetter = CreateServerEventButtonClicked,
	hoverHint = "Create new server event",
	shortName = "Random Race",
	getActive = function()
		return true
	end,
	widthXScale = 0.25,
}

module.serverEventButton = serverEventButton

_annotate("end")
return module
