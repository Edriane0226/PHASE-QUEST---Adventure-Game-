# Pixel art tools

The standard for `assets/pixel_v1`. Aseprite draws and exports; Godot only checks.

| Step | Command (from the project folder) |
| --- | --- |
| Build palette, templates, tiles, example | `pwsh tools/art/pixel_v1/build.ps1` (or `-What palette`, `template`, `tiles`, `example`) |
| Build the game's terrain sheets | `pwsh tools/art/pixel_v1/build.ps1 -What terrain`, then export, then `tools/world/terrain_bake/bake.gd` |
| Export every sheet | `pwsh tools/art/pixel_v1/export.ps1` |
| Review picture of assembled tiles | `pwsh tools/art/pixel_v1/build.ps1 -What review` (after export) |
| Check everything | `pwsh tools/art/pixel_v1/validate.ps1` |
| Check an old image | `pwsh tools/art/pixel_v1/validate.ps1 -Legacy <png>` |
| Test the checker itself | `pwsh tools/art/pixel_v1/selftest.ps1` |

Aseprite is expected at `C:\aseprite\build\bin\aseprite.exe`; use `-Aseprite` for another place. `validate.ps1` has `-Godot`.

## Files

- `palette.lua` is the only place where colours are defined: 8 ramps of 5, 8 neutrals and one accent (olive). New colours are added at the end. Index 0 is transparent.
- `art_src/pixel_v1/` holds the `.aseprite` sources and one hand-kept `.meta.json` per source. `_template/` has the starting files. Godot ignores the folder.
- `assets/pixel_v1/` holds exports: `.png`, `.json` (frames, times, tags), `.meta.json` and `manifest.json`. Never edit them by hand.
- `art_src/pixel_v1/generated.json` remembers what the scripts wrote. A file that a person changed is skipped, never replaced. To take a generated file over, edit and save it in Aseprite.

## Standard

- Indexed colour, master palette, layers `body`, `detail`, `outline`. Aseprite cannot lock a palette inside a file, so `export.ps1` audits each source and the validator fails on a changed palette.
- Pixels are fully opaque or empty. Shadows are separate sheets named `<group>_shadow`, one colour; the engine sets their strength.
- Light from top-left. Cell and pivot are fixed per group. 8 frames per row, no trim, no padding.
- Colours per sheet: prop 6, card 8, character 12, machine 16, cap 4, edge 4, side 6, shadow 1.
- Frame time 60-1000 ms in clips of two or more frames.
- Clips: `idle_<state>`, `to_<state>_from_<state>`, `use`, `wrong`, `solved`, the character clips, and `variant_*` or `mask_*` for tiles.
- Cap: 40x20, rows 2, 6 ... 38, 38 ... 6, 2 pixels, so a (20,10) lattice has no gap or overlap. Marks cover at most 15%.
- Edge masks: 16 frames in mask order, NE 1, SE 2, SW 4, NW 8. Cell 40x24.
- Side: 20 columns by 20 rows; repeats every (20,10) along the cliff and every 20 rows down. Cell 40x40. All tile pivots are 20,10.
- Palette rules: pairs at least 30 RGB units apart, ramp steps at least 11 lightness (L*), meaning pairs at least 20 apart (Lab) for normal, protan, deutan and tritan vision. Colour is never the only sign.

## Adding a sprite

1. Copy a file from `_template/`, draw in it, and name the tags.
2. Write `<group>.meta.json` beside it (group, class, palette, cell, pivot, footprint, clips).
3. Run `export.ps1`, then `validate.ps1`.