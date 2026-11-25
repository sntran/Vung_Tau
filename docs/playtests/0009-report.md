# Report 0009: Houses on the lots (interim)

| Field | Value |
|---|---|
| Plan | [0009 Houses on the lots](../plans/0009-houses-on-the-lots.md) |
| Branch | `feat/0009-houses-on-the-lots` at commit `a36c84e` (the last data run of the workflow "Buildings and lidar"; the last commit of the builder is `7d32458`) |
| Date | 2026-11-19 |
| Scope | Phase 1a: R1, R5, R5a, R5c, and R5d (the fetches and the reports). Nothing in the game changes. |

The pictures of this report are in [`0009/audit-2026-11-19/`](0009/audit-2026-11-19/).

## 1. Runs

| Check | Result |
|---|---|
| CI of `7d32458` | Pass: Test (8 parts), and the job "Get the buildings and the lidar". |
| `python -m pytest -q tools/geo/tests/test_buildings_tool.py` | Pass: 7 tests. |
| The data at the head (`a36c84e`) | Read here with Python: `buildings_2019.json`, `temporal.json`, `overture.json`, the four files of the lidar, and the map `temporal_2019_unmatched.tif`. |

## 2. What is correct

- The tools find the data of each source with no account: Overture Maps (56 359 outlines), the manifests and the tiles of Open Buildings 2.5D Temporal (cells `31` and `37`, 4 tiles for each year from 2016 to 2023), OpenStreetMap on 2019-01-22 (1 119 buildings), and SlideRule.
- The 2.5D rasters lie a few meters off the outlines, and the tool finds the shift of each year from the overlap and moves the outlines by it. This is a good find.
- `buildings_2019.json` has 52 379 buildings: 42 242 first show in 2016, 2 523 in 2017, 1 603 in 2018, 1 341 in 2019, and 4 670 have no year. 3 980 are out (their first year is after 2019). The median height is 6 m, and 90 % are under 10.5 m. These numbers are plausible for the town.
- R5c: ATL24 keeps only the photons of the sea floor (class 40), and `ortho_h` is no longer turned over the geoid two times (`7d32458`).
- R5: `data/geo/LICENSE` has a note for each new source, and it says which license of Open Buildings the game uses.

## 3. Defects

### D-0009-01: The data at the head is from a run that lost data (high)

The workflow ran again on the push of `7d32458` (its trigger is a push that changes a tool) and committed `a36c84e`. That run gave less data than the run before it, and it replaced the files:

| File | `86f606a` and `7d32458` | `a36c84e` (the head) |
|---|---|---|
| ATL03, ground photons | 896 655, the years 2018 to 2026 | 383 425: 0 rows for 2021, 2022, 2023, and 2025, and no time for 2026 |
| GEDI L2A | 1 122 shots | 188 shots |
| ATL08 | 4 745 segments | 10 680 segments |
| ATL24 | 32 929 photons | not fetched ("no time"); the file of `7d32458` stays |

The report of the builder and the notes in the plan give the numbers of the first run, not the data at the head.

- A year that fails or that gets no time must keep the data of that year from the last good run. Keep the data of each product by year, and fetch only the years that are not there.
- A year that gives 0 rows where the last run had rows is an error. The report says so, and the job does not commit.
- A product with fewer points than its file fails the job, unless a person starts the run with an input that allows it.
- A unit test: a fetch with one year that fails keeps the rows of that year.

### D-0009-02: ATL03 has only the ground photons (medium)

`parms_for("atl03_ground")` asks only for `atl08_ground`. D10 and R2 need the photons on the roofs: the lidar is the check of the heights of the buildings ("Where a lidar photon of R5a falls on a roof"). Also fetch the photons of the classes `atl08_canopy` and `atl08_top_of_canopy` and the photons with no class, and keep only those over an outline of `overture.json` (to keep the file small). Then the report compares the height of each roof photon over the ground with the 2.5D height of its outline.

### D-0009-03: The reports of R1 and R5d are not complete (medium)

The builder notes say that some parts come later. Before phase 1a is done:

- **R1, the maps**: all the buildings, the ones of 2019, the ones that are out, and the places with a building in the raster of 2019 and no outline. The report has only a GeoTIFF of the last one. Make PNG maps that a person can look at, as in `data/geo/build/report.md`.
- **R1, the checks of the heights**: 3D-GloBFP, GHS-BUILT-H, `building:levels` of OpenStreetMap, and the roof photons of D-0009-02. None of them is in the report yet.
- **R5d, the lists**: the buildings that OpenStreetMap had on 2019-01-22 and the 2.5D data does not have in 2019, and the other way; and the buildings with a `start_date` after 2019. The report gives only the counts.

### D-0009-04: The 3.3 km² of "building with no outline" (medium)

This answers question 5 of the builder. I drew the map of 2019 (`no_outline_center.png`, `no_outline_bai_truoc.png`): gray is an outline of 2019, red is an outline that is out, and orange is a cell of 5 m that is more than half building in the raster of 2019 with no outline. There are two kinds of orange:

- **Thin bands along the sides of outlines.** These come from the shift: the raster and the outline do not agree to the last meter. They are not buildings.
- **Whole blocks with no outline**, mostly in the dense town east of Quang Trung. Overture Maps has no outlines for many small houses there. These are real buildings of 2019, and phase 2 (the far level of the whole town) will show holes there.

So the number 130 632 cells mixes the two. Measure only groups of cells that are 3 m or more from an outline, and at least 4 cells (100 m²) in one group. Give their count, their area, and a map. Then I decide how the town gets houses there (R1 says that a building of the raster with no outline is "Check").

### D-0009-05: The values of the presence and the heights (low)

This answers question 5 of the builder too.

- **The presence of 0.5** can stay for now.
- **8 pixels (2 m²) for a year** is too few for an outline of 50 m² to 100 m²: with a shift that is wrong by 1 m or 2 m, the pixels of the next house count. Use a part of the area of the outline (for example 30 %), with 8 pixels as the least.
- **The height of a building** is its value of 2019 only. The heights of one outline change by about 1 m from year to year (for example 5.5, 4.0, 4.5, 5.0, 6.0, 5.0, 3.5, 4.0 m): this is noise. Use the median of all the years from its first year on.

