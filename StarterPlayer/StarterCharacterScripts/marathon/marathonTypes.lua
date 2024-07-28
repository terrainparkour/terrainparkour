--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local tt = require(game.ReplicatedStorage.types.gametypes)

--the metadata to store for each running marathonKind
export type findInMarathonRun = { signName: string, findTicks: number, findOrder: number }

--return value for the method which handles "user hit sign S in relation to marathon M, did you do anything? and if so did the run just start"
export type userFoundSignResult = {
	added: boolean,
	marathonDone: boolean,
	started: boolean,
}

export type marathonDescriptor = {
	kind: string,
	highLevelType: string,
	humanName: string,
	addDebounce: { [string]: boolean },
	reportAsMarathon: boolean,
	finds: { findInMarathonRun },
	targets: { string },
	orderedTargets: { string },
	count: number,
	requiredCount: number,
	startTime: number?,
	killTimerSemaphore: boolean,
	runningTimeTileUpdater: boolean,
	timeTile: TextLabel?,
	IsDone: (desc: marathonDescriptor) -> boolean,
	AddSignToFinds: (desc: marathonDescriptor, signName: string) -> boolean,
	UpdateRow: (desc: marathonDescriptor, exi: Frame, foundSignName: string) -> nil,
	EvaluateFind: (desc: marathonDescriptor, signName: string) -> userFoundSignResult,
	SummarizeResults: (desc: marathonDescriptor) -> { string },
	awardBadge: tt.badgeDescriptor?,
	hint: string?,
	chipPadding: number?,
	sequenceNumber: string, --for types whihc have multiple variants (find<N>, etc.) what seq number should it be?. for some use str(name) for others str(seq)
}

_annotate("end")
return {}
