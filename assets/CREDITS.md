# Asset credits

| Asset | Path | Source | License |
|---|---|---|---|
| Be Vietnam Pro (Regular, SemiBold, Bold, Italic) | `assets/fonts/BeVietnamPro-*.ttf` | [google/fonts](https://github.com/google/fonts/tree/main/ofl/bevietnampro), by the Be Vietnam Pro Project Authors | SIL Open Font License 1.1 (`assets/fonts/OFL.txt`) |
| Icons: sound on, sound off, notebook, arrows | `assets/icons/*.svg` | Made for this project. The shapes are the same as the 2D prototype icons. | CC0 |
| App icon | `icon.svg` | Made for this project. | CC0 |
| Sounds (ting, clack, TV upstairs) | `scripts/tones.gd` | Made in code when the game starts. No sound files. | CC0 |
| Voices | `assets/voices/*.ogg` | Made by `tools/voices/build.py` with [VieNeu-TTS v3 Turbo](https://huggingface.co/pnnbao-ump/VieNeu-TTS-v3-Turbo) (project [pnnbao97/VieNeu-TTS](https://github.com/pnnbao97/VieNeu-TTS)) and its preset voices. The model page permits commercial use of the audio of the preset voices. | Apache License 2.0 (the model, the code, and the preset voices) |
| Audio tokenizer of VieNeu-TTS | (used to make the voices, not in the game) | [MOSS-Audio-Tokenizer-Nano](https://huggingface.co/OpenMOSS-Team/MOSS-Audio-Tokenizer-Nano), OpenMOSS-Team | Apache License 2.0 |
| Phonemizer of VieNeu-TTS | (used to make the voices, not in the game) | [sea-g2p](https://github.com/pnnbao97/sea-g2p) 0.10.0. The builder checked the license: the `LICENSE` file of the repository and the package metadata are Apache License 2.0. | Apache License 2.0 |

The 3D shapes in plan 0001 are made in code (`scripts/greybox.gd`). They use no model files.

## Geodata (plan 0005)

| Asset | Path | Source | License |
|---|---|---|---|
| Map data: roads, coastline, beaches, buildings, names | `data/geo/raw/osm.pbf`, `data/geo/build/` | © OpenStreetMap contributors ([openstreetmap.org](https://www.openstreetmap.org)) | ODbL 1.0. The changed data in `data/geo/` is a Derivative Database under ODbL 1.0 (`data/geo/LICENSE`). |
| Ground height | `data/geo/raw/dem.tif`, `data/geo/build/height/` | Copernicus DEM GLO-30. Produced using Copernicus WorldDEM-30 © DLR e.V. 2010-2014 and © Airbus Defence and Space GmbH 2014-2018 provided under COPERNICUS by the European Union and ESA; all rights reserved. | Copernicus DEM license. The organisations in charge of the Copernicus programme by law or by delegation do not incur any liability for any use of the Copernicus WorldDEM-30. |
| Tide model | `data/geo/build/tide.json` | EOT20: Hart-Davis, M. G., Piccioni, G., Dettmering, D., Schwatke, C., Passaro, M., Seitz, F. (2021). EOT20 - A global Empirical Ocean Tide model from multi-mission satellite altimetry. SEANOE. [doi:10.17882/79489](https://doi.org/10.17882/79489). The game uses the tide constituents at Hòn Bà and Bãi Trước. | CC BY 4.0 |
| Tide software | (used in CI by `tools/geo/tide.py`, not in the game) | [pyTMD](https://github.com/tsutterley/pyTMD), by Tyler Sutterley | MIT License |
| Sea floor: the intertidal zone | `data/geo/raw/intertidal.tif`, `data/geo/build/height/` | Contains modified Copernicus Sentinel data 2017–2020 (Sentinel-2 L2A, from [Earth Search on AWS](https://earth-search.aws.element84.com/v1)). The heights use the pixel method of [DEA Intertidal](https://knowledge.dea.ga.gov.au/data/product/dea-intertidal) (Geoscience Australia) with the EOT20 tide (`tools/geo/intertidal.py`). | The Copernicus Sentinel data license (free use, with the notice) |
| Sea floor: the deeper water | `data/geo/raw/gebco.tif`, `data/geo/build/height/` | GEBCO Compilation Group (2025) GEBCO 2025 Grid ([doi:10.5285/37c52e96-24ea-67ce-e063-7086abc05f29](https://doi.org/10.5285/37c52e96-24ea-67ce-e063-7086abc05f29)) | Public domain, with the GEBCO terms of use |
| Ground texture: sand | `assets/textures/ground/sand/` | [Poly Haven: Coast Sand 01](https://polyhaven.com/a/coast_sand_01) | CC0 |
| Ground texture: grass | `assets/textures/ground/grass/` | [Poly Haven: Leafy Grass](https://polyhaven.com/a/leafy_grass) | CC0 |
| Ground texture: rock | `assets/textures/ground/rock/` | [Poly Haven: Rocky Terrain 02](https://polyhaven.com/a/rocky_terrain_02) | CC0 |
| Ground texture: asphalt | `assets/textures/ground/asphalt/` | [Poly Haven: Asphalt 02](https://polyhaven.com/a/asphalt_02) | CC0 |
| Ground texture: concrete | `assets/textures/ground/concrete/` | [Poly Haven: Brushed Concrete](https://polyhaven.com/a/brushed_concrete) | CC0 |

`data/geo/raw/manifest.json` records the download URL, the date, and the SHA-256 of each file. The game shows these notices on the Credits sheet (Settings → Credits).
