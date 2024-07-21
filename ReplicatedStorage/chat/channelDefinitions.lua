--!strict
--2021 reviewed mostly

--eval 9.24.22

local textUtil = require(game.ReplicatedStorage.util.textUtil)
local enums = require(game.ReplicatedStorage.util.enums)
local text = require(game.ReplicatedStorage.util.text)
local grantBadge = require(game.ServerScriptService.grantBadge)
local config = require(game.ReplicatedStorage.config)

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local playerdata = require(game.ServerScriptService.playerdata)
local rdb = require(game.ServerScriptService.rdb)

local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)
local serverwarping = require(game.ServerScriptService.serverWarping)
local channelCommands = require(game.ReplicatedStorage.chat.channelCommands)

local sendMessageModule = require(game.ReplicatedStorage.chat.sendMessage)
local commandParsing = require(game.ReplicatedStorage.chat.commandParsing)

local module = {}

--looks like this is a way to shuffle around pointers to actual channel objects.
local channelsFromExternal = nil
module.sendChannels = function(channels)
	channelsFromExternal = channels
end

export type channelDefinition = {
	Name: string,
	AutoJoin: boolean,
	WelcomeMessage: string,
	adminFunc: any,
	adminFuncName: string,
	noTalkingInChannel: boolean,
	BackupChats: boolean,
}

local joinMessages = {
	"Speedrunning scavenger hunt",
	"Asymptotic complete runs",
	"Quest for 1000 signs",
	"No invisible walls",
	"Just one more race",
	"Emergent speedrunning",
	"Racing off the rails",
	"Going farther than others would",
}
local joinMessage = joinMessages[math.random(#joinMessages)]

--define the channels for processing and metadata
module.getChannelDefinitions = function(): { channelDefinition }
	local res: { channelDefinition } = {}
	local doNotCheckInGameIdentifier = require(game.ReplicatedStorage:FindFirstChild("doNotCheckInGameIdentifier"))
	if doNotCheckInGameIdentifier.useTestDb() then
		joinMessage =
			"WARNING. This is the test game. Records and other items will be WIPED.  No guarantee of progress.  Also things will be broken.  WARNING."
	end

	local serverTime = os.date("Server Time: %H:%M %d-%m-%Y", tick())

	table.insert(res, {
		Name = "All",
		AutoJoin = true,
		WelcomeMessage = "Welcome to Terrain Parkour!"
			.. "\nVersion: "
			.. enums.gameVersion
			.. "\n"
			.. serverTime
			.. "\n"
			.. joinMessage,
		adminFunc = commandParsing.DataAdminFunc,
		adminFuncName = "AllAdminFunc",
		noTalkingInChannel = false,
		BackupChats = true,
	})

	table.insert(res, {
		Name = "Data",
		AutoJoin = true,
		WelcomeMessage = sendMessageModule.usageCommandDesc,
		adminFunc = commandParsing.DataAdminFunc,
		adminFuncName = "DataAdminFunc",
		noTalkingInChannel = true,
	})

	table.insert(res, {
		Name = "Racers",
		AutoJoin = true,
		WelcomeMessage = "This channel shows joins and leaves!",
		noTalkingInChannel = true,
	})
	return res
end

module.getChannel = function(name)
	while true do
		wait(1)
		if channelsFromExternal ~= nil then
			break
		end
	end
	for k, v in pairs(channelsFromExternal) do
		if v.Name == name then
			return v
		end
	end
	warn("no channel.")
	return nil
end

return module
