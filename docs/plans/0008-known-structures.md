# 0008 Known structures

| Field | Value |
|---|---|
| Status | In progress |
| Branch | `feat/0008-known-structures` |
| Depends on | 0005 (the real ground), 0020 (the clearings of the trees), and World: the blueprints of buildings and statues (plan 0023, D9, request W13). |
| Used by | 0010 (the bus ride passes some of these places), 0016 (Hòn Bà), 0017 (the Vi Ba road), 0024 (the cable car), and the activities of the first release: the stairs to the statue, the lighthouse, Bạch Dinh, Cầu Đá. |

## 1. Goal

At the end of this plan, a person who knows Vũng Tàu looks at the screen and says the name of the place. The known places of the town stand where they stood in 2019, with their real size, and the player can walk to them. A picture of Bãi Trước, Bãi Sau, or the road to Núi Lớn is a picture of Vũng Tàu, and not of any beach with a hill.

The places are:

- The statue on the top of Núi Nhỏ (Tượng Chúa Kitô Vua, and the stairs to it).
- The lighthouse (Hải đăng Vũng Tàu).
- Bạch Dinh.
- The statue of Our Lady at Bãi Dâu (Tượng Đức Mẹ Bãi Dâu).
- Miếu Hòn Bà, with its gate, its steps, and the two old bunkers.
- Chùa Tam Bảo on the Vi Ba road.
- The old stone jetty of Cầu Đá.
- Nhà thờ lớn Vũng Tàu and the statue of Trần Hưng Đạo.
- The temples and pagodas on the slope above Hạ Long.
- The town anchors: the bus station, the markets, the big roundabout, and Ngã Năm.

## 2. Out of scope

- The inside of any building. The player stays outside or on a terrace.
- The activities at these places (plans 0016, 0017, 0024 and others).
- The houses between the places (plan 0009).
- The people at these places (plan 0006).

## 3. Decisions

| # | Decision | Reason |
|---|---|---|
| D1 | One record for each place in `data/geo/landmarks.json`: the id, the name in Vietnamese and English, the position, the direction, the size, the order of its model, the source of each size, and a status (Confirmed, Source, or Check). | Content is data (AGENTS.md, section 4). I must be able to edit it. |
| D2 | A place with the status "Check" does not go into the game without my approval. | AGENTS.md, section 7. |
| D3 | World makes the models of the buildings and the statues with its systems: the same assemblies of materials, parts, and physics as its houses, with new blueprints for towers, villas, churches, temples, and statues (plan 0023, W13). Vũng Tàu owns the drawing of each place: an order in `data/landmarks/NAME.json` with its sizes and a source for each size. The parts that sit on the ground (the stairs, the paths, the platforms, the jetty, and the retaining walls) come from the game at the load of a chunk, from the lines of OpenStreetMap and the heights of the DEM, as the roads do. | A temple, a tower, or a statue has a grammar of parts, like a house. A system in World makes many of them from options, for this game and for other projects (for example the temples and the statues of Tre). A stair or a jetty must fit the real ground to the centimeter, so the game makes it on the ground. Changed on 2026-11-06. |
| D3a | Until a place has its model, it has a stand-in: a plain shape with the real size, in one color. The Lens app does not show it as a finished place. | The placement, the visibility, the paths, and the tests can be built and checked now. The stand-in is replaced one place at a time. |
| D3b | Each order is data: the blueprint, the options, the sizes, and the sources. `data/world/orders.json` (plan 0023, R1) lists them, and the lock file pins the bytes. | Content is data. A size with no source is a guess, and I can correct a drawing without code. |
| D3c | A statue is a figure of the person blueprint of World at the real size, in the pose of the statue, cast as one solid: the body and the robe are one shell of concrete or stone, with the stains of the sea air. A statue can be hollow, with stairs and openings inside. | The statues are human figures. A figure made of boxes does not look like the statue from Bãi Sau or from the sea. Visitors climb inside the statue on Núi Nhỏ to its shoulders. |
| D4 | What the player can see from a place follows the real ground. The game never adds a line of sight. For example, from Bãi Trước the statue is hidden behind the ridge of Núi Nhỏ, and the lighthouse is mostly hidden. From the south part of Bãi Sau the statue shows above the ridge. | I do not see the lighthouse from Bãi Trước in the real town. The DEM gives the same result (culture notes, section Vũng Tàu). |
| D5 | No floating name labels in the world. The Lens app names the places. The labels stay as a debug option (F3). | The labels overlap and hide the picture (report 0005, D-0005-02). A person who knows the place does not need a label. |
| D6 | Each place has a Lens card in the data: the name, the Vietnamese phrase, the English meaning, and a short text. A fact with the status "Check" is not in the text. | Plan 0003 (the Lens app). |
| D7 | Each place stands on a flat base on the ground (a platform, a floor, or steps). The ground under a place is level, with a skirt that hides the join. | The ground has a 2 m grid. A structure on a slope needs a base, or it floats or sinks. |
| D8 | A place that the player sees from far (the statue, the lighthouse, Bạch Dinh, the church) has a far form: a simple shape with the real silhouette. | The player sees them from 3 km, from the sea, and from the bus. |

