# 0004 Desktop and the house detail kit

| Field | Value |
|---|---|
| Status | Built |
| Branch | `feat/0004-desktop-and-house-detail` |
| Depends on | 0003 (status "Built") |

## 1. Goal

The game runs on desktop computers as the main platform, with better light. The houses of the hẻm look like real tube houses in Vũng Tàu: brick under plaster and paint, with depth, wear, and the clutter of a real street.

The houses in this plan are in the hẻm of plans 0001 to 0003. Plan 0007 puts houses of the same kit on the real lots of the map.

## 2. Out of scope

- Houses on the real map. (Plan 0007.)
- Rooms inside the houses, except the open shop floor of plan 0002 R15.
- People models.
- Signed builds and store pages. (The release plan.)

## 3. Decisions

| ID | Decision | Reason |
|---|---|---|
| D1 | Desktop (Windows, macOS, Linux) is the main platform. Android, iOS, and the web build stay, with lower settings. This replaces the platform line in `AGENTS.md`. | My decision. A desktop screen and a desktop graphics card show more of the place. |
| D2 | One renderer for each platform: Forward+ on desktop, Mobile on Android and iOS, Compatibility on the web. Set `rendering/renderer/rendering_method` to `forward_plus` and `rendering/renderer/rendering_method.mobile` to `mobile`. | Forward+ has screen-space ambient occlusion (SSAO), screen-space indirect light (SSIL), global light from signed distance fields (SDFGI), volumetric fog, and screen-space reflections. The builder checks in the Godot documentation which of these the Mobile renderer does not have, and records it in `AGENTS.md`. |
| D3 | Quality presets: Low, Medium, High, Ultra. The game selects one at the first start. The player changes it in the Settings app. | Desktop computers differ very much. Low is near the phone look. |
| D4 | Desktop controls: mouse look with a captured cursor, W, A, S, D to move, E to act, Tab for the phone, Esc for the menu. A gamepad also works. Touch controls stay on phones. | Standard first-person controls on a computer. |
| D5 | All house parts are made in code and shaders. No model files. Ground textures are CC0 scans that CI downloads. | No artist on the project. The quick test showed that depth, shadows, and a plaster shader made in code change the look the most. |
| D6 | Houses are brick under plaster and paint. Brick shows only where plaster fell off, or on bare side walls that rise above a shorter neighbor. | I confirm it first-hand. |
| D7 | Play tests of game logic run on the Mobile renderer. The look review runs on Forward+ with still screenshots only. | Verified in the workspace: Forward+ with SSAO, SSIL, and SDFGI renders under lavapipe, but one frame at 1600 × 900 takes about 2 s. The Mobile renderer is much faster. |
| D8 | Wall colors are muted and faded: off-white, cream, pale yellow, light grey, and sand. Strong colors are rare on walls. Most strong color in the street comes from signs, awnings, shutters, tiles, plants, and laundry. The palette comes from photos of real houses that I approve. | My review of the first test: the pastel colors looked artificial, and few houses have them. |

## 4. Requirements

### Desktop

- **R1.** Set the renderers of D2. The desktop window can change size, and it has a fullscreen setting. The layout works at 16:9, 16:10, and 21:9.
- **R2.** Desktop controls of D4. The Settings app has mouse sensitivity and "invert up and down". A gamepad: left stick to move, right stick to look, A (bottom button) to act, Y (top button) for the phone.
- **R3.** When the phone is up on desktop, the cursor is free, and the mouse uses the apps. W, A, S, D still move the player. Tab or a right click lowers the phone.
- **R4.** Quality presets:

  | Preset | Renderer | Sun shadow distance | SSAO | SSIL | SDFGI | Volumetric fog | Render scale |
  |---|---|---|---|---|---|---|---|
  | Low | Mobile | 25 m | No | No | No | No | 0.75 |
  | Medium | Forward+ | 50 m | Yes | No | No | No | 1.0 |
  | High | Forward+ | 80 m | Yes | Yes | Yes | No | 1.0 |
  | Ultra | Forward+ | 120 m | Yes | Yes | Yes | Yes | 1.0 |

  A change of renderer needs a restart. The Settings app says so.
