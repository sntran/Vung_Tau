# 0003 Real geography of Vũng Tàu

| Field | Value |
|---|---|
| Status | Draft |
| Branch | `feat/0003-real-geography` |
| Depends on | 0002 (status "Built") |

## 1. Goal

The player walks in first person on the real ground of Vũng Tàu: the real hills, the real coast, the real beaches, and the real roads.

All shapes in this plan come from open data. Nothing comes from photos or from an artist. Plan 0004 adds the known structures (for example Bãi Trước, Mũi Nghinh Phong, Bãi Sau). Plan 0005 makes houses and puts them on the lots between the roads. This plan prepares the data for these two plans.

## 2. Out of scope

- Buildings and landmarks. This plan only finds their positions and their lots in the data.
- People, cars, and scooters.
- Tides, swimming, and boats.
- A change to the hẻm of plans 0001 and 0002. That hẻm stays the main game scene until plan 0005. This plan makes a separate scene.

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

## 5. Requirements

### Data pipeline

- **R1.** `data/geo/landmarks.json` lists the places to find, with their Vietnamese names, other names, and the OSM tags to search. Put in at least: Bãi Trước, Bãi Sau, Bãi Dâu, Mũi Nghinh Phong, Núi Lớn, Núi Nhỏ, Tượng Chúa Kitô Vua, Hải đăng Vũng Tàu, Bạch Dinh. I can add names.
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
- **R7.** `data/geo/overrides.json` holds corrections to the OSM data (for example a missing hẻm). `build.py` applies them after it reads the OSM data. Each correction has a reason.
- **R8.** `.github/workflows/geodata.yml` runs by hand (`workflow_dispatch`). It runs `fetch.py` and `build.py`. When a file changes, it commits to `main` with the identity in `CONTRIBUTING.md` and the message "Update the geodata". It uploads `report.md` as a CI artifact.

### The homestay hẻm

- **R8a.** `build.py` finds the homestay hẻm with these steps:
  1. Find the lighthouse on Núi Nhỏ (`man_made=lighthouse`, name "Hải đăng Vũng Tàu").
  2. Find the road that goes from the coast road at Bãi Trước up to the lighthouse. Use the shortest path in the road network.
  3. Go up this road from the bottom. Find the first curve: a change of direction of more than 45° in 60 m or less.
  4. At the end of this curve, find the hẻm that leaves the road and goes straight on, in the direction that the road had before the curve (±30°).
  5. Record this hẻm as `homestay_hem`, with the residential blocks along it, in `data/geo/build/homestay.json`.
- **R8b.** `build.py` draws `data/geo/build/homestay_area.png`: a top-down map of 300 m around the hẻm, with the roads, their names, the lighthouse road, and the hẻm in a strong color. I confirm the hẻm on this map.
- **R8c.** If step 4 finds no hẻm, or more than one, the report lists each candidate with its OSM ID, and the map shows each candidate with a number.

### The world in Godot

- **R9.** Make a scene `scenes/world/vung_tau.tscn`. It builds the ground chunks, the sea, the sky, and the roads from `data/geo/build/`. Start it with the command-line argument `--world=vung_tau`.
- **R10.** Load and unload chunks around the player while the player walks. A missing chunk must never show a hole. A far chunk shows before its near version is ready.
- **R11.** Roads are mesh strips on the ground:
  - Asphalt for main roads, concrete for each hẻm.
  - A curb of 0.15 m and a sidewalk on roads of type `primary`, `secondary`, and `tertiary`, when OSM does not say otherwise.
  - Lane lines on main roads.
- **R12.** Ground materials: sand on beaches, grass and trees on hills (use simple tree shapes for now), rock on steep slopes above 35°, and concrete on blocks. Use the CC0 scanned textures. Record each texture in `assets/CREDITS.md`.
- **R13.** The sea follows D8. The player cannot walk into water deeper than 0.5 m. A message says "The water is too deep here."
- **R14.** The sun follows D9. Light at 06:00, 12:00, 18:00, and 21:00 must look different and correct for the time.
- **R15.** Put a marker with the Vietnamese name above each landmark that the data found. Plan 0004 replaces the markers with structures.
- **R16.** Performance on phones: the target is 30 frames per second on a mid-range Android phone from 2022. Show the frame rate with a debug key. The play tests record the frame time under lavapipe. That number is only for comparison between builds, not a phone result.

### Tests

- **R17.** Unit tests for:
  - The projection: a known latitude and longitude goes to the expected game X and Z, and back, with an error below 0.01 m.
  - Height sampling on a small known grid.
  - Road widths from tags and from the table.
  - Blocks from a small set of roads.
- **R18.** Python tests for `build.py` with a small test extract in `tools/geo/tests/`. CI runs them.

## 6. Play-test scenarios

Run each scenario at 1280×720.

- **PT-18 `geo_views`.** Take screenshots from fixed viewpoints: Bãi Trước seen from the water, the top of Núi Nhỏ looking north, Mũi Nghinh Phong looking south, and Bãi Sau from the beach road. Take each one at 06:00, 12:00, and 18:00. The architect and I compare them with the real places.
- **PT-19 `geo_walk_road`.** Walk 500 m along the road beside Bãi Trước with the joystick. The camera height above the road surface stays 1.6 m ± 0.1 m. The road name on the debug screen is the name from OSM.
- **PT-20 `geo_beach`.** Walk from the road across the sand to the water. The player stops at the 0.5 m depth and the message shows.
- **PT-21 `geo_hill`.** Walk up the road to the top of Núi Nhỏ. The player never goes through the ground. The player cannot walk up a slope that is steeper than 45° where there is no road.
- **PT-22 `geo_chunks`.** Walk 2 km with tap to walk. At each frame, a ray down from the camera hits the ground or the sea. Record the time to load each chunk. No chunk takes more than 2 s under lavapipe.

## 7. Acceptance criteria

1. The geodata workflow ran in CI. `data/geo/build/report.md` exists, and all landmarks in R1 are found, or the report says why not.
2. All unit tests, Python tests, and play tests pass.
3. I looked at the PT-18 screenshots and agree that the shapes of the hills, the coast, and the beaches are correct.
4. The credits screen shows the OSM and Copernicus notices.
5. `AGENTS.md` describes the geodata pipeline and the commands.

## 8. Open questions

- **Q1.** Is the bounding box in D5 correct? Does it include all the places that I want?
- **Q2.** If OSM has no data for many small hẻm in the area, how do we add them? `overrides.json` can hold them, but someone must draw them from a map. The report in R6 shows how large this problem is. The homestay hẻm in R8a must be in the data, or in `overrides.json`.
