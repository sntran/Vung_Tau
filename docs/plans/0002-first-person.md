# 0002 First-person walking

| Field | Value |
|---|---|
| Status | Draft |
| Branch | `feat/0002-first-person` |
| Depends on | 0001 (status "Built") |

## 1. Goal

The player sees the hẻm through the eyes of the visitor and walks like a person in real life.

Plan 0001 stays the foundation: the data, the clock, the notebook, the talk panel, the save, the play-test system, and CI. This plan replaces the camera, the controls, and the screen layout of plan 0001.

## 2. Out of scope

- Models from photos of real places. (Plan 0003.)
- The phở table and the eating flow.
- Running, jumping, and vehicles.

## 3. Decisions

These decisions replace decisions D3, D4, and D5 of plan 0001.

| ID | Decision | Reason |
|---|---|---|
| D1 | First-person camera at an eye height of 1.6 m. The player body is not visible. | The player must walk around as in real life. |
| D2 | Landscape is the main layout. Base viewport 1280 × 720, stretch mode `canvas_items`, aspect `expand`. Phones lock the screen to landscape. The web build works with all window shapes. | A first-person view needs width. A portrait view shows a narrow street and makes the player turn more. |
| D3 | Move with a floating joystick on the left half of the screen. The joystick appears where the thumb touches. | Standard control for mobile 3D games. |
| D4 | Look with a drag on the right half of the screen. | Standard control for mobile 3D games. Players prefer two touch controls to tilt controls for aim in a study of a mobile game ([Teather et al. 2017](https://yorku.ca/mack/ec2017.html)). |
| D5 | Look by moving the phone (gyroscope) is also available. It is on by default on phones with a gyroscope. A setting turns it off. A button centers the view. | In a study of a first-person tablet game, players with little game experience enjoyed motion look more. With motion look, the gap in performance between new and experienced players went away ([Kniestedt et al. 2018](https://research.utwente.nl/en/publications/including-non-gamers-a-case-study-comparing-touch-and-motion-inpu/)). Our players are adults who often do not play games. |
| D6 | Tap to walk. A short tap on the ground, a spot, or a person within 15 m makes the player walk there. A tap on a spot or a person also opens the talk panel at the end of the walk. | Players who do not play games can move without the joystick, as in a map app. |
| D7 | Comfort: walk speed 1.4 m/s, no head bob, horizontal field of view 75° (a setting from 60° to 90°), smooth look with a limit on the turn speed. | A normal walk speed. Less motion sickness for players who do not play 3D games. |
| D8 | A small dot at the screen center shows the focus. The focus is the touchable object nearest to the dot, at 3 m or less. An action button shows the verb for the focus ("Talk", "Look", "Sit"). | One clear way to start an action without a precise tap. |
| D9 | Sensor data (gyroscope) is input. Play tests can send sensor data through the play-test driver. | Rule R33 of plan 0001 permits input only. The gyroscope is input. |
| D10 | Use the Mobile renderer (Vulkan) on Android and iOS. This replaces decision D2 of plan 0001. The web build stays on the Compatibility renderer, because Godot web exports support only that renderer. | The Mobile renderer gives better light on phones. It now renders in the development workspace with the Mesa software Vulkan driver (lavapipe), so the play tests can still take screenshots. Verified with Godot 4.7.2: "Vulkan 1.4.318 - Forward Mobile - Using Device: llvmpipe". |

The time cost of walking does not change: 1 game minute for each 8 m.

## 4. Requirements

### Player

- **R1.** The player is a `CharacterBody3D` with a capsule of radius 0.25 m and height 1.7 m. The step height is 0.2 m, for curbs and doorsteps.
- **R2.** The player cannot go through walls, carts, stools, tables, people, trees, or the beach wall.
- **R3.** The camera near plane is 0.05 m. The camera must never show the inside of a wall.
- **R4.** The player starts at the homestay door and looks along the hẻm toward Bãi Trước. After "Sleep until morning", the player is at the same place and looks in the same direction.

### Controls

- **R5.** The joystick appears where the left thumb touches. It has a radius of 80 px at the base width. A drag to the edge gives full speed. A small drag gives a slow walk. The joystick disappears when the thumb lifts.
- **R6.** A drag on the right half turns the view. The settings give the sensitivity and "invert up and down". The up and down look stops at 80°.
- **R7.** The gyroscope look adds to the drag look. A "center" button resets the gyroscope reference. With the setting off, the gyroscope has no effect.
- **R8.** A tap is a touch that is shorter than 0.25 s and moves less than 12 px. A tap on the left half does not make a joystick.
- **R9.** Tap to walk (D6) uses the navigation mesh. A joystick touch or a look drag stops the walk.
- **R10.** When the target of a tap is more than 15 m away, the player walks 15 m in its direction.
- **R11.** Keyboard and mouse in the web build: W, A, S, D and the arrow keys move. A drag with the mouse turns the view. A click is a tap.

### Focus and actions

- **R12.** Each spot and each person has a focus point and an action verb in `data/spots.json` or in the NPC data.
- **R13.** When the focus changes, the action button shows the new verb. When there is no focus, the action button is hidden.
- **R14.** A person turns to face the player during a talk.

### World

- **R15.** The open ground floor of each shop is a room 4 m deep. The player can walk into it. In this plan the room is greybox.
- **R16.** Keep the house and hẻm sizes of plan 0001 R14. In first person, the sizes must look correct at eye height. Record in Open questions any size that looks wrong in the screenshots.

### Screen layout

- **R17.** Make the UI again for landscape:
  - The top bar is one thin row at the top.
  - The talk panel is on the right side, at most 42% of the screen width. It must not cover the center dot.
  - The joystick zone and the look zone must not include a button.
- **R18.** A settings sheet has: look sensitivity, invert up and down, gyroscope on or off, field of view, and tap to walk on or off. The settings are saved in the save file.
- **R19.** All buttons are at least 88 px high at the 720 px base height.

### Renderer

- **R22.** Set `rendering/renderer/rendering_method` and `rendering/renderer/rendering_method.mobile` to `mobile`.
- **R23.** `tools/setup.sh` installs the package `mesa-vulkan-drivers` when `/usr/share/vulkan/icd.d/lvp_icd.json` is missing. The command is `apt-get install -y mesa-vulkan-drivers`. The CI workflow does the same.
- **R24.** `tools/playtest.sh` runs Godot with `--rendering-driver vulkan --rendering-method mobile`. Record the frame rate under lavapipe in `AGENTS.md`.
- **R25.** Run PT-17 one time on the web build too, with the Compatibility renderer. The web screenshots can look different, but the layout must be correct.

### Play-test system

- **R26.** Add these functions to `PlaytestDriver`:

  | Function | What it does |
  |---|---|
  | `hold_stick(direction: Vector2, seconds: float)` | Touch at a point on the left half, drag in the direction, hold, then release. Uses `InputEventScreenTouch` and `InputEventScreenDrag`. |
  | `drag(from: Vector2, to: Vector2, seconds: float)` | A drag with a drag event at each frame. |
  | `look_at_id(test_id: String, timeout_s := 10.0)` | Drags on the right half until the node is at the center dot. |
  | `gyro(rate: Vector3, seconds: float)` | Sends gyroscope data through the sensor source of the game. |

- **R27.** The game reads the gyroscope through one sensor source object. Normally it reads `Input.get_gyroscope()`. The play-test system can replace it with a scripted source.

## 5. Play-test scenarios

Change the scenarios of plan 0001 to use first-person input. Remove PT-02 `walk_hem` and PT-07 `tap_through`. The new scenarios PT-11, PT-12, and PT-13 replace them.

Run all scenarios at 1280×720 and 2400×1080. PT-17 also runs at 1920×1080 and 720×1280.

- **PT-11 `fp_walk`.** From the homestay door, walk to Bãi Trước with the joystick and look drags only. Then walk back with tap to walk only. At each lot, check the position (±1 m) and save a screenshot at eye height. Check that the clock moved forward the correct number of minutes for the distance.
- **PT-12 `fp_collision`.** Push into each house wall, each cart, each palm tree, and the beach wall for 3 s. After each push, the capsule must not intersect a collision shape. The player must stay on the floor. Look at a wall from 0.3 m. The screenshot must not show the inside of the wall.
- **PT-13 `fp_tap_walk`.** Tap a spot that is 10 m away. The player arrives and the talk panel opens with the correct line ID. Tap a spot that is 25 m away. The player walks 15 m toward it and stops. Tap the ground. Start a joystick touch during a tap walk. The tap walk stops.
- **PT-14 `fp_focus`.** Look at Bà Tư from 2 m. The action button shows "Talk". Tap it. The greeting line shows, and Bà Tư faces the player. Look away. The action button hides.
- **PT-15 `fp_gyro`.** Send a yaw rate of 0.5 rad/s for 2 s. The view turns 1 rad, ±5%. Turn the gyroscope off in settings. Send the same rate. The view does not turn. Use the center button.
- **PT-16 `fp_settings`.** Change each setting. Quit and start again. All settings are the same.
- **PT-17 `fp_layout`.** For each screen size: open each sheet and each kind of talk panel. No control is off the screen. No control covers the top bar or the center dot. No button is in the joystick zone or the look zone in a way that a joystick touch or a look drag starts on it.

## 6. Acceptance criteria

1. All unit tests and all play tests pass, in the workspace and in CI.
2. The builder looked at all screenshots. No screen is broken.
3. The web build works with a mouse and a keyboard. The Android debug APK works with touch, the joystick, and the gyroscope.
4. `AGENTS.md` shows the new decisions: first person, landscape, the controls, and the new driver functions. The builder updates the plan list in `docs/plans/README.md`.

## 7. Open questions

- **Q1.** The gyroscope "on" by default (D5) needs my approval.
- **Q2.** Landscape only on phones (D2) needs my approval.
- **Q3.** Is tap to walk necessary when the joystick is there? Keep both until I try the APK.
