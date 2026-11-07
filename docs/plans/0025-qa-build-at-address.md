# 0025 QA mode: build a house at an address

| Field | Value |
|---|---|
| Status | Draft |
| Branch | `feat/0025-qa-build-at-address` |
| Depends on | 0005 (the roads and the addresses), 0009 (the lots), 0023 (the models from World), plan 0001 of World ("The people build on demand"): the stream of a construction (`POST /builds`), the blueprints in data, and the MCP tools `plan_build` and `build`; and plan 0002 of World ("The people of World build any blueprint"): a blueprint of the game in the order (or by its hash after `POST /blueprints`), the MCP tool `check_blueprint`, and the skills of the trades (World `docs/skills.md`). |
| Changes | 0023 R2: the fetch of a model can follow the construction of the model. |

## 1. Goal

At the end of this plan, the game has a QA mode for me. In QA mode I walk
to an address in the town, open the QA panel, and tell an architect (a
language model) what to build there: "a tube house of three floors, 4 by
16 m, blue, with a cửa cuốn". The architect writes the order and checks
it with World. Then the people of World build it, and I watch the house
go up on its lot, element by element: the base, the walls, the slabs,
the roof. I can pause the build, change it ("one floor more"), resume
it, or cancel it. When the build is done, the house on the lot is the
finished model of World, and I can keep its order in the data of the
game.

The same calls of World get the known places of plan 0008 and the houses
of the lots of plan 0009 when the game is made (compile time), as plan
0023 does now.

The game owns its blueprints (World plan 0002, D1): the house of a lot,
the statue on Núi Nhỏ and the lighthouse are blueprints in data of the
game, in `data/world/blueprints/`, made of the skills of the trades of
World (a tube house as on a real site: the frame floor by floor, the
bricks band by band, the render and the paint; a statue cast in pours).
The game sends the blueprint with each order. World does not need its
own models of Vũng Tàu.

## 2. Out of scope

- The QA mode in a release build. It is only in the debug builds.
- The houses of the town in normal play (plan 0009). This plan does not
  change them.
- A build with no network. The QA mode needs `world.mkfifo.com`.
- The people of the game. The workers of World are not people of the
  game: the game shows the elements, not the workers (an idea for later).

## 3. Decisions

| # | Decision | Reason |
|---|---|---|
| D1 | The QA mode is a debug feature: a key opens the QA panel, and the export of a release removes it. | The players of a release do not order buildings. |
| D2 | A new autoload `WorldClient` talks to World: `POST /builds` with `accept: text/event-stream`, and it reads the stream with `HTTPClient` (chunked reads in `_process`). Each event is one signal: `planned`, `element`, `paused`, `changed`, `done`, `stopped`. With `Last-Event-ID`, a stream that breaks goes on from its last event. | Godot has no `EventSource`. `HTTPClient` reads a stream in parts. World sends the events of a construction as server-sent events. |
| D3 | Each build has one `Node3D` on its lot. An `element` event gives the key of a GLB and a matrix: the client gets `/builds/ID/elements/KEY.glb` once for each key, decodes it with `GLTFDocument.append_from_buffer` on the `WorkerThreadPool`, and adds an instance of it at the matrix on the main thread. | The keys are hashes of the meshes: a wall of 5,000 bricks has few keys. The decode does not stop a frame; only the main thread changes the scene tree. |
| D4 | At `done`, the client gets the finished model (`/o/HASH.glb` at the level of the build) and puts it in the place of the elements, in one frame. | The finished file has the joined meshes, the materials and the levels, as the other models of plan 0023. |
| D5 | The architect is outside the game: a language model that uses the MCP server of World (`list_blueprints`, `get_blueprint`, `check_drawing`, `plan_build`, `build`). The game gives it the lot (its width, its depth, its front, its neighbors) and my words, and gets an order back. The key of the language model is in an environment variable of my computer, never in the repository. | World checks each order, so the architect can make mistakes and correct them with the errors of World. The game does not need the rules of a house. |
| D6 | When I keep a house, its order goes into `data/world/orders.json` (plan 0023, R1) with the id of the lot, and the lock gets its hash (plan 0023, R3). A blueprint in data or a drawing that is new goes to World as a proposal (`propose_drawing`), and I review it there. | The game has no orders that are not in the lock. World keeps one catalog for all my projects. |
| D7 | The fetch of plan 0023 (`tools/world/fetch.py --source=factory`) uses `POST /builds` with the stream for a model that the factory does not have yet, and prints the elements as they come. It keeps the same files and the same lock. | A first build of a big model takes a long time. The stream shows that it goes on. |
| D8 | The blueprints of the game are data of the game: `data/world/blueprints/NAME.json` (the format of World `docs/format.md`, "A blueprint in data"; the skills of World `docs/skills.md`). Each order of `data/world/orders.json` gives its blueprint as `{"hash": HASH}`; the fetch sends the blueprint to `POST /blueprints` first when World does not have its hash. A blueprint that needs a skill that World does not have is a request to the owner of World. | The game decides how its houses look; World decides how the people build them. The hash names the blueprint and its options, so the lock stays the same for the same data. |

