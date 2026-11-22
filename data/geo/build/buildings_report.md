# The buildings of the play area (plan 0009, R1 and R5d)

Made by `tools/geo/buildings.py`. Do not change by hand. The large files are assets of the release `geodata-0009-1` (`data/geo/raw/buildings/manifest.json`).

45324 buildings of 2019, 6365 out (their first year is after 2019), and 4670 that the 2.5D data does not see (Check).

## The first year of each outline (D-0009-05, D-0009-08)

| Kind | Up to 2019 | After 2019 |
|---|---|---|
| A year with 30 % of the outline | 43208 | 5247 |
| No year with 30 %: the first year with 8 pixels or more | 2116 | 1118 |

Fewer than 8 pixels in each year: 4670 outlines (median area 23 m²). They are not in `buildings_2019`: the list `buildings_unseen` of the store and the map `buildings_unseen.png`, with the status Check. Each building of 2019 and each building that is out has a height (no null).

## The buildings with no outline (D-0009-04)

2714 groups, 39419 cells of 5 m, 98.5 ha (`buildings_no_outline.png`, the groups in orange).

## The maps (D-0009-03)

`buildings_all.png`, `buildings_2019.png`, `buildings_out.png`, `buildings_no_outline.png`, and `buildings_unseen.png`: the whole box at the left, the middle of the town at the right.

## The lists of R5d

All the rows are in `buildings_r5d.json`.

### In OpenStreetMap on 2019-01-22, not in the 2.5D data of 2019 (155)

| OSM | x | z | building | name |
|---|---|---|---|---|
| way/118945108 | 1453.5 | -3085.4 | yes |  |
| way/118945155 | 1515.2 | -3167.9 | yes |  |
| way/118945162 | 1484.3 | -3126.5 | yes |  |
| way/119007044 | 1639.2 | -3578.6 | yes |  |
| way/119007052 | 1622.2 | -3542.2 | yes |  |
| way/119007054 | 1664.7 | -3527.0 | yes |  |
| way/119007058 | 2650.6 | -5263.5 | yes |  |
| way/119007077 | 2762.8 | -5344.3 | yes |  |
| way/119007119 | 1698.0 | -3506.5 | yes |  |
| way/119007124 | 1987.2 | -4138.5 | yes |  |
| way/119007171 | 1659.9 | -3564.2 | yes |  |
| way/119007178 | 1731.3 | -3546.6 | yes |  |
| way/119007179 | 2005.6 | -4134.9 | yes |  |
| way/215192527 | 4300.8 | -3669.2 | residential | Sea View 4 - DIC |
| way/237612652 | -1466.0 | -4775.0 | yes | CHXD Sao Mai |
| way/237612653 | -1467.6 | -4770.0 | roof |  |
| way/237612660 | -1609.6 | -4603.1 | yes | Trường Tiểu học Sao Mai |
| way/243309172 | 3380.5 | -6042.0 | yes |  |
| way/243309197 | 2762.3 | -4978.7 | yes |  |
| way/243309201 | 2832.8 | -5004.8 | yes |  |
| way/243309205 | 2861.4 | -4979.2 | yes |  |
| way/243309206 | 2804.7 | -5029.6 | yes |  |
| way/243309207 | 2779.5 | -4996.7 | yes |  |
| way/243309221 | 3590.7 | -6173.2 | yes |  |
| way/243309229 | 3550.5 | -6215.2 | yes |  |
| way/243309231 | 3603.0 | -6133.4 | yes |  |
| way/270798111 | 2895.0 | -5288.1 | yes |  |
| way/286996176 | 2528.5 | -4973.8 | commercial | Toa nha XNK&SG Vietsovpetro |
| way/428404916 | 4087.1 | -5661.5 | house | Nhà Thờ Trung Đồng |
| way/524440459 | 3807.8 | -3827.5 | yes |  |
| way/616272229 | 5273.5 | -6920.4 | yes |  |
| way/616272263 | 6054.6 | -7310.9 | industrial |  |
| way/616272310 | 5403.2 | -7159.7 | yes |  |
| way/118927573 | 2112.3 | -291.5 | yes |  |
| way/118927574 | 2085.7 | -296.7 | yes |  |
| way/118929467 | 2155.8 | -317.8 | yes |  |
| way/118929478 | 2191.3 | -313.0 | yes |  |
| way/118939582 | 962.6 | -1728.3 | yes |  |
| way/118939587 | 1112.6 | -1979.0 | yes |  |
| way/118939595 | 1052.1 | -1855.5 | yes |  |

### In the 2.5D data of 2019, not in OpenStreetMap on 2019-01-22 (1152)

