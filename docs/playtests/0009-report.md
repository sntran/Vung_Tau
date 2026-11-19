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
