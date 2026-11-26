# Report 0031: the web build loads in steps

| Field | Value |
|---|---|
| Plan | [0031](../plans/0031-web-load.md) |
| Branch | `feat/0031-web-load` |
| Audit 1 | 2026-11-26, at `a4210ce` (steps 1 and 2) |
| Result | Steps 1 and 2 are made as the plan says, and they help. In the measures of the workspace no target of D10 is met; on my phone the start took about 25 s (section 6). The plan has the changes D11 to D16 for the next steps. |

## 1. What I audited

The report of the builder did not come to me. I read the builder notes of the plan (section 9 on the branch), `docs/web/load.md`, and the code, and I ran the unit tests (161 pass). CI passes on `a4210ce` (Test run 454, Export run 261).

My workspace cannot open `workers.dev`, and it has no export templates, so I did not open the web build and I did not make it. The numbers of the web build in this report are those of the builder. The numbers of the files are mine.

## 2. What is done

| Item | State |
|---|---|
| R1: the measures as a phone | Done. `tools/web/check.js --measure` writes the tables of `docs/web/load.md`. |
| R2: the web pack leaves out the near levels of the buildings and `data/geo/raw` | Done, with `tools/web/check_pack.py` (the deploy fails on a file that must be out) and `tests/unit/test_web_pack.gd`. |
| R3: the compact form of the build data | Done as gzip copies that only the web build reads. A computer reads the JSON as before. |
| R4: the test of a second pack, and the packs | The test is done in Chromium: it works when the game keeps the download in memory and writes the file itself (`HTTPRequest.download_file` writes 0 bytes on the web). One pack is made: `people`. The stop of the game when a pack loads is not measured (see D-0031-03). No test in Firefox or Safari: the workspace has neither. Chrome on my Pixel 10 is the reference, so that is not a defect. |
| R5 (threads), R6 (the loading screen) | Not started: steps 3 and 4. |
| R7: the hash in the names | In part: the files are under the commit of the build, with a cache time of one year. |
| R8: the measure of the people (D9) | Not done by the builder. I measured it (section 4). |
| R9: the deploy removes old builds | Not done. |
| R10: AGENTS.md | Done. |
| PT-85 | Made. The first move passes at each start. The ride of 300 m does not end in the workspace (0.4 frames a second), so PT-85 fails there on the ride only. |

## 3. The numbers of the builder against the targets

At 25 Mbit/s, 720 × 1280, an empty cache, the processor four times slower:

| | Base line | Step 1 | Step 2 | Target (D10) |
|---|---|---|---|---|
| Over the network before the first frame | 331 MB | 199.5 MB | 122.4 MB | 40 MB |
| First frame | 192 s | 144 s | 115 s | 20 s |
| The player can move | 326 s | 271 s | 255 s | 40 s |
| With the cache: the player can move | 313 s | 256 s | 195 s | 15 s |
| The page at the first frame | 1 923 MB | 1 711 MB | 1 407 MB | 700 MB |

The download is 2.7 times smaller, and the second visit downloads nothing before the first frame. But each target is far.

## 4. Findings

### D-0031-01: The times of the workspace do not tell the time on a phone (high)

The workspace has no graphics chip. Chromium draws there with SwiftShader, at 0.4 to 0.6 frames a second. The world builds its parts some in each frame: the showcase 8 ms of work in each frame (`VungTau.SHOWCASE_FRAME_MS`), and one chunk, one patch, or one far tile in each frame (AGENTS.md, section 5c). So in the workspace the time from the first frame to "the player can move" (about 130 s of the 255 s) is the count of the frames times 2 s for each frame. A phone that draws 30 frames a second does the same frames in some seconds. The other way is also true: a phone can be slower than the workspace in the parts that the processor does.

So nobody knows now how long my phone waits. Two things follow:

- I must see the times on my phone, with no stopwatch (D11).
- While the player cannot move, the world must build with all the time of each frame, not with 8 ms (D12). Then a slow frame rate does not make the wait long, on a phone and in the workspace.

### D-0031-02: The import makes the people three times larger (high)

The pack `people` is 93.4 MB (81.3 MB with Brotli). I compared the files of World with the scenes that Godot makes from them:

| Files | From World (GLB) | After the import (scene) |
|---|---|---|
| The people, mid level (20) | 24.5 MB | 57.7 MB |
| The people, far level (20) | 5.9 MB | 35.7 MB |
| The other models, near, mid, and far | 118.9 MB | 115.3 MB |

`tools/world/fetch.py` writes `gltf/embedded_image_handling=3` in each import file: the pictures of a model go into its scene with no compression. A person has pictures (the skin, and the baked picture of the far level); the other models have almost none. So the pack `people` can be about 30 MB with the pictures kept small, and less with pictures that the graphics chip keeps compressed (Basis Universal): these also take less memory. The plan has D13 for this.

The newest World also gives a set of people with one shared picture (12 people at the mid level: 16.6 MB as single files, 6.4 MB as a set; report 0009, section 10.5a). That comes with the plan that takes the new World, not with this plan.

### D-0031-03: A pack stays in the memory of the page, and the memory after the ride is 2 449 MB (high)

The file system of the web build is in the memory of the page. The game keeps the download of a pack in memory, writes it to `user://packs/`, and loads it. The file stays there as long as the page is open, and its resources are loaded too. The builder measured 1 407 MB at the first frame and 2 449 MB at the end of the ride of PT-85, with the people there. The write and the load of the pack are in one frame, and no measure gives the length of that frame (R4 asks for it).

Two more things to check, which I did not see in the code or the notes:

- Godot keeps `user://` in the storage of the browser (IndexedDB) and reads it into memory at each start. If that is so for `user://packs/`, the second visit reads 93 MB into memory before the first frame, and then downloads the pack again, because `WebPacks` does not look for a file that is there.
- A pack comes over the network again at each visit unless the cache of the browser keeps it.

The plan has D15 and D16 for this.

### D-0031-04: The cache of the browser does not keep a large file (medium)

The builder found it: Chromium kept the start pack of 114 MB, but not the pack of 191 MB of step 1. A phone has a smaller cache, so I do not know if my phone keeps 114 MB. The second visit must not depend on that (D15).

### D-0031-05: The start pack is three times its target (medium)

The start pack is 121.8 MB: 49.6 MB of textures, 27.8 MB of near levels of the things of the showcase, 22 MB of mid levels, 13.2 MB of build data. At 25 Mbit/s that is 39 s of download: the first frame cannot come in 20 s. The builder asks for a decision: the start pack can lose the models of the showcase only if the first frame shows less. That is Q5 of the plan (D14).

## 5. What is good

- Each number of the builder has its build, its command, and its table. I can compare the steps.
- The test of the second pack found a real fault of Godot on the web (`download_file` writes 0 bytes) and a way that works.
- The game reads a pack in parts of 4 MiB: the pack `people` takes about 20 frames, not 1 240.
- The checks of the pack run at each deploy.

## 6. My look on my phone (2026-11-26)

After this audit the report of the builder came to me, and I opened the build of step 2 on my Pixel 10: the loading screen took about 20 s, and then the street was ready after about 5 s more. I did not note the connection (at home I have fiber) or if the cache was empty.

| | The workspace of the builder (25 Mbit/s) | My phone |
|---|---|---|
| To the first frame | 115 s | about 20 s |
| From the first frame until I can ride | 140 s | about 5 s |

What follows:

- D-0031-01 is confirmed: the times of the workspace are not the times of the phone. The report of the builder also says that an old Godot process used two processors of its workspace during the measures, so its times are slower again.
- On my phone the wait after the first frame is short. The wait before the first frame is the main part. On a fast connection it is mostly the work of the phone (the compile, the start of the engine, the build of the world); at 25 Mbit/s the download of 122 MB adds about 39 s.
- So the order of the next work changes: first the times on the screen (D11), then the size of the first download (D13, D14) and the packs that the page keeps (D15), then the loading screen and the load by time (D7, D12) and the memory (D16). The threads (D6) come last, and only if the parts of D11 on my phone show that the build of the world is a large part of the start.

## 7. What is open

- On my phone I did not yet look at the second visit, at the moment when the people come (a stop of the game), and at the turn with the thumb far to the side.
- Q5 of the plan (the far levels first).
- The changes D11 to D16 of the plan wait for my approval.