Only the outlines that OpenStreetMap has today: the other outlines of 2019 (Microsoft, Google) were never in OpenStreetMap.

| Overture | x | z | first year |
|---|---|---|---|
| 525a63d3-bfa7-4e72-88e2-99c2ed65cd7a | 5918.2 | -7485.7 | 2016 |
| 3b6a2fb9-8120-4075-8b7d-80bb322deb12 | 4275.8 | -7372.3 | 2016 |
| 7297f2fe-301a-46de-99f6-e7637d6e82be | 4330.0 | -7392.4 | 2017 |
| 16603e50-1d45-43f5-b240-67c24ed0830d | 4308.8 | -7384.3 | 2016 |
| 640ab505-1839-4e84-8127-63fe78f3b15d | 4205.2 | -7347.1 | 2017 |
| 4b6ba9df-905e-436d-af99-52959504ef66 | 4222.4 | -7358.0 | 2018 |
| 7bc61509-f3db-4438-8394-a46e4cdfdea9 | 4183.0 | -7324.7 | 2016 |
| 9276241d-0032-4498-b877-4ee77eb78bed | 4643.9 | -7110.9 | 2016 |
| 35b56673-181a-4bb9-826b-78892c10b232 | 4610.0 | -7097.4 | 2016 |
| ff7d1d62-51df-4d4a-a6dd-2ccc72e8ce73 | 4552.8 | -7075.3 | 2016 |
| eb019198-71b7-4866-8bdd-e74bbd07fe20 | 4603.3 | -7039.7 | 2016 |
| 06c53f53-928f-46cf-9a0c-15639acf862b | 4436.8 | -7034.4 | 2016 |
| 61038011-a124-41d2-aeed-7f0bba2bf6e5 | 4626.7 | -6994.2 | 2016 |
| bbdb9f1b-b8f1-48ad-9af5-df8424591a7d | 4454.4 | -6985.5 | 2016 |
| cc68b996-082c-412c-8731-242cb5200beb | 4471.2 | -6937.1 | 2016 |
| bca2970a-29f7-45d5-ab99-64fd863313a8 | 4522.3 | -6903.6 | 2016 |
| 014cae71-3255-47da-9149-c6b5d484b34c | 5284.4 | -6920.7 | 2016 |
| a672e766-3d99-4e64-b5f8-f342720159de | 4443.0 | -6843.2 | 2016 |
| 699bc81b-25d6-4712-b3a9-ca895b63f249 | 5202.4 | -6808.8 | 2016 |
| 382297ef-a6f9-4556-9cee-d5eb07a4c25f | 5220.9 | -6801.9 | 2016 |
| 9cf036fa-eee7-4ae6-9f8a-f597eebc7a4b | 5777.9 | -6763.7 | 2016 |
| 258515de-1226-4f04-af03-91eaa5c58f53 | 3789.0 | -6518.5 | 2016 |
| 2bdfcebf-c090-4690-8e50-d747cf67572e | 5334.5 | -6461.1 | 2016 |
| d761349e-63e3-4728-9c32-04c8806a652e | 4982.3 | -6460.4 | 2017 |
| 390afaca-522d-4f00-bb29-02ac3ea5a02c | 4466.2 | -6429.2 | 2016 |
| 9529c350-a77e-421b-9433-5dd5c65e6067 | 4654.8 | -6202.4 | 2016 |
| 4c0b2c5d-20ca-4907-9fb8-1f7cfbebd870 | 4678.0 | -6207.2 | 2016 |
| 1cf342e6-028b-4457-b214-bc3c544a4801 | 4660.0 | -6180.9 | 2016 |
| bba6f66b-4855-4f50-83fc-bf30d46891a7 | 4846.7 | -6053.1 | 2018 |
| 51cad101-1e2d-4308-a056-16401180e279 | 4726.7 | -6060.5 | 2016 |
| c6fd1fe2-95d7-419d-a071-fce19664a728 | 5504.3 | -6078.1 | 2016 |
| 6d18ea71-3273-4712-a677-953d1ba94387 | 3787.7 | -6013.9 | 2016 |
| ffcc58bf-4837-4d4f-b2db-6d76f70664ae | 3819.6 | -5989.9 | 2016 |
| c52838d7-7a15-4de0-8716-f7c2225e5323 | 3750.5 | -5967.2 | 2016 |
| 29c8f387-616e-459b-af9b-3096a32a2527 | 3809.7 | -5953.4 | 2016 |
| 999dff90-660d-4188-93af-23c3d269a9b0 | 4100.6 | -5927.8 | 2016 |
| c5061dbf-120f-47b4-b924-18501a28e396 | 4087.3 | -5907.7 | 2016 |
| 40b01556-d1fa-4684-b214-964465f2ca3e | 4266.8 | -5884.7 | 2018 |
| 0879d149-7e65-4ca3-ae28-7528320c2629 | 4546.8 | -5806.4 | 2016 |
| 95733ad7-be27-4dbb-8403-4ad363306233 | 4319.9 | -5839.6 | 2016 |

