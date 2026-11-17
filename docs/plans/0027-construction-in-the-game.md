# 0027 The construction is in the game

| Field | Value |
|---|---|
| Status | Draft |
| Branch | `feat/0027-construction-in-the-game` |
| Depends on | 0023 (models from World). World steps W24 to W28 (section 5). |
| Changes | 0023 (D1, R2, R3, R5: a model is its parts, not one GLB for each level), 0026 (D5, `docs/world-models.md`: the loop of look and edit). |

## 1. Goal

World works as Dreams. In Dreams, a creation is many small sculptures and elements, the engine builds and streams each one, and the creation is put together where it is used. So:

- **World gives the tools, the parts, and the labour.** Its people build each part of a model as a small job and stream it. World does not join the parts into one model, and it does not keep a whole model in memory.
- **Vũng Tàu does the construction.** It gets the parts of each model and glues them together at their places, in the game.
- **An edit builds only the parts that change.** The other parts come again from the store of World, by their keys.

Why now (report 0026, section 3): the edge of World answers 503 for each building of 17 m or more; the join at the end of a construction is the peak of the memory (`house_brick_vn` at near: about 680 MB, World `docs/factory.md`); and each change of Hải Âu takes 28 minutes with `mix world.order` in CI. A part of a building (a wing, a band of balconies, a stair tower, the letters) is small, so the edge can build it.

## 2. Out of scope

- The changes in World. World makes them (section 5); this plan says what Vũng Tàu needs.
- Downloads while the game runs. The game that I give to players has all the files (plan 0023, D2). The stream is for the build and for the loop of look and edit.
- The catalog models that World builds natively (the statue, the Grand Hotel, Cảng vụ). They keep their files until World gives them as parts too.

## 3. Decisions

- **D1. A model is its parts list.** For each order and each level, World gives a parts list: for each part, its key, its node, its transform, its material roles, and its collision; and the joints and the ports of the model. Reason: the list is small, and the game can put the parts together at any time.
- **D2. A part is fixed by its key.** The key is the hash of the data of the part (and the version of the rule that makes it). The same data gives the same key and the same bytes. World keeps each part file, so an order that has a part of an older order does not build it again. Reason: this makes an edit fast, and the lock can check each file.
- **D3. The glue is a step of the import, not of each start.** For each model and each level, the glue puts the parts at their transforms; the parts of one material become one mesh, and a part that repeats (a window, a balcony, a lamp) becomes a MultiMesh. The result is one scene for each level, with its collision. Reason: the game loads one scene as before, and the draw calls stay low on Low.
- **D4. The lock has the parts.** For each model: the hash of its parts list and the SHA-256 of each part file. `fetch.py --check` needs no network, as before.
- **D5. The loop of look and edit.** `tools/world/drawings.py look` shows the parts as World streams them (the events `element` of `POST /builds`), next to the photos. An edit asks World only for the parts that change.

## 4. Requirements

- **R1.** `tools/world/fetch.py` gets the parts list and the part files of each order from the factory (W24, W25), and from a clone of World for the catalog.
- **R2.** The lock of D4. A new lock lists each part, and `fetch.py --check` checks each file.
- **R3.** The glue of D3 (`tools/world/glue.py`, or an import plugin of Godot). The same parts always give the same scene. Unit tests: the bounds of the glued model are the bounds of its parts; its triangles are the sum of the triangles of its parts; a repeated part is a MultiMesh.
- **R4.** `WorldModel` loads a glued model as before: the levels and their ranges, the joints, `set_pose()`, `parts()`, and the receipt.
- **R5.** The loop of D5 in `drawings.py look`: the parts as they come, then the views next to the photos, then an edit with only the changed parts.
- **R6.** Hải Âu is the first model: its parts come from the factory, and the game glues them. The time from an edit of Hải Âu to its new mid level is at most 5 minutes.
- **R7.** When each order of `data/world/orders.json` comes as parts, the job "Models of World" (`mix world.order` in CI) builds only what World does not give as parts yet.

## 5. What Vũng Tàu needs from World

- **W24.** A parts list for an order at each level (D1), with no join, at the factory and with `mix world.order`.
- **W25.** A URL for each part file by its key (D2), kept in the store of World. Now a part of a build stays for 5 minutes only (`/builds/ID/elements/KEY.glb`).
- **W26.** Each part fits the memory of the edge. A part that does not fit is cut into smaller parts.
- **W27.** An edit of an order builds only the parts whose data changed.
- **W28.** The events `element` of `POST /builds` give the keys of W25.

## 6. Play-test scenarios

- **PT-77 `world_parts`.** Hải Âu at each level, glued from its parts, next to its whole GLB of plan 0023: the bounds agree within 1 cm, the triangles are the same, and the draw calls are not more. Screenshots of both, near and from the walk of Hạ Long.
- PT-56 `world_models` and PT-71 to PT-76 pass with the glued models.

## 7. Acceptance criteria

| # | Criterion |
|---|---|
| 1 | The unit tests, PT-56, PT-71 to PT-77 pass, and CI is green. |
| 2 | Hải Âu comes from the factory as parts, with no build in CI, and an edit gives a new mid level in at most 5 minutes (R6). |
| 3 | The budget of plan 0026 (R16) holds on Low. |

## 8. Open questions

- **Q1.** In Dreams, a soft blend joins the sculptures of one group. Here, a blend stays inside one part: World makes the parts so that no blend crosses two parts. Is that enough for the buildings and the statues? (World answers.)
- **Q2.** For the far level, is one small part for the whole model better than many parts? (World answers, with the triangles and the draw calls of Hải Âu.)
