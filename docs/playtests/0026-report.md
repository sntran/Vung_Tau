# Report 0026: Showcase of Bãi Trước (interim)

| Field | Value |
|---|---|
| Plan | [0026 Showcase: Bãi Trước](../plans/0026-showcase-bai-truoc.md) |
| Branch | `feat/0026-showcase-bai-truoc` at commit `935b57a` |
| Date | 2026-11-16 |
| Scope | Phases 2 to 6 as built. The plan is "In progress". |

## 1. Runs

| Play test | Result |
|---|---|
| PT-75 `showcase_people` (17:00 and 12:00, Low) | Pass. 0 swimmers: they wait for Q-W6. |
| PT-74 `showcase_walk`, run 5 (892 m to 1 115 m, Hạ Long) | **Fail, two times of two.** The player stops at 1 113 m, at (−217.6, 442.0), on a slope of 37° (floor normal y 0.79), and is 0.52 m over the ground at (−175, 387). |
| PT-74 `showcase_walk`, run 6 (1 115 m to the jetty) | Pass. |
| PT-72 sheets of the branch (`docs/showcase/sheet_S1.jpg` to `sheet_S5.jpg`) | I looked at the four images of each shot. |

## 2. Defects

### D-0026-01: The player stops near Hải Âu (high)

PT-74 run 5 fails in the workspace two times of two (see section 1); the builder reports a pass. A test that passes on one computer and fails on another hides a defect that a player finds. Find the cause (the walk on the sea wall ends, and the route goes on a slope of 37° that the player cannot climb), correct the ground or the route, and make the run give the same result on each computer (with `PLAYTEST_MAX_FPS=3` too).

### D-0026-02: The shots do not show their places (high)

A shot is the view of its photo. Now:

- **S3** is half asphalt and a sidewalk. The bars of the numbers 4 to 26, the scooters, the people, and Cảng vụ at the end of the street are not in the frame.
- **S4**: three plain boxes of the stand-ins stand in front of the Grand Hotel and hide its ground storey and its fence.
- **S1**: the hotels of Hạ Long, which the photo of S1 shows behind the beach, are not there (stand-ins of 1 storey, Q6).

Put the eye of each shot at the place of its photo (the geotags are in the survey of World plan 0018, `sources.photos`), in the direction of the photo, with its field of view, so that the sheet compares the same view. Take the stand-ins of S4 out, or give them their real storeys.

### D-0026-03: The slope of Hạ Long is bare (medium)

From the junction of Quang Trung to Hải Âu, the side of the hill is brown ground with a few palms (PT-74 run 5, `403` to `406`). In the real street, houses and hotels stand there. Put the houses of the street rules of World (plan 0009, D3) or stand-ins with their storeys there.

### D-0026-04: The edges of the walk of Hạ Long are steps of 0.5 m (medium)

The checker tiles of the walk on the sea wall have a jagged edge and steps in their surface (`403`, `405`): the walk comes from the mask of 0.5 m. Make the walk a mesh along its line, with a straight edge and a smooth surface.

### D-0026-05: The far hill trees look like patches (medium)

In S2, S4, and S5, the slopes of Núi Lớn and Núi Nhỏ are dark and light patches, as camouflage. This is the far form of the hill trees (plan 0020). It is the background of most shots of the area, so correct it here.

### D-0026-06: The sea at noon is too blue (low)

At 12:00 the water of S1 is a bright cyan, as a pool. The water of Bãi Trước is green grey. Correct the color of the water by the hour in `data/look/grading.json` or in the sea shader.

### D-0026-07: The park looks empty (medium)

At 17:00 the 40 people are on about 1.3 km of paths: the shots show 0 to 3 people. In the real park at 17:00 people walk on the walk of the sea, sit on the walls, sell drinks and snacks, and children play. Put the people where the shots and the player are (the walk of the sea at sunset, the squares, the benches, the sellers), and make PT-75 count the people in each shot.

### D-0026-08: Plain parts (low)

The low lamps of the park are white posts, and the raised lawns are boxes with a flat green top. Make them as drawings of edits, from photos (D-0026-09).

### D-0026-09: The requests ask World to make the models (high)

`data/world/requests/bai_truoc.json` asks World to design the things of the park, the sea wall, the plants, and the clothes (Q-W5 to Q-W8 give "needs" and no sizes), and two sources say "not looked at". World is an engine with tools, as Dreams: this game makes its models with them (`docs/world-models.md`). Make each model as a drawing, a blueprint in data, or an order with edits, with sizes measured from photos that you looked at. Ask World only for a tool that is missing (section 5 of that file). Also, write the data as from me (first person), not "the owner".

### D-0026-10: The Palace Hotel is not there (medium)

The Palace Hotel (1 Nguyễn Trãi, OpenStreetMap node 7402231824, near (212, 53)) is across from the park, near the Grand Hotel. It is a block of about 8 or 9 storeys with its name in large letters on the roof (`docs/content/reference/video-1992.md`, 2:15), and it stood in 2019. Find its outline (one of the ways 791795129, 791795130, 791795131) and its 2019 look from photos, and make its model (D5).

## 3. World

- **The catalog of World is behind its code (Q9).** At World `8fbf36c`, the code of `honda_vision_110` has the joint `side_stand` (World `a87e283`), but `priv/models/honda_vision_110.*` is from 2026-11-08, with no joints. So the factory and a clone give different bytes, and the R4 test of plan 0023 fails correctly. World must build its catalog files again from its code at each commit, and its CI must fail when they differ.
- **People at the mid and far levels** take one mean color for all faces under an item of clothes, and the near level of a person cannot be built by the factory. The builder worked around both. They are faults of World.
- **Corrected at World `1984a6f` (2026-11-17):** the catalog is the build of the code, and the CI of World fails when a file differs (`fdc332c`); each item of clothes keeps its colors at the mid and far levels (`db9bdff`); the factory builds a person at each level (`7189d0b`). Take out the workaround of the builder for the near level (`fetch.py` makes the receipt of a model with no near level from its first level).
- **Large buildings at the factory.** A model of the catalog of World (the statue, the Grand Hotel, Cảng vụ) is built natively with `mix world.build`, and the factory serves its files. An order at a request is built by the VM of World at the edge (World `docs/factory.md`, "Where the builds run"), and on 2026-11-17 the edge answered 503 for each building of 17 m or more (tool request `e1ee3aaa`). So both are true: World builds large models, but the factory does not build a new large order at a request yet. Until it does, the job "Models of World" builds such an order with `mix world.order`.

## 4. Changes to the plan

The builder writes these in the plan file on the branch (the plan on `main` is older than the branch):

- **D5 (new text).** Vũng Tàu makes its models with the tools of World, as a player of Dreams makes things (`docs/world-models.md`): an order of a blueprint with the numbers of this game, an order with edits, or a drawing of edits, in `data/world/drawings/`. World gives the tools, corrects its faults, and adds a tool when this game shows the need. World does not make a model of this game.
- **R17 (new).** A workflow copies the open photos (CC0, CC BY, CC BY-SA, public domain) of the drawings and of section 3 into `docs/reference/photos/`, with a file of credits (the author, the license, the link, the date), so that the builder and the architect can look at them in the workspace. The workspace cannot reach `upload.wikimedia.org` (checked on 2026-11-16), but CI can. A photo that is not open stays a link.
- **R15 (change).** Each shot has the eye, the direction, and the field of view of its photo (D-0026-02).
- **Q5.** The whole park and the walk of the sea to z −365 are in the area: yes.
- **Q6.** Do not wait for plan 0009: count the storeys from the photos (R17), with the status "Source". A stand-in of 1 storey is not correct in a shot.
- **Q9.** Wait for World to correct its catalog (section 3).
- **Q7.** I have no memory of the color in 2019. Use the look of the photo of 2014 (sky blue with white bands), the photo nearest to 2019, with the status "Source".
- **Q8.** Hải Âu stood in 2019, and its name is used: the letters HAI AU go on the model. The same for the name in the game.
- **Q10.** I do not remember eyes on the bows of the boats of Bãi Trước, but they are not wrong: keep the boat of World with its eyes.
- **Q11 and Q12.** I have no photos. The builder searches for them (section 6).

