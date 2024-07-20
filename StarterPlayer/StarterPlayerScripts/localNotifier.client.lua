--!strict

--eval 9.25.22
--runs on playerside for notifications

local config = require(game.ReplicatedStorage.config)
local tt = require(game.ReplicatedStorage.types.gametypes)

local runResultsGuiCreator = require(game.ReplicatedStorage.gui.runresults.runResultsGuiCreator)
local findResultsCreator = require(game.ReplicatedStorage.gui.runresults.findGuiCreator)

local ephemeralNotifications = require(game.ReplicatedStorage.gui.ephemeralNotificationCreator)

local PlayersService = game:GetService("Players")
repeat
	game:GetService("RunService").RenderStepped:wait()
until game.Players.LocalPlayer.Character ~= nil
local localPlayer = PlayersService.LocalPlayer

local playerGui = localPlayer:WaitForChild("PlayerGui")
local warper = require(game.StarterPlayer.StarterPlayerScripts.util.warperClient)

type legacyOptions = {}

--notify player of something.
local function clientReceiveNotification(options: any)
	if config.isInStudio() then
		-- print("client receive notifications:" .. options.kind)
		-- print(options)
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
		local thing =
			runResultsGuiCreator.createNewRunResultSgui(options, { requestWarpToSign = warper.requestWarpToSign })
		thing.Parent = playerGui
		return
	end

	--fallback to ephemeral
	local actionResultOptions: tt.ephemeralNotificationOptions = options :: tt.ephemeralNotificationOptions
	ephemeralNotifications.notify(actionResultOptions, warper)
end

--set up events.
local function init()
	local remotes = require(game.ReplicatedStorage.util.remotes)
	local messageReceivedEvent = remotes.getRemoteEvent("MessageReceivedEvent")
	messageReceivedEvent.OnClientEvent:Connect(function(options)
		clientReceiveNotification(options)
	end)
end

init()
