--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensureFolderExists(folderName: string): Folder
	local folder = ReplicatedStorage:FindFirstChild(folderName)
	if not folder then
		local message = string.format("Required ReplicatedStorage.%s folder is missing", folderName)
		annotater.Error(message)
		error(message)
	end
	if not folder:IsA("Folder") then
		local message = string.format(
			"ReplicatedStorage.%s is a %s, expected Folder",
			folderName,
			folder.ClassName
		)
		annotater.Error(message)
		error(message)
	end
	_annotate(string.format("Info: %s folder already exists", folderName))
	return folder :: Folder
end

local module = {}

module.CreateRemoteEventsAndRemoteFunctions = function()
	_annotate("Validating RemoteEvents, RemoteFunctions, and BindableEvents folders")

	ensureFolderExists("RemoteEvents")
	ensureFolderExists("RemoteFunctions")
	ensureFolderExists("BindableEvents")

	local remotes = require(game.ReplicatedStorage.util.remotes)

	--note: this is all pointless, the getters should do registration too if necessary.
	--note actually not, it helps having server register everything first so client/server getters don't fight.

	-- taking this over as a generic client to server message passing function
	remotes.getRemoteFunction("ClientToServerRemoteFunction")

	--send message from server to client (lb updates, sign finds, runs, marathon runs, badge grants etc.
	remotes.getRemoteEvent("ServerToClientEvent")

	--chatscript and movement guys call this to make banned players move like sludge.
	remotes.getRemoteFunction("GetBanStatusRemoteFunction")

	--blocks any timing stuff til return value comes in
	--
	remotes.getRemoteFunction("ClientRequestsWarpToRequestFunction")

	-- for sending events about user metadata etc back and forth between client and server
	-- eventually, if it even matters, it could be made generic.
	remotes.getRemoteFunction("UserDataFunction")

	remotes.getRemoteEvent("ShowClientSignProfileEvent")
	remotes.getRemoteEvent("MarathonCompleteEvent")
	remotes.getRemoteEvent("EphemeralMarathonCompleteEvent")
	remotes.getRemoteFunction("DynamicRunningFunction")
	remotes.getRemoteEvent("DynamicRunningEvent")

	-- for relaying errors from client to server
	remotes.getRemoteEvent("ErrorMessageEvent")

	-- from the client command /show
	remotes.getRemoteEvent("ShowSignsEvent")

	-- to get someone to download all their found signs? not sure.
	remotes.getRemoteEvent("ShowSignProfileEvent")

	-- for the server to tell the client to highlight something when the user does a command for example.
	-- remotes.getRemoteEvent("HighlightSignIdEvent")

	remotes.getRemoteEvent("ServerEventRemoteEvent")
	remotes.getRemoteFunction("ServerEventRemoteFunction")

	-- sent from server-side code which wants to do a warp, which the client receives, does a full warp lock, and replies TRUE when it's done.
	remotes.getRemoteEvent("ServerRequestClientToWarpLockEvent")

	-- when a user finishes a race in runEnding on server, we need to tell every player's local script about server events UI about it.
	remotes.getBindableEvent("ServerEventBindableEvent")

	remotes.getRemoteFunction("EphemeralMarathonCreateFunction")

	-- not just getting whether they have the badge or not, but also their progress within that badge class, etc in getting it.
	remotes.getRemoteFunction("BadgeProgressFunction")
	remotes.getRemoteFunction("GetUserSettingsFunction") --look up user settings from client => server, load from db, reply.
	remotes.getRemoteFunction("UserSettingsChangedFunction")
	remotes.getRemoteFunction("GetPopularRacesFunction")
	remotes.getRemoteFunction("GetNewRacesFunction")
	remotes.getRemoteFunction("GetContestsFunction")
	remotes.getRemoteFunction("GetSingleContestFunction")
	remotes.getRemoteFunction("GetArchivedContestsFunction")

	--new 2024.09. Why again do I have a billion types of events.
	remotes.getRemoteEvent("ClientToServerEvent")

	--send events to clients telling them to update their leaderboard with player stats and stuff.
	remotes.getRemoteEvent("LeaderboardUpdateEvent")

	--local player clicks sign, server generate signpopup, send it back to client
	remotes.getRemoteFunction("ClickSignFunction")

	-- Chat system (TextChatService migration 2025.11)
	_annotate("Creating ProcessCommandFunction RemoteFunction")
	remotes.getRemoteFunction("ProcessCommandFunction")
	_annotate("Creating DisplaySystemMessageEvent RemoteEvent")
	remotes.getRemoteEvent("DisplaySystemMessageEvent")
	_annotate("Chat remotes created successfully")
end

_annotate("end")
return module