### D-0009-06: Large files in the repository (medium)

This answers question 4 of the builder. The branch adds about 64 MB of JSON (`atl03_ground.json` 26 MB, `overture.json` and `temporal.json` 20 MB, `buildings_2019.json` 16 MB), and its history also has the ATL03 file of the first run. If the branch goes to `main` as it is, each clone of the repository gets all of them, for all time.

- Keep the large raw files out of Git: a release asset of the repository (as `people-packs-1` of the people packs), with the SHA-256 of each file in a small manifest in Git. The tools and CI get them from the release. The workspace can download a release asset (AGENTS.md).
- Keep in Git only the small files that the build or a person reads: the reports, the maps, and a short form of the lidar (for example, for each 20 m of a track: the date, the median ground, the median roof, and the count).
- Make the history of the branch again before the merge to `main`, so that no large file goes into the history of `main`.

### D-0009-07: The sea floor of ATL24 and the mean sea level (a check for me)

R5c: ATL24 is 0.91 m over the intertidal heights (RMSE 2.06 m). The two sources do not use the same zero. ATL24 is over EGM2008 (the geoid), and the intertidal heights of plan 0005 are over the mean sea level of the tide model EOT20. In the South China Sea, the mean sea level is not at the geoid: the ocean models give a mean dynamic topography there. So much of the 0.91 m can be that offset, and not an error of either source. If that is so, the land of the game (Copernicus, over EGM2008) and its sea (over the mean sea level) have the same offset at the beach.

Before any change of the ground or the sea (R5b, phase 1b), compare the 0.91 m with a model of the mean dynamic topography (for example DTU22MDT or CNES-CLS22) at Bãi Trước, and write the result in the report.

## 4. The street photos (R5e, made on the branch of plan 0026)

See report 0026, section 9.4.

## 5. Status

Phase 1a is not done: D-0009-01 to D-0009-06. R5b (phase 1b) waits for plan 0026, as the plan says.

## 6. Audit 2: branch at `0038ab6` (2026-11-20)

The pictures of this audit are in [`0009/audit-2026-11-20/`](0009/audit-2026-11-20/).

### 6.1 Runs

| Check | Result |
|---|---|
| CI of `0038ab6` | Pass: run 302, 12 of 12 jobs. |
| The release `geodata-0009-1` | Each of the 48 files of the two manifests downloads in the workspace with `tools/geo/geostore.py`, and its SHA-256 agrees with the manifest. |
| The history of the branch | No file of more than 2.3 MB (`lidar_tracks.json`). |
| The data at the head | Read here with Python: the buildings of 2019, the 2.5D data of each outline, and the lidar of each product and year. |

### 6.2 What is correct

- **D-0009-01.** The lidar is kept by product and year, the guard is in the tool and its test, and the store has the data of the good run again (ATL03 ground photons 896 655, GEDI 1 122 shots). The report gives the numbers of the head.
- **D-0009-02.** 60 434 roof photons, and their check against the 2.5D heights.
- **D-0009-03.** The four maps, the four checks of the heights, and the lists of R5d.
- **D-0009-04.** The groups of at least 4 cells, 3 m or more from an outline: 2 714 groups, 98.5 ha. The map now shows whole blocks with no outline, not bands along the outlines.
- **D-0009-06.** The large files are assets of the release, with a manifest in Git, and the history of the branch has none of them.
- **D-0009-07.** ATL24 minus the intertidal heights is 1.02 m at Bãi Trước (0.88 m for all the points), and the mean dynamic topography of DTU22 is 1.16 m. So most of the offset is the height of the mean sea level over the geoid, not an error of a source. This is a good piece of work.

### 6.3 Defects

#### D-0009-08: 7 904 buildings of 2019 have no first year and no height (medium)

`buildings_2019.json` has 7 904 buildings with `first_year` null, and 7 902 of them have `height` null. Before D-0009-05 there were 4 670. The report does not say so: its median height leaves them out. My rule of D-0009-05 (30 % of the outline) did not say what to do when no year reaches it. In the 2.5D data, these buildings are of three kinds (`no_first_year.png`):

| Kind | Buildings | What it means |
|---|---|---|
| 8 pixels or more in a year up to 2019, but under 30 % of the outline | 2 116 | Most likely a building of 2019 (the old rule gave it a year). |
| 8 pixels or more only in a year after 2019 | 1 118 | Most likely a building after 2019: the old rule took it out, and now it is in 2019. |
| Fewer than 8 pixels in each year | 4 670 | The 2.5D data does not see it. The median area is 31 m² (70 m² for all the buildings). |

- The first year is the first year with 30 % of the outline. If no year has 30 %, it is the first year with 8 pixels or more. Its height is the median of its years from that year on.
- A building with fewer than 8 pixels in each year is not in `buildings_2019.json`. Write it in a list of its own with a map, with the status Check. A guess is not in the game.
- The report gives the count of each kind, and the heights with no null.
- A unit test for each kind.

#### D-0009-09: The guard keeps the ATL08 of a year that lost passes (medium)

ATL08 has 17 of the 30 passes of ATL03 of the same years. The years that the last run fetched (2018, 2021, 2025, 2026) have all their passes. The years that came from the earlier runs (2019 from `a36c84e`; 2020 and 2022 from `7d32458`; 2023 and 2024 from `a36c84e`) have one or two passes of four or five: 2020 has 3 segments for 48 543 ground photons of ATL03. The ATL03 ground photons get their class from ATL08, so ATL08 has these passes.

- A year is complete only when each product has the passes (the date and the track) that the other products of the same year have. The report gives the passes of each product and year, and the next run fetches each year that is not complete again.
- Fetch ATL08 of 2019, 2020, 2022, 2023, and 2024 again.
- A unit test: a year with fewer passes than ATL03 of the same year is fetched again.

#### D-0009-10: The new maps have no import file (low)

`buildings_2019.png`, `buildings_all.png`, `buildings_no_outline.png`, `buildings_out.png`, and `lidar_seafloor.png` in `data/geo/build/` have no `.import` file. The other maps there have one with `importer="keep"`. Without it, Godot imports each map as a texture and writes a new import file in the working copy. Add the import files.

