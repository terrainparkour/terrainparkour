--!strict

--eval 9.21

local module = {}

export type AssetLink = { assetId: number }

local audios: { [string]: AssetLink } = {}
audios.oof = { assetId = 10799908168 }
audios.windowsError = { assetId = 2323663829 }
audios.windowsStartup = { assetId = 3673835118 }
audios.gallop = { assetId = 10800199301 }
audios.knock = { assetId = 10800199831 }
audios.runningConcrete = { assetId = 10800200784 }
audios.runningIce = { assetId = 10800201272 }
audios.runningMuddy = { assetId = 10800201690 }
audios.runningSnow = { assetId = 10800202072 }
audios.swoosh = { assetId = 10800203092 }

module.audios = audios

local music: { [string]: AssetLink } = {}
music.gamelan = { assetId = 1840694341 }
music.marimba = { assetId = 1845912647 }
music.marimbaloop = { assetId = 10800200350 }

module.music = music

return module