## 5. Photos

I have no photos of these places. The builder finds as many photos as it can, in each place that it can reach, and uses each one to make the models more correct:

- image searches (in Vietnamese and in English: "bãi trước vũng tàu", "công viên bãi trước", "đường hạ long vũng tàu", "kè bãi trước", "bậc xuống bãi tắm", "cầu đá vũng tàu", "khách sạn hải âu vũng tàu", with the years 2017 to 2020),
- Wikimedia Commons, Flickr, Mapillary, news articles, travel blogs, hotel and review pages, and videos of walks in Vũng Tàu.

For each photo it writes the link, the date, the license, and what it shows, in the drawing that uses it. An open photo goes into `docs/reference/photos/` (R17). A photo that is not open stays a link: the builder can look at it in a run of CI (an artifact that is not kept), but it does not go into the repository. A video of 1992 shows the route from the park to Hạ Long (`docs/content/reference/video-1992.md`). It is not a source for a 2019 value, but it shows what to look for. For Q11 and Q12 (the steps down to the sand and a walk on the sand along Hạ Long), the builder looks for at least three photos from 2017 to 2021 before it decides; with fewer, the value stays "Check".

## 6. Status

The plan stays "In progress". Q9: World corrected its catalog at `1984a6f` (its CI builds the files of the catalog from its code). Plan 0023 goes to `main` with this plan, when CI is green.

## 7. Audit 2: branch at `2375a18` (2026-11-17)

The pictures of this audit are in [`0026/audit-2026-11-17/`](0026/audit-2026-11-17/).

### 7.1 Runs

| Run | Result |
|---|---|
| PT-74 `showcase_walk`, all runs (workspace) | **Fail in run 5.** At 702 m the player stops at (73.7, 3.3, 195.1) against a wall (D-0026-11). The scenario stops at the first failed run, so I ran runs 6, 7, and 8 alone: pass. |
| PT-72 `showcase_shots`, phases 1 and 2 (Low, 17:10 and 12:00) | Pass. I put the shots of 12:00 next to their photos: `shots_noon.jpg`. |
| PT-71 `showcase_places` | Pass (116 s here). |
| PT-75 `showcase_people`, phase 1 (17:00) | Pass, with 0 swimmers (D-0026-20). |
| CI of `2375a18` | **Fail.** Five play tests take more than 300 s in their first run: `geo_hill`, `landmark_views`, `geo_chunks`, `landmark_sheet`, and `showcase_places` (D-0026-12). |

### 7.2 What is correct

- The models of this game are made in the correct way (D5, `docs/world-models.md`). The lamps, the walls, the plants, and the steps are sculptures from edits in this repository. Each size has its photo and how it was measured. The ten tool requests ask World for tools, not for models.
- The open photos are in `docs/reference/photos/` with their credits (R17). Five photos of 2017 to 2020 show the steps down to the sand (Q11).
- The people on the walk of the sea, the bars of Quang Trung, Cảng vụ, and the fishing boats look correct. The sea is green grey (D-0026-06).
- The walk on the sea wall of Hạ Long and the way onto the jetty pass (runs 6 to 8).

### 7.3 Defects

#### D-0026-11: A ledge between the park and the sidewalk of Quang Trung (high)

At the south end of the park, the sidewalk of the park side of Quang Trung is a ledge of about 0.3 m to 0.5 m over the path (`ledge_run5.jpg`). The player steps up 0.25 m, so a player who walks from the park to the street stops there. It passes on your computer and fails here: it is the same kind of defect as D-0026-01. Add a scan of each edge between a part that a player walks on and the ground of the area (rays every 0.5 m along the edge): a step higher than 0.25 m with no way round it fails. Then correct the edges: in the photos, the curbs of Quang Trung are low, and the paths of the park meet the sidewalk at its level.

#### D-0026-12: The play tests of the world are slower, and five fail in CI (high)

On `main` (CI of `eada09b`), `landmark_sheet` takes 91 s and `landmark_views` 142 s. On `2375a18`, the first run of each takes more than 300 s, and so do `geo_hill`, `geo_chunks`, and `showcase_places`. Most of these play tests are not about the showcase: the showcase makes each start of the Vũng Tàu world slower. Measure the time from the start to the first frame on `main` and on the branch. Then build the showcase only when the player comes near it (or in parts, over some frames), so that each play test of `main` takes its time of `main` again. Add the time of the start to a play test, with a limit.

#### D-0026-13: Hải Âu (high)

- **Its ground storey is under the ground.** From the walk (PT-74 run 8) and from near (PT-71), a bank of earth hides the ground storey: the shops and the porch of the photo are not there (`hai_au.jpg`). The level ground under the model must be the level of the sidewalk of Hạ Long in front of it.
- **No look of the true model.** The three looks in `khach_san_hai_au.json` are of a preview from a copy of the rule of World that you made in Python. Nobody looked at the model that World built (the job "Models of World", 28 minutes). A look is of the files of the lock, next to the photos. Do not keep a copy of the code of World, in this repository or in a workspace: two copies drift apart (Q9).
- **Sizes.** The height of a storey is "estimate (no source)", but photo 0 has a car and people at the front of the building. Measure it from them.

#### D-0026-14: Stand-ins in the shots (high)

- In S1, Khách sạn Bưu điện and Cao ốc Sen Biển are two grey boxes (`s1_hill_and_stand_ins.jpg`). They are the main subject of the photo of S1. The photo of S1 (2014) and the photo from a drone of 2021 show them: make them as orders of `building`, as Hải Âu.
- In S4, a box of grey stone stands at the right of the Grand Hotel.
- The old hydrofoil terminal is a box of 11 m over the land end of the jetty, and the way to the jetty is a corridor cut through it (`terminal_and_slope.jpg`). The outline of OpenStreetMap is the area of the port, not the building. Until a model from photos is there, no box stands over the jetty and its way.
- PT-72 passes when a stand-in in the frame has its storeys. Make it fail when a stand-in is a main subject of the photo of the shot.

#### D-0026-15: The far hill trees are dark shapes, and the hill is a patchwork (high)

In S1 at 12:00 and at 17:10 on Low, the far trees of Núi Nhỏ are dark shapes like small houses on the hill, and the ground of the hill has pink and teal patches (the far roofs of the town) where the photo shows trees and a few white villas (`s1_hill_and_stand_ins.jpg`). The check of D-0026-05 measures the spread of the brightness only. Also compare the colors (the hue and the value) of the box `hill` with the photo, at 12:00 and at 17:10.

#### D-0026-16: The top of the low wall of the beach is a saw-tooth (medium)

Where the low wall follows a curve or a slope, the top of each piece slopes on its own, and the top of the wall is a saw-tooth (`s1_wall_top.jpg`). The rail of the wall is one smooth line: the pieces meet at the same height.

#### D-0026-17: The park is a bare lawn (medium)

The photos of the park (`park.jpg`) show clipped hedges along the paths, round clipped bushes, flower beds, granite balls, benches, frangipani trees, and paths of tiles. In the game, the park is a flat lawn with trees, and the paths look like gravel. S2 shows a frangipani in the middle of the frame, where its photo shows the grove of leaning coconut palms. Put the hedges and the flower beds in the park (Q19), make the paths tiles, and put the leaning palms of S2 in the frame of S2.

#### D-0026-18: The roads look like gravel (medium)

