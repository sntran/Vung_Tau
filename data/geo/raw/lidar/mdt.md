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
