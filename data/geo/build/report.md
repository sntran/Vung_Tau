# Geodata report

Made by `tools/geo/build.py` on 2026-10-24.

## Extents

| Item | Value |
|---|---|
| Box (degrees) | 10.3° to 10.42° N, 107.05° to 107.13° E |
| OSM data (degrees) | 8.65744° to 10.77631° N, 106.53076° to 107.17618° E |
| Game X (m) | -2688.7 to 6161.8 |
| Game Z (m) | -8484.0 to 4849.8 |
| Origin | 10.34368307° N, 107.07404669° E (UTM 48N 727110 E, 1144150 N) |
| Height chunks | 960 (756 with land) |
| Highest DEM sample | 249.8 m |
| Mean height change in towns (buildings removed) | 0.16 m |

## Roads

Total road length: 692.3 km. Roads with a width tag: 7 of 4123. Hẻm: 2365.

| Type | Roads | Length (km) |
|---|---|---|
| residential | 1473 | 256.06 |
| service | 912 | 120.35 |
| primary | 233 | 105.85 |
| alley | 871 | 81.38 |
| secondary | 105 | 41.37 |
| tertiary | 68 | 28.34 |
| footway | 251 | 17.46 |
| unclassified | 41 | 17.21 |
| path | 50 | 16.90 |
| track | 24 | 4.42 |
| steps | 88 | 2.21 |
| pedestrian | 5 | 0.56 |
| cycleway | 1 | 0.14 |
| living_street | 1 | 0.08 |

## Blocks and buildings

- Blocks: 1975.
- Blocks with OSM building outlines: 409.
- Buildings: 2193.

## Landmarks

| Landmark | Found | OSM | Position (game X, Z) | Height (m) | Note |
|---|---|---|---|---|---|
| Bãi Trước | yes | way/220821647 | -2.55, -1.31 | 1.2 | 3 candidates, 347.9 m from the hint |
| Bãi Sau | yes | way/234800751 | 2463.57, 115.52 | -2.07 | 5 candidates, 391.9 m from the hint |
| Bãi Dâu | yes | way/895756059 | -1377.16, -2753.98 | 1.12 | 3 candidates, 435.3 m from the hint |
| Mũi Nghinh Phong | yes | node/2435353682 | 1076.55, 2561.69 | 1.2 | 1 candidates, 85.4 m from the hint |
| Núi Lớn | yes | node/2452682527 | -649.2, -1712.32 | 238.42 | 1 candidates, 188.9 m from the hint |
| Núi Nhỏ | yes | node/-1 | 374.1, 1035.7 | 175.6 | 1 candidates, 0.0 m from the hint |
| Tượng Chúa Kitô Vua | yes | way/235008112 | 1159.87, 1893.39 | 138.33 | 1 candidates, 83.3 m from the hint |
| Hải đăng Vũng Tàu | yes | way/229301316 | 402.21, 1056.5 | 173.11 | 1 candidates, 21.8 m from the hint |
| Bạch Dinh | yes | way/220753354 | -596.69, -776.93 | 28.11 | 1 candidates, 259.6 m from the hint |

## Homestay hẻm

Found: way 1408726731 (Hẻm 2 Hải Đăng, unclassified, 3.5 m wide, 567 m long). Check it on `homestay_area.png`.
The first curve of the lighthouse road turns -172° between 116 m and 138 m from the bottom.
- Candidate 1: way 1408726731 (Hẻm 2 Hải Đăng), 2.6° from the direction before the curve.

## The sea floor, the rocks, and the Hòn Bà ridge (R8g, R8h)

- The sea floor slopes from +1.2 m at the coastline to -4.0 m over 80 m, then stays at -4.0 m.
- Rocks in the sea: 58 grid cells at +0.5 m.
- The ridge Đường ra Hòn Bà (way/221906223): 206 m long, 4 m wide, top at -1.70 m.
- The tide: see `tide_report.md`.

## Corrections from overrides.json

- add node -1 ({'natural': 'peak', 'name': 'Núi Nhỏ', 'alt_name': 'Núi Tao Phùng'}): OSM has no object for Núi Nhỏ. The position is the highest point of the Copernicus DEM on the hill (177.9 m), next to the lighthouse.

## Problems with the data

