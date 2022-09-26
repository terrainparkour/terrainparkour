--!strict

--eval 9.21

--TODO new broken 9.22

--also used for newRaceResult
export type popularRaceResult = {
	startSignName: string,
	startSignId: number,
	endSignName: string,
	distance: number,
	ct: number,
	userPlaces: { { username: string, userId: number, place: number } },
	hasFoundStart: boolean,
	wasLastRace: boolean?,
	kind: string,
}

return {}
