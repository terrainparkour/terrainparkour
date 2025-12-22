--!strict

-- changelog.lua :: ReplicatedStorage.util.changelog
-- Central release history with structured release dates.
-- Version numbers map to 0.X.Y format (e.g., 400 = 0.4.0, 408 = 0.4.8).

local module = {}

-- Release entry type with explicit date field
export type ReleaseEntry = {
	date: string?, -- "YYYY-MM-DD" format, nil if unknown
	notes: string, -- Changelog text
	commit: string?, -- Git commit hash (internal reference, not user-facing)
}

-- Version numbering:
-- 185 = 0.1.85
-- 400 = 0.4.0
-- 408 = 0.4.8

local releases: { [number]: ReleaseEntry } = {
	[104] = {
		date = nil, -- Pre-git history
		notes = [[1.004
* Fix zooming in (recent bugs from zenkoina)
* Being trapped by sphere
* Unify sign popup endpoint data request
* Click sign UI refactor & improve
* Profile sign popup performance (mostly avatar image caching)
* Principle: whenever showing sign name, make it red marbled for signification
* Fix yellowness colors on race results and finds
* Fix LB bug for joiners
* 000 / win-by-001 badges
* 555 / 777 / 000 badges
* Badge awarding fast
* Internal script naming cleanup
* Take DB backup
* When deleting a BestRun, automatically recalculate BestRuns
* Back-fix all
* Restructure types/keys for relatedSigns in display and make that nice
* Refactor self-nature yellow in find and RR
* Incorrect green flashing in LB fix
* Rewrite sign popup to make it somewhat better
* Clean up old game
* RR hacking
* Redo timing measurement
* Bug around RR not resetting race sometimes
* Collisions investigation
* Standardize character (?)
* Redo badge awarding work
* Get Lua into repo / source control
* Make git pull
* Mobile high speed test
* Make systemctl restart
* Make alias to do everything
* Cache avatar images
* Make deployment passwords easier (notes)
* VSCode final setup
* Fix badges in general
* Clean up code structure and refs (static, etc.)
* Fix the Django UI thing
* Rojo re-setup
* Basic avatar standardization
* Protect hard-to-get-to signs in RR
* Make LB awesome
* Make sign popup awesome
]],
	},
	[105] = {
		date = nil,
		notes = [[1.005
* Timetile being cleared when blue
* Broken LBs
* Fix messaging other bugs (nil player)
* The "how far away a sign you don't have is" bug helps
* The nearest race you haven't run is bugged and shows only signs you haven't
* Marathon results popup
* Fixed time display of complete marathons clearing annoyingly when it turns blue
* Think I've fixed the LB bug
* Related sign display on sign popup more restrictive (esp. signs you haven't found yet)
* Fixed some internal stuff
* Finds: so you can use distance to find them
* Improve remaining legacy messages
* Player thumbs etc.
]],
	},
	[108] = {
		date = nil,
		notes = [[1.008
* Tablet sign
* Change verv username
* Fix bumped creator bug
* Fix ordering of submarathon item reporting
]],
	},
	[109] = {
		date = nil,
		notes = [[1.009
* Add green highlighting to yellow coloring for marathon display
* Filter UI for incoming non-RR messages
* Multi-marathon V1 (free/fixed)
]],
	},
	[110] = {
		date = nil,
		notes = [[1.010
* You could always disable GlobalShadows
]],
	},
	[113] = {
		date = nil,
		notes = [[1.013
* Marathons - find10, 100 reversealpha
* Poggod badge
* Print cleanup
* Hide popups on mobile
]],
	},
	[119] = {
		date = nil,
		notes = [[1.019
* Fix LB bug
* Fix marathon name bug
* Banned users of any type can't set complete races or find signs
]],
	},
	[120] = {
		date = "2022-02-27",
		notes = [[1.020
* Fix green bugs
* New signs
* Remove hardcoded sign locations
* Simplify new sign creation
* Bouncing between Studio & VSCode now awesome
* you/you bugs
* Refactor ephemeral messages
* Test mobile (seems same)
* Fixed width font for times
* Tech design of Marathons v2: server monitors active marathons
]],
	},
	[121] = {
		date = "2022-02-27",
		notes = [[1.021
* 10-T*
* Cleanups
]],
	},
	[125] = {
		date = "2022-02-27",
		notes = [[1.025
* Fun find-letters sign
* Bugs etc.
]],
	},
	[128] = {
		date = "2022-03-01",
		notes = [[1.028
* Admin ordering
* Day summary Django view
* Fix Django timezone
* Fix templating
]],
	},
	[131] = {
		date = "2022-03-04",
		notes = [[1.031
* Fix timing
* Stats_python
* Advertise 500
* New spawn point
]],
	},
	[132] = {
		date = "2022-03-05",
		notes = [[1.32
* New sign
* New spawn
* Fix badge
* Frog king / Sandking should give a royalty badge or something
]],
	},
	[133] = {
		date = "2022-03-05",
		notes = [[1.033
* RR timing bugs
]],
	},
	[134] = {
		date = "2022-03-05",
		notes = [[1.034
* Nil scoreboard problem
* Lots of refact
]],
	},
	[135] = {
		date = "2022-03-05",
		notes = [[1.035
* RaceResult warping
]],
	},
	[136] = {
		date = "2022-03-05",
		notes = [[1.036
* Badge command and LB display
]],
	},
	[137] = {
		date = "2022-03-06",
		notes = [[1.037
* New signs
* -finish
* Ice area
* Marathon digits lower
]],
	},
	[141] = {
		date = "2022-03-07",
		notes = [[1.041
* Find shows face
]],
	},
	[142] = {
		date = "2022-03-07",
		notes = [[1.042
* Cleanup
]],
	},
	[144] = {
		date = "2022-03-09",
		notes = [[1.044
* UI improvements
* Font standardization
* Ephemeral message formatting and face
* Standardize font for numbers / times (either fixed width or not)
]],
	},
	[145] = {
		date = "2022-03-10",
		notes = [[1.045
* Fix z-fighting on LB sign
* Ephemeral notification warping
]],
	},
	[150] = {
		date = "2022-03-12",
		notes = [[1.050
* Python 3.10
* New server
* DB copy
* Full backup of info
* New local venv and remove old
* Full typing (use this to fix return types)
]],
	},
	[151] = {
		date = "2022-03-12",
		notes = [[1.051
* Yolk sign
* Redo ordering of sign
]],
	},
	[154] = {
		date = "2022-03-14",
		notes = [[1.054
* Fix race place and priorbests
* Race speed testing zone
]],
	},
	[155] = {
		date = "2022-03-14",
		notes = [[1.055
* Badge displayer
* Badge progress display
]],
	},
	[156] = {
		date = "2022-03-15",
		notes = [[1.056
* Badges
]],
	},
	[157] = {
		date = "2022-03-15",
		notes = [[1.057+
* Settings UI
* How to play
* Badges settings UI
]],
	},
	[161] = {
		date = "2022-03-17",
		notes = [[1.061
* Signlength marathon
* Marathon refactor
]],
	},
	[164] = {
		date = "2022-03-19",
		notes = [[1.064
* Rewrite ordering code, fix up things
* Lettercount marathons
]],
	},
	[166] = {
		date = "2022-03-20",
		notes = [[1.066
* Persistent settings, userboolsettings
]],
	},
	[170] = {
		date = "2022-03-20",
		notes = [[1.07x
* Opt out of LB (broken)
* Surveys
* Improve stats UI
]],
	},
	[182] = {
		date = "2022-03-30",
		notes = [[1.082
* Discord
* Run guru
* Death pits
]],
	},
	[185] = {
		date = "2022-04-02",
		notes = [[1.085
* Fix challenge for long sign names
* Move marathon configuration to an easier new button, removed from settings
* Mouseovers for leaderboard headers
* Fixed marathon timing to be more exact
* Fixed settings "hide leaderboard" function
]],
	},
	[186] = {
		date = "2022-04-02",
		notes = [[1.086
* Make surveys have 3 possible answers: yes, unset, no.
* Make a new setting to shorten digit display in contest window
* Some improvements to make settings better in the future
]],
	},
	[187] = {
		date = "2022-04-03",
		notes = [[1.087
* Popular button
* Make dynamic running into a setting
* Setting for digit display of contest UI
* Fixed internal sign representation
* Fix live-application of settings and marathon configurations when you reset character
]],
	},
	[188] = {
		date = "2022-04-03",
		notes = [[1.088
* Random sayings
* New button
* Redo dynamic running to always position your run against the current result, not your prior result
]],
	},
	[189] = {
		date = "2022-04-03",
		notes = [[1.089
* Marathon ui bugfixes
* Keyboard shortcut '1' to warp to the last completed race.
* Worse lava behavior
]],
	},
	[191] = {
		date = "2022-04-06",
		notes = [[1.091
* Got year sign run
* Got hour sign
* Badge for "has found all signs"
* Server events interactive loop with payouts
]],
	},
	[192] = {
		date = "2022-04-14",
		notes = [[1.092 (thursday)
* Badge: Sign WRs 800
* Higher tix badges
* Tab to toggle LB / UIs on/off
* Keyboard to clear notifications
* Warping light effect
* Fix bugs when someone leaves the server who had dynamic running on
]],
	},
	[194] = {
		date = "2022-04-23",
		notes = [[1.094
* Axolotl
* Infotaxis
* Gyrovague
* New area
* Timer de-stepping
* Disable constant resetting of touchability status of avatar
* Improve dynamic running
]],
	},
	[195] = {
		date = "2022-10-09",
		notes = [[1.095
* Fix dynamic running more.
]],
	},
	[196] = {
		date = "2022-10-09",
		notes = [[1.096
* Other small fixes and server event badges.
* Webhooks for server event completion
]],
	},
	[197] = {
		date = "2022-10-15",
		notes = [[1.097
* Moving spawn
* Emoji sign by wraps near hurdle
* Double elite
* Scottish noah
* Badge for getting 100 badges
* Badge for 1.234
* Playtime badges
* New signs & areas & slogans
* Badge for being the first person to win a certain badge
* Improved UI for badge notifications
* "beckon" command
* Special signs with badges
* Improvement to discord webhooks
* <tab> now only toggles LB, not LB+Chat
* Server events can only be started from signs which someone in the server has found
* Shrunk LB somewhat to handle more people
* Fixed mouseovers and green highlighting
* Cleaned up old code - test warping
* Warning: disable dynamic running if you have performance problems with it
]],
	},
	[198] = {
		date = "2022-10-16",
		notes = [[1.098
* DB: utf8mb4 migration notes
* Bugfixes for resetting
* Fix dynamic running efficiency
* Fix beckon terminology
* Redo movement setup
]],
	},
	[201] = {
		date = "2022-04-30",
		notes = [[1.101
* Waymond and new area
* Fix runner count
]],
	},
	[202] = {
		date = "2022-10-22",
		notes = [[1.102
* Instant timing (no negative times)
* Minor warp pillar update
* Tab to go into "zen" mode
* F to fall down
* R to ragdoll
* Various bugfixes
]],
	},
	[203] = {
		date = "2022-10-22",
		notes = [[1.103
* Possibly fixed WRCount / findCount issues
* Sign lore badge
]],
	},
	[205] = {
		date = "2022-10-22",
		notes = [[1.105
* Survey server integration
]],
	},
	[206] = {
		date = "2022-10-22",
		notes = [[1.106
* Freedom
]],
	},
	[208] = {
		date = "2022-10-23",
		notes = [[1.108
* Badge fixes
]],
	},
	[209] = {
		date = "2022-10-23",
		notes = [[1.109
* Fix jumping
]],
	},
	[210] = {
		date = "2022-10-25",
		notes = [[1.110
* New signs
* New badges
* Lower respawn timing
* Fixed marathons
* Increase zoomlevel
* Move spawn
]],
	},
	[211] = {
		date = "2022-10-25",
		notes = [[1.111
* Add other server user info into sign history lookups
* Starting on user sign profiles. try "/sign tripool"
]],
	},
	[212] = {
		date = "2022-10-25",
		notes = [[1.112 (out)
* We cache badges now so counts should load much faster
* Some other fixes
* Some secret commands
]],
	},
	[213] = {
		date = "2022-10-25",
		notes = [[1.113 (out)
* Fix marathons including special sign names
* Updates to marathon presence
]],
	},
	[214] = {
		date = "2022-10-25",
		notes = [[1.114 (out)
* Fix sign name commands
* Show distance in race queries
* Larger thumbnails
]],
	},
	[216] = {
		date = "2022-10-28",
		notes = [[1.116
* First release in a while, new sign, catching up.
]],
	},
	[218] = {
		date = "2022-10-28",
		notes = [[1.116-1.118
* Movement changes
* Event admin stuff
]],
	},
	[219] = {
		date = "2022-10-28",
		notes = [[1.119
* Hipheight down a bit
* roblox-studio badge enabled
* Speed display in race run history
]],
	},
	[221] = {
		date = "2023-03-10",
		notes = [[1.121 (5/28)
* No FPS unlocker
* Avatar collision: inner box
* Remove fall & ragdoll
]],
	},
	[222] = {
		date = "2023-03-11",
		notes = [[1.122
* Lava & new signs
* Fix badgeaward getorcreate
]],
	},
	[223] = {
		date = "2023-03-11",
		notes = [[1.223
* Undo some of the emoji madness
* Fix teleportation bug
* Delete some bad times
* Make a new contest
* Fix don't step on grass
* Test other special signs
]],
	},
	[226] = {
		date = "2023-03-15",
		notes = [[1.226
* Change spawn
* Badge images in badge UI
* Superlow badge
* Superlow sign
* Fix lava behavior (maybe less ragdolling chance?)
* Sign aliases for non-english / easy sign names for lookups
* Remove lava
* Fix numbers in presence
* Fix tanstaafl
* Fix zenkoina3 times
]],
	},
	[227] = {
		date = "2023-03-15",
		notes = [[227
* Redid the way i manage movement, warping etc
* Fixed special signs including mOld
* Show command
* Warping now highlights the related sign a lot of the time (configurable, incl. disable)
* Rotates you and camera towards it
* Particles changed
* Excluded more signs from being involved in server events
]],
	},
	[231] = {
		date = "2023-03-22",
		notes = [[* First release in a very great while. 
* Rewrote warping, movement, refactor lots of things, lots of new funky signs. 
* Some UI and cmdline fixes. Basically, this is about rebooting game development]],
	},
	[235] = {
		date = "2024-07-27",
		notes = [[ Redid the way i manage movement, warping etc
* Fixed special signs including mOld
* Show command
* Warping now highlights the related sign a lot of the time.
* This should be configurable with a setting which is also easy to modify whether we highlight at all (and also kill active highlighting)
* And rotates you and camera towards it
* Particles changed
* Excluded more signs from being involved in server events

Internals
* Added script load timing
* Particles can do and see a lot more stuff now. Not optimized
* Converted most scripts to be characterScripts not playerScripts
* robloxServerError
* ...getFoundSignIds
* Delete a bunch of events in workspaceSetup
* avatarEventMonitor
* main.client.lua to clearly control order of client script loading 
* cool features I can do
]],
	},
	[236] = {
		date = "2024-07-28",
		notes = [[ * fix game even when the user dies or gets reset.
* Fix aligning player to point at warp target
* Optional highlight when doing /rr, joining a popular or new race, joining a server event, joining a race someone else ran, hitting 1 to rejoin your prior race, 
* User settings for highlighting in some situations, plus globally
* Sort user settings now
* Global 'show' command
* Keyboard command to kill highlight 'h'
 ]],
	},
	[237] = {
		date = "2024-07-31",
		notes = [[* draggable leaderboard (!) claude+1 hour
* keyboard shortcuts.
* new server slogans
]],
	},
	[240] = {
		date = "2024-07-28",
		notes = [[* Fixed serious bugs in sign profiles: incorrect total WR count (missing runs you hadn't run at all)
* Improved sign profile text and tooltip functionality
* Tooltips will become clickable to race with highlighting (for grinding WRs)
* Split keyboard shortcuts to separate file for easier management
* Added keyboard shortcuts to help UI
* Extensive Luau linting improvements
* Script load timing added
* Particles expanded capabilities
* Converted most scripts to characterScripts (not playerScripts)
* Improved Roblox server error handling
* Better avatar event monitoring
* Centralized client script loading order in main.client.lua
]],
	},
	[241] = {
		date = "2024-07-29",
		notes = [[* Sign profile results: CWRS row now first, other row shows non-CWRS only
* Sign profiles now show unique runner count (not total runs) in parenthesis after sign name
* Fixed unrun sign list ordering: now by number of runners (to find new CWRS), then alphabetical
* Server events properly update when joining game and when respawning
* Standardized filtering of signs for highlighting and server events
* Improved dynamic run highlighting text
* Ghost functionality fixed
* New signs and improved custom sign setup system
* Added option to disable avatar & camera rotation when warping with highlight target
* Z keyboard shortcut to cancel current race
]],
	},
	[248] = {
		date = "2024-08-04",
		notes = [[* Momentum reset: changed humanoid StateChange destination from GettingUp to Freefall to prevent jumping too quickly after warp
* Player anchor added during momentum reset
* Leaderboard is now draggable, resizable, and minimizable
* Improved warp logic
* Removed annotation DEBUG statements and optimizations
* New badges and badge images
* Test hiding for mobile users
]],
	},
	[251] = {
		date = "2024-08-06",
		notes = [[* The leaderboard, server events, and marathon windows are now separate, draggable, resizable, and minimizable
* Fixed thumbnail mouseover
* Tracking gamejoin version and is mobile start
]],
	},
	[252] = {
		date = "2024-08-06",
		notes = [[* fix sign profile mouseovers somewhat.]],
	},
	[256] = {
		date = "2024-08-08",
		notes = [[* Swim fly
* Swim fast
* Dynamic running breaking? (investigated)
]],
	},
	[257] = {
		date = "2024-08-09",
		notes = [[* Fixed swim bug with flying and stopping swimming slowdown incorrectly
* Particles: working on fixing them and giving them all meaning, will be able to be turned off
* Fixed small UI bugs with minimize buttons not working totally
]],
	},
	[258] = {
		date = "2024-08-10",
		notes = [[* fixed a few speedup bugs where you wouldn't accelerate sometimes.
* reduced particles and made them hopefully more useful. lots of other ideas here including a "random particle sign". But for now really turned them down a lot. I've been thinking that in a way, they are like gears in trackmania. Or could be... see unreleased code.
* I have some more ideas about this but all that should change here today is fixing things.
* Some other logical fixes in here too, nothing that should effect runs normally.
* moved running UI to center and gave it a light background. This UI will likely change and also be more configurable and moveable and controllable, etc in the future for you.
]],
	},
	[261] = {
		date = "2024-08-10",
		notes = [[* actually fix lacking speedups as you run? Also somewhat improve race running UI
* make speed display continuous rather than only showing up when you are on a run.
]],
	},
	[267] = {
		date = "2024-08-11",
		notes = [[* Fix shiftlock
* Ninja parkour integration
]],
	},
	[276] = {
		date = "2024-08-26",
		notes = [[* New signs
* Mobile shiftlock button
]],
	},
	[278] = {
		date = "2024-08-26",
		notes = [[* New leaderboard columns for days in game
* Internals: lots of fixes for admin UI
* Fixed user stats for CWRS, WRS, etc.
]],
	},
	[279] = {
		date = "2024-08-26",
		notes = [[* New area and new signs
* You can't warp to inside a sign now
* Splitting the 1 shortcut into two versions: warp+restart last completed run (optional highlighting), or warp to sign you last started from
* New keyboard shortcut UI (hit K)
* Improved particles showing exactly where you touch sign to start, retouch, and complete run
* Fix /cwrs (but not cwrTop10s yet in leaderboard)
]],
	},
	[282] = {
		date = "2024-09-06",
		notes = [[* Ghost functionality
]],
	},
	[292] = {
		date = "2024-09-06",
		notes = [[* Spawn change
* Lots of new signs
* Run UI (time & source) is moveable, resizable, position saved between runs
* Improved marathon naming & settings
* Leaderboard position is saved now, you can sort columns
* Distance is back on active run UI (will be configurable in future)
* Avatar effects like transparency and ghosting visible to other players
]],
	},
	[298] = {
		date = "2024-09-06",
		notes = [[* Major networking changes (fixes background issues, faster character reloading, less server load)
* Reworked momentum removal (likely too weak now, feedback welcomed)
* Affected warping: if you get stuck, please report
* If people find new exploits times will be removed, testing this change
* Dynamic running shows correct popups for signs now
* Fixed grind UI
* Fixed failed searches for new signs
* Sign search by prefix improved
]],
	},
	[299] = {
		date = "2024-09-06",
		notes = [[* Prevent someone from making too many requests
* Incorporated my collaborator's terrain and more fun terrain drawing
* Server particles
* Server error reporting integration
]],
	},
	[301] = {
		date = "2024-09-06",
		notes = [[* New sign types & 3 new signs
* New land area developed (still WIP)
* Fixed grind UI: can't use warp buttons to highlight unseen signs
* Find grind UI now shows how many people have run it (like unruns), not just your personal count
* Leaderboard tries harder to not get stuck off-screen on rejoin with different screen size
]],
	},
	[304] = {
		date = "2024-10-24",
		notes = [["Swift as wind, footsteps like verse",
"Mountains as paths, clouds as bounds",
"Each step anew, each leap unique",
"Endless terrain, boundless chance",
"Speed and passion, perfect blend",
"Challenge self, surpass the peak",
"Write with speed, compose with leaps",
"In chaos seek, the finest route",
"Parkour's way, supreme and high",
"Break limits, transcend mortal realm"

Scavenger hunt speedrunning!

3d terrain routing and speedrunning!

Race and explore a huge world!  Find the best routes and set world records!

"No more invisible walls!"
"Just One More Race"
"Everything matters"

Updates
* Weekly Contests
* More Signs
* Neko Sign!
* Beluga Sign!

Join the group for special chat color! https://www.roblox.com/My/Groups.aspx?gid=3200785

Update: MovementV2

Note: Source code for the Lua part of this game is available online here: github terrainparkour
]],
	},
	[305] = {
		date = "2024-10-24",
		notes = [[* Improve query startup time (PS + no threading was very slow to start up)
* Improve RR UI
* WR UI improvements: reduce overlapping of text, add your run if not present, add warp, add "look at reverse records", other convenience
* Working on Windows.lua anchoring to nearest corner and restore if off-screen
]],
	},
	[307] = {
		date = "2024-10-29",
		notes = [[* Top10 renamed to TopN
* Totally redo GUIs for Finds, WR progression, Run results (properly sized now)
* Test: all text descriptors, raceResults GUI and runResults GUIs
* Todo: Cave, Aphex warping
* Preparing server: get DB over, update config files and text nginx, fork test place with newest working code
* Update IP of the hidden thing
* Update prod secret key (IMPORTANT)
* Validate and give professor a copy
* You can control which window is on top
]],
	},
	[308] = {
		date = "2024-10-29",
		notes = [[* User Favorites feature added
* Fixed broken logic about showing your old best (can be restored)
]],
	},
	[309] = {
		date = nil,
		notes = [[* Favorites screen as general race list view
* Race data: total run counts, user run counts
* Expose players who improve too fast for review
* Connected component command
* Prod bug fixes
* Marathon fixes
* Limit run results to top ten option
* Transparency options: T and bit-T combine to 75%
* Fix min height of leaderboard
* Your relations appear more easily in run results
* When you beat past run, improvement is visible
* Friend relationships
]],
	},
	[310] = {
		date = "2024-10-31",
		notes = [[* Scrolling sticky frame
* Fix sizing
* Fix cwrs order in grind
* Fix highlight time
* Restore and fix dynamic running
* Genericize interleaving logic
]],
	},
	[311] = {
		date = nil,
		notes = [[* Restore ephemeral notifications
* Restore marathons
* Convert grind UI to new system
* Visual polish
* R to restart race
* Fix run results to have IDs for ghost lookup
* Particles on unseen and seen signs
* Restore cow sign
* Server-side monitoring of start/end timing
* Extra field on run for server-measured time (security tokens)
* JS viewer
* Grind UI layout fixes
* Fix runs display
* Show D (distance) in running UI
* Error reporting to DB
* Zenk's momentum fix
* Greenmushroom's sign
* New leaderboard columns and sorting
* String setting for internal data
* Leaderboard configurator
* Running UI visual improvements
]],
	},
	[400] = {
		date = "2025-11-08",
		notes = [[New dawn, new dev
* TP actually works again
* Disabled default chat system
* New sign added
* New developer onboarded
]],
	},
	[408] = {
		date = "2025-11-24",
		notes = [[Active Run UI improvements and leaderboard enhancements

ACTIVE RUN UI
* Real-time acceleration display with color gradients (cyan/blue positive, purple/magenta negative)
* 3D preview of target sign using ViewportFrame (replaces text name)
* Detailed breakdown of active speed multipliers (Walking, Lava, Jumps, Special Signs, etc.)
* Adjusted speed display label sizes and text alignment

SETTINGS
* Toggle acceleration display option (default: on)

COMMANDS
* /9run - find random uncompleted races with exactly 9 runners

LEADERBOARD
* Option for internal scrolling (Settings -> Leaderboard)
* Header color changed from green to blue
* Updated cell border styling and row positioning

WINDOWS
* Improved resizing behavior for all UI windows

UI & PERFORMANCE
* Improved padding system using UIPadding for consistent spacing
* Reduced log spam across client and server

BACKEND
* Web: "Races with 9 Runners" added to lookup page
* Web: Favicon added (different icon for dev vs production)
* Admin: Top-100 find/WR filters in user admin list
* Admin: Bulk tools for user management and stat recalculation

CONTROLS
* Tab key now restores sync between Chat/Leaderboard if desynchronized
]],
	},
	[409] = {
		date = "2025-12-06",
		notes = [[Major release with modular run UI, run removal requests, and agent infrastructure

MODULAR WIDGET SYSTEM
* New active run widget system with 23 widget modules and 12 categories
* Categories: Timer, Speed, SpeedChart, Altitude, Distance, Stats, Terrain, Compass, Maps, Acceleration, RunInfo, Container
* Each category has multiple variants (e.g., Timer: transparent-large, classic, none)
* Widgets are draggable with persistent positions across sessions
* Mix and match widgets to customize your run UI
* Access via menu button or /runUI command

TIME SERIES CHART LIBRARY
* New shared library for bar/point/line visualizations over time
* Features: non-linear Y-axis compression, color thresholds, event markers
* Multi-series support with independent scaling
* Sliding window and "all from start" display modes

RUN REMOVAL REQUEST SYSTEM
* /requestRemoval <race> - request removal of your fastest time on a race
* /removalStatus - view your pending, accepted, and rejected requests
* /cancelRemoval <id> - cancel a pending request
* Confirmation required via /yes within 60 seconds
* Costs 3 tix per request (prevents abuse)
* Submissions never used as evidence against you

CHANGELOG COMMAND
* /changelog - list available versions
* /changelog <version> - view specific version notes
* /changelog search <term> - search all changelogs
* Aliases: /changes, /releases

LEADERBOARD IMPROVEMENTS
* New setting: show distance from other players in server
* New setting: show warp-to column
* New setting: who can warp to you (none/friends/all)

ENVIRONMENT DETECTION
* New environment.lua module for clean production/studio/test detection
* Uses PlaceId (public) instead of gitignored files
* Replaces doNotCheckInGameIdentifier pattern

BACKEND IMPROVEMENTS
* Server now records run duration for timing verification
* Larger setting storage for widget configurations
* Better error messages when signs not found
* Structured result types (success + raceNotFound flags)

CODE QUALITY
* Chat system file naming consistency
* Type improvements throughout gametypes.lua
* Standardized run results response structure
* New standard button component for consistent UI
]],
	},
	[410] = {
		date = "2025-12-07",
		notes = [[WR Progression Chart, Your Runs popup, and modal improvements

WR PROGRESSION CHART
* New visual chart showing world record progression over time
* X-axis: from first race run to today's date
* Y-axis: race times with non-linear compression (0-60s compressed, 60-95s expanded)
* Circular avatar portraits at each WR point
* Color coding: yellow for your WRs, green for race discovery
* Hover tooltips: username, exact time, improvement, attempts data
* "WR Chart" button in WR Progression modal and Run Results

YOUR RUNS POPUP
* Hover popup on "Your Runs" tile in Run Results and WR Progression
* Shows all your runs on that race with times and ages
* Fetches data lazily on hover, cached for performance

MODAL IMPROVEMENTS
* Content-adaptive modal sizing: height based on actual content
* Run Results modal now resizable with position/size persistence
* WR Progression modal now resizable with position/size persistence
* Resize handle moved to bottom-right corner (conventional location)

RUN CHART ENHANCEMENTS
* Mode toggle: switch between "10s" (sliding window) and "full" (all data)
* Minimize button on title bar with size save/restore
* "No filters active" overlay when all data series disabled
* "Start a run" empty state message before first run
* Air terrain transitions no longer logged as separate markers
* Filter state and chart mode persisted across sessions

WR PROGRESSION MODAL
* New "Attempts" column showing total/winner's attempts per WR window
* First Runner row shows who discovered the race
* Portrait column moved before username
* Rows show who previous WR holder was

UI IMPROVEMENTS
* "(just now)" suffix on your just-completed runs in Run Results
* "Ways to Play" and "Keyboard Shortcuts" modals rewritten using standard windows system

BACKEND
* WR Progression API returns attemptsBetween and attemptsByWinner fields
* New events: wrProgressionChartRequest, getUserRunsForRaceRequest
* Migrations 0076-0077: race_competitive field on BestRun
* Admin: myleaderboardcolumns and mywidgets summary fields

TECHNICAL
* LocalScripts renamed to ModuleScripts for explicit load ordering
* main.client.lua orchestrates all module Init() calls
* New files: wrProgressionChart.lua, yourRunsPopup.lua, versionHistory.lua, highlightUtils.lua
* New minimize config option for time series chart library
* Standard button autoSize option for text-fitting buttons
* Resize handle moved to bottom-right, better position persistence
]],
	},
	[411] = {
		date = "2025-12-16",
		notes = [[Search, sorting, and UI polish

SEARCH & FILTER
* Marathon window now has a search bar to filter marathons by name
* Favorites window now has a search bar to filter your favorite races
* Type to filter, X button to clear

SORTING
* Favorites window shows your placement summary across all favorites (how many 1sts, 2nds, etc.)
* Run results can now highlight slower digits vs the row above (opt-in setting)

WR PROGRESSION CHART
* "Profiles: On/Off" toggle button to hide/show runner portraits
* Improved layout and connector routing

NEW COMMANDS
* /bugreport <text> - submit bug reports directly from the game
* /idea <text> - submit feature ideas and suggestions

NEW BADGES
* New badges added
]],
	},
	[412] = {
		date = "2025-12-17",
		notes = [[Badge comparison command and UI improvements

NEW COMMANDS
* /badgecompare <player> - compare your badges with another player
* /badgecompare <playerA> <playerB> - compare two other players' badges

BADGE POPUP
* Badge popup now shows actual badge icons in a new column

NEW SETTINGS
* Hide races from Discord - option to hide your race results from Discord integration

UI FIXES
* Fixed position and font issues in Find UI
* Fixed position and font issues in Run Results UI
]],
	},
}

-- Export the releases table
module.releases = releases

-- Backward compatibility: export releaseNotes as a flat string map
-- This is derived from releases for code that still uses the old format
local releaseNotes: { [number]: string } = {}
for versionNum, entry in pairs(releases) do
	releaseNotes[versionNum] = entry.notes
end
module.releaseNotes = releaseNotes

-- Helper to get release date for a version
function module.getReleaseDate(versionNum: number): string?
	local entry = releases[versionNum]
	if entry then
		return entry.date
	end
	return nil
end

-- Get all versions with known dates, sorted by date
function module.getVersionsWithDates(): { { version: number, date: string } }
	local result: { { version: number, date: string } } = {}
	for versionNum, entry in pairs(releases) do
		if entry.date then
			table.insert(result, { version = versionNum, date = entry.date })
		end
	end
	table.sort(result, function(a, b)
		return a.date < b.date
	end)
	return result
end

return module
