# 0009 Houses on the lots

| Field | Value |
|---|---|
| Status | Draft. It waits for the houses of World (plan 0023, requests W17 to W23). |
| Branch | `feat/0009-houses-on-the-lots` |
| Depends on | 0004 (the house kit and the palette), 0005 (the roads and the ground), 0008 (the known places stay as they are), 0023 (the houses come from World, D8). |
| Used by | 0010 (the bus ride), 0011 to 0015 (the shops and the streets), 0021 (Tết), 0022 (the garden). |

## 1. Goal

At the end of this plan, the town is full of houses. The hẻm of the homestay is the real Hẻm 2 Hải Đăng, with the slope of Núi Nhỏ on one side. The streets near chợ Xóm Lưới have their shops and houses. From the tops of Núi Nhỏ and Núi Lớn, the player sees the real roofs of the town, and not a flat color. The town is as it was in 2019, with no newer towers.

## 2. Out of scope

- The people (plan 0006) and the shops' work (plans 0011 to 0014).
- The Tết decorations (plan 0021). This plan leaves the ports for them.
- The inside of the houses, except the homestay's front room and the open floor of a shop (plan 0023, W20).
- The traffic (plan 0018). Parked scooters are in this plan. Moving ones are not.

## 3. Decisions

| # | Decision | Reason |
|---|---|---|
| D1 | The buildings of the town come from public data of 2019, not from drawings by hand. A building is in the game only when the data shows it in 2019. | A town that is correct from the hills must have the real number, places, and heights of the buildings. |
| D2 | The fetch of the data runs in CI (a workflow like `geodata.yml`), and the result goes into `data/geo/build/`. | The workspace cannot reach the data sites. I checked on 2026-11-05: `storage.googleapis.com`, the Overture Maps bucket, the Microsoft buildings site, and `source.coop` all refuse the connection. |
| D3 | The houses come from World (plan 0023, D8). One house is made by an order, and a family of orders gives variants. The game does not make houses with code. | World is the one source of models of my projects. |
| D4 | The game chooses the variant of a house from the id of the building, so the same building is always the same house. | A player who comes back sees the same street. |
| D5 | Three levels for each house: near, mid, and far (plan 0023, W22). The far level is a box with the right roof, and it is the only level that most of the town has. | Thousands of houses. |
| D6 | The real hẻm (Hẻm 2 Hải Đăng) replaces the test street of plans 0001 to 0004. The shops and the people of the test street move to the streets near chợ Xóm Lưới. Bà Tư and cô Nga stay at the homestay. | AGENTS.md, section 1. |
| D7 | The street is lived in. The rules for scooters, stools, laundry, plants, and cages are in the data, and they depend on the time of day (plan 0023, sections 9.3 and 9.4). | A clean street is not Vũng Tàu. |
| D8 | The colors follow the rules of plan 0004 (R10a): most walls come from the muted palette, a few are bold, and two neighbors never have the same color. | The measured palette of the aerial photos. |
| D9 | NASA lidar checks the heights: ICESat-2 (ATL08, the ground and the tops of the trees along its tracks) and GEDI (L2A, the ground and the height of the top in circles of 25 m). It does not give the shapes of the houses: its tracks are lines kilometers apart. The fetch runs in CI with my NASA Earthdata token in the GitHub secret `EARTHDATA_TOKEN`. | The ground heights of plan 0005 come from radar, which sees the tops of the trees and the roofs. On the forest of Núi Lớn and Núi Nhỏ the hills can be too high, and the game puts its trees on top of that. The lidar measures the ground under the trees. The workspace cannot reach the NASA data sites (`cmr.earthdata.nasa.gov` and `data.nsidc.earthdatacloud.nasa.gov`, checked on 2026-11-11). |

## 4. Requirements

### The data

