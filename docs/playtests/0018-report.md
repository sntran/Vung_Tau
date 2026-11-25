# Report 0018: The scooter, part 1

| Field | Value |
|---|---|
| Plan | [0018 The scooter, part 1](../plans/0018-scooter.md) |
| Branch | `feat/0018-scooter` at commit `f8e1cce` ("Set plan 0018 to Built") |
| Date | 2026-11-23 |
| Scope | All of part 1: R1 to R11 (the real clock, the touch controls, and the ride). |

The pictures of this report are in [`0018/audit-2026-11-23/`](0018/audit-2026-11-23/).

## 1. Runs

| Check | Result |
|---|---|
| CI of `f8e1cce` | Pass: Test (run 409, 12 parts) and Export (run 216). |
| Unit tests (`tools/test.sh`) | Pass: 147 tests, 4 114 asserts. |
| PT-80 `scooter_ride`, 1280 × 720, Mobile renderer | Pass (356 s). Run 1: 689 m from the start of Bãi Trước along Quang Trung and Hạ Long, 39.5 km/h at the top. On the seat at the start (Low): 303 draw calls, 276 065 triangles. R9: 311 frames, median 290 ms, the longest 1 620 ms, 4 frames longer than three times the median. |
| PT-81 `touch_controls` | Pass at 2400 × 1080 (192 s) and 720 × 1280 (94 s) on the Mobile renderer at Bãi Trước, and at 1280 × 720 (69 s) on the Compatibility renderer in the test street. |
| My scenario (not in the repository) | Section 2 and section 3: the clock over 20 s and after a stall of 15 s, the throttle to the top speed, a full turn at the top speed, get off, the keys, and a slow ride over the curb of PT-80. |
| The web build of the branch | Not checked: the workspace cannot reach `workers.dev`. |

## 2. What is correct

- **The clock (D6, R1).** 20 s of game time moved the clock 20.0 s to 20.3 s. A stall of 15 s of the main thread (no frames) moved the clock 0.52 s, and the next 40 frames moved it as much as 40 frames with no stall (10.67 s each): Godot does not give the lost time to the frames after a stall. A hidden browser tab also gives no frames, so I expect the same there. My ride on the web build checks it (acceptance 2).
- **The motion (D2).** The full throttle from a stop gave 39.6 km/h after 9 s. PT-80 checks 0 to 20 km/h and the brake of 4 m/s² in physics steps, also at 3 frames each second (`PLAYTEST_MAX_FPS=3`, builder notes).
- **Get on and get off (D1, D9, R4).** The center dot shows "Lên xe · Ride" at a parked scooter. The action button gets the player on. At a stop "Xuống xe · Get off" puts the player at the left side, and the scooter stays upright on its stand. The player can walk away, come back, and ride it again (PT-80 run 2).
- **The wall (D5).** On the walk of Hạ Long, the scooter stops at the parapet with one bump and no error.
- **The start scooters and `--ride` (R8).** A scooter stands within 10 m of the start of Bãi Trước, along the road, and `--ride` starts the game on it.
- **The view (D3, R6).** The grips and the front of the scooter show at the bottom of the view at 1280 × 720 (`ride_pitch()`), and the view leans into a turn (8° at most).
- **The touch controls (D7, R3).** After a touch the joystick shows at its rest place, light, at each size, and a drag walks. On the scooter a drag up rides, down brakes, and to the right turns. After a click of the mouse the joystick goes away, and after a touch it comes back. At 720 × 1280 the view on the seat shows the road in the upper half and the front of the scooter in the lower half: the camera keeps the horizontal field of view, and a rider who looks down sees the same.
- **The code** follows the plan: one motion model in each physics step (`ScooterMotion`), a capsule along the scooter, the curb step of 20 cm over the floor, the stair test, the drop test, and the sand test.
- **The sounds (R7)** are made in code, because the libraries of free recordings need an account. The pitch follows the speed, and each sound has its caption. A recording can come later (section 6, Q2).

## 3. Defects

