# 0009 Houses on the lots

| Field | Value |
|---|---|
| Status | In progress (phase 1a, 2026-11-19). Approved (2026-11-16), for the area of plan 0026 first. Changed (2026-11-18): all the sources of the data (section 3, "The sources"; D9 to D11, R1, R5 to R5e, Q1, Q5 to Q7). |
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
| D9 | The ground is bare earth. The build makes it from three models of the ground, and lidar points from space check them (R5a, R5b). Copernicus GLO-30 (plan 0005) is a model of the surface: it has the tops of the trees and the roofs. GEDTM30 and DeltaDTM are models of the ground under them: they start from Copernicus and correct it with the lidar of ICESat-2 and GEDI. DeltaDTM has only the land below 10 m (the town, the beaches, the market). GEDTM30 has all the land, also the hills. The lidar points come from SlideRule, a public service that needs no account. They do not give the shapes of the houses: their tracks are lines hundreds of meters to some kilometers apart. Changed (2026-11-18): SlideRule replaces the NASA Earthdata token, and the two models of the ground are new. | The ground heights of plan 0005 come from radar, which sees the tops of the trees and the roofs. On the forest of Núi Lớn and Núi Nhỏ the hills can be too high, and the game puts its trees on top of that. In the town, the roofs make the ground under the houses of this plan too high. The workspace cannot reach the NASA data sites (`cmr.earthdata.nasa.gov` and `data.nsidc.earthdatacloud.nasa.gov`, checked on 2026-11-11), or the sites of the new sources (`storage.googleapis.com`, `zenodo.org`, `data.4tu.nl`, `slideruleearth.io`, `api.ohsome.org`, checked on 2026-11-18). So the fetch runs in CI (D2). |
| D10 | The heights of the buildings, and the first year when each building shows, come from Google Open Buildings 2.5D Temporal: a raster for each year from 2016 to 2023, with a real resolution of about 4 m. The outlines come from Overture Maps and OpenStreetMap (plan 0005). 3D-GloBFP (the heights of 2020) and GHS-BUILT-H (the mean height in cells of 100 m) are checks. The lidar photons on the roofs (ICESat-2 ATL03) also check the heights. | The 2.5D data has the state of each year, so the build can remove the buildings that are newer than 2019 (D1). Its heights are not exact. Google measured a mean error of 1.5 m only in North America, Europe, and Japan, and small houses that touch can show as one shape. So each outline takes the median height of the pixels in it, and only the pixels where the data is sure of a building. |
| D11 | Google Earth, its photorealistic 3D meshes, Street View, and Esri Wayback are for my eyes only. I can look at them to remember the town or to check a year, as I look at a photo. The game takes no shape, size, or color from them, and the repository keeps no copy of them. | Their terms do not let a project copy, keep, or trace their content. |

### The sources

Each source of the data of this plan, also the ones that the plan does not use, and why. "In use" is a source of plan 0005, 0008, or 0020. A "check" source does not change the game: the report compares it with the sources in use, and I decide.

**The ground**