## 4. Requirements

### The client of World

- **R1.** `autoload/world_client.gd`: `build(order, level, budget)` gives the id of the build and starts its stream; `pause(id)`, `resume(id)`, `cancel(id)` and `change(id, order)` call `POST /builds/ID/pause`, `/resume`, `/cancel` and `/change`. Each event of the stream is a signal with its data.
- **R2.** A stream that breaks starts again after 1, 2, 4 and 8 s with `Last-Event-ID`. After four tries, the client gives the signal `lost`.
- **R3.** A unit test plays a recorded stream (a file of events and two element GLBs, as World `test/js/fixtures/world`) into the client, and checks the signals, their order, and the nodes of the build.

### The build on the lot

- **R4.** `scenes/qa/build_site.tscn`: a `Node3D` at the origin of the lot, turned to the front of the lot. For each `element` event, an instance of the mesh of its key at its matrix (the axes of glTF). The mesh of a key is decoded once.
- **R5.** At `done`, the finished model takes the place of the elements in one frame. At `stopped`, the elements stay, gray, with the reason on a label.
- **R6.** A build has a budget: at most 8 workers, 120 s, and the triangles of the near level of a house of plan 0023 (W22). The QA panel shows the budget and the time so far.

### The QA panel

- **R7.** The QA panel shows the address and the lot where I stand (plan 0005 and 0009), a text field for my words, and the buttons Build, Pause, Resume, Change, Cancel and Keep.
- **R8.** Build sends my words and the lot to the architect, shows its order and the plan of World (`plan_build`: the tasks, the trades, the triangles), and starts the build when I press Build again.
- **R9.** Change sends my new words and the order of the build to the architect, and sends the new order with `change`. The elements that stay stay on the lot, and the elements that World makes again go away and come again.
- **R10.** Keep writes the order into `data/world/orders.json` with the id of the lot, and runs `tools/world/fetch.py --update` for it.

### The fetch at compile time

- **R11.** `tools/world/fetch.py --source=factory` follows the stream of a build when the factory does not have the files, and prints one line for each task that is done. The files and the lock stay as plan 0023 says.
- **R12.** The known places of plan 0008 (the statue on Núi Nhỏ, the lighthouse) are orders of blueprints of the game in `data/world/orders.json`, with the sizes and the sources of plan 0008.
- **R13.** `data/world/blueprints/`: the house of a lot (from the example `tube_house` of World: the width, the depth, the floors, the openings of each floor and the finish of each wall of the lot of plan 0009), the statue and the lighthouse. `tools/world/fetch.py --check` calls the MCP tool `check_blueprint` on each, and fails with the path of each error.
- **R14.** The fetch sends a blueprint to `POST /blueprints` when an order gives a hash that World does not have (an order with an unknown hash gives the error `blueprint.hash`), then places the order.

## 5. Phases

1. The client and its test with a recorded stream (R1 to R3).
2. The build on a lot, with an order that I write by hand (R4 to R6).
3. The QA panel and the architect (R7 to R10).
4. The fetch at compile time and the blueprints of the game (R11 to R14).

## 6. Play-test scenarios

- **PT-01.** In QA mode, I stand in front of an empty lot of Hẻm 2 Hải Đăng. I ask for "a tube house of two floors". The plan of World shows on the panel. I press Build, and the house goes up on the lot in less than 120 s, element by element. At the end, the model is the finished model.
- **PT-02.** During the build, I press Pause. No new element comes. I ask for "three floors" and press Change, then Resume. The ground floor stays, and the rest comes again with one floor more.
- **PT-03.** I press Cancel. The elements stay gray, with the label "cancelled".
- **PT-04.** I turn off the network during a build, then turn it on. The build goes on from its last element, with no element two times.
- **PT-05.** In a release build, the key of the QA panel does nothing.

## 7. Acceptance criteria

- The unit tests of the client pass, also with a stream that breaks.
- PT-01 to PT-05 pass on the desktop at the quality preset "high" of plan 0004, with no frame over 33 ms when an element comes.
- A house that I keep is in `data/world/orders.json` and in the lock, and `fetch.py --check` passes.

## 8. Open questions

- **Q1.** Which language model is the architect, and does the game call it, or does a small tool on my computer call it and give the order to the game?
- **Q2.** The edge of World has 128 MB. A house at near can need more memory than that (World AGENTS.md, "Known problems"). Is the mid level good enough for the QA mode until World measures it? (World plan 0002 puts the memory later: a node can run on a computer with more memory.)
- **Q3.** The world page of World shows the yard: the trucks that bring the bricks to the site, the people at work. Does the QA mode show them too, or only the elements on the lot?