- **R5.** The sun casts shadows on all presets and all renderers, except the web build if it shows the old defect in `AGENTS.md`. Record the result.
- **R6.** Add export presets for Windows (x86_64), macOS (universal), and Linux (x86_64). The export workflow builds them and uploads them as CI artifacts. The macOS build is not signed in this plan. Write in the release notes that macOS shows a warning at the first start.

### The house detail kit

- **R7.** Make the parts in `scenes/world/parts/`. Each part takes parameters and a seed:
  - Front wall with real depth: the upper floors, the floor lines, and a roof parapet.
  - Window: recessed 0.15 m to 0.25 m, with a frame and a sill. Styles: wooden louvered shutters (older houses), glass with aluminum frames (newer houses), iron security bars.
  - Balcony: a slab that sticks out 0.6 m to 1.2 m, with a rail. Rail styles: plain vertical bars, iron patterns, stainless steel.
  - Ground floor: roll-up metal shutter (open, half, closed, with a short animation), folding iron gate (cửa xếp), or a wall with a door. A tiled step in front.
  - Roof types. The mix depends on the area:
    - Dense hẻm of homes: mostly corrugated metal roofs (tôn), faded mint or teal, rusty brown, and some red or maroon. Between them, flat concrete roof terraces with a parapet. Few tile roofs.
    - Villa areas: pitched roofs of terracotta tiles.
    - Schools and offices: long blocks with deep red tile roofs.
    - Flat roof terraces have rebar that sticks up for a future floor, stainless steel water tanks, solar water heaters (flat panels or glass tubes), laundry lines, and foam boxes with plants. Metal roofs often have a round turbine vent.
    - The players see roofs from Núi Lớn and Núi Nhỏ, so roofs matter.
  - Clutter: AC units, potted plants, shop signs with Vietnamese text, canvas or corrugated awnings, electric meter boxes, and down pipes.
  - Overhead cables: concrete poles with thick, sagging bundles of many cables across the street and along it. In the street photos they are one of the strongest features. Make them dense, not a few thin lines.
  - Rooftop: stainless steel water tanks (horizontal and vertical), satellite dishes, TV antennas, and sometimes a cell tower.
  - Signs: vertical signs on the corner of a building ("KHÁCH SẠN" for hotels), stacked shop signs, light boxes, and signs fixed to balconies. Use fictional names only.
  - Front materials: polished granite or ceramic tiles on the ground floor front, patterned ceramic tiles on the whole front of some houses, vase balusters (con tiện) and columns on villas, breeze blocks or small vent openings in bare side walls.
  - Building types: tube houses of 2 to 5 floors, villas with pitched tile roofs, and mini-hotels of 5 to 8 floors with many small windows and narrow balconies near the beach.
- **R8.** Plaster shader (`plaster.gdshader`), with a seed for each house:
  - Paint color with small changes in tone.
  - Rain streaks from the parapet and below each sill.
  - Damp and dirt at the base.
  - Patches where plaster fell off, with red brick and mortar under them. Mostly low on the wall and at edges.
  - A paint age parameter: new houses are clean, old houses are faded and stained.
