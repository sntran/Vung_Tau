# AGENTS.md

Read this file before you change the repository.
Then read `CONTRIBUTING.md` and the active plan in `docs/plans/`.

## 1. The project

The name of the project is "Vũng Tàu". Always write the name with the diacritics.
The repository name is `Vung_Tau` because GitHub names cannot have diacritics. Use "Vũng Tàu" in all other places: documents, the Godot project name, the app name, and the game text.

Vũng Tàu is a 3D game about Vietnamese food and daily life. The player is a traveler from the United States who visits Vũng Tàu today.

- **Audience:** adults who are not Vietnamese. They know phở from restaurants abroad. They do not know how people eat it in Vietnam.
- **Goal:** the player learns how people in Vietnam really eat, order, and live around food. The player does not learn recipes.
- **Setting:** Vũng Tàu today, with its real geography. The player stays at a family homestay in a small hẻm (alley) at the foot of Núi Nhỏ, near Bãi Trước (Front Beach).
- **Platforms:** Android and iPhone apps. A web build is for quick review.
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
| Renderer | Compatibility (OpenGL 3 / OpenGL ES 3 / WebGL 2) | It renders in a headless Linux workspace with Mesa llvmpipe. The play tests can take screenshots. It also runs on older phones and in web browsers. |
| Unit tests | GUT 9.7.1, kept in `addons/gut/` | Standard test addon for Godot 4. |
| Play tests | Scenario scripts in `playtests/`, run by `tools/playtest.sh` under Xvfb | See plan 0001. |
| Text language | English with Vietnamese terms | The audience reads English. |
| Font | Be Vietnam Pro (SIL Open Font License) | Full Vietnamese diacritics. |
| CI | GitHub Actions | The repository is public, so CI is free. |
| Android build | GitHub Actions, Ubuntu runner | The Android SDK cannot download in the development workspace. |
| iOS build | GitHub Actions, macOS runner with Xcode | An iOS build always needs macOS and Xcode. Signed builds need a paid Apple Developer account. |

Verified in the development workspace (Linux, 2 CPUs, no GPU, no Vulkan):

- Godot 4.7.2 renders a 3D scene with shadows under `xvfb-run` with `--rendering-driver opengl3`. It saves a PNG screenshot.
- `Input.parse_input_event()` with an `InputEventScreenTouch` presses a `Button`. Touch-to-mouse emulation is on by default.
- GUT 9.7.1 runs with `godot --headless -s addons/gut/gut_cmdln.gd`.
- GitHub, npm, and PyPI are reachable. Google downloads (Android SDK, Maven) and blender.org are not reachable.
- GitHub archive downloads (`github.com/OWNER/REPO/archive/...`) return 403 in the workspace. `git clone` works. So `tools/setup.sh` gets GUT with `git clone`. GitHub release downloads (Godot, the export templates) work.
- `Camera3D.project_ray_normal()` does not use the frustum offset. The camera uses a frustum offset, so `CameraRig.screen_ray()` calculates the ray. `Camera3D.unproject_position()` is correct.
- The workspace prints "WARNING: Could not set V-Sync mode" at each start. This warning comes from the Mesa driver. It is not a defect.
- With `--audio-driver Dummy`, Godot prints no ALSA errors. `tools/playtest.sh` and `tools/test.sh` use it.
- Godot 4.7 has the `Logger` class (`OS.add_logger()`). The play-test system uses it to record each engine error and script error as a failure in `log.json`.
- The renderer is slow under llvmpipe: about 20 frames per second at 720×1280 and 10 at 1080×2400. MSAA halves these numbers, so it is off.
- An Xvfb screen of 1280×720 is too small for a 1080×2400 window. `tools/playtest.sh` uses `-screen 0 2560x2560x24`.
- Godot exports the iOS Xcode project on Linux. Only the build of an `.ipa` needs macOS.
- With the sun shadow on, the Compatibility renderer under llvmpipe makes up-facing surfaces about three times too bright when the sun is high. The sun has no shadow until plan 0002 checks it on phones.
- The web export (thread support off) starts in the pre-installed Chromium with WebGL 2.

Commands that work:

```sh
# Import the project (do this once after a clone, and after you add assets)
godot --headless --path . --import

# Unit tests
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit

# Run the game with a picture, without a screen
xvfb-run -a -s "-screen 0 2560x2560x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 720x1280 -- --playtest=boot_intro

# The project scripts (they do the commands above)
tools/setup.sh               # Godot 4.7.2 in .tools/godot/, GUT in addons/gut/
tools/setup.sh --templates   # also the export templates
tools/test.sh                # all unit tests
tools/playtest.sh walk_hem   # one play test at 720x1280
tools/playtest.sh walk_hem --size=1080x2400
tools/playtest.sh --all      # all play tests at all sizes (about 20 minutes)

# Exports (they need the export templates)
godot --headless --path . --export-release "Web" build/web/index.html
godot --headless --path . --export-debug "iOS" build/ios/VungTau.ipa   # Xcode project only on Linux
```

A play-test scenario is `playtests/NAME.gd`. It extends `RefCounted` and has `func run(d: PlaytestDriver) -> void`. The header lines `# phase: ARGS` and `# sizes: WxH ...` tell `tools/playtest.sh` how to run it. See `scripts/playtest_driver.gd` for the API.

The audio driver prints ALSA errors in the workspace. These errors are not defects.

## 6. Repository map

| Path | Content |
|---|---|
| `AGENTS.md` | This file. |
| `CONTRIBUTING.md` | Writing rules and commit rules. |
| `docs/plans/` | Plans. `README.md` there lists all plans and their status. |
| `docs/playtests/` | Play-test reports from the architect. |
| `docs/content/culture-notes.md` | What we know about the food and customs, with sources and check status. |
| `docs/prototype/hem-2d.html` | The first 2D prototype. Use it as a reference for content and flow only. Do not copy its look. |
| `project.godot`, `export_presets.cfg` | The Godot project and the export presets (Web, Android, iOS). |
| `autoload/` | `Content` (reads and checks `data/`), `GameState` (clock, notebook, save), `Playtest` (active only with `--playtest=NAME`). |
| `data/` | All content: cards, spots and opening hours, dialogue, the hẻm layout, UI text. |
| `scenes/` | `main.tscn` (world and UI), `world/` (hẻm, tube house, beach, camera), `actors/` (player, NPC), `ui/` (top bar, talk panel, sheets, toast). |
| `scripts/` | Classes with no scene: clock math, save format, content checks, light by time, greybox shapes, sounds, UI theme, play-test driver. |
| `tests/unit/` | GUT unit tests. |
| `playtests/` | Play-test scenarios PT-01 to PT-10. |
| `tools/` | `setup.sh`, `test.sh`, `playtest.sh`. |
| `assets/` | Fonts, icons, and `CREDITS.md`. |
| `.github/workflows/` | `test.yml` (tests on each push) and `export.yml` (web, Android, iOS builds). |

Plan 0001 adds the Godot project structure. See that plan.

## 7. Content status

`docs/content/culture-notes.md` has all known facts. Each fact has a status:

- **Confirmed**: I know it first-hand. It is correct for Vũng Tàu and the South.
- **Source**: a published source says it. I did not confirm it yet.
- **Check**: we are not sure. Do not put it in the game without my approval.

Facts about Northern customs need a reviewer from the North. I know Southern customs.
