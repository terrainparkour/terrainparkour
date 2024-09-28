--!strict

local module = {}

module.gameVersion = "0.298"

--do not change these! only deletions without fillin are allowed.
local name2signId: { [string]: number } = {
	["Lavaslug"] = 589,
	["Alone"] = 588,
	["Auryn"] = 587,
	-- ["Hypernormalization"] = 586, --
	["Nimbus"] = 585,

	-- ["Hyperparasite"] = 584, --
	["Hypernudge"] = 583, --
	["Tesla"] = 582,
	["Ys"] = 581,
	["Hyperborea"] = 580,
	["Algorithm"] = 579,
	["Hiraeth"] = 578,
	["Brussel Sprouts"] = 577,
	["Nauvis"] = 576,
	["Tsundoku"] = 575,
	["Vellichor"] = 574,
	["Eigengrau"] = 573,
	["Hygge"] = 572,
	["Crystal Mentality"] = 571,
	["Zenzizenzizenzic"] = 570,
	["Zoom"] = 569,
	["FPS"] = 568,
	["Cryotheque"] = 567,
	["Gradus"] = 566,
	["Chert"] = 565,
	["Papua"] = 564,
	["Nighthawks"] = 563,
	["Whippoorwill"] = 562,
	["Tri Arch"] = 1,
	["Gold Pond"] = 2,
	["3d cube"] = 3, --todo do NOT change to "3d Cube"
	["Ziggurat"] = 4,
	["Monument"] = 5,
	["Castle"] = 6,
	["Chasm"] = 7,
	["Lava Tube"] = 8,
	["Lilypad"] = 9,
	["Spiral"] = 10,
	["Plains"] = 11,
	["Salt Zone"] = 12,
	["The Cube"] = 13,
	["Inca"] = 14,
	["Pools"] = 15,
	["Jitty"] = 16,
	["LA River"] = 17,
	["Grass Tree"] = 18,
	["Small Cube"] = 19,
	["Wickets"] = 20,
	["Spaghett"] = 21,
	["World of Molecules"] = 22,
	["Globular Cluster"] = 23,
	["Sands of Mars"] = 24,
	["Monolith"] = 25,
	["Seaweed"] = 26,
	["Pretzel"] = 27,
	["Overpass"] = 28,
	["Mud Theater"] = 29,
	["Salt Maze"] = 30,
	["Start"] = 31,
	["Orthanc"] = 32,
	["Crater"] = 33,
	["Tenochtitlan"] = 34,
	["Steps of Infinity"] = 35,
	["Beehive"] = 36,
	["Pharoah"] = 37,
	["Helix"] = 38,
	["Mondrian"] = 39,
	["Maze"] = 40,
	["Marsscape"] = 41,
	["Goldbridge"] = 42,
	["Barrows"] = 43,
	["Troll Bridge"] = 44,
	["Cliffs of Insanity"] = 45,
	["Subterranean Temple"] = 46,
	["Fringe"] = 47,
	["Close"] = 48,
	["Mazatlan"] = 49,
	["Tripool"] = 50,
	["Overlook"] = 51,
	["Cave of Forgotten Dreams"] = 52,
	["Balance"] = 53,
	["Spiral Jump"] = 54,
	["The Zone"] = 55,
	["Death Valley"] = 56,
	["Tangle"] = 57,
	["Castle Top"] = 58,
	["Rapunzel"] = 59,
	["Cave"] = 60,
	["Mold"] = 61,
	["Hyperion"] = 62,
	["Angle of Repose"] = 63,
	["Shadows"] = 64,
	["Journey to the Center of the Earth"] = 65,
	["Jasper"] = 66,
	["Why"] = 67,
	["Elevator"] = 68,
	["Rubble"] = 69,
	["Race End"] = 70,
	["Race Start"] = 71,
	["Cromulent"] = 72,
	["Inverse"] = 73,
	["CubeCube"] = 74,
	["Cloud Chamber"] = 75,
	["A"] = 76,
	["B"] = 77,
	["C"] = 78,
	["D"] = 79,
	["Olympus"] = 80,
	["Kaminarimon"] = 81,
	["Vesuvius"] = 82,
	["Summit"] = 83,
	["Trailhead"] = 84,
	["Khufu"] = 85,
	["Ribs"] = 86,
	["Blanc"] = 87,
	["Scuba"] = 88,
	["Bergfried"] = 89,
	["Husqvarna"] = 90,
	["Pentekontors"] = 91,
	["Maobahe"] = 92,
	["Sputnik"] = 93,
	["Canals"] = 94,
	["Excalibur"] = 95,
	["Mechanus"] = 96,
	["Weathertop"] = 97,
	["Waffle"] = 98,
	["Dawn"] = 99,
	["Dusk"] = 100,
	["Noon"] = 101,
	["Sphere"] = 102,
	["Pyla"] = 103,
	["Gnomon"] = 104,
	["Sundial"] = 105,
	["Climbing Wall"] = 106,
	["Armintxe"] = 107,
	["Dryntimy"] = 108,
	["Horseshoe"] = 109,
	["Bombadil"] = 110,
	["Mauna Loa"] = 111,
	["Skafloc"] = 112,
	["Mare"] = 113,
	["Wolfram"] = 114,
	["Hamilton"] = 115,
	["Tipperary"] = 116,
	["Weir"] = 117,
	["Obby"] = 118,
	["Flint"] = 119,
	["Pachacuti"] = 120,
	["Fisher"] = 121,
	["Decker"] = 122,
	["Polysaccharide"] = 123,
	["Oxalis"] = 124,
	["Valgrind"] = 125,
	["Frigate"] = 126,
	["Cornu"] = 127,
	["Avestan"] = 128,
	["Chaoskampf"] = 129,
	["Nyx"] = 130,
	["Heinlein"] = 131,
	["Dipole"] = 132,
	["Nabkha"] = 133,
	["Kaarlo"] = 134,
	["Lignin"] = 135,
	["Geosmin"] = 136,
	["Hasmonean"] = 137,
	["Aguirre"] = 138,
	["Saltus"] = 139,
	["GmbH"] = 140,
	["Prince Dakkar"] = 141,
	["Crenellation"] = 142,
	["Ra"] = 143,
	["Enguerrand"] = 144,
	["Atocha"] = 145,
	["Terminal"] = 146,
	["Mencius"] = 147,
	["Ooloi"] = 148,
	["Claudius"] = 149,
	["Tybalt"] = 150,
	["Sutter"] = 151,
	["World Turtle"] = 152,
	["Viridian"] = 153,
	["Kochi"] = 154,
	["Lutum"] = 155,
	["Trags"] = 156,
	["Hosho"] = 157,
	["Paul"] = 158,
	["Batatas"] = 159,
	["Xylem"] = 160,
	["Schiaparelli"] = 161,
	["Conch"] = 162,
	["Phloem"] = 163,
	["Bretzel"] = 164,
	["Jordan"] = 165,
	["Anki"] = 166,
	["Wozniak"] = 167,
	["Bogleheads"] = 168,
	["Klytus"] = 169,
	["Wilson"] = 170,
	["Crobuzon"] = 171,
	["Cinchona"] = 172,
	["Tapochki"] = 173,
	["Amber"] = 174,
	["Aran"] = 175,
	["Pozzolana"] = 176,
	["Sciocchi"] = 177,
	["POGGOD"] = 178,
	["Ice Cave"] = 179,
	["Wirtual"] = 180,
	["STS"] = 181,
	["Erdos"] = 182,
	["Junkevin"] = 183,
	["Erg"] = 184,
	["Shiny"] = 185,
	["MarginalRev"] = 186,
	["Mango"] = 187,
	["Caldor"] = 188,
	["Mogwai"] = 189,
	["Kalzumeus"] = 190,
	["JuniorEgg"] = 191,
	["Metamodern"] = 192,
	["Foundation"] = 193,
	["Balaji"] = 194,
	["Phlogistron"] = 195,
	["Brand"] = 196,
	["Corbusier"] = 197,
	["Union"] = 198,
	["Improv"] = 199,
	["Kit"] = 200,
	["Jersey"] = 201,
	["Lem"] = 202,
	["Bell"] = 203,
	["Boustrophedon"] = 204,
	["Ricardo"] = 205,
	["Runic"] = 206,
	["Shed"] = 207,
	["Banks"] = 208,
	["Sterling"] = 209,
	["Succulent"] = 210,
	["Roblox"] = 211,
	["Sandking"] = 212,
	["Frog King"] = 213,
	["Bergamot"] = 214,
	["Sejong"] = 215,
	["Life"] = 216,
	["Slug"] = 217,
	["Villeneuve"] = 218,
	["Verne"] = 219,
	["Sakura"] = 220,
	["Osu"] = 221,
	["Rojo"] = 222,
	["Cosmo"] = 223,
	["Vance"] = 224,
	["Ortho"] = 225,
	["Aorta"] = 226,
	["Ende"] = 227,
	["Pakicetus"] = 228,
	["Slig"] = 229,
	["Asana"] = 230,
	["Socotra"] = 231,
	["Uniq"] = 232,
	["Frow"] = 233,
	["100mm"] = 234,
	["Akureyri"] = 235,
	["Dungen"] = 236,
	["Eusocial"] = 237,
	["Formicidae"] = 238,
	["Fosse"] = 239,
	["GoldPath"] = 240,
	["Hollavallagardur"] = 241,
	["Krystal Cat"] = 242,
	["Motte"] = 243,
	["Nosey Parker"] = 244,
	["Woodingdean"] = 245,
	["Zimmerman"] = 246,
	["Consilience"] = 247,
	["Polk"] = 248,
	["Carreyrou"] = 249,
	["Disillusion"] = 250,
	["Oki"] = 251,
	["Saws"] = 252,
	["Rivendell"] = 253,
	["Mana"] = 254,
	["Iris"] = 255,
	["Link"] = 256,
	["Kew"] = 257,
	["Moranis"] = 258,
	["Furin"] = 259,
	["Haldane"] = 260,
	["Guru"] = 261,
	["Asp"] = 262,
	["Lemna"] = 263,
	["Mitochondria"] = 264,
	["Iron Council"] = 265,
	["Darwin"] = 266,
	["Huxley"] = 267,
	["Queequeg"] = 268,
	["Karolina"] = 269,
	["Mieville"] = 270,
	["Remus"] = 271,
	["Slaad"] = 272,
	["Romulus"] = 273,
	["Shetland"] = 274,
	["Asimov"] = 275,
	["Honey"] = 276,
	["Aphid"] = 277,
	["Ararat"] = 278,
	["Spanish Steps"] = 279,
	["E"] = 280,
	["Petrichor"] = 281,
	["Kudzu"] = 282,
	["Orbital"] = 283,
	["Kermit"] = 284,
	["Natural Selection"] = 285,
	["Soylent"] = 286,
	["Markopolos"] = 287,
	["Mutation"] = 288,
	["Clarke"] = 289,
	["Elemental"] = 290,
	["Dwarf Fortress"] = 291,
	["Eno"] = 292,
	["Barchan"] = 293,
	["Heretic"] = 294,
	["IPO"] = 295,
	["Mandelbrot"] = 296,
	["Meter"] = 297,
	["Minesweeper"] = 298,
	["Mitchell"] = 299,
	["Nakamura"] = 300,
	["P vs NP"] = 301,
	["Rosen"] = 302,
	["Ryuichi"] = 303,
	["Roygbiv"] = 304,
	["Starlink"] = 305,
	["Seek"] = 306,
	["Aphex"] = 307,
	["Poaceae"] = 308,
	["Black"] = 309,
	["Macbeth"] = 310,
	["F"] = 311,
	["Stickmaster"] = 312,
	["Yang"] = 313,
	["Kongzi"] = 314,
	["Sully"] = 315,
	["Swiss"] = 316,
	["Reggie"] = 317,
	["Shimrod"] = 318,
	["Bee Swarm"] = 319,
	["Nautical"] = 320,
	["Emerald"] = 321,
	["Voxel"] = 322,
	["McGuire"] = 323,
	["Terrain"] = 324,
	["Hunters"] = 325,
	["Motherboard"] = 326,
	["Fungible"] = 327,
	["Adam"] = 328,
	["Mortal Coil"] = 329,
	["Null Island"] = 330,
	["Point Nemo"] = 331,
	["Kaladin"] = 332,
	["Spline"] = 333,
	["Quidnunc"] = 334,
	["Joe"] = 335,
	["Midnight"] = 336,
	["Rockall"] = 337,
	["Dusek"] = 338,
	["Quirk"] = 339,
	["Yocto"] = 340,
	["Gate"] = 341,
	["Noob"] = 342,
	["Sebeok"] = 343,
	["Floor"] = 344,
	["Coagulate"] = 345,
	["Anlil"] = 346,
	["Natsu"] = 347,
	["Supernova"] = 348,
	["Julia"] = 349,
	["Tosa"] = 350,
	["Enki"] = 351,
	["Kornfeld"] = 352,
	["Eve"] = 353,
	["WoofMoo"] = 354,
	["Tablet"] = 355,
	["Moonlight"] = 356,
	["Weatherbottom"] = 357,
	["Obelisk"] = 358,
	["Bazooka"] = 359,
	["Niven"] = 360,
	["Stepping Stone"] = 361,
	["Shackleton"] = 362,
	["Leafy"] = 363,
	["Loch"] = 364,
	["Signal"] = 365,
	["Joist"] = 366,
	["Lapidem"] = 367,
	["888"] = 368,
	["Penguin"] = 369,
	["Ice Nine"] = 370,
	["Rime"] = 371,
	["Frozen"] = 372,
	["Hyperquenched"] = 373,
	["Channel"] = 374,
	["Square"] = 375,
	["Construction"] = 376,
	["Symmetry"] = 377,
	["Chomik"] = 378,
	["Pothole"] = 379,
	["Merely"] = 380,
	["Slack"] = 381,
	["Pynchon"] = 382,
	["Atlantis"] = 383,
	["Meme"] = 384,
	["Paleozoic"] = 385,
	["Studio"] = 386,
	["Neandertal"] = 387,
	["Yolk"] = 388,
	["Lunar"] = 389,
	["Alpha"] = 390,
	["Hurdle"] = 391,
	["Beta"] = 392,
	["Ardillita"] = 393,
	["Wiki"] = 394,
	["SeniorEgg"] = 395,
	["Mariana Trench"] = 396,
	["Tiktaalik"] = 397,
	["Totem"] = 398,
	["Yap"] = 399,
	["Thaana"] = 400,
	["Moire"] = 401,
	["Bit"] = 402,
	["Nozzle"] = 403,
	["Yeager"] = 404,
	["Antediluvian"] = 405,
	["Acre"] = 406,
	["Transparent Radiation"] = 407,
	["Foam"] = 408,
	["Pit"] = 409,
	["Lyonesse"] = 410,
	["Klondike"] = 411,
	["Waldo"] = 412,
	["Metropolitan"] = 413,
	["Gyrovague"] = 414,
	["Axolotl"] = 415,
	["Infotaxis"] = 416,
	["Game Making Journey"] = 417,
	["💀"] = 418,
	["人"] = 419,
	["Waymond"] = 420,
	["დიუნი"] = 421,
	["الكثيب"] = 422,
	["෴☃❽"] = 423,
	["Napoleon"] = 424,
	["Josephine"] = 425,
	["Parkour"] = 426,
	["Oobleck"] = 427,
	["Rheology"] = 428,
	["凸"] = 429,
	["凹"] = 430,
	["zzyzx"] = 431,
	["Neko"] = 432,
	["O"] = 433,
	["Chirality"] = 434,
	["Polysaturated"] = 435,
	["Humuhumunukunukuapuaa"] = 436,
	["👍"] = 437,
	["🔥"] = 438,
	["Perseverance"] = 439,
	["Defenestrate"] = 440,
	["Lindebrock"] = 441,
	["Beluga"] = 442,
	["Artificial Petrifaction"] = 443,
	["Varmints"] = 444,
	["Wordsworth"] = 445,
	["Lord"] = 446,
	["Basin"] = 447,
	["King"] = 448,
	["Queen"] = 449,
	["Ring"] = 450,
	["UGC"] = 451,
	["Kappa"] = 452,
	["Xanthophyll"] = 453,
	["ディズニー"] = 454,
	-- ["♦"]=445,
	-- ["♣"]=446,
	-- ["♥"]=447,
	-- ["♠"]=448,
	["Landscape"] = 455,
	["Acrobatics"] = 456,
	["Contest"] = 457,
	["Penrose Tiles"] = 458,
	["Equal Temperament"] = 459,
	["Magnus"] = 460,
	["Midjourney"] = 461,
	["Sophon"] = 462,
	["Rhadamanthus"] = 463,
	["ඞ"] = 464,
	["007"] = 465,
	["65536"] = 466,
	["Unicycle"] = 467,
	["Cobweb"] = 468,
	["Wing"] = 469,
	["Squelch"] = 470,
	["Gold Bug"] = 471,
	["Tanstaafl"] = 472,
	["CERN"] = 473,
	["Entity"] = 474,
	["Arbitrage"] = 475,
	["Hsu"] = 476,
	["Perestroika"] = 477,
	["Kazumura"] = 478,
	["Unexpectable"] = 479,
	["RCC"] = 480,
	["Instrumental Convergence"] = 481,
	["Hedonic Monster"] = 482,
	["Brachiolation"] = 483,
	["Survival"] = 484,
	["Hyperparameter"] = 485,
	["Wallfacer"] = 486,
	["Glasnost"] = 487,
	["HPMOR"] = 488,
	["Teotwaki"] = 489,
	["Jackie"] = 490,
	["Hide"] = 491,
	["Skill Susie"] = 492,
	["Hypergravity"] = 493,
	["Bolt"] = 494,
	["Stellar Voyage"] = 495,
	["Tungsten"] = 496,
	["Quadruple"] = 497,
	["Mægæ"] = 498,
	["Elder"] = 499,
	["Triple"] = 500,
	["Village Up North"] = 501,
	["Ø"] = 502,
	["Fosbury"] = 503,
	["Tetromino"] = 504,
	["Keep Off the Grass"] = 505,
	["cOld mOld on a sLate pLate"] = 506,
	["Freedom"] = 507,
	["Salekhard"] = 508,
	["Knocking on the Door of Life"] = 509,
	["Polemic"] = 510,
	["GPT"] = 511,
	["Calico"] = 512,
	["Tern"] = 513,
	["Easy"] = 514,
	["Expand"] = 515,
	["Kalikandjari"] = 516,
	["Agartha"] = 517,
	["Based"] = 518,
	["Zen"] = 519,
	["Waluigi"] = 520,
	["Pavement"] = 521,
	["Ukumbizo"] = 522,
	["Ripple"] = 523,
	["Butte"] = 524,
	["Tryto"] = 525,
	["Grid"] = 526,
	["Manifold"] = 527,
	["Elam"] = 528,
	["Factorio"] = 529,
	["Nadir"] = 530,
	["YTP"] = 531,
	["Prompt"] = 532,
	["Chadiesson"] = 533,
	["Enum"] = 534,
	["Talladega"] = 535,
	-- ["Talladega2"] = 536,
	["👻"] = 537,
	["Big"] = 538,
	["Small"] = 539,
	["Blossa"] = 540,
	["Pulse"] = 541,
	["ataasinngorneq"] = 542,
	["Дыццӕг"] = 543,
	["Rebo"] = 544,
	["Fimmtudagur"] = 545,
	["金曜日"] = 546,
	["Thứ Bảy"] = 547,
	["일요일"] = 548,
	["Jökulhlaup"] = 549,
	["►"] = 550,
	["◄"] = 551,
	["🗯"] = 552,
	["Gemelo"] = 553,
	["Cow"] = 554,
	["Claude"] = 555,
	["Molière"] = 556,
	["Éliante"] = 557,
	["Erewhon"] = 558,
	["Polytropon"] = 559,
	["DNA"] = 560,
	["Prefontaine"] = 561,
}

