# R3 007 cast sources and production

15 November 2026. Built-in `image_gen.imagegen` through the imagegen skill, six calls, `transparent_background=true`, no CLI/API fallback. Sources preserved in this directory. References were current Phase Quest explorer/Professor art and newly generated identity sheets; no lavender-haired HUD character or proprietary sprite was supplied as an identity reference. New portraits/world sheets are original generated designs requiring user acceptance. Existing source provenance is retained, not re-certified by this task.

User explicitly authorized Finn rework after no dedicated current art or reliable original binding was found: “ok also rework finn if you cant find it i think it got deleted”. Finn's name and capstone role remain; resident is not renamed. New Professor names/IDs are documented in the production registry and do not change live dialogue routing.

## Generated inputs

- `marisol-world-source.png`:1536×1024,8columns×4rows. Original generated file `exec-7b1136d9-13a1-47ea-b678-14ac08f32c58.png`.
- `ivo-world-source.png`:1536×1024,8×4. Original `exec-90e8ed4d-76a2-4b84-8aaa-419513b9ea79.png`.
- `marisol-portrait-source.png`:1254×1254,2×2. Original `exec-ce309b3a-a59e-4e96-aa1a-e7f02fcc55de.png`.
- `ivo-portrait-source.png`:1254×1254,2×2. Original `exec-0666ab5c-4b2d-4831-9dff-31ca0e90d1ae.png`.
- `finn-world-source.png`:1536×1024,8×4. Original `exec-aeddbd78-eb10-4d89-997b-89b203afc69d.png`.
- `finn-portrait-source.png`:1254×1254,2×2. Original `exec-ba71ae60-cd78-440a-bc17-1e95ba0a892f.png`.

Original generation output directory: `C:/Users/Nitro/.codex/generated_images/01a1db19-7cef-7cb2-a32a-f37e432aff11/`. All six selected files were copied into this workspace; no production asset depends on that external directory. The requested portrait composition mentioned1024; actual1254dimensions are measured and split using actual image size, never assumed1024.

## Exact generation prompts

### Marisol world sheet

References: existing `assets/characters/cast/professor/reworked/idle/south_east/frame_00.png` and existing `assets/characters/cast/explorer/Animation Sprites Player/Animation Sprites Player/black_hair_generated/idle_south_east.png`.

```text
Create ONE transparent game character sprite sheet for original Phase Quest Professor Marisol Reed (Zone 2, evaporation/boiling/condensation teacher). Reference images are STYLE/PROPORTION ONLY, not edit targets: preserve their confident thin dark contours, warm cel shading, compact chibi adventure RPG proportions, big head, readable hands, 2D orthographic top-down/isometric-style camera. Design a DISTINCT new adult woman: deep warm brown skin, dark chocolate curly hair swept into a large high round puff with small ochre tie, no facial glasses, brass goggles resting above forehead, sage green short field coat with cream lapels over cream shirt, ochre waist sash, dark trousers and sturdy brown ankle boots. Friendly scientist, not wizard; empty relaxed hands; no staff, tools, clipboard or glowing magic. No lavender or purple hair, no copied characters. Exact sheet: 8 EQUAL COLUMNS x 4 EQUAL ROWS, landscape 3:2 aspect, fully transparent background, generous alpha gutters inside EVERY cell, no text, labels, grid lines, shadows or scenery. Keep same character/height/feet baseline in each cell, full body unobstructed with all hair/boots inside cell. Column camera directions ordered LEFT TO RIGHT: EAST (right profile), SOUTHEAST (front-right three-quarter), SOUTH (front), SOUTHWEST (front-left), WEST (left profile), NORTHWEST (back-left), NORTH (back), NORTHEAST (back-right). Keep genuine back views. Row 1: neutral idle. Row 2: attentive listening, hands gathered near waist. Row 3: explaining, one open palm extended gently. Row 4: pleased success, small welcoming hand gesture, not jumping. These are discrete interaction poses, not a walk cycle. Every cell must have original identical costume, skin, hair and anatomy; only direction/pose changes. Sprite sheet suitable for native atlas slicing, not an illustrated presentation poster.
```

### Ivo world sheet

References: existing Professor southeast frame and `marisol-world-source.png`, style/proportion only.