### 6.4 Notes for the next phases

- **The zero of the heights (R5b).** The land of the game (Copernicus, over EGM2008) and its sea (the tide model, over the mean sea level) do not have the same zero: the mean sea level is about 1.0 m to 1.2 m over EGM2008 here (D-0009-07). So now the land is about 1.1 m too high against the sea. R5b uses one zero: the mean sea level. The heights over EGM2008 (the ground, the bare earth, ATL24, the lidar) take away the mean dynamic topography of DTU22 (1.16 m), and the report shows the beach of Bãi Trước before and after.
- **The banks next to the hall of report 0026.** In PT-71 the hall with the orange roof still has a slope of bare ground 3 m to 5 m high at each side. Copernicus is a model of the surface, with the buildings and the trees in it. The bare earth of D9 (phase 1b) is the correction for that; check the hall in PT-71 after it.
- **The heights of the buildings.** The checks do not agree: against the 2.5D heights, 3D-GloBFP is 3.70 m higher (median), GHS-BUILT-H is 3.95 m lower, and the roof photons are 1.22 m lower (RMSE 6.37 m). The roof photons are the only direct measure. I decide the heights of phase 2 from them.

### 6.5 Status

Phase 1a is not done: D-0009-08 to D-0009-10.

## 7. Audit 3: branch at `a6ffd2c` (2026-11-21)

### 7.1 Runs

| Check | Result |
|---|---|
| CI of `a6ffd2c` | Pass. |
| The data at the head | Read here with Python from the release `geodata-0009-1`. |

### 7.2 What is correct

- **D-0009-08.** 45 324 buildings of 2019 and 6 365 out, each with a first year and a height. The 4 670 buildings that the 2.5D data does not see are in the list `buildings_unseen`, with the status Check, and the build stops on a building of 2019 with no height.
- **D-0009-09.** ATL08 has the 30 passes of ATL03, and a year that loses a pass is fetched again.
- **D-0009-10.** The maps have their import files.

### 7.3 Defects

#### D-0009-11: Photons of clouds in the check of the roofs (low)

The RMSE of the roof photons went from 6.37 m to 17.55 m. The cause is one building: 5 photons of 2025-08-30 at 758 m over a roof of 6 m (clouds). Without the 10 differences of more than 50 m, the RMSE is 4.66 m. The other large differences are towers (a 2.5D height of 60 m to 90 m), where the photons fall on lower parts.

- Keep only the photons of a high signal confidence, and at most 150 m over the ground.
- Give the median and the median absolute difference with the RMSE, and give the towers (2.5D over 40 m) in a row of their own.

#### D-0009-12: A commit with another author (high, before the merge to `main`)

See report 0026, D-0026-43: the merge commit `8990b37`.

### 7.4 Status

Phase 1a is done when D-0009-11 and D-0009-12 are corrected. Phase 1b waits for plan 0026 to go to `main`.

## 8. Audit 4: phases 1b and 2, branch at `e3c983a` (2026-11-21)

The pictures of this audit are in [`0009/audit-2026-11-21/`](0009/audit-2026-11-21/). The sheets of PT-68 are on the branch in `docs/town/`.

### 8.1 Runs

| Check | Result |
|---|---|
| The merge of plan 0026 | `909901b` on `main`, a merge commit with my identity. The CI of `main` passes. Plan 0026 is "Built" and its status line names D-0026-46 to D-0026-48, Q29, and R19. |
| CI of `0184ded` | 15 of 18 jobs pass. Parts 5, 7, and 10 fail: PT-72 S1 (the box `hill`), PT-63 run 2, PT-33 run 2. |
| CI of `e3c983a` | The same three parts fail. Part 5 also fails PT-62 `cau_da_jetty` run 4: "the scenario takes more than 180 seconds", then "2 resources still in use at exit". The report of the builder does not have this (D-0009-21). |
| PT-68 `town_views` runs 1 and 2 (here) | Pass. The frames are the frames of the sheets. |
| PT-69 `town_budget` run 1 (here) | Low: 175 to 266 draw calls, 139 853 to 160 697 triangles, 730 MB to 737 MB of video memory. The same numbers as the builder. The report does not give the video memory. |
| PT-63 run 2 (here) | miếu Hòn Bà from 50 m: 44 %, as in CI. |
| PT-33 run 2 (here) | The same three values as in CI: 36 %, 0.61, 0.38. |
| PT-71 run 2 and PT-72 run 2 (here) | PT-71 passes. PT-72 S1 at 12:00 on Low: the saturation 0.06 from the photo, as in CI. |
| A walk of my own (here, Low, 10:00) | From the corner of S3 to the east along Trương Công Định and Phan Bội Châu to chợ Xóm Lưới: 80 m with the joystick, then five stops with a look ahead, to the left, and to the right ([`walk_s3_to_market.jpg`](0009/audit-2026-11-21/walk_s3_to_market.jpg)). |

### 8.2 What is correct

- **One zero for the land and the sea.** Each height over EGM2008 (Copernicus, GEDTM30, DeltaDTM, the lidar, ATL24) takes away the 1.16 m of DTU22 (`data/geo/ground.json`).
- **The half pixel.** The builder found that the ground of plans 0005 to 0026 was about 15 m west and north of its place: `rasterio.merge()` put the pixels of Copernicus on the edges of the box, and their centers are on whole arc seconds. At the correct place, the RMSE against the lidar ground goes from 4.50 m to 3.78 m. This is a good find.
- **The rule of the bare earth.** The choice of a model for each group by the RMSE against the lidar, the report with its maps, and DeltaDTM over 30 m as no data (not the value 30).
- **The boxes.** 45 324 boxes of `buildings_2019`, with the unseen buildings out, the walls that a neighbor hides, the roofs by the shares of the palette, and the colors read as sRGB. At the views of PT-69 on Low, a frame has at most 160 697 of 300 000 triangles. The range of 1 500 m comes from a measure (S5 had 299 733 triangles with 2 000 m).
- **The banks next to the hall** (section 6.4) are lower. 5 m behind the front of the hall, the ground at 25 m to 40 m to its sides was 4.5 m to 6.1 m over its level, and now it is 2.0 m to 4.1 m ([`hall_after_1b.jpg`](0009/audit-2026-11-21/hall_after_1b.jpg)). The rest is the slope of Núi Nhỏ, with no level for the lots at the sides of the hall: phase 3 (the lots) does it.
- **The photos of the views** have open licenses and credits, and the bus view says that it has no photo.
- The builder did not change a limit to make a check pass, and named each check that fails.

