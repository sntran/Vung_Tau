# Play-test report: plan 0004, Desktop and the house detail kit

## 1. Commit

`a546611` on `main`. The game code is the same as `53fbace` ("Set plan 0004 to Built").

## 2. What the architect ran

| Run | Result |
|---|---|
| Unit tests (`tools/test.sh`): 8 scripts, 76 tests, 649 asserts | All pass |
| PT-25 `look_review` (Forward+ High and Mobile Low, 07:00, 12:00, 17:30, 20:00) | Pass. See the look defects D-0004-03, D-0004-04, D-0004-06. |
| PT-26 `desktop_controls`, PT-27 `gamepad`, PT-28 `quality_presets`, PT-29 `shutters`, PT-30 `window_sizes`, PT-31 `house_seeds`, PT-32 `budget` at 1280×720 | All pass |
| PT-01 `fp_walk`, `fp_tap_walk`, `fp_collision`, `fp_focus` in the narrower hẻm (R11a) at 1280×720 | All pass |
| PT-23 `walk_away` and PT-20 `reply_modes` at 2400×1080 | `walk_away` fails 2 times of 2 (D-0004-01). `reply_modes` passes. |
| Desktop exports from a fresh clone with the commands of `export.yml` | Windows, macOS, and Linux: exit 0, files made |
| CI on `main` since `53fbace` | "Test" fails on each run (D-0004-01). "Export" fails on each run in the job "Desktop builds" (D-0004-02). |
| Probes of the architect (not play tests): views from above the hẻm, and the distance to each person in a talk | D-0004-03, D-0004-05 |

## 3. Defects

### D-0004-01: The play tests fail in CI on each run, and the hẻm is blocked at 2400×1080 (high)

![walk_away at 2400×1080](0004/d01-blocked.jpg)