- **R9.** Side walls above a shorter neighbor show bare grey plaster or brick (D6). Where brick shows, it is red hollow clay brick (gạch ống): the holes show at broken ends and edges. Mortar joints are thick and uneven.
- **R10.** Each house in `hem_layout.json` gets: width (3.5 m to 5 m), floors (2 to 5), a style (`old` or `new`), a paint color from the palette (R10a), paint age, and a seed. The old and the new styles mix in one hẻm, as in a real street.
- **R10a.** `data/world/palette.json` holds the wall colors. Each color has a value in sRGB, a weight (how often it is used), and a source. Use these first values. The architect measured them from three aerial photos of Vũng Tàu that I chose (from Núi Lớn and Núi Nhỏ). The method: only the town area near the camera, only sunlit pixels, without trees, water, and terracotta roof tiles, then 10 color clusters:

  | sRGB | Weight | Saturation | Value |
  |---|---|---|---|
  | `#C1C2C3` | 0.132 | 0.01 | 0.76 |
  | `#B1AFB0` | 0.128 | 0.01 | 0.70 |
  | `#E9E4DC` | 0.123 | 0.06 | 0.91 |
  | `#B5A497` | 0.120 | 0.16 | 0.71 |
  | `#D2D4D4` | 0.117 | 0.01 | 0.83 |
  | `#F5F6F2` | 0.101 | 0.02 | 0.96 |
  | `#D1B7A6` | 0.096 | 0.21 | 0.82 |
  | `#E8CFB9` | 0.093 | 0.20 | 0.91 |
  | `#B88C7C` | 0.054 | 0.33 | 0.72 |
  | `#939DB4` | 0.036 | 0.18 | 0.71 |

  The photos have haze, which makes white walls look grey. So the builder makes each grey (saturation 0.02 or less) 10% lighter. Most walls have a saturation of 0.06 or less. Cream and peach walls have about 0.2. The test colors of the first probe had 0.3 to 0.4, which is why they looked artificial. The source of each value is "aerial photos, 2026-10-24". The photos are not in the repository.

  Street-level photos that I chose add these values (white balance corrected with the asphalt as neutral grey):

  | Part | sRGB | Saturation |
  |---|---|---|
  | Cream villa wall | `#D3CFB4` | 0.15 |
  | Salmon hotel wall | `#CE9E74` | 0.44 |
  | Turquoise wall | `#06ACC0` | 0.97 |
  | Unpainted grey plaster | `#A3A799` | 0.08 |
  | Terracotta roof tiles in sunlight | `#E19C61` | 0.57 |

  So strong colors do exist, but on few buildings, and more on mini-hotels and shops than on homes. The rule: about 85% of walls come from the measured muted palette. About 15% are "bold": salmon, turquoise, sky blue, bright yellow, or two-color stripes. Bold walls are at most 1 house in 6 in a hẻm of homes, and up to 1 in 3 on a street near the beach with hotels. The house generator picks colors by weight. Two neighbor houses must not have the same color.
- **R10b.** The palette also has colors for the accent parts: shutters, rails, window frames, signs, and awnings. These can be stronger than the walls.
- **R10c.** Roof colors: terracotta tiles from `#D39B83`, `#B28469`, and `#634D3C` (measured in the same photos), with a seed for age and moss. Terracotta is about 6% of the town area in the photos.
  Corrugated metal and roof terrace colors, measured in a top-down photo of a dense hẻm that I chose (12 clusters, without the dark alleys):

    | sRGB | Weight | Kind |
    |---|---|---|
    | `#CBCAC0` | 0.132 | grey/white (concrete roof, wall, faded metal) |
    | `#BCAF9A` | 0.114 | terracotta or orange metal |
    | `#DDE5E4` | 0.112 | grey/white (concrete roof, wall, faded metal) |
    | `#91968E` | 0.104 | grey/white (concrete roof, wall, faded metal) |
    | `#7A7A71` | 0.086 | grey/white (concrete roof, wall, faded metal) |
    | `#5C3E36` | 0.086 | rusty metal |
    | `#94B8B8` | 0.082 | mint/teal corrugated metal |
    | `#92574A` | 0.081 | rusty metal |
    | `#B98265` | 0.063 | terracotta or orange metal |
    | `#505E5B` | 0.061 | mint/teal corrugated metal |
    | `#B0D8D8` | 0.053 | mint/teal corrugated metal |
    | `#4FA9A9` | 0.027 | mint/teal corrugated metal |

  In that photo: grey and white (concrete terraces and faded metal) 43%, mint and teal metal 22%, orange and tan metal 18%, rusty metal 17%. Rust shows in streaks along the ridges of the metal sheets.
- **R11.** The hẻm floor: concrete with cracks and patches, a drain gutter, and covers. The tiled fronts of the houses differ from house to house.
- **R11a.** A hẻm of homes is narrow: 2 m to 3.5 m between the house fronts. Change the homestay hẻm from 3.5 m to 2.8 m until the map data of plan 0005 gives its real width. Check that first-person walking, tap to walk, and the phone still work in it.
- **R12.** `docs/content/reference/houses.md` lists each part of R7 with links to public photos on the web for comparison. Links only. Do not copy photos into the repository. I mark each part as correct or not correct for Vũng Tàu.

