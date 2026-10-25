# AGENTS.md

Read this file before you change the repository.
Then read `CONTRIBUTING.md` and the active plan in `docs/plans/`.

## 1. The project

The name of the project is "Vũng Tàu". Always write the name with the diacritics.
The repository name is `Vung_Tau` because GitHub names cannot have diacritics. Use "Vũng Tàu" in all other places: documents, the Godot project name, the app name, and the game text.

Vũng Tàu is a 3D game about Vietnamese food and daily life. The player is a traveler from the United States who visits Vũng Tàu today.

- **Audience:** adults who are not Vietnamese. They know phở from restaurants abroad. They do not know how people eat it in Vietnam.
- **Goal:** the player learns how people in Vietnam really eat, order, and live around food. The player does not learn recipes.
- **Setting:** Vũng Tàu today, with its real geography. The player stays at a family homestay in a small hẻm (alley) at the foot of Núi Nhỏ, near Bãi Trước (Front Beach). The homestay hẻm is only homes: the slope of the mountain is on one side, and one row of houses is on the other side. Nobody sells anything in it. To eat, the player walks down to chợ Xóm Lưới and the streets near it. The hẻm of plans 0001 to 0004, with its shops, is a test street until plan 0009 builds the real hẻm.
- **Platforms:** desktop (Windows, macOS, Linux) is the main platform. Android and iPhone apps stay, with lower settings. A web build is for quick review (plan 0004, D1).
- **Engine:** Godot 4.7.2-stable. See section 5.

## 2. Roles and workflow

I approve each plan and decide the scope. I know Southern and Vũng Tàu customs first-hand.

There are two other roles.

| Role | Work |
|---|---|
| Architect | Writes plans in `docs/plans/`. Audits the code against the plan. Runs the play tests and writes the play-test reports. |
| Builder | Builds what an approved plan describes. Writes the unit tests and the play-test scenarios that the plan lists. |

The workflow for each plan:

1. The architect writes `docs/plans/NNNN-name.md` with the status "Draft".
2. I approve it. The status changes to "Approved".
3. The builder works on a branch for the plan (for example `feat/0001-foundation`). The builder sets the status to "In progress".
4. The builder runs all unit tests and all play tests. All must pass before the builder sets the status to "Built".
5. The architect runs the play tests again, audits the code, and writes `docs/playtests/NNNN-report.md`.
6. The builder corrects all defects in the report. Then the status changes to "Done".

Do not start work that is not in an approved plan.
If the plan is not clear, or if the plan is wrong, write the question in the plan file under "Open questions". Do not guess.

## 3. Play-test standard

I must not find a defect that a play test can find.

- A play test uses real input events only. It sends touch events to screen positions. It does not call game functions to skip steps.
- A play test does every path that a player can do, not only the "happy path".
- A play test saves screenshots at each important step. Look at the screenshots. A play test that passes but shows a broken screen is a failed play test.
- A play test fails if Godot prints a script error.
- When you find a defect, add a play-test step that finds it. Then correct the defect.

## 4. Design rules

- **No "game over" and no "wrong answer".** Local people react to what the player does. They laugh, show the correct way, and explain why.
- **Many sides.** History and customs depend on who tells them. Show more than one view. For example, Southern phở and Northern phở are both correct. Each has its own customs.
- **Real words.** Use Vietnamese words with all diacritics. Show the English meaning next to the Vietnamese. Do not translate names of dishes.
- **Time of day matters.** Food has its time. Phở is breakfast. Hủ tiếu gõ comes at night. Shops open and close by the game clock.
- **The notebook (sổ tay).** Each custom that the player learns is a card in the notebook. The cards are the progress of the game.
- **Content is data.** All culture text, names, prices, and opening hours are in data files in `data/`. They are not in code. I must be able to edit them.
- **Respect.** Smelly or "strange" food is a brave moment for the player. It is not a joke about the food. Local people are proud of their food.
- **No real businesses.** Do not use the names, logos, or signs of real shops or brands.

