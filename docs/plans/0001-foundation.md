# 0001 Foundation and the walkable hẻm

| Field | Value |
|---|---|
| Status | Draft |
| Branch | `feat/0001-foundation` |
| Depends on | Nothing |

## 1. Goal

At the end of this plan, the owner has:

- A Godot 4.7.2 project with the name "Vũng Tàu".
- A play-test system. It drives the game with real touch events, without a screen, and saves screenshots.
- CI on GitHub Actions. It runs all tests on each push. It makes a web build, an Android debug APK, and an iOS simulator build.
- A simple 3D hẻm that the player can walk along, from the homestay to Bãi Trước. Shops open and close by the game clock. The talk panel, the notebook, and the clock work.

The 3D models in this plan are simple shapes with correct proportions ("greybox"). Plan 0002 makes them look real. The game rules, the data, and the test system from this plan stay for all later plans. They must be correct.

## 2. Out of scope

- Realistic models, textures, and people. (Plan 0002.)
- The phở table and the eating flow. (Plan 0003.)
- Coffee, homestay meals, street snacks. (Later plans.)
- Music and recorded sound.
- Signed builds for the app stores.

## 3. Decisions

| ID | Decision | Reason |
|---|---|---|
| D1 | Godot 4.7.2-stable. GDScript only. | Verified in the development workspace. One language is easier to audit. |
| D2 | Compatibility renderer for all platforms. Set `rendering/renderer/rendering_method` and `rendering/renderer/rendering_method.mobile` to `gl_compatibility`. | The play tests can render it without a GPU. The screenshots then show what the phone shows. |
| D3 | Portrait phone is the main layout: base viewport 720 × 1280, stretch mode `canvas_items`, aspect `expand`. The game must also work in landscape, for the web build on a computer. | Most players hold a phone in one hand. |
| D4 | The camera looks at the house fronts from the other side of the hẻm, at about 25° down. It follows the player along the hẻm. | The player must see the shop fronts, the signs, and the shutters. This is the view that worked in the 2D prototype. A free camera can come later. |
| D5 | Tap to walk. Tap the ground to walk there. Tap a shop, a cart, or a person to walk to it and talk. | One-hand play. Same as the prototype. |
| D6 | All content is in JSON files in `data/`. Code reads it through one autoload, `Content`. | The owner must be able to edit text, hours, and prices without code. |
| D7 | Each node that a player can touch has a test ID in its metadata (`test_id`). | Play tests find nodes by test ID. They do not depend on English text or on screen positions that change. |
| D8 | Dialogue lines have IDs, for example `spot.pho.closed_after`. Play tests check the ID of the line on screen. | Text can change without a test change. |
| D9 | Units are meters. The hẻm runs along the X axis. X = 0 is the homestay. Bãi Trước is at the high X end. | One rule for all scenes. |

## 4. Project structure

Make this structure. Add files as necessary, but keep these names.

```
project.godot
export_presets.cfg
addons/gut/                 GUT 9.7.1
assets/
  fonts/                    Be Vietnam Pro (OFL), with the license file
  CREDITS.md                Source and license of each asset
autoload/
  content.gd                Reads and checks data/*.json
  game_state.gd             Clock, day, notebook, save and load
  playtest.gd               Active only with --playtest
data/
  cards.json                Notebook cards
  spots.json                Places in the hẻm, opening hours, dialogue IDs
  dialogue/hem.json         Dialogue lines and choices
  world/hem_layout.json     Lots, house sizes, colors, sign text
scenes/
  main.tscn                 World and UI
  world/hem.tscn            Built from hem_layout.json
  world/tube_house.tscn     One house, built from parameters
  world/beach.tscn          Bãi Trước
  actors/player.tscn
  actors/npc.tscn
  ui/top_bar.tscn
  ui/talk_panel.tscn
  ui/notebook_sheet.tscn
  ui/clock_sheet.tscn
  ui/toast.tscn
scripts/                    Classes with no scene (clock math, save format)
tests/unit/                 GUT tests
playtests/                  Play-test scenarios
tools/
  setup.sh                  Downloads Godot 4.7.2 and GUT if they are missing
  test.sh                   Runs the unit tests
  playtest.sh               Runs the play tests
.github/workflows/
  test.yml
  export.yml
```

## 5. Requirements

### Project and tools

