--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

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
	remotes.getRemoteFunction("ClientRequestsWarpToRequestFunction")

	-- for sending events about user metadata etc back and forth between client and server
	-- eventually, if it even matters, it could be made generic.
	remotes.getRemoteFunction("UserDataMessageFunction")

	remotes.getRemoteEvent("ShowClientSignProfileEvent")
	remotes.getRemoteEvent("MarathonCompleteEvent")
	remotes.getRemoteEvent("EphemeralMarathonCompleteEvent")
	remotes.getRemoteFunction("DynamicRunningFunction")
	remotes.getRemoteEvent("DynamicRunningEvent")

	-- from the client command /show
	remotes.getRemoteEvent("ShowSignsEvent")

	-- to get someone to download all their found signs? not sure.
	remotes.getRemoteEvent("ShowSignProfileEvent")
	remotes.getRemoteEvent("TellServerRunEndedRemoteEvent")

	-- for the server to tell the client to highlight something when the user does a command for example.
	-- remotes.getRemoteEvent("HighlightSignIdEvent")

	remotes.getRemoteEvent("ServerEventRemoteEvent")
	remotes.getRemoteFunction("ServerEventRemoteFunction")

	-- sent from server-side code which wants to do a warp, which the client receives, does a full warp lock, and replies TRUE when it's done.
	remotes.getRemoteEvent("ServerRequestClientToWarpLockEvent")

	-- when a user finishes a race in runEnding on server, we need to tell every player's local script about server events UI about it.
	remotes.getBindableEvent("ServerEventBindableEvent")

	remotes.getRemoteFunction("EphemeralMarathonCreateFunction")
	remotes.getRemoteFunction("BadgeAttainmentsFunction")
	remotes.getRemoteFunction("GetUserSettingsFunction") --look up user settings from client => server, load from db, reply.
	remotes.getRemoteFunction("UserSettingsChangedFunction")
	remotes.getRemoteFunction("GetPopularRunsFunction")
	remotes.getRemoteFunction("GetNewRunsFunction")
	remotes.getRemoteFunction("GetContestsFunction")
	remotes.getRemoteFunction("GetSingleContestFunction")

	--send message from server to client (notifier, etc.)
	remotes.getRemoteEvent("MessageReceivedEvent")

	--send events to clients telling them to update their leaderboard with player stats and stuff.
	remotes.getRemoteEvent("LeaderboardUpdateEvent")

	--local player clicks sign, server generate signpopup, send it back to client
	remotes.getRemoteFunction("ClickSignRemoteFunction")
end

_annotate("end")
return module