--aliases of symbolic signs to their english alias.
--for example: [🔥:"flame"]
module.signName2Alias = {}
module.signName2Alias["💀"] = "skull"
module.signName2Alias["Molière"] = "Moliere"
module.signName2Alias["Éliante"] = "Eliante"
module.signName2Alias["人"] = "person"
module.signName2Alias["დიუნი"] = "dune"
module.signName2Alias["الكثيب"] = "arabic"
module.signName2Alias["෴☃❽"] = "squiggle"
module.signName2Alias["凸"] = "bumpout"
module.signName2Alias["凹"] = "bumpin"
module.signName2Alias["👍"] = "thumbsup"
module.signName2Alias["🔥"] = "flame"
module.signName2Alias["ディズニー"] = "disney"
module.signName2Alias["Mægæ"] = "Maegae"
module.signName2Alias["ඞ"] = "sus"
module.signName2Alias["Ø"] = "nullsymbol"
module.signName2Alias["👻"] = "ghost"
module.signName2Alias["ataasinngorneq"] = "Monday - Greenlandic"
module.signName2Alias["Дыццӕг"] = "Tuesday - Ossettian"
module.signName2Alias["Rebo"] = "Wednesday - Indonesian"
module.signName2Alias["Fimmtudagur"] = "Thursday - Icelandic"
module.signName2Alias["金曜日"] = "Friday - Japanese"
module.signName2Alias["Thứ Bảy"] = "Saturday - Vietnamese"
module.signName2Alias["일요일"] = "Sunday - Korean"
--probably put this in a bucket saying to NOT repeat its alias.
module.signName2Alias["Jökulhlaup"] = "Jokulhlaup"
module.signName2Alias["►"] = "right"
module.signName2Alias["◄"] = "left"
module.signName2Alias["🗯"] = "anger"