- **R1.** Set the Godot project name to "Vũng Tàu". Use the Android package name and the iOS bundle ID in Open question Q1.
- **R2.** `tools/setup.sh` downloads Godot 4.7.2-stable for Linux from the Godot GitHub releases and puts it in `.tools/` (ignored by git). It downloads the export templates for 4.7.2 only when the argument `--templates` is given. The script does nothing when the files are already there.
- **R3.** `tools/test.sh` imports the project and runs all GUT tests in `tests/unit/`. It returns exit code 0 only when all tests pass.
- **R4.** Use Be Vietnam Pro as the default theme font. All Vietnamese text must show all diacritics. Add the font license to `assets/fonts/`.

### Content and data

- **R5.** Move the content of the prototype (`docs/prototype/hem-2d.html`) into `data/`: the spots, the opening hours, the cards, and the hẻm dialogue. Do not move the phở table content. It is for plan 0003.
- **R6.** Each fact in the data has a `status` field with the value `owner`, `source`, or `check`, the same as in `docs/content/culture-notes.md`.
- **R7.** `Content` checks the data when the game starts. In a debug build, it stops the game with a clear message when:
  - a dialogue choice points to a line ID that does not exist,
  - a spot or a choice points to a card ID that does not exist,
  - opening hours are not in the range 0 to 1440 minutes,
  - a required field is missing.
- **R8.** Store all Vietnamese text in Unicode NFC form.

### Game state

- **R9.** The clock counts minutes from midnight (0 to 1439) and the day number. The new game starts on day 1 at 06:00.
- **R10.** Time moves forward only by player actions:
  - Walking: 1 game minute for each 8 m walked.
  - Each action in the data has its own time cost.
  - The clock sheet: "Wait one hour", "Wait until 11:00", "Wait until 15:00", "Wait until 18:30", "Wait until 20:30". Show only the times that are later than now.
  - "Sleep until morning": day + 1, time 05:45, the player stands at the homestay door.
  - At 23:30 or later, the only choice in the talk panel is "Go home and sleep".
- **R11.** A spot is open when `open <= minutes < close`. Write unit tests for the edge minutes.
- **R12.** The notebook keeps each card ID one time only. When the player learns a new card, show a toast with the card title and play a short sound.
- **R13.** Save to `user://save.json` after each change of state. The file has a `version` field. Load the save when the game starts. A save with a different version starts a new game and does not crash. With `--save-path=PATH`, use PATH instead of `user://save.json`.

### The hẻm

- **R14.** Build the hẻm from `data/world/hem_layout.json`. Use these approximate sizes until the owner corrects them (Open question Q3):
  - Each house front is 4 m to 5 m wide.
  - Each floor is 3.2 m high. Houses have 2 to 4 floors.
  - The hẻm is 3.5 m wide between the house fronts.
- **R15.** Order of the lots, from X = 0: the homestay of Bà Tư's family, Phở Cô Sáu, a house with the bánh mì cart in front, cà phê cóc, Phở Bắc Bác Hà, a house with the nước mía cart in front, Bánh khọt Cô Út, then Bãi Trước.
- **R16.** `tube_house.tscn` makes one house from parameters: width, number of floors, wall color, balcony (yes or no), window shutter color, ground floor type (`gate`, `shop`, `wall`), sign text, sign colors. A shop has a rolling metal shutter (cửa cuốn) with three positions: open, half, closed.
- **R17.** Bãi Trước: sand, a flat sea to the horizon, a low wall along the beach road, two palm trees, and fishing boats. Between 04:30 and 07:30, the boats are on the sand and people exercise. At other times, the boats are far out on the sea.
- **R18.** Carts (bánh mì, nước mía, hủ tiếu gõ, hột vịt lộn) are present only in their opening hours. When a cart is not present, the player cannot touch it, and the panel does not show it as near.
- **R19.** Shops show the shutter closed outside their hours. Phở Cô Sáu shows the shutter half open from 04:30 to 05:30 and from 10:30 to 12:00.
- **R20.** Light follows the clock: the sun angle and color, the sky color, and the ambient light. At night, the shop lights and the street lights are on. Use not more than 8 dynamic lights in view at one time. Use emissive materials for the other lamps.
- **R21.** At night, the hủ tiếu gõ helper walks along the hẻm and makes the clack sound ("lóc cóc") each 4 to 5 seconds. Show a small speech bubble with "lóc cóc…" when the sound plays.