- **R1.** `tools/geo/buildings.py` (CI) fetches the footprints and the heights of buildings in the play area, and the height by year. It writes `data/geo/build/buildings_2019.json`: the outline, the height, the source, and the first year when the building shows. A building that first shows after 2019 is not in the file. The report `buildings_report.md` gives the counts and the maps: all buildings, the ones in 2019, and the ones that are removed.
- **R2.** The floors come from the height with a rule in `data/geo/houses.json` (a base height and a height for each floor). The builder calibrates the rule with 20 buildings that I know (the homestay hẻm and some places on Trần Phú), and writes the result in the report. Where a lidar point of D9 falls on a building, its height also calibrates the rule, so I give the floors of fewer buildings.
- **R3.** The kind of each building:
  - When OpenStreetMap has a tag (hotel, church, temple, market), the tag decides.
  - Otherwise, a narrow deep footprint (width up to 6 m, depth at least twice the width) is a tube house. A tall narrow building near the beach is a mini-hotel. A large footprint is a block with a flat roof (`big`).
  - The known places of plan 0008 are not houses. Their outlines clear the houses.
- **R4.** The front of each house points to the nearest road. The width and the depth come from the smallest rectangle around the outline. A row of houses with shared walls keeps the walls shared (W17).
- **R5.** The data has a license note and a credit in the credits page (R15).
- **R5a.** `tools/geo/lidar.py` (CI) gets the points of ICESat-2 ATL08 and GEDI L2A in the play area, of the years 2018 to 2023, to `data/geo/raw/lidar/`. It keeps only the points of good quality (the quality flags of each product), and writes for each point: the position, the date, the height of the ground, the height of the top, and the product.
- **R5b.** The ground under the trees. `tools/geo/build.py` compares the height of the DEM with the height of the lidar ground at each point, and the report gives the difference by land cover (tree cover, bushes, town, bare ground) and on each hill. If the mean difference under the tree cover is more than 2 m, the build lowers the DEM under the tree cover by the difference, smoothly to zero at the edge of the cover, and the report shows the maps before and after. If it is 2 m or less, the build does not change the DEM. Then PT-33 runs again, and I look at the views of the hills.

### The game

- **R6.** Load the houses in chunks of 256 m, with the chunks of plan 0005. The near level is within the near range of the preset, the mid level to a longer range, and the far level beyond. A house in a chunk that is not loaded costs nothing.
- **R7.** For each kind and width class, ask World for a family (W19), and make a library at the start. The game picks the variant by the id of the building (D4), and the colors by D8. The game puts the small parts with MultiMeshes at the ports of the house (W18): AC units, rails, pots, signs, number plates, tanks, dishes, and antennas.
- **R7a.** A house of World keeps up to 12 roles (plan 0023, W22 and W23: I chose this in World). The game merges them into at most 6 materials for each house: the walls (`plaster`, `brick_ong`), the front (`tile_granite`, `tile_pattern`), the metal (`metal_shutter`, `iron`, `aluminum`), the roof (`roof_corrugated`, `roof_clay`), `concrete`, and `glass` with `wood`. The map is data in `data/world/materials.json`. PT-69 counts the materials of each house.
- **R8.** The ground under a house is level, with a step up from the sidewalk and a ramp for scooters (plan 0004, N11). On a slope, the house has a low base wall on the downhill side.
- **R9.** Occluders on the house walls, and visibility ranges for the parts (plan 0004, R13).
- **R10.** Budget: the limit of plan 0020 (Q7) holds at the views of PT-54 and at the views of PT-68: Low has at most 300 000 triangles. The builder measures the draw calls, and proposes limits that I approve.

### The hẻm and the streets