-- exclusion list.
module.aliasesWhichAreVeryCloseSoDontNeedToBeShown = {}
module.aliasesWhichAreVeryCloseSoDontNeedToBeShown["Jökulhlaup"] = true
module.aliasesWhichAreVeryCloseSoDontNeedToBeShown["Éliante"] = true
module.aliasesWhichAreVeryCloseSoDontNeedToBeShown["Molière"] = true

local useLeftFaceSignNames = { ["cOld mOld on a sLate pLate"] = 1, ["Tetromino"] = 2 }
local usesBackFaceSignNames = { ["Brussel Sprouts"] = 1 }
local unanchoredSignNames = { ["Freedom"] = 1 }

module.useLeftFaceSignNames = useLeftFaceSignNames
module.unanchoredSignNames = unanchoredSignNames
module.usesBackFaceSignNames = usesBackFaceSignNames
local alternateNames = [[Tiramisu Parboil
Turin Parchment
Tar Heel Parker
Tureen Parfait
Terrapin Parrot
Tarragon Partake
Terrene Parka
Terrain Parsley
Tern Parquet
Tarantula Parturition]]

--⚔
--♦ ♣ ♠ ♥⅖♾¥€ß
--℘

module.name2signId = name2signId

module.ExcludeSignNamesFromEndingAt = {
	"007",
	"65536",
	"POGGOD",
	"Mauna Loa",
}

