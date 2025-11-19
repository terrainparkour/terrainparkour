--!strict

-- notifier.lua
--runs on playerside for notifications
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local module = {}

local config = require(game.ReplicatedStorage.config)
local tt = require(game.ReplicatedStorage.types.gametypes)

local drawRunResultsGui = require(game.ReplicatedStorage.gui.runresults.drawRunResultsGui)

local drawFindGui = require(game.ReplicatedStorage.gui.runresults.drawFindGui)
local ephemeralNotifications = require(game.ReplicatedStorage.gui.ephemeralNotificationCreator)

type legacyOptions = {}

--notify player of something.
-- note: 2024, I am taking this over and instead generically probably going ot handle it in clientCommands.
local function clientReceiveNotification(pythonResponse: any)
	if config.IsInStudio() then
		_annotate("client receive notifications:" .. tostring(pythonResponse.kind))
	end
	if pythonResponse.kind == "race results" then
		drawRunResultsGui.DrawRunResultsGui(pythonResponse)
		return
	elseif pythonResponse.kind == "userFoundSign" then
		local dcFindResponse = pythonResponse :: tt.dcFindResponse
		_annotate(
			string.format(
				"clientReceiveNotification: received userFoundSign userId=%d signId=%d signName=%s foundNew=%s",
				dcFindResponse.userId,
				dcFindResponse.signId,
				dcFindResponse.signName,
				tostring(dcFindResponse.foundNew)
			)
		)
		drawFindGui.CreateFindScreenGui(dcFindResponse)
		_annotate("clientReceiveNotification: drawFindGui.CreateFindScreenGui called")
		return
	elseif pythonResponse.kind == "marathon results" then
		pythonResponse = pythonResponse :: tt.userFinishedRunResponse
		drawRunResultsGui.DrawRunResultsGui(pythonResponse)
		return
	else
		if pythonResponse.kind then
			--fallback to ephemeral
			local actionResultOptions: tt.ephemeralNotificationOptions =
				pythonResponse :: tt.ephemeralNotificationOptions
			ephemeralNotifications.notify(actionResultOptions)
		else
			warn("bad response.")
		end
	end
end

module.Init = function()
	_annotate("init")
	local remotes = require(game.ReplicatedStorage.util.remotes)
	local ServerToClientEvent = remotes.getRemoteEvent("ServerToClientEvent")

	ServerToClientEvent.OnClientEvent:Connect(function(options)
		clientReceiveNotification(options)
	end)
	_annotate("init done")
end

_annotate("end")
return module
