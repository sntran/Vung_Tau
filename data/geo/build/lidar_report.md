# The lidar points of the play area (plan 0009, R5a and R5c)

Made by `tools/geo/lidar.py`. Do not change by hand.

## lidar fetch (2026-11-19 16:04 UTC)

- sliderule 5.8.1, 2018-10-14T00:00:00Z to 2026-11-19T00:00:00Z
- atl08: atl08p gave 4745 rows; the columns: ['ph_count', 'gt', 'solar_elevation', 'spot', 'cycle', 'segment_id', 'h_te_median', 'rgt', 'h_mean_canopy', 'h_canopy', 'canopy_h_metrics', 'veg_ph_count', 'h_min_canopy', 'snowcover', 'x_atc', 'gnd_ph_count', 'canopy_openness', 'landcover', 'h_max_canopy', 'geometry']
- atl08: 4745 points in data/geo/raw/lidar/atl08.json
- atl03_ground: atl03x 2018: 98228 rows
- atl03_ground: atl03x 2019: 168384 rows
- atl03_ground: atl03x 2020: 48543 rows
- atl03_ground: atl03x 2021: 41168 rows
- atl03_ground: atl03x 2022: 108229 rows
- atl03_ground: atl03x 2023: 119835 rows
- atl03_ground: atl03x 2024: 68270 rows
- atl03_ground: atl03x 2025: 148200 rows
- atl03_ground: atl03x 2026: 95798 rows
- atl03_ground: atl03x gave 896655 rows; the columns: ['region', 'gt', 'spacecraft_velocity', 'solar_elevation', 'rgt', 'ph_index', 'height', 'atl08_class', 'spot', 'x_atc', 'y_atc', 'srcid', 'cycle', 'atl03_cnf', 'background_rate', 'segment_id', 'quality_ph', 'geometry']
- atl03_ground: 896655 points in data/geo/raw/lidar/atl03_ground.json
- atl24: atl24x 2018: 8505 rows
- atl24: atl24x 2019: 6270 rows
- atl24: atl24x 2020: 3551 rows
- atl24: atl24x 2021: 3309 rows
- atl24: atl24x 2022: 1407 rows
- atl24: atl24x 2023: 2568 rows
- atl24: atl24x 2024: 3634 rows
- atl24: atl24x 2025: 3685 rows
- atl24: atl24x: no time for 2026 and later
- atl24: atl24x gave 32929 rows; the columns: ['region', 'class_ph', 'gt', 'surface_h', 'rgt', 'ortho_h', 'confidence', 'spot', 'x_atc', 'y_atc', 'srcid', 'cycle', 'quality_ph', 'geometry']
- atl24: 32929 points in data/geo/raw/lidar/atl24.json
- gedi02a: gedi02ap gave 1122 rows; the columns: ['track', 'solar_elevation', 'orbit', 'sensitivity', 'beam', 'elevation_lm', 'flags', 'elevation_hr', 'geometry']
- gedi02a: 1122 points in data/geo/raw/lidar/gedi02a.json

## lidar report (2026-11-19 17:33 UTC)


## R5c: the sea floor

| Source | Points | Mean difference (m) | RMSE (m) |
|---|---|---|---|
| intertidal.tif | 2825 | 0.91 | 2.06 |
| gebco.tif | 32929 | 5.09 | 10.07 |
- the map of the depths of ATL24: lidar_seafloor.png