### Performance

- **R13.** Use `MultiMeshInstance3D` for the many repeated small parts (rail bars, pots, AC units). Use visibility ranges to show fewer parts on far houses. Put occluders on the house walls.
- **R14.** Budget at the fixed views of PT-32, from `RenderingServer.get_rendering_info()`:

  | Preset | Draw calls | Triangles in view |
  |---|---|---|
  | Low | 600 or fewer | 300 000 or fewer |
  | High | 2 000 or fewer | 2 000 000 or fewer |

  Record the measured values in `AGENTS.md`.

## 5. Play-test scenarios

- **PT-25 `look_review`.** Fixed views of the hẻm at 07:00, 12:00, 17:30, and 20:00. Take still screenshots on Forward+ (High) and on Mobile (Low). I compare them with `houses.md`.
- **PT-26 `desktop_controls`.** Keyboard and mouse: walk the hẻm, look, act on Bà Tư with E, raise the phone with Tab, use the Listen app with the mouse, lower the phone with a right click.
- **PT-27 `gamepad`.** The same steps with gamepad events.
- **PT-28 `quality_presets`.** Change to each preset. Quit and start again. The preset stays. Take a screenshot of the same view on each preset.
- **PT-29 `shutters`.** At 04:40, 05:40, 10:40, and 12:10, the shutter of Phở Cô Sáu is half, open, half, and closed. The shutter does not go through the sign or the step.
- **PT-30 `window_sizes`.** At 1280 × 720, 1920 × 1080, 2560 × 1080, and 1920 × 1200: the phone, the subtitles, and the center dot are fully visible and do not overlap.
- **PT-31 `house_seeds`.** Build 50 houses with random seeds and parameters. No part goes through another part. No floating part. Each house stands on the ground.
- **PT-32 `budget`.** Measure R14 at three fixed views on each preset.

## 6. Acceptance criteria

1. All unit tests and play tests pass. The builder looked at all screenshots.
2. I looked at the PT-25 screenshots and agree that the houses look like Vũng Tàu.
3. The Windows, macOS, and Linux builds start on my computer.
4. `AGENTS.md` has the platform decision, the renderers, the presets, and the measured budget.

## 7. Open questions

- **Q1.** Which computer do I use to test the desktop builds (Windows, macOS, or Linux)?
- **Q2.** Which parts in R7 are not correct for Vũng Tàu, and which parts are missing? (For example: solar water heaters on roofs, an altar for Ông Địa in shops, numbers painted on the walls.) Answered in part: the photos show solar water heaters on many flat roofs (now in R7).
- **Q3.** Answered: in a dense hẻm, corrugated metal roofs and flat concrete terraces are the most common. Tile roofs are common in villa areas (R7, R10c).
- **Q4.** Answered: the street photos show granite or tiled ground floor fronts and some fully tiled fronts with patterns. They are in R7.
- **Q5.** The bold wall colors "sky blue" (`#7DB3DC`) and "bright yellow" (`#E6C440`), the stripes, the brick color, and the accent colors (R10b) are first values of the builder, with the source "builder, check" in `palette.json`. Are they correct?
- **Q6.** Esc shows the home screen of the phone, because the phone is the menu of the game (N3). Is that the menu that I want, or do I want a separate pause menu?

## 8. Builder notes

