--!strict

--eval 9.25.22

local nocol = require(game.ServerScriptService.nocollide)
nocol.init()

--IMPORTANT  this go first because it's where signs and everything are set up
local workspaceSetup = require(game.ServerScriptService.workspaceSetup)
workspaceSetup.createEvents()

local locationMonitor = require(game.ReplicatedStorage.locationMonitor)

local setupSigns = require(game.ServerScriptService.setupSigns)
setupSigns.init()

local pushSigns = require(game.ServerScriptService.pushSigns)
pushSigns.checkSignsNeedingPushing()

local presence = require(game.ServerScriptService.presence)
presence.init()

local banning = require(game.ServerScriptService.banning)
banning.init()

local marathon = require(game.ServerScriptService.marathon)
marathon.init()

local ephemeralMarathon = require(game.ServerScriptService.EphemeralMarathons.ephemeralMarathon)
ephemeralMarathon.init()

locationMonitor.init()

--include these to initialize listeners despite not being "used".
local us = require(game.ServerScriptService.userSettings)
us.init()

local popularListener = require(game.ServerScriptService.data.popular)
popularListener.init()

local newListener = require(game.ServerScriptService.data.new)
newListener.init()

local contests = require(game.ServerScriptService.data.contests)
contests.init()

local dynamic = require(game.ServerScriptService.dynamicServer)
dynamic.init()

local serverEvents = require(game.ServerScriptService.serverEvents)
serverEvents.init()

--how  does the game work?
--good question.  mainly it's in lua client/server scripts, but via certain calls made from BE, you hit a python mysql db server you also have to have set up.  this is where all your real records and data are stored.

--how does this open source thing work, since if I use it, I won't have those things set up?
--I'm attempting to add a fake layer so at least in memory of the server, you will have records of some kind. that, or many calls will return fake values or at least messages saying "please set up the backend"

--will you make the backend open source too?
--I'm thinking about this.  it's possible. it would be cool to see what people could do with this setup.
