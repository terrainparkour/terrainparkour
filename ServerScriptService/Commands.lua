--!strict

-- Commands.lua :: ServerScriptService.Commands
-- SERVER-ONLY: Routes chat commands to CommandService and broadcasts player join/leave messages.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CommandService = require(game.ReplicatedStorage.ChatSystem.commandService)

type Module = {
	Init: () -> (),
}

local module: Module = {} :: Module

module.Init = function()
	local RemoteFunctionsFolder = ReplicatedStorage:WaitForChild("RemoteFunctions")

	local ProcessCommandFunction = RemoteFunctionsFolder:WaitForChild("ProcessCommandFunction") :: RemoteFunction

	local RemoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")

	RemoteEventsFolder:WaitForChild("DisplaySystemMessageEvent")

	ProcessCommandFunction.OnServerInvoke = function(player, commandText, sourceChannelName)
		_annotate(string.format("Info: Received command from %s: %s (channel: %s)", player.Name, commandText, sourceChannelName or "nil"))
		local result = CommandService:ProcessCommand(commandText, player, sourceChannelName)
		_annotate(string.format("Info: Processed command from %s", player.Name))
		return result
	end
	_annotate("Info: Command handler bound")

	-- Note: Player join/leave notifications are handled by joiningServer.lua
	-- which is called from presence.lua and uses the compatibility wrapper
	_annotate("Info: Command handler ready (join/leave handled by joiningServer)")

	_annotate("Info: Command system fully initialized")
end

_annotate("end")
return module
