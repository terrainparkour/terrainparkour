--!strict

-- receiveClientEventServer.lua listens for client events and just trusts them.
-- avatar morphs, etc.

local runEnding = require(script.Parent.runEnding)
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local tt = require(game.ReplicatedStorage.types.gametypes)
local remotes = require(game.ReplicatedStorage.util.remotes)
local runResultsCommand = require(game.ReplicatedStorage.commands.runResultsCommand)
local wrProgressionCommand = require(game.ReplicatedStorage.commands.wrProgressionCommand)
local pinRaceCommand = require(game.ReplicatedStorage.commands.pinRaceCommand)
local userFavoriteRacesCommand = require(game.ReplicatedStorage.commands.userFavoriteRacesCommand)
local rdb = require(game.ServerScriptService.rdb)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)

-- local GenericClientUIEvent = remotes.getRemoteEvent("GenericClientUIEvent")
local GenericClientUIFunction = remotes.getRemoteFunction("GenericClientUIFunction")

--in new trust the client code, just call this directly with the actual details.
--note: it would be nice to retain server-side timing to detectre hackers. nearly every one would give themselves away.

local function handleAvatarMorph(player: Player, data: tt.avatarMorphData)
	_annotate("handleAvatarMorph", data)

	local didAnything = false

	if data.transparency then
		_annotate("got request to set character transparency to: " .. tostring(data.transparency))
		local targetCharacter = player.Character
		local targetTransparency = data.transparency
		for i, v: Decal | MeshPart in pairs(targetCharacter:GetDescendants()) do
			-- print(v.Name, v.ClassName)
			if v:IsA("Decal") or v:IsA("MeshPart") then --v:IsA("BasePart")
				if v.Transparency ~= targetTransparency then
					v.Transparency = targetTransparency
					didAnything = true
				end
			end
		end
	end
	if data.scale then
		local targetCharacter = player.Character
		local currentScale = targetCharacter:GetScale()
		if currentScale ~= data.scale then
			_annotate(
				string.format("Rescaling character from currentScale=%f to desiredScale=%f", currentScale, data.scale)
			)
			targetCharacter:ScaleTo(data.scale)
			didAnything = true
		end
	end
	return didAnything
end

local function handleWRProgressionRequest(player: Player, data: { startSignId: number, endSignId: number })
	_annotate("handleWRProgressionRequest", data)

	local startSignId, endSignId = data.startSignId, data.endSignId

	local res = wrProgressionCommand.GetWRProgression(player, startSignId, endSignId)
	return res
end

local function handleRunEndingRequest(player: Player, data: tt.runEndingDataFromClient)
	_annotate("handleRunResultsRequest", data)

	return runEnding.DoRunEnd(player, data)
end

local function handleRunResultsRequest(player: Player, data: any)
	_annotate("handleRunResultsDelivery", data)

	return runResultsCommand.SendRunResults(player, data.startSignId, data.endSignId)
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
	local res =
		userFavoriteRacesCommand.GetFavoriteRaces(player, data.targetUserId, data.requestingUserId, data.otherUserIds)
	-- if not res.success then
	-- 	error("GetFavoriteRaces failed")
	-- end
	return res
end

module.Init = function()
	_annotate("init")
	GenericClientUIFunction.OnServerInvoke = function(player: Player, event: tt.clientToServerRemoteEventOrFunction)
		if event.eventKind == "avatarMorph" then
			return handleAvatarMorph(player, event.data)
		elseif event.eventKind == "wrProgressionRequest" then
			return handleWRProgressionRequest(player, event.data)
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
		end
	end

	return false
end

_annotate("end")
return module