- **N1. The renderer of a preset.** Godot selects the renderer when it starts. The builder verified with Godot 4.7.2 that a settings file (`override.cfg`, or `application/config/project_settings_override` in `user://`) changes the value of the setting, but not the renderer. The command-line argument `--rendering-method` works. So when the preset needs another renderer (Low on desktop uses the Mobile renderer), the game starts again with this argument (`OS.set_restart_on_exit`). The Settings app shows the note "The change starts after a restart" and a "Restart now" button. The play tests and the editor do not start again. A computer with Low starts the game two times at each start. `docs/release-notes.md` says so.
- **N2. The first preset.** The first start selects Low on a phone, in the web build, and on a computer without a graphics card (lavapipe in the workspace and in CI), Medium with a graphics chip in the processor, and High with a separate graphics card (`RenderingServer.get_video_adapter_type()`).
- **N3. Desktop controls.** A click of a real mouse on the world captures the cursor. Then a click acts on the focus, the same as E. Esc shows the home screen of the phone (the phone is the menu), and Esc again lowers it (Q6). With a gamepad and the phone up, the D-pad selects a button of the phone, A presses it, and B goes back, so that the gamepad can use the apps (PT-27).
- **N4. Low shadows.** R5 asks for sun shadows on all presets. Low uses one shadow split and hard shadows, the cost of a phone. Medium uses two splits, and High and Ultra use four, with soft shadows. The web build keeps the shadows off: with the sun shadow on, Compatibility still makes the up-facing surfaces almost white at noon with Godot 4.7.2 (section 5 of `AGENTS.md` has the result).
- **N5. Light on Forward+.** In the narrow hẻm, SDFGI and SSAO made the street almost black at noon in the first look review. The SDFGI energy is now 4, and SDFGI converges in 5 frames (it also helps after a jump of the clock). I check the PT-25 screenshots of High against Low.
- **N6. The shaders without a graphics card.** The play tests render on the CPU (lavapipe). The first plaster shader computed many noise functions for each pixel and made the frame about two times slower. The shaders now read two tileable noise textures that the game makes at the start (`HouseMaterials.noise_textures()`). At the "along" view of PT-32, a frame takes about 110 ms at 1280 × 720 under lavapipe with all parts and the shadow.
- **N7. The hẻm floor and D5.** D5 says that ground textures are CC0 scans that CI downloads. The hẻm floor of this plan is a shader made in code (concrete, cracks, patches). The download of the scanned ground textures is a step of plan 0005, for the real ground.
- **N8. The palette.** The greys of the aerial photos (saturation 0.02 or less) have a value 10 % higher (for example `#C1C2C3` to `#D4D5D6`). `palette.json` keeps each measured value next to the value that the game uses. The colors of the houses of the hẻm follow the rules of R10a: neighbors differ, 2 bold walls in the 14 houses of the hẻm (salmon and turquoise), and 1 in 4 on the beach road (sky blue). `content_checker.gd` checks the rules.
- **N9. The floors of the mini-hotels.** R10 gives 2 to 5 floors for each house of `hem_layout.json`, and R7 gives 5 to 8 floors for a mini-hotel. The two mini-hotels on the beach road have 5 floors. PT-31 builds mini-hotels with 5 to 8 floors.
- **N10. The narrow hẻm (R11a).** The hẻm is 2.8 m wide. The carts, the people, and the places where the player stands now follow the width of the hẻm (`Hem.cart_z` and the others). People stand nearer to the player, so a look at the face, the chest, or the hips of a person makes the focus (it was the face only).
- **N11. The step and the shutter.** The tiled step in front of each house is 8 cm high and 30 cm deep, on the floor layer, so the player walks on it and a tap on it walks there. The rolled shutter box is inside the top of the opening, and the shutter runs behind the front of the wall. Then the shutter does not go through the sign or the step (PT-29). The shutter rolls in 1.2 s when the time changes during the game.
- **N12. Parts that touch.** PT-31 found that pots on a balcony went through the rails and the AC units, and that roofs went past the side walls into the next house. Pots now stand only on deep balconies, in their own places, and roofs stop at the side walls. A mini-hotel has its balconies and its AC units away from its vertical sign.
- **N13. The budget (R14).** PT-32 measured (with the occluders of R13): Low 348 to 464 draw calls and 132 000 to 150 000 triangles (limit 600 and 300 000). Medium 455 to 592 draw calls and 167 000 to 175 000 triangles. High 481 to 863 draw calls and 183 000 to 277 000 triangles (limit 2 000 and 2 000 000). Ultra 483 to 931 draw calls and 181 000 to 302 000 triangles. The roof view has the most parts, because it sees over the occluders. `AGENTS.md` has the values.
- **N14. Play tests.** PT-25 to PT-32 are new. PT-16 and PT-21 change the new settings too. A phase line in a scenario can have `--renderer=forward_plus`, and the argument `--quality=NAME` sets the preset (a setup step, the same as `--start-time`). Fullscreen in PT-16 goes on and off again, because a fullscreen window under Xvfb has the size of the whole virtual screen.

