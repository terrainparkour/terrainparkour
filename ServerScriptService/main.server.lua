--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
annotater.Init()

local nocol = require(game.ServerScriptService.nocollide)
nocol.Init()

--IMPORTANT  this go first because it's where signs and everything are set up
local workspaceSetup = require(game.ServerScriptService.workspaceSetup)
workspaceSetup.createEvents()

local locationMonitor = require(game.ReplicatedStorage.locationMonitor)

local setupSigns = require(game.ServerScriptService.setupSigns)
setupSigns.Init()

local setupFindTouchMonitoring = require(game.ServerScriptService.setupFindTouchMonitoring)
setupFindTouchMonitoring.Init()

local sounds = require(game.ServerScriptService.sounds)
sounds.Init()
_annotate("done with sounds")

local pushSigns = require(game.ServerScriptService.pushSigns)
pushSigns.checkSignsNeedingPushing()
_annotate("done with pushSigns")

local presence = require(game.ServerScriptService.presence)
presence.Init()
_annotate("done with presence")

local banning = require(game.ServerScriptService.banning)
banning.Init()

local marathon = require(game.ServerScriptService.marathon)
marathon.Init()
_annotate("done with marathon")

local ephemeralMarathon = require(game.ServerScriptService.EphemeralMarathons.ephemeralMarathon)
ephemeralMarathon.Init()

local locationMonitor = require(game.ReplicatedStorage.locationMonitor)
locationMonitor.Init()
_annotate("done with locationMonitor")

--include these to initialize listeners despite not being "used".
local userSettings = require(game.ServerScriptService.userSettings)
userSettings.Init()
_annotate("done with userSettings")

local popularListener = require(game.ServerScriptService.data.popular)
popularListener.Init()
_annotate("done with popularListener")

local newListener = require(game.ServerScriptService.data.new)
newListener.Init()
_annotate("done with newListener")

local contests = require(game.ServerScriptService.data.contests)
contests.Init()
_annotate("done with contests")

local dynamic = require(game.ServerScriptService.dynamicServer)
dynamic.Init()
_annotate("done with dynamic")

local serverEvents = require(game.ServerScriptService.serverEvents)
serverEvents.Init()
_annotate("done with serverEvents")

local serverWarping = require(game.ServerScriptService.serverWarping)
serverWarping.Init()

_annotate("done with serverWarping")

local raceEnding = require(game.ServerScriptService.raceEnding)
raceEnding.Init()

_annotate("done with raceEnding")

local setupSpecialSigns = require(game.ServerScriptService.setupSpecialSigns)
setupSpecialSigns.Init()

--how  does the game work?
--good question.  mainly it's in lua client/server scripts, but via certain calls made from BE, you hit a python mysql db server you also have to have set up.  this is where all your real records and data are stored.

--how does this open source thing work, since if I use it, I won't have those things set up?
--I'm attempting to add a fake layer so at least in memory of the server, you will have records of some kind. that, or many calls will return fake values or at least messages saying "please set up the backend"

--will you make the backend open source too?
--I'm thinking about this.  it's possible. it would be cool to see what people could do with this setup.
_annotate("end")
