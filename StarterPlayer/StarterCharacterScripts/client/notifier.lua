--!strict

--runs on playerside for notifications
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local config = require(game.ReplicatedStorage.config)
local tt = require(game.ReplicatedStorage.types.gametypes)

local remotes = require(game.ReplicatedStorage.util.remotes)

local runResultsGuiCreator = require(game.ReplicatedStorage.gui.runresults.runResultsGuiCreator)
local findResultsCreator = require(game.ReplicatedStorage.gui.runresults.findGuiCreator)
local ephemeralNotifications = require(game.ReplicatedStorage.gui.ephemeralNotificationCreator)

local PlayersService = game:GetService("Players")

local localPlayer = PlayersService.LocalPlayer

local playerGui = localPlayer:WaitForChild("PlayerGui")
local warper = require(game.StarterPlayer.StarterPlayerScripts.warper)

type legacyOptions = {}

--notify player of something.
local function clientReceiveNotification(options: any)
	if config.isInStudio() then
		_annotate("client receive notifications:" .. options.kind)
		_annotate(options)
	end
	if options.kind == "race results" then
		options = options :: tt.pyUserFinishedRunResponse
		local thing = runResultsGuiCreator.createNewRunResultSgui(options, warper)
		thing.Parent = playerGui
		return
	end
	if options.kind == "userFoundSign" then
		options = options :: tt.signFindOptions
		local thing = findResultsCreator.createFindScreenGui(options)
		thing.Parent = playerGui
		return
	end

	if options.kind == "marathon results" then
		options = options :: tt.pyUserFinishedRunResponse
		local thing = runResultsGuiCreator.createNewRunResultSgui(options, { WarpToSign = warper.WarpToSign })
		thing.Parent = playerGui
		return
	end

	--fallback to ephemeral
	local actionResultOptions: tt.ephemeralNotificationOptions = options :: tt.ephemeralNotificationOptions
	ephemeralNotifications.notify(actionResultOptions, warper)
end

--set up events.
local messageReceivedEvent = remotes.getRemoteEvent("MessageReceivedEvent")
messageReceivedEvent.OnClientEvent:Connect(function(options)
	clientReceiveNotification(options)
end)

_annotate("end")
return {}
