# Phase Quest

Godot 4.7 game project. Open `project.godot`. The startup scene is `UI/Menus/MainMenuPanel.tscn`.

## Layout

- `Actors/`: player and character scenes with their scripts (`Actors/Player/`, `Actors/Characters/`), plus world actor scenes.
- `Scripts/`: gameplay and UI scripts, including the autoloads in `Scripts/Autoload/`.
- `UI/`: menu, HUD, guide, dialog and control scenes and themes.
- `World/`: world scenes, navigation, data, and the Zone 1, 2 and 3 content.
- `assets/`: artwork, animation resources, audio, fonts, shaders and attribution.
- `tools/`: art, audio and world build scripts used to author assets. They are not part of the shipped game.
- `export_presets.cfg`: Android export settings. The `android/build` folder is the Gradle template used for export.

Godot regenerates the local `.godot/` cache. Do not commit it.