--random race cannot start from these for preservation of sanctity reasons.
module.ExcludeSignNamesFromStartingAt = {
	"007",
	"65536",
	"POGGOD",
	"Chaoskampf",
	"Nyx",
	"👻",
	"💀",
	"🔥",
	"Ø",
	"Chirality",
	"Why",
	"Chomik",
	"Rubble",
	"Vesuvius",
	"Kew",
	"Neandertal",
	"Troll Bridge", -- the above should likely never be warpable.
}

local SignIdIsExcludedFromStart: { [number]: boolean } = {}
module.SignIdIsExcludedFromStart = SignIdIsExcludedFromStart
for ii, signName in ipairs(module.ExcludeSignNamesFromStartingAt) do
	local signId = module.name2signId[signName]
	if signId == nil then
		continue
	end
	module.SignIdIsExcludedFromStart[signId] = true
end

local SignIdIsExcludedFromEnd: { [number]: boolean } = {}
module.SignIdIsExcludedFromEnd = SignIdIsExcludedFromEnd
for ii, signName in ipairs(module.ExcludeSignNamesFromEndingAt) do
	local signId = module.name2signId[signName]
	if signId == nil then
		continue
	end
	module.SignIdIsExcludedFromEnd[signId] = true
end

module.signId2name = {}