### 8.3 Defects

#### D-0009-13: The area of the showcase leaves out each building, also the buildings that nothing draws (high)

92 buildings of 2019 have their middle in the area of the showcase. The showcase draws 25 of them (16 under a model of World, 9 under a stand-in). The other 67 have no box and no stand-in ([`showcase_area_buildings.png`](0009/audit-2026-11-21/showcase_area_buildings.png), red). Commit `299621d` made this: "The area of the showcase draws its own buildings".

Among the 67 is the street of S3 to chợ Xóm Lưới. On my walk from the corner of S3, the first 80 m of Trương Công Định are empty ground, with Cảng vụ on one side (the walk, top row). This is the empty corner of my decision of report 0026, section 12.5, and phase 2 must correct it.

- Leave out a box only where a model, a stand-in, or a part of the showcase that a player walks on covers it (for example, more than 30 % of its outline). Else the box stays.
- A unit test: a building in the area with no model and no stand-in has a box. PT-72 S3 shows the boxes behind Cảng vụ.

#### D-0009-14: From Núi Nhỏ, the town stops at 1 500 m (high)

On Low the boxes stop at 1 500 m. Behind that line the ground pattern is a plain of pink brown, and the line shows (`docs/town/sheet_nui_nho_top.jpg`). The photo from the lighthouse shows the town to the coast of Bãi Sau, with its towers.

- In the direction of the frame of the lighthouse are 55 buildings of 45 m or more. 53 of them are farther than 1 500 m. Two of them are side by side in the middle of the frame, 90 m and 91 m high, 2.4 km away: the two towers of the photo.
- The towers are what make this view Vũng Tàu, and the lighthouse is on the hill of the homestay.

Correction:

- Each tall building (for example, 25 m or more: 191 in the whole area) shows to the end of the far range on each preset. Give the cost in PT-69.
- The far pattern of the town has the mean color of the boxes at its edge, so that no line shows. (Or a far level of the boxes, by blocks.)

#### D-0009-15: The boxes are too bright (medium)

The walls of the boxes have the colors of the paint of the palette: a mean value of 0.81, and 54 % are over 0.8. In the frame of the lighthouse at 12:00 the pixels of the town have a mean value of 0.73, against 0.60 in the photo, and 45 % are near white, against 18 % in the photo.

From far, a front is not its paint only: it has windows, balconies, shade, and the open ground floor of the shops. The photo also has many trees between the houses.

This is also a part of PT-33 run 2. In the view to the north from Núi Nhỏ, the boxes have a mean value of 0.78 and the far pattern 0.64 (the limit of the land is 0.40 to 0.55). So the report is not correct that the boxes do not cause these values.

- The far color of a wall is the mean of its front (with a share of dark for the windows and the ground floor).
- PT-68 compares the town of `nui_nho_top` with its photo: the mean value and the share of near white.

#### D-0009-16: Bàu Sen is not in the game (medium)

The photo from the lighthouse has the lake of Bàu Sen in the middle of the town. The game has no water on the land, and no plan has it (Bàu Sen, Bàu Trũng). The water areas of OpenStreetMap (`natural=water`) can be flat water at their level. Q9 asks where it goes.

#### D-0009-17: Núi Nhỏ keeps the model of the surface (medium)

ICESat-2 has 3 bins of ground on Núi Nhỏ, so each group of Núi Nhỏ keeps Copernicus, with the tops of its trees. On Núi Nhỏ (the cells over 20 m, in 700 m of its point), GEDTM30 is 3.1 m lower than Copernicus on average, and 10 % of the cells are 7.1 m lower or more. On Núi Lớn it is 3.9 m lower, and there the lidar chose GEDTM30.

The homestay, its hẻm, and the villas of phase 3 are on Núi Nhỏ, and the game puts its own trees on it. So the trees are two times in the hill.

- A group with fewer than 30 points takes the choice of the same land cover on the nearest zone with enough points (here Núi Lớn), and the report says so.

#### D-0009-18: Three views of PT-68 do not have the camera of their photo (medium)

- **Núi Lớn.** The photo is from the cable car over Bạch Dinh, to the south-east. The eye of the game is on the flat top, in a clearing, and the trees of its edge hide the town. The check counts 612 boxes "in the frame", because it counts the boxes in the frustum, also the boxes that do not show.
- **The Hải Đăng road.** The heading is 10°. From the eye, Núi Lớn is at 341°, so it is on the left of the frame. The photo does not have Núi Lớn, and it has the water of Bãi Sau on the right: its heading is about 30° to 45°.
- **The bus view** has no photo. The workflow "Street photos" (Mapillary, CC BY-SA 4.0) runs in CI and can make a contact sheet for this point.

Correction:

- The eye and the direction of each view come from its photo, as in the shots of plan 0026.
- The check counts the boxes that show (a ray or a depth test), not the boxes in the frustum.

#### D-0009-19: A crest of ground hides miếu Hòn Bà (medium)

The islet of Hòn Bà has an area of about 5 450 m² (about 80 m across). That is less than three cells of the 30 m DEM, so its shape is not data. From 50 m on the stairs, the stairs go up to a crest of ground and rocks, and the temple is behind it: the crest hides its lower half ([`mieu_hon_ba_50m.jpg`](0009/audit-2026-11-21/mieu_hon_ba_50m.jpg)). The ground of the islet moved 15 m with the half pixel, so the crest is now between the stairs and the temple.

- Keep the limit of 50 %.
- The ground from the top of the stairs to the temple is not higher than the base of the temple (as `level_places()` and `cut_stairs()` do for the other places).
- The sand at the sides of the stairs has the edge of a saw. Make it smooth.