### Player and touch

- **R22.** Walk speed is 2.0 m/s. Use a `NavigationAgent3D` on a navigation mesh of the hẻm floor and the beach road.
- **R23.** A tap sends a ray from the camera. When the ray hits a touchable object (an `Area3D` with a `spot_id` or an `npc_id`), the player walks to the stand point of that object. Then the talk panel opens for it. When the ray hits the floor, the player walks to that point.
- **R24.** The player body must not block a tap on an object behind it. (This defect was in the prototype.)
- **R25.** Two buttons at the bottom corners walk the player 6 m to the left or to the right. The arrow keys do the same on a computer.
- **R26.** When the player stops near a spot (2 m or less), the talk panel shows the spot name, the English name, and "Open now" or "Closed now" with the hours.

### UI

- **R27.** The top bar shows the time (for example "6:00") with the Vietnamese word for the part of the day (sáng, trưa, chiều, tối, đêm), the place name, the day number, a sound on/off button, and the notebook button with the count (for example "3/21").
- **R28.** The talk panel shows: the speaker name in a colored label, the text, the Vietnamese phrases with their English meaning, the choices as large buttons, and an optional hint. Each button is at least 88 px high at the 720 px base width.
- **R29.** The talk panel must never cover the player. When the panel is tall, the camera moves so the player stays visible.
- **R30.** The notebook sheet shows all cards in groups (Phở, Xóm, Vũng Tàu). A card that the player does not know yet shows only its hint.
- **R31.** Port the hẻm dialogue from the prototype: the intro, Bà Tư's greeting ("Ăn sáng chưa con?"), the homestay (rest, sleep), and the "closed" and "look" lines for each spot. For Phở Cô Sáu in its open hours, show a line that says the shop comes in a later version.

### Play-test system

- **R32.** `playtest.gd` is an autoload. It is active only when the command line has `--playtest=NAME`. Without it, it does nothing.
- **R33.** Before the scenario starts, the play-test system can set only the start state: `--start-time=HH:MM`, `--day=N`, `--save-path=PATH`, `--seed=N`. After the start, the scenario changes the game only through input events.
- **R34.** The scenario API (a `PlaytestDriver` object):

  | Function | What it does |
  |---|---|
  | `tap(pos: Vector2)` | Sends an `InputEventScreenTouch` press and release at a screen position. |
  | `tap_id(test_id: String)` | Finds the node with that test ID. Calculates its screen center (for a 3D node, from the camera). Fails when the point is off the screen or when another touchable object or control is on top. Then calls `tap()`. |
  | `wait_until(check: Callable, timeout_s := 10.0)` | Waits until `check` returns true. Fails at the timeout. |
  | `wait_frames(n: int)` | Waits for n frames. |
  | `screenshot(name: String)` | Waits for `RenderingServer.frame_post_draw`. Saves a PNG. |
  | `expect(condition: bool, message: String)` | Records a failure with the message when the condition is false. |
  | `state()` | Returns a read-only dictionary: time, day, cards, mode, player position, the ID of the dialogue line on screen, the test IDs of the visible choices. |
  | `ui_report()` | Returns the rectangle of each visible control, and tells if a label has more lines than it can show. |

- **R35.** `tools/playtest.sh NAME [--size=WxH]` and `tools/playtest.sh --all` run Godot under `xvfb-run` with `--rendering-driver opengl3`. Output goes to `build/playtest/NAME/WxH/`: numbered screenshots and `log.json` with each step, its time, and the result.
- **R36.** A play test fails when:
  - an `expect()` fails or a wait times out,
  - Godot prints a line that contains `SCRIPT ERROR` or `ERROR:` (ignore the audio driver lines that contain `ALSA` or `audio_driver`),
  - the scenario takes more than 180 seconds.
- **R37.** `--all` runs each scenario at 720×1280 and 1080×2400. PT-06 also runs at 1280×720.

### CI