In S3, S4, and at the south end of the park (`ledge_run5.jpg`), the asphalt is a light grey surface of coarse stones. In the photos, it is dark smooth asphalt with white lines. A brown block stands on the road at the south end of the median (`ledge_run5.jpg`, right).

#### D-0026-19: The blue lamp poles of the walk of the sea are not there (medium)

`lamp_rows` puts the blue poles only on the sidewalk of Quang Trung. The photo of 2014 (`park_blue_lamp_2014.jpg`) and the photos of 2019 show them along the walk of the sea, by the low wall. Put a row there.

#### D-0026-20: No swimmers and no boats on the sand (medium)

Section 8 says that at 17:00 the swimmers are in the water near the beach. PT-75 writes "0 swimmers" and passes. Make PT-75 fail with no swimmers. The photo of S1 also shows the boats pulled up on the sand, and people in the water (Q20).

#### D-0026-21: The slope of Hạ Long is still bare (low)

The side of the hill along Hạ Long is bare earth with palms (`terminal_and_slope.jpg`, PT-74 run 6). See Q13.

### 7.4 Answers to the questions of the plan

- **Q13.** Do not wait for an Earth Engine account. Count the storeys of the houses of the slope from the photos of 2017 to 2021 (the photo from a drone of 2021 shows many of them), as for the other stand-ins. A footprint that no photo shows stays off. The account is a question for plan 0009. Plan 0009 now needs no account (2026-11-18): the 2.5D data is in a public bucket, and its sources are open downloads or public services (plan 0009, section 3, "The sources").
- **Q14.** Correct the build now: at a junction, both roads come to one smooth height. Build the geodata again, and run the geodata tests and PT-33 to PT-39.
- **Q15.** Yes. Grow the outline of the area to the lot of the Palace Hotel (way 791795130) and to Nguyễn Trãi in front of it. Where the photos of 2014 and of 2022 show the same porch and the same faces, that was the look in 2019 too: Source (Q17, rule 1). Where they do not agree, the value stays Check. The video of 1992 (`docs/content/reference/video-1992.md`, 2:15) shows that the hotel is in the view from Quang Trung.
- **Q16.** Yes: use the name. The letters HA LONG HOTEL of the photo of 2021 go on the model (AGENTS.md section 4; the culture notes list the exception).
- **Q17.** Two rules, for this and for the next models. (1) A look that a photo before 2017 and a photo after 2021 both show was the look in 2019: Source. (2) A thing that a photo of 2017 to 2021 shows (also from far, for example the photo from a drone of 2021), with its sizes from a photo of 2014 or 2015: Source. A thing that no photo of 2017 or later shows stays Check. For the two sloped sea walls, the drop is the height of the walk less the height of the sand in the ground of the game, and the run comes from the photos: Source.
- **Q18.** Over the road. The photo from a drone of 2021 (`drone_2021_park.jpg`) shows the arms of the poles of both sidewalks of Quang Trung over the road. The status is Source.
- **Q19.** In this plan: the swimmers with the swim rings (section 8), the hedges, the round bushes, and the flower beds of the park (D-0026-17), the steps at the openings of the low wall, and the woman with the wide hat as a walker. For the Norfolk pine, keep one model only: the tree of plan 0020 or the drawing, the one that is nearer to the photos at the mid and the far levels.
- **Q20 (new).** Did the people of Bãi Trước swim in shorts and T-shirts, or in swim clothes? **Answer:** in shorts and T-shirts. They are local, and this is not a swimming pool (culture notes, Confirmed). So the swimmers wear the shorts and T-shirts of the person blueprint of World, with the swim rings (`phao_boi`), and do not wait for `swim_trunks`. The garment `swim_trunks` (`quan_dui_boi_nam`) is not needed for this plan.

### 7.5 New requirements (2026-11-17)

The builder writes these in the plan file on the branch.

A game of the streets of Hà Nội in Unreal Engine 5 (screenshots shared on Facebook, 2026-11-17) looks real mostly because of the things that people leave on the street and the wear of the surfaces, not only because of its engine. The showcase has almost none of these things.

- **R18. The dressing of the streets.** A kit of the small things of a street of Vũng Tàu, each made with the tools of World (D5, `docs/world-models.md`): plastic stools (blue and red), scooters parked on the sidewalk (they are in `parked_rows.json`; more of them, by the photos), shop signs with Vietnamese text (red and yellow boards, phone numbers, some signs over others; invented names only, AGENTS.md section 4), the poles of the electricity with their boxes and their wires, the AC units on the fronts, tarps over the tables of the sellers, and the carts of the sellers. Rules of where each thing goes (`data/showcase/dressing.json`): a number for each 10 m of sidewalk, in front of a shop or at a corner, from photos of Quang Trung, Hạ Long, and the streets near them, of 2017 to 2021. Each count and each place has its photo and how it was counted.
- **R19. The dressing of Tết.** Day 1 of the game is two weeks before Tết Kỷ Hợi. In those weeks, the streets have the red flags, the banners of "Chúc mừng năm mới", and pots of kumquat (quất) and of mai for sale on the sidewalk. Take what each street has, and where, from photos of the weeks before Tết in 2017 to 2021 (Tết was on 16 February 2018, 5 February 2019, 25 January 2020, and 12 February 2021). Write each fact in `docs/content/culture-notes.md` with its photo; I confirm them there. No flame tree has flowers in January (`data/trees/types.json` already).
- **R20. The surface of the roads** (with D-0026-18). Dark asphalt with patches, stains, manhole covers, and the painted lines and crossings of the photos; the granite curbs with their wear. Decals or a mask of the ground, from photos of 2017 to 2021.
- **R21. A look on a real graphics card.** The screenshots of this report are on Low, with a software renderer and no graphics card: the worst case. Make the macOS build of the branch (the export workflow) run PT-72 on High with one command, and write the command in the report. I run it on my computer and put the sheets in the branch.
- **PT-72 (change).** In S3, S4, and the street views of PT-74, count the things of R18 and R19 in the frame, against the counts of the photos.

## 8. Audit 3: branch at `a9f6c6b` (2026-11-18)

The pictures of this audit are in [`0026/audit-2026-11-18/`](0026/audit-2026-11-18/). The workspace of this audit has 2 CPUs and 8 GB of memory.

### 8.1 Runs

| Run | Result |
|---|---|
| CI of `a9f6c6b` | Pass: 17 of 17 jobs. |
| PT-71 `showcase_places` | Pass (148 s). The scan of the edges: 11 of 6 136 points have a step of more than 0.25 m, and the longest run is 2 m. |
| PT-72 `showcase_shots`, phases 1 and 2 (Low, 17:10 and 12:00) | Pass. The checks of the hill and of the water pass. |
| PT-73 `showcase_budget`, phase 1 (Low) | Pass. S1 194 722, S2 289 293, S3 266 828, S4 158 239, S5 286 902 triangles (CI: S5 296 532). |
| PT-74 `showcase_walk`, runs 1 to 8 | Pass, also run 5 with `PLAYTEST_MAX_FPS=3`. |
| PT-75 `showcase_people`, phases 1 and 2 | Pass. At 17:00, 11 of 11 swimmers are in the sea, and 7 show in the frame of S1. |
| PT-76 `showcase_night`, phase 1 (Low) | Pass. |
| PT-76 `showcase_night`, phase 2 (High, Forward+) | **Stopped by the workspace**: Godot used 6.0 GB, more than the 8 GB of the workspace with the other processes. It passes in CI (16 GB). With lavapipe, the memory of the GPU is in the RAM, so this is not the memory of the computer of a player. R21 also records the memory on a real graphics card. |
| PT-37 `geo_chunks`, phase 1 | Pass. The world is built in 3.3 s, and the first frame comes 17.1 s after the start of the engine. |
| PT-58 `morning_exercise` | Pass. |