#### D-0009-20: Square terraces in the ground of the town (low)

`terrain.remove_buildings()` (an opening with a square window, plan 0005) still runs after the bare earth. GEDTM30 has no buildings, so the opening only cuts each hump into a flat square.

On a profile of 1 km through the town north of chợ Xóm Lưới, 45 % of the cells are flat to 5 mm, with slopes of 1 m to 3 m between the squares ([`town_ground_squares.png`](0009/audit-2026-11-21/town_ground_squares.png)). Phase 3 puts the lots and the hẻm on this ground.

- No opening where the bare earth is used, or a round window that keeps the slope.

#### D-0009-21: A red part that the report does not have (low)

On the CI of `e3c983a`, part 5 also failed PT-62 (`cau_da_jetty` run 4, more than 180 s). The report said "I expect the same result". On `main` the same test took 838 s and passed; on the branch it took 851 s. So run 4 is near its limit.

- Split run 4 in two runs.
- The report names each part that fails.

### 8.4 The question of the builder: the limits

The builder asks if the limits of PT-33, PT-63, and the box `hill` of S1 stay, or if new limits come for the new ground. What I recommend:

- **PT-33: the limits stay.** They come from my photos (D-0005-09). D-0009-14 and D-0009-15 are the look of the town from the hills, and that look is the review of phase 2. Run PT-33 again after them.
- **PT-63: the limit stays.** D-0009-19 is in the ground of phase 1b.
- **PT-72, the box `hill` of S1:** this is the look of the hill, and it waits for the later pass of the look (report 0026, section 12.5). The values change near the limits from run to run (6 of 8 runs pass). Q8 asks what to do until then.

### 8.5 Questions for me

- **Q8.** Until the later pass of the look, does PT-72 stop the check of the box `hill` of S1 (it writes its values in the log, and the plan names it as open)? I recommend yes: the box is noisy, the photo of S1 is from 2014, and the villa of 2019 in the old box may be newer.
- **Q9.** Does the water of the land (Bàu Sen, Bàu Trũng, D-0009-16) come in phase 2 now? I recommend yes: it is small, and the view from the lighthouse needs it.
- **Q10.** The builder proposes the limits of the draw calls of PT-69: Low 600, High 2 000, as PT-73. R10 says that I approve them. Phase 3 adds the near houses, with up to 6 materials each (R7a).

### 8.5a Answers (2026-11-21)

- **Q8: yes.** Until the later pass of the look, PT-72 does not fail on the box `hill` of S1. It writes its values in the log, and the plan names the check as open.
- **Q9: yes.** The water of the land (D-0009-16) comes in phase 2 now.
- **Q10: yes.** The limits of the draw calls of PT-69 are Low 600 and High 2 000.

### 8.6 Notes for phase 3

- In phase 2 the boxes show from 0 m, with no collision, so on my walk I went through them. This is not a defect of phase 2: the near and mid levels come in phase 3 (R6), and then the far level starts after the mid range.
- With the town, S5 of PT-73 has 281 874 of 300 000 triangles on Low. Phase 3 has little room there.
- On the walk, the hẻm near chợ Xóm Lưới (Nguyễn Công Trứ, 3.5 m) has no road surface, and the ground between the boxes is bare earth. The hẻm and the lots of phase 3 give the floors.

### 8.7 Status

Phases 1b and 2 are not done: D-0009-13 to D-0009-21. Phase 3 waits for my look at the views of PT-68 after the corrections.

## 9. Audit 5: the corrections of audit 4, branch at `f521f15` (2026-11-22)

The pictures of this audit are in [`0009/audit-2026-11-22/`](0009/audit-2026-11-22/). The sheets of PT-68 are on the branch in `docs/town/`.

### 9.1 Runs

| Check | Result |
|---|---|
| Commits | `e137aac` to `f521f15`, 23 commits, all with my identity. |
| CI of `f521f15` | 16 of 18 jobs pass. Part 10 fails PT-33 run 2. The job "Models of World" fails: the factory of World answers HTTP 422 for the near level of `scooter_tay_ga_1` (D-0009-25). |
| CI of `main` at `d610863` (my report, no code) | Part 11 failed `soak` run 2 at 2400×1080: "the player left the floor or is in a wall", in the solid of the cart `Cart_mia` of the test hẻm (D-0009-26). The run of `c88908f` before it passed. |
| PT-68 run 1 (here) | Passes. 1 334 of 1 776 boxes in the frustum show from the top of Núi Nhỏ; 28 boxes are left out in the whole area. Bàu Sen shows. The town 0.59 and 3 % near white, the photo 0.61 and 16 %. No line at the end of the boxes (0.62 and 0.62). |
| PT-33 run 2 (here) | The same values as CI: `nui_lon_south_east` 39 % (40 % or more), `nui_nho_north` 0.58 (0.40 to 0.55). |
| PT-63 run 2 (here) | Passes: 56 % at 50 m. The stairs go up to the temple, and their sides are smooth. |
| My walk from S3 to chợ Xóm Lưới (here) | The boxes are along Trương Công Định now ([`walk_after.jpg`](0009/audit-2026-11-22/walk_after.jpg)). |

### 9.2 What is correct

- **D-0009-13.** 28 boxes are left out in the whole area of the showcase, not 92. S3 shows 7 boxes behind Cảng vụ, and my walk has houses along the street.
- **D-0009-14.** The buildings of 25 m or more show to 6 000 m on each preset, for 29 meshes and 2 434 triangles. The two towers of the photo of the lighthouse are in the view. My count of 191 was wrong: I measured the box from its base on the lowest ground, so a box on a slope was too high. The builder counts 166 buildings of 25 m or more, and that is correct.
- **D-0009-15.** In the frame of the lighthouse the town is 0.59, against 0.61 in the photo.
- **D-0009-16.** Bàu Sen, Bàu Trũng, and the other water of the land are in the game, flat at their level.
- **D-0009-17.** Núi Nhỏ takes the choices of Núi Lớn: on 91.9 ha the ground is 3.08 m lower on average. The builder also found pits of up to 90 m from DeltaDTM at the edge of its clip of 30 m. In audit 4 (section 8.2) I wrote that DeltaDTM over 30 m was correct; that was wrong, and this is a good find.
- **D-0009-18.** Each view has the eye and the direction of its photo. The view from Núi Lớn now has Bạch Dinh, the bay, and Núi Nhỏ as in the photo. The check counts the boxes that show (a ray test).
- **D-0009-19.** See 9.1.
- **D-0009-20.** On a profile of 1 km in the town, 27 % of the cells are flat (53 % before). The area of the showcase keeps the ground of phase 1b, because its parts, models, and checks were made on it. I accept this until the later pass of the look of plan 0026, and that pass brings the area to the new filter.
- **D-0009-21.** Run 4 of PT-62 is two runs.
- **PT-69:** Low 189 to 257 draw calls, 113 930 to 137 285 triangles, 738 MB to 745 MB; High 327 to 388 draw calls, up to 871 188 triangles, about 1 900 MB.

