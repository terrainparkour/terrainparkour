--!strict

-- guiTypes. So far, only an action button which is a button which
-- lots of UIs can be set up to have. It has the basic functions defined like how to draw the button,
-- what to do when the user clicks, hints, hovers, size etc.
-- 2024: this is not ideal but did work before. At some point it stopped being optimized
-- so lots of actionButton users have really bad repeated code.  Also when I wrote it I didn't fully get
-- the difference between Script, LocalScript, etc. and basically, that anything which is running on client can always
-- just easily get the localPlayer from the environment.

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
	widthXScale: number,
}

_annotate("end")
return module
