# The sea floor report (plan 0005, R8g)

Made by `tools/geo/build.py` on 2026-10-26.

## Sources

- The intertidal zone: 1230108 grid cells with a height from the Sentinel-2 images and the tide (`tools/geo/intertidal.py`, the pixel method of DEA Intertidal), from -1.91 m to +0.64 m.
- The deeper water: the GEBCO 2025 grid.
- Beyond the edge of the data, the floor goes down at once, at the slope of the data at its edge (the median is 0.015 m for each meter), and never flatter than 1 m in 60 m, to the GEBCO depth or to −4 m. Where no data is near, the old slope stays near the coast (from +1.2 m at the coastline to −4 m at 80 m). These heights are made, not measured.
- The images: 310 different times. 28 of them have the sea below −1.5 m, and 4 below −2.0 m (the lowest is -2.20 m). A pixel lower than the lowest tides of the images cannot have a value.

## The game days

The sea level of the game days (22 January to 28 February 2019) goes from -2.25 m to +1.45 m.
At the lowest tide, 7.23 km² of sea floor is dry: 4.47 km² from the data (sand color in the map), and 2.76 km² made (red).

![The land that is dry at the lowest tide](intertidal_dry.png)

Green: the land. Sand: the sea floor that is dry at the lowest tide, with a height from the data. Red: dry at the lowest tide, with a made height. Blue: the water at the lowest tide (darker is deeper, to 10 m).

## From the main beach of Bãi Trước out into the bay

The line starts at the water line of the data, game point (-7.9, 1.2), in the game direction (-0.99, 0.16).

| From the sand (m) | Height (m) | Source | Depth at the lowest tide (m) | Depth at the highest tide (m) |
|---|---|---|---|---|
| 0 | +1.01 | made | 0.00 | 0.44 |
| 50 | -1.53 | data | 0.00 | 2.98 |
| 90 | -1.72 | data | 0.00 | 3.17 |
| 100 | -1.84 | made | 0.00 | 3.29 |
| 150 | -2.68 | made | 0.43 | 4.13 |
| 200 | -3.52 | made | 1.27 | 4.97 |
| 250 | -4.00 | made | 1.75 | 5.45 |
| 300 | -4.00 | made | 1.75 | 5.45 |
| 350 | -4.00 | made | 1.75 | 5.45 |
| 400 | -4.00 | made | 1.75 | 5.45 |
| 450 | -4.00 | made | 1.75 | 5.45 |
| 500 | -4.00 | made | 1.75 | 5.45 |
| 550 | -4.00 | made | 1.75 | 5.45 |
| 600 | -4.00 | made | 1.75 | 5.45 |

The data ends 90 m from the water line. The rows after it are made.
