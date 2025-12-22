--!strict

-- serverBootstrap.lua :: ReplicatedStorage.ChatSystem.serverBootstrap
-- Coordinates server-side initialization of the Terrain Parkour TextChat system.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local chatService = require(game.ReplicatedStorage.ChatSystem.chatService)
local commands = require(game.ServerScriptService.Commands)

local module = {}

module.Init = function()
	chatService:Init()
	commands.Init()
end

_annotate("end")
return module
