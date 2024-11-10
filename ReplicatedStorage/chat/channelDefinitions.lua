--!strict

-- channelDefinitions. I believe sometimes required on server or client.
-- we enabled some old multitabbing code.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local enums = require(game.ReplicatedStorage.util.enums)
local sendMessageModule = require(game.ReplicatedStorage.chat.sendMessage)
local commandParsing = require(game.ReplicatedStorage.chat.commandParsing)
local tt = require(game.ReplicatedStorage.types.gametypes)

local module = {}

--looks like this is a way to shuffle around pointers to actual channel objects.
local channelsFromExternal = nil

module.SendChannels = function(channels)
	_annotate(string.format("received #channels %d", #channels))
	channelsFromExternal = channels
end

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
module.getChannelDefinitions = function(): { tt.channelDefinition }
	local res: { tt.channelDefinition } = {}
	local doNotCheckInGameIdentifier = require(game.ReplicatedStorage:FindFirstChild("doNotCheckInGameIdentifier"))
	if doNotCheckInGameIdentifier.useTestDb() then
		joinMessage =
			"WARNING. This is the test game. Records and other items will be WIPED.  No guarantee of progress.  Also things will be broken.  WARNING."
	end

	local serverTime = os.date("Server Time: %H:%M %d-%m-%Y", tick())
	local welcomeMessage =
		string.format("Welcome to Terrain Parkour!\nVersion: %s\n%s\n%s", enums.gameVersion, serverTime, joinMessage)
	table.insert(res, {
		Name = "All",
		AutoJoin = true,
		WelcomeMessage = welcomeMessage,
		adminFunc = commandParsing.DataAdminFunc,
		noTalkingInChannel = false,
	})

	table.insert(res, {
		Name = "Data",
		AutoJoin = true,
		WelcomeMessage = sendMessageModule.usageCommandDesc,
		adminFunc = commandParsing.DataAdminFunc,
		noTalkingInChannel = true,
	})

	table.insert(res, {
		Name = "Racers",
		AutoJoin = true,
		WelcomeMessage = "This channel shows joins and leaves!",
		-- adminFunc = commandParsing.DataAdminFunc,
		noTalkingInChannel = true,
	})
	return res
end

module.GetChannel = function(name): tt.channelDefinition | nil
	while true do
		if channelsFromExternal ~= nil then
			break
		end
		_annotate("waiting for channelsFromExternal")
		task.wait(1)
	end
	for _, channel in pairs(channelsFromExternal) do
		if channel.Name == name then
			_annotate("returning channel " .. name)
			return channel
		end
	end
	annotater.Error(string.format("no channel when asking for: %s", name))
end

_annotate("end")
return module