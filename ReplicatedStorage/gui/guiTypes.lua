--!strict

--eval 9.21

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

return module