### 8.2 What is correct

- **D-0026-11.** The walk from the park to the jetty passes in its eight runs, also at 3 frames per second. The scan of the edges of PT-71 finds a ledge before a player does.
- **D-0026-12.** CI is green, and each play test of the world starts in its time again.
- **D-0026-13.** Hải Âu stands at the level of the sidewalk of Hạ Long, and its looks are of the files of the lock.
- **D-0026-14.** Khách sạn Bưu điện and Cao ốc Sen Biển are models from their photos in S1. No box stands over the jetty.
- **D-0026-16, D-0026-18, D-0026-19, D-0026-20.** The top of the low wall is one smooth line. The roads are dark asphalt with white lines. The blue poles stand along the walk of the sea. The swimmers wear T-shirts and shorts, some have swim rings, and the boats lie on the sand.
- **D-0026-17.** The park has its hedges, round bushes, flower beds, benches, and paths of tiles, and S2 shows the grove of leaning palms.
- **The fast ground** (`prepare_at()` and `is_settled()`, `39fa0b9` and `a43d35f`): a measure waits for the far tiles. **PT-58** measures the motion in game time for 2 s. **The impostors** of the bushes and of the flowers have their colors, and the check finds a white impostor.

### 8.3 Defects

#### D-0026-22: The Grand Hotel stands on a bank of earth (high)

In S4, a bank of bare earth goes up from the sidewalk of Quang Trung to the front of the hotel (`s4_grand_hotel_bank.jpg`). The ground of the game is 6.65 m at x 115 (the outer edge of the sidewalk) and 8.83 m at the front of the model (x 125 to x 155): the hotel is 2.2 m over the sidewalk. The scan of the edges finds the foot of the bank (steps of 0.31 m to 0.34 m at x 116, z 8 to z 9), but the run is shorter than 5 m, so it passes. In the photo of S4, the fence with the lantern posts stands on the sidewalk, and the garden with the frangipani and the big trees is at the same level. This is the fault of D-0026-13 again.

- Make the ground level from the sidewalk to the front of the hotel, as for Hải Âu (`forecourt_m`, `level_at`).
- Put the fence with its lantern posts and the trees of the garden of the photo (Source from photos of 2017 to 2021, or Check).
- Add a check to PT-71: for each model of World in the area, the ground from the curb of its street to its front does not go up or down more than 0.5 m.

#### D-0026-23: The far hill is still a pattern of mounds (high)

In S1, S5, and each walk view of PT-74, the forest of Núi Nhỏ on Low is dark green caps with flat bottoms, at even distances on a smooth green slope (`s1_hill_mounds.jpg`). In the photo, it is one rough canopy of crowns of many sizes, with dark gaps between them. This is the open item of the report of the builder, and the look of D-0026-15. PT-72 passes, because the box `hill` measures the mean color and the spread of blocks of 16 px: the caps and the slope between them have about the same mean.

- Change the far form so that the crowns touch and the gaps are shade, not a lit slope.
- Add a check of the shape: for example, the part of the pixels of the box on a sharp edge (a gradient filter), and the largest smooth area between two crowns, against the same values of the photo.
- Put the box `hill` of the shot next to the photo at twice the size in the sheets.

#### D-0026-24: A row of casuarinas along Hạ Long hides the hall (medium)

In S1, an even row of trees of one kind, one size, and 7 m apart stands along Hạ Long from the beach to Cao ốc Sen Biển (`s1_trees_hide_hall.jpg`). It hides the hall with the roof of orange tiles (way 225803473: PT-72 sees its 18 points, but the trees cover it) and the fronts by the road. The trees come from the rule `coast_roads` of `data/geo/trees.json` (85 % casuarina, every 7 m: a builder value of plan 0020, Check). The photo of S1 and the photo from a drone of 2021 show a few coconut palms there. In the area of the showcase, the trees of Hạ Long come from the photos, as the grove of S2. Make the hall a subject of S1 in `data/showcase/shots.json`, so that PT-72 fails when a tree or a model hides it.

#### D-0026-25: The low wall at the eye of S1 (medium)

In the photo of S1, the wall in front of the eye is solid granite blocks with a thick flat cap, and the white wall with posts starts farther north (`s1_wall.jpg`). In the game, all the wall has posts and openings. Use the kind of wall of the photos at each part of the line, or Check where no photo shows it. Also, near the eye of S1 the walk goes down to the wall with a grade of about 0.3 in its last 2 m (the ground: 4.63 m at 3 m from the line, 4.02 m at 1 m). In the photos, the walk is level to the wall.

#### D-0026-26: The steps in the openings of the low wall (medium)

In PT-74 run 1 (150 m) and in S1, a flight of steps stands on the side of the walk and goes up from the walk to the top of the wall (`steps_on_the_walk_side.jpg`). The steps must go down from the walk to the sand, on the side of the beach. Find the cause: in the ground of the game, the side of the sea is lower along all the line except its flat north end (0.2 m to 0.8 m lower at 1 m from the line, 0.8 m to 2.0 m lower at 3 m). Add a play test that walks through each opening, down the steps to the sand, and back up, with a screenshot of each opening from the walk and from the sand.

#### D-0026-27: Four models with the status Source are not in the game (medium)

- `nha_mai_ngoi_cam` (the hall with the roof of orange tiles), `ke_ha_long` (the sea wall of Hạ Long), and `ke_da_bai_truoc` (the sea wall under the low wall of the beach) have the status Source and no order in `data/world/orders.json`, and their `status_note` does not say why. So the sea wall of Hạ Long is a plain slope of earth in PT-74 runs 3 to 6, and the hall is a stand-in. The near level of the hall needs the job "Models of World": put its order in `orders.json`, and the job of this repository builds it (no construction shift of World is necessary).
- `nha_khach_ha_long`: its two looks are of "a preview in my workspace, not of the model of World". This is the fault of D-0026-13. A look is of the files of the lock.
- The test `test_the_orders_of_the_drawings_are_in_the_orders_of_the_game` passes them: `order_problems()` checks only the drawings that are in `orders.json`, but its docstring says that it finds the drawings with the status Source whose order is not there. Make the test fail for a Source drawing with no order, unless its `status_note` says why it is not in the game (as `cay_thong_noel`).

#### D-0026-28: The budget of S5 has no room (medium)

In CI, S5 has 296 532 triangles on Low: 1.2 % under the limit. The builder found that two walkers near the eye at the same time can take it over the limit. A player sees the walkers at any moment, so PT-73 must measure the worst case: each walker of the spots of S5 at its point nearest to the eye. S5 must pass with that.

#### D-0026-29: A gray slab on the raised lawn of S5 (low)

In S5, at 17:10, 12:00, and 20:00, a light gray area covers about a third of the top of the raised lawn (way 234797330) (`s5_slab_on_the_lawn.jpg`). The ground under the lawn is level (4.73 m to 4.85 m at its corners and in its middle), so it is not the ground through the top. In the photo of S5, the top is all grass.

#### D-0026-30: Small things (low)

See `low_items.jpg`.

- The south end of the park is bare sand with a blurred dark band at the edge of the lawn (PT-74 run 4, 550 m).
- The south end of the median at the junction of Quang Trung and Hạ Long is a point of brown earth on the road (PT-74 run 5, 700 m).
- A walker in a tight white top looks like a body with no clothes at 1 m (PT-74 run 2, 200 m). Give the light tops a texture or a second color, as the far hair of plan 0023.
- The wet sand near the water has dark and white patches (S1, and PT-75 `008-swimmers_1700.png`).

### 8.4 The plan

