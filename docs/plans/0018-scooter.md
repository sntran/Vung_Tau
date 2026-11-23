# 0018 The scooter, part 1: ride, the real clock, and the controls on a touch screen

| Field | Value |
|---|---|
| Status | Approved (2026-11-23) |
| Branch | `feat/0018-scooter`, made from `feat/0009-houses-on-the-lots` (the rides need the town of plan 0009). It merges after plan 0009. |
| Depends on | 0002 (first-person walking), 0004 (the desktop controls), 0005 (the ground and the roads), 0009 (the town and the streets), 0023 (the scooter of World and the parked rows). |
| Changes | 0001 (R10: the clock), 0002 (the time cost of walking; the floating joystick), AGENTS.md section 5 ("View and controls"). |

## 1. Goal

The player can get on a scooter that is parked in the street, ride it through the town, and get off anywhere. The game clock runs at the speed of real time, so a slow ride along the coast at sunset takes the time that it took in real life. On a touch screen, the player sees the controls.

The scooter is first a tool to move fast: for me and for an agent that tests the town. The rules of real life come in later parts (section 2).

## 2. Out of scope

These come in later parts of this plan, each with its own approval:

- The player rents the scooter of the homestay from cô Nga, and rides only that scooter (it needs the homestay of plan 0009, R11).
- The helmet, and the reactions of people to a rider with no helmet.
- Paid parking (gửi xe) with a ticket at the market and at the beach.
- Fuel, a horn, and a passenger.
- Traffic: other scooters, cars, and buses that move on the streets (later in this plan, with lanes and junctions).
- A model of a 50 cm³ moped from World. Until World has one, the parked scooter of World (`scooter_tay_ga_1`) rides with the limits of a 50 cm³ moped (D2).

## 3. Decisions

| # | Decision | Why |
|---|---|---|
| D1 | For now, the player can ride any scooter that is parked in the street (my decision, 2026-11-23). The player gets on with the action button. When the player gets off, the scooter stays there on its stand, and anyone (the player too) can ride it again. Only one scooter moves at a time. | I need fast rides now, before the homestay. The rule of an owned or a rented scooter comes later. |
| D2 | The scooter is a 50 cm³ moped (xe gắn máy). Its top speed is 40 km/h; from 0 to 40 km/h it takes about 8 s; it brakes at about 4 m/s². | A 50 cm³ moped needs no licence in the law of 2008 (Điều 60), so a traveler of 2019 can ride it. Its design speed is at most 50 km/h (QCVN 41:2016), and its legal top speed is 40 km/h (Thông tư 91/2015). |
| D3 | First person on the seat: the eye is 1.45 m over the ground, the near level of the scooter shows its handlebars, mirrors, and the front, and the view leans into a turn (at most 8°). The player can turn the head (the look drag, the mouse, the right stick) up to 100° to each side; when the scooter moves, the head comes back to the front 1 s after the player lets go. | The fixed decision of first person (AGENTS.md, section 5) stays. |
| D4 | The motion is a simple model of a two-wheeler, not a physics vehicle: the speed, a turn radius from the turn of the handlebars, and a turn of the handlebars that gets smaller with the speed (35° when slow, 8° at the top speed). The body is a `CharacterBody3D` with a capsule along the scooter (`move_and_slide()`). | A physics vehicle wobbles and falls over at low frame rates (the workspace and the web run at 6 to 20 frames each second). A simple model is the same at each frame rate. |
| D5 | Where a scooter can go: the roads, the hẻm, the sidewalks, the paving of the parks, and a ramp or a curb of at most 15 cm. It stops at a wall, a house, a person, a tree, a stair, the sand, and the water. A hit stops the scooter (no damage, no "game over"), with the sound of a bump. | People in Vũng Tàu ride onto the sidewalks to park. The sand and the stairs are not for scooters. |
| D6 | The game clock runs at the speed of real time: one second of the game is one second of the clock (my decision, 2026-11-23). It counts the time that the game runs (the time of the frames), not the time of the computer: in a hidden browser tab or an app in the background, the clock does not move. A new game starts at 06:00 on 22 January 2019, as before. Walking and riding do not move the clock by distance. The time cost of an action in the data, the waits of the Clock app, and "Sleep until morning" still move the clock at once. At 23:59 the clock stops until the player sleeps, as before. | It is a relaxing game: a ride at sunset takes the time of a ride at sunset. The rule of 1 minute for each 8 m (plan 0001, R10) was made for a test street of 100 m; in the real town, the walk from the homestay to chợ Xóm Lưới (about 1 km) took about 2 hours of the game. |
| D7 | On a touch screen, the joystick shows at its rest place in the bottom left (light, about 40 % opacity), and it follows the thumb in the left half as before. It shows when the last input was a touch, and goes away after an input of the mouse or the keyboard. On the scooter, the same joystick rides: up is the throttle, down is the brake, left and right turn the handlebars. A button "Get off" takes the place of the action button while the player rides. | Now the joystick is invisible until a thumb touches the screen, so a new player does not know that it is there. |
| D8 | The controls of a computer on the scooter: W the throttle, S the brake (and, when the scooter stands, a slow push back at 0.5 m/s, with the feet), A and D the handlebars, E get on and get off, the mouse the head. A gamepad: the right trigger the throttle, the left trigger the brake, the left stick the handlebars, the right stick the head, A get on and get off. | The controls of plan 0004 (D4), with the scooter. |
| D9 | Get off only at less than 2 km/h. The scooter goes on its center stand where it stops (the joints of World: `stand`), and the player stands at its left side. | A rider in Vietnam gets off on the left side, away from the traffic. |