### A start_date after 2019 (1)

| OSM | x | z | start_date | building | name |
|---|---|---|---|---|---|
| way/1095432060 | 1331.7 | 1261.7 | 2022-9-1 | retail | Nhà Bà Tư Boutique Homestay |

(The tables show the first 40 rows.)

## The checks of the heights (R1)

The difference is the height of the 2.5D data minus the height of the check (m). The median absolute difference is the median of the differences with no sign.

| Check | Buildings | Mean | Median | Median absolute difference | RMSE | Note |
|---|---|---|---|---|---|---|
| 3D-GloBFP | 32948 | -4.80 | -3.70 | 4.10 | 8.35 | a building of 3D-GloBFP in an outline (46561 in the box) |
| GHS-BUILT-H | 3663 | +5.23 | +3.91 | 3.92 | 8.21 | for each cell of 90 m: the mean of the 2.5D heights, weighted by area, against AGBH |
| building:levels of OpenStreetMap | 40 | +5.75 | +1.65 | 3.45 | 17.46 | 40 buildings; the check is 3.3 m a storey |
| ATL03 roof photons, 2.5D to 40 m | 2067 | +1.56 | +1.19 | 1.86 | 4.12 | 52510 photons of a high signal confidence over 2817 outlines, 6 of them more than 150 m over the ground (clouds, out); the median of at least 3 photons over the median of the ground photons of the same pass within 40 m |
| ATL03 roof photons, towers (2.5D over 40 m) | 18 | +44.24 | +50.79 | 50.79 | 51.53 | the photons can fall on the lower parts of a tower |

The median 2.5D height for each number of storeys of OpenStreetMap: 1: 7.3 m (2), 2: 10.0 m (5), 3: 11.0 m (13), 4: 11.5 m (4), 5: 16.8 m (5), 9: 23.1 m (2), 10: 44.0 m (1), 16: 76.0 m (1), 21: 64.2 m (1), 25: 78.0 m (3), 26: 86.8 m (3).

## outlines (2026-11-22 16:52 UTC)

- the release of Overture Maps: 2026-11-18.0
- 56359 outlines; by source: {'Microsoft ML Buildings': 33087, 'Google Open Buildings': 21084, 'OpenStreetMap': 2188}


## temporal (2026-11-22 16:52 UTC)

- 1174 manifests in the bucket; 16 of EPSG:32648: ['31_EPSG_32648_2016_06_30.json', '31_EPSG_32648_2017_06_30.json', '31_EPSG_32648_2018_06_30.json', '31_EPSG_32648_2019_06_30.json', '31_EPSG_32648_2020_06_30.json', '31_EPSG_32648_2021_06_30.json', '31_EPSG_32648_2022_06_30.json', '31_EPSG_32648_2023_06_30.json', '37_EPSG_32648_2016_06_30.json', '37_EPSG_32648_2017_06_30.json', '37_EPSG_32648_2018_06_30.json', '37_EPSG_32648_2019_06_30.json', '37_EPSG_32648_2020_06_30.json', '37_EPSG_32648_2021_06_30.json', '37_EPSG_32648_2022_06_30.json', '37_EPSG_32648_2023_06_30.json']
- the tiles of the play area: 2016: 4, 2017: 4, 2018: 4, 2019: 4, 2020: 4, 2021: 4, 2022: 4, 2023: 4
- 56357 outlines in EPSG:32648
- 2016: the outlines move -3.5 m down and +2.5 m right on the raster (at that shift 67 % of the pixels of the outlines near the middle have a building)
- 2016: 4 tiles, 212 blocks with buildings, 43653 outlines with a building (31 s)
- 2017: the outlines move +1.5 m down and +1.5 m right on the raster (at that shift 67 % of the pixels of the outlines near the middle have a building)
- 2017: 4 tiles, 214 blocks with buildings, 44761 outlines with a building (62 s)
- 2018: the outlines move +2.0 m down and +3.5 m right on the raster (at that shift 69 % of the pixels of the outlines near the middle have a building)
- 2018: 4 tiles, 214 blocks with buildings, 45530 outlines with a building (93 s)
- 2019: the outlines move +3.0 m down and +1.5 m right on the raster (at that shift 69 % of the pixels of the outlines near the middle have a building)
- 2019: 4 tiles, 213 blocks with buildings, 46323 outlines with a building (123 s)
- 2020: the outlines move +3.5 m down and +1.0 m right on the raster (at that shift 70 % of the pixels of the outlines near the middle have a building)
- 2020: 4 tiles, 214 blocks with buildings, 46908 outlines with a building (159 s)
- 2021: the outlines move +3.0 m down and +2.5 m right on the raster (at that shift 69 % of the pixels of the outlines near the middle have a building)
- 2021: 4 tiles, 213 blocks with buildings, 47796 outlines with a building (190 s)
- 2022: the outlines move -1.0 m down and -1.5 m right on the raster (at that shift 68 % of the pixels of the outlines near the middle have a building)
- 2022: 4 tiles, 214 blocks with buildings, 48155 outlines with a building (220 s)
- 2023: the outlines move -1.0 m down and -0.5 m right on the raster (at that shift 71 % of the pixels of the outlines near the middle have a building)
- 2023: 4 tiles, 213 blocks with buildings, 48426 outlines with a building (252 s)
- 52569 outlines with a building in a year; the map of 2019 of the buildings with no outline: 130632 cells of 5 m more than half building