### D-0018-01: The scooter sticks on a curb at a low speed (medium)

At the curb of PT-80 (Quang Trung at x 99.5 m, z 60 m, to the west), I rode at half throttle. In 5 pushes of 1 s, the scooter bumped 5 times ("[cộp]") and did not ride on. Its height changed between +0.01 m and +0.25 m over the road, so it stays across the curb. Nothing shows in front of it (`curb_stuck.jpg`). The surface mask has no sand there (R = 0), so the sand test does not stop it.

At about 34 km/h, in my turn of section 4, the scooter went up the curb of the park with no bump. A rider goes up a curb slowly, to park on a sidewalk, so the slow case is the one that matters.

PT-80 run 2 does not find this. It checks the height of the scooter at one moment ("0.20 m over the road"), and then puts the rider at the wall with a setup step. Its screenshot `103-over_the_curb.png` shows no handlebars, because `start_at()` sets the pitch of the view to 0.

The correction: the scooter rides up a curb of 15 cm at each speed from 2 km/h to 40 km/h, and rides on. A play-test step rides up the curb at 3 km/h and at 20 km/h, and then 5 m on along the sidewalk with no bump.

### D-0018-02: "Xuống xe · Get off" covers the road in the middle of the view during the whole ride (medium)

While the player rides, the button stays at the place of the action button: in the middle of the screen, over the road 5 m to 10 m in front of the scooter (`get_off_button.jpg`). An obstacle or a turn appears there first. D7 says that the button takes the place of the action button, but the button of a walk shows only when the player looks at a thing. On the scooter it shows all the time.

The correction: while the scooter moves, the button is not in the middle third of the view. For example, it goes to the right side, over the phone button, or it shows only under 2 km/h. A tap at a speed still gives "Slow down to get off." R3 still holds at 1280 × 720, 2400 × 1080, and 720 × 1280. PT-81 checks the place of the button at each size.

### D-0018-03: With `--ride`, the ride starts before the showcase is built (low)

With `--ride` (and `?ride` on the web), the player sits on the scooter at the first frame. At that moment the sidewalk of Quang Trung, the median, and the plants of the park of Bãi Trước are not there yet. They come some seconds later, while the player can already ride at 40 km/h (`ride_start.jpg`: left, the start with `--ride`; right, the same place after the walk of 37 s of PT-80 run 1). R9 asks that the showcase is ready before the player sees it.

The correction: with `--ride`, the scooter does not move until the showcase near the start is built (`prepare_at()` builds it at once), or the world builds it before the first frame. PT-80 run 2 takes its first screenshot before the first push.

### D-0018-04: No play test does some paths of the ride (low)

The play-test standard (AGENTS.md, section 3) asks for each path that a player can do. These paths have no step:

- "Get off" at a speed of more than 2 km/h (D9): the scooter does not stop, and the caption says "Slow down to get off."
- A ride into the sand, into the water, and down stairs (D5). PT-80 checks only that its route does not go there.
- The screenshot of the turn of PT-80 (`004-turn_lean.png`) is taken after the stick is let go: its step says "lean 1.5°, steer 0.0°". The plan asks for a screenshot of a turn with the lean. Take it while the stick holds the turn.

## 4. My error in plan 0018: the turn at speed (D4)

