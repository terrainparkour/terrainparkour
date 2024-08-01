--!strict

-- channeldefinitions
-- we enabled some old multitabbing code.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local enums = require(game.ReplicatedStorage.util.enums)
local sendMessageModule = require(game.ReplicatedStorage.chat.sendMessage)
local commandParsing = require(game.ReplicatedStorage.chat.commandParsing)

local module = {}

--looks like this is a way to shuffle around pointers to actual channel objects.
local channelsFromExternal = nil
module.sendChannels = function(channels)
	_annotate(string.format("received #channels", #channels))
	channelsFromExternal = channels
end

export type channelDefinition = {
	Name: string,
	AutoJoin: boolean,
	WelcomeMessage: string,
	adminFunc: any,
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
	"Endless terrain, endless adventure",
	"Every second counts, every path matters",
	"Natural selection of strategies: Only the fittest runs survive",
	-- now some totally new, really wild and crazy slogans:
	"The only way to win is to run faster",
	"The only way to lose is to run slower",
	"Where every jump is a new discovery",
	"Racing through the randomness",
	"Mastering the unpredictable",
	"Where no two runs are ever the same",
	"Speedrunning in a world without end",
	"Conquering chaos, one jump at a time",
	"跑得快，跑得远",
	"征服地形，超越极限",
	"每一步都是新纪录",
	"无尽地形，无限可能",
	"速度与激情的完美结合",
	"挑战自我，超越巅峰",
	"用速度书写传奇",
	"在随机中寻找最佳路线",
	"跑酷大师的终极挑战",
	"突破界限，创造奇迹",
	"Swift as wind, footsteps like verse",
	"Mountains as paths, clouds as bounds",
	"Each step anew, each leap unique",
	"Endless terrain, boundless chance",
	"Speed and passion, perfect blend",
	"Challenge self, surpass the peak",
	"Write with speed, compose with leaps",
	"In chaos seek, the finest route",
	"Parkour's way, supreme and high",
	"Break limits, transcend mortal realm",
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
		noTalkingInChannel = false,
		BackupChats = true,
	})

	table.insert(res, {
		Name = "Data",
		AutoJoin = true,
		WelcomeMessage = sendMessageModule.usageCommandDesc,
		adminFunc = commandParsing.DataAdminFunc,
		noTalkingInChannel = true,
		BackupChats = true,
	})

	table.insert(res, {
		Name = "Racers",
		AutoJoin = true,
		WelcomeMessage = "This channel shows joins and leaves!",
		adminFunc = commandParsing.DataAdminFunc,
		noTalkingInChannel = true,
		BackupChats = false,
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

_annotate("end")
return module
