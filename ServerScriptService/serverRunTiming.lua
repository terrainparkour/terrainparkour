--!strict
-- serverRunTiming.lua (ServerScriptService/serverRunTiming.lua)
-- Tracks server-side run start times for security analysis.
-- When a client claims to start a run, we record the server tick.
-- When they finish, we compare server-observed duration vs client-claimed time.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

-- Module internals
-- userId => { startSignId, startSignName, serverStartTick, clientTick }
type ActiveRunEntry = {
	startSignId: number,
	startSignName: string,
	serverStartTick: number,
	clientTick: number, -- client's tick at touch, for rejecting out-of-order arrivals
}
local activeRuns: { [number]: ActiveRunEntry } = {}

-- Called when we receive a run start notification from the client
module.RecordRunStart = function(userId: number, startSignId: number, startSignName: string, clientTick: number)
	local existingEntry = activeRuns[userId]

	-- Reject out-of-order arrivals: if we already have a newer touch, ignore this stale one
	if existingEntry and clientTick < existingEntry.clientTick then
		_annotate(
			string.format(
				"RecordRunStart: IGNORING stale notification userId=%d signName=%s clientTick=%.3f < existing=%.3f",
				userId,
				startSignName,
				clientTick,
				existingEntry.clientTick
			)
		)
		return
	end

	local serverTick = tick()
	activeRuns[userId] = {
		startSignId = startSignId,
		startSignName = startSignName,
		serverStartTick = serverTick,
		clientTick = clientTick,
	}
	_annotate(
		string.format(
			"RecordRunStart: userId=%d signId=%d signName=%s serverTick=%.3f clientTick=%.3f",
			userId,
			startSignId,
			startSignName,
			serverTick,
			clientTick
		)
	)
end

-- Called when a run ends to get the server-side duration
-- Returns the server-observed duration in milliseconds, or nil if no start was recorded
module.GetServerDurationAndClear = function(userId: number, endSignName: string): number?
	local entry = activeRuns[userId]
	if not entry then
		_annotate(string.format("GetServerDurationAndClear: no active run for userId=%d (end=%s)", userId, endSignName))
		return nil
	end

	local serverEndTick = tick()
	local serverDurationMs = math.floor((serverEndTick - entry.serverStartTick) * 1000)

	_annotate(
		string.format(
			"GetServerDurationAndClear: userId=%d start=%s end=%s serverDurationMs=%d",
			userId,
			entry.startSignName,
			endSignName,
			serverDurationMs
		)
	)

	-- Clear the entry
	activeRuns[userId] = nil

	return serverDurationMs
end

-- Called when a player leaves to clean up their entry
module.ClearPlayer = function(userId: number)
	if activeRuns[userId] then
		_annotate(string.format("ClearPlayer: removing active run for userId=%d", userId))
		activeRuns[userId] = nil
	end
end

-- For debugging: check if a player has an active run tracked
module.HasActiveRun = function(userId: number): boolean
	return activeRuns[userId] ~= nil
end

module.Init = function()
	_annotate("init")

	-- Clean up when players leave
	local PlayersService = game:GetService("Players")
	PlayersService.PlayerRemoving:Connect(function(player: Player)
		module.ClearPlayer(player.UserId)
	end)

	_annotate("init done")
end

_annotate("end")
return module
