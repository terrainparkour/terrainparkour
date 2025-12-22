--!strict

-- notifyClient.lua
-- Client-side handler for all server notifications via ServerToClientEvent.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local config = require(game.ReplicatedStorage.config)
local tt = require(game.ReplicatedStorage.types.gametypes)

local drawRunResultGui = require(game.ReplicatedStorage.gui.runresults.drawRunResultGui)
local drawFindGui = require(game.ReplicatedStorage.gui.runresults.drawFindGui)
local drawWRHistoryProgressionGui = require(game.ReplicatedStorage.gui.menu.drawWRHistoryProgressionGui)
local badgeCompareGui = require(game.ReplicatedStorage.gui.menu.badgeCompareGui)
local ephemeralNotifications = require(game.ReplicatedStorage.gui.ephemeralNotificationCreator)

local module = {}

local function clientReceiveNotification(notification: tt.serverToClientNotification)
	if config.IsInStudio() then
		_annotate("client receive notification: " .. tostring(notification.kind))
	end

	if notification.kind == "userFoundSign" then
		local findResponse = notification :: tt.dcFindResponse
		_annotate(
			string.format(
				"received userFoundSign userId=%d signId=%d signName=%s foundNew=%s",
				findResponse.userId,
				findResponse.signId,
				findResponse.signName,
				tostring(findResponse.foundNew)
			)
		)
		drawFindGui.CreateFindScreenGui(findResponse)
	elseif notification.kind == "raceResults" then
		local raceResponse = notification :: tt.raceResultsNotification
		drawRunResultGui.DrawRunResultGui(raceResponse)
	elseif notification.kind == "marathonResults" then
		local marathonResponse = notification :: tt.marathonResultsNotification
		drawRunResultGui.DrawRunResultGui(marathonResponse)
	elseif notification.kind == "wrProgression" then
		local wrResponse = notification :: tt.wrProgressionNotification
		if wrResponse.raceExists then
			drawWRHistoryProgressionGui.CreateWRHistoryProgressionGui(wrResponse)
		end
	elseif notification.kind == "wrProgressionChart" then
		local wrResponse = notification :: tt.wrProgressionChartNotification
		if wrResponse.raceExists then
			drawWRHistoryProgressionGui.ShowWRProgressionChart(wrResponse)
		end
	elseif notification.kind == "badgeCompare" then
		local payload = notification :: tt.badgeCompareNotification
		badgeCompareGui.ShowBadgeCompare(payload)
	elseif notification.kind == "badge received" then
		-- Badge notifications with optional badge icon
		local badgeOptions = notification :: tt.badgeOptions
		ephemeralNotifications.notifyBadge(badgeOptions)
	else
		-- Ephemeral notifications (action results, etc.)
		local actionResultOptions = notification :: tt.ephemeralNotificationOptions
		if actionResultOptions.text then
			ephemeralNotifications.notify(actionResultOptions)
		else
			annotater.Error(
				string.format("clientReceiveNotification: unrecognized notification kind=%s", tostring(notification.kind)),
				{ kind = notification.kind }
			)
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
