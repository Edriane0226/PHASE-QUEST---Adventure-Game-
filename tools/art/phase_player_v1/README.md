# Phase player v1 — native animation authoring

R2 Prompt 004, 13 November 2026. Sources are the current authored explorer `frames.tres` / operating art and the preserved R2 003 Phase Device sprites. No imagegen redraw, raster replacement, model resize or locomotion-resource rewrite was required.

- `reference.gd` exports a read-only reference sheet of actual idle/walk/operate textures.
- `current-reference.png` preserves that source review.
- `baseline-hashes.json` records source files before this integration.
- `build.gd` creates `device_v1/poses.tres`, `gait_sockets.tres` and `manifest.json`. Run with Godot `--headless --path . --script res://tools/art/phase_player_v1/build.gd`.

Forty native clips contain 80 pose-frame records: hold `[0]`, aim `[1]`, fire start `[0,1]`, loop `[1,2,1,3]`, release `[1,0]`, in every compass direction. These indices refer to the existing four authored `operate` frames. Primary hand points are selected from opaque skin components and validated; each frame records grip, hand-occlusion region, neck, recoil, rear-forearm warp and projected muzzle. All 464 existing base/gait/action frames have separate neck/torso landmarks. Rebuild these resources if the source artwork changes.

The runtime compositor replaces only the torso band with a registered upper-body pose while retaining the current gait/head/boots. A separate original-head layer protects the face/hair from equipment. A source-hand layer covers the grip. Rear forearms extend through a small piecewise skinning transform; the fist itself translates rigidly. Both the hand and device use the same transformed socket, including recoil and gait bob. This creates authored directional animation from the established art instead of regenerating the character.

The existing explorer `frames.tres`, its PNGs, `player_model.gd`, collision shape and movement/jump constants remain source inputs. `Actors/Player.tscn` and `campaign_player.gd` intentionally change to integrate the rig. Consequently, the historical R2 003 "player files unchanged" checks for those two integration files are no longer an applicable invariant after R2 004; the original locomotion-art hash is still enforced by the new tests.

This folder inherits `tools/art/.gdignore`; source/review inputs do not ship as runtime dependencies. No prior source art or user assets were deleted.
