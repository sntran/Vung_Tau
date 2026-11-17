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

## 3. World

- **The catalog of World is behind its code (Q9).** At World `8fbf36c`, the code of `honda_vision_110` has the joint `side_stand` (World `a87e283`), but `priv/models/honda_vision_110.*` is from 2026-11-08, with no joints. So the factory and a clone give different bytes, and the R4 test of plan 0023 fails correctly. World must build its catalog files again from its code at each commit, and its CI must fail when they differ.
- **People at the mid and far levels** take one mean color for all faces under an item of clothes, and the near level of a person cannot be built by the factory. The builder worked around both. They are faults of World.

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

For each photo it writes the link, the date, the license, and what it shows, in the drawing that uses it. An open photo goes into `docs/reference/photos/` (R17). A photo that is not open stays a link: the builder can look at it in a run of CI (an artifact that is not kept), but it does not go into the repository. For Q11 and Q12 (the steps down to the sand and a walk on the sand along Hạ Long), the builder looks for at least three photos from 2017 to 2021 before it decides; with fewer, the value stays "Check".

## 6. Status

The plan stays "In progress". Q9: do not put plan 0023 on `main` with a red test; World corrects its catalog first.