- **R18 to R21 and the change of PT-72** (section 7.5, on `main` since `cd1e2b8`) are not on the branch yet. Merge `main` into the branch, and write them in the plan file.
- **Q21 to Q23** wait for my answers. Mapillary has street photos of the area with their dates (plan 0009, R5e; the secret `MAPILLARY_TOKEN` is in the repository). A photo of 2017 to 2021 from there can answer Q21 (the back wings of the Grand Hotel), Q22 (the fronts along Hạ Long), and Q23 (the letters on Khách sạn Bưu điện).
  - **Decided (2026-11-19):** use Mapillary now, in this plan. Make the tool of plan 0009, R5e, on the branch of this plan. Use its photos of 2017 to 2021 for Q21 to Q23, for D-0026-21, D-0026-22, D-0026-24, and D-0026-25, and for the counts of R18 to R20. The workspace cannot reach Mapillary (`graph.mapillary.com`) or download the artifacts of CI (`*.blob.core.windows.net`, checked on 2026-11-19), so a workflow of CI gets the photos and commits what the builder must look at. A letter or a name of a business on a building (Q23) still waits for my approval (AGENTS.md, section 4).

### 8.5 Status

The plan stays "In progress". No defect of this audit needs a construction shift of World: the large models are built by the job "Models of World" of this repository (`mix world.order` in CI).

## 9. Audit 4: branch at `38253fe` (2026-11-19)

The pictures of this audit are in [`0026/audit-2026-11-19/`](0026/audit-2026-11-19/). The workspace has 2 CPUs and 8 GB of memory. The audit of plan 0009, phase 1a, is in [report 0009](0009-report.md).

### 9.1 Runs

| Run | Result |
|---|---|
| CI of `38253fe` | Pass: 24 jobs (12 parts of the play tests, the unit tests, "Models of World", and the macOS look build). |
| PT-71 `showcase_places` | Pass (234 s). 11 of 6 136 points of the edges have a step of more than 0.25 m; the longest run is 2 m. But see D-0026-34. |
| PT-72 `showcase_shots`, phases 1 and 2 (Low) | Pass. Phase 9 (the sheets) fails here because I did not run the six phases of High; this is not a defect. |
| PT-73 `showcase_budget`, phase 1 (Low) | Pass. S1 182 046, S2 276 176 (283 410 with the walkers near the eye), S3 214 294, S4 163 151, S5 275 758 triangles. |
| PT-74 `showcase_walk`, runs 1 to 8 | Pass. |
| PT-75 `showcase_people`, phases 1 and 2 | Pass. At 17:00, 11 of 11 swimmers are in the sea, and 7 show in S1 with no boat in front of them. |
| PT-76 `showcase_night`, phase 1 (Low) | Pass. |
| PT-77 `showcase_steps`, phases 1 to 4 | Pass: 10 openings, each with steps down to the sand. |
| PT-37 `geo_chunks`, PT-57 `parked_rows`, PT-58 `morning_exercise` | Pass. |
| PT-72, phase 3 (High, Forward+) | The system stopped the engine (out of memory) at 84 s, after the first frame. This is the limit of this workspace (8 GB), as in audit 3, not a number of a player. |

### 9.2 What is correct

- **D-0026-22.** The ground in front of the Grand Hotel is level: 6.65 m at the outer edge of the sidewalk, 6.82 m at the front (it was 8.83 m). S4 has the fence with its posts and the trees of the garden. PT-71 checks the ground from the curb to the front of each model of World.
- **D-0026-24.** The row of casuarinas is gone from the band of Hạ Long at the junction, and the hall with the orange roof shows in S1. It is a subject of S1 now.
- **D-0026-26.** The steps of each opening go down from the walk to the sand (`Showcase._lift_of()`), and PT-77 walks through each opening, down and up, with a screenshot from the walk and from the sand. The cause (a model that hangs under its port comes out lifted by its depth) is in AGENTS.md.
- **D-0026-27.** The hall and the two sea walls are models of World in the game. The sea wall of Hạ Long is no longer a slope of earth.
- **D-0026-29 and part of D-0026-30.** The gray slab on the raised lawn is gone, the light shirts have a mid tone, and the puddles of the wet sand are soft.
- **The street photos (R5e).** The tool, its workflow, the index of 25 462 images, the contact sheets with their credits, and the decisions are in the repository (section 9.4).
- **R21.** The macOS look build is in the export workflow, and `tools/look_on_mac.sh` is ready for my computer.

### 9.3 Defects

#### D-0026-23 (still open): the far hill

S1 on Low is better: the crowns are larger and overlap more. But the lower half of Núi Nhỏ is still separate dark caps on a lit slope (`s1_hill.jpg`), and on High the builder sees separate round crowns (the sheet `sheet_S1_hill.jpg`). The new check passes with limits that are far from the photo: S1 has 28 % of the box on an edge and a smooth area of 56 %; the photo has 92 % and 0 %. The limits (at least 20 % and at most 80 %) let a hill that looks very different pass. Make the limits a part of the values of the photo (for example at least half of its edges, and a smooth area of at most 20 %), and make the far forest pass them.

#### D-0026-31: The walk of Hạ Long has no lamps (medium)

The photo of Mapillary 1927330624091805 (2018-07-29, hoangvietanh, CC BY-SA 4.0) shows a green post with five white globes on the walk of Hạ Long, near (-111, 326), and a bench at the parapet (`ha_long_walk_lamps.jpg`). The images of 2024 (for example 605171615183890, lyduchuy) show the same posts. The note of the grove of D-0026-24 in `data/geo/trees.json` says so too. A photo of 2018 is a source for 2019 (`docs/world-models.md`, section 3). In the game, the walk of Hạ Long has no lamp (PT-74 runs 5 to 7). Make the post with five globes as a model of this game, with its sizes from the photos, and put the row along the parapet.

#### D-0026-32: The mid level of the blue pole is a cone (medium)

From about 20 m, each blue pole of the walk shows a large blue cone at half its height (S5, and PT-74 runs 1 to 3; `blue_pole_cones.jpg`). The near pole has a thin shaft with two arms. This is a fault of the same kind as the wedges of the far fence (the open point of D-0026-22). Correct the levels of `den_cot_xanh_hai_tay`, and add a check to PT-56 for each model: the outline of the mid and the far level seen from the side covers about the same area as the outline of the near level (for example within 30 %).

#### D-0026-33: Blue poles stand in two openings of the low wall (medium)

In openings 0 and 3, a blue pole stands at the top of the steps, in the middle of the way (`poles_in_openings.jpg`). The rows of lamps put a pole every 40 m, 0.8 m in from the wall, with no gap at the openings. Keep each pole at least 1.5 m from the side of an opening, and add to PT-77 a check that no part stands in the way of the opening (a body of the player from the walk to the sand).

#### D-0026-34: PT-71 passes with a view that shows nothing (medium)

The view of Cao ốc Sen Biển in PT-71 (`011-cao_oc_sen_bien.png`) is a flat olive plane over most of the frame, with a piece of the road at the bottom (`pt71_sen_bien_blocked.jpg`). In audit 3 the same view showed the tower. Find the object in front of the camera. One possibility: a far crown of the hill (25 m to 70 m wide on Low since `208b658`) near the camera, in a tile whose middle is far, so the visibility range of the tile shows it. Add a check to PT-71 and PT-72: a frame where one flat color covers more than half fails.

#### D-0026-35: Trees stand on the walk of Hạ Long (low)

Past Cao ốc Sen Biển, palms stand on the tiles of the walk, some in its middle (PT-74 run 6 at 950 m, run 7 at 1 050 m; `palms_on_the_walk.jpg`). These come from the rule `coast_roads`. A player walks into them. Keep the trees off the parts that a player walks on, and in the area of the showcase put a tree only where a photo shows one (as the grove of D-0026-24).

#### D-0026-36: The hall with the orange roof stands in a pit (low)

