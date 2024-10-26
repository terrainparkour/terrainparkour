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

local ServerEventRemoteFunction = remotes.getRemoteFunction("ServerEventRemoteFunction")

local module = {}

--TODO make this into an ephemeral notification.
module.Click = function(userIds: { number }): ScreenGui
	local userId = PlayersService.LocalPlayer.UserId
	ServerEventRemoteFunction:InvokeServer(serverEventEnums.messageTypes.CREATE, { userId = userId })
	return Instance.new("ScreenGui")
end

module.HoverHint = "Create new server event"
module.Name = "Create Server Event"

_annotate("end")
return module
