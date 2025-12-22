--!strict

-- receiveClientEventServer.lua listens for client events and just trusts them.
-- avatar morphs, etc.

local runEnding = require(script.Parent.runEnding)
local serverRunTiming = require(script.Parent.serverRunTiming)
local rdb = require(script.Parent.rdb)
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local config = require(game.ReplicatedStorage.config)
local enums = require(game.ReplicatedStorage.util.enums)

local module = {}

local tt = require(game.ReplicatedStorage.types.gametypes)
local remotes = require(game.ReplicatedStorage.util.remotes)
local runResultsCommand = require(game.ReplicatedStorage.commands.runResultsCommand)
local wrProgressionCommand = require(game.ReplicatedStorage.commands.wrProgressionCommand)
local pinRaceCommand = require(game.ReplicatedStorage.commands.pinRaceCommand)
local userFavoriteRacesCommand = require(game.ReplicatedStorage.commands.userFavoriteRacesCommand)
local tpUtil: typeof(require(game.ReplicatedStorage.util.tpUtil)) = require(game.ReplicatedStorage.util.tpUtil)
local notify = require(game.ReplicatedStorage.notify)

-- local GenericClientUIEvent = remotes.getRemoteEvent("GenericClientUIEvent")
local GenericClientUIFunction = remotes.getRemoteFunction("GenericClientUIFunction")

--in new trust the client code, just call this directly with the actual details.
--note: server-side timing is now tracked via serverRunTiming module for security analysis.

local function handleRunStartNotification(player: Player, data: tt.runStartDataFromClient)
	_annotate(string.format("handleRunStartNotification: userId=%d signId=%d signName=%s clientPing=%dms clientTick=%.3f", player.UserId, data.startSignId, data.startSignName, data.networkPingMs or 0, data.clientTick))
	serverRunTiming.RecordRunStart(player.UserId, data.startSignId, data.startSignName, data.clientTick)
	return true
end

local function handleAvatarMorph(player: Player, data: tt.avatarMorphData)
	_annotate("handleAvatarMorph", data)

	local didAnything = false

	if data.transparency then
		_annotate("got request to set character transparency to: " .. tostring(data.transparency))
		local targetCharacter = player.Character
		if targetCharacter then
			local targetTransparency = data.transparency
			for i, v: Instance in pairs(targetCharacter:GetDescendants()) do
				-- print(v.Name, v.ClassName)
				if v:IsA("Decal") or v:IsA("MeshPart") then
					local part = v :: any
					if part.Transparency ~= targetTransparency then
						part.Transparency = targetTransparency
						didAnything = true
					end
				end
			end
		end
	end
	if data.scale then
		local targetCharacter = player.Character
		if targetCharacter then
			local currentScale = targetCharacter:GetScale()
			if currentScale ~= data.scale then
				_annotate(string.format("Rescaling character from currentScale=%f to desiredScale=%f", currentScale, data.scale))
				targetCharacter:ScaleTo(data.scale)
				didAnything = true
			end
		end
	end
	return didAnything
end

local function handleWRProgressionRequest(player: Player, data: { startSignId: number, endSignId: number })
	_annotate("handleWRProgressionRequest", data)

	local startSignId, endSignId = data.startSignId, data.endSignId

	local res = wrProgressionCommand.GetWRProgression(player, startSignId, endSignId, false)
	return res
end

local function handleWRProgressionChartRequest(player: Player, data: { startSignId: number, endSignId: number })
	_annotate("handleWRProgressionChartRequest", data)

	local startSignId, endSignId = data.startSignId, data.endSignId

	local res = wrProgressionCommand.GetWRProgression(player, startSignId, endSignId, true)
	return res
end

local function handleRunEndingRequest(player: Player, data: tt.runEndingDataFromClient)
	_annotate("handleRunResultsRequest", data)

	return runEnding.DoRunEnd(player, data)
end

local function handleRunResultsRequest(player: Player, data: any)
	_annotate("handleRunResultsDelivery", data)

	local result = runResultsCommand.SendRunResults(player, data.startSignId, data.endSignId)
	if result.raceNotFound then
		local startName = tpUtil.signId2signName(data.startSignId)
		local endName = tpUtil.signId2signName(data.endSignId)
		notify.notifyPlayerAboutActionResult(player, {
			userId = player.UserId,
			text = string.format("No one has run %s-%s yet. Be the first!", startName, endName),
			kind = "info",
			warpToSignId = 0,
		})
	end
	return result.success
end

local function handlePinRaceRequest(player: Player, data: any)
	_annotate("handlePinRaceRequest", data)
	local res = pinRaceCommand.PinRace(player, data.startSignId, data.endSignId)
	if not res.success then
		error("nil response from PinRace")
	end
	return res
end

local function handleAdjustFavoriteRaceRequest(player: Player, data: any)
	_annotate("handleAdjustFavoriteRaceRequest", data)
	local res = userFavoriteRacesCommand.AdjustFavoriteRace(player, data.signId1, data.signId2, data.favoriteStatus)
	return res
