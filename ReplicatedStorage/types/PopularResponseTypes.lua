--!strict

--TODO new broken 9.22
--also used for newRaceResult

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

export type popularRaceResult = {
	startSignName: string,
	startSignId: number,
	endSignName: string,
	endSignId: number,
	distance: number,
	ct: number,
	userPlaces: { { username: string, userId: number, place: number } },
	hasFoundStart: boolean,
	wasLastRace: boolean?,
	kind: string,
}

_annotate("end")
return {}
