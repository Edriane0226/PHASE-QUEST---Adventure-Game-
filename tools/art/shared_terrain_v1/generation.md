# Shared terrain v1 — source/provenance

R3 Prompt003,15 November2026. Original editable terrain/traversal SVGs authored by build_terrain.ps1 using R3 measured80×40world grid,2source pixels/world unit. No reference pixels cropped into terrain. Existing actor art is unchanged and used only in isolated review.

Cave uses built-in image_gen.imagegen, transparent_background=true; environmental-style reference: docs/plans/references/open-world-handoff/references/approved-hud-no-map.png. Original output retained as cave-source-original.png; targeted alpha/contour edit retained as cave-source-alpha-edit.png. No CLI/API fallback. Original tool output IDs: exec-d93861b6-6924-4f75-a2e6-dda79046bc89 and exec-bddbac7e-fbc8-4ca3-b674-d1db609313be.

Generation prompt: One original game-ready transparent Phase Quest cave sprite. Environmental reference only; do not copy composition, UI, characters or exact cave. Compact isometric entrance from sparse asymmetric chunky gray stone blocks, dark open central arch, thin material-colored contours, beveled highlights, subtle face variation, upper-left lighting and restrained lower-right contact shadow.2:1 orthographic ground axes. Wide readable walking threshold, neutral stone suitable for snow/grass/lab. Minimal moss outside doorway. No ground patch, character, UI, words, extra objects, photorealism or detailed voxel texture; generous transparent margins.

Edit prompt: Preserve exact block shapes, opening, perspective, colors and placement; remove broad upper/side translucent haze, retain only small base shadow, clarify contours/top edges at game scale. True alpha, full uncropped sprite, no added backdrop/objects/text. The edit retains low-alpha outer haze; production uses the existing0.90–0.97 cutout policy plus separate cave_shadow.svg. This limitation is not hidden by an opaque backdrop.

Packing: docs/art/r3-prompt003/review/prepare_cave.gd measures high-alpha bounds, adds16source-pixel margin, resizes uniformly to384wide and records crop/pivot in cave_catalog.json. Source PNGs preserved. Runtime cave.png384×274, scale0.5; doorway threshold selected explicitly, not image-bottom anchoring. Collision/support is a separate64×64passage with side blockers. Review doorway and clearances before final world placement.

Atlas: review/pack_atlas.gd bakes all273entries losslessly into four2048×2048pages,4transparent pixels padding per side, unrotated regions. terrain_atlas.tres preserves full texture envelope and source pivot remains in catalog. Pixel-equality checks compare each packed region to original imported SVG/PNG. Native source gutters, alpha and shared tile edge raster bleed are separate from physical ground support.

All original source files, prompts and builders remain retained. User art acceptance/Android review remain pending; no claim that generated cave replaces an existing campaign asset.