## 5. Technical decisions

These decisions are fixed. To change one, write the change in a plan and get my approval.

| Topic | Decision | Reason |
|---|---|---|
| Engine | Godot 4.7.2-stable, GDScript | Free and open source. Exports to Android, iOS, and web. Runs without a GPU in a Linux workspace. |
| Renderer | Forward+ on desktop. Mobile (Vulkan) on Android and iOS. Compatibility (WebGL 2) for the web build (plan 0004, D2). Quality presets Low, Medium, High, Ultra (plan 0004, D3). | A desktop graphics card shows more light and detail. The Mobile renderer gives better light on phones. Both render in the workspace with the Mesa software Vulkan driver (lavapipe). Forward+ with SSAO, SSIL, and SDFGI takes about 2 s for one frame there, so the logic play tests use the Mobile renderer. Godot web exports support only the Compatibility renderer. |
| View and controls | First person at 1.6 m, landscape, base viewport 1280 × 720. Floating joystick on the left half, look drag on the right half, gyroscope look, tap to walk, a center dot and an action button (plan 0002). | The player walks around as in real life. |
| Unit tests | GUT 9.7.1, kept in `addons/gut/` | Standard test addon for Godot 4. |
| Play tests | Scenario scripts in `playtests/`, run by `tools/playtest.sh` under Xvfb | See plan 0001. |
| Text language | English with Vietnamese terms | The audience reads English. |
| Font | Be Vietnam Pro (SIL Open Font License) | Full Vietnamese diacritics. |
| CI | GitHub Actions | The repository is public, so CI is free. |
| Desktop builds | GitHub Actions: Windows, macOS (universal), Linux | Plan 0004. Not signed until the release plan. |
| Android build | GitHub Actions, Ubuntu runner | The Android SDK cannot download in the development workspace. |
| iOS build | GitHub Actions, macOS runner with Xcode | An iOS build always needs macOS and Xcode. Signed builds need a paid Apple Developer account. |

Verified in the development workspace (Linux, 2 CPUs, no GPU, no Vulkan):

