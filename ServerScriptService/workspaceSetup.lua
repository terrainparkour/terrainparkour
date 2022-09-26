--!strict

--eval 9.25.22

local remotes = require(game.ReplicatedStorage.util.remotes)

local module = {}

module.createEvents = function()
	--setting up race event
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local fe = Instance.new("Folder")
	fe.Name = "RemoteEvents"
	fe.Parent = ReplicatedStorage
	local fr = Instance.new("Folder")
	fr.Name = "RemoteFunctions"
	fr.Parent = ReplicatedStorage

	--notify client that a race which already started, has an updated (later) start time.
	-- remotes.registerRemoteEvent("DelayedStartTimeUpdateEvent")

	--chatscript and movement guys call this to make banned players move like sludge.
	remotes.registerRemoteFunction("GetBanStatusRemoteFunction")

	--blocks any timing stuff til return value comes in
	--
	remotes.registerRemoteFunction("WarpRequestFunction")

	--server calls this to hook into normal client warp locking.
	--then client calls back
	remotes.registerRemoteFunction("ServerWantsWarpFunction")

	remotes.registerRemoteEvent("MarathonCompleteEvent")
	remotes.registerRemoteEvent("EphemeralMarathonCompleteEvent")
	remotes.registerRemoteFunction("DynamicRunningFunction")
	remotes.registerRemoteEvent("DynamicRunningEvent")

	remotes.registerRemoteFunction("EphemeralMarathonCreateFunction")
	remotes.registerRemoteFunction("BadgeAttainmentsFunction")
	remotes.registerRemoteFunction("GetUserSettingsFunction") --look up user settings
	remotes.registerRemoteFunction("UserSettingsChangedFunction") --look up user settings
	remotes.registerRemoteFunction("GetPopularRunsFunction")
	remotes.registerRemoteFunction("GetNewRunsFunction")
	remotes.registerRemoteFunction("GetContestsFunction")
	remotes.registerRemoteFunction("GetSingleContestFunction")

	remotes.registerRemoteEvent("RunStartEvent")

	--used for tellign the client to stop displaying the run in progress..
	remotes.registerRemoteEvent("RunEndEvent")

	--artificially tell server the actual runtime of an end
	remotes.registerRemoteEvent("ClientControlledRunEndEvent")

	--send message from server to client (notifier, etc.)
	remotes.registerRemoteEvent("MessageReceivedEvent")

	--TODO is this actually used and why is it a remote function at all?
	remotes.registerRemoteFunction("CancelRunRemoteFunction")

	--send events to clients telling them to update their leaderboard with player stats and stuff.
	remotes.registerRemoteEvent("LeaderboardUpdateEvent")

	--local player clicks sign, server generate signpopup, send it back to client
	remotes.registerRemoteFunction("ClickSignRemoteFunction")
end

return module
