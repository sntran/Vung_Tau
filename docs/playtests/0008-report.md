# Report 0008: Known structures (interim)

| Field | Value |
|---|---|
| Plan | [0008 Known structures](../plans/0008-known-structures.md) |
| Branch | `feat/0008-known-structures` at commit `78a485b` |
| Date | 2026-11-07 |
| Scope | Phases 1 to 4 and 6. Phase 5 waits for World (W13). This is an interim audit: the plan is "In progress". |

## 1. Runs

| Play test | Result |
|---|---|
| PT-60 `landmark_views` (12:00 and 18:00) | Pass. The DEM and the game agree for each view, and the labels are gone. |
| PT-61 `statue_stairs` (8 parts and the top) | Pass in 1 075 s. The route is 478 m, with 6 stairs and 691 steps. No part needed a second tap. |
| PT-63 `landmark_sheet` | Pass. I looked at the 18 screenshots. |

## 2. Defects

### D-0008-01: The player stands on air beside the stairs (medium)

The builder reports that the player can stand on an invisible slope beside the stairs, up to about 0.7 m over the visible ground. A player sees this as floating. The collision must follow the visible ground, or the visible ground must follow the collision. Add a PT-61 step that walks beside each stair and checks that the feet are within 0.1 m of the visible ground.

### D-0008-02: A gap of 5.4 m in the route (low)

Two ways of the route do not meet in OpenStreetMap. Join them in `data/geo/overrides.json` (data, not code), so the player walks on the path the whole way.

### D-0008-03: The second tap of PT-61 (low)

PT-61 taps a second time when a tap does not move the player. In my run, no part needed it. A tap that does not move the player is a defect that a player sees, so remove the second tap: the test fails if a tap does not move the player.

### D-0008-04: The stand-ins and the stairs are pure white (medium)

The stairs, the plaza, and the stand-ins are pure white with almost no shade (`601-part_7_start.png`, `702-part_8_end.png`): the plaza is a white shape with no edges. Give the stairs the material of concrete (grey, with the edge of each step visible), and the stand-ins a light grey with roughness, so the shapes read in the sun.

### D-0008-05: The close views of PT-63 do not show the places (low)

Bạch Dinh at 10 m is inside a tree, the lighthouse at 50 m is behind trees, and Miếu Hòn Bà at 10 m is between black boulders. A sheet is for my approval, so each view must show the place. Put the views of the sheets where a visitor stands: on the paths and the plazas, looking at the place.

## 3. Notes and questions

- **The number of steps.** The game has 691 steps on its route. The source says 811 (culture notes). The OSM ways can be shorter than the real stairs, or the step height can differ. The builder writes which it is.
- **The jetty of Cầu Đá in 2019.** The deck is a plain slab with no rails. I remember concrete rails in the 1990s. Their state in 2019 has the status "Check".
- **Q7 (the plaza of the statue).** It waits for my answer.
