--!strict

local tt = require(game.ReplicatedStorage.types.gametypes)

local module = {}

local messageTypes = {}
messageTypes.CREATE = "create"
messageTypes.UPDATE = "update"
messageTypes.END = "end"
module.messageTypes = messageTypes

module.getSortedUserBests = function(ev: tt.runningServerEvent): { tt.runningServerEventUserBest }
	--constructing row2, player results.
	local holder = {}
	for _, ev in pairs(ev.userBests) do
		table.insert(holder, ev)
	end

	table.sort(holder, function(a: tt.runningServerEventUserBest, b: tt.runningServerEventUserBest)
		return a.timeMs < b.timeMs
	end)
	return holder
end

--allocation breakdowns by number of people participating.
module.getTixAllocation = function(ev: tt.runningServerEvent): { tt.serverEventTixAllocation }
	local res: { tt.serverEventTixAllocation } = {}
	local runnerCount = 0
	for _, el in pairs(ev.userBests) do
		runnerCount += 1
	end

	local bests = module.getSortedUserBests(ev)
	if runnerCount == 1 then
		table.insert(
			res,
			{
				eventPlace = 1,
				userId = bests[1].userId,
				username = bests[1].username,
				tixallocation = math.ceil(ev.tixValue * 1.0),
			}
		)
	end
	if runnerCount == 2 then
		table.insert(
			res,
			{
				eventPlace = 1,
				userId = bests[1].userId,
				username = bests[1].username,
				tixallocation = math.ceil(ev.tixValue * 0.75),
			}
		)
		table.insert(
			res,
			{
				eventPlace = 2,
				userId = bests[2].userId,
				username = bests[2].username,
				tixallocation = math.ceil(ev.tixValue * 0.25),
			}
		)
	end
	if runnerCount == 3 then
		table.insert(
			res,
			{
				eventPlace = 1,
				userId = bests[1].userId,
				username = bests[1].username,
				tixallocation = math.ceil(ev.tixValue * 0.6),
			}
		)
		table.insert(
			res,
			{
				eventPlace = 2,
				userId = bests[2].userId,
				username = bests[2].username,
				tixallocation = math.ceil(ev.tixValue * 0.3),
			}
		)
		table.insert(
			res,
			{
				eventPlace = 3,
				userId = bests[3].userId,
				username = bests[3].username,
				tixallocation = math.ceil(ev.tixValue * 0.1),
			}
		)
	end
	if runnerCount == 4 then
		table.insert(
			res,
			{
				eventPlace = 1,
				userId = bests[1].userId,
				username = bests[1].username,
				tixallocation = math.ceil(ev.tixValue * 0.55),
			}
		)
		table.insert(
			res,
			{
				eventPlace = 2,
				userId = bests[2].userId,
				username = bests[2].username,
				tixallocation = math.ceil(ev.tixValue * 0.25),
			}
		)
		table.insert(
			res,
			{
				eventPlace = 3,
				userId = bests[3].userId,
				username = bests[3].username,
				tixallocation = math.ceil(ev.tixValue * 0.13),
			}
		)
		table.insert(
			res,
			{
				eventPlace = 4,
				userId = bests[4].userId,
				username = bests[4].username,
				tixallocation = math.ceil(ev.tixValue * 0.07),
			}
		)
	end
	if runnerCount == 5 then
		table.insert(
			res,
			{
				eventPlace = 1,
				userId = bests[1].userId,
				username = bests[1].username,
				tixallocation = math.ceil(ev.tixValue * 0.55),
			}
		)
		table.insert(
			res,
			{
				eventPlace = 2,
				userId = bests[2].userId,
				username = bests[2].username,
				tixallocation = math.ceil(ev.tixValue * 0.25),
			}
		)
		table.insert(
			res,
			{
				eventPlace = 3,
				userId = bests[3].userId,
				username = bests[3].username,
				tixallocation = math.ceil(ev.tixValue * 0.13),
			}
		)
		table.insert(
			res,
			{
				eventPlace = 4,
				userId = bests[4].userId,
				username = bests[4].username,
				tixallocation = math.ceil(ev.tixValue * 0.07),
			}
		)
	end
	if runnerCount == 6 then
		table.insert(
			res,
			{
				eventPlace = 1,
				userId = bests[1].userId,
				username = bests[1].username,
				tixallocation = math.ceil(ev.tixValue * 0.50),
			}
		)
		table.insert(
			res,
			{
				eventPlace = 2,
				userId = bests[2].userId,
				username = bests[2].username,
				tixallocation = math.ceil(ev.tixValue * 0.25),
			}
		)
		table.insert(
			res,
			{
				eventPlace = 3,
				userId = bests[3].userId,
				username = bests[3].username,
				tixallocation = math.ceil(ev.tixValue * 0.13),
			}
		)
		table.insert(
			res,
			{
				eventPlace = 4,
				userId = bests[4].userId,
				username = bests[4].username,
				tixallocation = math.ceil(ev.tixValue * 0.08),
			}
		)
		table.insert(
			res,
			{
				eventPlace = 5,
				userId = bests[5].userId,
				username = bests[5].username,
				tixallocation = math.ceil(ev.tixValue * 0.04),
			}
		)
	end

	return res
end

return module
