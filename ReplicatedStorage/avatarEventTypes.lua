--!strict

--special luau types for movement.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

export type avatarEventDetails = {
	relatedSignId: number?,
	relatedSignName: string?,
	floorMaterial: Enum.Material?, --this is either a terrain or a non-terrain, you need to check.
	newMoveDirection: Vector3?,
	oldMoveDirection: Vector3?,
	newState: Enum.HumanoidStateType?,
	oldState: Enum.HumanoidStateType?,
	warpSourceSignName: string?,
	warpDestinationSignName: string?,
	oldSpeed: number?,
	newSpeed: number?,
	oldJumpPower: number?,
	newJumpPower: number?,
	reason: string?,
}

export type avatarEvent = {
	eventType: number,
	timestamp: number,
	details: avatarEventDetails?,
}

--the types of all the events broadcast by avatarEventMonitor.
local avatarEventTypes: { [string]: number } = {
	CHARACTER_ADDED = 1, --when the character is added.
	RUN_START = 2,
	RUN_COMPLETE = 3,
	RUN_KILL = 31,
	RETOUCH_SIGN = 4,
	TOUCH_SIGN = 5, --distinct from retouch, end, run_start.

	-- CHANGE_DIRECTION = 6, --this is the roblox property, which contains both the movement vector3 (direction), which also will turn to 0,0,0 if the player totally stops.
	FLOOR_CHANGED = 7,
	STATE_CHANGED = 8, --this is where we load all swimming, jumping
	AVATAR_STOPPED = 108, --since change direction is sent way too often when currently all we actually care about is if they have stopped
	AVATAR_STARTED_MOVING = 109,

	AVATAR_RESET = 9, -- resetting avatar.

	KEYBOARD_WALK = 10, --inputs from keyboard.
	KEYBOARD_RUN = 11,

	RESET_MORPHS = 12,

	DO_SPEED_CHANGE = 13, --when I do my own, movementV2 related speedups.
	DO_JUMPPOWER_CHANGE = 14,

	DIED = 28,
	CHARACTER_REMOVING = 30,
	GET_READY_FOR_WARP = 34, -------warper sends this out to shut down other options for users.
	MORPHING_WARPER_READY = 35,
	MOVEMENT_WARPER_READY = 36,
	RACING_WARPER_READY = 37,
	MARATHON_WARPER_READY = 38,

	WARP_DONE_RESTART_MORPHS = 46,
	WARP_DONE_RESTART_MOVEMENT = 47,
	WARP_DONE_RESTART_RACING = 48,
	WARP_DONE_RESTART_MARATHONS = 49,

	MORPHING_RESTARTED = 50,
	MOVEMENT_RESTARTED = 51,
	RACING_RESTARTED = 52,
	MARATHON_RESTARTED = 53,
}

local avatarEventTypesReverse = {}
for k, v in pairs(avatarEventTypes) do
	avatarEventTypesReverse[v] = k
end

module.avatarEventTypes = avatarEventTypes
module.avatarEventTypesReverse = avatarEventTypesReverse

_annotate("end")
return module