local signId2name: { [number]: string } = {}
module.signId2name = signId2name

local namelower2signId: { [string]: number } = {}
module.namelower2signId = namelower2signId

local signCount = 0
for name, signId in pairs(module.name2signId) do
	module.signId2name[signId] = name
	module.name2signId[name] = signId
	module.namelower2signId[name:lower()] = signId
	signCount += 1
end
module.signCount = signCount

local objects = {}

--users
objects.TerrainParkourUserId = 164062733
objects.BrouhahahaUserId = 90115385
objects.terrainparkorffcUserId = 7030441423
objects.ninjaParkourGroupId = 3200785
objects.TerrainParkourPlaceId = 868107368
objects.TerrainParkourUniverseId = 360479749
objects.TerrainParkourDevGamePlaceId = 1
objects.TerrainParkourDevGameUniverseId = 1

module.objects = objects

--amount of time to do green 'something changed' ui
module.greenTime = 24

local releaseNotes: { [number]: string } = {
	[185] = [[* fix challenge for long sign names
* move marathon configuration to an easier new button, removed from settings
* mouseovers for leaderboard headers
* fixed marathon timing to be more exact
* fixed settings "hide leaderboard" function
]],
	[186] = [[* make surveys have 3 possible answers: yes, unset, no.
* make a new setting to shorten digit display in contest window
* some improvements to make settings better in the future
]],
	[187] = [[* make dynamic running into a setting.
* setting for digit display of contest UI
* fixed internal sign representation
* fix live-application of settings and marathon configurations when you reset character
]],
	[188] = [[* redo dynamic running to always position yoru run against the current result, not your prior result
]],
	[189] = [[* marathon ui bugfixes
* keyboard shortcut '1' to warp to the last completed race.
* worse lava behavior
]],
	[191] = [[* server events interactive loop with payouts]],
	[192] = [[* fix bugs when someone leaves the server who had dynamic running on]],
	[194] = [[* improve dynamic running]],
	[195] = [[* Fix dynamic running more.]],
	[196] = [[* Other small fixes and server event badges.
* webhooks for server event completion]],
	[197] = [[* New signs 
* New areas
* New slogans
* New badges
* Badge for being the first person to win a certain badge
* Improved UI for badge notifications
* "beckon" command
* Special signs with badges
* Improvement to discord webhooks
* <tab> now only toggles LB, not LB+Chat
* Server events can only be started from signs which someone in the server has found
* Shrunk LB somewhat to handle more people
* Fixed mouseovers
* Fixed mouseover and green highlighting
* Cleaned up a bunch of old code - test warping
* Warning: disable dynamic running if you have performance problems with it
]],
	[198] = [[* Bugfixes for resetting
* fix dynamic running efficiency
* fix beckon terminology
* redo movement setup (?)
]],
	[202] = [[* Various bugfixes]],
	[203] = [[* Sign lore badge]],
	[205] = [[* Survey server integration]],
	[206] = [[* Freedom]],
	[208] = [[* Badge fixes]],
	[211] = [[* Add other server user info into sign history lookups
* starting on user sign profiles. try "/sign tripool"]],
	[216] = [[* First release in a while, new sign, catching up.]],
	[231] = [[* First release in a very great while. 
	* Rewrote warping, movement, refactor lots of things, lots of new funky signs. 
	* Some UI and cmdline fixes. Basically, this is about rebooting game development]],
	[235] = [[ Redid the way i manage movement, warping etc
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
	[236] = [[ * fix game even when the user dies or gets reset.
* Fix aligning player to point at warp target
* Optional highlight when doing /rr, joining a popular or new race, joining a server event, joining a race someone else ran, hitting 1 to rejoin your prior race, 
* User settings for highlighting in some situations, plus globally
* Sort user settings now
* Global 'show' command
* Keyboard command to kill highlight 'h'
 ]],
	[237] = [[* draggable leaderboard (!) claude+1 hour
* keyboard shortcuts.
* new server slogans
]],
	[251] = [[* The leaderboard, server events, and marathon windows are now separate, draggable, resizable, and minimizable.
* Tracking gamejoin versions
]],
	[252] = [[* fix sign profile mouseovers somewhat.]],
	[257] = [[* leaderboard redos. server fixes. fixed swim bug with flying and i think also with stopping swimming slowdown incorrectly.
also, some particles. working on fixing them and giving them all meaning, also will bea ble to be turned off
also fixed small UI bugs with minimize buttons not working totally.
and I'm working on more stuff soon.]],
	[258] = [[* fixed a few speedup bugs where you wouldn't accelerate sometimes.
* reduced particles and made them hopefully more useful. lots of other ideas here including a "random particle sign". But for now really turned them down a lot. I've been thinking that in a way, they are like gears in trackmania. Or could be... see unreleased code.
* I have some more ideas about this but all that should change here today is fixing things.
* Some other logical fixes in here too, nothing that should effect runs normally.
* moved running UI to center and gave it a light background. This UI will likely change and also be more configurable and moveable and controllable, etc in the future for you.]],
	[261] = [[* actually fix lacking speedups as you run? Also somewhat improve race running UI
* make speed display continuous rather than only showing up when you are on a run.]],
}

local SpecialSignDescriptions = {
	["Triple"] = "Limited to 3 terrain types:",
	["Keep Off the Grass"] = "Don't touch Grass",
	["Quadruple"] = "Limited to 4 terrain types:",
	["cOld mOld on a sLate pLate"] = "Touch each terrain type only once.",
	["Fosbury"] = "High Jump",
	["Bolt"] = "Fast",
	["Prefontaine"] = "Faaast",
	["Salekhard"] = "Slip",
	["Hypergravity"] = "So Heavy",
	["👻"] = "ghost",
}
module.SpecialSignDescriptions = SpecialSignDescriptions

module.releaseNotes = releaseNotes

return module
