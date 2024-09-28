--!strict

-- serverutil
-- utils for server, which have rdb
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayersService = game:GetService("Players")

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local playerData2 = require(game.ServerScriptService.playerData2)
local module = {}

------------------HELPER LOGICAL METHODS----------------------------

module.UserCanInteractWithSign = function(userId: number, sign: Part): boolean
	local signId = tpUtil.signName2SignId(sign.Name)
	return module.UserCanInteractWithSignId(userId, signId)
end

-- covering both is the sign valid physically (i.e. it's enabled in the game at this moment) but also has the user even found it.
-- generally: users can't interact at all with signs
module.UserCanInteractWithSignId = function(userId: number, signId: number): boolean
	if not playerData2.HasUserFoundSign(userId, signId) then
		return false
	end

	local sign = tpUtil.signId2Sign(signId)
	if not sign then
		return false
	end

	if not tpUtil.IsSignPartValidRightNow(sign) then
		return false
	end

	return true
end

_annotate("end")
return module