- **Evidence:** On `main`, the "Test" workflow failed for `53fbace`, `0017e0e`, `9208d0a`, and `a546611`. "Play tests (part 4 of 6)" fails on each run, and part 3 on three of four. The status of plan 0004 is "Built", but step 4 of the workflow in `AGENTS.md` says that all play tests must pass first.
- **One cause that the architect found:** PT-23 `walk_away` at 2400×1080 fails 2 times of 2 in the workspace, alone on the computer: "the talk ends at 6 m: 1.87 m" and "Cô Sáu calls after the player". The player walks east from Phở Cô Sáu with the joystick and stops near the bánh mì cart. In the 2.8 m hẻm (R11a), the cart and the people at it fill the width. The scenario passes at 1280×720.
- **Expected:** All play tests pass in CI before "Built". A player can always walk the length of the hẻm at every time of day.
- **Correction:** Read the logs of parts 3 and 4 (the architect's workspace cannot download CI logs). Keep a free path of at least 0.9 m (the player capsule and a margin) along the hẻm at all times: move the cart customers, or let the player pass between people. Add a play-test step that walks the full hẻm at 06:00, 07:00, 12:00, 18:00, and 20:30 at both sizes.

### D-0004-02: The desktop builds fail in CI (high)

- **Evidence:** The job "Desktop builds" of the "Export" workflow fails in the step "Export the Windows, macOS, and Linux builds" on each run since `53fbace`, about 20 s after the start of the step. No desktop build was uploaded yet. The same commands from a fresh clone in the architect's workspace give exit 0 and the three files.
- **Expected:** R6: CI uploads the Windows, macOS, and Linux builds. Acceptance criterion 3 needs them.
- **Correction:** Read the log of the step. Check the cache of the export templates: the key `godot-templates-…` is the same for the jobs that use only the web or the Android templates.

### D-0004-03: The roofs do not look like a dense hẻm of Vũng Tàu (medium)

![The hẻm from above](0004/d03-roofs.jpg)

- **Expected:** R7 and R10c: in a dense hẻm, most roofs are corrugated metal in faded mint or teal, rust, orange or tan, and some red. Rust shows in streaks along the ridges. Flat terraces have tanks, solar water heaters, laundry, plants, and rebar. I compared the game with the top-down photo of a dense hẻm that I chose for R10c (the photo is not in the repository).
- **Actual:**
  - The metal roofs use grey, beige, and dark grey. There is no mint or teal roof. Rust streaks do not show from above.
  - The flat terraces are white and almost empty.
  - All houses have the same depth and a flat back, and the roofs are at a few heights only. In the photo, houses have back extensions, roofs at many heights, small rooms on the terraces, and metal roofs over parts of terraces.
- **Cause:** The grey and white clusters of R10c (43%) are mostly concrete terraces and walls, not metal sheets. `metal_roofs` in `palette.json` uses them for the metal sheets.
- **Correction:** Metal sheets get their colors from the mint and teal, rust, orange and tan, and red clusters only. Flat terraces take the grey and white share. More rooftop parts on the terraces (R7). Variation in depth, back extensions, and small rooms on terraces. Add a fixed view from above to PT-25.

### D-0004-04: The light is wrong at 17:30 and 20:00 on High (medium)

![12:00, 17:30, and 20:00 on High](0004/d04-light.jpg)

- **Actual:** At 17:30 the hẻm is almost black. At 20:00 it is brighter than at 17:30, and the walls are flat cream, like day light. At 12:00 the shade is blue and cold.
- **Expected:** The light follows the time: a warm, bright noon with hard shadows, a golden 17:30, and a dark 20:00 with pools of light under the lamps and from the shop fronts.
- **Correction:** Check the SDFGI energy of 4 (builder note N5) at night: it makes the lamps light the whole hẻm. Use a different energy or ambient light by time of day. Add PT-25 checks of the mean brightness of the lower half of the view: 20:00 must be darker than 17:30, and 17:30 darker than 12:00.

### D-0004-05: In a talk, the player stands too close to the person (medium)

![Talk with Cô Sáu](0004/d05-talk-close.jpg)

- **Measured:** In a talk, the eyes of the player are 0.77 m from the head of Cô Sáu, cô Nga, Bác Hà, and Cô Út (0.75 m on the ground). The face of the person fills the view.
- **Expected:** A normal distance for a talk: 1.0 m to 1.2 m. Plan 0006 adds real faces. At 0.75 m they will look too close and strange.
- **Cause:** Builder note N10: the people and the stand points moved with the narrower hẻm.
- **Correction:** A stand point at 1.0 m to 1.2 m from the person, along the hẻm if the width is too small. Add a check of the distance to PT-18.

### D-0004-06: The patches of fallen plaster are small spots all over the walls (low)

![Brick spots](0004/d06-brick-spots.jpg)

- **Actual:** Many small red patches at all heights, also high on the walls and on the parapets. From a distance they look like red spots.
- **Expected:** R8: patches mostly low on the wall and at the edges, fewer and larger. Most walls of new houses have none.
- **Correction:** Fewer, larger patches. Use the "low" and "edge" weights more strongly. New houses (paint age low) have no patch above the ground floor.

### D-0004-07: Low on a computer starts the game two times at each start (low, question for me)

- **Actual:** Builder note N1: the desktop build uses Forward+, and Low uses the Mobile renderer, so the game starts again at each start.
- **Proposal:** On a computer, Low uses Forward+ with all effects off. Then no restart is needed. The Mobile renderer stays for phones. This changes R4 of plan 0004, so I decide.

## 4. Audit of the requirements

| Req. | Result | Notes |
|---|---|---|
| R1 | Pass | Renderers set. PT-30 checks 16:9, 21:9, and 16:10. |
| R2, R3 | Pass | PT-26 and PT-27. Esc opens the phone home screen (Q6 is still open). |
| R4 | Pass | See D-0004-07. |
| R5 | Pass | Shadows on all presets. The web build keeps them off, with the reason in `AGENTS.md`. |
| R6 | Defect | D-0004-02. `docs/release-notes.md` exists. |
| R7 | Partly | All parts exist. See D-0004-03 for the roofs. |
| R8, R9 | Partly | See D-0004-06. |
| R10, R10a, R10b | Pass | `content_checker.gd` checks the palette rules. Q5 (the builder's bold and accent colors) is still open. |
| R10c | Defect | D-0004-03. |
| R11 | Pass | Concrete floor with cracks, patches, and the drain. |
| R11a | Defect | The hẻm is 2.8 m wide. Walking, tap to walk, and the phone pass at 1280×720. See D-0004-01 and D-0004-05. |
| R12 | Pass | `docs/content/reference/houses.md` has the links. I did not mark the parts yet. |
| R13, R14 | Pass | Measured: Low 359 to 477 draw calls, 132 664 to 149 778 triangles. High 481 to 874 draw calls, 183 292 to 277 168 triangles. |

### Acceptance criteria

| # | Result |
|---|---|
| 1 | Fail: D-0004-01. |
| 2 | Open: I look at the PT-25 screenshots. The architect's findings are D-0004-03, D-0004-04, and D-0004-06. |
| 3 | Blocked: D-0004-02. Also Q1 (which computer I use) is open. |
| 4 | Pass. |

## 5. Order of the corrections

1. D-0004-01 and D-0004-02 (CI must be green, and the desktop builds must exist).
2. D-0004-05 (plan 0006 needs it).
3. D-0004-03 and D-0004-04 (the look).
4. D-0004-06, then D-0004-07 after my decision.
