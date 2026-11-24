# Phase Device dial v1

Original repo-native SVG artwork matching the plan's brass circular reference direction and current ivory/navy/gold HUD. No external reference image was supplied in this prompt; no reference pixels were copied. Vector authoring preserves readable outlines at different viewport sizes.

Run `python tools/art/phase_dial_v1/build.py` from repository root with any Python 3 installation. This environment uses `C:/Users/Nitro/AppData/Roaming/uv/python/cpython-3.15.2-windows-x86_64-none/python.exe`. Reimport in Godot after regeneration. Source and delivered SVGs are editable; no intermediate assets were deleted.

Delivered in `assets/ui/phase_dial/v1/`: sixteen individually authored mode/state wedges, four distinct mode glyphs, brass frame, transparent center glow and padlock (23 SVGs, 256×256 transparent canvases). Godot imports losslessly without mipmaps. The builder owns geometry, colors and ornament. `Scripts/UI/phase_mode_dial.gd` owns dynamic type, padlock/unlock location badges, equipped/ready captions and composition. Labels use existing InterfaceSans.

Thermal is top; Cryo bottom; Pressure left; Vacuum right. Locked wedges have neutral glyphs, hatch marks, padlocks and exact introduction locations. Hovered wedges add a second bright rim and READY caption. Selected wedges add a colored fill, edge chevron, EQUIPPED caption and central mode glyph. Reduced effects removes the soft center glow and dims the center fill; outline and selected glyph remain. No shimmer, pulse or particle animation runs.

`UI/HUD/PhaseModeDial.tscn` remains a presentation view with no focus or input handler. `present(record, hovered_mode, reduced_effects)` can preview artwork without saving/equipping. Runtime uses normalized PlayerSave mode access/selection; learned capabilities stay separate. R2 006 adds `phase_mode_selector.gd` and `phase_dial_gesture.gd` adapters through the existing TouchControls router. Hover/drag adds a bright rim while the center stays committed. R2 007 adds independent Fire routing and `phase_fire_input.gd`; live target/effect integration remains in later prompts.

Inspect rendered states and phone layouts under `docs/tests/evidence/phase-dial/`; reproduce and manually inspect using `docs/tests/r2-prompt005-mode-dial.md`. Evidence/source folders have `.gdignore` and do not import as game assets.
