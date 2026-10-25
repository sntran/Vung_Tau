# 0006 People

| Field | Value |
|---|---|
| Status | Approved |
| Branch | `feat/0006-people` |
| Depends on | 0003 (status "Built"). Uses the quality presets of 0004 when 0004 is built. |

## 1. Goal

The people of the hẻm look like real people from Vũng Tàu. They have real bodies, faces, hair, and clothes. They move like people: they breathe, shift their weight, turn their heads to the player, blink, and sit on the low stools of the cà phê cóc. When they speak, their mouths move with the words, and their faces show the feeling of the line.

The blocks of plans 0001 to 0003 go away.

## 2. Out of scope

- Crowds on the beach and on the coast road (plan 0015).
- Work movements for one place: cooking bánh khọt, the phin of the cà phê cóc, the morning exercise at Bãi Trước. The plan of each place adds its movements (plans 0012 to 0015).
- People on scooters (plan 0018).
- The body and the hands of the player.
- Motion capture of real people.
- New dialogue lines.

## 3. Decisions

| ID | Decision | Reason |
|---|---|---|
| D1 | People are full 3D humans with a skeleton and face shapes. Do not use voxels, blocks, or low-poly figures. | Voxels and blocks cannot show a real face, a smile, or the shape of a mouth that speaks. The game is about people and their food. The player looks at their faces in each talk. |
| D2 | Make the people with MPFB 2 (MakeHuman for Blender), by a script, from the data in `data/people.json`. Pin the MPFB version (2.0.18 or later). | The code of MPFB is GPLv3. The models that it makes, and its CC0 asset packs, are CC0 ([license](https://static.makehumancommunity.org/about/license.html)). It has sliders for age, sex, weight, muscle, height, and the face. It has a game-engine skeleton. It has the 52 face shapes of the ARKit standard (`faceunits01`) and the 15 mouth shapes for speech of the Meta (Oculus) standard (`visemes02`). We have no artist, so each person is numbers in a data file. |
| D3 | Run Blender as a Python module (`bpy` from PyPI) in CI and in the workspace. Pin the version. | I checked it in the workspace: `bpy` 5.2.3 installs from PyPI, MPFB 2 loads as an extension, and a script makes a rigged older woman and exports a `.glb` in about 3 s. `blender.org` is not reachable, but PyPI is. |
| D4 | Use only the CC0 asset packs of MakeHuman when possible. A CC-BY pack is permitted only with its credit in `assets/CREDITS.md`. | `CONTRIBUTING.md` permits CC0, CC-BY, and OFL. CC0 needs no credit, but we write the source of each pack. |
| D5 | Keep our own copy of each asset pack that we use. Store it as an asset of a GitHub release in our repository (`people-packs-1`), with its SHA-256. The build downloads the packs from that release. | On 2026-10-21, MakeHuman shut down its forum and its asset repository ([news](https://static.makehumancommunity.org/news/2026-10-21-community-site-shut-down.html)). The asset packs are still online, but the future of the site is not clear. The workspace cannot reach the MakeHuman servers. GitHub release downloads work in the workspace. |
| D6 | Semi-realistic look: real proportions, real movement, a living face. Do not try for photo-real skin. | Almost-real faces that do not move correctly look wrong to people (the "uncanny valley"). Eyes that do not move are the worst part. The life of the eyes and the face is more important than the detail of the skin. |
| D7 | Body movement comes from CC0 animation libraries. Godot retargets them to our skeleton with its humanoid profile (`SkeletonProfileHumanoid` and a `BoneMap`). The first library is the Universal Animation Library of Quaternius. The builder checks its license and its content. | It has more than 120 CC0 animations on a humanoid skeleton ([Quaternius](https://quaternius.com/packs/universalanimationlibrary.html)). Retargeting lets all people share one set of animations. |
| D8 | Small movements come from code: the head and eyes turn to the person or thing of interest, the eyes blink, the eyes make small jumps (saccades), the chest breathes, and the weight shifts. | These small movements make a person look alive. A library animation cannot know where the player is. |
| D9 | Lip sync comes from the audio of each spoken line. Rhubarb Lip Sync (MIT) with its phonetic recognizer reads each voice file and writes the mouth shapes over time. The voices build runs it. | The phonetic recognizer works for languages other than English ([Rhubarb](https://github.com/DanielSWolf/rhubarb-lip-sync)). The voices are made in CI (plan 0003), so the mouth data is made in the same place, at the same time. |
| D10 | Each spoken line can have a face: `smile`, `laugh`, `proud`, `surprised`, `worried`, `frown`, or `neutral`. `data/faces.json` gives the face-shape weights of each face. | Content is data. I can change the feeling of a line without code. |
| D11 | Work in two phases. Phase A makes Bà Tư only. I judge her look, movement, face, and lip sync. Phase B makes the other people only after I approve Phase A. | The look is a matter of taste. One person is cheap to change. Seven people are not. |
| D12 | Face shapes are only on a separate head mesh. Keep only the face shapes that the game uses (R10). | A face shape stores data for each vertex of its mesh. The full body has about 13 000 faces. With 67 shapes on the full body, one person uses tens of MB of memory. On the head mesh only, it is a small part of that. |
| D13 | The prototype in `docs/prototype/people/` is the target look. I approved it. It also shows how to make the clothes that MakeHuman does not have. | It is faster to start from values and methods that work. Its README lists what we learned and the known faults. |

## 4. Requirements

### People data

- **R1.** `data/people.json` has an entry for each person: `id` (the speaker ID of the dialogue), sex, age, weight, muscle, height, the proportions of the face, the skin, the hair, the eyebrows, the clothes, the shoes, the things they carry or wear (for example a nón lá or a cloth bag), and a `seed`. The values are the MPFB slider values, so I can change them.
- **R2.** All people of this plan are Vietnamese adults from the South. Their faces and bodies have variety: not one face with different hair. The `asian` value of MPFB alone gives a general East Asian face. Use the face targets of the prototype (`docs/prototype/people/people.json`): a wider nose with a lower bridge, a shorter face, high cheekbones, lean cheeks for older people, eyes that are open enough, and mouth corners that are not low. Skin is the color of people who live in the sun: the "asian" skins of MakeHuman are light-skin textures, so lower their saturation and tint them, as the prototype does. Older people have the marks of age. Older men often have dark hair.
- **R3.** The people (I approved this table and the prototype look, see Q1):

  | Person | Age | Look | Clothes |
  |---|---|---|---|
  | Bà Tư | about 70 | Small and thin. Grey hair in a bun. | Đồ bộ with a small flower print. Dép (sandals). |
  | Cô Nga | about 48 | Medium build. Black hair in a ponytail. | A plain T-shirt and loose long trousers. Dép. |
  | Cô Sáu | about 55 | Strong arms. Black hair in a bun. A wide smile. | Đồ bộ with a red flower print. Dép. An apron at the shop (later plan). |
  | Bác Hà | about 68 | Thin, straight back. Short steel-grey hair. Glasses. From the North. | A pale short-sleeve shirt with buttons, light trousers. Dép. |
  | Cô Út | about 40 | Small, quick. Black hair in a ponytail. | A T-shirt and trousers. Dép. An apron and a cloth hat at the shop (later plan). |
  | Chú Bảy | about 62 | Thin, lean face, sunburned. Short dark hair. Glasses. | A white T-shirt and dark trousers. Dép. |
  | Chú Chín | about 60 | Heavy, round face, a belly, a ready smile. Short black hair. | An áo ba lỗ (singlet) and checked quần đùi (shorts). Dép. |

- **R4.** Clothes: start from the CC0 shirt and trousers meshes of MakeHuman, which fit the body. Keep their materials (normal maps), and replace only the base color. Make the cloth patterns by code: small flower prints for đồ bộ, checks for quần đùi, plain colors that are worn and faded. The colors come from the same kind of measured palette as the walls of plan 0004 (low saturation, with rare strong colors). Do not use a logo or a real brand. Do not use the shoes of MakeHuman: people wear dép.
- **R4a.** Make by code, with the methods of the prototype: short sleeves and knee shorts (cut a MakeHuman item, then show the skin again where the cloth is gone), the áo ba lỗ (from the torso surface of the body, cut along smooth curves), dép, and glasses. Also make the nón lá and the cloth bag by code. Each item made by code must follow the skeleton.
- **R4b.** The face of each person at rest can have a light expression from the ARKit face units (for example a small smile). It is in `data/people.json`. A line `face` (R25) adds to it.
- **R5.** Hair: use the CC0 hair meshes and hair materials. A bun, short hair, and hair tied back must exist. If no CC0 mesh has a bun, make the bun by code (a shape at the back of the head with the hair material).

### People build

- **R6.** `tools/people/build.py` reads `data/people.json`. For each person, it makes `assets/people/ID.glb` with Blender (`bpy`) and MPFB. It uses the `game_engine` skeleton of MPFB. If that skeleton cannot move the eyes and the jaw well enough with face shapes only, use `default_no_toes`, and write the reason in the builder notes.
- **R7.** The build applies the body shape, removes the helper geometry of MakeHuman, and splits each person into meshes: the head (with the eyes, eyebrows, eyelashes, and teeth), the body, the hair, and the clothes. Only the head has face shapes.
- **R8.** The build makes two levels of detail for each person: LOD0 (full mesh) and LOD1 (about a quarter of the faces, no face shapes, the head joined to the body). The builder can use the MPFB proxy meshes for LOD1.
- **R9.** `build.py` writes `assets/people/manifest.json`: for each person, the files, the triangle count of each level, the texture sizes, the face shapes, and a hash of the person entry, the MPFB version, the `bpy` version, and the pack hashes. It makes a person again only when the hash changes. `Content` checks the hashes at start, as for the voices (plan 0003, R4).
- **R10.** Face shapes to keep on the head: the 15 Meta (Oculus) visemes of `visemes02` (`viseme_sil`, `viseme_PP`, `viseme_FF`, `viseme_TH`, `viseme_DD`, `viseme_kk`, `viseme_CH`, `viseme_SS`, `viseme_nn`, `viseme_RR`, `viseme_aa`, `viseme_E`, `viseme_I`, `viseme_O`, `viseme_U`), and these ARKit face units of `faceunits01`: `eyeBlinkLeft`, `eyeBlinkRight`, `eyeLookUpLeft`, `eyeLookUpRight`, `eyeLookDownLeft`, `eyeLookDownRight`, `eyeLookInLeft`, `eyeLookInRight`, `eyeLookOutLeft`, `eyeLookOutRight`, `eyeSquintLeft`, `eyeSquintRight`, `eyeWideLeft`, `eyeWideRight`, `browInnerUp`, `browDownLeft`, `browDownRight`, `browOuterUpLeft`, `browOuterUpRight`, `cheekSquintLeft`, `cheekSquintRight`, `mouthSmileLeft`, `mouthSmileRight`, `mouthFrownLeft`, `mouthFrownRight`, `mouthPressLeft`, `mouthPressRight`, `jawOpen`, `noseSneerLeft`, `noseSneerRight`. A face in `data/faces.json` can use only these.
- **R11.** Done: `.github/workflows/people-packs.yml` (by hand only) copied the asset packs in `tools/people/packs.json` from the MakeHuman servers to the release `people-packs-1` of our repository. The files `packs.lock.*.json` in the release give the source, the license, and the SHA-256 of each pack. Add a `tools/people/packs.py` that downloads each pack that `data/people.json` uses from that release only, and checks its SHA-256. A pack that is not CC0 or CC-BY stops the build. Unzip the packs into the MPFB user data folder (see the prototype README).
- **R12.** `.github/workflows/people.yml` runs by hand, and on a push to `main` that changes `data/people.json`, `data/faces.json`, or `tools/people/`. It runs `build.py` and commits the changed files to `main` with the identity in `CONTRIBUTING.md` and the message "Update the people". It also renders a picture of each person (front, three-quarter, and face) with Blender into `docs/people/`, and the export workflow publishes the pictures at `/people/` on GitHub Pages, as for the voice audition.
- **R13.** Add MPFB, each asset pack, each animation library, and Rhubarb Lip Sync to `assets/CREDITS.md`, with the license and the source.

### Movement

- **R14.** Godot imports each person with a `BoneMap` to `SkeletonProfileHumanoid`. All people use the same retargeted animations.
- **R15.** Animations of this plan: two or more idle animations for standing (with weight shifts and breathing), talk gestures (small hand and head movements, used during a spoken line), a walk, sitting on a low stool, and standing up from it. Each person plays the idle animations in a random order with a random start time, so two people never move the same way at the same time.
- **R16.** Sitting on a low stool: the stools of the cà phê cóc are 0.32 m high (plan 0003, N11). The hips are on the top of the stool, the knees are high, and the feet are flat on the ground. If no library has this pose, the builder makes the pose by code (bone rotations in a data file) and blends it with the breathing of an idle animation. Chú Bảy and Chú Chín sit on stools. Their `height` value of 1.2 in `hem_layout.json` goes away.
- **R17.** Look-at: during a talk, the person looks at the player. The eyes turn first, then the head and the neck (`LookAtModifier3D` or the same), with limits: head and neck together at most 70° to the side and 30° up or down. When the player is outside these limits for more than 1 s, the person turns the body with a step. The turn of plan 0003 (N4) becomes this smooth turn.
- **R18.** Out of a talk, a person sometimes looks at the player when the player comes within 4 m, for 1 to 3 s, then looks back at their work. People who talk to each other (Chú Bảy and Chú Chín) look at each other.
- **R19.** One walker: a neighbor (no talk, no name) walks the hẻm at 07:00 and at 17:00 with a plastic bag. The walk speed matches the animation, so the feet do not slide. The walker goes around the player.

### Face and speech

- **R20.** Blinks: every 2 to 6 s at random, 0.10 to 0.15 s long. A person also blinks at the start of a large eye turn.
- **R21.** Saccades: during a talk, the eyes make a small jump every 0.5 to 2.5 s, within 3° of the target.
- **R22.** The voices build (`tools/voices/build.py`) also runs Rhubarb Lip Sync with the phonetic recognizer on each voice file of a person. Pin the Rhubarb version. Add the mouth cues to `assets/voices/manifest.json` for each clip. The hash of a clip does not change. A clip with no cues gets them on the next build.
- **R23.** Map the Rhubarb mouth shapes to the visemes: A to `viseme_PP`, B to `viseme_kk`, C to `viseme_E`, D to `viseme_aa`, E to `viseme_O`, F to `viseme_U`, G to `viseme_FF`, H to `viseme_nn`, X to `viseme_sil`. Blend between two shapes over 60 ms. Put the map in `data/faces.json`.
- **R24.** The mouth moves only while the audio of the line plays. It follows the audio position (`get_playback_position()`), not a timer. When the line stops, the mouth goes to rest in 100 ms.
- **R25.** Add the optional field `face` to a spoken line in `data/dialogue/*.json`. The face shows from the start of the line to 0.8 s after its end, then goes back to `neutral`. The builder sets a first `face` for each line with the status "check". I approve them.
- **R26.** If the Rhubarb result does not look correct for Vietnamese (Phase A), the second choice is: `jawOpen` from the loudness of the audio, with a viseme from the vowel of each syllable of the `say` text. I decide in Phase A.

### Distance and performance

- **R27.** The face (blinks, saccades, mouth, face) updates only when the person is within 10 m and on the screen. The skeleton updates only when the person is on the screen. LOD1 shows from 12 m. On the Low preset, LOD1 shows from 6 m.
- **R28.** Budget for all people on the screen together, as a part of the budget of plan 0004 (R14): at most 20% of the triangles and at most 40 draw calls. The textures of one person use at most 24 MB of video memory at High, and 8 MB at Low (smaller textures at Low). Measure the memory of the face shapes of one person, and record it in the builder notes.
- **R29.** On desktop High and Ultra, the skin uses subsurface scattering. On Low and on the web build, it does not.

### The `Npc` class

- **R30.** `Npc` keeps its API and its touch area, solid body, and voice (`face()`, `facing()`, `head_position()`, `set_present()`). `head_position()` uses the head bone. The touch area and the solid body fit the new size of each person.
- **R31.** Remove `Greybox.person()` after all people use the new models.

## 5. Phases

- **Phase A.** R1 to R30 for Bà Tư only, and the walker of R19 with a simple version of the build. Then the builder sends me the pictures of R12, screenshots at 1.5 m and 5 m at 07:00 and 17:30, and a video of 20 s of a talk with Bà Tư (Godot `--write-movie`). The status stays "In progress". I answer in the plan under "Open questions".
- **Phase B.** After I approve Phase A: the other six people, the cà phê cóc stools, R31, and all play tests.

## 6. Play-test scenarios

The play-test driver needs: `bone_position(npc_id, bone)`, `blend_shape(npc_id, name)` (the current weight), `look_target(npc_id)`, `lod(npc_id)`, and `people_budget()` (triangles, draw calls, and video memory of the people).

Run each scenario at 1280×720 and 2400×1080, unless the scenario says otherwise.

- **PT-40 `people_look`.** Each person in fixed views at 1.5 m and at 5 m, at 07:00 and 17:30, on the Mobile renderer and on Forward+ High (stills). I compare them.
- **PT-41 `talk_face`.** Talk with Bà Tư. During her line, sample the visemes every 0.1 s. They follow the mouth cues of the manifest within one frame. The line `face` shows, then goes back to `neutral`. After the line, the mouth is at rest within 100 ms. Ask her to say it again ("Dạ, bà nói lại được không ạ?"): the mouth moves again.
- **PT-42 `blink_and_eyes`.** Stand 2 m from Bà Tư for 30 s of game time. Count the blinks: 5 to 15. During a talk, the eye target stays within 3° of the head of the player.
- **PT-43 `look_at`.** In a talk, walk in a circle at 2 m around Bà Tư. The head turn never goes past the limits of R17. When the player is behind her, she turns her body within 2 s. At no time does the neck turn more than 70°.
- **PT-44 `seated`.** At 06:00, Chú Bảy and Chú Chín sit at the cà phê cóc. The hips are within 3 cm of the stool top. The feet are within 3 cm of the ground. No bone of the legs is inside the stool. They look at each other while they talk.
- **PT-45 `walker`.** At 07:00, the walker walks the hẻm. During each step, the foot on the ground moves less than 0.1 m/s. Stand in the path: the walker goes around the player and does not go through walls.
- **PT-46 `people_budget`.** At 3 fixed views with all people present, on each preset: the budget of R28. At 15 m, `lod()` is 1 and the face does not update.
- **PT-47 `people_web`.** On the Compatibility renderer: all people show, the visemes move in a talk, and Godot prints no errors.

PT-01, PT-03 to PT-24 must still pass. A play test that taps a person must tap the new model.

## 7. Acceptance criteria

1. I approved Phase A.
2. The people workflow ran in CI. Each person has a model, and the pictures are on GitHub Pages at `/people/`.
3. Each pack, animation library, and tool is in `assets/CREDITS.md` with its license.
4. All unit tests and all play tests pass. The builder looked at all screenshots.
5. Unit tests check: the people data rules (R1, R2, R10), the map of R23, the blink and saccade times, the manifest hashes, and that a pack with a bad license stops the build.
6. `AGENTS.md` describes the people build, the people workflow, the faces, and the measured budget.
7. On the Android debug APK, the people show and move at Low, and the frame rate is not lower than before this plan by more than 10%.

## 8. Open questions

- **Q1.** Answered: the R3 table and the prototype look (`docs/prototype/people/people_v3.jpg`) are close enough for now. The women's faces had no reference photos. I can send photos later.
- **Q2.** Does Rhubarb make a good mouth for Vietnamese? I decide in Phase A (R26).
- **Q3.** Is the look of Phase A good, or must it be more realistic or more simple? I decide in Phase A.

## 9. Builder notes