## 4. Requirements

### The clock

- **R1.** `GameState` moves the clock by the time of the frames (D6), with the seconds, and saves the seconds. `add_walk()` no longer moves the clock (`walked_total_m` stays for the play tests). The clock does not move while the game waits for a load of the world at its start. Unit tests: 60 s of frames give 1 minute; a walk of 100 m gives no minute; an action with a time cost, a wait of the Clock app, and the sleep still move the clock.
- **R2.** Each play test that counts on the rule of 8 m for each minute changes to the new rule. `PlaytestDriver.set_time_scale()` speeds up the clock and the world together, as now.

### The touch controls

- **R3.** The joystick at its rest place, and the "Get off" button (D7). They do not cover the phone, the subtitles, or the center dot, at 1280 × 720, 2400 × 1080, and 720 × 1280.

### The ride

- **R4.** Each parked scooter of World in the game can be ridden: the rows of `data/world/parked_rows.json`, the scooters of the test street, and the rows of the streets of plan 0009 when they come. When the player looks at one within 2 m, the center dot shows the action "Ride" (Vietnamese and English text in `data/`). The scooter leaves its row while the player rides it, and goes back into a row of its own where the player gets off.
- **R5.** The motion of D2, D4, and D5. The wheels turn with the speed, the front wheel and the handlebars turn with the steering (the joints of World), and the stand goes up. The scooter follows the ground: its pitch from the ground under its two wheels.
- **R6.** The view of D3.
- **R7.** The sound of the engine: a loop whose pitch follows the speed, the start, and the bump, with captions in `data/sounds.json` ("[xe máy nổ máy]", "[xe máy chạy]", "[cộp]"). The recordings are CC0 or CC BY, with their credits in `assets/CREDITS.md`.
- **R8.** A parked scooter within 10 m of each start point of `data/geo/starts.json`, so that a test can ride at once. The URL parameter `ride` of the web build (and the argument `--ride`) starts the game on that scooter.
- **R9.** The world streams in time for a ride at 40 km/h: the ground, the town, the houses of the streets, the trees, and the showcase are ready before the player sees them. PT-80 gives the longest frame and the count of frames longer than three times the median frame, along the ride. I set the limit after the first measure.
- **R10.** `PlaytestDriver.ride_along(path, speed)`: a play test rides a route with the joystick (real input), as `stick_along()` walks one. An agent that tests the town uses it to go far fast.
- **R11.** AGENTS.md, section 5: the fixed decision "View and controls" with the scooter and the joystick at its rest place, and the commands.

## 5. Play-test scenarios

- **PT-80 `scooter_ride`.** On Low, at 17:00, from the start point `bai_truoc`. The player walks to the parked scooter with the joystick, looks at it, and gets on with the action button. The player rides along Quang Trung and the walk of Hạ Long to Cầu Đá at the top speed, turns at a junction, brakes, rides onto a sidewalk over a curb, rides into a wall (the scooter stops, no error), and gets off. The scooter stands on its stand there, and the player walks away and back and rides it again. Screenshots at each step (the handlebars in the view, a turn with the lean, the stop at the wall). Checks: the speed never goes over 40 km/h; the scooter never goes into a wall, a house, a person, the sand, or the water; the clock moved by the time of the frames, not by the distance; R9.
- **PT-81 `touch_controls`.** At 2400 × 1080 and 720 × 1280 on the Mobile renderer, and at 1280 × 720 on the Compatibility renderer (the web build): the joystick shows at its rest place; a touch drag walks the player; on a scooter, the drag up rides, down brakes, and to the sides turns; "Get off" gets off. After a mouse input the joystick goes away, and after a touch it comes back. Screenshots of each state.
- PT-01 to PT-79 pass with the new clock (R2).

