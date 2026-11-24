PHASE QUEST - ZONE 1: SMOOTH ADVENTURE PACK

Replaces the original pixel pack with smooth illustrated assets generated using the built-in image_gen tool. The current MainCharModel sprite supplied chibi proportions, warm brown contours, cream, ocean-blue and golden-tan palette cues. The character itself remains unchanged.

All individual PNGs and animation frames are now 192x192 with transparent backgrounds. The original *_Atlas_48.png filenames are retained for project compatibility, but their cells are 192x192, not 48x48. Use linear filtering for the environment. Ground geometry remains an 80x40 isometric footprint in Level 1; character filtering remains nearest.

Terrain atlas: 8 columns, 2 rows (1536x384). Row-major order:
grass, snow, ice, water, stone, frost, dirt, cracked_ice, deep_water, slush, hot_stone, ice_bridge

Objects atlas: 8 columns, 3 rows (1536x576). Row-major order:
ice_block, melting_ice, frozen_key, puddle, heater, cooler, temperature_controller, gate_closed, gate_open, pressure_plate, ice_bridge, wood_bridge, water_collector, thermometer, crystal, rock, snow_tree, sign, switch, steam_vent, snow_pile

Individual PNGs are in tiles/ and objects/. Animation sheets are 1152x192: six 192x192 frames left to right. Melting decreases solid ice into water. Freezing assets are included for future gameplay; Level 1 currently uses melting only.

Original pixel assets are preserved in Assets/Sprites/Zone1_Original_Pixel_Backup/Pack, excluded from Godot import. Full generated source sheets are stored in smooth_sources/ (also excluded from import). GENERATION_PROMPTS.json contains the exact prompts. tools/package_zone1_smooth.ps1 performs mechanical cropping and atlas packaging; run it with Windows PowerShell 5.1 if rebuilding.

The art uses a coordinated smooth style, rather than the original character's pixel texture. Generated terrain is fitted into the game's ground geometry; these are visual assets, not automatic terrain/autotiling rules. Collisions and puzzle connections remain in the level scripts.