In PT-71 (`012-nha_mai_ngoi_cam.png`, `pt71_hall.jpg`), bare slopes rise on each side of the hall above its base. In the photo of S1, the hall stands at the level of the road, in front of the hill. The windows of its near level are blurred.

#### D-0026-37: Two sitters of S5 are the same person (low)

On the raised lawn of S5, two people sit side by side with the same face, hair, and clothes (`s5_two_sitters.jpg`; also PT-75). Do not put two of the same person next to each other.

#### D-0026-38: The worst case of PT-73 can be behind the eye (low)

S5 with "the walkers of its spots at their points nearest to the eye" has the same draw calls and triangles as S5 with no walkers moved (571 and 275 758). The nearest point of a way can be under or behind the eye. Put each walker in the frame, at the nearest point of its way that is 3 m to 10 m in front of the eye. (My words in D-0026-28 asked for the nearest point.)

#### D-0026-39: A number plate in a sheet of Mapillary (low)

The sheet `docs/reference/mapillary/sheet_q23_buu_dien_roof_after_1.jpg` shows a number plate that a person can read (image 1091249252584160). Mapillary did not blur it. Blur it, or leave out the image, as for the frames of the video of 1992 (`docs/content/reference/video-1992.md`).

#### Still open from the builder

- The far level of the fence of the Grand Hotel shows wedges at the posts (past 40 m on Low).
- D-0026-30: the south end of the park is bare sand with a blurred band, and the end of the median at the junction is a point of brown earth (PT-74 runs 4 and 5).
- D-0026-25: the kind of the low wall at the eye of S1 (Check, question 3 of the builder below).
- `nha_khach_ha_long`: its looks are still of a preview in the workspace (D-0026-27).

#### Observation: the video memory on Low

On Low, PT-72 logs 1 448 MB of video memory, of which 1 307 MB are textures (for example S1: "489 MB static, 1448 MB video"). The budget of the plan (R16) has the draw calls and the triangles, not the memory. A computer for Low can have a graphics chip in the processor with little memory. This is a question for me (Q24 below), not a defect.

### 9.4 The street photos of Mapillary

- **What Mapillary has.** The index has 25 462 images of the play area. Only 725 are of 2017 to 2021: two drives of 2018. One drive (598 images, 2018-04-24, the author ff5722) is along the coast to the north-west, at about x −2 060 to −320 and z −4 760 to −1 960. The other (126 images, 2018-07-29, hoangvietanh) passes the park and goes east into the town, at about x 280 to 1 100 and z 130 to 450. All the other images are of 2024 to 2026. So for 2019, most of Mapillary is "after" photos: a look that both a photo before 2017 and a photo of Mapillary after 2021 show is a source (report 0026, Q17, rule 1). A look that only a photo of 2024 shows is Check.
- **The decisions of the builder.** I looked at the sheets, and I agree with each one:
  - **Q21:** the back of the Grand Hotel stays Check: no image of 2017 to 2021 shows it.
  - **Q22:** the stand-in on the slope of Hạ Long is off.
  - **Q23:** the images of 2018 point at Khách sạn Bưu điện, but they show only the trees of the park, not the roof. The roof text of 2019 is still not known.
  - **D-0026-22:** the fence of the Grand Hotel: the photo of S4 (2014) and an image of 2024 both show it.
  - **D-0026-24:** no tree on the walk of Hạ Long in 2018. The image of 2018 also shows the lamps of D-0026-31.

### 9.5 The questions of the builder

1. **Q23, the letters on Khách sạn Bưu điện.** Answered (2026-11-19): use the photos nearest to 2019, before and after it, from Mapillary or the web, and read the letters on them. The letters can be the same on both sides. If a photo before 2017 and a photo after 2021 show the same letters, the letters are Source (rule 1). If they are not the same, use the letters of the photo nearest to 2019, with the status Check. I approve the name of the hotel on its roof as an exception of AGENTS.md, section 4: add it to `docs/content/culture-notes.md`.
2. **R18 and R19, the images of 2024 and 2025 for the counts.** Use them for the kinds of things, with rule 1 (a photo before 2017 of the same kind). The counts from them have the status Check, and the game uses them only after I look at the sheets.
3. **The low wall at the eye of S1.** Answered (2026-11-19): I do not know. Find more photos. Mapillary has no image on the walk of the sea (`photos_report.md`: 0 images at each point `d25_wall_*`), so also look for images from the road Quang Trung that look to the wall (a larger distance, with the compass of the image to the wall), and for photos on the web (Wikimedia Commons and Flickr with a free license; other photos are only for the eyes, plan 0009, D11). Rule 1 applies: the photo of S1 (2014) and a photo after 2021 that show the same granite wall at the same place make it Source. Until then, that part of the wall stays Check.
4. **The ATL03 file** and 5. **the values of plan 0009**: report 0009, D-0009-04 to D-0009-06.

### 9.6 New questions

- **Q24.** Is there a limit of the video memory on Low (for example 1 GB)? Then PT-72 and PT-73 check it, and the textures of the look (R12) get a smaller size on Low.
  - **Decided (2026-11-19):** yes. Low uses at most 1 024 MB of video memory (`RENDERING_INFO_VIDEO_MEM_USED`) at each shot, also in the worst case of PT-73. Add it to R16: PT-73 fails over the limit, and PT-72 logs the memory of each shot and the part of the textures. Low is the preset of the phones, the web build, and a computer with no graphics card (AGENTS.md, section 5b), and these share the memory with the processor. High has no limit of memory in this plan.

### 9.7 Status

The plan stays "In progress". No defect of this audit needs a construction shift of World.

## 10. Audit 5: branch at `f54b22d` (2026-11-20)

The pictures of this audit are in [`0026/audit-2026-11-20/`](0026/audit-2026-11-20/). I did not run the phases on High: the workspace has 8 GB of memory (section 9.1).

### 10.1 Runs

| Run | Result |
|---|---|
| CI of `f54b22d` | Pass: run 307, 17 of 17 jobs. |
| PT-71 `showcase_places` | Pass (258 s). But see D-0026-41. |
| PT-72 `showcase_shots`, phases 1 and 2 (Low) | Pass. The video memory is 665 MB to 679 MB at the five shots. But see D-0026-23 and D-0026-40. |
| PT-73 `showcase_budget`, phase 1 (Low) | Pass. S1 180 066 triangles (184 989 with the walkers held), S2 274 736 (281 970), S3 213 792, S4 162 307, S5 276 419; 705 MB to 708 MB of video memory (it was 1 448 MB). |
| PT-77 `showcase_steps`, phases 1 to 4 | Pass: no pole in an opening. |
| PT-74 `showcase_walk`, runs 1 to 8 | Pass. |
| PT-75 `showcase_people`, phases 1 and 2 | Pass. |
| PT-76 `showcase_night`, phase 1 (Low) | Pass. |
| PT-53 `bai_truoc_trees`, phase 3 (Low) | Pass: 856 coconut palms, and the palms of the park are back. |
| PT-56 `world_models`, phases 1 to 11 | Pass. |

### 10.2 What is correct

- **D-0026-31.** The green posts with five globes stand every 40 m along the parapet of Hạ Long (`ha_long_lamps_840m.jpg`), as in the image of 2018.
- **D-0026-32.** The blue poles are thin with their two arms at each distance (PT-74 runs 1 to 3, S5). The fence of the Grand Hotel and the black post of the park too. PT-56 and `tools/world/outlines.py` check the outline of each level.
- **D-0026-33.** No pole stands in an opening (`openings_0_and_3.jpg`).
- **D-0026-35.** No tree stands on the walk of Hạ Long, and the coconut palms of the park are back. The unit test that finds a rule with no photo is a good addition.
- **D-0026-36.** The yard of the hall is level 3 m past each side. The banks past the yard are in the ground of Copernicus, a model of the surface: report 0009, section 6.4.
- **D-0026-37.** The two sitters of S5 are two people (`s5_low.jpg`).
- **D-0026-38.** PT-73 holds the walkers of each spot in the frame.
- **D-0026-39.** The plate is blurred, a step of the sheets blurs the plates and the faces, and a list keeps the boxes that a detector misses.
- **Q24.** Low uses 705 MB to 708 MB. The cause was the files of the near levels, which Low does not show. This is a better correction than smaller textures.
- **Q23 and the low wall.** The builder used my answers and found a photo of 2019 (Kwozyn, 2019-02-21, CC BY-SA 4.0). It shows the parapet of Hạ Long, not the low wall of the beach.

