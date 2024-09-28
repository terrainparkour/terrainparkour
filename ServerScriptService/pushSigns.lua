--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local tt = require(game.ReplicatedStorage.types.gametypes)

local rdb = require(game.ServerScriptService.rdb)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local enums = require(game.ReplicatedStorage.util.enums)
local config = require(game.ReplicatedStorage.config)

local module = {}

local setSignPosition = function(data: { name: string, signId: number, x: number, y: number, z: number })
	local request: tt.postRequest = {
		remoteActionName = "setSignPosition",
		data = data,
	}
	local response = rdb.MakePostRequest(request)
end

local getKnownSignIds = function(): { [number]: boolean }
	local request: tt.postRequest = {
		remoteActionName = "getKnownSignIds",
		data = {},
	}
	local raw = rdb.MakePostRequest(request)
	local res = {}
	for signId, val in pairs(raw) do
		res[tonumber(signId)] = val
	end
	return res
end

--set them according to their positiong in generated.
module.checkSignsNeedingPushing = function()
	local knownSignIds: { [number]: boolean } = getKnownSignIds()
	-- note that the server will not fully register new signs in its cache until its been restarted.
	-- This leads to spurious local reposting of signs on server startup occasionally
	local knownSignCount = 0
	local signs = game.Workspace:FindFirstChild("Signs")
	for signname, signId in pairs(enums.name2signId) do
		if signId ~= nil then
			if knownSignIds[signId] then --TODO FORCE UPLOAD POSITIONS
				knownSignCount = knownSignCount + 1
				--server knows about sign
				continue
			end
			local signPart: Part = signs:FindFirstChild(signname)
			if signPart == nil then
				if config.isInStudio() then
					continue
				end
				warn("fail to find sign " .. signname)
				continue
			end
			warn("posting data on new sign:" .. signname)
			local pos = signPart.Position
			local data = {
				signId = signId,
				x = tpUtil.noe(pos.X),
				y = tpUtil.noe(pos.Y),
				z = tpUtil.noe(pos.Z),
				name = signname,
			}
			setSignPosition(data)
		end
	end
end

_annotate("end")
return module