- area 18343238 is not a correct polygon: invalid area (area_id=36686477)
- Núi Lớn is not in the OSM data of the box
- Núi Nhỏ is not in the OSM data of the box

## Source files

| File | Source | Date | SHA-256 | License |
|---|---|---|---|---|
| assets/textures/ground/asphalt/diffuse.jpg | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/asphalt_02/asphalt_02_diff_1k.jpg | 2026-10-24 | `1aa5ce99f58a625c…` | CC0 (Poly Haven) |
| assets/textures/ground/asphalt/normal.jpg | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/asphalt_02/asphalt_02_nor_gl_1k.jpg | 2026-10-24 | `42a1c381b53204e8…` | CC0 (Poly Haven) |
| assets/textures/ground/asphalt/roughness.jpg | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/asphalt_02/asphalt_02_rough_1k.jpg | 2026-10-24 | `70ba3edc65525eb4…` | CC0 (Poly Haven) |
| assets/textures/ground/concrete/diffuse.jpg | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/brushed_concrete/brushed_concrete_diff_1k.jpg | 2026-10-24 | `4054ed6eb65cd063…` | CC0 (Poly Haven) |
| assets/textures/ground/concrete/normal.jpg | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/brushed_concrete/brushed_concrete_nor_gl_1k.jpg | 2026-10-24 | `f4953a881f34627c…` | CC0 (Poly Haven) |
| assets/textures/ground/concrete/roughness.jpg | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/brushed_concrete/brushed_concrete_rough_1k.jpg | 2026-10-24 | `24da5e4c3d17b7db…` | CC0 (Poly Haven) |
| assets/textures/ground/grass/diffuse.jpg | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/leafy_grass/leafy_grass_diff_1k.jpg | 2026-10-24 | `cfa40bc9d9417d18…` | CC0 (Poly Haven) |
| assets/textures/ground/grass/normal.jpg | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/leafy_grass/leafy_grass_nor_gl_1k.jpg | 2026-10-24 | `832328216adc0a7e…` | CC0 (Poly Haven) |
| assets/textures/ground/grass/roughness.jpg | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/leafy_grass/leafy_grass_rough_1k.jpg | 2026-10-24 | `0c2a1d91aacb8e54…` | CC0 (Poly Haven) |
| assets/textures/ground/rock/diffuse.jpg | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/rocky_terrain_02/rocky_terrain_02_diff_1k.jpg | 2026-10-24 | `d570c10b1d5302f4…` | CC0 (Poly Haven) |
| assets/textures/ground/rock/normal.jpg | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/rocky_terrain_02/rocky_terrain_02_nor_gl_1k.jpg | 2026-10-24 | `f4f9d9671c660f4e…` | CC0 (Poly Haven) |
| assets/textures/ground/rock/roughness.jpg | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/rocky_terrain_02/rocky_terrain_02_rough_1k.jpg | 2026-10-24 | `8652ee05de206888…` | CC0 (Poly Haven) |
| assets/textures/ground/sand/diffuse.jpg | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/coast_sand_01/coast_sand_01_diff_1k.jpg | 2026-10-24 | `58af2e40100f7f40…` | CC0 (Poly Haven) |
| assets/textures/ground/sand/normal.jpg | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/coast_sand_01/coast_sand_01_nor_gl_1k.jpg | 2026-10-24 | `fe4d045aec99e71e…` | CC0 (Poly Haven) |
| assets/textures/ground/sand/roughness.jpg | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/coast_sand_01/coast_sand_01_rough_1k.jpg | 2026-10-24 | `cbc3e0bf2214e043…` | CC0 (Poly Haven) |
| dem.tif | https://copernicus-dem-30m.s3.amazonaws.com/Copernicus_DSM_COG_10_N10_00_E107_00_DEM/Copernicus_DSM_COG_10_N10_00_E107_00_DEM.tif | 2026-10-24 | `4a212aa188369913…` | Copernicus DEM license, © DLR e.V. 2010-2014 and © Airbus Defence and Space GmbH 2014-2018 |
| osm.pbf | https://download.geofabrik.de/asia/vietnam-latest.osm.pbf | 2026-10-24 | `862cef84cb27aa2b…` | ODbL 1.0, © OpenStreetMap contributors |
