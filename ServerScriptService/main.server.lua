--!strict

-- some terms:
-- "client" / player is the roblox client
-- server usually is either the roblox game server (where serverscripts can run)
-- but also might be my external, db server which runs python + mysql.
-- the roblox one will

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
annotater.Init()

--IMPORTANT  this go first because it's where signs and everything are set up
local workspaceRemoteSetup = require(game.ServerScriptService.workspaceRemoteSetup)
annotater.Profile("workspaceRemoteSetup.CreateRemoteEventsAndRemoteFunctions", function()
	workspaceRemoteSetup.CreateRemoteEventsAndRemoteFunctions()
end)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerBootstrap = require(ReplicatedStorage:WaitForChild("ChatSystem"):WaitForChild("serverBootstrap"))
ServerBootstrap.Init()

-- Register all commands as TextChatCommand instances so Roblox suppresses them
local registerCommands = require(game.ServerScriptService.registerCommands)
annotater.Profile("registerCommands.Init", function()
	registerCommands.Init()
end)

local rdb = require(game.ServerScriptService.rdb)
annotater.Profile("rdb.Init", function()
	rdb.Init()
end)

local nocol = require(game.ServerScriptService.nocollide)
annotater.Profile("nocol.Init", function()
	nocol.Init()
end)

local userDataServer = require(game.ServerScriptService.userDataServer)
annotater.Profile("userDataServer.Init", function()
	userDataServer.Init()
end)

local setupSignsServer = require(game.ServerScriptService.setupSignsServer)
annotater.Profile("setupSignsServer.Init", function()
	setupSignsServer.Init()
end)

local receiveClientEventServer = require(game.ServerScriptService.receiveClientEventServer)
annotater.Profile("receiveClientEventServer.Init", function()
	receiveClientEventServer.Init()
end)

local signMovement = require(game.ReplicatedStorage.util.signMovement)
annotater.Profile("signMovement.SetupGrowingDistantPinnacle", function()
	signMovement.SetupGrowingDistantPinnacle()
end)

local setupFindTouchMonitoring = require(game.ServerScriptService.setupFindTouchMonitoring)
annotater.Profile("setupFindTouchMonitoring.Init", function()
	setupFindTouchMonitoring.Init()
end)

local sounds = require(game.ServerScriptService.sounds)
annotater.Profile("sounds.Init", function()
	sounds.Init()
end)

local pushSigns = require(game.ServerScriptService.pushSigns)
annotater.Profile("pushSigns.CheckSignsNeedingPushing", function()
	pushSigns.CheckSignsNeedingPushing()
end)

local presence = require(game.ServerScriptService.presence)
annotater.Profile("presence.Init", function()
	presence.Init()
end)

local banning = require(game.ServerScriptService.banning)
annotater.Profile("banning.Init", function()
	banning.Init()
end)

local marathon = require(game.ServerScriptService.marathon)
annotater.Profile("marathon.Init", function()
	marathon.Init()
end)

local ephemeralMarathon = require(game.ServerScriptService.EphemeralMarathons.ephemeralMarathon)
annotater.Profile("ephemeralMarathon.Init", function()
	ephemeralMarathon.Init()
end)

local locationMonitor = require(game.ReplicatedStorage.locationMonitor)
annotater.Profile("locationMonitor.Init", function()
	locationMonitor.Init()
end)

--include these to initialize listeners despite not being "used".
local userSettings = require(game.ServerScriptService.settingsServer)
annotater.Profile("userSettings.Init", function()
	userSettings.Init()
end)

local newRaces = require(game.ServerScriptService.data.newRaces)
annotater.Profile("newRaces.Init", function()
	newRaces.Init()
end)

local popularRaces = require(game.ServerScriptService.data.popularRaces)
annotater.Profile("popularRaces.Init", function()
	popularRaces.Init()
end)

local contests = require(game.ServerScriptService.data.contests)
annotater.Profile("contests.Init", function()
	contests.Init()
end)

local dynamic = require(game.ServerScriptService.dynamicServer)
annotater.Profile("dynamic.Init", function()
	dynamic.Init()
end)

local serverEvents = require(game.ServerScriptService.serverEvents)
annotater.Profile("serverEvents.Init", function()
	serverEvents.Init()
end)

local serverWarping = require(game.ServerScriptService.serverWarping)
annotater.Profile("serverWarping.Init", function()
	serverWarping.Init()
end)

local runEnding = require(game.ServerScriptService.runEnding)
annotater.Profile("runEnding.Init", function()
	runEnding.Init()
end)

local setupSpecialSigns = require(game.ServerScriptService.setupSpecialSigns)
annotater.Profile("setupSpecialSigns.Init", function()
	setupSpecialSigns.Init()
end)

local _playerData2 = require(game.ServerScriptService.playerData2)
local signClicking = require(game.ServerScriptService.signClicking)
annotater.Profile("signClicking.Init", function()
	signClicking.Init()
end)

local badges = require(game.ServerScriptService.badges)
annotater.Profile("badges.Init", function()
	badges.Init()
end)

--how  does the game work?
--good question.  mainly it's in lua client/server scripts, but via certain calls made from BE, you hit a python mysql db server you also have to have set up.  this is where all your real records and data are stored.

--how does this open source thing work, since if I use it, I won't have those things set up?
--I'm attempting to add a fake layer so at least in memory of the server, you will have records of some kind. that, or many calls will return fake values or at least messages saying "please set up the backend"

--will you make the backend open source too?
--I'm thinking about this.  it's possible. it would be cool to see what people could do with this setup.

local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)
local function checkBadgesForBadIds()
	local counts = {}
	-- 		_annotate("doing badge duplication check since you're in studio.!")

	for _, el in pairs(badgeEnums.badges) do
		if not counts[el.assetId] then
			counts[el.assetId] = 0
		end
		counts[el.assetId] = counts[el.assetId] + 1
	end

	for a, b in pairs(counts) do
		if b > 1 then
			warn(string.format("badge id %d appears %d times", a, b))
		end
	end
end

local testing = require(game.ReplicatedStorage.testing)

local config = require(game.ReplicatedStorage.config)
if config.IsInStudio() then
	annotater.Profile("checkBadgesForBadIds", checkBadgesForBadIds)
	annotater.Profile("testing.TestAll", function()
		testing.TestAll()
	end)
end

_annotate("end")
