# Play-test report: plan 0020, Real trees

## 1. Commit

`8fa9a0e` on `main`. Plan 0020 has the status "Built".

## 2. What the architect ran

| Run | Result |
|---|---|
| CI on `main` (the branch `fix/0005-ground-detail` with the same commit is green) | Pass on the branch. The tree build check passes. |
| PT-52 `tree_gallery`, runs 3 and 4 (all 14 types at 12:00 on day 1, Low) | Pass. My sheets are below. The sheet run (13) needs all 12 runs, so I did not make it. |
| PT-33 at 12:00 | Pass, but see D-0020-01. |
| PT-54 on Low | Pass: 212 000 to 265 000 triangles (limit 300 000), 219 to 301 draw calls. |
| PT-54 on High | Stopped after 300 s in the workspace (2 CPUs). CI passes it. See D-0020-05. |

![All types at 8 m, 12:00 on day 1, Low](0020/trees-8m.jpg)

![Five types at 8 m, 30 m, 120 m, and 400 m](0020/distances.jpg)

## 3. Defects

### D-0020-01: A tree blocks the view from the top of Núi Nhỏ, and PT-33 passes (high)

![The view from Núi Nhỏ along Bãi Sau](0020/d01-blocked-view.jpg)

- **Actual:** in the PT-33 view "From Núi Nhỏ along Bãi Sau", a near tree covers half of the frame with flat dark green leaves. The view "From Núi Nhỏ to the north" stands in a forest. The top of Núi Nhỏ is the round, paved platform of Tượng Chúa Kitô Vua, with no trees on it. PT-33 checks only that the places are in the frame, not that the player can see them.
- **Correction:**
  1. No trees on the paved tops and the platforms of the known places (the summit of Núi Nhỏ, the lighthouse, the terraces of Núi Lớn), and none on the roads and the paths. Use the OSM areas (`highway`, `man_made`, `tourism`, `amenity` areas, and the landmarks of R1) as places with no trees.
  2. Add to PT-33: in each view, objects nearer than 3 m to the camera cover at most 5 % of the frame.

### D-0020-02: The leaves of the hill trees and the shade trees are too large (medium)

- **Actual:** at 8 m and 30 m, `hill_a`, `hill_b`, `hill_c`, and `shade` show single leaves about 0.4 m to 0.6 m long, in sparse groups. The trees look like paper cutouts. Most broad leaves of the forest of Núi Lớn and of the street trees are 5 cm to 20 cm long (`teak` and `bang` have large leaves, and that is correct).
- **Correction:** smaller leaves in dense groups for these types (leaf cards with many small leaves for the middle form), so that a crown is a mass of leaves with gaps, as in my photos of Trần Hưng Đạo and the hills.

### D-0020-03: Half of the street trees have no tree in the canopy map (medium)

- **Actual:** `report.md` says that the canopy map of 2019 shows no tree within 5 m of 14 600 of the 29 060 street and park trees (casuarina 2 499 of 3 509, shade 5 192 of 11 057), and "I check them on photos". Nobody can check 14 600 trees on photos. The rules of `data/geo/trees.json` put a tree each 9 m on all trunk, primary, secondary, and tertiary roads, so many rows in the game do not exist.
- **Correction:**
  - On the roads that I confirmed (Quang Trung, Ba Cu, Trần Hưng Đạo, Thùy Vân, Hạ Long, Trần Phú, and the park of Bãi Trước), keep the rows of my photos, but move each tree to the nearest tree top of the canopy map within 6 m when there is one.
  - On the other roads, put a street tree only where the canopy map has a tree top within 6 m of the road edge, with the type mix of the road. The canopy map can miss single palms: keep the coconut palms of the park and of Quang Trung.
  - The report gives the share for each road group, not a list.

### D-0020-04: Some types do not look like the photos (low)

- **Coconut palm:** the leaflets are yellow-green and bright. In my photos of Bãi Trước, the fronds are a darker green, with yellow-green only on some old fronds.
- **Fan palm:** a round mass like a head of broccoli, not round fan leaves on long stems.
- **Scrub:** at 8 m, a few floating leaves with gaps; a bush is a dense mass of small leaves.
- **Norfolk pine:** a single cone of leaves, not flat layers of branches. It is not in the game now (Q6), so this can wait.

### D-0020-05: PT-54 on High takes more than 300 s in the workspace (low)