D4 gives the turn of the handlebars from 35° when slow to 8° at the top speed. With the turn radius from the wheelbase (1.255 m), 8° at 40 km/h is a radius of 8.9 m, and a side acceleration of 13.8 m/s² (1.4 g). That is two times what riders reach on a race track: the highest side acceleration of seven riders on a closed track had a mean of 7.05 m/s² (0.72 g) ([a study of the University of Pisa](https://arpi.unipi.it/retrieve/74471326-31be-403c-be6c-e9c6638e53d6/motorcycle%20riders.pdf)). In my scenario, the full stick to the right for 0.6 s at 34 km/h to 40 km/h turned the scooter by 95°, off the road and into the park (`turn_at_speed.jpg`). The handlebars turned to 11.6° at about 34 km/h: a radius of 6.1 m, and about 1.5 g. With a joystick on a touch screen, a small move of the thumb gives a large turn at speed.

| Speed | The turn now | Radius | Side acceleration | With a limit of 3.5 m/s²: turn | Radius |
|---|---|---|---|---|---|
| 10 km/h | 28.2° | 2.3 m | 3.3 m/s² (0.34 g) | 29.7° | 2.2 m |
| 20 km/h | 21.5° | 3.2 m | 9.7 m/s² (0.99 g) | 8.1° | 8.8 m |
| 30 km/h | 14.7° | 4.8 m | 14.6 m/s² (1.49 g) | 3.6° | 19.8 m |
| 40 km/h | 8.0° | 8.9 m | 13.8 m/s² (1.41 g) | 2.0° | 35.3 m |

**The change that I propose (it needs my approval):** D4: "the turn of the handlebars is at most 35°, and at most the turn that gives a side acceleration of 3.5 m/s² (about 0.35 g) at the speed now: about 30° at 10 km/h, 8° at 20 km/h, and 2° at 40 km/h". A street corner (a radius of about 9 m) then needs a speed of 20 km/h or less, as on a real moped. A unit test checks the side acceleration at 5, 10, 20, 30, and 40 km/h. PT-80 already slows to 20 km/h for its turn.

## 5. Notes

- **R9 (the stream at 40 km/h).** In this workspace (Low, 2 CPUs, no graphics card) the median frame was 290 ms, and the longest 1 620 ms. In CI (builder notes) the longest was 2 744 ms. These numbers come from software rendering, and they do not show what a phone or a computer gives. My limit for R9 comes from my ride on the web build (acceptance 2).
- **The ground over the road at Cầu Đá (plan 0009).** On Hạ Long near the junction at Cầu Đá, a band of light brown ground shows over the road on the sea side (PT-80, `005-turned_south.png`). It is not from the scooter. Plan 0009 looks at it with the roads of phase 3.
- **`ride_along()` keeps to the line of the road in the data**, so the test rider rides on the middle line of Hạ Long. That is correct for a test. A player rides on the right side.
- **The joystick and the stick of the test.** On the screen, up is −y: `hold_stick(Vector2(0, -1))` is the throttle and `Vector2(0, 1)` is the brake. A short comment at `hold_stick()` helps the next test writer.

## 6. Questions for me

- **Q1.** The change of D4 in section 4: yes or no?
  - **My answer (2026-11-23):** yes. Plan 0018 has the change (D4, R5).
- **Q2.** The sounds of the engine are tones made in code. Is that good for now, or do I want a recording (CC0 or CC BY) of a 50 cm³ moped? I can find candidates, and I download the file if the workspace cannot reach it.
- **Q3.** The limit of R9: after my ride on the web build.

## 7. Audit 2 (2026-11-25)

The branch at `e288998` (the corrections `c660919` to `bf5c096`). The pictures are in [`0018/audit-2026-11-25/`](0018/audit-2026-11-25/).

### 7.1 Runs

| Check | Result |
|---|---|
| CI of `e288998` | Pass: Test (run 416) and Export (run 223). |
| Unit tests | Pass: 148 tests, 4 744 asserts. |
| PT-80 `scooter_ride`, 1280 × 720 | Pass, in its four runs. R9 in the workspace: 330 frames, median 290 ms, the longest 1 667 ms, 1 long frame. |
| PT-81 `touch_controls` | Pass at 1280 × 720 (67 s), 2400 × 1080 (199 s), and 720 × 1280 (105 s). |
| My scenarios (not in the repository) | Section 7.2. |
| The web build of the branch | Not checked: the workspace cannot reach `workers.dev`. |

### 7.2 The defects

| Defect | Result | What I did |
|---|---|---|
| D-0018-01, the curb at a low speed | Corrected | PT-80 run 3 rides up the curb at 2.4 km/h and at 19.6 km/h, then 12 m to 14 m on the sidewalk with no bump, and the handlebars are in the view. In my ride, in pushes of 0.3 s (1.6 km/h to 1.7 km/h at most), the scooter went up the curb at z 60 m and at z 35 m and 8 m on, with no bump. It went up at an angle of 30° to the curb, and it went up and down again at 3.6 km/h, with no bump. |
| D-0018-02, the place of "Get off" | Corrected | The button is at the right, above the phone button, at 1280 × 720, 2400 × 1080, and 720 × 1280. The road ahead is free (`corrections.jpg`). The middle third of the width and of the height, as the builder read it, is what I meant. |
| D-0018-03, `--ride` before the showcase | Corrected | A push of 2 s at the first frames moved the scooter 0.00 m. The hold ended 15.5 s after the first frames, and then the scooter rode. |
| D-0018-04, the paths with no step | Corrected | PT-80 run 4: "Get off" at a speed, the sand, the steps of an opening, and the lake each stop the scooter with the bump before the front wheel is there. The screenshot of the turn shows the stick held and the lean. |
| D4 and R5 (changed) | Done | In my ride at 39 km/h, a turn of the stick of 0.7 for 1 s turned the scooter by 17.7°, with a side acceleration of 2.50 m/s² at most (0.7 of 3.5 m/s²) and the handlebars at 1.7°. In audit 1 the full stick for 0.6 s turned it by 95°. |

### 7.3 Notes

- **The screenshot `get_off_at_speed` of PT-81 at 2400 × 1080 and 720 × 1280 shows no caption.** The check of the text passes, but at these sizes in the workspace the caption (1.6 s) is gone before the screenshot. The caption does show on the screen at both sizes: my screenshot one frame after the tap has it (`slow_down_caption.jpg`). Take the screenshot in the first frame after the tap. This does not block the plan.
- **A hit at a speed stops the scooter at once (D5).** In my ride the scooter went into the end of the median of Quang Trung at about 39 km/h and stood, with the bump. That is the rule of part 1.
- **The wait at the start.** With `?ride` the scooter stands for about 15 s to 18 s in the workspace until the showcase is built, and the caption "The street is not ready yet. Wait a moment." shows at each push. On a slow phone the wait can be longer. I look at it in my ride.
- **The ground over the road** (section 5) shows again in the pictures of PT-81 at Quang Trung. It stays with plan 0009.

### 7.4 What is open

- **My ride on the web build** (acceptance 2): https://feat-0018-scooter-vung-tau.fifo.workers.dev/?start=bai_truoc&ride
- Q2 (the sounds) and Q3 (the limit of R9) of section 6.
- The words of the new caption `scooter_wait` in `data/ui.json`: "The street is not ready yet. Wait a moment."

## 8. My ride on the web build (2026-11-25)

I rode the web build of `bf5c096` at `?start=bai_truoc&ride`. Acceptance 2 does not pass yet.

| What I found | What follows |
|---|---|
| The turn was hard to make. I did not find how to slow down. | The brake is the stick down, and nothing on the screen says so. A scooter with no throttle slows at 0.4 m/s² (28 s from the top speed to a stop), and at 40 km/h the limit of D4 gives a curve of 35 m. Plan 0018 has the proposed changes D10 (the stick gives the speed, and the engine slows the scooter), D11 (a stick held hard to a side makes the turn tight), and D12 (a hint on the first rides). |
| The loading screen of Godot took about one minute, and then I could not ride, because the world was not ready. | Plan 0031 (Draft): the web build loads in steps. |
| I did not know the roads, and I did not know where I was. | The roads are those of OpenStreetMap. Out of the showcase, the town is boxes with no fronts and no signs; only Trương Công Định has houses. Plan 0018 has the proposed change D13 (the name of the road on the screen). The app Maps of plan 0030 (approved) shows where the player is. The houses of phase 3 of plan 0009 make a street look as I know it. |

## 9. Status

The builder corrected D-0018-01 to D-0018-04 and made the change of D4. Plan 0018 stays Built: after my ride, the changes D10 to D13 wait for my approval. After the builder makes them, I ride again (acceptance 2).
