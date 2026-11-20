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

## lidar fetch (2026-11-19 23:59 UTC)

- sliderule 5.8.1, 2018-10-14T00:00:00Z to 2026-11-19T00:00:00Z
- atl08 2018: 4654 rows (it had None)
- atl08 2021: 2464 rows (it had None)
- atl08 2025: 9774 rows (it had None)
- atl08 2026: 4919 rows (it had None)
- atl03_ground 2026: 95798 rows (it had 95798)
- atl03_roof 2018: 5662 rows (it had None)
- atl03_roof 2019: 5679 rows (it had None)
- atl03_roof 2020: 2244 rows (it had None)
- atl03_roof 2021: atl03x: ValueError: no frame
- atl03_roof 2021: None rows; the file of the last good run stays (None rows)
- atl03_roof 2022: atl03x: ValueError: no frame
- atl03_roof 2022: None rows; the file of the last good run stays (None rows)
- atl03_roof 2023: atl03x: ValueError: no frame
- atl03_roof 2023: None rows; the file of the last good run stays (None rows)
- atl03_roof 2024: 6515 rows (it had None)
- atl03_roof 2025: 9318 rows (it had None)
- atl03_roof 2026: 11909 rows (it had None)
- atl24 2026: 2500 rows (it had None)
- gedi02a 2018: 0 rows; the file of the last good run stays (None rows)
- gedi02a 2020: 0 rows; the file of the last good run stays (None rows)
- gedi02a 2026: 0 rows; the file of the last good run stays (None rows)

## lidar tracks (2026-11-20 01:08 UTC)

- the short form: 43772 bins of 20 m from 937982 photons (2193 KB, data/geo/build/lidar_tracks.json)

## lidar report (2026-11-20 01:09 UTC)


## The points in the store (the head of the branch)

| Product | 2018 | 2019 | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 | 2026 | All |
|---|---|---|---|---|---|---|---|---|---|---|
| atl08 | 4654 | 5627 | 3 | 2464 | 1139 | 2202 | 2851 | 9774 | 4919 | 33633 |
| atl03_ground | 98228 | 168384 | 48543 | 41168 | 108229 | 119835 | 68270 | 148200 | 95798 | 896655 |
| atl03_roof | 5662 | 5679 | 2244 | – | – | – | 6515 | 9318 | 11909 | 41327 |
| atl24 | 8505 | 6270 | 3551 | 3309 | 1407 | 2568 | 3634 | 3685 | 2500 | 35429 |
| gedi02a | – | 384 | – | 74 | 23 | 416 | 72 | 153 | – | 1122 |

## R5c: the sea floor

| Source | Points | Mean difference (m) | RMSE (m) |
|---|---|---|---|
| intertidal.tif | 2994 | 0.88 | 2.27 |
| gebco.tif | 35429 | 5.02 | 10.09 |
- the map of the depths of ATL24: lidar_seafloor.png
