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
workspaceRemoteSetup.CreateRemoteEventsAndRemoteFunctions()

local rdb = require(game.ServerScriptService.rdb)
rdb.Init()

local nocol = require(game.ServerScriptService.nocollide)
nocol.Init()

local userDataServer = require(game.ServerScriptService.userDataServer)
userDataServer.Init()

local setupSignsServer = require(game.ServerScriptService.setupSignsServer)
setupSignsServer.Init()

local receiveClientEventServer = require(game.ServerScriptService.receiveClientEventServer)
receiveClientEventServer.Init()

local signMovement = require(game.ReplicatedStorage.util.signMovement)
signMovement.SetupGrowingDistantPinnacle()

local setupFindTouchMonitoring = require(game.ServerScriptService.setupFindTouchMonitoring)
setupFindTouchMonitoring.Init()

local sounds = require(game.ServerScriptService.sounds)
sounds.Init()

local pushSigns = require(game.ServerScriptService.pushSigns)
pushSigns.CheckSignsNeedingPushing()

local presence = require(game.ServerScriptService.presence)
presence.Init()

local banning = require(game.ServerScriptService.banning)
banning.Init()

local marathon = require(game.ServerScriptService.marathon)
marathon.Init()

local ephemeralMarathon = require(game.ServerScriptService.EphemeralMarathons.ephemeralMarathon)
ephemeralMarathon.Init()

local locationMonitor = require(game.ReplicatedStorage.locationMonitor)
locationMonitor.Init()

--include these to initialize listeners despite not being "used".
local userSettings = require(game.ServerScriptService.settingsServer)
userSettings.Init()

local newRaces = require(game.ServerScriptService.data.newRaces)
newRaces.Init()

local popularRaces = require(game.ServerScriptService.data.popularRaces)
popularRaces.Init()

local contests = require(game.ServerScriptService.data.contests)
contests.Init()

local dynamic = require(game.ServerScriptService.dynamicServer)
dynamic.Init()

local serverEvents = require(game.ServerScriptService.serverEvents)
serverEvents.Init()

local serverWarping = require(game.ServerScriptService.serverWarping)
serverWarping.Init()

local runEnding = require(game.ServerScriptService.runEnding)
runEnding.Init()

local setupSpecialSigns = require(game.ServerScriptService.setupSpecialSigns)
setupSpecialSigns.Init()

local playerData2 = require(game.ServerScriptService.playerData2)
local signClicking = require(game.ServerScriptService.signClicking)
signClicking.Init()

local badges = require(game.ServerScriptService.badges)
badges.Init()

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
	checkBadgesForBadIds()
	testing.TestAll()
end

_annotate("end")
