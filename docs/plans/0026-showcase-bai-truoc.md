# 0026 Showcase: Bãi Trước

| Field | Value |
|---|---|
| Status | Draft |
| Branch | `feat/0026-showcase-bai-truoc` |
| Depends on | 0023 (models from World), 0020 (trees), 0008 (the known structures: the jetty of Cầu Đá, the views). Their branches go to `main` first (R1). |
| Uses from later plans | 0006 (people), 0009 (houses), 0015 (the beach in the evening), 0018 (traffic): only the parts that this area needs. Those plans keep the rest of their work. |
| World | The models of World plan 0018 ("The street Quang Trung of Vũng Tàu as it is") and the requests of section 7. |

## 1. Goal

One small area of the town is finished before the rest: **Bãi Trước around Quang Trung**. A person who knows Vũng Tàu sees a screenshot of it and says "Bãi Trước" at once, as a person from Sài Gòn knows Nhà thờ Đức Bà.

The area:

- The park Bãi Trước, with its coconut palms, its paths, and its walk along the sea.
- The beach and the sea wall, and the fishing boats and the basket boats in the bay.
- Quang Trung from Cảng vụ (number 2) to Nhà thiếu nhi: the two roads with the median, the row of bars of the numbers 4 to 26, and the Grand Hotel.
- Hạ Long from Quang Trung to Hải Âu and the jetty of Cầu Đá, with Núi Nhỏ behind.

At the end, the area is full: buildings, ground, plants, lamps, boats, people, and scooters, in the light of the real date and time. The rest of the town stays as it is.

A note on the view: the lighthouse stands on the top of Núi Nhỏ, but nobody sees it from the park or the beach of Bãi Trước. I confirmed this, and PT-60 of plan 0008 finds the same from the DEM. So the view of the area is the slope of Núi Nhỏ behind Hạ Long and the bay, not the lighthouse.

## 2. Out of scope

- The inside of the buildings, except the open fronts of the bars (World plan 0018, D3).
- Talks and activities with the people of the area (plans 0011 to 0015). People in this plan walk, sit, sell, and swim. Nobody talks to the player yet.
- The traffic of plan 0018 (lanes, traffic lights, junctions). This plan has some scooters on fixed loops only (R11).
- Sound (a later plan).
- The other parts of the town.

## 3. The target

The target is the real place in 2019, not a drawing. These public photos (Wikimedia Commons, open licenses, from the survey of World plan 0018) show it. Links only: do not copy the photos into the repository.