## osm2019 (2026-11-22 16:57 UTC)

- 1119 versions from the ohsome API, 1119 valid on 2019-01-22
- 1119 buildings of OpenStreetMap on 2019-01-22, 0 with building=construction
- 2 buildings of OpenStreetMap on 2026-07-26 with a start_date


## checks (2026-11-22 16:58 UTC)

- 3D-GloBFP grid 2108: 46561 buildings in the box; the columns ['Height', 'geometry']; the height Height
- GHS-BUILT-H: a window of 96 × 144 cells, 4861 with a height


## build (2026-11-22 16:59 UTC)

- D-0009-08: the first year by 30 % of the outline: 43208 up to 2019, 5247 after; by 8 pixels (no year with 30 %): 2116 up to 2019, 1118 after; fewer than 8 pixels in each year: 4670 (buildings_unseen, Check)
- 45324 buildings of 2019, 6365 out (the first year is after 2019); the first years: 2016: 37023, 2017: 3919, 2018: 2464, 2019: 1918
- the heights: median 5.8 m, 90 % under 9.8 m, the highest 90.0 m
- D-0009-04: 130632 cells of 5 m more than half building with no outline; 2714 groups of at least 4 cells at least 3 m from an outline: 39419 cells, 0.985 km²; the largest groups [356, 329, 212, 206, 192] cells
- R5d: 155 buildings of OpenStreetMap on 2019-01-22 not in the 2.5D data of 2019; 1152 outlines of OpenStreetMap of today in the 2.5D data of 2019 and not in OpenStreetMap on 2019-01-22; 1 buildings with a start_date after 2019
- the checks of the heights: 3D-GloBFP 32948; GHS-BUILT-H 3663; building:levels of OpenStreetMap 40; ATL03 roof photons, 2.5D to 40 m 2067; ATL03 roof photons, towers (2.5D over 40 m) 18

<!-- street fronts (D-0009-22) -->
## The street fronts (report 0009, D-0009-22)

For each street, each 5 m, on each side: a building from 2 m to 14 m past the edge of the road (as section 9.3 of report 0009). Before: the boxes of the outlines of 2019. After: also the boxes of the groups of the 2.5D raster of 2019 with no outline that touch a street (`raster_2019.json`, the source "raster").

| Street | Points | Before: a box of 2019 | Before: no box, the raster has a building | Before: neither | After: a box (2019 or raster) | After: no box, the raster has a building | After: neither |
|---|---:|---:|---:|---:|---:|---:|---:|
| Ba Cu | 618 | 62 % | 15 % | 23 % | 66 % | 11 % | 23 % |
| Lê Lai | 346 | 60 % | 18 % | 22 % | 67 % | 12 % | 22 % |
| Xô Viết Nghệ Tĩnh | 600 | 56 % | 15 % | 29 % | 62 % | 9 % | 29 % |
| Phan Chu Trinh | 688 | 52 % | 16 % | 32 % | 53 % | 14 % | 32 % |
| Trương Công Định | 1730 | 47 % | 21 % | 32 % | 54 % | 14 % | 32 % |
| Nam Kỳ Khởi Nghĩa | 458 | 47 % | 14 % | 40 % | 52 % | 9 % | 40 % |
| Bình Giã | 614 | 42 % | 23 % | 35 % | 55 % | 10 % | 35 % |

<!-- end of the street fronts -->