## 6. Acceptance criteria

| # | Criterion |
|---|---|
| 1 | The unit tests, PT-80, PT-81, and the play tests of R2 pass, and CI is green. |
| 2 | On the web build of the branch, I ride from Bãi Trước to chợ Xóm Lưới and along the coast on a phone and on a computer. |
| 3 | The budget of plan 0009 (R10, Q10) holds on Low, with the scooter in the view. |

## 7. Open questions

- **Q1.** In the first person on a scooter, the body of the rider does not show (no hands on the handlebars). Is that enough for now? (I answer.)
  - **My answer (2026-11-23):** yes. The player sees no body of their own when they walk, so no hands on the handlebars fits.

## 8. Builder notes (2026-11-23)

- **The clock (R1, R2).** `GameState.advance()` moves the clock by the time of the frames (the game time, with `Engine.time_scale`), with the seconds, which the save keeps (`seconds` in place of `walk_m`; a save of version 2 without it starts the minute at 0 s). It runs from the first frame, and in the Vũng Tàu world from the frame where the ground of the start is ready (at most 60 s after, `Main.CLOCK_WAIT_S`). The play tests that counted on the old rule, and their changes: PT-11 `fp_walk` (the clock moves by the time of the frames, not by the distance); PT-05 `save_reload` (after the restart the same minute or the next one: the clock runs before the quit and after the start); the soak (the run of the cart of mía moves the clock one minute from now, not to the opening minute plus one, which the clock can be at already). The other play tests that read the clock (`boot_intro`, `clock_sheet`, `phone_apps`, `morning_exercise`) pass as they are.
- **The motion (D2, D4, D5).** `ScooterMotion` runs in each physics step; `tests/unit/test_scooter.gd` checks the same path at 3 and at 60 frames each second, and PT-80 checks 0 to 20 km/h (4 s) and the brake (4 m/s²) in physics steps. PT-80 passes with `PLAYTEST_MAX_FPS=3`. A curb or a ramp of at most 16 cm goes up; a second step within 0.5 m is a stair; a drop of more than 20 cm in front of the wheels stops; a contact with a wall at more than 30° from its face is a hit (a scooter that slid along the walk on the sea wall at 21 km/h was the first defect of PT-80).
- **The view (D3, R6).** The eye is 1.45 m over the ground, 0.5 m behind the middle of the scooter. The camera keeps the horizontal field of view, so a wide screen sees less up and down: the view looks down enough to show the grips at each aspect (`Player.ride_pitch()`: -10° at 16:9, -15° at 2400 × 1080).
- **The sounds (R7).** Made in code (`Tones.scooter_engine()`, `scooter_start()`, `scooter_bump()`): the free libraries of recordings (CC0, CC BY) need an account, which the workspace does not have. `assets/CREDITS.md` has no new line.
- **The scooters (R4, R8).** The rows of `data/world/parked_rows.json`, the test street, one scooter along the road within 10 m of each start point, and each scooter where the player got off. No street of plan 0009 has a row of parked scooters yet.
- **The town boxes.** The boxes of the town (`TownField`) have no collision: a scooter goes through them, as a walker does. The houses of plan 0009, the places, the parts of the showcase, and the lamp poles stop it.
- **R9: the stream along the ride of PT-80 (run 1, about 690 m at up to 40 km/h, Low).** In the workspace: 625 frames, median 122 ms, the longest 669 ms, 2 frames longer than three times the median. With `PLAYTEST_MAX_FPS=3`: 308 frames, median 333 ms, the longest 1 141 ms, 2 frames longer than three times the median. In CI: see the report of the CI run (`frames_1.json` in the artifact of the part with PT-80).
- **PT-81.** Run 1 at 2400 × 1080 and 720 × 1280 at Bãi Trước (Mobile); run 2 at 1280 × 720 in the test street (Compatibility). The Vũng Tàu world on the Compatibility renderer leaves two textures of 349 524 bytes (256 × 256 RGBA with mipmaps) at the quit: "Texture with GL ID of 125 (126): leaked". It is also on main (63fa8ba) and on the branch of plan 0009, with no scooter. It is not the sky, the reflections, the sea, the trees, the caches of the models of World, or the fonts of the labels in 3D. It is an open defect of its own: the page of the web build does not quit, so a player does not see it.
- **The web build.** https://feat-0018-scooter-vung-tau.fifo.workers.dev with `?start=bai_truoc&ride`, `?start=cho_xom_luoi&ride`, and `?start=truong_cong_dinh&ride`: each page starts on the scooter of its start (Chromium in the workspace).