### 9.3 Defects

#### D-0009-22: The data has no buildings on a large part of the street fronts (high)

In the bus view, 11 boxes show: the boxes stand 20 m to 40 m back from Bình Giã, with open ground between. The photo has a row of shops at the sidewalk. Overture has 8 outlines in 40 m of the eye, so this comes from the data and not from the build ([`bus_view_outlines.png`](0009/audit-2026-11-22/bus_view_outlines.png)).

I measured each main street near chợ Xóm Lưới: each 5 m, on each side, is there a building from 2 m to 14 m past the edge of the road?

| Street | A box of 2019 | No box, but the 2.5D raster of 2019 has a building | Neither |
|---|---|---|---|
| Ba Cu | 63 % | 14 % | 23 % |
| Lê Lai | 59 % | 20 % | 21 % |
| Xô Viết Nghệ Tĩnh | 54 % | 17 % | 29 % |
| Phan Chu Trinh | 51 % | 16 % | 32 % |
| Trương Công Định | 48 % | 21 % | 31 % |
| Nam Kỳ Khởi Nghĩa | 47 % | 17 % | 36 % |
| Bình Giã | 44 % | 28 % | 28 % |

A shop street of Vũng Tàu has a house on almost all of its front. Part of the gap is in the data: the groups of cells with a building and no outline (D-0009-04, 98.5 ha) are on the street fronts. The rest has nothing in the data, perhaps under the trees of the street (the photo of the bus view has large trees on each side).

- Phase 2: a box for each group of cells of the 2.5D raster of 2019 with a building and no outline that touches a street, with the height of the raster (`unmatched_2019` keeps only the part of each cell, so the build reads the heights again).
- The rest of the gap: Q12.

#### D-0009-23: The far town is one flat color (medium)

Past the range of the boxes, the ground shader draws the far town with the mean color of the boxes and no pattern. From the hills it is a grey plain with dark green patches, and the tall boxes stand alone on it ([`far_town_flat.jpg`](0009/audit-2026-11-22/far_town_flat.jpg)).

The two values of PT-33 run 2 come from it. In the view to the north from Núi Nhỏ, the plain has a mean value of 0.66, the brightest part of the land (the boxes 0.63). Its saturation is 0.04, so the town from Núi Lớn has 39 % of its points with a saturation over 0.2.

- The far town keeps a pattern of roofs and shade (the pattern of D-0005-09), with its mean at the mean of the boxes at the edge, so that no line shows.
- The limits of PT-33 stay.

#### D-0009-24: The towers have the colors of the tube houses (medium)

92 of the 166 tall buildings have a wall with a saturation over 0.15: teal (`#1894A5`), green, blue, and brown. These are the bold colors of the house kit. The towers in the photos are white, cream, grey, or glass. Each tower takes a color of a palette of towers from the photos.

#### D-0009-25: The job "Models of World" fails because of a change in World (medium)

