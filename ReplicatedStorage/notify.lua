--!strict

-- notify on server for spreading out various types of related activity notifications

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local playerData2 = require(game.ServerScriptService.playerData2)
local emt = require(game.ServerScriptService.EphemeralMarathons.ephemeralMarathonTypes)
local tt = require(game.ReplicatedStorage.types.gametypes)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local enums = require(game.ReplicatedStorage.util.enums)
local config = require(game.ReplicatedStorage.config)
local PlayersService = game:GetService("Players")
local remotes = require(game.ReplicatedStorage.util.remotes)
local ServerToClientEvent = remotes.getRemoteEvent("ServerToClientEvent")

local module = {}

module.playerNotificationTypes = {
	userFoundSign = "userFoundSign",
	userFinishedRun = "userFinishedRun",
	userFinishedMarathon = "userFinishedMarathon",
	userEarnedBadge = "userEarnedBadge",
	tellPlayersTheirFoundSignIds = "tellPlayersTheirFoundSignIds",
}

--internal method to actually send notifications.

local function notifyPlayerAboutMarathonResults(player: Player, options: tt.userFinishedRunResponse)
	ServerToClientEvent:FireClient(player, options)
end
module.notifyPlayerAboutMarathonResults = notifyPlayerAboutMarathonResults

local function notifyPlayerAboutBadge(player: Player, options: tt.badgeOptions)
	_annotate("badge notif")
	ServerToClientEvent:FireClient(player, options)
end
module.notifyPlayerAboutBadge = notifyPlayerAboutBadge

local function notifyPlayerOfSignFind(player: Player, options: tt.dcFindResponse)
	_annotate(
		string.format(
			"notifyPlayerOfSignFind: firing to player=%s userId=%d signId=%d signName=%s foundNew=%s",
			player.Name,
			options.userId,
			options.signId,
			options.signName,
			tostring(options.foundNew)
		)
	)
	ServerToClientEvent:FireClient(player, options)
	_annotate(string.format("notifyPlayerOfSignFind: fired successfully"))
end
module.notifyPlayerOfSignFind = notifyPlayerOfSignFind

local function notifyPlayerOfEphemeralMarathonRun(player: Player, res: emt.emRunResults)
	annotater.Error("not set up.", player.UserId)
	warn("not set up.")
end
module.notifyPlayerOfEphemeralMarathonRun = notifyPlayerOfEphemeralMarathonRun

local function notifyPlayerAboutActionResult(player: Player, options: tt.ephemeralNotificationOptions)
	ServerToClientEvent:FireClient(player, options)
end
module.notifyPlayerAboutActionResult = notifyPlayerAboutActionResult

--notify other players in the server of interesting things that happened.
--like someone earning tix, setting a WR, pushing someone's score down
local function handleActionResults(actionResults: { tt.actionResult })
	if not actionResults or #actionResults == 0 then
		return
	end

	-- we load this very late since there is circular dependency otherwise.

	for _, actionResult in ipairs(actionResults) do
		if actionResult.userId == nil or actionResult.userId == 0 then
			warn("bad userid came in on message entirely" .. actionResult.userId)
			continue
		end
		local arSubjectUserId: number = actionResult.userId :: number

		if arSubjectUserId == 0 then
			warn("bad targetUserId came in on message entirely" .. arSubjectUserId)
			continue
		end
		local arSubjectPlayer: Player? = tpUtil.getPlayerByUserId(arSubjectUserId)
		if arSubjectPlayer == nil then
			_annotate("player was not in server, this is okay.")
			continue
		end
		local subjectPlayer: Player = arSubjectPlayer :: Player
		if actionResult.notifyAllExcept then
			for _, op in ipairs(PlayersService:GetPlayers()) do
				local useMessage = actionResult.message
				if op.UserId == subjectPlayer.UserId then
					if config.IsInStudio() then
						useMessage = actionResult.message .. " (studio only)"
					else
						continue
					end
				end

				--filter this out if the person we are notifying isn't allowed to warp to it
				local useWarpToSignId = (
					actionResult.warpToSignId
					and playerData2.HasUserFoundSign(op.UserId, actionResult.warpToSignId)
					and not enums.SignIdIsExcludedFromStart[actionResult.warpToSignId]
					and actionResult.warpToSignId
				) or 0

				notifyPlayerAboutActionResult(op, {
					userId = actionResult.userId,
					text = useMessage,
					kind = actionResult.kind,
					warpToSignId = useWarpToSignId,
				})
			end
		else
			local useWarpToSignId = (
				actionResult.warpToSignId
				and playerData2.HasUserFoundSign(subjectPlayer.UserId, actionResult.warpToSignId)
				and not enums.SignIdIsExcludedFromStart[actionResult.warpToSignId]
				and actionResult.warpToSignId
			) or 0
			notifyPlayerAboutActionResult(subjectPlayer, {
				userId = actionResult.userId,
				text = actionResult.message,
				kind = actionResult.kind,
				warpToSignId = useWarpToSignId,
			})
		end
	end
end
module.handleActionResults = handleActionResults

_annotate("end")
return module