### 10.3 Defects

#### D-0026-23 (still open): the far hill

The check passes (12:00: 54 % on an edge and a smooth area of 6 %; 17:10: 46 % and 15 %), but the look is the same as in audit 4. At 12:00 the lower half of Núi Nhỏ is large dark caps with light ground between them (`s1_hill_1200.jpg`). Commit `d4aa97a` adds a fine noise, with a cell of about two pixels, to the far clumps and the far ground. The check counts a change of brightness of more than 0.02 between pixels 2 apart, so this noise passes it with no change of the shapes.

A measure of the size of the patches finds the fault. I measured the distance at which the autocorrelation of the brightness of the box falls to one half, with the photo at the width of the shot: 4 px in the photo, 17 px in the game at 12:00, and 11 px at 17:10. So the patches of the game are 3 to 4 times the size of the crowns of the photo.

- Make the crowns of the far forest the size of the crowns of the photo (about 5 m to 12 m), and cover the slope where the photo has trees (no light ground between them).
- Replace the check of the edges by a check of the size: the autocorrelation length of the box in the game at most 1.5 times that of the photo, at 12:00 and 17:10, on Low and High. Keep the check of the color.
- A noise that passes a check with no change that a person sees is not a correction. A check must find the defect that a person sees (AGENTS.md, section 3).

#### D-0026-40: The roof of the hall is pale (medium)

In S1, at 12:00 and at 17:10, the roof of `nha_mai_ngoi_cam` is a pale peach, and its walls are a blur (`hall_roof.jpg`). The photo of S1 shows a roof of orange red tiles. Near (PT-71), the roof is a salmon pink: also lighter than the photo. The hall is a subject of S1. Correct the color of the roof at each level against the photo. Add to PT-72 a check of the color of a box on the roof of the hall (the hue and the saturation against the photo, as for the box `hill`).

#### D-0026-41: The view of Cao ốc Sen Biển in PT-71 shows the hall (low)

After D-0026-34, the eye of this view stands next to the hall: the roof and the wall of the hall fill the lower half of the frame, and the tower shows only above them (`pt71_sen_bien_view.jpg`). A view of a place must show the place. PT-71 fails a view where the place covers less than 20 % of the frame, or where another model covers more of the frame than the place. Put the eye where a photo of the place stands, or across the road.

#### Still open

- **D-0026-30.** Answer to the builder: draw the outline of the lawns of the south end from the photo from a drone (`drone_2021_park.jpg`, 2021, CC BY-SA 4.0: a photo of 2017 to 2021 is a source for 2019), with the edges of the ways of OpenStreetMap as the reference. Put the outline next to the photo in a sheet.
- **`nha_khach_ha_long`:** Q25 below.
- **D-0026-25:** Q26 below.

#### Notes

- In S1, the lower slope of Núi Nhỏ behind the hotels is bare. The photo shows villas and houses there. Plan 0009, phase 2, builds them; this is not a defect of this plan.

### 10.4 Questions for me

- **Q25.** A new lock of World. World has 76 commits after `1984a6f`, with the tools that this plan asked for (a curved porch with its fascia, a width for a line of letters, blocks with their own storeys) and new files of the Grand Hotel and the people. The proposal: yes, one new lock after the defects of this audit, in a commit of its own, with PT-56, `tools/world/outlines.py`, PT-71 to PT-77, and the looks of each drawing run again.
  - **Decided (2026-11-20):** yes, now, because World has the tools that this plan needs. Lock the newest commit of World `main` whose CI is green (World still works on its construction shifts; they do not change the files of the models). Make the new lock first, in a commit of its own, and run the checks again before the corrections of this audit.
  - **Added (2026-11-20):** take the files of the new lock from a clone of World or from a build in CI (`--source=checkout`, the job "Models of World"), not from the factory, until World says that the check of its bucket is done (plan 0027, R6a). A lock that already has files from the factory is checked again then.
- **Q26.** The low wall at the eye of S1. Only the photo of S1 (2014) shows it: rough granite blocks with a flat cap. No photo after 2017 shows it. The proposal: use the look of 2014 there. Else the wall keeps its posts, and no photo shows posts at that place.
  - **Decided (2026-11-20):** find photos of the year before or after 2019 (2018 or 2020) that show the wall at the eye of S1, from any source (news, travel pages, videos of a walk on the beach, the photos of a map service), only for the eyes, and use the kind of wall that they show. Write the link, the date, and what each shows in the drawing.
- **Q27.** The letters on Khách sạn Bưu điện: VUNG TAU P&T HOTEL (2011 and April 2014), or a wave and P&T HOTEL (March 2024). The photo of April 2014 is the nearest to January 2019. The proposal: VUNG TAU P&T HOTEL.
  - **Decided (2026-11-20):** use VUNG TAU P&T HOTEL, if the letters fit the place of the sign on the roof as in the photo of 2014.
- **Q28.** R19, the dressing of Tết: no open photo shows the weeks before Tết of 2018 to 2021. The proposal: the builder looks at news photos and videos of those weeks only with the eyes (in `docs/content/culture-notes.md`, a link and a note of what each shows, and no copy, as plan 0009, D11), and I confirm each fact.
  - **Decided (2026-11-20):** look at the photos and the videos of the weeks before Tết of 2018 to 2021 from any source. Vietnam has been in the Berne Convention since 2004, so a photo is protected also with no license or notice: do not copy such a photo into the repository. A fact that a photo shows (what is on a street, where, and how many) is not protected: write it in `docs/content/culture-notes.md` with the link and the date, and I confirm it there.

### 10.5 Status

The plan stays "In progress": D-0026-23, D-0026-30, D-0026-40, and D-0026-41, and the answers to Q25 to Q28. No defect of this audit needs a construction shift of World.

## 11. Audit 6: branch at `0076639` (2026-11-21)

The pictures of this audit are in [`0026/audit-2026-11-21/`](0026/audit-2026-11-21/).

### 11.1 Runs

| Run | Result |
|---|---|
| CI of `0076639` | Pass: Test, Export, and Reference photos. |
| PT-71 `showcase_places`, runs 1 and 2 | Pass (195 s and 104 s). |
| PT-72 `showcase_shots`, phases 1 and 2 (Low) | Pass. The hill of S1: 4.0 px (the photo 4.0 px) at 12:00 and 17:10. The roof of the hall: hue 14 at 12:00 and 8 at 17:10 (the photo 9). |
| PT-73 `showcase_budget`, phase 1 (Low) | Pass. S1 162 071 triangles, S2 248 967, S3 196 808, S4 147 835, S5 250 281 with 597 draw calls; 706 MB to 709 MB of video memory. |
| PT-33 `geo_views`, phases 2 and 5 | Pass. |
| PT-74 `showcase_walk`, runs 1, 4, 5, and 6 | Pass. |
| PT-77 `showcase_steps`, phase 1, and PT-75 `showcase_people`, phase 1 | Pass. |

### 11.2 What is correct

