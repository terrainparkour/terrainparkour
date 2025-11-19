--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

export type lbColumnDescriptor = {
	name: string,
	num: number,
	widthScaleImportance: number,
	userFacingName: string,
	tooltip: string,
	doWrapping: boolean,
}

_annotate("end")
return module
