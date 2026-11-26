# 0031 The web build loads in steps

| Field | Value |
|---|---|
| Status | In progress. Approved (2026-11-25). After steps 1 and 2 (report 0031): D11 to D16 and R11 to R16 are added, and I approved them (2026-11-26). |
| Branch | `feat/0031-web-load`, made from `feat/0018-scooter` (the newest branch of the town). |
| Depends on | 0009 (R16: the web build on Cloudflare, and its measures), 0018 (the ride that needs the world at once), 0023 (the files of the models of World). |
| Changes | 0009 (R16: the files of the web build and the deploy), 0004 (the quality presets of the web build), AGENTS.md section 5 (the web build). |

## 1. Goal

I open the web build, and I ride in a short time. The page gets first only what the start needs. It gets the rest while I play. A phone can open the page.

On 2026-11-25 I opened the web build of plan 0018 on my computer. The loading screen of Godot took about one minute. Then I could not ride, because the world was not ready.

## 2. Out of scope

- Another engine, and a game that a server draws (D1).
- The desktop builds and the apps of Android and iOS: they keep one pack.
- A change of the look of the game on a computer.
- The illustrated map of plan 0029.

## 3. What the builder measured (plan 0009, R16, 2026-11-23)

- The pack is 321.1 MB, and `index.wasm` is 39.5 MB. Godot gets the whole pack before the first frame and keeps it in the memory of the page.
- In the pack: the scenes of the models of World 227.5 MB (the buildings: near 78.6, mid 14.8, far 1.7; the people: mid 57.7, far 35.7; the other things: near 29.4, mid 7.1, far 2.5), the textures 49.6 MB, `data/geo/build` 34.5 MB of JSON, `data/geo/raw` 4.4 MB that the game does not read.
- In Chromium of the workspace, from Cloudflare: the first frame of the world after 29 s to 30 s, and the ground of the start ready after 81 s to 85 s. The memory of the page at the first frame: 1.13 GB to 1.25 GB.
- The web build starts on Low (`scripts/quality.gd`). On Low a building of World does not show its near level.

## 4. Decisions