| Shot | The photo to match |
|---|---|
| S1: the park edge, to the south: the bay, the boats, Hạ Long, the slope of Núi Nhỏ | [The beach and the sea wall to the south, hotels of Hạ Long behind](https://commons.wikimedia.org/wiki/File%3AV%C5%A9ng_T%C3%A0u%2C_Ba_Ria_-_Vung_Tau%2C_Vietnam_-_panoramio_%282%29.jpg) |
| S2: the park, its palms and paths | [Leaning palms](https://commons.wikimedia.org/wiki/File%3AC%C3%B4ng_Vi%C3%AAn_B%C3%A3i_Tr%C6%B0%E1%BB%9Bc%2C_Quang_Trung%2C_Ph%C6%B0%E1%BB%9Dng_1%2C_tp._V%C5%A9ng_T%C3%A0u%2C_B%C3%A0_R%E1%BB%8Ba_-_V%C5%A9ng_T%C3%A0u%2C_Vi%E1%BB%87t_Nam_-_panoramio_%281%29.jpg), [paths and low lamps](https://commons.wikimedia.org/wiki/File%3ACong_vien_bai_truoc-Ph%C6%B0%E1%BB%9Dng_1%2C_tp._V%C5%A9ng_T%C3%A0u%2C_B%C3%A0_R%E1%BB%8Ba_-_V%C5%A9ng_T%C3%A0u%2C_Vi%E1%BB%87t_Nam_-_panoramio_%282%29.jpg), [the pavilion with the orange roof](https://commons.wikimedia.org/wiki/File%3ACong_vien_bai_truoc-Ph%C6%B0%E1%BB%9Dng_1%2C_tp._V%C5%A9ng_T%C3%A0u%2C_B%C3%A0_R%E1%BB%8Ba_-_V%C5%A9ng_T%C3%A0u%2C_Vi%E1%BB%87t_Nam_-_panoramio_%283%29.jpg) |
| S3: Quang Trung to the south, Cảng vụ at the end | [Cảng vụ from the junction of Hạ Long](https://commons.wikimedia.org/wiki/File%3ABai_truoc-duong_Ha_long-Ph%C6%B0%E1%BB%9Dng_2%2C_tp._V%C5%A9ng_T%C3%A0u%2C_B%C3%A0_R%E1%BB%8Ba_-_V%C5%A9ng_T%C3%A0u%2C_Vi%E1%BB%87t_Nam_-_panoramio.jpg), [the road of the sea side by the park](https://commons.wikimedia.org/wiki/File:Quang_trung_street-Ph%C6%B0%E1%BB%9Dng_1,_tp._V%C5%A9ng_T%C3%A0u,_B%C3%A0_R%E1%BB%8Ba_-_V%C5%A9ng_T%C3%A0u,_Vi%E1%BB%87t_Nam_-_panoramio.jpg) |
| S4: the Grand Hotel and the median | [The Grand Hotel from Quang Trung](https://commons.wikimedia.org/wiki/File:Grand_hotel,_quang_trung_street-Ph%C6%B0%E1%BB%9Dng_1,_tp._V%C5%A9ng_T%C3%A0u,_B%C3%A0_R%E1%BB%8Ba_-_V%C5%A9ng_T%C3%A0u,_Vi%E1%BB%87t_Nam_-_panoramio.jpg), [Nguyễn Trãi from the median](https://commons.wikimedia.org/wiki/File%3AV%C5%A9ng_T%C3%A0u%2C_Ba_Ria_-_Vung_Tau%2C_Vietnam_-_panoramio_%2811%29.jpg) |
| S5: the walk of the sea at dusk | [Strips of lawn in granite borders, lamp poles](https://commons.wikimedia.org/wiki/File%3AVoyage_au_Vi%C3%AAt_Nam_-_panoramio_%2812%29.jpg), [the sea wall of stone blocks](https://commons.wikimedia.org/wiki/File%3AV%C5%A9ng_T%C3%A0u%2C_Ba_Ria_-_Vung_Tau%2C_Vietnam_-_panoramio_%286%29.jpg) |

Most photos are from 2014 and 2015. A difference from 2019 that I know is a "Check" fact in the culture notes, and I decide it.

`docs/plans/0026/baseline-2026-11-15/` has two renders of the area as it is now, with the World buildings of plan 0018 put in their places and stand-ins for the rest (the architect, 2026-11-15). They show the gap: large empty lawns, a ground with no paths or walls, blocks for the buildings of Hạ Long, no people, and a light that is not golden yet.

## 4. Decisions

| # | Decision | Reason |
|---|---|---|
| D1 | One area is finished first. Its outline is data (`data/showcase/bai_truoc.json`): from Cầu Đá and Hải Âu in the south to the north end of Nhà thiếu nhi, and from the jetty to the lots behind Quang Trung. Inside it, everything of section 5 is done. Outside it, nothing changes. | A town that is full in one place looks better than a town that is half done everywhere. It also tests each step from World to the screen. |
| D2 | The year is 2019. The models of World plan 0018 come from photos of 2014 to 2024. A difference that I know is in the order of the model (for example the paint of Cảng vụ). A difference that nobody knows has the status "Check". | AGENTS.md, section 1. |
| D3 | The game owns the place of each thing. `data/world/places/bai_truoc.json` gives each model of World its position, its direction, and its level of detail, from the survey of World (`priv/surveys/quang_trung.json`, the field `at`) and the roads of plan 0005. | World guide (`docs/requests.md`): a project owns the place of each thing. The survey of World has the points, but not the frame of the game. |
| D4 | The models of buildings and sculptures of World keep their own textures (their materials `part_NN`). A rule of `data/world/materials.json` keeps them. The roles of plan 0023 (D3) stay for the other models. | World now gives a building its maps (World plans 0009, 0010). They carry the detail that a plain color cannot. |
| D5 | The requests of section 7 are files of this repository, sent to World as plan 0023 does. World builds them from its rules. | World guide: "A project does not add its things to World: it keeps its requests in its own repository." |
| D6 | The level of detail follows the preset. On Low the near level of a building is its mid level (a block of World plan 0018 has 117 000 triangles at near and 18 600 at mid). The near level of a building is for High and Ultra. | The budget of Low is 300 000 triangles in a view (plan 0020, Q7). |
| D7 | A beauty pass, as data: the color grading, the bloom, the haze, and the sky for each hour, on each preset. Five fixed shots (section 3) are the review views and the frames of a short video. | Most of the look of a good screenshot is light and color. The shots make each review the same. |
| D8 | People come from the person blueprint of World, with ages from 1 to 90, in the clothes of 2019 (section 7). They follow simple routines (walk a path, sit, sell, swim) from data. The full people of plan 0006 come later. | A place with no people does not look real. |

## 5. Requirements

### Before the work

- **R1.** The branches of plans 0023, 0020, and 0008 go to `main` after their reports are clear (report 0008 interim: D-0008-01 to D-0008-05; report 0020: D-0020-04 needs my approval of the PT-52 sheets; plan 0023: my approval of the Phase A sheet). This plan starts from `main`.

### The ground

- **R2.** Quang Trung as it is in the area: two roads of about 10 m, one for each direction, with a median of about 3 m with a hedge, Araucaria trees, and lamps; the curb red and white where the photos show it; the sidewalk of the side of the town, about 5.5 m, with tiles. The sizes come from the survey of World plan 0018 (section 3.1).
- **R3.** The park: its paths and its paved squares from the footways and the areas of OpenStreetMap, its lawns in granite borders, flower beds, the pavilion with the orange tile roof, benches, low lamps, and the sculptures of the photos (their subjects are "Check" until I know them).
- **R4.** The walk of the sea, the low wall of stone along the beach, and the sea wall of stone blocks (photos of section 3, S5).
- **R5.** The beach between the wall and the water, with the tide of plan 0005. Basket boats (thúng chai) on the sand above the water line.
- **R6.** Hạ Long from Quang Trung to Hải Âu: its road, its sidewalks, and the houses and hotels on the side of the hill, with the houses of the street rules of World (plan 0009, D3) where no survey exists.

### The buildings and the things

- **R7.** The buildings of World plan 0018 at their places (D3): `cang_vu_vung_tau`, `quang_trung_4_10`, `quang_trung_12_18`, `quang_trung_20_26`, `khach_san_grand_canh_nam`, `khach_san_grand`, and the other buildings of the area when World has them (section 7). A building in the area that World does not have yet keeps a stand-in of its real outline and height.
- **R8.** The jetty of Cầu Đá from plan 0008 (R15), and the moored fishing boats (`ghe_danh_ca_vung_tau`) and the basket boats (`thung_chai_edits`) of `sea_objects.json`, on the water with the tide and the waves.
- **R9.** The trees of plan 0020 in the park and on the streets, with the Araucaria of the median and the coconut palms that lean (photos of section 3, S2). The lamps of the photos: the blue lamp poles, the lamps of globes on the median, the low lamps of the park.
- **R10.** People (D8): people who walk on the walk of the sea and in the park, people who sit on the benches and on the wall, sellers with their carts on the sidewalk, children, and at 17:00 the families who swim in the evening with rented swim rings (plan 0015). About 40 people in the area at 17:00, fewer at noon. Each has a path or a place and a routine from `data/showcase/people.json`.
- **R11.** Scooters: parked in rows on the sidewalk of the bars (plan 0023, `WorldRow`), and some riders on fixed loops of Quang Trung and Hạ Long at a real speed. They stop for nobody in this plan, so the loops stay on the roads.

### The look

- **R12.** The materials (D4): a rule in `data/world/materials.json` keeps the textures of the materials `part_*` of World. The plaster, the tiles, and the stone of the ground of R2 to R4 use texture sets (CC0, for example from Poly Haven, fetched in CI) with the roles of plan 0023.
- **R13.** The beauty pass (D7): `data/look/grading.json` gives, for each hour and each preset, the exposure, the color grading, the bloom, the haze, and the sky. The golden hour (16:30 to 17:45 in January) is warm and low, with long shadows.
- **R14.** Night: the lamps, the lit fronts of the bars, and the windows of the hotels from 18:00.

### The shots and the budget

- **R15.** The five shots of section 3 as data (`data/showcase/shots.json`: position, direction, lens, time). PT-72 takes each shot on Low (Mobile renderer) and on High (Forward+), at 17:10 and at 12:00, and makes a sheet with the link of its photo of section 3.
- **R16.** Budget, at each shot: Low at most 300 000 triangles and 600 draw calls; High at most 2 000 000 triangles and 2 000 draw calls. PT-73 measures them and fails over the limit.

## 6. Phases

1. R1: the three branches go to `main`.
2. The ground (R2 to R6) and the places of the World buildings (R7, D3, D4). The shots of R15 from the start, with what is there.
3. The trees, the lamps, the boats, the jetty (R8, R9).
4. The beauty pass (R12, R13). I look at the shots on High.
5. The people and the scooters (R10, R11).
6. The new buildings of World as they come (section 7), and night (R14).

## 7. Requests to World

These are requests of this repository (D5). World builds them from its rules.

| # | What | From |
|---|---|---|
| Q-W1 | **The year.** World plan 0018 asks which year: 2019 for each model of this game. | World plan 0018, section 6 |
| Q-W2 | **Hải Âu** (OSM way 790529523, about 70 m long, on Hạ Long in front of Cầu Đá): a `building`, from about ten photos. Its storeys and its look in 2019 are "Check". | I remember it in front of Cầu Đá in the 1990s. |
| Q-W3 | **Nhà khách Hạ Long** (102 Hạ Long, OSM way 235149416, 8 storeys): a `building`. | OSM |
| Q-W4 | **Nhà thiếu nhi** and the low block and the office (rows T14 to T16 of the survey): World plan 0018, step 4. | World plan 0018 |
| Q-W5 | **The park**: the pavilion with the orange tile roof, a bench of the park, a low lamp, the blue lamp pole, the lamp of globes, a kiosk, and the sculptures (when I know their subjects). | Photos of section 3 |
| Q-W6 | **People of 2019**: the clothes of a town in 2019 (a T-shirt, a shirt, shorts, long pants, a dress, áo bà ba, a sun jacket, sandals, a helmet, a nón lá, swim clothes), and a swim ring (phao). | R10 |
| Q-W7 | **The sea wall**: a piece of 2 m of the wall of stone blocks and of the low wall of the walk, with the granite border of a lawn, as the street kit (W21). | Photos of section 3, S5 |
| Q-W8 | **The Araucaria** tree, a hedge, and the plants of a flower bed, with the plant blueprint. | Survey of World plan 0018, section 3.1 |

## 8. Play-test scenarios

- **PT-71 `showcase_places`.** Each model of `places/bai_truoc.json` stands on the ground (its base within 0.1 m of the ground), on its lot, with its front to its street. No two models overlap.
- **PT-72 `showcase_shots`.** The five shots of R15, with their sheets. The architect and I look at them next to the photos.
- **PT-73 `showcase_budget`.** The budget of R16 at each shot.
- **PT-74 `showcase_walk`.** With the joystick, walk from the north end of the park along the walk of the sea to Hải Âu and onto the jetty, at 17:00. The player does not fall, does not walk through a wall or a person, and stays on the ground. Screenshots every 50 m.
- **PT-75 `showcase_people`.** At 17:00 the area has 30 to 50 people, the swimmers are in the water near the beach, and nobody stands inside a wall, a tree, or another person. At 12:00 there are fewer.
- **PT-76 `showcase_night`.** The shots S3 and S5 at 20:00: the lamps, the fronts of the bars, and the windows.

## 9. Acceptance criteria

| # | Criterion |
|---|---|
| 1 | The unit tests and PT-71 to PT-76 pass. |
| 2 | I look at each shot of PT-72 next to its photo and say that it is Bãi Trước. |
| 3 | The budget of R16 holds on Low. |
| 4 | No fact with the status "Check" is in the game. |

## 10. Open questions

- **Q1.** Hải Âu and Nhà khách Hạ Long in 2019: their storeys, their colors, and their fronts. Photos from family or friends help.
- **Q2.** The park in 2019: the subjects of the sculptures, the place of the pavilion, and the kiosks.
- **Q3.** The evening swim: the place of the swim ring rentals, and how many people swim at 17:00 on a weekday of January.
- **Q4.** Moving scooters: are fixed loops (R11) enough for the first video, or does it wait for plan 0018?