```text
Create ONE original game sprite sheet of Phase Quest Professor Ivo Aster, Zone3 controlled phase-change scientist. References are STYLE/PROPORTION ONLY, not characters to copy. Match crisp thin dark outlines, restrained warm cel shading and compact big-headed chibi adventure game bodies, 2D orthographic top-down/isometric-style camera. DISTINCT new adult male scientist around40, olive bronze skin, short neatly swept charcoal hair with ONE silver streak at right temple, slim rectangular steel spectacles, clean shaven (no moustache/beard), longer high-collar ivory lab coat with muted teal side panels and dark slate cuffs, navy trousers, dark boots, small brass instrument badge. No hat, no goggles, no lavender/purple hair, no magical costume. Empty hands. Silhouette and costume clearly different from burgundy elderly reference professor and green-coat puff-haired woman reference. EXACT 8 COLUMNS x4 ROWS, landscape3:2 aspect, equal cells, alpha-transparent background, no scenery, no shadows/glows, no text/labels/grid, generous blank gutters. Every character fully opaque including dark boots and clothes; only background fully transparent. Full body inside each cell, consistent feet baseline and body scale. Columns LEFT TO RIGHT: east right profile, southeast front-right, south frontal, southwest front-left, west left profile, northwest back-left, north back, northeast back-right. Genuine back views with no frontal face pasted on. Rows: neutral idle; attentive listening hands near waist; explaining with one open palm; pleased success with small friendly open hands, no jumping. Identical identity/hair/costume/anatomy across all32poses. This is a native-game atlas source, no decorative poster.
```

### Marisol portraits

References: `marisol-world-source.png` identity; existing `assets/characters/cast/professor/portraits/professor_neutral.png` portrait finish only.

```text
One square transparent 2x2 PORTRAIT EXPRESSION ATLAS of Professor Marisol Reed, precisely the SAME new sage-coat puff-haired woman in reference1. Reference2 is PORTRAIT FINISH STYLE ONLY, do not copy old man's identity or burgundy clothes. Keep reference1 warm brown skin, dark curly high puff, ochre tie, brass goggles on forehead, sage field coat/cream lapels, cream shirt, ochre sash, adult friendly female teacher. Match original Phase Quest clean thin dark outlines and gentle cel shading. Four equal square cells, each head-and-shoulders/bust facing southeast/front-right three-quarter, identical face/hair/costume/scale/baseline, all hair/goggles/shoulders inside its cell with generous transparent margins. Top-left NEUTRAL friendly attentive closed mouth; top-right EXPLAINING one open palm and engaged speaking mouth; bottom-left HAPPY smile with pleased eyes; bottom-right CONCERNED thoughtful eyebrows, supportive not angry. Not four different people. Exact 2columns x2rows, square1024x1024 composition, no text, borders, labels, grid lines, background or extra props. Character pixels fully opaque, background transparent. Do not crop puff or goggles. No lavender hair or copied reference characters.
```

### Ivo portraits

References: `ivo-world-source.png` identity; existing Professor neutral portrait finish only.

```text
One transparent square 2x2 PORTRAIT EXPRESSION ATLAS of Professor Ivo Aster, exactly the new ivory/slate-coated black-haired scientist with silver temple streak from reference1. Reference2 only establishes original Phase Quest portrait finish, NOT old man's face/hair/moustache/clothes. Keep reference1 clean-shaven adult man, olive bronze/light warm skin, charcoal short swept hair with single silver streak at right temple, dark framed spectacles, ivory long high-collar lab coat with slate teal panels/cuffs, dark navy vest/shirt and small brass instrument badge. Four equal square cells, all same identity/head scale, southeast front-right three-quarter head-and-shoulders bust, gentle cel shading and thin crisp dark contours. Top-left neutral attentive; top-right explaining with one open palm and speaking mouth; bottom-left happy pleased smile; bottom-right concerned thoughtful/supportive expression with hand near chin. All hair/spectacles/hands/shoulders wholly inside each cell, generous transparent margins. Exact2columns x2rows square composition1024x1024; no text, labels, borders, scene or extra props. Fully opaque character including black hair, fully transparent background. Do not turn him into gray-haired moustached Scaldwell, woman, child, wizard or lavender-haired mockup figure.
```

### Finn world sheet

References: existing Professor southeast frame and `marisol-world-source.png`, finish/proportion only; new identity authorized by user.

