--!strict

-- playerData2.lua on the server.
--generic getters for player information for use by commands or UIs or LBs

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local tt = require(game.ReplicatedStorage.types.gametypes)
local playerData2 = require(game.ServerScriptService.playerData2)
local remotes = require(game.ReplicatedStorage.util.remotes)
local ClickSignFunction: RemoteFunction = remotes.getRemoteFunction("ClickSignFunction")
local signProfileCommand = require(game.ReplicatedStorage.commands.signProfileCommand)
local badgeCheckers = require(game.ServerScriptService.badgeCheckersSecret)

local function showSignLeadersPopup(player: Player, signId: number)
	local got = 0
	local relatedSignData = {}

	local signWRLeaderData: { tt.signWrStatus }
	local s1, e1 = pcall(function()
		relatedSignData = playerData2.getRelatedSigns(signId, player.UserId)
		got = got + 1
	end)

	if not s1 then
		warn("failed to get related signs." .. e1)
		relatedSignData = {}
		got = got + 1
	end

	local s2, e2 = pcall(function()
		signWRLeaderData = playerData2.getSignWRLeader(signId)
		got = got + 1
	end)

	if not s2 then
		warn("failed to get sign WR Data." .. e2)
		signWRLeaderData = {}
		got = got + 1
	end

	badgeCheckers.CheckBadgeGrantingFromSignWrLeaderData(signWRLeaderData, player.UserId)

	while true do
		if got == 2 then
			local res = {
				signWRLeaderData = signWRLeaderData,
				relatedSignData = relatedSignData,
			}
			return res
		end
		wait(0.3)
	end
end

module.Init = function()
	ClickSignFunction.OnServerInvoke = function(player: Player, signClickMessage: tt.signClickMessage): any
		if signClickMessage.leftClick then
			return showSignLeadersPopup(player, signClickMessage.signId)
		else
			signProfileCommand.signProfileCommand(player.Name, signClickMessage.signId, player)
		end
	end
end

_annotate("end")
return module
