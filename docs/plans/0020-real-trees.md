# 0020 Real trees

| Field | Value |
|---|---|
| Status | Draft |
| Branch | `feat/0020-real-trees` |
| Depends on | 0005 (status "Built"). Uses the quality presets of 0004. |

## 1. Goal

The trees of Vũng Tàu look real. A player who knows the town sees the coconut palms of Bãi Trước, the casuarinas of Bãi Sau, the bàng trees of the park, and the forest on Núi Lớn and Núi Nhỏ, and knows them. The trees move in the wind, cast shadows, and change with the season of the game date.

The box shapes of plan 0005 (`TreeKit`) go away.

## 2. Out of scope

- The trees on the far hills at every distance. Defect D-0005-01 of plan 0005 adds them first, with simple far forms. This plan replaces the near and middle forms, and the far form if it is better.
- Garden plants and fruit trees of the homestay (plan 0022).
- Tết plants: the pots of hoa mai and the other plants of the flower market (plan 0021).
- Grass, bushes, and flowers on the ground.
- Trees that fall, are cut, or grow.

## 3. Decisions

| ID | Decision | Reason |
|---|---|---|
| D1 | The trees are made by code in Blender (`bpy` from PyPI, the version of plan 0006), from the values in `data/trees/types.json`. The script exports a `.glb` for each type and variant. | We have no artist. Free libraries have few tropical trees, and the workspace cannot download from `dl.polyhaven.org`. Code lets me change a tree with numbers. Plan 0006 already runs Blender in the workspace and in CI. The prototype `docs/prototype/trees/trees.py` makes a coconut palm and a bàng tree in about 40 s each. |
| D2 | The prototype pictures `docs/prototype/trees/trees_v1.jpg` show the target look. | I judge a look from a picture, not from text. |
| D3 | Each type has three forms: near (real leaves and leaflets), middle (leaf cards: flat pictures of leaf groups with alpha), and far (an impostor: a picture of the tree from many directions, on a camera-facing card). Godot changes the form by distance with `visibility_range_begin`, `visibility_range_end`, and a fade. | A tree with real leaves has tens of thousands of triangles. The town has about 29 000 street trees and many more hill trees. Only the near trees can have real leaves. |
| D4 | The leaves use alpha scissor, not alpha blend. | Blended leaves sort wrong and cannot cast shadows. Scissored leaves can. |
| D5 | Each type has at least 3 variants with different seeds. The world adds a random turn and size to each tree. | Copies of one tree in a row look false. |
| D6 | Wind moves the trees in the vertex shader: the trunk a little, the branches more, the palm fronds and the leaves most. The wind of the game sets the strength and the direction. | Trees that do not move look dead. A shader costs almost nothing. |
| D7 | Only facts with the status "Source" or "Confirmed" in `docs/content/culture-notes.md` choose the tree types of a place. | I know the town. A guess must not become a fact. |

## 4. Requirements

### The tree types

- **R1.** Types and their first values (the builder sets the sizes from sources and adds them to `data/trees/types.json` with the status "check"):

| Type | Where | Look |
|---|---|---|
| `coconut` | Bãi Trước (shore and park), coast roads | Curved grey trunk with rings, 8 to 15 m. A crown of 18 to 26 fronds of about 4 to 5 m. Leaflets hang down in a V. Dead brown fronds hang under the crown. Green and brown coconuts. |
| `bang` | The park of Bãi Trước, streets | Straight dark trunk. Branches in flat layers (tiers), like a pagoda. Large leaves in groups at the ends of the twigs. In the dry season, some leaves are red and orange (Q4). |
| `casuarina` | Bãi Sau, coast roads | Tall and thin, with a sparse, uneven crown of thin grey-green needles. |
| `flame` | Streets, Núi Lớn | Phượng vĩ: wide, flat crown like an umbrella, small fern-like leaves. Red flowers from late April to early July. Few leaves late in the dry season. |
| `frangipani` | Streets, temples, parks | Hoa sứ: short, thick, grey branches that fork. Long leaves in groups at the ends. White and yellow flowers. |
| `fan_palm` | Parks | Round fan leaves on long stems. |
| `shade` | Main roads | A large shade tree (Q1). |
| `tall_shade` | Between the Bãi Trước road and the sea | Q2. |
| `hill_a`, `hill_b`, `hill_c` | Núi Lớn, Núi Nhỏ | Three forms of the hill forest (Q3): a round broadleaf crown, a tall tree with a high crown, and a low, wide bush-tree. Some lose leaves in the dry season. |