- **R38.** `.github/workflows/test.yml` runs on each push and pull request. It runs `tools/setup.sh`, `tools/test.sh`, and `tools/playtest.sh --all` on `ubuntu-latest`. It installs `xvfb` and the Mesa OpenGL drivers. It uploads `build/playtest/` as a CI artifact, also when a test fails.
- **R39.** `.github/workflows/export.yml` runs on each push to `main` and by hand (`workflow_dispatch`). It has three jobs:
  - **Web:** export the web preset with thread support off, then publish it to GitHub Pages. (Thread support needs special server headers that GitHub Pages does not send.)
  - **Android:** on `ubuntu-latest`, install JDK 17 and the Android SDK, export a debug APK, and upload it as a CI artifact.
  - **iOS:** on `macos-latest`, export the Xcode project, then build it for the iOS Simulator with `CODE_SIGNING_ALLOWED=NO`. Upload the build log. This job shows that the iOS build compiles. It does not make an app for a real phone.
- **R40.** Cache the Godot binary and the export templates in CI.

## 6. Play-test scenarios

Write each scenario as `playtests/NAME.gd`. Each scenario starts with a new save file.

- **PT-01 `boot_intro`.** Start at 06:00. The intro shows. Tap "Step outside". Bà Tư's greeting shows. Tap "Dạ, chưa ạ". The card `anSang` is in the notebook. The toast shows. Tap "Thanks, Bà Tư". The talk panel shows the homestay. Screenshot each step.
- **PT-02 `walk_hem`.** Walk from the homestay to Bãi Trước with floor taps only, then back with the walk buttons only. At each lot, check that the player is within 1 m of the target. Check that the clock moved forward the correct number of minutes for the distance. Check that the player is always on the floor (Y within 0.1 m of the floor). Screenshot each lot.
- **PT-03 `spots_by_time`.** For each start time 05:50, 11:00, 15:00, 18:30, and 21:40: tap each spot that is present. Check that the dialogue line ID is the correct one for that spot and time. Check that a cart that is not present cannot be tapped and is not shown as near. Screenshot each spot.
- **PT-04 `clock_sheet`.** Use each wait choice. Check the time after each one. Use "Sleep until morning". Check day 2, 05:45, and the player at the homestay door. Start at 23:00, wait one hour, and check that the only choice is "Go home and sleep".
- **PT-05 `save_reload`.** Learn two cards and walk to the cà phê cóc. Quit the game. Start it again with the same save path. Check the cards, the day, the time, and the player position.
- **PT-06 `layout`.** At 720×1280, 1080×2400, and 1280×720: open each sheet and each kind of talk panel. Use `ui_report()`. Check that each control is fully on the screen, no control covers the top bar, no label hides lines, and each button is at least 88 px high at the base width. Check that the player is visible when the talk panel is open.
- **PT-07 `tap_through`.** Stand the player directly in front of the bánh mì cart at 06:00. Tap the cart. The cart dialogue must open.
- **PT-08 `night`.** Start at 20:30. Check that the lights are on (screenshot). Wait for two clack sounds and check that the bubble shows. Tap the hủ tiếu gõ cart. Check the line ID.
- **PT-09 `soak`.** Use seed 1. Do 200 random taps on the floor, the spots, and the visible choices. Check that there is no script error and that the player never leaves the floor.
- **PT-10 `harness_self_test`.** A button with a known test ID must react to `tap_id()`. A tap on an off-screen node must fail with a clear message. This scenario checks the play-test system itself.

## 7. Acceptance criteria

The builder sets the status to "Built" only when all of these are true:

1. `tools/test.sh` passes. There are unit tests for the clock, the opening hours, the notebook, the save format, and the content checks in R7.
2. `tools/playtest.sh --all` passes in the development workspace and in CI.
3. The builder looked at all screenshots. No screen is broken.
4. The export workflow makes the web build on GitHub Pages, the Android debug APK, and a successful iOS Simulator build.
5. The web build opens on a phone browser, and the player can walk the hẻm.
6. Godot prints no errors and no warnings in a normal start, except the audio driver lines in a workspace with no sound card.
7. `AGENTS.md` and this plan are updated with all facts that the builder learned (for example, a command that does not work as written here).

## 8. Open questions

- **Q1.** Android package name and iOS bundle ID. The proposal is `com.sntran.vungtau`. The owner must approve it.
- **Q2.** Does the web build fit the limits of GitHub Pages without problems? The builder records the size of the web build here.
- **Q3.** The owner must check the sizes in R14 against real houses and hẻm in Vũng Tàu.
- **Q4.** The Compatibility renderer has fewer effects than the Mobile renderer. Plan 0002 must check if it can look real enough. The Mobile renderer needs Vulkan, and the development workspace has no Vulkan driver. A Vulkan software driver (lavapipe) on the CI runner is a possible solution.
