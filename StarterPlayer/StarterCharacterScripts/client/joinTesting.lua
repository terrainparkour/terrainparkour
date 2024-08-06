--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local config = require(game.ReplicatedStorage.config)
local tt = require(game.ReplicatedStorage.types.gametypes)
local leaderboard = require(game.StarterPlayer.StarterCharacterScripts.client.leaderboard)

test = function()
	task.spawn(function()
		local fakeDataUpdateData: tt.afterData_getStatsByUser = {
			kind = "joiner update other lb",
			userId = 90115385,
			runs = 123,
			userTotalFindCount = 123,
			findRank = 123,
			top10s = 123,
			races = 123,
			userTix = 123,
			userCompetitiveWRCount = 123,
			userTotalWRCount = 123,
			wrRank = 123,
			totalSignCount = 123,
			awardCount = 123,
		}
		leaderboard.ClientReceiveNewLeaderboardData(fakeDataUpdateData)
		print("did join.")
		wait(2)
		leaderboard.ClientReceiveNewLeaderboardData({ userId = 90115385, kind = "leave" })
		print("did leave.")
		wait(2)
		leaderboard.ClientReceiveNewLeaderboardData(fakeDataUpdateData)
		print("did join again.")
	end)
end

if config.isTestGame() then
	--test()
end

_annotate("end")

return module