- **R2.** `data/trees/types.json` holds the values of each type: the sizes, the counts of branches, fronds, and leaves, the colors of each season, the flower season, and the seeds of the variants. Code does not hold these values.
- **R3.** The build script (`tools/trees/build.py`) makes the forms of R5 for each type and variant: `assets/trees/TYPE_VARIANT.glb` and the impostor textures. It is in CI and in the workspace. It is deterministic: the same values give the same files.

### The look

- **R4.** At the near distance, each type looks like the target picture for its type (D2), under the light of the game. The leaves let light through when the sun is behind them.
- **R5.** The forms and the distances of each preset:

| Preset | Near form to | Middle form to | Far form to |
|---|---|---|---|
| Low | 20 m | 120 m | 900 m |
| Medium | 35 m | 200 m | 900 m |
| High | 60 m | 300 m | 1 500 m |
| Ultra | 90 m | 400 m | 2 000 m |

- **R6.** A change of form is not visible as a jump: the forms fade, and the mean color of the middle and far forms is within 8 % of the near form, under the same light.
- **R7.** The trees cast shadows inside the shadow distance of the preset. The far form does not cast shadows.
- **R8.** Wind (D6). In calm air, the leaves still move a little.
- **R9.** The season (`scripts/season.gd`) changes the colors, the share of bare branches, and the flowers of each type, as `data/trees/types.json` says.

### In the world

- **R10.** `StreetTrees` and the hill trees of `scenes/world/vung_tau.gd` use the new types. The mixes in `data/geo/trees.json` use the new type names. Bãi Trước has coconut palms along the shore and in the park (culture notes).
- **R11.** The boats are only at the corner end of Bãi Trước (plan 0005, Q6). The trees of the main beach do not stand on the sand where the locals swim.
- **R12.** Budget (plan 0004, R14): at the views of PT-54, Low stays at 600 draw calls and 300 000 triangles or less, and High at 2 000 draw calls and 2 000 000 triangles or less.
- **R13.** On a phone (Mobile renderer), the near form ends at 15 m, and the middle form at 80 m.

## 5. Play-test scenarios

- **PT-52 `tree_gallery`.** A test scene with each type and variant in a row on flat ground. Screenshots at 8 m, 30 m, 120 m, and 400 m, at 07:00, 12:00, and 17:30, on day 1 (23 January 2027) and on 3 June 2027, on Low and High. The test makes one sheet for each type. Checks: each screenshot of a tree has leaf-colored pixels in the crown area. At each change of form, the mean color of the crown area changes by 8 % or less (R6).
- **PT-53 `bai_truoc_trees`.** Views of Bãi Trước: from the sand of the main beach, from the park, from Quang Trung road, and from the water (the view of D-0005-02). Checks: coconut palms are in the frame (by the test ID of the instances near the view); no tree stands on the sand in front of the swimming area (R11).
- **PT-54 `tree_budget`.** The views "Núi Nhỏ top", "Bãi Trước road", and "Bãi Sau road" on each preset. It records the draw calls, the triangles, and the frame time under lavapipe. Checks: R12.
- **PT-55 `tree_wind`.** Two screenshots 0.5 s apart near a coconut palm and a bàng tree, in wind and in calm air. Checks: the pixels of the crown change between the two screenshots (R8). The trunk base does not move.

## 6. Acceptance criteria

1. The sheets of PT-52 look like the target pictures (D2), and I approve them.
2. In PT-53, I see the coconut palms of Bãi Trước, and I know the place.
3. PT-54 passes on all presets.
4. All unit tests and play tests pass, also the play tests of plans 0004 and 0005.

## 7. Open questions

- **Q1.** Which trees are the large shade trees of the main roads of Vũng Tàu (for example Ba Cu, Trần Hưng Đạo, Lê Lợi)?
- **Q2.** Which trees stand between the Bãi Trước road (Quang Trung) and the sea? A source names old coconut palms and old bàng trees in the park.
- **Q3.** Which trees make the forest of Núi Lớn and Núi Nhỏ? A source on the species, or my memory.
- **Q4.** Do the bàng trees of Vũng Tàu turn red and drop leaves near Tết?
- **Q5.** Is the target look of `trees_v1.jpg` correct? What must change?
