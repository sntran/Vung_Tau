## lidar report (2026-11-22 16:59 UTC)


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

ATL24 over the mean sea level (its height over EGM2008 minus 1.16 m, the mean dynamic topography of DTU22, plan 0009, R5b) minus the source.

| Source | Points | Mean difference (m) | RMSE (m) |
|---|---|---|---|
| intertidal.tif | 2994 | -0.28 | 2.11 |
| gebco.tif | 35429 | 3.86 | 9.56 |
- the map of the depths of ATL24: lidar_seafloor.png
