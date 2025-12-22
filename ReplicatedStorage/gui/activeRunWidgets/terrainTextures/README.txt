TERRAIN TEXTURE TILES
=====================

Place 32x32 or 64x64 PNG tiles here, one per terrain type.

Required files (priority order):
1. grass.png
2. rock.png
3. sand.png
4. snow.png
5. ice.png
6. water.png
7. mud.png
8. concrete.png
9. brick.png
10. wood.png
11. cobblestone.png
12. asphalt.png
13. slate.png
14. basalt.png
15. limestone.png
16. sandstone.png
17. glacier.png
18. crackedlava.png
19. pavement.png
20. leafygrass.png
21. ground.png
22. salt.png

After creating tiles:
1. Upload to Roblox via Game Explorer > Bulk Import
2. Copy the asset IDs
3. Update terrainData.lua with the IDs

Example in terrainData.lua:
    grass = {
        ...
        textureId = "rbxassetid://123456789",
    },