end

local function handleFavoriteRacesRequest(player: Player, data: any): tt.serverFavoriteRacesResponse
	_annotate("handleFavoriteRacesRequest", data)
	local res = userFavoriteRacesCommand.GetFavoriteRaces(player, data.targetUserId, data.requestingUserId, data.otherUserIds)
	-- if not res.success then
	-- 	error("GetFavoriteRaces failed")
	-- end
	return res
end

local function handleGetUserRunsForRaceRequest(player: Player, data: any): tt.getUserRunsForRaceResponse
	_annotate("handleGetUserRunsForRaceRequest", data)
	local request: tt.postRequest = {
		remoteActionName = "getUserRunsForRace",
		data = {
			userId = player.UserId,
			startSignId = data.startSignId,
			endSignId = data.endSignId,
			limit = data.limit or 10,
		},
	}
	local res: tt.getUserRunsForRaceResponse = rdb.MakePostRequest(request)
	return res
end

local logSignData = require(game.ServerScriptService.logSignData)

local function handleLogSignDataRequest(player: Player, _data: any): boolean
	_annotate(string.format("handleLogSignDataRequest from player %s (%d)", player.Name, player.UserId))
	logSignData.LogAllSignData()
	return true
end

-- Nuke test user: deletes all data for TerrainParkour test account.
-- Triple-safety: Studio only, hardcoded userId only, backend also validates.
local function handleNukeTestUserRequest(player: Player, _data: any): { res: boolean, error: string, totalDeleted: number? }
	-- SAFETY CHECK 1: Studio only
	if not config.IsInStudio() then
		_annotate("nukeTestUser rejected: not in Studio")
		return { res = false, error = "SAFETY: nukeTestUser only works in Studio", totalDeleted = nil }
	end

	-- SAFETY CHECK 2: Hardcoded test user only
	if player.UserId ~= enums.objects.TerrainParkourUserId then
		_annotate(string.format("nukeTestUser rejected: userId %d != %d", player.UserId, enums.objects.TerrainParkourUserId))
		return { res = false, error = "SAFETY: nukeTestUser only works for TerrainParkour test user", totalDeleted = nil }
	end

	_annotate(string.format("NUKING TEST USER: %s (userId=%d)", player.Name, player.UserId))

	local request: tt.postRequest = {
		remoteActionName = "nukeTestUser",
		data = {
			userId = player.UserId,
			confirmation = "NUKE_TERRAINPARKOUR_CONFIRMED",
		},
	}

	local res = rdb.MakePostRequest(request)
	if res and res.res then
		_annotate(string.format("NUKE COMPLETE: deleted %d records", res.totalDeleted or 0))
		return { res = true, error = "", totalDeleted = res.totalDeleted }
	else
		local errMsg = res and res.error or "unknown error"
		_annotate(string.format("NUKE FAILED: %s", errMsg))
		return { res = false, error = errMsg, totalDeleted = nil }
	end
end

module.Init = function()
	_annotate("init")
	GenericClientUIFunction.OnServerInvoke = function(player: Player, event: tt.clientToServerRemoteEventOrFunction)
		if event.eventKind == "avatarMorph" then
			return handleAvatarMorph(player, event.data)
		elseif event.eventKind == "wrProgressionRequest" then
			return handleWRProgressionRequest(player, event.data)
		elseif event.eventKind == "wrProgressionChartRequest" then
			return handleWRProgressionChartRequest(player, event.data)
		elseif event.eventKind == "runEnding" then
			local converted: tt.runEndingDataFromClient = event.data :: tt.runEndingDataFromClient
			-- we call runEnding to end the run, then it calls the generic commadn to message the user with data including extra calculated stuff.
			return handleRunEndingRequest(player, converted)
		elseif event.eventKind == "runResultsRequest" then
			return handleRunResultsRequest(player, event.data)
		elseif event.eventKind == "pinRaceRequest" then
			return handlePinRaceRequest(player, event.data)
		elseif event.eventKind == "adjustFavoriteRaceRequest" then
			return handleAdjustFavoriteRaceRequest(player, event.data)
		elseif event.eventKind == "favoriteRacesRequest" then
			return handleFavoriteRacesRequest(player, event.data)
		elseif event.eventKind == "runStartNotification" then
			local converted: tt.runStartDataFromClient = event.data :: tt.runStartDataFromClient
			return handleRunStartNotification(player, converted)
		elseif event.eventKind == "getUserRunsForRaceRequest" then
			return handleGetUserRunsForRaceRequest(player, event.data)
		elseif event.eventKind == "logSignDataRequest" then
			return handleLogSignDataRequest(player, event.data)
		elseif event.eventKind == "nukeTestUserRequest" then
			return handleNukeTestUserRequest(player, event.data)
		end
	end

	serverRunTiming.Init()

	return false
end

_annotate("end")
return module
