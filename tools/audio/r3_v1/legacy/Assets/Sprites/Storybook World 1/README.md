# Storybook World 1 props

Original AI-generated artwork inspired by the supplied cartoon adventure reference. Applied to the playable World 1 terrain/props and secondary menu panels. The main menu and player use their restored original artwork. Transparent prop PNG master sheet with 16 Godot AtlasTexture resources; drag `.tres` resources into Sprite2D or TextureRect texture fields.

Includes leafy tree, snow pine, mossy rock, flowering shrub, unlit/lit heater, firewood, campfire, solid/melting/puddle ice states, frost crystal, air vent, heat reflector, checkpoint lantern, and sanctuary gate.

The prop layout is not an exact uniform grid. Atlas regions use adjusted row and column boundaries. Ice uses three illustrated states selected by melt progress. `storybook_terrain.png` contains grass, dirt, snow, and stone quadrants sampled onto the existing walkable terrain. `storybook_menu.png` is the shared forest backdrop.

`storybook_explorer.png` and `explorer_frames.res` retain the unused generated explorer draft. The active model instead uses `Assets/Sprites/MainCharModel/original_explorer_frames.tres`: separate idle rotation images and eight running frames in each of eight directions. Rebuild that active resource with `tools/restore_original_explorer.gd`.

Shared parchment/wood frames remain scalable code-native StyleBoxes in `UI/quest_frame.gd`. Rebuild themes with `tools/build_quest_theme.gd`, then persist menu previews with `tools/save_storybook_menus.gd`.