| # | Decision | Why |
|---|---|---|
| D1 | The game stays in Godot (my decision, 2026-11-25). | The slow load comes from one file of 321 MB, most of which the start does not need. An engine made for the web gets its files one by one, but the change is a new game: about 20 000 lines of code, the shaders, and 58 play tests, and it loses the desktop builds, which are the main platform (plan 0004, D1). A game that a server draws needs a graphics computer for each player. |
| D2 | The work is in steps. Each step is measured before and after, deployed, and reported. A step that does not help is not kept. | Some steps are not sure in Godot on the web (D5). |
| D3 | The measure is as a real player on a phone gets it: `tools/web/check.js` opens the page as a phone (720 × 1280 and 2400 × 1080, a touch screen, the processor four times slower), with a limit on the network of 25 Mbit/s and of 100 Mbit/s, with an empty cache, and then again with the cache. It gives the bytes over the network before the first frame, the time to the first frame of the world, the time until the player can move, and the memory of the page (the heap of the engine, and all of the page). | I test on my phone most of the time (Q1). The median 5G download of the fastest network of the United States was 314 Mbit/s in the first half of 2026, but only 79 % of its 5G samples had 25 Mbit/s or more ([Ookla, by IEEE ComSoc](https://techblog.comsoc.org/2026/07/23/highlights-from-ooklas-u-s-speedtest-connectivity-report-mobile-fixed-networks/)). The workspace gets the pack at 47 MB/s. |
| D4 | Step 1, the cuts that do not change what the web build shows on Low: the web pack has no near level of a building of World, and no file of `data/geo/raw`. The data of `data/geo/build` that the game reads goes in a compact form, or in files for each chunk. Each large file goes over the network compressed (Brotli or gzip), also from R2. | These are about 110 MB of the download: 83 MB that the web build does not use, and JSON that is five times smaller when it is compressed. |
| D5 | Step 2, the packs. First a test: a second pack that the game downloads while it runs (to `user://`, then `ProjectSettings.load_resource_pack()`), in the web build of Godot 4.7.2, in Chromium, Firefox, and Safari. If it works: a start pack (the code, the screens, the ground and the roads, and what shows within 300 m of each start point at its first frame), and a pack for each area and each kind (the showcase of Bãi Trước, the people, each street of phase 3, the test street). The game gets a pack when the player comes near its area, and shows the stand-ins until then. If it does not work, the builder tells me what it measured and proposes another way (for example, loose files that the game loads from `user://`). | Reports of other projects do not agree on this function in a web build. |
| D6 | Step 3, the threads. The web build has thread support, and the Worker sends the two headers that a page needs for it (`Cross-Origin-Opener-Policy: same-origin`, `Cross-Origin-Embedder-Policy: require-corp`). The world then builds its chunks, its town, and its models in the worker threads, as on a computer. If Safari on an iPhone does not start with threads, the builder tells me before a change. | With no threads, the main thread builds the whole world: about 50 s after the first frame in the workspace. |
| D7 | Step 4, the loading screen. The page shows a picture of the game, the name "Vũng Tàu", and the part of the load that is done, not the default screen of Godot. In the game, the player can move when the ground, the roads, and the parts within 150 m of the start are ready. The rest comes while the player moves, with no frame longer than the limit of plan 0018 (R9). | A player who sees the progress waits with more patience, and a player who can move does not wait. |
| D8 | The files of each build have their hash in their name, and the cache time is one year (as now for the pack). A new build downloads only the packs that changed. | The second visit starts fast. |
| D9 | The people (93.4 MB) are the largest part after the buildings. The builder measures what a far level as a card, or pictures that the people share, saves. A change in World is a request to World that I approve. | Each person has pictures of its own, of about 0.85 MB. |
| D10 | The targets, on a phone with 5G (Q1), with the measure of D3 at 25 Mbit/s: at most 40 MB over the network before the first frame (13 s of download); the first frame of the world at most 20 s after the page opens; the player can ride at most 40 s after the page opens; with the cache, at most 15 s. The memory of the page at the first frame: at most 700 MB. My phone is an Android phone (Q3). An iPhone is not a target now: there a page of WebAssembly can count on about 300 MB to 500 MB only ([WebKit bug 269777](https://bugs.webkit.org/show_bug.cgi?id=269777) of 2024), so the builder also gives the heap of the engine in each measure. The builder tells me after step 1 and step 2 if a target is out of reach. After each step I open the page on my phone and tell the builder what I see: the workspace has no phone. | A target makes each step a pass or a fail. Now the page has 1.13 GB to 1.25 GB at the first frame. |
| D11 | Added (2026-11-26; I approved it). The times on the screen. After the player can move, the game shows one line at the top for 20 s, and the Settings app of the phone shows the same line: the megabytes over the network before the first frame, the seconds to the first frame, the seconds until the player can move, the frames each second, and the memory of the page if the browser gives it. A build of a branch shows the line always; the build of `main` shows it with `?times`. The game also keeps the time of each part of the start (the download, the compile of the WebAssembly, the start of the engine, the build of the world to the first frame, the first frame to "can move") in `window.vungTau`, and `check.js` writes them to `docs/web/load.md`. | The workspace draws 0.4 frames a second with no graphics chip, and the world builds by frames: its times do not tell the time on my phone (report 0031, D-0031-01). I read the line on my phone and send a screenshot. The parts show where the time goes. |
| D12 | Added (2026-11-26; I approved it). The load goes by time, not by frames. While the player cannot move (before the first frame, and while the start is not ready), the world builds what the start needs (D7: the ground, the roads, and the parts within 150 m) with all the time of each frame: at least 100 ms of work in each frame, with a frame between for the progress on the screen. When the player can move, the world builds the rest with the small part of each frame, as now. | Now the showcase gets 8 ms in each frame, and the ground one chunk in each frame. On a slow frame rate the wait is the count of the frames, not the work. |
| D13 | Added (2026-11-26; I approved it). The pictures of the people stay compressed. The builder measures, for the people on the web, the import with the pictures as Basis Universal and as small lossy pictures against the import of now (no compression): the size of the pack, the time of its load, the memory of the page with the people there, and the look on the sheets of PT-56 at the mid and the far level. The web build takes the smallest form with no loss that I can see at 5 m. A computer keeps its import unless the same form is also good there. | The import makes the people three times larger: 30.4 MB of files of World are 93.4 MB of scenes (report 0031, D-0031-02). |
| D14 | Added (2026-11-26; I approved it). The far levels first. The start pack has, of each model of World, only its far level (and the stand-ins as now). The mid levels, and the near levels of the things, are in packs of their areas; the game gets the pack of the start area right after the first frame, the nearest models first, and each model changes to its better level when it is there. The textures of the look that only a better level uses go with those packs. | The start pack is 121.8 MB, and its target is 40 MB. The far levels of all models are about 10 MB of files of World (the people with their pictures compressed, D13). |
| D15 | Added (2026-11-26; I approved it). The page keeps the packs. The page (not the engine) downloads the start pack and each other pack, shows the progress, and keeps each in the Cache Storage of the browser under its name with the hash (D8). At the next visit it takes them from there, with no request for the file. It removes the packs of older builds. No pack is larger than 50 MB over the network. If the loader of Godot cannot take the start pack from the page, the builder tells me before another way. | Chromium does not keep a large file in its HTTP cache, and a phone has a smaller cache (report 0031, D-0031-04). Now the game downloads the pack `people` again at each visit. |
| D16 | Added (2026-11-26; I approved it). The memory of the packs. The builder measures the heap of the engine, the JavaScript heap, and the page before and after each pack, and the longest frame while a pack loads. A pack must not stay in memory two times (its file and its loaded resources), and `user://packs/` must not come into memory at the start of the next visit. If a pack of Godot cannot do that, the game gets its later models as single files that it deletes after their load, and the builder tells me what it measured. New target: the page at most 1 000 MB at the end of the ride of PT-85. | The page has 1 407 MB at the first frame and 2 449 MB at the end of the ride of PT-85 (report 0031, D-0031-03). |

## 5. Requirements

- **R1.** `tools/web/check.js` gives the measures of D3, with the limits on the network, and writes them to `docs/web/load.md` (a table for each step, before and after).
- **R2.** The web preset of the export keeps out the files of D4. A unit test or a check of the export fails when a near level of a building or a file of `data/geo/raw` is in the web pack. On each preset of the web build, a building of World shows its mid level also from near (Q2).
- **R3.** The compact form of the build data of D4, with no change of what the game reads on a computer. The time of the start of the world on a computer does not get longer (PT-37).
- **R4.** The test of D5, with its result in `docs/web/load.md`. Then the packs of D5, the list of the packs with their areas in data (`data/web/packs.json`), and the load of a pack while the game runs, with no stop of the game longer than the limit of plan 0018 (R9).
- **R5.** The threads of D6, with the headers in `tools/web/worker.js`.
- **R6.** The loading screen of D7, at 1280 × 720, 2400 × 1080, and 720 × 1280.
- **R7.** The names of the files and the cache of D8.
- **R8.** The measure of D9, in `docs/web/load.md`.
- **R9.** `tools/web/deploy.sh` deploys only to the Worker `vung-tau` and its R2 bucket, as in plan 0009 (R16). It removes the files of builds that are older than the last five.
- **R10.** AGENTS.md, section 5: the packs, the commands, the headers, and the measures.
- **R11.** Added (2026-11-26; I approved it). The line of the times and the parts of the start of D11. PT-85 checks that the line shows after the first move and takes its screenshot.
- **R12.** Added (2026-11-26; I approved it). The load by time of D12. A play test on a computer starts with `--ride` at 3 frames each second (`PLAYTEST_MAX_FPS=3`) and at the full frame rate: the wait from the first frame until the scooter can start, in real time, is at most 1.5 times as long at 3 frames each second. The longest frame after the player can move stays in the limit of plan 0018 (R9).
- **R13.** Added (2026-11-26; I approved it). The measure and the choice of D13, in `docs/web/load.md`, with a sheet of one walker at 5 m in each form.
- **R14.** Added (2026-11-26; I approved it). The packs of D14 (if I answer yes to Q5), with a play-test step: at the first frame each model of the start area shows a level (no hole), and after its pack is there each model within 40 m shows its mid level.
- **R15.** Added (2026-11-26; I approved it). The cache of D15. `check.js` opens the page two times with a disk cache of 50 MB: the second visit gets no pack over the network.
- **R16.** Added (2026-11-26; I approved it). The measures and the limit of D16, in `docs/web/load.md`. PT-85 fails over 1 000 MB at the end of its ride.

## 6. Play-test scenarios

- **PT-85 `web_load`.** After each deploy, `tools/web/check.js` opens the page at `?start=bai_truoc&ride` and at `?start=hem` in Chromium, with an empty cache and a network of 50 Mbit/s: it waits for the first frame of the world, pushes the joystick with a real touch, and checks that the scooter (or the player) moves. It keeps a screenshot of the loading screen, of the first frame, and of the first move, with the times, the bytes, and the memory. It rides 300 m along Quang Trung and checks that the models of the showcase show (no stand-in in the frame at the end). A script error or an engine error in the console is a failure. A time or a size over its target of D10 is a failure after step 2. (2026-11-26: the workspace draws 0.4 frames a second at 1280 × 720, so the ride of 300 m does not end there. The ride of PT-85 runs in a window small enough for the ride to end in 10 minutes; the builder gives the size.)
- The play tests of the other plans pass on a computer with no change.

## 7. Acceptance criteria

| # | Criterion |
|---|---|
| 1 | PT-85 passes, the unit tests and the other play tests pass, and CI is green. |
| 2 | I open the web build on my computer and on my phone, and I ride in the times of D10. |
| 3 | `docs/web/load.md` has the measures of each step. |

## 8. Open questions

- **Q1.** Which computer, which phone, and which connection are the reference for the targets of D10? (I answer.)
  - **My answer (2026-11-25):** my phone. I test there most of the time. My connection at home is fiber, but the page must be fast with 5G.
- **Q2.** On the web, a building of World shows its mid level also from near, on each preset. Is that good for the web build? (I answer. If not, the near levels are a pack of their own that only Medium and High get.)
  - **My answer (2026-11-25):** yes, that is good for now. The web pack has no near level of a building.
- **Q3.** Is my phone an iPhone or an Android phone? (I answer.) Chrome on Android gives a page much more memory than Safari on an iPhone, so the answer sets the memory target of D10.
  - **My answer (2026-11-25):** an Android phone, a Pixel 10, with Chrome.
- **Q4.** Do I also want the app on my phone for my tests (the Android build of CI as a file, or the iOS build with TestFlight, which needs a paid Apple Developer account)? (I answer.) An app starts from its own files in some seconds and uses the Mobile renderer, but I must get each new build.
  - **My answer (2026-11-25):** the web only, for now.
- **Q5.** (2026-11-26) May the first frame show the far level of each model near the start, and change each to its better level in the seconds after (D14)? (I answer.) The builder says that the start pack cannot come near 40 MB while it has the models of the showcase at their mid and near levels. If I say no, the start pack stays at about 120 MB (39 s of download at 25 Mbit/s), and the targets of D10 for the first visit change. The audit recommends yes: a street that gets sharp in some seconds is better than a wait of one minute.
  - **My answer (2026-11-26):** yes.

## 9. Builder notes (2026-11-26)

Steps 1 and 2 are done; steps 3 and 4 wait for my look on my phone. The web build of step 2: `https://feat-0031-web-load-vung-tau.fifo.workers.dev/?start=bai_truoc&ride` (the build `f416161ee448`, the version `https://1e651075-vung-tau.fifo.workers.dev`; the measures of step 2 are of `e2430eaea126`, with the same packs). The tables of each measure are in [`docs/web/load.md`](../web/load.md).

### R1: the measures (`tools/web/check.js --measure`)

- Chromium of the workspace as a phone (D3): 720 × 1280 and 2400 × 1080, a touch screen, a mobile user agent, the processor four times slower, 25 Mbit/s and 100 Mbit/s with 40 ms of latency, first an empty cache and then the cache (a profile on the disk). The heap of WebAssembly comes from a hook of `WebAssembly.instantiate`; the memory of the page is the resident memory of the renderer and the GPU process.
- The workspace draws WebGL 2 with SwiftShader (on the processor). The throttle of the processor slows only the page, not SwiftShader; PT-85 gets 0.4 to 0.6 frames a second at 1280 × 720. The times are for the comparison of the steps; the phone gives the real times.
- A cut of the network (a reset of the connection through the proxy of the workspace) stops an opening at once, and the measure tries once more with an empty cache; the row says so.

### The three measures at 25 Mbit/s, 720 × 1280, an empty cache

| | Base line (`98ff3d71277c`) | Step 1 (`32feaeec2693`) | Step 2 (`e2430eaea126`) | Target of D10 |
|---|---|---|---|---|
| Over the network before the first frame | 331 MB | 199.5 MB | 122.4 MB | 40 MB |
| First frame | 192 s | 144 s | 115 s | 20 s |
| Can move | 326 s | 271 s | 255 s | 40 s |
| With the cache: over the network / first frame / can move | 321.4 MB / 182 s / 313 s | 191.5 MB / 135 s / 256 s | 0 MB / 63 s / 195 s | — / — / 15 s |
| Page (renderer + GPU) at the first frame | 1923 MB | 1711 MB | 1407 MB | 700 MB |
| Heap of the engine at the first frame | 344 MB | 344 MB | 344 MB | — |

**The targets of D10 are out of reach after step 1 and step 2** (the numbers above, and all the rows in `docs/web/load.md`). The targets stay as they are.

### Step 1 (D4, R2, R3)

- `data/web/web.json` lists what the web pack leaves out: the near level of each of the 14 buildings of World (on the web the mid level shows also from near, Q2: `WorldModel.levels_of()` keeps the levels with a file, and a row of World starts such a mid level at 0 m), `data/geo/raw`, and the files of the build that the game does not read. The JSON of the build that the game reads goes as gzip copies (`GeoData.read_text()`; a computer reads the JSON). `tools/web/prepare.py` writes the filters of the preset Web and makes the copies; `tools/web/check_pack.py` fails the deploy when a near level of a building, a raw file, or a file of a pack is in the main pack (R2); `tests/unit/test_web_pack.gd` checks the list, the preset, and the reader.
- The pack, the wasm, and each pack go over the network as Brotli copies (`FILE.br`, quality 9; the Worker sends `Content-Encoding: br` and `Vary: Accept-Encoding`). The wasm goes from 39.5 MB to 7.9 MB; the pack from 215.2 MB to 191.5 MB (most of it is textures and meshes, which are compressed already).
- The pack: 321.4 MB → 215.2 MB.

### Step 2 (D5, R4)

- **The test of D5** (`?packtest`, `scripts/web/pack_test.gd`): it works in Chromium, with the body of the download in memory and FileAccess to `user://`, then `ProjectSettings.load_resource_pack()`. On the web, `HTTPRequest.download_file` of Godot 4.7.2 writes a file of 0 bytes, although the request counts all the bytes (also with no compression). The workspace has no Firefox and no Safari: a download of Firefox was not permitted in the workspace, so the test is in Chromium only.
- **The packs** (`data/web/packs.json`): the main pack is the start pack; the pack `people` has the mid and far levels of the walkers, the sitters, the swimmers, and the aerobics group (93.4 MB, 81.3 MB with Brotli), with the area of the showcase of Bãi Trước and 300 m around it. `tools/web/deploy.sh` makes each pack with `tools/web/make_pack.gd`; `scripts/web/web_packs.gd` downloads a pack when the player comes near its area, writes it to `user://packs/`, and loads it; the people of the showcase and of the morning exercise come when it is there. A computer keeps one pack (the files are there, and no pack waits). The start pack: 121.8 MB (114.4 MB with Brotli).
- On the web, HTTPRequest reads one part of the body in each frame, 64 KiB by default: the pack `people` took about 1240 frames. WebPacks reads parts of 4 MiB (about 20 frames).
- **The cache:** Chromium keeps no entry in its cache that is larger than a part of its disk cache. The pack of step 1 (191.5 MB) came again over the network on each visit; the start pack of step 2 (114.4 MB) stays in the cache (0 MB on the second visit). A phone has the same rule, with a smaller cache.
- **What is not a pack yet:** what stays in the start pack shows near the two start points (`bai_truoc` is in the showcase; `hem` is the hẻm): 49.6 MB of textures, 27.8 MB of near levels of the props (bins, benches, shades, hills), 22 MB of mid levels (the buildings of the showcase, the houses of Quang Trung), 13.2 MB of the data of the build. Plan 0009 phase 3 waits, so there are no streets of phase 3 to put in packs. To come nearer to 40 MB, the start pack must lose the showcase: the showcase then shows its stand-ins until its pack comes (`bai_truoc` starts in it). This is a change of what the web build shows at its first frame, so I did not make it; it needs a decision.

### PT-85 (`tools/web/check.js URL OUT --pt85`)

- After each deploy: `?start=bai_truoc&ride` and `?start=hem` at 50 Mbit/s with an empty cache, a real touch on the joystick (CDP), the first move, and a ride of 300 m along Quang Trung with the stick.
| Build | Start | First frame | Can move | First move | Ride | The pack people | Errors |
|---|---|---|---|---|---|---|---|
| Step 1 (`32feaeec2693`) | `bai_truoc&ride` | 59 s | 179 s | 1.26 m | 85 m in 600 s (0.4 frames a second) | — | none |
| Step 1 (`32feaeec2693`) | `hem` | 61 s | 125 s | 1.16 m | — | — | none |
| Step 2 (`f416161ee448`) | `bai_truoc&ride` | 44 s | 171 s | 1.26 m | 258 m in 1500 s (0.4 frames a second) | there at the end (`waiting` 0; 203.7 MB in all over the network) | none |
| Step 2 (`f416161ee448`) | `hem` | 44 s | 109 s | 1.16 m | — | — | none |

- The first move passes on each build, at each start (the stick held until the scooter or the player moves 1 m). The ride of 300 m does not end in the workspace: at 0.4 frames a second, 300 m takes more than 20 minutes (the ride has 1500 s now). So PT-85 fails on the ride only; the phone gives the real ride. At the end of the ride of step 2 the page has 2449 MB (the people are there); in the hẻm 1595 MB.
- At the first frame the game wrote a new `window.vungTau`, and the signals of the packs from before it were lost; the object now keeps them.

### The other corrections

- PT-80 run 2 failed in CI on a faster runner (also on `feat/0018-scooter`): a brake during the climb of a curb gave a bump. The correction is on `feat/0018-scooter` (plan 0018, section 8).
