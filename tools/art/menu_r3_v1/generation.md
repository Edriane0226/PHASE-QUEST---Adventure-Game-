# R3 011 original menu sources and exports

15 November 2026. Imagegen skill, built-in `image_gen.imagegen`, three independent generation calls, `transparent_background=false`; no CLI/API fallback, no proprietary artwork extraction. Exact complete prompt set is [imagegen-prompts.json](imagegen-prompts.json). Approved world/HUD images and the user's attached Crystarise title screen informed composition/style only; no character/logo/scene was copied. Original Phase Quest OFL title typeface and existing shared UI are retained.

## Selected original paintings

All selected outputs are **1672×941**, measured rather than assumed from the requested ideal2048×1152. Original generated files remain in `C:/Users/Nitro/.codex/generated_images/01a1db19-7cef-7cb2-a32a-f37e432aff11/`. Workspace copies preserve original bytes:

- [gardens-source.png](gardens-source.png): `exec-de2330b4-d93e-416b-a5cd-63fbbecf1c61.png` — snowy Gardens terraces/river/shelter exteriors.
- [vale-source.png](vale-source.png): `exec-0dcffe57-03dd-43f3-af26-c2f88313ea61.png` — Sunpetal Vale lowlands/orchard/greenhouse silhouettes.
- [laboratory-source.png](laboratory-source.png): `exec-47832777-1967-4cd4-a055-be2a0b23b75d.png` — pale Phaseworks lab/observatory ridge exteriors.

Each shares a mainland identity: snowy upper terraces, green river lowlands and pale research ridge. No floating-island substitution. These are staged regional compositions, **not final built-world coordinates/camera captures**;021must bind or replace them with final accepted geography. No visible targets, machinery controls, recipes, crystals, objective markers, checkpoints, puzzle solutions or discovery state. Broad unmarked terrain/architecture remains visible as atmosphere; final spoiler/art acceptance is human review.

## Editable native sources

- `layer_source.gd`: registered original tint/edge veil plus separate decorative mist/light motes. These are newly authored separable overlays over a flattened painting, not invented recovered terrain/object layers.
- `logo_source.gd`: original Phase Quest wordmark using unchanged `PhasequestUI.ttf`, restrained cream/cyan/gold edge and small original line/diamond detail. No extracted Crystarise letterforms or characters.
- `build_assets.gd` / `build.ps1`: native GPU export at measured canvas size. Straight-alpha normalization is applied only to newly rendered transparent veil/atmosphere/logo products because transparent viewport output is premultiplied; original generated paintings remain unchanged.
- Runtime presentation sources under `Scripts/UI/Title`; shared010support dialogs reused unchanged.

Each regional runtime set has `{gardens|vale|laboratory}_painting.png`, `_veil.png`, `_atmosphere.png`, `_static.png` under `assets/ui/main_menu/r3_v1/`. Also exports `title_logo.png` and `fallback_static.png`:14PNG products. `regions.json`, `dialogs.json`, `menu_states.json` and `build-products.json` describe registration, seven supporting dialogs and19disposable menu states. Current background/Save/Continue rotation/transition logic is not changed. No original source project or old menu files deleted.

Static rendering loads one background texture; layered rendering uses painting/veil/atmosphere. A1672×941RGBA texture is6,293,408bytes≈6.002MiB raw; one layered set≈18.006MiB before platform formats/mipmaps. Title/fonts/shared-support/cast/cache/peak import memory are additional. Mobile memory/load/overdraw/compression remains012/013/021/050verification. PNG file size is not GPU memory. No constant slideshow; optional atmosphere drift is small and stops for reduced motion, pause/focus/background/modal. Static exports preserve phase0.

Rebuild never reruns imagegen. Selected source PNGs and prompts remain in this project. No production consumer depends on the external generated-images directory.
