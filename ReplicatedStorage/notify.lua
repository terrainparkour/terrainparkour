--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayersService = game:GetService("Players")
local emt = require(game.ServerScriptService.EphemeralMarathons.ephemeralMarathonTypes)
local tt = require(game.ReplicatedStorage.types.gametypes)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local enums = require(game.ReplicatedStorage.util.enums)
local config = require(game.ReplicatedStorage.config)

local module = {}

local re = require(game.ReplicatedStorage.util.remotes)
local messageReceivedEvent = re.getRemoteEvent("MessageReceivedEvent")

--internal method to actually send notifications.

module.notifyPlayerAboutMarathonResults = function(player: Player, options: tt.pyUserFinishedRunResponse)
	messageReceivedEvent:FireClient(player, options)
end

module.notifyPlayerAboutBadge = function(player: Player, options: tt.badgeOptions)
	_annotate("badge notif")
	_annotate(options)
	messageReceivedEvent:FireClient(player, options)
end

module.notifyPlayerOfRunResults = function(player: Player, options: tt.pyUserFinishedRunResponse)
	messageReceivedEvent:FireClient(player, options)
end

module.notifyPlayerOfSignFind = function(player: Player, options: tt.signFindOptions)
	messageReceivedEvent:FireClient(player, options)
end

module.notifyPlayerOfEphemeralMarathonRun = function(player: Player, res: emt.emRunResults)
	warn("not set up.")
end

--notify other players in the server of interesting things that happened.
--like someone earning tix, setting a WR, pushing someone's score down
module.handleActionResults = function(actionResults: { tt.actionResult })
	if not actionResults or #actionResults == 0 then
		return
	end
	local rdb = require(game.ServerScriptService.rdb)
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
		local arSubjectPlayer = tpUtil.getPlayerByUserId(arSubjectUserId)
		if arSubjectPlayer == nil then
			-- _annotate("player was not in server, this is okay.")
			continue
		end
		if actionResult.notifyAllExcept then
			for _, op in ipairs(PlayersService:GetPlayers()) do
				local useMessage = actionResult.message
				if op.UserId == arSubjectPlayer.UserId then
					if config.isInStudio() then
						useMessage = actionResult.message .. " (studio only)"
					else
						continue
					end
				end

				--filter this out if the person we are notifying isn't allowed to warp to it
				local useWarpToSignId = (
					actionResult.warpToSignId
					and rdb.hasUserFoundSign(op.UserId, actionResult.warpToSignId)
					and not enums.SignIdIsExcludedFromStart[actionResult.warpToSignId]
					and actionResult.warpToSignId
				) or 0

				module.notifyPlayerAboutActionResult(op, {
					userId = actionResult.userId,
					text = useMessage,
					kind = actionResult.kind,
					warpToSignId = useWarpToSignId,
				})
			end
		else
			local useWarpToSignId = (
				actionResult.warpToSignId
				and rdb.hasUserFoundSign(arSubjectPlayer.UserId, actionResult.warpToSignId)
				and not enums.SignIdIsExcludedFromStart[actionResult.warpToSignId]
				and actionResult.warpToSignId
			) or 0
			module.notifyPlayerAboutActionResult(arSubjectPlayer, {
				userId = actionResult.userId,
				text = actionResult.message,
				kind = actionResult.kind,
				warpToSignId = useWarpToSignId,
			})
		end
	end
end

module.notifyPlayerAboutActionResult = function(player: Player, options: tt.ephemeralNotificationOptions)
	messageReceivedEvent:FireClient(player, options)
end

_annotate("end")
return module
