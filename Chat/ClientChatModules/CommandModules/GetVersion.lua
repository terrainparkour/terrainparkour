--	// FileName: GetVersion.lua
--	// Written by: spotco
--	// Description: Command to print the chat version.

local util = require(script.Parent:WaitForChild("Util"))
local ChatConstants = require(script.Parent.Parent:WaitForChild("ChatConstants"))

function ProcessMessage(message, ChatWindow, ChatSettings)
	return false
end

return {
	[util.KEY_COMMAND_PROCESSOR_TYPE] = util.COMPLETED_MESSAGE_PROCESSOR,
	[util.KEY_PROCESSOR_FUNCTION] = ProcessMessage,
}