- **Actual:** the High run stopped after 300 s here. CI passes it, but the CI computers are slower, so it is near its limit.
- **Correction:** split PT-54 into one run for each view and preset.

## 4. Acceptance criteria

| # | Result |
|---|---|
| 1 | Open: I look at the sheets of PT-52 (the pictures in section 2 are a part of them) and approve the look after D-0020-02 and D-0020-04. |
| 2 | Open: after D-0020-03, I look at Bãi Trước in PT-53. |
| 3 | Pass on Low. High passes in CI. |
| 4 | Pass in CI on the branch. |

## 5. Order of the corrections

1. D-0020-01 (the views and the places with no trees).
2. D-0020-03 (the street trees from the canopy map).
3. D-0020-02 and D-0020-04 (the look).
4. D-0020-05.


## Re-check of 2026-11-05

I ran PT-33, PT-38, and PT-53 on `main` at commit `286e6fa`, at 1280 × 720 on the Mobile renderer. All pass. I did not run PT-52 (the sheets) and PT-54 (the budget) again, so I did not check D-0020-04 and D-0020-05.

| Defect | Result | Evidence |
|---|---|---|
| D-0020-01 | Partly fixed | PT-33 now checks that nothing is nearer than 3 m to the camera, and it passes (0.0 %). But in `103-nui_nho_north_1200.png`, one tree about 5 m from the camera covers about a fifth of the frame, and more trees stand on the grass inside the gravel ring at the top. The ring is the platform of the statue. So the 3 m check does not find the problem that I described, and the top is not clear. |
| D-0020-02 | Partly fixed | The leaves of the hill trees are smaller than before (`103-nui_nho_north_1200.png`). The leaves of the street trees at Quang Trung and in the park (`101-quang_trung_high.png`, `002-park_high.png`) are still large flat shapes about 20 cm to 30 cm long at 5 m, with gaps between them. They look like paper cutouts. |
| D-0020-03 | Fixed | The park and Quang Trung show rows of trees on the tree tops of the canopy map, with the coconut palms of the park. |

New, low:

- **D-0020-06.** The dark lower trunks and the upper trunks of the street trees have a hard line between two colors (`101-quang_trung_high.png`, the tree at the right). Make the change of color gradual.
- **D-0020-07.** In January, the flame trees of the park and of Quang Trung show many red and orange leaves, like flowers (`002-park_high.png`). Flame trees flower from late April to early July. In January they have dry, thin leaves and no flowers. Check the season values of the type `flame` for day 1 (plan 0005, N30).

**Corrections:**

1. D-0020-01: remove the trees from the area inside the gravel ring at the top of Núi Nhỏ. In PT-33, make the check for objects near the camera 8 m for the views from the tops (5 % of the frame at most).
2. D-0020-02: smaller leaves for the street tree types, in more groups.
3. D-0020-06 and D-0020-07.
4. D-0020-04 and D-0020-05 stay open. I check them when I run PT-52 and PT-54 again.

**Status:** plan 0020 stays "Built".

## Second re-check of 2026-11-07

I ran PT-33 (phase 2, 12:00), PT-53, and PT-54 (phase 1, Low) on the branch `feat/0020-real-trees` at commit `2d47234`, at 1280 × 720. All pass.

| Defect | Result | Evidence |
|---|---|---|
| D-0020-01 | Fixed | `103-nui_nho_north_1200.png`: the gravel ring at the top of Núi Nhỏ is clear, and the view goes over the trees to the town and Núi Lớn. |
| D-0020-02 | Fixed | `101-quang_trung_high.png`: the leaves of the street trees are smaller and in groups. |
| D-0020-06 | Fixed | No hard line on the trunks. Note: the trunks of the street trees are now almost black. Give them the grey brown of bark. |
| D-0020-07 | Fixed | The red leaves at Quang Trung are on the bàng trees, which turn red in the dry season. That is correct for January. |
| D-0020-04 | Open | I approve the look of the types from the sheets of PT-52. |
| D-0020-05 | Open, low | PT-54 on High passes in CI. Phase 1 (Low) passes in the workspace: 279 draw calls and 217 104 triangles at the top of Núi Nhỏ (limit 300 000). |

**Status:** plan 0020 stays "Built" until the branch is on `main` and I approve the sheets of PT-52 (criterion 1).
