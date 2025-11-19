--!strict

-- ServerBootstrap.lua :: ReplicatedStorage.ChatSystem.ServerBootstrap
-- Coordinates server-side initialization of the Terrain Parkour TextChat system.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local ChatService = require(script.Parent.chatService)
local Commands = require(game.ServerScriptService.Commands)

local module = {}

module.Init = function()
	ChatService:Init()
	Commands.Init()
end

_annotate("end")
return module