| Source | What it gives | License | Use |
|---|---|---|---|
| Copernicus DEM GLO-30 | Heights of the surface (the tops of the trees and the roofs), 30 m | Free, with the credit of plan 0005 | In use. It stays where no better model of the ground agrees with the lidar (R5b). |
| [GEDTM30](https://codeberg.org/openlandmap/GEDTM30) v1.2 (OpenGeoHub, 2025) | Heights of the ground, 30 m, all the land, and a map of the uncertainty | CC BY 4.0 | New. The ground of the hills and of the town, where the lidar agrees (R5b). |
| [DeltaDTM](https://data.4tu.nl/datasets/1da2e70f-6c4d-4b03-86bd-b53e789cc629) v1.0 (Pronk and others, 2024) | Heights of the ground, 30 m, only the land below 10 m. The error against airborne lidar is 0.74 m (RMSE), and 0.91 m in towns. | CC BY 4.0 | New. The ground of the low town and of the beaches, where the lidar agrees (R5b). |
| FABDEM, FathomDEM | Heights of the ground, 30 m | CC BY-NC-SA 4.0 (non-commercial) | Not used: the license is non-commercial. |
| SRTM, NASADEM, ALOS AW3D30, TanDEM-X 90 m | Older models of the surface | Free (TanDEM-X 90 m: only for science) | Not needed. GEDTM30 uses AW3D30 already. |
| CoastalDEM, TanDEM-X 12 m, the national lidar of Vietnam | Heights of the ground or of the surface | Not open: paid, or only by a request to the survey office | Not usable. |

**The lidar points** (all from [SlideRule](https://slideruleearth.io), with no account; NASA data has no limits of use)

| Source | What it gives | Use |
|---|---|---|
| ICESat-2 ATL08 | The ground and the tops of the trees along the tracks, in segments of 20 m and 100 m, from October 2018 | New. The check of the three models of the ground (R5b). |
| ICESat-2 ATL03, with the classes of ATL08 | Each photon, with its class (ground, tree, top of a tree). A photon on a roof gives the height of the roof. | New. A check of the heights of the buildings (D10, R2). |
| ICESat-2 ATL24 | The depth of the sea floor along the tracks, where the water is clear | New, a check. The heights of the intertidal zone and of the bay of plan 0005 (R5c). |
| GEDI L2A | The ground and the height of the top in circles of 25 m, from April 2019 | New. The check of the ground (R5b), and of tall buildings. |

**The buildings**

| Source | What it gives | License | Use |
|---|---|---|---|
| Overture Maps | Outlines from OpenStreetMap, Microsoft, and other sources | ODbL | In use. The outlines (R1). |
| OpenStreetMap | Outlines, tags (hotel, church, temple, market), and some levels (`building:levels`) | ODbL | In use. The kind (R3), and the floors where the tag is (R2). |
| OpenStreetMap history ([ohsome API](https://wiki.openstreetmap.org/wiki/Ohsome_API)) | OpenStreetMap as it was on a date, for example 22 January 2019 | ODbL | New, a check of D1 (R5d). |
| [Google Open Buildings 2.5D Temporal](https://sites.research.google/gr/open-buildings/temporal) | For each year from 2016 to 2023: the presence of a building and its height, about 4 m. Vietnam is in its list. | CC BY 4.0 or ODbL | New. The heights and the first year (D10). |
| Google Open Buildings v3 | Outlines of 2023 | CC BY 4.0 or ODbL | New. The outlines where Overture has none. |
| [3D-GloBFP](https://essd.copernicus.org/articles/16/5357/2024/) | Outlines of Microsoft with heights of 2020. The error in Asia can be 13 m (RMSE). | CC BY 4.0 | New, a check of the heights. |
| GHS-BUILT-H (European Commission, 2018) | The mean height of the buildings in cells of 100 m | CC BY 4.0 | New, a check of the mean height of each block. |
| Microsoft Global ML Building Footprints | Outlines, and heights in some countries | ODbL | Not needed: Overture has them. |

**The trees, the land cover, and the sea**

| Source | Use |
|---|---|
| Meta and WRI canopy heights (1 m), ESA WorldCover 2021 | In use (plans 0005 and 0020). They give the classes of R5b. |
| ETH global canopy height 2020 (10 m) | Not needed: the map of Meta and WRI is finer. |
| GEBCO 2025, Sentinel-2 L2A | In use (plan 0005, R8g). |
| The nautical charts of Vietnam | Not usable: not open. |

**The photos** (for the look of the models, `docs/world-models.md`, section 3)

| Source | What it gives | License | Use |
|---|---|---|---|
| Wikimedia Commons, Flickr | Photos with dates | CC0, CC BY, CC BY-SA, or public domain | In use. |
| The video of 1992 (`docs/content/reference/video-1992.md`) | The things that did not change | Kept for reference (my decision) | In use. |
| [Mapillary](https://www.mapillary.com) | Street photos with dates, positions, and directions. Mapillary blurs the faces and the number plates. | CC BY-SA 4.0. The API needs a free token (Q6). | New. Photos for the look of the houses, the streets, and the models of World (R5e). |
| KartaView | Street photos with dates and positions | CC BY-SA 4.0 | New, a check. The builder counts its photos of 2017 to 2021 on the streets of this plan. |
| OpenAerialMap | Aerial photos | CC BY 4.0 | Not available: it has no photos of Vũng Tàu. |
| My scans with a phone (the lidar of an iPhone Pro, or many photos) | A mesh of a small thing: a gate, a shrine, a stair, the front of a house | Mine | An option, only for things that did not change since 2019 (Q7). |
| My photos from a drone | A mesh of a street | Mine | An option. A flight in Vietnam can need a permit (Check). |

**For my eyes only** (D11)

| Source | Use |
|---|---|
| Google Earth and its photorealistic 3D meshes | I look at the town in 3D. In Vũng Tàu, the meshes have little detail (I looked on 2026-11-18): at the church, the roof is a photo on a rough shape, and the bell tower does not stand up. |
| Google Earth, the photos of earlier years | I check the year of a building (Q3). |
| Google Street View | I look at a street. |
| Esri Wayback (World Imagery by date) | I check the year of a building (Q3). |

## 4. Requirements

### The data

- **R1.** `tools/geo/buildings.py` (CI) fetches the buildings of the play area (D10):
  - The outlines of Overture Maps and OpenStreetMap (plan 0005), and the outlines of Google Open Buildings v3 where they have none.
  - The rasters of Open Buildings 2.5D Temporal of 2016 to 2023. They are in the public bucket `open-buildings-temporal-data`, version `v1`. The manifests of the S2 cell `31` (level 2) give the GeoTIFF of each tile and year (the download notebook of Google does the same).
  - The heights of 3D-GloBFP (the part of Asia, DOI 10.5281/zenodo.11397014) and of GHS-BUILT-H.

  For each outline, the build takes the median `building_height` of the pixels in it, where `building_presence` is more than a limit. The builder proposes the limit in the report. The first year is the first year in which the outline has a building. The build writes `data/geo/build/buildings_2019.json`: the outline, the height, the source of the outline, the source of the height, and the first year. A building that first shows after 2019 is not in the file. The report `buildings_report.md` gives the counts and the maps: all buildings, the ones in 2019, the ones that are removed, and the places where the raster of 2019 has a building and no outline has it (a building that is gone now). It also compares the heights of the 2.5D data with 3D-GloBFP, GHS-BUILT-H, the levels of OpenStreetMap, and the lidar of R5a.
- **R2.** The floors come from the height with a rule in `data/geo/houses.json` (a base height and a height for each floor). The builder calibrates the rule with 20 buildings that I know (the homestay hẻm and some places on Trần Phú), and writes the result in the report. Where a lidar photon of R5a falls on a roof, or OpenStreetMap has `building:levels`, the height also calibrates the rule, so I give the floors of fewer buildings.
- **R3.** The kind of each building:
  - When OpenStreetMap has a tag (hotel, church, temple, market), the tag decides.
  - Otherwise, a narrow deep footprint (width up to 6 m, depth at least twice the width) is a tube house. A tall narrow building near the beach is a mini-hotel. A large footprint is a block with a flat roof (`big`).
  - The known places of plan 0008 are not houses. Their outlines clear the houses.
- **R4.** The front of each house points to the nearest road. The width and the depth come from the smallest rectangle around the outline. A row of houses with shared walls keeps the walls shared (W17).
- **R5.** Each source in use has a license note in `data/geo/LICENSE` and a credit in the credits page (R15). For a source with two licenses (Open Buildings), the note says which one the game uses.
- **R5a.** `tools/geo/lidar.py` (CI) asks SlideRule (the Python package `sliderule`, the public service) for the points in the play area, of all the years, to `data/geo/raw/lidar/`:
  - ICESat-2 ATL08, and ATL03 with the classes of ATL08.
  - ICESat-2 ATL24.
  - GEDI L2A.

  It keeps only the points of good quality (the quality flags of each product). For each point, it writes the position, the date, the height of the ground, the height of the top (or the height of the photon and its class), and the product. The lidar heights are above the WGS 84 ellipsoid. The build changes them to the vertical datum of the models of the ground (EGM2008 for Copernicus and DeltaDTM). The builder checks the datum of each model, and the report gives it. If SlideRule is not available, the fallback is the NASA Earthdata access with a free account (Q5).
- **R5b.** The ground under the trees and the roofs. `tools/geo/fetch.py` also gets windows of GEDTM30 (version 1.2, a COG: the heights are in decimeters, Int32) and DeltaDTM (the tile of 10° N to 11° N and 107° E to 108° E, from the file of Asia of 4TU.ResearchData, DOI 10.4121/21997565). Then `tools/geo/build.py` does these steps:
  1. It compares Copernicus, GEDTM30, and DeltaDTM with the lidar ground at each point. The report gives, for each model, the mean difference and the RMSE by land cover (tree cover, bushes, town, bare ground) and on each hill.
  2. For each class and each hill, it takes the model with the smallest RMSE. A class or a hill with fewer than 30 lidar ground points keeps Copernicus, and the report says so.
  3. Where that model differs from Copernicus by more than 2 m on average, the build uses it, with a smooth change to Copernicus over 60 m at the edge. Elsewhere, the build keeps Copernicus.
  4. Below the line of the high water, the heights of plan 0005 (R8g) stay.

  The report shows the maps before and after, and pictures of Bãi Trước and of Núi Nhỏ with each model side by side. The roads and the known places (plans 0005 and 0008) are built again on the new ground. Then PT-33 and PT-60 to PT-62 run again, and I look at the views of the hills.
- **R5c.** The sea floor. The build compares the depths of ATL24 with the heights of the intertidal zone and of GEBCO (plan 0005, R8g), and the report gives the differences on a map. The build does not change the sea floor. I decide after the report.
- **R5d.** The check of 2019 by OpenStreetMap. `tools/geo/buildings.py` gets the buildings of OpenStreetMap on 22 January 2019 from the ohsome API. The report lists the buildings that OpenStreetMap had then and the 2.5D data does not have in 2019, and the other way. It also lists the buildings with a `start_date` after 2019, or with `building=construction` in 2019. OpenStreetMap of 2019 did not have all the buildings, so a building that it does not have is not removed for that reason.
- **R5e.** Street photos from Mapillary. `tools/geo/photos.py` (CI, with the secret `MAPILLARY_TOKEN`) lists the images of the play area from the coverage tiles (`mly1_public`, zoom 14) and the API of the images. It writes `data/geo/raw/mapillary.json`. For each image, it writes the id, the date, the position after processing (`computed_geometry`), the direction (`compass_angle`), the kind of camera (360 or not), the sequence, and the author. The report `photos_report.md` gives a map of the images by year, and the count of images of 2017 to 2021 on each street of this plan and at each known place (plan 0008).
  - The build does not copy the images. For a model, the builder chooses the images and copies them into `docs/reference/photos/` with the link, the date, the author, and the license (`docs/world-models.md`, section 3).
  - The URL of a picture expires, so the index keeps the id of the image, and not the URL.
  - A sequence can have a point cloud (`sfm_cluster`). A size from a point cloud has the status "Check", and the report gives how it was measured.

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

1. The data pipeline and its report (R1 to R5e). I look at the maps in the report, and at the hills before and after R5b.
   - Changed (2026-11-18): phase 1 has two parts. **1a**: the fetches and the reports (R1, R5, R5a, R5c, R5d, R5e). They change nothing in the game, so they can start before plan 0026 is on `main`, on the branch of this plan. R5e is made on the branch of plan 0026 (my decision, 2026-11-19: plan 0026 uses the photos of Mapillary now), and it comes to this plan with plan 0026. They need no model of World and no construction shift of World. **1b**: the new ground (R5b). It changes the ground under the showcase of plan 0026, so it starts after plan 0026 is on `main`. Report 0026, D-0026-22 (the Grand Hotel on a bank of earth) is a fault of the same kind: the model of the surface has the trees of the garden and the roofs.
2. The far level of the whole town (R6, R10), with boxes of the right size and roofs. I look from Núi Nhỏ and Núi Lớn.
3. The houses of World, near and mid (R7, R8, R9), one kind at a time: the tube house first.
4. The real hẻm and the homestay (R11).
5. The streets near chợ Xóm Lưới (R12, R13), then the night (R14).

## 6. Play-test scenarios

- **PT-65 `buildings_data`.** The unit test of R1 to R4: no building is outside the area, no two overlap, the floors are from 1 to 12, and no building first shows after 2019. The test of R5b: with a DEM that is 5 m too high under the tree cover of a test area, the build finds the 5 m (within 0.5 m) and lowers the ground; with a correct DEM, it changes nothing. With two models, one correct and one 5 m too high, the build takes the correct one, and no step at the edge is more than 0.3 m from cell to cell. A lidar point at a known height above the ellipsoid gets the height of the datum of the models. The test of R1: an outline with the raster of a building from 2021 only is not in the file, and its median height ignores the pixels of low presence.
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
  - **Partly answered (2026-11-18):** the sources table (section 3) and D10. Vietnam (VNM) is in the list of countries of the 2.5D data. The builder still checks in CI that its tiles cover the play area, and the architect confirms the report.
- **Q2.** The rule for floors (R2). I give the floors of the buildings that I know: 20 without lidar, fewer where the lidar points fall on buildings.
- **Q5.** I make a free NASA Earthdata account and put its token in the secret `EARTHDATA_TOKEN` before phase 1.
  - **Changed (2026-11-18):** no account is necessary. SlideRule is a public service, and the files of the other sources are open downloads. Only if SlideRule is not available (R5a), I make the account and the secret.
- **Q3.** The 2019 state of some places: which streets near chợ Xóm Lưới had shops, and which hotels stood near Bãi Trước. These facts have the status "Check".
- **Q4.** The first release does not need all the town. Which part has houses of the near level first: the hẻm, the market streets, and the road to Bãi Trước?
- **Q6.** The API of Mapillary needs a free account and a token (a secret `MAPILLARY_TOKEN`). Do I make them? Without them, the builder checks only KartaView.
  - **Answered (2026-11-18):** I make them if Mapillary has good photos of the play area. The first look is on the public map of Mapillary, which needs no account.
  - **Answered (2026-11-18), later:** the photos are good. I made the account, and the secret `MAPILLARY_TOKEN` of this repository has the client token (R5e).
- **Q7.** When I am in Vũng Tàu, which things do I scan with a phone? Only things that did not change since 2019 are useful: for example a gate, a shrine, a stair, or a part of the sea wall.
  - **Partly answered (2026-11-18):** I asked some people to take photos later. It is not sure, so no step of this plan waits for them.

## Builder notes

- **Phase 1a (2026-11-19).** `tools/geo/buildings.py` (R1, R5d) and `tools/geo/lidar.py` (R5a, R5c) run in CI only, with the workflow "Buildings and lidar" (`.github/workflows/buildings.yml`, by hand or on a push that changes the tools). The workspace cannot reach their sources (D2, D9). `buildings.py outlines` gets the buildings theme of Overture Maps in the box of `data/geo/area.json` (it joins OpenStreetMap, Microsoft, and Google Open Buildings v3, so an outline of Google is there where OpenStreetMap has none); `temporal` finds and reads the windows of the rasters of Open Buildings 2.5D Temporal of 2016 to 2023 (the public bucket `open-buildings-temporal-data`, `v1`, the cell 31); `osm2019` gets the buildings of OpenStreetMap on 2019-01-22 from the ohsome API; `build` (no network) writes `data/geo/build/buildings_2019.json` (the median height of the pixels where `building_presence` is more than 0.5, a builder value, and the first year) and `buildings_report.md`. `lidar.py fetch` asks SlideRule for ATL08, ATL03 with the classes of ATL08, ATL24, and GEDI L2A, with the heights over the ellipsoid and over EGM2008; `report` compares ATL24 with the intertidal heights and GEBCO (R5c). Each part writes what it found and each error in the report, and a part that fails does not stop the others: the first runs show the formats of the sources, and I correct the tools from the reports. 3D-GloBFP and GHS-BUILT-H (the checks of R1) come after the first runs. The first run in CI (2026-11-19) and the corrections: the outlines gave 56 359 buildings of Overture Maps (33 087 of Microsoft, 21 084 of Google Open Buildings, 2 188 of OpenStreetMap), and ATL08 22 639 points; the job committed nothing, because `git add` stops for all the paths when one of them is not there (now the job adds only the files that it made). The workspace reaches the bucket of the 2.5D data, the ohsome API, and Overture Maps (not SlideRule from Python), so I corrected these parts here. `temporal`: the lines of a manifest are paths after its `uriPrefix` with no "/" between them (`v1/geotiffs/31` and `754_2019_06_30/tile_X.tif` give the folder `31754_2019_06_30`), and the first run read them from the root of the bucket (HTTP 404 for each file); the manifests of the play area are the cells `31` and `37` of EPSG:32648, and the affine transform of each line gives its bounds, so the part reads only the tiles of the area. A window of the area at 0.5 m is about 5 GB for each year, so the part keeps no raster: for each outline and each year it writes the median height of its pixels with a presence of more than 0.5 and the number of these pixels (`data/geo/raw/buildings/temporal.json`), and a map of 2019 at 5 m of the pixels with a building and no outline (`temporal_2019_unmatched.tif`). The rasters are about 3 m south and 1.5 m east of the outlines (the red bands under each outline in the overlay of 2019): the part finds the shift of each year with the best overlap in 400 m round the middle of the town (at most 8 m each way) and moves the outlines by it; at that shift 69 % of the pixels of the outlines near the middle have a building. A year counts for an outline from 8 pixels (2 m², a builder value). `osm2019`: the ohsome API answers HTTP 403 at `elements/geometry`, and `elementsFullHistory/geometry` works; the part asks for the versions from 2019-01-22 to the next day and keeps the ones that are valid from the start: 1 119 buildings, none with `building=construction`. `lidar.py`: each `x` call of SlideRule for all the years stopped at the server after 600 s and gave nothing, so the `x` calls ask for one year at a time, the calls that worked (`atl08p`, `gedi02ap`) come first, and GEDI L2A takes `elevation_lm` (the ground) and `elevation_hr` (the top). The step that finds these: `tools/geo/tests/test_buildings_tool.py` (the paths and the tiles of a manifest, the medians, the count of pixels, the versions of the day, the shift, and the years of the lidar). The second run in CI (`86f606a`): 56 359 outlines, the heights of the 2.5D data of 51 689 of them, 52 379 buildings in `buildings_2019.json`, and 3 980 out (their first year is after 2019); the shift of the outlines on the rasters is from 1 m to 4.3 m each year, with 67 % to 71 % of the pixels of the outlines near the middle on a building. The map of 2019 has 130 632 cells of 5 m more than half building with no outline: I did not look at them yet, and the limit of the presence (0.5) and the count of pixels (8) are builder values for the next review. The lidar: ATL08 4 745 segments, ATL03 896 655 ground photons (2018 to 2026, 60 MB: a large file for the repository), ATL24 32 929 photons of the sea floor (2018 to 2025), and GEDI L2A 1 122 shots. R5c: the tool took `ortho_h` of ATL24 (a height over EGM2008 already) and turned it over the geoid a second time (−0.45 m became +2.11 m); now the heights of `ortho_h` stay as they are. ATL24 is 0.91 m over the intertidal heights (RMSE 2.06 m, 2 825 points) and 5.09 m over GEBCO (RMSE 10.07 m, 32 929 points). The build does not change the sea floor (R5c). R5: `data/geo/LICENSE` has the notes of the new sources; the credits page gets them when the game uses them (phase 1b and later).
- **The corrections of report 0009 (2026-11-20).** The numbers are the numbers at the head of the branch (`2de28d4`, the second commit of the workflow "Buildings and lidar" after the history of the branch was made again; D-0009-06).
  - **D-0009-01 (the guard).** `tools/geo/lidar.py` keeps the data of each product by year: one file for each product and year, with its rows in `data/geo/raw/lidar/manifest.json`. The fetch asks only for the years that are not there and for the current year. A year that fails or gets no time keeps its file; a year with 0 rows where the last run had rows is an error; a product with fewer points than before is an error unless a person starts the workflow with `allow_fewer`. After an error the job ends red, keeps the reports as an artifact, and commits nothing. `lidar.py seed` got back the files of `86f606a`, `a36c84e`, and `7d32458` from the history (for each year the file with the most rows). The tests: `tools/geo/tests/test_lidar_store.py` ("a fetch with one failed year keeps the rows of that year", "a year with 0 rows where the last run had rows is an error", the rule of fewer points, the years to fetch, the SHA-256 of the store, and the short form). The points at the head: ATL03 ground photons 896 655 (2018 98 228, 2019 168 384, 2020 48 543, 2021 41 168, 2022 108 229, 2023 119 835, 2024 68 270, 2025 148 200, 2026 95 798), ATL08 33 633 segments, ATL24 35 429 photons of the sea floor (2018 to 2026), GEDI L2A 1 122 shots (2019 384, 2021 74, 2022 23, 2023 416, 2024 72, 2025 153). The first run with the guard: three years of the roof photons (2021 to 2023) failed at SlideRule ("no frame") and kept no file; the next run asked only for them (and the current year) and got them: the guard and the fetch by year worked as the plan says.
  - **D-0009-06 (the large files).** The large files are assets of the release `geodata-0009-1` (`tools/geo/geostore.py`): each name has the start of its SHA-256, and `data/geo/raw/lidar/manifest.json` and `data/geo/raw/buildings/manifest.json` give the SHA-256 of each file. The tools get a file from the release (public, no account) and check its SHA-256. Git keeps the reports, the maps, the R5d lists, and the short form of the lidar (`data/geo/build/lidar_tracks.json`: for each 20 m of a track, the date, the median ground, the median roof, and the counts; 43 772 bins from 937 982 photons, 2.1 MB). The history of the branch was made again (2026-11-20, `git filter-branch` on the commits of the branch): no commit of the branch has the large raw files, and the final files did not change; the workflow no longer reads the history (the one-time seed of the files of the runs before the store came out of it).
  - **D-0009-02 (the roof photons).** The product `atl03_roof`: the ATL03 photons of the classes canopy, top of canopy, and no class, only the photons over an outline. At the head: 60 434 photons (2018 5 662, 2019 5 679, 2020 2 244, 2021 2 090, 2022 8 474, 2023 8 543, 2024 6 515, 2025 9 318, 2026 11 909). The check of the heights: the median of at least 3 roof photons of an outline over the median of the ground photons of the same pass within 40 m, against the 2.5D height: 2 027 buildings (52 510 photons over 2 817 outlines), mean +1.96 m, median +1.22 m, RMSE 6.37 m (the 2.5D height minus the photons).
  - **D-0009-03 (the reports).** The maps `buildings_all.png`, `buildings_2019.png`, `buildings_out.png`, and `buildings_no_outline.png` (the whole box, and the middle of the town at a larger scale). The checks of the heights (the 2.5D height minus the check): 3D-GloBFP 31 467 buildings, median −3.70 m, RMSE 8.42 m; GHS-BUILT-H 3 598 cells of 90 m, median +3.95 m, RMSE 8.33 m; `building:levels` of OpenStreetMap (3.3 m a storey) 40 buildings, median +1.65 m, RMSE 17.46 m; the roof photons above. The lists of R5d (`data/geo/build/buildings_r5d.json`): 165 buildings in OpenStreetMap on 2019-01-22 and not in the 2.5D data of 2019, 1 094 the other way (the outlines that OpenStreetMap has today), and 1 building with a `start_date` after 2019.
  - **D-0009-04 (the buildings with no outline).** Only the groups of cells of 5 m with a building and no outline, 3 m or more from an outline, of at least 4 cells: 2 714 groups, 39 419 cells, 98.5 ha (the map `buildings_no_outline.png`; the largest groups have 356, 329, and 212 cells). The test: `test_buildings_tool.py` (the groups).
  - **D-0009-05 (the first year and the height).** The presence stays at 0.5. The first year of a building is the first year with 30 % of the area of its outline, and at least 8 pixels; its height is the median of all its years from the first year on. At the head: 51 112 buildings of 2019 and 5 247 out (their first year is after 2019). The test: `test_buildings_tool.py` (the first year and the height).
  - **D-0009-07 (the mean dynamic topography).** `lidar.py mdt` (`data/geo/raw/lidar/mdt.md`) compares ATL24 minus the intertidal heights with DTU22MDT and with the mean sea surface DTU21MSS minus EGM2008, at the points of R5c. Bãi Trước (34 points): ATL24 minus intertidal 1.02 m (median 0.94 m), DTU22MDT 1.16 m (error 0.07 m), DTU21MSS minus EGM2008 1.20 m. All of R5c (2 994 points, most at Bãi Sau): 0.88 m, DTU22MDT 1.16 m, DTU21MSS minus EGM2008 0.88 m. So most of the offset (0.88 m to 1.02 m of 1.16 m) is the mean sea level over the geoid: the rest is −0.14 m at Bãi Trước and −0.28 m over all, less than the difference of the tide systems (0.12 m) and the spread of the two models near the coast. If the land of the game (Copernicus, over EGM2008) and its sea are on these two levels, the sea of the game is about 1.1 m too low at the beach. I do not change the ground or the sea: R5b (phase 1b) waits for plan 0026.
- **The corrections of audit 2 (report 0009, section 6, 2026-11-20).** For each defect, the test that finds it came first, and it failed before the correction. The numbers are the numbers at the head of the branch (`efe2b54`, the commit of the workflow "Buildings and lidar" after `9790cf5`).
  - **D-0009-08 (the first year).** The first year of a building is the first year with 30 % of its outline; else the first year with 8 pixels or more. Its height is the median of the years from that year on. A building with fewer than 8 pixels in each year goes to the list `buildings_unseen` of the store and the map `buildings_unseen.png` (the outlines in blue), with the status Check, and the build stops when a building with a first year has no height. The report gives the count of each kind: a year with 30 % of the outline, 43 208 up to 2019 and 5 247 after 2019; no year with 30 % but a year with 8 pixels or more, 2 116 up to 2019 and 1 118 after 2019; fewer than 8 pixels in each year, 4 670 (median area 23 m²). So 45 324 buildings of 2019 and 6 365 out, and no height is null. The tests: `tools/geo/tests/test_buildings_tool.py`, one for each kind and one for `sort_buildings()` (the counts, the list of the unseen, and no null height). The check with the roof photons now has 2 086 buildings (it had 2 027): median +1.20 m, RMSE 17.55 m (it was 6.37 m): the new buildings of the kind "8 pixels" bring large differences; I look at them with the next review of the limits (the presence 0.5 and the 8 pixels are builder values).
  - **D-0009-09 (the passes).** `lidar.py` keeps the passes of each product and year (the dates of its rows) in `data/geo/raw/lidar/manifest.json`. A year is complete only when ATL08 has each pass of the ATL03 ground photons, and the ground photons have each pass of ATL08 and of the roof photons (ATL24, over the water only, and GEDI, another satellite, are not compared). The report gives the passes of each product and year and the years that are not complete, and the next run asks again for each product of a year that is not complete. The tests: `tools/geo/tests/test_lidar_store.py` ("the land products of a year have the same passes", "a year with fewer passes than ATL03 of the same year is fetched again"). Before the correction, ATL08 had 17 passes and the ground photons 30 (2019, 2020, 2022, 2023, and 2024 were not complete). The run of 2026-11-20 (the second try: the first stopped at SlideRule, "Cluster experiencing heavy load", and the guard kept the store and committed nothing) asked again for ATL08 of these five years: 2019 8 016 segments (it had 5 627), 2020 3 411 (3), 2022 7 599 (1 139), 2023 5 573 (2 202), 2024 4 464 (2 851). Now ATL08 and the ground photons have 30 passes each, and each year is complete.
  - **D-0009-10 (the import files).** The maps `buildings_all.png`, `buildings_2019.png`, `buildings_out.png`, `buildings_no_outline.png`, `buildings_unseen.png`, and `lidar_seafloor.png` have import files with `importer="keep"` (`geostore.write_keep_import()`, called by each tool that writes a map), and the workflow commits them. The test: `tools/geo/tests/test_units.py` ("each map of the build has a keep import").
  - **The data at the head.** Buildings: 56 359 outlines of Overture Maps; 45 324 buildings of 2019, 6 365 out, 4 670 unseen (Check); 2 714 groups of cells with a building and no outline (98.5 ha); R5d: 155 buildings in OpenStreetMap on 2019-01-22 and not in the 2.5D data of 2019, 1 152 the other way, 1 with a `start_date` after 2019. The checks of the heights (the 2.5D height minus the check): 3D-GloBFP 32 948 buildings, median −3.70 m, RMSE 8.35 m; GHS-BUILT-H 3 663 cells, median +3.91 m, RMSE 8.21 m; `building:levels` 40 buildings, median +1.65 m, RMSE 17.46 m; the roof photons above. Lidar: ATL08 50 874 segments (2018 4 654, 2019 8 016, 2020 3 411, 2021 2 464, 2022 7 599, 2023 5 573, 2024 4 464, 2025 9 774, 2026 4 919), ATL03 ground photons 896 655, roof photons 60 434, ATL24 35 429 photons of the sea floor, GEDI L2A 1 122 shots; the short form 44 185 bins of 20 m from 957 089 photons. R5c: ATL24 is 0.88 m over the intertidal heights (RMSE 2.27 m, 2 994 points) and 5.02 m over GEBCO (RMSE 10.09 m, 35 429 points).
  - **The notes of section 6.4** are not work for now (your answer of 2026-11-20).
