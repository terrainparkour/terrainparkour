--	// FileName: UnknownMessage.lua
--	// Written by: TheGamer101
--	// Description: Default handler for message types with no other creator registered.
--	// Just print that there was a message with no creator for now.

local MESSAGE_TYPE = "UnknownMessage"
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local clientChatModules = script.Parent.Parent
local ChatSettings = require(clientChatModules:WaitForChild("ChatSettings"))
local util = require(script.Parent:WaitForChild("Util"))

function CreateUnknownMessageLabel(messageData)
	_annotate("No message creator for message: " .. messageData.Message)
end

_annotate("end")
return {
	[util.KEY_MESSAGE_TYPE] = MESSAGE_TYPE,
	[util.KEY_CREATOR_FUNCTION] = CreateUnknownMessageLabel,
}