- Godot 4.7.2 renders a 3D scene with shadows under `xvfb-run` with `--rendering-driver opengl3`. It saves a PNG screenshot.
- `Input.parse_input_event()` with an `InputEventScreenTouch` presses a `Button`. Touch-to-mouse emulation is on by default.
- GUT 9.7.1 runs with `godot --headless -s addons/gut/gut_cmdln.gd`.
- GitHub, npm, and PyPI are reachable. Google downloads (Android SDK, Maven) and blender.org are not reachable.
- The Copernicus DEM bucket (`copernicus-dem-30m.s3.amazonaws.com`) and the Poly Haven API are reachable. The Overpass API, Geofabrik, and `dl.polyhaven.org` are not. So `tools/geo/fetch.py` runs in CI only (plan 0005, D1).
- Godot changes a 16-bit PNG file to 8 bits when it loads it. The game reads the 16-bit height files with `Png16` (`scripts/geo/png16.gd`). An import file with `importer="keep"` makes the export keep a file as it is, and Godot does not change that import file.
- `PackedByteArray.decompress_dynamic(-1, FileAccess.COMPRESSION_DEFLATE)` reads a zlib stream (the data of a PNG file).
- A `Vector2` has 32-bit floats. UTM values and degrees need 64 bits, so `GeoProjection` gives them in a `PackedFloat64Array`.
- GitHub archive downloads (`github.com/OWNER/REPO/archive/...`) return 403 in the workspace. `git clone` works. So `tools/setup.sh` gets GUT with `git clone`. GitHub release downloads (Godot, the export templates) work.
- `Camera3D.project_ray_normal()` does not use the frustum offset. The camera uses a frustum offset, so `CameraRig.screen_ray()` calculates the ray. `Camera3D.unproject_position()` is correct.
- The workspace prints "WARNING: Could not set V-Sync mode" at each start. This warning comes from the Mesa driver. It is not a defect.
- With `--audio-driver Dummy`, Godot prints no ALSA errors. `tools/playtest.sh` and `tools/test.sh` use it.
- Godot 4.7 has the `Logger` class (`OS.add_logger()`). The play-test system uses it to record each engine error and script error as a failure in `log.json`.
- The Mobile renderer under lavapipe (package `mesa-vulkan-drivers`) runs at about 15 frames per second at 1280×720 and 6 at 2400×1080, with no shadows and no MSAA. The Compatibility renderer under llvmpipe runs at about 20 frames per second at 720×1280. MSAA halves these numbers, so it is off.
- At a low frame rate, the game time is slower than the real time: Godot does not do more than 16 physics steps in one frame (`project.godot`). A play-test check that measures a time or a distance must use the game time (`SceneTreeTimer`, `wait_seconds()`), not `Time.get_ticks_msec()`. A run longer than 180 s at 2400×1080 must be split into phases. `tools/playtest.sh` stops a run after 300 s of real time (the CI computers are about two times slower than the workspace).
- Without the package `mesa-vulkan-drivers`, Godot cannot make a Vulkan surface and falls back to OpenGL. `tools/setup.sh` installs the package.
- An Xvfb screen of 1280×720 is too small for a 1080×2400 window. `tools/playtest.sh` uses `-screen 0 2560x2560x24`.
- Godot exports the iOS Xcode project on Linux. Only the build of an `.ipa` needs macOS.
- With the sun shadow on, the Compatibility renderer under llvmpipe makes up-facing surfaces about three times too bright when the sun is high. Plan 0004 (R5) checked it again with Godot 4.7.2 at 12:00: the roofs and the hẻm floor become almost white (33 % of the lower half of the roof view is near white, against 4 % with the shadow off). The web build (Compatibility) keeps the sun shadow off. The Mobile and Forward+ renderers have shadows on all presets.
- The web export (thread support off) starts in the pre-installed Chromium with WebGL 2.
- Hugging Face is reachable from the workspace. VieNeu-TTS v3 Turbo (`vieneu==3.8.3`) runs on the CPU with ONNX Runtime: about 2 s for each line with 4 CPUs. ONNX Runtime 1.23 and later refuse the model files in the Hugging Face cache ("External data path escapes model directory"), so `tools/voices/requirements.txt` pins 1.22.1.
- A quit in the first seconds after the start does not end the process: the main thread waits for a task of the worker threads, and no worker runs it (seen with the house kit of plan 0004, with `gdb`). The play-test system waits 1 s of game time after the end of a run before it quits.
- `TaskStop` on a play-test run stops the shell, but the Godot processes go on and use the CPU. Look for them with `pgrep -fa godot` and stop them.
- An Ogg stream that still plays when Godot quits is not freed ("resources still in use at exit"). The play-test system stops the voices some frames before it quits (`stop_sounds()` in `scenes/main.gd`).

Commands that work:

