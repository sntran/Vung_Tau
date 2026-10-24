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