## 4. Requirements

### Data and placement

- **R1.** Extend `data/geo/landmarks.json` with the fields of D1. `Content` checks at the start: each place has a position inside the play area, a size with a source, a status, and a Lens card; a place with "Check" has no model order. The position of each place comes from OpenStreetMap or from the published coordinates. The source of each value is a link in `docs/content/reference/landmarks.md` (R11).
- **R2.** Put each place on the ground (D7). The base is flat at the height of the lowest point of its outline plus 0.1 m, and a skirt goes down to the ground around it. The builder records the heights.
- **R3.** Stand-ins (D3a): a box, a cylinder, or a cone of the real size for each place. The statue is a column on a round base with a parapet. The lighthouse is a tower of about 18 m with a gallery. The stand-ins use the colors of the places (white, orange, grey), and `Content` marks them as "stand-in". When the build has the model, the model replaces the stand-in with no change of the data.
- **R4.** Remove the floating markers of plan 0005 (R15) from the world (D5). F3 shows them again.
- **R5.** The clearings of the trees (plan 0020, D-0020-01) come from the outline of each place and its paths and stairs, plus 3 m around them.

### Paths and stairs

- **R6.** Walkable paths:
  - The stairs from the road to the statue on Núi Nhỏ, with the route of OpenStreetMap (`highway=steps`) when it exists, and with a landing at each turn. Each step is 15 cm to 18 cm high.
  - The steps of Miếu Hòn Bà and the path on the islet (plan 0005, R8i).
  - The jetty of Cầu Đá, about 400 m, with the stone edge. The player walks on it.
  - The area around the statue: the round base, with a parapet that the player cannot pass.
- **R7.** Collision for each place: the player does not walk through walls, and does not fall from the jetty or the base. The collision uses simple boxes, not the visible shape.

### The view

- **R8.** The visibility of each place from the viewpoints of D4 matches a ray test against the DEM (tools/geo, Python), and the game matches the same test against its own ground. The two results agree for the viewpoints of PT-60.
- **R9.** The far form (D8) shows from 3 km to the sea. The far form of the statue and the lighthouse is at most 300 triangles each.
- **R10.** Night: the lighthouse has a turning light. The statue has a light on it. Both have the status "Check" for the times and the color in 2019, so they stay off until I approve them.


### The models (D3)

- **R12.** One order for each place in `data/landmarks/NAME.json`, and its entry in `data/world/orders.json`. The game imports the files of World as plan 0023 (R2, R6) says: near, mid, and far forms, the collision boxes, and the ports.
- **R13.** The first orders, in this order: the statue on Núi Nhỏ, the lighthouse, Bạch Dinh, Miếu Hòn Bà, Cầu Đá (the ground part only), then the others. Each order waits for the blueprint of World that it needs (W13).
- **R14.** The statue on Núi Nhỏ: the figure is 32 m high, with arms 18.4 m wide from hand to hand, on a base with the carvings of Christ and the twelve apostles. The stairs from the road have 811 steps. Inside, 133 steps in a spiral go up to the shoulders, where visitors look out (I confirm this). This plan makes the inside as part of the model, closed to the player. A later plan opens it.
- **R15.** The ground parts (D3) come from `scripts/geo/` builders: the stairs follow the OSM line with steps of 15 cm to 18 cm and landings, the jetty follows the OSM outline with its stone edge, and a platform is level with a retaining wall on its low side. The materials come from the same roles as the houses (plan 0023, D3).
- **R16.** The review sheet of each model: the render of World next to the links of its photos in `landmarks.md`, from the front, the side, and the far distance. I approve each place on its sheet before the stand-in goes.

### Sources

- **R11.** `docs/content/reference/landmarks.md` lists each place with links to public photos and to the sources of its sizes. Links only, no copied photos. I mark each place as correct or not correct for Vũng Tàu.

## 5. Phases

1. Data, the check, and the stand-ins (R1, R3, R4).
2. Placement and the bases (R2, R5).
3. Paths, stairs, and collision (R6, R7).
4. The visibility tests and the far form (R8, R9).
5. The orders and the models of World, one place at a time (R12 to R14): the statue and the lighthouse first, because the player sees them from far.
6. The ground parts (R15): the stairs to the statue, the steps of Miếu Hòn Bà, the jetty of Cầu Đá.

## 6. Play-test scenarios