```text
One original Phase Quest game sprite sheet: FINN, friendly young adult traveling capstone assessor. User authorized new Finn design because old art cannot be recovered. References establish only thin dark outlines, warm cel shading, compact big-headed chibi RPG body and orthographic top-down/isometric perspective. Finn must be distinct from explorer and all Professors: short tidy auburn/copper side-parted hair with two small cowlicks, warm fair freckled cheeks, brown eyes, no glasses/goggles/beard/hat, slate-blue sleeveless waistcoat over ivory rolled-sleeve shirt, muted teal neckerchief, charcoal trousers, brown ankle boots, small brown crossbody CLOSED ledger pouch with brass clasp. Empty hands, no loose clipboard or weapon. Not shirtless resident, not black-haired explorer, not lab-coat Professor, no lavender hair. EXACT8columns x4rows landscape3:2 sheet, equal cells, full body within each cell, identical feet baseline/scale and outfit, generous transparent gutters, no scene/text/grid/shadows. Fully opaque character pixels, truly transparent background. Columns east right profile, southeast front-right, south front, southwest front-left, west left profile, northwest back-left, north back, northeast back-right. Rows neutral idle; attentive listening hands near waist; explaining one open palm; pleased success small open-hand gesture not jumping. Same Finn through32poses, genuine back views. Suitable for native atlas slicing.
```

### Finn portraits

References: `finn-world-source.png` identity; existing Professor neutral portrait finish only.

```text
Create ONE transparent square2x2portrait expression atlas of FINN, the exact auburn freckled assessor in reference1. Reference2 only establishes original Phase Quest portrait illustration finish. Preserve Finn short auburn/copper side-part/cowlick hair, fair warm freckled cheeks, brown eyes, NOglasses, slate-blue sleeveless vest over ivory rolled-sleeve shirt, muted teal neckerchief, brown crossbody ledger pouch strap. Friendly young adult capstone assessor, NOT resident/explorer/Professor. Same face, hair and clothing across four equal square cells, all southeast/front-right head-and-shoulders bust with generous transparent margins. Top-left neutral attentive; top-right explaining/supportive one open palm; bottom-left happy encouraging smile; bottom-right concerned/thoughtful supportive expression, no anger. Original game thin dark contour and warm cel shading, big-headed chibi RPG portrait proportions. Every hair tip/hand/shoulder within its cell, identical scale and bottom baseline. Square1024x1024layout,2columns2rows,no text, labels, grid, background, scenery, magical effects, extra people or copied lavender-haired character. Fully opaque character and transparent background.
```

## Deterministic pipeline

Run `build.ps1` from this folder or root; it invokes the isolated `docs/art/r3-prompt007/review/build_cast.gd` builder through the review runner. Read source PNG RGBA; detect alpha>0.10bounds per cell, estimate boot center from bottom14rows atalpha>0.35, derive each direction's uniform factor from idle opaque height130. Apply that same factor across its four poses, registering boots at(96,159)inside192×192. This does not repaint/erase source pixels or alter old character art. Nonsemantic slicing/resizing/atlas packing uses Godot Image; generated art editing was not delegated to Python or replaced by SVG placeholders.

Portraits use actual2×2source cells, common per-character union crop, one uniform fit into512×640with16pxbottom margin. New world/portrait PNGs keep generated RGBA. New art does not inherit the old high-alpha cutout because it would discard legitimate generated alpha. The view-image diagnostic's RGB/alpha display initially looked rectangular; actual Godot GPU captures and retained alpha diagnostics confirm transparent background. Source PNGs remain untouched; no manual background removal or alpha-threshold repaint.

Scaldwell world frames and original portrait crops are read unchanged. New wrappers pack exact RGBA pixels with four transparent gutters; world1page and portrait2pages, all2048×2048. New SpriteFrames preserve192logicalcanvas/trim offsets; existing Scaldwell idle uses its original1.5fps/fourframes. Other Z1 states select existing idle frames without claiming authored explanatory gestures. New Z2/Z3/Finn clips are one authored pose per state/direction; no fake walk cycles or invented gameplay.

Production resources reside in `assets/characters/professors/r3_v1/`; `cast_registry.json`, atlas metadata and normalized PNGs preserve source-cell/bounds/scale/foot/export records. `write_manifest.ps1` captures source/product SHA-256 and dimensions. Re-run deterministic build rather than imagegen for identical outputs. Generation itself is not deterministic and does not approve final art, names, animation or mobile readability.
