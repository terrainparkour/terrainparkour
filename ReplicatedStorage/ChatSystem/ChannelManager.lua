--!strict

-- channelManager.lua :: ReplicatedStorage.ChatSystem.channelManager
-- Houses channel definitions and runtime registry for TextChatService.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local enums = require(game.ReplicatedStorage.util.enums)
local MessageFormatter = require(script.Parent.messageFormatter)

export type ChannelDefinition = {
	name: string,
	autoJoin: boolean,
	allowUserMessages: boolean,
	welcomeMessage: string?,
	showInChannelTabs: boolean,
}

type Module = {
	GetDefinitions: () -> { ChannelDefinition },
	GetDefinition: (string) -> ChannelDefinition?,
	ShouldAllowUserMessages: (string) -> boolean,
	GetDefaultChannelName: () -> string,
	RegisterChannel: (string, TextChannel) -> TextChannel,
	CreateChannel: (string, TextChannel) -> TextChannel,
	GetChannel: (string) -> TextChannel?,
}

local channels: { [string]: TextChannel } = {}
local definitions: { ChannelDefinition }? = nil
local definitionIndex: { [string]: ChannelDefinition } = {}

local JOIN_MESSAGES = {
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

local function useTestDatabase(): boolean
	local identifier = game.ReplicatedStorage:FindFirstChild("doNotCheckInGameIdentifier")
	if identifier and identifier:IsA("ModuleScript") then
		local ok, result = pcall(require, identifier)
		if ok and type(result) == "table" and result.useTestDb and result.useTestDb() then
			return true
		end
	end
	return false
end

local function buildJoinMessage(): string
	local joinMessage = JOIN_MESSAGES[math.random(1, #JOIN_MESSAGES)]
	if useTestDatabase() then
		joinMessage =
			"WARNING. This is the test game. Records and other items will be WIPED.  No guarantee of progress.  Also things will be broken.  WARNING."
	end
	local serverTime = os.date("Server Time: %H:%M %d-%m-%Y", tick())
	return string.format("Welcome to Terrain Parkour!\nVersion: %s\n%s\n%s", enums.gameVersion, serverTime, joinMessage)
end

local function registerDefinition(definition: ChannelDefinition)
	definitionIndex[definition.name] = definition
end

-- Channel Rules:
-- Chat: User chat + notable events (007, chomik results, server magic messages). NO long command spam.
-- Data: Command output (long user-generated spam from /wrs, /cwrs, etc.). NO user chat.
-- Joins: Join/leave notifications only (with timings, ranks, server count). NO user chat.

local function buildDefinitions(): { ChannelDefinition }
	local defs: { ChannelDefinition } = {
		{
			name = "Chat",
			autoJoin = true,
			allowUserMessages = true,
			welcomeMessage = buildJoinMessage(),
			showInChannelTabs = true,
		},
		{
			name = "Data",
			autoJoin = true,
			allowUserMessages = false,
			welcomeMessage = MessageFormatter.usageCommandDesc,
			showInChannelTabs = true,
		},
		{
			name = "Joins",
			autoJoin = true,
			allowUserMessages = false,
			welcomeMessage = "Join/leave notifications with timings, ranks, and server player count",
			showInChannelTabs = true,
		},
	}

	table.clear(definitionIndex)
	for _, definition in ipairs(defs) do
		registerDefinition(definition)
	end

	return defs
end

local function ensureDefinitions()
	if not definitions then
		local built = buildDefinitions()
		definitions = built
		_annotate(string.format("Built %d chat channel definitions", #built))
	end
end

local module: Module = {} :: Module

function module.GetDefinitions(): { ChannelDefinition }
	ensureDefinitions()
	return definitions :: { ChannelDefinition }
end

function module.GetDefinition(name: string): ChannelDefinition?
	ensureDefinitions()
	return definitionIndex[name]
end

function module.ShouldAllowUserMessages(channelName: string): boolean
	local definition = module.GetDefinition(channelName)
	if definition then
		return definition.allowUserMessages
	end
	return true
end

function module.GetDefaultChannelName(): string
	return "Chat"
end

function module.RegisterChannel(channelName: string, channel: TextChannel): TextChannel
	channels[channelName] = channel
	local definition = module.GetDefinition(channelName)
	if not definition then
		error(
			string.format(
				"[channelManager] Tried to register TextChannel with no definition: name=%s channel=%s",
				tostring(channelName),
				channel:GetFullName()
			)
		)
	end

	_annotate(
		string.format(
			"channelManager: registered TextChannel name=%s autoJoin=%s allowMessages=%s showInTabs=%s",
			channelName,
			tostring(definition.autoJoin),
			tostring(definition.allowUserMessages),
			tostring(definition.showInChannelTabs)
		)
	)

	channel.ShouldDeliverCallback = function(message: TextChatMessage): boolean
		local textSource = message.TextSource
		local rawText = message.Text or ""

		if not textSource then
			return true
		end

		if rawText:sub(1, 1) == "/" then
			return false
		end

		if not definition.allowUserMessages then
			return false
		end

		return true
	end

	return channel
end

function module.CreateChannel(channelName: string, channel: TextChannel): TextChannel
	return module.RegisterChannel(channelName, channel)
end

function module.GetChannel(channelName: string): TextChannel?
	return channels[channelName]
end

_annotate("end")
return module
