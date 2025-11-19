--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local tt = require(game.ReplicatedStorage.types.gametypes)

local rdb = require(game.ServerScriptService.rdb)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local enums = require(game.ReplicatedStorage.util.enums)
local config = require(game.ReplicatedStorage.config)

local module = {}

type SignPositionData = { name: string, signId: number, x: number, y: number, z: number }

local setSignPositions = function(dataList: { SignPositionData })
	if #dataList == 0 then
		return
	end
	local request: tt.postRequest = {
		remoteActionName = "setSignPositions",
		data = dataList,
	}
	rdb.MakePostRequest(request)
end

local getKnownSignIds = function(): { [number]: boolean }
	local startTime = tick()
	local request: tt.postRequest = {
		remoteActionName = "getKnownSignIds",
		data = {},
	}
	_annotate(string.format("getKnownSignIds: request prepared in %.3fs", tick() - startTime))
	local requestStartTime = tick()
	local raw = rdb.MakePostRequest(request)
	_annotate(string.format("getKnownSignIds: POST request took %.3fs", tick() - requestStartTime))
	local parseStartTime = tick()
	local res: { [number]: boolean } = {}
	if typeof(raw) ~= "table" then
		_annotate("getKnownSignIds: response was not a table")
		return res
	end
	for _, signId in pairs(raw) do
		if signId == nil then
			continue
		end
		local numericId = tonumber(signId)
		if numericId then
			res[numericId] = true
		end
	end
	_annotate(string.format("getKnownSignIds: parsing took %.3fs, total %.3fs", tick() - parseStartTime, tick() - startTime))
	return res
end

-- Set sign positions according to their location in generated workspace.
module.CheckSignsNeedingPushing = function()
	local startTime = tick()
	local signs = game.Workspace:FindFirstChild("Signs")
	if not signs then
		_annotate("CheckSignsNeedingPushing: Signs folder not found")
		return
	end
	_annotate(string.format("CheckSignsNeedingPushing: found Signs folder in %.3fs", tick() - startTime))

	local fetchStartTime = tick()
	local knownSignIds: { [number]: boolean } = getKnownSignIds()
	_annotate(string.format("CheckSignsNeedingPushing: fetched known sign IDs in %.3fs", tick() - fetchStartTime))
	local signsToUpload: { SignPositionData } = {}

	for signName, signId in pairs(enums.name2signId) do
		if signId ~= nil and not knownSignIds[signId] then
			local signPart = signs:FindFirstChild(signName)
			if not signPart then
				if not config.IsInStudio() then
					annotater.Error(string.format("checkSignsNeedingPushing: fail to find sign %s", signName))
				end
				continue
			end
			local part = signPart :: Part

			_annotate(string.format("queuing data on new sign: %s", signName))
			local pos = part.Position
			table.insert(signsToUpload, {
				signId = signId,
				x = tpUtil.noe(pos.X),
				y = tpUtil.noe(pos.Y),
				z = tpUtil.noe(pos.Z),
				name = signName,
			})
		end
	end

	-- Batch upload all new signs in single request.
	-- Note: server will not fully register new signs in its cache until restart,
	-- which leads to spurious local reposting of signs on server startup occasionally.
	if #signsToUpload > 0 then
		_annotate(string.format("uploading %d new sign positions", #signsToUpload))
		setSignPositions(signsToUpload)
	end
end

_annotate("end")
return module