- **R11.** Build Hẻm 2 Hải Đăng from `data/geo/build/homestay.json`: the slope of Núi Nhỏ on one side, with some houses on it, and one row of houses on the other side. The homestay stands on an empty lot on the slope side, with the terraces for the garden of plan 0022 behind it. The front room of the homestay (W20) has the family altar, the earth god altar near the door, a table, and chairs. Only homes are in the hẻm: nobody sells anything.
- **R12.** Move the shops and the people of the test street (cô Sáu, bác Hà, cô Út, the cà phê cóc, the bánh mì cart, and the hủ tiếu gõ cart) to the streets near chợ Xóm Lưới. Each one gets a place that the builder proposes, and I approve it.
- **R13.** Street dressing from the data: the sidewalks and the curbs (W21), the power poles with the cables, the street lamps, and the trash bins. Scooters parked in rows on the sidewalks, and in front of each house at night. Low stools, hammocks, laundry, plants, and cages by rules of time and kind of street.
- **R14.** Lights at night: some windows are lit, with a chance that depends on the hour. Shops keep their lamps with a short range (`Hem.SHOP_LIGHT_RANGE`, plan 0004). The street lamps turn on at dusk.
- **R15.** Credits: the page of credits and `assets/CREDITS.md` have the data sources and their licenses.

## 5. Phases

1. The data pipeline and its report (R1 to R5b). I look at the maps in the report, and at the hills before and after R5b.
2. The far level of the whole town (R6, R10), with boxes of the right size and roofs. I look from Núi Nhỏ and Núi Lớn.
3. The houses of World, near and mid (R7, R8, R9), one kind at a time: the tube house first.
4. The real hẻm and the homestay (R11).
5. The streets near chợ Xóm Lưới (R12, R13), then the night (R14).

## 6. Play-test scenarios

- **PT-65 `buildings_data`.** The unit test of R1 to R4: no building is outside the area, no two overlap, the floors are from 1 to 12, and no building first shows after 2019. The test of R5b: with a DEM that is 5 m too high under the tree cover of a test area, the build finds the 5 m (within 0.5 m) and lowers the ground; with a correct DEM, it changes nothing.
- **PT-66 `hem_homestay_walk`.** Walk the full hẻm with the joystick at 06:00, 12:00, and 20:30. The free path is 0.9 m or more at all times (the check of plan 0004, `hem_walk`). Enter the front room of the homestay.
- **PT-67 `xom_luoi_walk`.** Walk from the homestay hẻm to chợ Xóm Lưới and along the streets around it. Each shop of R12 is at its place.
- **PT-68 `town_views`.** Screenshots from the top of Núi Nhỏ, the top of Núi Lớn, the Hải Đăng road, and the bus view of plan 0010, at 12:00 and 18:00. The architect looks at them.
- **PT-69 `town_budget`.** The triangles and the draw calls at the views of PT-68, on Low and on High.
- **PT-70 `town_night`.** Screenshots of the hẻm and a street near the market at 20:30: the lit windows, the lamps, and the parked scooters.

## 7. Acceptance criteria

| # | Criterion |
|---|---|
| 1 | The unit tests and PT-65 to PT-70 pass. |
| 2 | From the tops of the hills, I see the real roofs of the town, and no building that was not there in 2019. |
| 3 | I walk the hẻm, and I know it. |
| 4 | The budget of R10 holds on Low. |

## 8. Open questions

- **Q1.** The sources of the footprints and of the heights. The first choice: Google Open Buildings 2.5D Temporal for the height by year (4 m grid, CC BY 4.0 or ODbL), and a footprint set that covers the area (OpenStreetMap, Overture Maps, or Open Buildings). The builder checks in CI which one covers Vũng Tàu, and the architect confirms.
- **Q2.** The rule for floors (R2). I give the floors of the buildings that I know: 20 without lidar, fewer where the lidar points fall on buildings.
- **Q5.** I make a free NASA Earthdata account and put its token in the secret `EARTHDATA_TOKEN` before phase 1.
- **Q3.** The 2019 state of some places: which streets near chợ Xóm Lưới had shops, and which hotels stood near Bãi Trước. These facts have the status "Check".
- **Q4.** The first release does not need all the town. Which part has houses of the near level first: the hẻm, the market streets, and the road to Bãi Trước?