```sh
# Import the project (do this once after a clone, and after you add assets)
godot --headless --path . --import

# Unit tests
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit

# Run the game with a picture, without a screen
xvfb-run -a -s "-screen 0 2560x2560x24" godot --path . --rendering-driver vulkan --rendering-method mobile --audio-driver Dummy --resolution 1280x720 -- --playtest=boot_intro

# The project scripts (they do the commands above)
tools/setup.sh               # Godot 4.7.2 in .tools/godot/, GUT in addons/gut/
tools/setup.sh --templates   # also the export templates
tools/test.sh                # all unit tests
tools/playtest.sh fp_walk    # one play test at 1280x720 with the Mobile renderer
tools/playtest.sh fp_walk --size=2400x1080
tools/playtest.sh fp_layout --renderer=compatibility   # the renderer of the web build
tools/playtest.sh look_review   # plan 0004: still screenshots on High and Low (both Forward+)
tools/playtest.sh --all      # all play tests at all sizes (about 20 minutes)

# Voices (plan 0003): a Python 3.10+ venv with tools/voices/requirements.txt
python tools/voices/build.py            # make the missing and the changed voice files
python tools/voices/build.py --check    # only check the files
python tools/voices/build.py --audition docs/voices   # also the audition page
python -m pytest -q tools/voices/tests

# Geodata (plan 0005). Python 3.13 with the packages of tools/geo/requirements.txt.
python -m pip install -r tools/geo/requirements.txt
python tools/geo/build.py          # data/geo/raw/ to data/geo/build/ (about 2 minutes, no download)
python -m pytest -q tools/geo/tests
python tools/geo/fetch.py          # CI only: the "Geodata" workflow runs it by hand on main
tools/playtest.sh geo_views        # PT-33: the screenshots of the real places

# The Vũng Tàu world (plan 0005): add -- --world=vung_tau to the Godot command. F3 shows the debug screen.

# Exports (they need the export templates)
godot --headless --path . --export-release "Web" build/web/index.html
godot --headless --path . --export-debug "iOS" build/ios/VungTau.ipa   # Xcode project only on Linux
godot --headless --path . --export-release "Linux" build/linux/vung-tau.x86_64      # plan 0004
godot --headless --path . --export-release "Windows" build/windows/VungTau.exe
godot --headless --path . --export-release "macOS" build/macos/VungTau.zip          # ad-hoc signature only
```

A play-test scenario is `playtests/NAME.gd`. It extends `RefCounted` and has `func run(d: PlaytestDriver) -> void`. The header lines `# phase: ARGS`, `# sizes: WxH ...`, and `# compatibility: WxH` tell `tools/playtest.sh` how to run it. See `scripts/playtest_driver.gd` for the API. The first-person functions are `hold_stick()`, `drag()`, `look_at_id()`, `look_at_point()`, and `gyro()`. `gyro()` replaces the sensor source of the game with a `ScriptedSensorSource`, because a workspace has no gyroscope. The phone functions (plan 0003) are `raise_phone()`, `lower_phone()`, `open_app(name)`, `tap_phone_id(test_id)`, `subtitle()`, `transcript()`, `audio_playing(npc_id)`, `talk_to(npc_id)`, `answer(reply_id, mode)`, `wait_line()`, `wait_answer()`, and `wait_quiet()`. `tools/playtest.sh NAME --only-phase=N` runs one phase, `--all --shard=I/N` runs a part of all scenarios (CI runs 6 parts at the same time), and `PLAYTEST_MAX_FPS=3` makes a fast computer test like a slow one.

## 5a. Voices, dialogue, and the phone (plan 0003)

People speak aloud in Vietnamese with subtitles. The player is a traveler with a phone. The phone is the only flat thing on the screen, with the subtitles and the action button.

