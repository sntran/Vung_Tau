# 0008 Known structures

| Field | Value |
|---|---|
| Status | Draft |
| Branch | `feat/0008-known-structures` |
| Depends on | 0005 (the real ground), 0020 (the clearings of the trees). The models come from World (plan 0023, section 9.9, request W13). |
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
| D3 | The models come from World (plan 0023, D9). Until World has a model, the place has a stand-in: a plain shape with the real size, in one color, and the Lens app does not show it as a finished place. | The placement, the visibility, the paths, and the tests can be built and checked now. The stand-in is replaced one place at a time. |
| D4 | What the player can see from a place follows the real ground. The game never adds a line of sight. For example, from Bãi Trước the statue is hidden behind the ridge of Núi Nhỏ, and the lighthouse is mostly hidden. From the south part of Bãi Sau the statue shows above the ridge. | I do not see the lighthouse from Bãi Trước in the real town. The DEM gives the same result (culture notes, section Vũng Tàu). |
| D5 | No floating name labels in the world. The Lens app names the places. The labels stay as a debug option (F3). | The labels overlap and hide the picture (report 0005, D-0005-02). A person who knows the place does not need a label. |
| D6 | Each place has a Lens card in the data: the name, the Vietnamese phrase, the English meaning, and a short text. A fact with the status "Check" is not in the text. | Plan 0003 (the Lens app). |
| D7 | Each place stands on a flat base on the ground (a platform, a floor, or steps). The ground under a place is level, with a skirt that hides the join. | The ground has a 2 m grid. A structure on a slope needs a base, or it floats or sinks. |
| D8 | A place that the player sees from far (the statue, the lighthouse, Bạch Dinh, the church) has a far form: a simple shape with the real silhouette. | The player sees them from 3 km, from the sea, and from the bus. |

## 4. Requirements

### Data and placement

- **R1.** Extend `data/geo/landmarks.json` with the fields of D1. `Content` checks at the start: each place has a position inside the play area, a size with a source, a status, and a Lens card; a place with "Check" has no model order. The position of each place comes from OpenStreetMap or from the published coordinates. The source of each value is a link in `docs/content/reference/landmarks.md` (R11).
- **R2.** Put each place on the ground (D7). The base is flat at the height of the lowest point of its outline plus 0.1 m, and a skirt goes down to the ground around it. The builder records the heights.
- **R3.** Stand-ins (D3): a box, a cylinder, or a cone of the real size for each place. The statue is a column on a round base with a parapet. The lighthouse is a tower of about 18 m with a gallery. The stand-ins use the colors of the places (white, orange, grey), and `Content` marks them as "stand-in". When World has the model, the order of its file replaces the stand-in with no change of the data.
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

### Sources

- **R11.** `docs/content/reference/landmarks.md` lists each place with links to public photos and to the sources of its sizes. Links only, no copied photos. I mark each place as correct or not correct for Vũng Tàu.

## 5. Phases

1. Data, the check, and the stand-ins (R1, R3, R4).
2. Placement and the bases (R2, R5).
3. Paths, stairs, and collision (R6, R7).
4. The visibility tests and the far form (R8, R9).
5. The models of World, one place at a time (after plan 0023).

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
| 1 | The unit tests and PT-59 to PT-64 pass. |
| 2 | I look at the sheets of PT-63 and agree that I know each place. |
| 3 | The visibility of PT-60 matches the real ground, and the labels are gone. |
| 4 | Each place has its sources in `landmarks.md`, and no fact with "Check" is in the game. |

## 8. Open questions

- **Q1.** The sizes of the places. Which sources do we use for the height of the statue, the lighthouse, and the width of Bạch Dinh? The architect finds them and I confirm them.
- **Q2.** The state in 2019: did Khách sạn Hải Âu stand? Could visitors climb the lighthouse? Was Bạch Dinh a museum, and when was it open? Which temples and pagodas stood above Hạ Long? These facts have the status "Check".
- **Q3.** The names. The Lens card of the statue uses "Tượng Chúa Kitô Vua", and the Vietnamese phrase uses what people say, "tượng Chúa giang tay". I confirm the other names.
- **Q4.** The order of the places for World (plan 0023, W13). The statue and the lighthouse first, because the player sees them from far?
