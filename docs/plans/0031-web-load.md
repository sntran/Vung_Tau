# 0031 The web build loads in steps

| Field | Value |
|---|---|
| Status | Approved (2026-11-25) |
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

## 6. Play-test scenarios

- **PT-85 `web_load`.** After each deploy, `tools/web/check.js` opens the page at `?start=bai_truoc&ride` and at `?start=hem` in Chromium, with an empty cache and a network of 50 Mbit/s: it waits for the first frame of the world, pushes the joystick with a real touch, and checks that the scooter (or the player) moves. It keeps a screenshot of the loading screen, of the first frame, and of the first move, with the times, the bytes, and the memory. It rides 300 m along Quang Trung and checks that the models of the showcase show (no stand-in in the frame at the end). A script error or an engine error in the console is a failure. A time or a size over its target of D10 is a failure after step 2.
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
