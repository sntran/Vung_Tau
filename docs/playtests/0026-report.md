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

### 8.5 Status

The plan stays "In progress". No defect of this audit needs a construction shift of World: the large models are built by the job "Models of World" of this repository (`mix world.order` in CI).
