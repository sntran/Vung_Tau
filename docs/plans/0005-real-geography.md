# 0005 Real geography of Vũng Tàu

| Field | Value |
|---|---|
| Status | Approved |
| Branch | `feat/0005-real-geography` |
| Depends on | 0004 (status "Built") |

## 1. Goal

The player walks in first person on the real ground of Vũng Tàu: the real hills, the real coast, the real beaches, and the real roads.

All shapes in this plan come from open data. Nothing comes from photos or from an artist. Plan 0006 adds the known structures (for example Tượng Chúa Kitô Vua, Hải đăng Vũng Tàu, Bạch Dinh). Plan 0007 makes houses and puts them on the lots between the roads. This plan prepares the data for these two plans.

## 2. Out of scope

- Buildings and landmarks. This plan only finds their positions and their lots in the data.
- People, cars, and scooters.
- Swimming, and boats that move. (R13a puts boats at anchor on the sea.)
- The walk to Miếu Hòn Bà, the Vi Ba road activities, and the shops. Later plans add them. This plan only prepares their ground, their paths, and the tide.
- A change to the hẻm of plans 0001 and 0002. That hẻm stays the main game scene until plan 0009. This plan makes a separate scene.

## 3. Data sources

| Data | Source | License | What we use |
|---|---|---|---|
| Roads, coastline, beaches, water, land use, names, building outlines | [OpenStreetMap](https://www.openstreetmap.org) | ODbL 1.0 | Shapes, names, road types, road widths |
| Ground height | [Copernicus DEM GLO-30](https://documentation.dataspace.copernicus.eu/APIs/SentinelHub/Data/DEM/resources/license/License-COPDEM-30.pdf) | Copernicus DEM license (free, also for commercial use, with notices) | Height of the land, 30 m grid |
| Ground materials (sand, grass, rock, asphalt, concrete) | [Poly Haven](https://polyhaven.com) or [ambientCG](https://ambientcg.com) | CC0 | Scanned textures of real surfaces |

Required notices. Show them on a "Credits" screen in the game and in `assets/CREDITS.md`:

- OpenStreetMap: "© OpenStreetMap contributors". The OSM data that we change or extend is a Derivative Database. Keep it in `data/geo/` under ODbL 1.0, with a `LICENSE` file in that folder. ([OSMF licence FAQ](https://osmfoundation.org/wiki/Licence_and_Legal_FAQ))
- Copernicus DEM, for changed data: "produced using Copernicus WorldDEM-30 © DLR e.V. 2010-2014 and © Airbus Defence and Space GmbH 2014-2018 provided under COPERNICUS by the European Union and ESA; all rights reserved". Also add: "The organisations in charge of the Copernicus programme by law or by delegation do not incur any liability for any use of the Copernicus WorldDEM-30".

## 4. Decisions

| ID | Decision | Reason |
|---|---|---|
| D1 | Only CI downloads the source data. A GitHub Actions workflow downloads it, processes it, and commits the result to `main`. | The development workspace cannot reach OpenStreetMap, the DEM storage, or the texture sites. GitHub Actions runners can. |
| D2 | Commit the raw extracts (small, clipped to the play area) and the processed files. | Then the workspace can run the processing again without a download. |
| D3 | The processing is Python in `tools/geo/`. Use `numpy`, `rasterio`, `pyproj`, `shapely`, and `osmium` from PyPI. | PyPI is reachable in the workspace and in CI. These packages read GeoTIFF and OSM data. |
| D4 | Projection: UTM zone 48N (EPSG:32648). The game origin is the center of Bãi Trước, rounded to 10 m. Game X is east, game Y is up, game −Z is north. 1 unit is 1 m. | Vũng Tàu is in UTM zone 48. The play area is less than 15 km wide, so 32-bit floats are accurate enough. |
| D5 | The play area is the south part of the peninsula: Núi Lớn, Núi Nhỏ, Bãi Trước, Bãi Sau, Mũi Nghinh Phong, and Bãi Dâu. The first bounding box is latitude 10.30° to 10.42° N and longitude 107.05° to 107.13° E. The fetch script must check that all landmarks of `data/geo/landmarks.json` are in the box and report the true extents. | It contains the places that I named. Q1 confirms the box. |
| D6 | The ground is in square chunks of 256 m. Near chunks (within 300 m) use a 2 m grid. Far chunks use an 8 m grid or a 16 m grid. Each chunk has a `HeightMapShape3D` for collision at the 2 m grid when it is near. | The full area is too large for a phone at full detail. |
| D7 | The 30 m DEM is smooth. Resample it to the 2 m grid with bicubic interpolation. Then make the ground flat under roads, and make a smooth slope under beaches down to sea level. | A 30 m grid gives hills, but roads and beaches need exact local shapes. |
| D8 | The sea is one water surface at height 0 with a water shader: waves, reflection of the sky, and foam near the coast. Foam uses a texture of the distance to the coastline. | Code can make a sea that looks real. |
| D9 | The sky is `PhysicalSkyMaterial`. The sun position comes from the real latitude of Vũng Tàu and the game clock. | A real sun angle for a real place. |
| D10 | The game shows Vũng Tàu today, as OpenStreetMap shows it. | The player is a traveler from the United States who visits Vũng Tàu today. |
| D11 | The homestay is in a real hẻm, but the homestay, its family, and its neighbors are fictional. Do not use a real house number, a real family name, or a real business name. | A real place for the player, with respect for the people who live there. |
| D12 | The sea level follows the real tide at Vũng Tàu. CI computes the tide constituents for Vũng Tàu from the open global tide model EOT20, with the Python package `pyTMD`. The builder checks the license of EOT20 before use (CC BY 4.0 is expected), and adds its notice to the credits screen and `assets/CREDITS.md`. The game computes the sea level from these constituents and the game date and time. | Miếu Hòn Bà can be reached on foot only at low tide. The tide at Vũng Tàu is mixed, mainly semi-diurnal, with a mean range of about 2.5 m ([Vimaru JMST](https://jmst.vimaru.edu.vn/index.php/jmst/article/download/891/646/1911)). A fixed sea level cannot show this. |
| D13 | The game has a real calendar. Day 1 is a real date. The Clock app of the phone (plan 0003) shows the solar date and the lunar date (âm lịch). Compute the lunar date with the Vietnamese rules: the new moon and the solar terms in the time zone UTC+7, not UTC+8. | Tides, festivals, and the day of rằm (the 15th of the lunar month) depend on the date. People in Vietnam plan by the lunar date. The Vietnamese calendar uses UTC+7, so a month can start one day earlier than in the Chinese calendar. |

## 5. Requirements

### Data pipeline

- **R1.** `data/geo/landmarks.json` lists the places to find, with their Vietnamese names, other names, and the OSM tags to search. Put in at least:
  - Beaches and capes: Bãi Trước, Bãi Sau, Bãi Dâu, Mũi Nghinh Phong.
  - Hills: Núi Lớn, Núi Nhỏ.
  - Structures: Tượng Chúa Kitô Vua, Hải đăng Vũng Tàu, Bạch Dinh, Tượng Đức Mẹ Bãi Dâu, Miếu Hòn Bà (on the islet Hòn Bà), Chùa Tam Bảo (also called chùa Khỉ, on the Vi Ba road).
  - Roads: đường Vi Ba (the road up Núi Lớn), and the road from Bãi Trước to the lighthouse.
  - Town anchors: the main bus station (Bến xe Vũng Tàu), the old markets, the big roundabout, and Ngã Năm.

  I can add names. The town anchors have been in the same place for a long time. They help me check that the map is correct.
- **R2.** `tools/geo/fetch.py` (CI only) downloads:
  - The OSM data for the bounding box, through the Overpass API. If the Overpass API fails, it downloads the Vietnam extract from Geofabrik and clips it with `osmium extract`.
  - The Copernicus GLO-30 tile or tiles that cover the box, from the public AWS bucket `copernicus-dem-30m`. Clip them to the box.
  - The ground textures in R12.
- **R3.** `fetch.py` writes `data/geo/raw/manifest.json`. For each file, it records the source URL, the download date, the SHA-256, and the license.
- **R4.** `tools/geo/build.py` (CI and workspace) reads `data/geo/raw/` and writes `data/geo/build/`:
  - Height chunks as 16-bit PNG files with a JSON file for the scale and the offset.
  - The land mask and the coastline.
  - Beach polygons.
  - Roads as center lines with: OSM ID, type, name, width, surface, and the flag `hem` for small alleys.
  - Blocks: the areas between roads, without the road surfaces. Mark each block that has OSM building outlines.
  - Landmarks: position, outline (when OSM has one), height above sea, and the OSM ID.
- **R5.** Road width: use the OSM tag `width` when it exists. Else use the table in `data/geo/road_widths.json`. Put the first values in the table. Then I can correct them. Mark as `hem` each road of type `service`, `footway`, `path`, `alley`, or `residential` with a width of 4 m or less.
- **R6.** `build.py` writes `data/geo/build/report.md` with: the true extents, the number of roads of each type, the total road length, the number of blocks, the number of buildings, each landmark (found or not found), and each problem with the data.
- **R6a.** `build.py` finds the town anchors by type, because their names in OSM can differ from the names that people use. It lists every bus station (`amenity=bus_station`), every market (`amenity=marketplace`), every roundabout (`junction=roundabout`), and every junction where five or more roads meet. It draws `data/geo/build/anchors.png`: a map of the town with each candidate as a number. The report lists the numbers with the OSM names. I write the correct Vietnamese names into `landmarks.json`.
- **R7.** `data/geo/overrides.json` holds corrections to the OSM data (for example a missing hẻm). `build.py` applies them after it reads the OSM data. Each correction has a reason.
- **R8.** `.github/workflows/geodata.yml` runs by hand (`workflow_dispatch`). It runs `fetch.py` and `build.py`. When a file changes, it commits to `main` with the identity in `CONTRIBUTING.md` and the message "Update the geodata". It uploads `report.md` as a CI artifact.

### The homestay hẻm

- **R8a.** `build.py` finds the homestay hẻm with these steps:
  1. Find the lighthouse on Núi Nhỏ (`man_made=lighthouse`, name "Hải đăng Vũng Tàu").
  2. Find the road that goes from the coast road at Bãi Trước up to the lighthouse. Use the shortest path in the road network.
  3. Go up this road from the bottom. Find the first curve: a change of direction of more than 45° in 60 m or less.
  4. At the end of this curve, find the hẻm that leaves the road and goes straight on, in the direction that the road had before the curve (±30°).
  5. Record this hẻm as `homestay_hem`, with the residential blocks along it, in `data/geo/build/homestay.json`. The hẻm has the slope of Núi Nhỏ on one side and one row of houses on the other side, and no shops (first-hand, 2026-10-24). The report says which side is the slope.
- **R8b.** `build.py` draws `data/geo/build/homestay_area.png`: a top-down map of 300 m around the hẻm, with the roads, their names, the lighthouse road, and the hẻm in a strong color. I confirm the hẻm on this map.
- **R8c.** If step 4 finds no hẻm, or more than one, the report lists each candidate with its OSM ID, and the map shows each candidate with a number.

### Tide and calendar

- **R8d.** `tools/geo/tide.py` (CI only) computes the amplitude and the phase of each tide constituent of EOT20 at Hòn Bà and at Bãi Trước. It writes `data/geo/build/tide.json` with the constituents, the datum (mean sea level), the source, and the license. It also writes 200 test values (time and sea level) for the unit tests.
- **R8e.** `tide.py` compares its amplitudes with the published values for the Vũng Tàu station: M2 0.778 m, K1 0.574 m, O1 0.421 m, S2 0.302 m ([Vimaru JMST](https://jmst.vimaru.edu.vn/index.php/jmst/article/download/891/646/1911)). The report shows the difference for each one. A difference of more than 20% is a problem in the report.
- **R8f.** The game computes the sea level with the same constituents and the nodal corrections. The result must agree with the test values within 0.02 m.
- **R8g.** The DEM has no sea floor. Make the near-shore sea floor: from the coastline, slope down to −4 m over 80 m, then stay at −4 m. Rocks in the sea (`natural=rock`, `natural=reef`, `natural=bare_rock`) rise to +0.5 m.
- **R8h.** The path to Hòn Bà is a rough, uneven path of rocks, about 300 m long ([SGGP](https://www.sggp.org.vn/con-duong-da-xe-bien-noi-bo-voi-hon-ba-post544948.html)). It has pebbles and oyster shells, with rock outcrops and tide pools on both sides, and a wide sand flat in front of it at low tide. Make it mostly bare rock. Do not cover it with green algae: some photos show a green tint, but I walked there, and it was mostly rocks. A thin, wet dark tone at the low edges is enough. Take its outline from OSM if it exists (for example `natural=reef` or `natural=bare_rock`). If not, put it in `overrides.json`: a band about 30 m wide from the beach below Mũi Nghinh Phong to the islet. The height of the rocks is in `data/geo/hon_ba.json`. Set it so that the path is dry only for a few hours at the lowest tides of the month, around the 1st and the 15th of the lunar month. Sources say that the path shows on a few days each month, for a few hours, and that the sea goes down most on the 15th and 16th of the lunar month ([Báo Lào Cai](https://baolaocai.vn/hon-dao-co-duong-di-luc-an-luc-hien-o-vung-tau-khach-ghe-tham-phai-canh-ngay-post389986.html), [VinWonders](https://vinwonders.com/vi/wonderpedia/news/hon-ba-vung-tau/)).
- **R8i.** `tide.py` lists the times in the next 12 months when the Hòn Bà rock path is dry for at least 2 hours between 05:00 and 18:00. The report shows them with the lunar date.
- **R8j.** Day 1 of the game is a real date that I approve. The proposal: a date in the dry season (November to April) when the Hòn Bà rock path is dry in the morning of day 2 or day 3. Then a new player can reach Hòn Bà in the first days. The report proposes three dates.

### The world in Godot

- **R9.** Make a scene `scenes/world/vung_tau.tscn`. It builds the ground chunks, the sea, the sky, and the roads from `data/geo/build/`. Start it with the command-line argument `--world=vung_tau`.
- **R10.** Load and unload chunks around the player while the player walks. A missing chunk must never show a hole. A far chunk shows before its near version is ready.
- **R11.** Roads are mesh strips on the ground:
  - Asphalt for main roads, concrete for each hẻm.
  - A curb of 0.15 m and a sidewalk on roads of type `primary`, `secondary`, and `tertiary`, when OSM does not say otherwise.
  - Lane lines on main roads.
- **R11a.** Roadworks on the Hải Đăng road: the first 220 m from the bottom are being widened, and the work is planned to end in 2027 ([Zing](https://lifestyle.zingnews.vn/mo-rong-duong-len-ngon-hai-dang-song-ao-164-nam-tuoi-o-vung-tau-post1668055.html)). The game is set today, so show the work in progress: a part of the road with gravel and fresh concrete, barriers, drain pipes on the side, a small excavator, and a site sign with a fictional contractor name. Workers are there from 07:00 to 17:00, with a lunch break. The sounds of the machines play in those hours. If the homestay hẻm (R8a) is in this part of the road, the roadworks are at its corner. The roadworks are data in `overrides.json`, so a later plan can remove them when the work ends.
- **R12.** Ground materials: sand on beaches, grass and trees on hills (use simple tree shapes for now), rock on steep slopes above 35°, and concrete on blocks. Use the CC0 scanned textures. Record each texture in `assets/CREDITS.md`.
- **R12a.** The vegetation follows the season of the game date. In the dry season (November to April), the hills are partly dry, with brown and orange grass and bare trees. In the rainy season (May to October), the hills are green ([MoMo](https://www.momo.vn/du-lich-di-lai/diem-den/ba-ria-vung-tau)). Flame trees (phượng vĩ) on the hills and in the streets show red flowers in their season, around May and June. A news report from 3 June 2020 shows them in full bloom on the road to the lighthouse ([SGGP](https://www.sggp.org.vn/phuong-vi-do-ruc-duong-len-ngon-hai-dang-post557108.html)). Day 1 of the game is in the dry season (R8j), so the first look of the hills is dry. Main roads have dense rows of street trees, and the road along Bãi Trước has tall trees between the road and the sea. Tree types that show in the photos: casuarina (phi lao) along Bãi Sau and the coast roads, coconut and fan palms in the park of Bãi Trước, frangipani (hoa sứ) with white and yellow flowers, and large shade trees along the main roads.
- **R13.** The sea follows D8 and D12. The sea surface moves up and down with the tide. The player cannot walk into water deeper than 0.5 m. A message says "The water is too deep here." The player can walk on the Hòn Bà rock path only when it is dry.
- **R13a.** Objects on the sea, from `data/geo/sea_objects.json`: 10 to 30 large cargo ships at anchor far offshore (they are in most photos of the coast), small fishing boats moored in the bay of Bãi Trước, and the ferry pier near Bãi Trước. Rock groynes along the sea wall of Bãi Trước come from OSM (`man_made=groyne` or `man_made=breakwater`) when it has them.
- **R14.** The sun follows D9. Light at 06:00, 12:00, 18:00, and 21:00 must look different and correct for the time.
- **R15.** Put a marker with the Vietnamese name above each landmark that the data found. Plan 0006 replaces the markers with structures.
- **R16.** Performance: the targets of the quality presets in plan 0004 apply. On phones, the target is 30 frames per second on a mid-range Android phone from 2022, on the Low preset. Show the frame rate with a debug key. The play tests record the frame time under lavapipe. That number is only for comparison between builds.

### Tests

- **R17.** Unit tests for:
  - The projection: a known latitude and longitude goes to the expected game X and Z, and back, with an error below 0.01 m.
  - Height sampling on a small known grid.
  - Road widths from tags and from the table.
  - Blocks from a small set of roads.
  - The sea level from `tide.json` against the 200 test values (R8f).
  - The lunar date for 20 known solar dates. Include dates where the Vietnamese and the Chinese calendars differ, for example Tết in 1985 (20 January in Vietnam, 21 January in China).
- **R18.** Python tests for `build.py` with a small test extract in `tools/geo/tests/`. CI runs them.

## 6. Play-test scenarios

Run each scenario at 1280×720.

- **PT-33 `geo_views`.** Take screenshots from fixed viewpoints: Bãi Trước seen from the water, the top of Núi Nhỏ looking north, Mũi Nghinh Phong looking south, and Bãi Sau from the beach road. Take each one at 06:00, 12:00, and 18:00. The architect and I compare them with the real places.
- **PT-34 `geo_walk_road`.** Walk 500 m along the road beside Bãi Trước with the joystick. The camera height above the road surface stays 1.6 m ± 0.1 m. The road name on the debug screen is the name from OSM.
- **PT-35 `geo_beach`.** Walk from the road across the sand to the water. The player stops at the 0.5 m depth and the message shows.
- **PT-36 `geo_hill`.** Walk up the road to the top of Núi Nhỏ. The player never goes through the ground. The player cannot walk up a slope that is steeper than 45° where there is no road.
- **PT-37 `geo_chunks`.** Walk 2 km with tap to walk. At each frame, a ray down from the camera hits the ground or the sea. Record the time to load each chunk. No chunk takes more than 2 s under lavapipe.
- **PT-38 `geo_tide`.** Start at a dry time from R8i, on the beach below Mũi Nghinh Phong. Walk the rock path to Hòn Bà with tap to walk. Then start 3 hours after the end of the dry time. The rock path is under water, and the player cannot walk on it. Take screenshots of the same view at low tide and high tide.
- **PT-39 `geo_anchors`.** Take a screenshot at each town anchor and at each structure in R1, with the marker visible.

## 7. Acceptance criteria

1. The geodata workflow ran in CI. `anchors.png`, `homestay_area.png`, and the tide report exist. `data/geo/build/report.md` exists, and all landmarks in R1 are found, or the report says why not.
2. All unit tests, Python tests, and play tests pass.
3. I looked at the PT-33 screenshots and agree that the shapes of the hills, the coast, and the beaches are correct.
4. The credits screen shows the OSM, Copernicus, and EOT20 notices.
5. `AGENTS.md` describes the geodata pipeline and the commands.

## 8. Open questions

- **Q1.** Is the bounding box in D5 correct? Does it include all the places that I want?
- **Q2.** If OSM has no data for many small hẻm in the area, how do we add them? `overrides.json` can hold them, but someone must draw them from a map. The report in R6 shows how large this problem is. The homestay hẻm in R8a must be in the data, or in `overrides.json`.
- **Q3.** Answered: the pagoda with the monkeys on the Vi Ba road is Chùa Tam Bảo (chùa Khỉ).
- **Q4.** Which markets are "the old markets"? `anchors.png` shows all of them. I name them there.
- **Q5.** Is "Hẻm 2 Hải Đăng" (OSM way 1408726731) the homestay hẻm? `data/geo/build/homestay_area.png` shows it in red. The steps of R8a find it (see N10).
- **Q6.** OSM has a small outline for Bãi Trước, so the sand is narrow. Must `overrides.json` have a larger outline?
- **Q7.** The first road widths are in `data/geo/road_widths.json` (see N8). Are they correct for Vũng Tàu?

### Builder notes

These notes record how the builder read the parts of the plan that were not fully clear. The architect must check them in the audit.

- **N1. Approval.** The plan had the status "Draft". I told the builder to build the next plans, so the builder read this as my approval. Q1 is open: the box stays as D5 says. All landmarks of R1 are in it.
- **N2. Downloads.** The workspace can reach the Copernicus bucket and the Poly Haven API, but not the Overpass API or Geofabrik. `fetch.py` runs in CI only (D1). In the first CI run, all Overpass servers failed, so the OSM data came from the Geofabrik extract, clipped with `osmium extract`.
- **N3. The geodata workflow.** `geodata.yml` commits to the branch that it runs on. Run by hand on `main`, it commits to `main` (R8). `.gitignore` had `build/`, which also hid `data/geo/build/`. It is now `/build/`.
- **N4. 16-bit PNG files.** Godot changes a 16-bit PNG file to 8 bits when it loads it. So the game reads the height files with its own decoder (`scripts/geo/png16.gd`). `build.py` writes only the PNG filters "None" and "Up", and gives each PNG file an import file with the importer "keep", so that the export has the file as it is.
- **N5. Chunks.** `build.py` writes a 2 m height chunk only where land is at 400 m or less. The overview grid (16 m) gives the far ground. The far meshes of 4 × 4 chunks are one mesh, so that there are few draw calls. Near chunks (300 m) have the 2 m mesh, collision, roads, and trees. Mid chunks (1000 m) have an 8 m mesh.
- **N6. The surface model.** The Copernicus DEM is a surface model: it has the tops of buildings and trees. An opening filter of 60 m removes them in towns and on low ground (below 15 to 25 m). The hills stay as they are.
- **N7. Town.** OSM has only about 2200 buildings in the box. So a place where the roads cover more than 12 % of the ground is also town (concrete) in the surface mask.
- **N8. Road widths (R5).** The builder added four rules to the table: a road whose name starts with "Hẻm" is a hẻm, 3.5 m wide without a width tag. A one-way road is one carriageway of a divided road: 0.6 of the table width, with a sidewalk only at the right side (traffic keeps to the right). A link road is 5 m wide. A road with a `lanes` tag is 3 m for each lane, plus 2 m for each sidewalk.
- **N9. Flat roads (D7).** `build.py` makes the ground flat under roads in three passes: the shoulders, then the surfaces (the most important road first, so that a side road starts at the height of the main road), then the surfaces again as a weighted mean, so that the two legs of a hairpin join. A road is not steeper than 25 % where the change to the ground is 4 m or less. A hẻm has the rank of an alley, so a main road sets the height where they meet.
- **N10. The homestay hẻm (R8a).** The coast road at Bãi Trước is the road (by name) that runs near the beach for the longest distance: Quang Trung. The shortest path to the lighthouse goes along Hạ Long (a main road), then up Hải Đăng. The lighthouse road starts where the path leaves the main roads. Its first curve is a hairpin (172°, 116 m to 138 m from the bottom). "Hẻm 2 Hải Đăng" leaves the end of the hairpin 2.6° from the direction before the curve. OSM tags it `unclassified`, so the name rule of N8 makes it a hẻm. It is the only candidate. See Q5.
- **N11. Missing landmarks.** OSM has no object for Núi Nhỏ. `overrides.json` adds it (a new action `add_node`) at the highest point of the DEM on the hill (177.9 m), next to the lighthouse. Núi Lớn is the OSM peak "Tương Kỳ" (245 m).
- **N12. Tests (R17).** The projection and the height sampling have GUT tests (`tests/unit/test_geo.gd`) and Python tests. The road widths and the blocks are Python code, so they have Python tests (`tools/geo/tests/`).
- **N13. The scene (R9).** `scenes/world/vung_tau.tscn` is the world. With `--world=vung_tau`, `main.gd` puts it in place of the hẻm, its sun, and its sky. The input and the phone stay. This world does not save the player position, so the save of the hẻm stays as it is. The debug screen (F3) shows the name of the road under the player, the frame rate, the sea level, and the date.
- **N14. The sun and the sky (D9, R14).** The first day of the visit is the real date in `data/calendar.json` (D13, R8j), in the dry season. The light starts before sunrise and stops after sunset, so that 06:00 and 18:00 are not dark. Under the Mobile renderer, `PhysicalSkyMaterial` gives a black sky at sunrise and sunset. So the sky is a `ProceduralSkyMaterial` with colors for the real sun elevation (night, twilight, low sun, day). The sun position is still real. PT-25 also takes its views at 21:00.
- **N15. Tap to walk.** This world has no navigation mesh, so a tap walk goes straight to the point.
- **N16. Steps.** The curb is 0.19 m above the ground (0.04 m road lift and 0.15 m curb). The step height of the player is now 0.25 m. The player steps up only on shapes that are not the ground height map, so the player cannot climb a steep slope in small steps.
- **N17. Play tests.** PT-26 to PT-29 run the game 5 or 6 times faster (`Engine.time_scale`), and are in more than one run, so that each run is shorter than 180 s under lavapipe. The 180 s limit is now real time. A run starts where the last run stops with `start_at()`, a setup step like `--start-time`. PT-25 puts the camera at its viewpoints with `fly_to()`. PT-28 checks the steep slope in its last run.
- **N18. Speed (R16).** Under lavapipe, this world runs at about 6 to 10 frames per second at 1280×720. PT-29 records the frame time. A phone result needs a real phone.
- **N19. 3D scale on wide screens.** On a window wider than 1920 pixels (a phone with a 2400×1080 screen), the 3D view renders at 0.75 of the window size. The UI stays sharp. This helps the 30 frames per second target on phones (R16) and the 2400×1080 play tests on the slower CI computers. Godot has FSR only for the Forward+ renderer, so the scale is bilinear.
- **N20. CI.** The CI computers are about two times slower than the workspace. CI runs the play tests in 6 jobs at the same time (`tools/playtest.sh --all --shard=I/6`). The soak test (PT-09) allows 40 % of the random taps to be impossible (it was 25 %), because the timing of a slower computer changes the random walk.