- **D-0026-40.** The roof of the hall is orange red at each level, and PT-72 checks its color.
- **D-0026-41.** The view of Cao ốc Sen Biển shows the tower (22 % of the frame), and PT-71 checks the part of each place in its view (`pt71_views.jpg`).
- **Q25.** The new lock is World `e8754d6`. The job "Models of World" built its files from a clone of World in CI, so no file comes from the bucket of the factory (plan 0027, R6a).
- **Q26.** Two photos of 2019 show the wall at the eye of S1: courses of granite on a base, square posts with low openings between them, and a flat cap. That is the kind of wall that the game has there.
- **Q28.** The facts of the weeks before Tết are in `docs/content/culture-notes.md` with their links and the status Check, and no copy of a photo is in the repository. The game does not use them.

### 11.3 Defects

#### D-0026-23 (still open, now medium): the far hill

The crowns are now the size of the crowns of the photo. But they are all of one size, in even rows, like scales (`s1_hill.jpg`). The photo has crowns of many sizes, in yellow green, dark green, and dry brown. PT-72 logs the color patches of the box: 0.013 to 0.014 in the game, 0.050 in the photo. It does not fail on them. At 17:10 the saturation is 0.13, and the photo has 0.26. On the lower slope at the right, large smooth light areas have no crowns.

- Make the crowns of different sizes (5 m to 12 m), light, and colors, with the dry patches of the photo.
- PT-72 fails when the color patches of the box are less than half of those of the photo, or when the saturation differs from the photo by more than 0.05, at 12:00 and 17:10.

#### D-0026-42: S5 is at the limit of the draw calls (medium)

S5 has 597 of 600 draw calls on Low. The letters of Hải Âu, of the Palace Hotel, and of Khách sạn Bưu điện, and the dressing of Tết, add draw calls in the shots. Get a margin at S5 (at most 560 draw calls) before you add them. PT-73 logs the margin of each shot.

#### D-0026-43: Commits with another author (high, before the merge to `main`)

Ten merge commits on this branch (for example `5368f60`) and one on the branch of plan 0009 (`8990b37`) have another author and committer, not my name and address. Each commit has my name and address (CONTRIBUTING.md). Make the history of each branch again with my name and address on these commits before it goes to `main`, and make each merge with that identity.

#### D-0026-44: The import files of Nhà khách Hạ Long (low)

The three import files of `nha_khach_ha_long` are in a short form. Godot writes them in the full form at each import, so each play test leaves three changed files in the working copy. Commit the files that Godot writes.

#### D-0026-45: "the owner" (low)

Three new lines (`docs/content/culture-notes.md`, `data/showcase/dressing.json`, and the builder notes of the plan) say "the owner". Write them in the first person, as AGENTS.md does.

#### Still open

- **D-0026-30.** At 17:00 the paving of the south end looks like sand, the parapet of the square is not there, and brown earth shows between the road meshes at the junction (`south_end_walk.jpg`: PT-74 run 4 at 550 m, run 5 at 700 m).
- **Q27.** The letters of Khách sạn Bưu điện wait for World.
- **The new tools of World** are in the lock, but no drawing uses them yet: the letters of Hải Âu and of the Palace Hotel, and the porch and the blocks of Hải Âu and of `khach_san_grand_canh_sau`.

#### Notes

- In PT-71, bare banks stand next to the hall and under Cao ốc Sen Biển (`pt71_views.jpg`). This is the ground of Copernicus, a model of the surface: report 0009, section 6.4 (the bare earth of phase 1b).

### 11.4 Questions for me

- **Q29.** Acceptance criterion 2: I look at each shot of PT-72 next to its photo (`docs/showcase/sheet_S1.jpg` to `sheet_S5.jpg`) and say whether it is Bãi Trước.
- **Q30.** R19, the dressing of Tết: I confirm the rows of `docs/content/culture-notes.md`, and I say what I know of the counts that no source gives (the red flags, the lanterns on the poles, the banners, and the sellers of mai and quất). The festival of 2019 opens on 1 February (day 11 of the game): what does the park show on days 1 to 10?

### 11.5 Status

The plan stays "In progress": D-0026-23, D-0026-30, and D-0026-42 to D-0026-45, the letters, the new tools of World, and Q29 and Q30.

## 12. Audit 7: branch at `4dcee5e`, status "Built" (2026-11-21)

The pictures of this audit are in [`0026/audit-2026-11-21b/`](0026/audit-2026-11-21b/).

### 12.1 Runs

| Run | Result |
|---|---|
| CI of `4dcee5e` | Pass: Test (18 jobs, also "Identity of the commits" and the play tests on High), Export, and Reference photos. |
| The history of the branch | Each commit after `main` has my name and address. The tree of the new commit of `0076639` (`9297915`) is the same as the tree of `0076639`. |
| PT-72, phases 1 and 2 (Low) | Pass. The hill of S1: 3.0 px and 3.5 px (the photo 4.0 px), saturation 0.23 and 0.26 (0.26), color patches 0.029 and 0.042 (0.050). |
| PT-73, phase 1 (Low) | Pass. S5: 380 draw calls, a margin of 220. |
| PT-71 run 2, PT-74 runs 2, 4, and 5, PT-75 phase 1, PT-76 phase 1, PT-56 phase 1 | Pass. |

### 12.2 What is correct

- **D-0026-23.** The crowns of the far forest have many sizes and colors, with no rows. The hill of S1 now reads as a forest (`docs/showcase/sheet_S1.jpg`).
- **D-0026-30.** The paving of the south end, the parapet of the square, and the junction with no brown earth (`south_end_and_people.jpg`).
- **D-0026-42.** S5 has 380 draw calls. The far level of a person as one surface looks the same as before in PT-75.
- **D-0026-43 to D-0026-45**, and the check of the identity of each commit in CI.

### 12.3 Defects

#### D-0026-46: S5 is not compared at the time of its photo (medium)

The photo of S5 is at dusk: a purple sky, and lamps with a warm orange light on wet-looking tiles. The sheet of S5 shows the shot at 17:10 and at 12:00, and PT-76 shows it at 20:00: a dark blue night with white lamps (`s5_night.jpg`). So no sheet compares S5 with its photo.

- Add S5 at the time of its photo (dusk in January, about 18:05) to PT-72 and to its sheet, and compare the box of the sky and the light of the lamps with the photo (hue and saturation).
- The color of the light of the lamps is a look. If a photo of 2017 to 2021 at night shows the lamps of the walk, use its color. If none does, the photo of 2015 and a photo after 2021 that agree give the color (rule 1). Else the color is Check.

#### D-0026-47: The near part of S1 does not agree with its photo (medium)

In the photo of S1, the low wall is a short cap at the lower left, and the beach, with its people and boats, fills the lower half. In the game, the wall fills the left third of the frame and turns away to the right, and the beach has a row of boats and a few swimmers (`docs/showcase/sheet_S1.jpg`). The hill and the buildings agree, so the eye looks in the correct direction, but the eye or the line of the wall is not at the correct place.

- Draw the line of the low wall and of the boats from the data through the camera of S1 on the photo, as `tools/showcase/lawn_sheet.py` does for the lawns. If the line of the wall does not agree with the photo, find which is wrong: the eye of the shot, or the wall. Correct it, and add the check to PT-72.

#### D-0026-48: A jagged dark band on the sand at the south end (low)

PT-74 run 4, at 550 m: a dark green band with steps runs across the sand (`south_end_and_people.jpg`). Find what it is (the edge of a lawn of the mask, or a shadow), and correct it. Add a check for a band of the color of the lawn on the sand.

#### Notes

- In S3 the street is empty: the photo has many motorbikes. Moving traffic is not in this plan.
- In S4 the Grand Hotel is a lemon yellow, and the photo shows a peach color. Its drawing has its sources, and I decide with the review of the sheets (Q29).

### 12.4 Status

The plan stays "Built" until D-0026-46 to D-0026-48 are corrected and I answer Q29 and Q30.