- **Dialogue format** (`data/dialogue/hem.json`). A line with a `speaker` is speech: `vi` is the subtitle, `en` is the meaning in the Listen app, `say` (optional) is the text that the voice reads (write numbers and prices as Southern words), and `voice_style` (optional) is a VieNeu-TTS tag such as `[cười]`. `replies` are the phrasebook answers (`vi`, `en`, `next`, optional `next_said` for "I'll say it", or `"english": true` with `en`). `actions` are answers by an action in the world (`target` is a test ID such as `spot.pho`, `verb`, `next`). `then` is the next line of the same talk. `introduces` (a speaker ID) marks the line where the person says who they are: the subtitle and the Listen app show the name of a person only from that line on, and "Someone" before it (report 0003, D-0003-04). A line without a speaker is a description for the Lens app (`text`). Each speaker has a form of address (`bà`, `cô`, `chú`, `bác`, ...) for "Dạ, cô nói lại được không ạ?" and an optional `call_after` line.
- **People and places** (`data/spots.json`). A spot has `lens` rules (descriptions by time). A person has `lines` rules (the first line of a talk by time), an optional `intro` (the line of the first talk, before the line for the time), and optional `chat` (a talk between neighbors: `lines` is a list of chats, each one time each day, in order) or `calls` (a seller who calls out).
- **Messages** (`data/messages.json`): the texts of cô Nga, by time (`at`, `before`, `day`) or by event (`start`, `wake`, `heard:LINE`, `lens:LINE`).
- **Voices** (`data/voices.json`): the VieNeu-TTS preset voice of each speaker and the neutral phone voice. `tools/voices/build.py` makes `assets/voices/CLIP.ogg` (mono, 48 kHz, −16 LUFS, no silence at the ends) and `assets/voices/manifest.json`. A clip is a spoken line, a phrasebook phrase (`reply.LINE.REPLY`), or the "say again" phrase (`say_again.SPEAKER`). The hash of each clip is from the text that the voice reads, the voice, and the model version. `Content` checks at start that each clip has a file with the correct hash (R4). After a change of the dialogue or the voices, run the build (or the voices workflow).
- **Voices workflow** (`.github/workflows/voices.yml`): by hand, or on a push to `main` that changes `data/dialogue/` or `data/voices.json`. It makes the voice files and the audition page (`docs/voices/`), commits them with the message "Update the voices", and starts the export workflow, which publishes the audition page at `/voices/` on GitHub Pages.
- **Sounds** (`data/sounds.json`): the captions of the sounds that are not speech, such as "[lóc cóc]".
- **The phone** (`scenes/ui/phone/`): Listen (transcript and phrasebook), Lens (camera view and the card of the place in the frame), Messages, Sổ tay, Clock (rest and sleep), and Settings. The talk flow, the speech, and the data of each app are in `scenes/main.gd`. The subtitle split is `scripts/subtitle_text.gd`.

## 5b. Desktop, quality presets, and the house kit (plan 0004)

- **Renderers** (D2). `project.godot` sets Forward+ for desktop, Mobile for Android and iOS, and Compatibility for the web. The Godot documentation ([Overview of renderers](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)) says that the Mobile renderer does not have these Forward+ features: SSAO, SSIL, SDFGI, VoxelGI, volumetric fog, screen-space reflections, and FSR 2. Glow and MSAA work in both.
- **Quality presets** (D3, R4, `scripts/quality.gd`). Low (sun shadow 25 m, hard shadows, render scale 0.75, no SSAO, SSIL, SDFGI, or fog), Medium (50 m, SSAO), High (80 m, SSAO, SSIL, SDFGI), Ultra (High plus volumetric fog, 120 m). All presets use Forward+ on a computer (D-0004-07). Android and iOS use the Mobile renderer, and the web build uses Compatibility, with each preset. The first start selects Low without a graphics card (lavapipe), Medium with a graphics chip in the processor, and High with a separate graphics card. Godot selects the renderer when it starts, and a settings file in `user://` cannot change it (verified). So no preset uses another renderer than the others on the same platform, and a change of preset never starts the game again. The play-test argument `--quality=NAME` sets the preset, and a phase line with `--renderer=forward_plus` runs that phase on Forward+.
- **Light by time** (`scripts/day_light.gd`, D-0004-04). The SDFGI energy, the ambient color and energy, the sky colors, and the moon light change with the time. SDFGI (High, Ultra) does not use the ambient light: there, the SDFGI energy and the sky (also its lower half, which is not visible) give the indirect light. A high SDFGI energy makes the open roofs and the sand almost white. The lights of the places and the street lamps have a short range, so that they make pools of light at night (`Hem.SHOP_LIGHT_RANGE`).
- **Sun shadows** (R5): on, on all presets, with the shadow distance of the preset. The web build (Compatibility) keeps them off: see the result in section 5.
- **Desktop controls** (D4, R2, R3, `scenes/desktop_controls.gd`). A click of a real mouse on the world captures the cursor. Then the mouse turns the view and a click acts. W, A, S, D move. E acts. Tab raises and lowers the phone. Esc shows the home screen of the phone (the menu). With the phone up, the cursor is free, W, A, S, D still move, and a right click lowers the phone. A gamepad: left stick to move, right stick to look, A to act, Y for the phone. With the phone up, the D-pad selects a button, A presses it, and B goes back. Touches make emulated mouse events, and the desktop controls do not read them.
- **The house kit** (R7 to R13, `scenes/world/parts/`, `scenes/world/tube_house.gd`). A house is built from parameters and a seed: the kind (tube house, villa, mini-hotel), the style (old or new), the paint, the paint age, the roof (flat terrace, corrugated metal, terracotta tiles), and the front tiles. `data/world/palette.json` has the colors. `plaster.gdshader` makes the paint, the rain streaks, the damp, and the patches of brick. Each house has one plaster mesh and a few vertex-colored meshes (`scripts/mesh_batch.gd`), and its values are instance uniforms. The rail bars, the balusters, the pots, and the AC units are MultiMeshes for each 15 m of the hẻm (`house_parts.gd`), with a visibility range of 70 m. A tube house has a back extension or a small yard, and a flat terrace can have a small room or a metal roof on posts (D-0004-08). A second random generator (`_plan_shape()`) makes this plan, so a change there does not change the other parts of a house. The metal sheets use only the colored clusters of `metal_roofs`, and the flat terraces use `terraces` (D-0004-03). About 30 % of the walls are bold (D-0004-09).
- **Budget** (R14, PT-32, measured under lavapipe at 1280 × 720, at the fixed views "along", "back", and "roofs", after the corrections of report 0004): with the occluders: Low 357 to 465 draw calls and 130 000 to 145 000 triangles (limit 600 and 300 000). Medium 465 to 614 draw calls and 163 000 to 171 000 triangles. High 488 to 891 draw calls and 179 000 to 269 000 triangles (limit 2 000 and 2 000 000). Ultra 492 to 966 draw calls and 178 000 to 292 000 triangles. The roof view has the most parts, because it sees over the occluders.
- **Desktop builds** (R6): the export workflow makes Windows, macOS (universal), and Linux builds, not signed. `docs/release-notes.md` says what macOS and Windows show at the first start.