On 2026-11-22 World put a guard of 60 MB on the memory of the factory (World #76). The test `test_the_two_sources_give_the_same_bytes` (R4 of plan 0023) now gets HTTP 422 for the near level of `scooter_tay_ga_1`: "needs more memory than the factory has (60 MB): order its parts list". This model is in the catalog of World, so its files are in `priv/models/` of World, but the factory builds it again. Q13.

#### D-0009-26: The player can be in the solid of the cart of the test hẻm (low)

On `main` (`d610863`), `soak` run 2 at 2400×1080 put the player in the solid of `Cart_mia` (action 36). The run of `c88908f` passed, so it is not each time. A player can be stuck there. Find the action that puts the player there, and add the step to the soak.

### 9.4 Notes

- **The sand bank in the bay** (the view from Núi Lớn). The builder saw a pale bank of sand in the bay that the photo does not have. Check the sea level of the tide at 12:00 on 22 January 2019, and the intertidal heights there against an image of Sentinel-2 at the same tide. The later pass of the look corrects it.
- **The mainland on the horizon.** The photos from the lighthouse and from the Hải Đăng road have the hills of the mainland on the horizon (Long Hải, Núi Dinh). The game has none. Q14.
- **The trees of the hills.** From the north of Núi Nhỏ, the ground under the trees is bright grass with the trunks in view, where the photos have a dark canopy. This is the look of the hill of Q8, and it waits for the later pass of the look.

### 9.5 Questions for me

- **Q11.** The limits of PT-33 stay (they come from my photos, D-0005-09), and D-0009-23 is the correction. If a value is still out after it only because of the trees of the hills, does PT-33 run 2 write the value and not fail until the later pass of the look, as Q8? I recommend yes.
- **Q12.** Where the data has no building on the front of a shop street (21 % to 36 % of the main streets near chợ Xóm Lưới), does phase 3 put a row of tube houses there, with the status Check, and the street photos of Mapillary as the source where they exist? I recommend yes: the streets of the market are the center of the game.
- **Q13.** For D-0009-25: I ask World for the files of its catalog at a commit with no build (the files of `priv/models/`). Until World does it, does the test of R4 compare only the levels that the factory gives, and write each level that it refuses in the log? I recommend yes.
- **Q14.** Do the hills of the mainland on the horizon come in phase 2 (a far mesh of the Copernicus DEM, to about 30 km)? I recommend yes: each view from the hills of Vũng Tàu has them.

### 9.5a Answers (2026-11-22)

- **Q11: yes.** The limits of PT-33 stay, and D-0009-23 is the correction. If a value is still out after it only because of the trees of the hills, PT-33 run 2 writes the value and does not fail until the later pass of the look.
- **Q12: yes.** Where the data has no building on the front of a shop street, phase 3 puts a row of tube houses there, with the status Check, and the street photos of Mapillary as the source where they exist.
- **Q13: yes.** I ask World for the files of its catalog at a commit with no build. Until World does it, the test of R4 compares only the levels that the factory gives, and writes each level that it refuses in the log.
- **Q14: yes.** The hills of the mainland on the horizon come in phase 2: a far mesh of the Copernicus DEM, to about 30 km.

### 9.6 Status

Phases 1b and 2 are not done: D-0009-22 to D-0009-26, and the work of Q13 and Q14. Phase 3 waits for my look at the views of PT-68 after the corrections.

## 10. Audit 6: the corrections of audit 5, branch at `e4b7ebe` (2026-11-22)

### 10.1 Runs

| Check | Result |
|---|---|
| Commits | `cdc3aec` to `e4b7ebe`, all with my identity. |
| CI of `e4b7ebe` | Test and Export pass. On the way, PT-73 S5 and `parked_rows` went over 300 000 triangles with the mainland at 400 m on Low (now 800 m: S5 has 292 533). |
| PT-68 run 1 (here) | Passes. From the top of Núi Nhỏ: 1 488 boxes show; Bàu Sen shows; the town 0.60 and 4 % near white (the photo 0.61 and 16 %); 32 towers with a saturation of 0.11 (the photo 0.05); the hills of Long Hải show at 21.6 km; no line at the end of the boxes (0.63 and 0.64). The bus view: 2 boxes nearer than 40 m. |
| PT-33 run 2 (here) | `nui_lon_south_east` 47 % (passes). `nui_nho_north` 0.59: open under Q11, because with the trees of the hills at the value of the canopy of the photo it is 0.53. The trees of the hills are 0.49 in the game and 0.16 in the photo. |
| PT-69 run 1 (here) | Low: 228 to 258 draw calls, 123 734 to 156 472 triangles, 728 MB to 736 MB. The tall boxes: 29 meshes, 2 590 triangles. |
| My stops on Bình Giã and from S3 to chợ Xóm Lưới (here) | Boxes along both streets. At the eye they are the far level, with no shadow and no floor of a street: phase 3 gives these. |

### 10.2 What is correct

- **D-0009-22.** 1 304 boxes from the raster (58.0 ha, a median height of 7.0 m) at the streets, with the source `raster`. The street fronts with a box go up 1 to 13 points on each street; the "neither" column stays, and the rule of Q12 for phase 3 is in plan 0009.
- **D-0009-23.** The far town has its pattern of roofs and shade again, with no line at the end of the boxes. From the lighthouse the town now has the look of the photo: the lake, the towers along the coast, and the hills of the mainland on the horizon (`docs/town/sheet_nui_nho_top.jpg` on the branch).
- **D-0009-24.** The towers have the colors of the photos; 4 of 32 in the frame are over a saturation of 0.15.
- **D-0009-25.** World now gives the files of its catalog with no build (World #83), and the test of R4 writes a level that the factory refuses in the log. It refused none.
- **D-0009-26.** A cart waits while the player stands in its place, and the soak checks it.
- **Q14.** The mainland is one mesh with no shadow: 3 840 triangles on Low, 14 572 on High.

### 10.3 Defects

#### D-0009-27: Some boxes of the raster are on roads (low)

953 of the 1 304 outlines of the raster are not valid polygons (an edge goes out and back on itself), and the town makes 472 of them rectangles. With the widths of `roads.json`, 20 boxes of the raster in the town have more than 10 % of their outline on the surface of a road (the most: `raster-745-1537`, 671 m² of 2 703 m²).

- Make each outline a valid polygon before the town simplifies it, and cut the surfaces of the roads after the simplification.
- A unit test: no box of the raster has more than 10 % of its outline on a road.

#### D-0009-28: A soak run that fails one time and that nobody can repeat (low)

Soak run 8 at 2400×1080 failed one time: the player was 0.25 m over the floor of the hẻm, with no solid near. The builder could not make it again, and the soak now writes the clock and the height 10 frames later. Keep it open until a run gives these facts.

### 10.4 Notes for phase 3 and the later pass of the look

- **The trees of the hills** are three times as bright as the canopy of the photos (0.49 against 0.16). This is the one cause of the open value of PT-33 and of the box `hill` of S1 (Q8, Q11).
- **The town is a little dull**: 4 % near white against 16 % in the photo, with the same mean value. The near level of phase 3 has its own colors, so look at it again then.
- **At the eye**, the boxes are walls with no windows, no shade, and no floor of a street between them, and the player goes through them (section 8.6). Phase 3 replaces them near the eye.
- **Big boxes of the raster**: 123 boxes of the raster are 1 000 m² or more (one of 5 300 m²), each with one height: a row of houses as one block. Phase 3 cuts them into lots.
- **World plan 0020** (a tint for each copy, a finish with no image, and the surfaces of windows, panels, and corrugated sheets) is for the houses of phase 3. It waits for my approval in World.

### 10.5 Status

Phase 1b and phase 2 are ready for my look at the views of PT-68. D-0009-27 and D-0009-28 are low, and the builder can correct them at the start of phase 3.

### 10.5a My decisions (2026-11-22)

- **Phase 3 starts now.** First D-0009-27 and D-0009-28. Then the houses of World, near and mid (R7 to R9), on the streets between Bãi Trước and chợ Xóm Lưới, with the rule of Q12 for the street fronts.
- **I approve World plan 0020**, with two additions that World writes in the plan when it sets its status:
  - **The profile of `corrugated` (D10).** A sheet has `round` ribs or `square` ribs. Most metal roofs in Vietnam have square ribs (sheets of 5, 9, or 11 ribs on a width of 1 070 mm), not only the round ribs of 76 mm and 18 mm ([Tôn thép Hoàng Phúc](https://www.tonthephoangphuc.com/cac-loai-song-ton-pho-bien), status Source). The profile, the pitch, and the depth of each roof come from its photos.
  - **`_FINISH` in Godot (D6).** Godot 4.7.2 reads `COLOR_0` with its alpha, but no attribute whose name starts with an underscore: its glTF import reads only `POSITION`, `NORMAL`, `TANGENT`, `TEXCOORD_0` to `TEXCOORD_7`, `COLOR_0`, `JOINTS_0`, `JOINTS_1`, `WEIGHTS_0`, and `WEIGHTS_1` (`modules/gltf/gltf_document.cpp` at `4.7.2-stable`). So a new open question with its answer: World writes `_FINISH` as the glTF format says, and Vũng Tàu reads it in its import, as it reads `_COLOR_0` (Q3).
- **What Vũng Tàu does for plan 0020, in phase 3:**
  - The plugin `addons/gpu_instancing/` reads `_COLOR_0` (the tint of each copy) when step 1 of World plan 0020 is on `main` of World.
    - Changed (2026-11-23): step 1 is on `main` of World (#92, `ecdab33`). A copy has its tint in one of two forms (World `docs/format.md`, "The copies" and "The instances"). A copy that is a node of its own has `extras.tint` (`#rrggbb`, sRGB). Godot 4.7.2 puts the extras of a glTF node in the metadata `extras` of its node in the scene (`merge_meta_from()` in `modules/gltf/gltf_document.cpp`). 16 copies or more of one mesh are one node with instances, with `_COLOR_0` (linear values) and `SCALE` for each copy. The plugin already reads `SCALE`.
    - World applies the tint to all the parts of a copy (plan 0020, D1), and its review page shows that. In this game, the tint is the paint of the walls only: the plaster of `house_walls`. Brick (`brick_ong`), glass, metal, the roof, and the tiles keep their colors. A test: a street of ten copies with ten tints, and the glass and the roof of each copy have the same color.
  - The import gives `_FINISH` to Godot, and the materials of `data/world/materials.json` read the roughness, the metal, and the glow from it, and the occlusion from the alpha of `COLOR_0`. No material uses the alpha of `COLOR_0` for transparency.
  - Note: the import of Godot makes each mesh again (`SurfaceTool.index()`), so the order of the points changes. A plugin cannot add the values of `_FINISH` after the import. It must give them to Godot in `_import_preflight` (after the accessors, before the meshes), for example as `TEXCOORD_2` and `TEXCOORD_3`, which Godot puts in `CUSTOM0`.
    - Changed (2026-11-23): step 2 is on `main` of World (#94, `b2eeab9`; the fast clock #95, `acbca48`). `_FINISH` is a `VEC3` of the component type `UNSIGNED_BYTE`, `normalized`, with a `byteStride` of 4 (the roughness, the metal, the glow; a byte of 255 is 1.0). The import divides each byte by 255. `COLOR_0` has four floats (linear), and the alpha is how open the point is.
    - Only a level with a `budget` and no `bake` has these values. At `acbca48` no model of the catalog has `_FINISH`. A house of phase 3 gets a far level with no image when its order of `street_house` has `"bake": {"near": 1024, "mid": 512}` (World `docs/format.md`). The far GLB of the test house of World is then 38 664 bytes in place of 92 412 bytes, but the windows of its upper storey are gone at far until step 3 (D11). The pictures of World (2026-11-23) show it: at the size of a far house on the screen (about 30 pixels high), the house with its image shows its windows and its door by day, and the house with no image is a white box with one point of light. So until step 3, the houses of phase 3 keep the image at each level (the default of the rules). After step 3, phase 3 measures both forms again (the size of the pack, and the look at 40 m to 150 m) before it chooses.
    - The version of a rule of World comes from the source of its modules: this step gives a new hash to most orders, one time. The update of the lock after this step gets new files for most models.
    - My audit of step 2 (2026-11-23) found that the cut of a level with a bake changed too: the far level of `house_edits` lost its chimney and its step (95 % of its surface within 18.2 cm of the near level, before 3.7 cm), and the far level of `hai_dang_vung_tau_edits` became worse. Vũng Tàu uses neither model. The far levels of the three rows of Quang Trung changed by a small amount. The outline check of PT-56 (`tools/world/outlines.py`, report 0026, D-0026-32) runs on each new lock.
    - Changed (2026-11-25): World corrected the cut (#96, `e1ddbef`): a level with a bake has the cut of before step 2 again (85 of the 88 files are the same bytes as before step 2), the far level of the lighthouse has its lamp room on its tower, and a check of the shape of each changed model runs in the CI of World (`scripts/shape.mjs`). My measure agrees.
    - Step 3 is on `main` of World (#97, `d2c1ac9`): the surfaces `windows`, `panels`, and `corrugated`. The house rules use them, so the three rows of Quang Trung, `day_pho_vung_tau`, and `nha_pho_2_tang_vung_tau` have new files: the windows have panes and frames at each level, and some windows are lit (about half of the glass leaves of an upper storey, by the seed). The shape of each level did not change (at most 3.3 cm at the near level, from the panes).
    - Open (2026-11-25): a lit window has the color of its light in its base color, so it is cream by day too. In daylight a window with a light on behind it looks dark, as its neighbors. Vũng Tàu has a day and a night, so the update of the lock to step 3 waits for this correction. My decision (2026-11-25): World corrects it before step 4 (the color of the glass by day, and the color of the light only in the glow), together with the light of a level with no image (below). Then World builds step 4, which I approve. I do not send the Workers Logs of World: the 16 entries of the history of the edits of 2026-11-18 to 2026-11-21 stay in its quarantine, and no model needs them.
    - The pictures of World of step 3 (2026-11-25): with an image, the far level of a tube house keeps its windows and its lit window, and the far level of a tower of 40 storeys shows its lit windows at night. With no image, the far level of the tower is one gray by day and has no light at night: a point has the mean color times the mean glow, and that is much less than the mean of the light. So the far houses of phase 3 keep their image (the default of the rules) after step 3 too, until World corrects this.
