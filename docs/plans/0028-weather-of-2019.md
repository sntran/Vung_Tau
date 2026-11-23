# 0028 The weather of 2019

| Field | Value |
|---|---|
| Status | Draft |
| Branch | `feat/0028-weather`, made from the newest branch of the town when the work starts (plan 0018 after it is Built, else plan 0009). |
| Depends on | 0005 (the sun and the sky of the real date), 0018 (the clock at the speed of real time), 0020 (the wind in the trees), 0026 (the grading of each hour, the sea). |
| Changes | 0005 (the sky gets clouds), 0026 (`data/look/grading.json`: the haze follows the humidity). |

## 1. Goal

Each hour of each day of the game has the weather that Vũng Tàu had in that hour in 2019: the clouds, the light of the sun, the wind, the rain, the haze, and the sea. A morning of 22 January 2019 in the game looks like that morning in the town.

## 2. Out of scope

- People who react to the rain (umbrellas, ponchos, people under the awnings): the plan of how people move.
- Puddles, floods, and lightning.
- A weather app on the phone.
- Weather for days after the last day of the game.

## 3. Decisions

| # | Decision | Why |
|---|---|---|
| D1 | The source is the hourly model data of the past: ECMWF IFS (9 km, from 2017), else ERA5 (25 km, from 1940), from the Historical Weather API of Open-Meteo. The data is CC BY 4.0, with the credit of Open-Meteo and of the Copernicus Climate Change Service. | No airport in Vũng Tàu publishes METAR reports. The model data has each hour of 2019, with the clouds at three heights, the rain, the wind at 10 m, the humidity, and the light of the sun. |
| D2 | The builder looks for the observations of the weather station of Vũng Tàu (WMO 48903) for January and February 2019 (for example in the Integrated Surface Database of NOAA). If they exist, their rain and their clouds correct the model, where the model at 9 km misses a local shower. If they do not exist, the model alone is the source. | A station on the ground is the best record of a day. |
| D3 | The days: 22 January 2019 to 28 February 2019, each hour, in `data/weather/2019.json`, with its sources. The game reads only that file: no network while it runs. Between two hours the values change smoothly. | The game covers about the first 22 days (plan 0021), and some more days are cheap. |
| D4 | The clouds: a layer of clouds on the sky with the cover of the low, the middle, and the high clouds of the hour, which moves with the wind. The sun gets darker behind the clouds by the share of its light of the hour (the light of the hour against the light of a clear sky at the same sun height). The same on each renderer, also on the web, at a low cost on Low. | Most days of January and February are in the dry season, so the clouds and the light make most of the change from day to day. |
| D5 | The wind of the hour moves the trees (`scripts/wind.gd`) and the foam and the waves of the sea, from its speed and its direction. | The wind exists in the game already, with values by the time only. |
| D6 | Rain only in the hours with rain in the data: drops near the eye, the ground and the roofs darker and wet, the sound of rain with its caption ("[mưa rơi]"). | Rain is rare in these months, so it must come when the data says so, not by chance. |
| D7 | The haze of `data/look/grading.json` grows with the humidity of the hour. | A humid morning is hazy over the bay. |
| D8 | A play test and a tester can force the weather: the argument `--weather=clear|cloudy|rain` and the URL parameter `weather` of the web build. | The views of the other plans must stay the same from run to run. |

## 4. Requirements

- **R1.** `tools/geo/weather.py` gets the hourly values of D1 and D2 for the points of the town (Bãi Trước) and of the sea in front of it, and writes `data/weather/2019.json` and `data/weather/report.md` (a chart of each day: the clouds, the rain, the wind, the temperature). It runs in the workspace or in CI. `--check` needs no network. Credits in `assets/CREDITS.md`.
- **R2.** The game reads the file at the start, and gives the weather of the clock of plan 0018 to the sky, the light, the wind, the rain, the haze, and the sea (`scripts/weather.gd`).
- **R3.** The layer of clouds of D4, and the light of the sun of D4. On Low it costs at most 2 draw calls.
- **R4.** The wind of D5, the rain of D6, and the haze of D7.
- **R5.** The argument and the URL parameter of D8. The play tests of the other plans run with `--weather=clear`, so their views and their limits stay the same.
- **R6.** AGENTS.md, section 5: the source, the file, the commands, and the argument.

## 5. Play-test scenarios

- **PT-82 `weather_days`.** On Low and High, at the five shots of plan 0026 and the view `nui_nho_top` of plan 0009, at three times of three real days: the clearest day, the cloudiest day, and the hour with the most rain (or the cloudiest hour, if no hour has rain). Screenshots in a sheet with the values of each hour (`docs/weather/`). Checks: the share of the sky that is cloud is within 0.2 of the cover of the hour; the sun is darker in a cloudy hour than in a clear hour of the same sun height; the trees move more in the windiest hour than in the calmest; the rain shows only in an hour with rain; the budget of plan 0009 holds on Low.

## 6. Acceptance criteria

| # | Criterion |
|---|---|
| 1 | The unit tests, PT-82, and the play tests of the other plans (with `--weather=clear`) pass, and CI is green. |
| 2 | I look at the sheets of PT-82 next to my memory of the season. |

## 7. Open questions

- **Q1.** If no hour of the game days has rain in the data, do I want one rainy afternoon anyway? (I answer.)