- **PT-59 `landmark_data`.** The unit test of R1: each place has the fields, the sources, and the status. A place with "Check" has no model.
- **PT-60 `landmark_views`.** Cast rays from these eye points to the top of the statue and the lighthouse: the beach of Bãi Trước, the south part of Bãi Sau, the Hải Đăng road, and the sea in front of Bãi Trước. Compare the result with the DEM calculation of the tools. Take a screenshot of each view at 12:00 and 18:00.
- **PT-61 `statue_stairs`.** With tap to walk, go from the road to the base of the statue. The player stays on the stairs, reaches the top, and does not pass the parapet. Take a screenshot at the bottom, the middle, and the top.
- **PT-62 `cau_da_jetty`.** Walk the jetty from the start to the end and back. The player does not fall.
- **PT-63 `landmark_sheet`.** For each place, three screenshots: from 200 m, from 50 m, and from 10 m. The architect looks at them.
- **PT-64 `landmark_lens`.** Aim the Lens app at each place: the card of the place shows with its name.

## 7. Acceptance criteria

| # | Criterion |
|---|---|
| 1 | The unit tests and PT-59 to PT-64 pass, and the lock file of World passes its check (plan 0023, R4). |
| 2 | I look at the sheets of PT-63 and agree that I know each place. |
| 3 | The visibility of PT-60 matches the real ground, and the labels are gone. |
| 4 | Each place has its sources in `landmarks.md`, and no fact with "Check" is in the game. |

## 8. Open questions

- **Q1.** The sizes of the places. Which sources do we use for the height of the statue, the lighthouse, and the width of Bạch Dinh? The architect finds them and I confirm them.
- **Q2.** The state in 2019: did Khách sạn Hải Âu stand? Could visitors climb the lighthouse? Was Bạch Dinh a museum, and when was it open? Which temples and pagodas stood above Hạ Long? These facts have the status "Check".
- **Q3.** The names. The Lens card of the statue uses "Tượng Chúa Kitô Vua", and the Vietnamese phrase uses what people say, "tượng Chúa giang tay". I confirm the other names.
- **Q5.** Answered: in 2019, visitors climbed inside the statue to its shoulders. A later plan makes it an activity (R14).
- **Q7.** (Builder, 2026-11-06.) R2 and R15 do not agree for a base on a slope. R2 says: "The base is flat at the height of the lowest point of its outline plus 0.1 m, and a skirt goes down to the ground around it." R15 says: "a platform is level with a retaining wall on its low side." The plaza of the statue on Núi Nhỏ is now level at the lowest point of its ring (R2). On the uphill side, the ground outside the parapet is up to 1.5 m higher than the plaza, so the parapet (1 m) is partly in the ground, with a wall of ground behind it. Which do you want: (a) R2 as now, with a retaining wall on the high side; (b) the plaza at the highest point of its ring, with a skirt or a retaining wall on the low side (R15); or (c) the plaza at the middle height, with a cut on the high side and a wall on the low side?
- **Q4.** Answered on 2026-11-06: the jetty of Cầu Đá follows the old stone line of OpenStreetMap (way 286293879, "Cầu Đá cổ", 254 m). Its land end is in the sea, about 90 m from the shore. The game goes on along the same line to the first point of the shore over the highest tide (R6, R15).
- **Q6.** Answered on 2026-11-06: the Lens cards are in `data/geo/landmarks.json`, in the record of each place (D6).

## 9. Builder notes

