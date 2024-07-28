--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

export type button = { name: string, contentsGetter: (localPlayer: Player) -> ScreenGui }
export type actionButton = {
	name: string,
	contentsGetter: (localPlayer: Player, userIds: { number }) -> ScreenGui,
	shortName: string,
	hoverHint: string,
	getActive: () -> boolean,
	widthPixels: number,
}

_annotate("end")
return module
