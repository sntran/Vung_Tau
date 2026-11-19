# The lidar points of the play area (plan 0009, R5a and R5c)

Made by `tools/geo/lidar.py`. Do not change by hand.

## lidar fetch (2026-11-19 17:39 UTC)

- sliderule 5.8.1, 2018-10-14T00:00:00Z to 2026-11-19T00:00:00Z
- atl08: atl08p gave 10680 rows; the columns: ['veg_ph_count', 'landcover', 'spot', 'h_canopy', 'h_max_canopy', 'gt', 'h_mean_canopy', 'canopy_openness', 'gnd_ph_count', 'rgt', 'x_atc', 'h_te_median', 'h_min_canopy', 'snowcover', 'solar_elevation', 'ph_count', 'cycle', 'canopy_h_metrics', 'segment_id', 'geometry']
- atl08: 10680 points in data/geo/raw/lidar/atl08.json
- atl03_ground: atl03x 2018: 98228 rows
- atl03_ground: atl03x 2019: 168384 rows
- atl03_ground: atl03x 2020: 48543 rows
- atl03_ground: atl03x 2021: 0 rows
- atl03_ground: atl03x 2022: 0 rows
- atl03_ground: atl03x 2023: 0 rows
- atl03_ground: atl03x 2024: 68270 rows
- atl03_ground: atl03x 2025: 0 rows
- atl03_ground: atl03x: no time for 2026 and later
- atl03_ground: atl03x gave 383425 rows; the columns: ['region', 'gt', 'spacecraft_velocity', 'solar_elevation', 'rgt', 'ph_index', 'height', 'atl08_class', 'spot', 'x_atc', 'y_atc', 'srcid', 'cycle', 'atl03_cnf', 'background_rate', 'segment_id', 'quality_ph', 'geometry']
- atl03_ground: 383425 points in data/geo/raw/lidar/atl03_ground.json
- atl24: atl24x: no time for 2018 and later
- gedi02a: gedi02ap gave 188 rows; the columns: ['sensitivity', 'elevation_lm', 'flags', 'track', 'beam', 'solar_elevation', 'elevation_hr', 'orbit', 'geometry']
- gedi02a: 188 points in data/geo/raw/lidar/gedi02a.json

## lidar report (2026-11-19 19:07 UTC)


## R5c: the sea floor

| Source | Points | Mean difference (m) | RMSE (m) |
|---|---|---|---|
| intertidal.tif | 2825 | 0.91 | 2.06 |
| gebco.tif | 32929 | 5.09 | 10.07 |
- the map of the depths of ATL24: lidar_seafloor.png