- **N1. Data (R1, D1, D2).** Each place of the plan has a "place" record in `data/geo/landmarks.json`: the names, the kind of stand-in, the sizes with a source for each, the colors, the status, and the Lens card. `KnownPlaces.check()` checks the records at the start, and PT-59 (`tests/unit/test_known_places.gd`) checks them in the unit tests. Six places have sizes with sources: the statue on Núi Nhỏ, the lighthouse, Bạch Dinh, Đức Mẹ Bãi Dâu, Miếu Hòn Bà, and Cầu Đá. The sources are in `docs/content/reference/landmarks.md`, and the facts of the Lens cards are in `docs/content/culture-notes.md` with the status "Source". Chùa Tam Bảo, Nhà thờ lớn Vũng Tàu, the statue of Trần Hưng Đạo, and the town anchors have no source of their sizes yet: they have the status "Check", no stand-in, and no Lens card (Q1, Q2).
- **N2. The stand-ins (R3, D3a, D8, R9).** `scenes/world/known_places.gd` makes them: the statue (a figure with arms on a dome, a terrace, and a base, on a round plaza with a parapet), the lighthouse (a tower with a gallery), Bạch Dinh (a block with a roof on the OSM outline), and a prism on the OSM outline for Đức Mẹ Bãi Dâu and Miếu Hòn Bà. The Lens card of a stand-in says "stand-in". The far form of the statue has 50 triangles, and of the lighthouse 44 (R9: 300 or less).
- **N3. The bases and the ground (R2, D7, R15).** `tools/geo/build.py` (`level_places()`) makes the ground level under each place at the lowest point of its outline (or of its plaza) plus 0.1 m, and writes `base_height` in `data/geo/build/landmarks.json`: the statue 136.52 m, the lighthouse 172.57 m, Bạch Dinh 20.27 m, Đức Mẹ Bãi Dâu 55.49 m, Miếu Hòn Bà 7.84 m. Round each base, for 6 m, the ground is not higher than a slope of 0.6 up from the base (a cut): on the uphill side of the plaza, the ground was 1.5 m higher and covered the parapet (Q7 asks what you want there). `cut_stairs()` then limits the grade of the ground under the stairs and the other ways of the route of each place to 0.5 (the mean of a cut and a fill, with the two ends of each way at the height of the ground), in a band of the width of the way and 3 m; the stairs come last, and the ways on the plaza are not cut. Under the stairs to the statue, the ground rose up to 0.86 m in each meter, steeper than steps can climb. The cut changes the ground by 3.6 m at most. The clearings of the trees come from the outline of each place, its stairs, and its jetty, plus 3 m (R5, `clearings.known_place_shapes()`).
- **N4. The labels (R4, D5).** The markers of plan 0005 are hidden. F3 (or `--debug`) shows them. PT-39 checks that they are hidden, and that F3 shows them.
- **N5. The stairs (R6, R7, R15).** The stairs follow the OSM lines of `highway=steps` (the statue: ways 788327902, 222906171, 788327910, 788327915, 222906168; Miếu Hòn Bà: way 221906225). All steps of a stair have one height of 15 cm to 18 cm, from the rise of the whole stair (`KnownPlaces.stair_profile()`). The steps follow the ground: a step goes up or down where the ground is more than 0.6 of a step from the tread, with a tread of 28 cm or more in a straight line (22 cm when the steps are more than two steps from the ground). A turn of more than 30° has a flat landing of 1.2 m at the ground of its middle, and the steps climb to it at 0.58 at most. The treads stand 12 cm over the cut ground. The collision of each stair is a height map with cells of 25 cm: in the width of the stair, a mean of the heights of the walk line (the noses of the steps) near the cell, and beside the stair an invisible slope of 3 m to 0.35 m under the ground, so that a player who walks beside the stairs can walk onto them. Near the foot of the stairs, the player can stand on this slope up to about 0.7 m over the ground. Boxes on each part of the line had edges at the joints, and one surface on the line had steep folds on the inner side of a bend; both stopped the player. The plaza has an opening of 3 m in its parapet where a stair or a way of the route crosses its ring (5 openings at the statue), and its round floor is at the level ground. PT-61 walks the 478 m from the road to the plaza with tap to walk in 8 parts, and a 9th part pushes the player to the parapet. The OSM ways of the route do not meet at one place: the end of footway 788327903 is 5.4 m from the foot of stair 788327902, and the player walks over the ground there.
- **N6. The jetty (R6, R7, Q4).** The deck is 4 m wide (the top width of the source), 0.6 m over the highest tide of the game year (2.05 m), with a stone edge of 0.35 m and invisible walls of 1.1 m at the sides and at the sea end. With the part to the shore, the jetty is 352 m. The player can stand on the deck over deep water: `VungTau.can_stand()` asks `KnownPlaces.floor_at()` first. The faces of the boxes of `known_places.gd` were in the wrong order, so the deck showed its inside (the water was visible through it). A unit test now checks that the faces of a box face out. The prisms had the same defect (their tops were not drawn); a second unit test checks them.
- **N7. The views (R8, D4, PT-60).** `tools/geo/geodata/visibility.py` casts the rays of `data/geo/place_views.json` against the DEM, and writes `data/geo/build/place_views.json`. The game casts the same rays against its own ground. The part of the place that shows (10 samples from the base to the top):

  | Eye | Statue (36 m) | Lighthouse (18 m) |
  |---|---|---|
  | The beach of Bãi Trước | 0.0 | 0.1 |
  | The south part of Bãi Sau | 0.8 | 1.0 |
  | The Hải Đăng road | 0.0 | 0.4 |
  | The sea in front of Bãi Trước | 0.0 | 0.0 |

  The DEM and the game give the same values for each view. No view was changed.
- **N9. The sheets (PT-63).** Each place has its three screenshots. From 10 m, Bạch Dinh is behind the trees of the slope, and from 50 m the lighthouse is behind the trees of Núi Nhỏ (D4). From 10 m, Miếu Hòn Bà is behind the rocks of the islet. The clearings round the places are 3 m (R5): tell me if you want the views of the sheets from other points.
- **N8. Phase 5 waits.** The orders of the models (R12 to R14, R16) wait for the blueprints of World (W13). Each place keeps its stand-in until World has its model.