## 5c. The geodata and the Vũng Tàu world (plan 0005)

- **Pipeline.** `tools/geo/fetch.py` (CI only, the "Geodata" workflow) downloads the OSM extract, the Copernicus DEM, and the ground textures to `data/geo/raw/`. `tools/geo/tide.py` (CI only) computes the tide constants of EOT20 and the dry times of the Hòn Bà rock path. `tools/geo/build.py` (CI and workspace, about 2 minutes) reads `data/geo/raw/` and the configuration files of `data/geo/` and writes `data/geo/build/`: the height chunks (16-bit PNG), the surface mask and the rock mask, the roads, the blocks, the landmarks and the town anchors, the homestay hẻm, the roadworks, the sea objects, the trees, and `report.md`.
- **Configuration** (`data/geo/`, data that I can edit): `area.json` (the box), `landmarks.json` (R1), `road_widths.json`, `overrides.json` (corrections to OSM, the band of rocks of the Hòn Bà path, and the roadworks), `hon_ba.json` (the heights of the path), `sea_objects.json` (ships and boats), and `trees.json` (the street and park trees).
- **The world** (`scenes/world/vung_tau.gd`): chunks of 256 m that load around the player, the sea with the tide, the sun and the sky by the real date and time, the markers, the street trees (`street_trees.gd`, `tree_kit.gd`), the sea objects (`sea_objects.gd`), and the roadworks (`roadworks.gd`). The plants follow the season of the game date (`scripts/season.gd`).

A play test in the Vũng Tàu world has `--world=vung_tau` in its phase line. `start_at()` and `fly_to()` are setup steps that put the player or the camera at a point. `set_time_scale()` plays the game faster for a long walk; a check of a time must then use the game time.

The audio driver prints ALSA errors in the workspace. These errors are not defects.

## 6. Repository map

