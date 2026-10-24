# 0004 Desktop and the house detail kit

| Field | Value |
|---|---|
| Status | Draft |
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
  - Roof: parapet, rebar that sticks up for a future floor, a steel water tank, laundry lines, foam boxes with plants.
  - Clutter: AC units, potted plants, shop signs with Vietnamese text, canvas or corrugated awnings, electric meter boxes, down pipes, wires, and cable bundles at the poles.
- **R8.** Plaster shader (`plaster.gdshader`), with a seed for each house:
  - Paint color with small changes in tone.
  - Rain streaks from the parapet and below each sill.
  - Damp and dirt at the base.
  - Patches where plaster fell off, with red brick and mortar under them. Mostly low on the wall and at edges.
  - A paint age parameter: new houses are clean, old houses are faded and stained.
- **R9.** Side walls above a shorter neighbor show bare grey plaster or brick (D6).
- **R10.** Each house in `hem_layout.json` gets: width (3.5 m to 5 m), floors (2 to 5), a style (`old` or `new`), paint color, paint age, and a seed. The old and the new styles mix in one hẻm, as in a real street.
- **R11.** The hẻm floor: concrete with cracks and patches, a drain gutter, and covers. The tiled fronts of the houses differ from house to house.
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
- **Q2.** Which parts in R7 are not correct for Vũng Tàu, and which parts are missing? (For example: solar water heaters on roofs, an altar for Ông Địa in shops, numbers painted on the walls.)
