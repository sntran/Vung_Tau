# The lidar points of the play area (plan 0009, R5a and R5c)

Made by `tools/geo/lidar.py`. Do not change by hand.

## lidar seed (2026-11-19 23:59 UTC)

- seed atl03_ground 86f606a: 2018 98228, 2019 168384, 2020 48543, 2021 41168, 2022 108229, 2023 119835, 2024 68270, 2025 148200, 2026 95798
- seed atl03_ground a36c84e: 2018 98228, 2019 168384, 2020 48543, 2024 68270
- seed atl03_ground 7d32458: 2018 98228, 2019 168384, 2020 48543, 2021 41168, 2022 108229, 2023 119835, 2024 68270, 2025 148200, 2026 95798
- seed atl08 86f606a: 2019 3603, 2020 3, 2022 1139
- seed atl08 a36c84e: 2019 5627, 2023 2202, 2024 2851
- seed atl08 7d32458: 2019 3603, 2020 3, 2022 1139
- seed atl24 86f606a: 2018 8505, 2019 6270, 2020 3551, 2021 3309, 2022 1407, 2023 2568, 2024 3634, 2025 3685
- seed atl24 a36c84e: 2018 8505, 2019 6270, 2020 3551, 2021 3309, 2022 1407, 2023 2568, 2024 3634, 2025 3685
- seed atl24 7d32458: 2018 8505, 2019 6270, 2020 3551, 2021 3309, 2022 1407, 2023 2568, 2024 3634, 2025 3685
- seed gedi02a 86f606a: 2019 384, 2021 74, 2022 23, 2023 416, 2024 72, 2025 153
- seed gedi02a a36c84e: 2019 188
- seed gedi02a 7d32458: 2019 384, 2021 74, 2022 23, 2023 416, 2024 72, 2025 153

## lidar fetch (2026-11-21 04:27 UTC)

- sliderule 5.8.1, 2018-10-14T00:00:00Z to 2026-11-21T00:00:00Z
- atl08 2026: 4919 rows (it had 4919)
- atl03_ground 2026: 95798 rows (it had 95798)
- atl03_roof 2026: 11909 rows (it had 11909)
- atl24 2026: 2500 rows (it had 2500)
- gedi02a 2018: 0 rows; the file of the last good run stays (None rows)
- gedi02a 2020: 0 rows; the file of the last good run stays (None rows)
- gedi02a 2026: 0 rows; the file of the last good run stays (None rows)

## lidar tracks (2026-11-21 04:28 UTC)

- the short form: 44185 bins of 20 m from 957089 photons (2215 KB, data/geo/build/lidar_tracks.json)

## lidar report (2026-11-21 04:28 UTC)


## The points in the store (the head of the branch)

| Product | 2018 | 2019 | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 | 2026 | All |
|---|---|---|---|---|---|---|---|---|---|---|
| atl08 | 4654 | 8016 | 3411 | 2464 | 7599 | 5573 | 4464 | 9774 | 4919 | 50874 |
| atl03_ground | 98228 | 168384 | 48543 | 41168 | 108229 | 119835 | 68270 | 148200 | 95798 | 896655 |
| atl03_roof | 5662 | 5679 | 2244 | 2090 | 8474 | 8543 | 6515 | 9318 | 11909 | 60434 |
| atl24 | 8505 | 6270 | 3551 | 3309 | 1407 | 2568 | 3634 | 3685 | 2500 | 35429 |
| gedi02a | – | 384 | – | 74 | 23 | 416 | 72 | 153 | – | 1122 |

## The passes of each product and year (D-0009-09)

A year is complete when ATL08 has each pass of the ATL03 ground photons, and the ground photons each pass of ATL08 and of the roof photons. ATL24 (passes over the water only) and GEDI (another satellite) are not compared. The next run asks again for a product of a year that is not complete.

| Product | 2018 | 2019 | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 | 2026 | All |
|---|---|---|---|---|---|---|---|---|---|---|
| atl08 | 2 | 5 | 4 | 2 | 4 | 4 | 2 | 5 | 2 | 30 |
| atl03_ground | 2 | 5 | 4 | 2 | 4 | 4 | 2 | 5 | 2 | 30 |
| atl03_roof | 2 | 5 | 4 | 1 | 4 | 4 | 2 | 5 | 2 | 29 |
| atl24 | 2 | 5 | 5 | 2 | 5 | 5 | 3 | 5 | 2 | 34 |
| gedi02a | – | 1 | – | 2 | 1 | 2 | 1 | 1 | – | 8 |

## R5c: the sea floor

| Source | Points | Mean difference (m) | RMSE (m) |
|---|---|---|---|
| intertidal.tif | 2994 | 0.88 | 2.27 |
| gebco.tif | 35429 | 5.02 | 10.09 |
- the map of the depths of ATL24: lidar_seafloor.png

## lidar mdt (2026-11-20 01:34 UTC)

## D-0009-07: the mean sea level over EGM2008 (R5c)

ATL24 is over EGM2008 and the intertidal heights are over the mean sea level, so ATL24 minus the intertidal height is the mean sea level over EGM2008 if both sources are correct.

| Points | ATL24 minus intertidal (m) | DTU22MDT (m) | Error of DTU22MDT (m) | DTU21MSS minus EGM2008 (m) | Rest: ATL24 minus intertidal minus DTU22MDT (m) |
|---|---|---|---|---|---|
| Bãi Trước: 34 | 1.02 (median 0.94) | 1.16 | 0.07 | 1.20 | -0.14 |
| Bãi Sau: 2432 | 0.84 (median 1.02) | 1.16 | 0.07 | 0.85 | -0.32 |
| the other points: 528 | 1.03 (median 1.22) | 1.16 | 0.07 | 0.97 | -0.13 |
| all of R5c: 2994 | 0.88 (median 1.05) | 1.16 | 0.07 | 0.88 | -0.28 |

- The parts (west, south, east, north): Bãi Trước (107.04, 10.315, 107.085, 10.36); Bãi Sau (107.085, 10.32, 107.13, 10.42).
- DTU22MDT: Knudsen and others (DTU Space), https://ftp.space.dtu.dk/pub/DTU22/MDT/dtu22mdt.grd.gz; DTU21MSS: https://ftp.space.dtu.dk/pub/DTU21/1_MIN/DTU21MSS_1min_WGS84.nc.zip.
- The geoid EGM2008 at each point: the mean of height minus height_egm2008 of the 30 nearest ground photons of ATL03 (the PROJ grid of the fetch).
- DTU21MSS is a mean of 1993 to 2012 and has the mean-tide system; EGM2008 and ATL24 have the tide-free system. At 10° N the two systems of the geoid differ by about (1 + 0.3) × (9.9 − 29.6 sin² 10°) cm = 0.12 m. The sea level of the South China Sea goes up about 4 mm each year, so the mean of 2018 to 2025 is about 0.06 m over the mean of 1993 to 2012.