| Path | Content |
|---|---|
| `AGENTS.md` | This file. |
| `CONTRIBUTING.md` | Writing rules and commit rules. |
| `docs/plans/` | Plans. `README.md` there lists all plans and their status. |
| `docs/playtests/` | Play-test reports from the architect. |
| `docs/content/culture-notes.md` | What we know about the food and customs, with sources and check status. |
| `docs/content/reference/houses.md` | Links to public photos for each part of the house kit (plan 0004, R12). |
| `docs/release-notes.md` | Notes for the desktop builds. |
| `docs/prototype/hem-2d.html` | The first 2D prototype. Use it as a reference for content and flow only. Do not copy its look. |
| `docs/prototype/people/` | The people prototype of plan 0006 (Blender and MPFB 2): the approved target look, the values of each person, and how to make clothes by code. |
| `project.godot`, `export_presets.cfg` | The Godot project and the export presets (Web, Android, iOS, Linux, Windows, macOS). |
| `autoload/` | `Content` (reads and checks `data/`), `GameState` (clock, notebook, save), `Playtest` (active only with `--playtest=NAME`). |
| `data/` | All content: cards, spots and opening hours, people, dialogue, messages, voices, sound captions, the hẻm layout, the house palette, UI text, credits, the calendar. |
| `data/geo/` | Plan 0005: the play area, the landmarks, the road widths, the OSM corrections and the roadworks (`overrides.json`), the Hòn Bà path (`hon_ba.json`), the sea objects, the trees, the raw extracts (`raw/`, with `manifest.json`), and the game data that `tools/geo/build.py` and `tools/geo/tide.py` make (`build/`, with `report.md`, `tide_report.md`, `anchors.png`, and `homestay_area.png`). ODbL, see `LICENSE` there. |
| `scenes/` | `main.tscn` (world, input, talk, and UI), `world/` (hẻm, house, beach, `parts/`: the house kit, its shaders, and the palette, and `vung_tau.tscn`, the real ground of plan 0005, with its trees, sea objects, and roadworks), `actors/` (first-person player, NPC with a voice), `ui/` (phone and its apps, subtitles, joystick, center dot), `desktop_controls.gd` (mouse, keys, gamepad). |
| `scripts/` | Classes with no scene: clock math, save format, content checks, voice clips, subtitle split, light by time, greybox shapes, mesh batches, quality presets, sounds, UI theme, play-test driver, the lunar calendar, the game calendar, the seasons. `geo/`: the projection, the geodata reader, the 16-bit PNG reader, the sun position, the tide model, and the ground and road mesh builders. |
| `shaders/` | The ground shader, the sea shader, and the tree shader of the Vũng Tàu world. |
| `tests/unit/` | GUT unit tests. |
| `playtests/` | Play-test scenarios PT-01, PT-03 to PT-17, PT-18 to PT-24 of plan 0003, PT-25 to PT-32 of plan 0004, and PT-33 to PT-39 of plan 0005 (PT-02 and PT-07 were removed in plan 0002). |
| `tools/` | `setup.sh`, `test.sh`, `playtest.sh`, `voices/` (the voice build and its tests), and `geo/` (the geodata pipeline: `fetch.py`, `build.py`, `tide.py`, the `geodata` package, and its tests). |
| `assets/` | Fonts, icons, voices, and `CREDITS.md`. |
| `docs/voices/` | The voice audition page (made by the voices workflow). |
| `.github/workflows/` | `test.yml` (tests on each push), `export.yml` (web, desktop, Android, iOS builds, and GitHub Pages), `voices.yml` (the voice files), `geodata.yml` (download and build the geodata, by hand), and `people-packs.yml` (copies the MakeHuman asset packs to the release `people-packs-1`, by hand only). |

Plan 0001 adds the Godot project structure. See that plan.

## 7. Content status

`docs/content/culture-notes.md` has all known facts. Each fact has a status:

- **Confirmed**: I know it first-hand. It is correct for Vũng Tàu and the South.
- **Source**: a published source says it. I did not confirm it yet.
- **Check**: we are not sure. Do not put it in the game without my approval.

Facts about Northern customs need a reviewer from the North. I know Southern customs.
