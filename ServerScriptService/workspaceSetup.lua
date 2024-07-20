--!strict

--eval 9.25.22

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

	local be = Instance.new("Folder")
	be.Name = "BindableEvents"
	be.Parent = ReplicatedStorage

	local remotes = require(game.ReplicatedStorage.util.remotes)

	--note: this is all pointless, the getters should do registration too if necessary.
	--note actually not, it helps having server register everything first so client/server getters don't fight.

	--chatscript and movement guys call this to make banned players move like sludge.
	remotes.getRemoteFunction("GetBanStatusRemoteFunction")

	--blocks any timing stuff til return value comes in
	--
	remotes.getRemoteFunction("warpRequestFunction")

	--server calls this to hook into normal client warp locking.
	--then client calls back
	remotes.getRemoteFunction("serverWantsWarpFunction")
	remotes.getRemoteEvent("ShowClientSignProfileEvent")
	remotes.getRemoteEvent("MarathonCompleteEvent")
	remotes.getRemoteEvent("EphemeralMarathonCompleteEvent")
	remotes.getRemoteFunction("DynamicRunningFunction")
	remotes.getRemoteEvent("DynamicRunningEvent")

	remotes.getRemoteEvent("ServerEventRemoteEvent")
	remotes.getRemoteFunction("ServerEventRemoteFunction")
	remotes.getBindableEvent("warpStartingBindableEvent")
	remotes.getBindableEvent("warpDoneBindableEvent")

	remotes.getRemoteFunction("EphemeralMarathonCreateFunction")
	remotes.getRemoteFunction("BadgeAttainmentsFunction")
	remotes.getRemoteFunction("GetUserSettingsFunction") --look up user settings
	remotes.getRemoteFunction("UserSettingsChangedFunction") --look up user settings
	remotes.getRemoteFunction("GetPopularRunsFunction")
	remotes.getRemoteFunction("GetNewRunsFunction")
	remotes.getRemoteFunction("GetContestsFunction")
	remotes.getRemoteFunction("GetSingleContestFunction")

	remotes.getRemoteEvent("RunStartEvent")

	--used for tellign the client to stop displaying the run in progress..
	remotes.getRemoteEvent("RunEndEvent")

	--artificially tell server the actual runtime of an end
	remotes.getRemoteEvent("ClientControlledRunEndEvent")

	--send message from server to client (notifier, etc.)
	remotes.getRemoteEvent("MessageReceivedEvent")

	--TODO is this actually used and why is it a remote function at all?
	remotes.getRemoteFunction("CancelRunRemoteFunction")

	--send events to clients telling them to update their leaderboard with player stats and stuff.
	remotes.getRemoteEvent("LeaderboardUpdateEvent")

	--local player clicks sign, server generate signpopup, send it back to client
	remotes.getRemoteFunction("ClickSignRemoteFunction")

	remotes.getBindableEvent("ServerEventBindableEvent")
end

return module
