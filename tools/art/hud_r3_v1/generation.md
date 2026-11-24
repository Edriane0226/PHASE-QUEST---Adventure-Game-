# R3 009 native HUD sources

Original editable SVG assets authored in build.ps1; panels, status rails, diamond portrait UVs, joystick, states and responsive layout authored in Scripts/UI/WorldHUD. This extends the existing Godot/native SVG UI pipeline. No imagegen, third-party artwork, reference-image extraction or semantic raster editing. Approved image supplies composition only. Original portrait PNG, four mode glyph SVGs, run SVG, font/license and historical HUD/selector sources retained unchanged.

Nine 128×128 SVG sources: circular/hexagonal frames, Guides, Pause, Jump, interaction hand, warning, lock and north-facing player marker. No raster atlas needed for this small set; texture memory/performance must still be measured on physical Android. Minimap shader masks circular RGBA and blends provider-owned discovery fog; new AtlasTexture reframes unchanged original portrait from region(145,430,475,430). Original explorer_neutral.png is visibly auburn-haired, while current world sprites are darker; this pre-existing difference is recorded, not recolored or mistaken for the lavender reference identity. User consistency review remains pending.

Reproduce SVGs with `build.ps1`; `catalog.ps1` hashes the new resources and retained sources, then binds nine existing audit families. It does not delete/retire old consumers. No generated PNG/source project was replaced.
