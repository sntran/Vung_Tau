# The load of the web build (plan 0031)

Each step of plan 0031 is measured before and after (D2), with `tools/web/check.js --measure` (R1, D3): Chromium of the workspace as a phone (a touch screen, a mobile user agent, the processor four times slower, the screen 720 × 1280 and 2400 × 1080), with a limit on the network of 25 Mbit/s and of 100 Mbit/s (a latency of 40 ms), first with an empty cache and then again with the cache (a profile on the disk).

```sh
node tools/web/check.js "https://BRANCH-vung-tau.fifo.workers.dev/?start=bai_truoc&ride" OUT --measure --md=docs/web/load.md --step="NAME"
node tools/web/check.js "https://BRANCH-vung-tau.fifo.workers.dev/" OUT --pt85     # PT-85, after each deploy
```

The columns:

- **Over the network before the first frame**: the bytes of all the files of the page (compressed as they come) until the first frame of the world.
- **First frame**: from the start of the navigation to the first frame of the world (`window.vungTau.firstFrameMs`).
- **Can move**: until the player can move: the clock runs (the ground of the start is ready) and the scooter does not wait for the showcase (`window.vungTau.canMoveMs`, report 0018, D-0018-03).
- **Heap of the engine**: the memory of WebAssembly of Godot at the first frame. An iPhone gives a page about 300 MB to 500 MB only (plan 0031, D10).
- **JavaScript heap**: the heap of the page at the first frame (the files of the loader are there).
- **Page (renderer + GPU)**: the resident memory of the processes of Chromium for the page at the first frame (the renderer and the GPU process).

The targets of D10 (at 25 Mbit/s): at most 40 MB over the network before the first frame; the first frame at most 20 s after the page opens; the player can move at most 40 s after it (with the cache at most 15 s); the page at most 700 MB at the first frame.

The workspace draws WebGL 2 with SwiftShader (on the processor), and the throttle of the processor slows only the page, not SwiftShader: a phone with a graphics chip draws faster, and its processor can be slower than four times the workspace. The numbers are for the comparison of the steps; my look on the phone gives the real times.

## The test of D5: a second pack that the game downloads while it runs (2026-11-26)

`node tools/web/check.js URL OUT --packtest` opens the page with `?packtest`: after the first frame, the game downloads `packtest.pck` of its build (1.6 MB, made by `tools/web/make_pack.gd`), puts it in `user://`, loads it with `ProjectSettings.load_resource_pack()`, and makes the near level of the building `nha_mai_ngoi_cam` from it. The main pack of step 1 does not have that file (`scripts/web/pack_test.gd`).

| Build | Server | The way | Bytes that HTTPRequest counts | The file in `user://` | `load_resource_pack()` | The scene from the pack |
|---|---|---|---|---|---|---|
| Step 1 (`32feaeec2693`) | the Worker (Brotli) | HTTPRequest writes the file (`download_file`) | — (not given by that test) | 0 bytes | false | no |
| Step 1 (`32feaeec2693`) | a local server (no compression) | HTTPRequest writes the file (`download_file`) | — | 0 bytes | false | no |
| Step 2 code (local export) | a local server (no compression) | HTTPRequest writes the file (`download_file`) | 1 592 168 | 0 bytes | false | no |
| Step 2 code (local export) | a local server (no compression) | the body in memory, then FileAccess writes the file | 1 592 168 | 1 592 168 bytes | true (63 ms with the load of the scene) | yes, 1 mesh |
| Step 2 (`e2430eaea126`) | the Worker (Brotli) | HTTPRequest writes the file (`download_file`) | 1 592 168 | 0 bytes | false | no |
| Step 2 (`e2430eaea126`) | the Worker (Brotli) | the body in memory, then FileAccess writes the file | 1 592 168 | 1 592 168 bytes | true (66 ms with the load of the scene) | yes, 1 mesh |

The result: **it works in Chromium** (HeadlessChrome 157 of the workspace), with the body in memory and FileAccess. On the web, `HTTPRequest.download_file` of Godot 4.7.2 writes a file of 0 bytes, although the request counts all the bytes; the compression is not the cause (the same with a local server and no compression). `scripts/web/web_packs.gd` uses the way that works. The workspace has no Firefox and no Safari (a download of Firefox was not permitted in the workspace): the test in those browsers is not done. Chrome on a Pixel 10 is the reference (Q3).

## Base line: the build of part A, with the measures of R1 (98ff3d71277c) (2026-11-26)

`https://d7325705-vung-tau.fifo.workers.dev/?start=bai_truoc&ride`, the processor 4 times slower. A value in bold is over its target of D10 (at 25 Mbit/s).

| Size | Network | Cache | Over the network before the first frame | First frame | Can move | Heap of the engine | JavaScript heap | Page (renderer + GPU) |
|---|---|---|---|---|---|---|---|---|
| 720 × 1280 | 25 Mbit/s | empty | **331 MB** | **192 s** | **326 s** | 344 MB | 636 MB | **1923 MB** |
| 720 × 1280 | 25 Mbit/s | with the cache | 321.4 MB | **182 s** | **313 s** | 344 MB | 634 MB | **1913 MB** |
| 720 × 1280 | 100 Mbit/s | empty | 331 MB | 108 s | 239 s | 344 MB | 636 MB | **1926 MB** |
| 720 × 1280 | 100 Mbit/s | with the cache | 321.4 MB | 103 s | 231 s | 344 MB | 635 MB | **1913 MB** |

## Base line at 2400 × 1080 (98ff3d71277c) (2026-11-26)

`https://d7325705-vung-tau.fifo.workers.dev/?start=bai_truoc&ride`, the processor 4 times slower. A value in bold is over its target of D10 (at 25 Mbit/s).

| Size | Network | Cache | Over the network before the first frame | First frame | Can move | Heap of the engine | JavaScript heap | Page (renderer + GPU) |
|---|---|---|---|---|---|---|---|---|
| 2400 × 1080 | 25 Mbit/s | empty | **331 MB** | **197 s** | **537 s** | 344 MB | 637 MB | **2012 MB** |
| 2400 × 1080 | 25 Mbit/s | with the cache | 321.4 MB | **193 s** | **513 s** | 344 MB | 634 MB | **1998 MB** |
| 2400 × 1080 | 100 Mbit/s | empty | 331 MB | 110 s | 432 s | 344 MB | 636 MB | **2011 MB** |
| 2400 × 1080 | 100 Mbit/s | with the cache | 321.4 MB | 108 s | 433 s | 344 MB | 634 MB | **2002 MB** |

## Step 1: the cuts and the compression (32feaeec2693) (2026-11-26)

`https://8d365a1b-vung-tau.fifo.workers.dev/?start=bai_truoc&ride`, the processor 4 times slower. A value in bold is over its target of D10 (at 25 Mbit/s).

| Size | Network | Cache | Over the network before the first frame | First frame | Can move | Heap of the engine | JavaScript heap | Page (renderer + GPU) |
|---|---|---|---|---|---|---|---|---|
| 720 × 1280 | 25 Mbit/s | empty | **199.5 MB** | **144 s** | **271 s** | 344 MB | 434 MB | **1711 MB** |
| 720 × 1280 | 25 Mbit/s | with the cache | 191.5 MB | **135 s** | **256 s** | 344 MB | 432 MB | **1715 MB** |
| 720 × 1280 | 100 Mbit/s | empty | 199.5 MB | 89 s | 210 s | 344 MB | 434 MB | **1712 MB** |
| 720 × 1280 | 100 Mbit/s | with the cache | 191.5 MB | 82 s | 208 s | 344 MB | 432 MB | **1698 MB** |
| 2400 × 1080 | 25 Mbit/s | empty | **199.5 MB** | **151 s** | **476 s** | 344 MB | 434 MB | **1800 MB** |
| 2400 × 1080 | 25 Mbit/s | with the cache | 191.5 MB | **146 s** | **477 s** | 344 MB | 432 MB | **1786 MB** |
| 2400 × 1080 | 100 Mbit/s | empty | 199.5 MB | 97 s | 446 s | 344 MB | 434 MB | **1797 MB** |
| 2400 × 1080 | 100 Mbit/s | with the cache | 191.5 MB | 103 s | 455 s | 344 MB | 432 MB | **1787 MB** |

## Step 2: the start pack and the pack of the people (e2430eaea126) (2026-11-26)

`https://f69165a5-vung-tau.fifo.workers.dev/?start=bai_truoc&ride`, the processor 4 times slower. A value in bold is over its target of D10 (at 25 Mbit/s).

| Size | Network | Cache | Over the network before the first frame | First frame | Can move | Heap of the engine | JavaScript heap | Page (renderer + GPU) |
|---|---|---|---|---|---|---|---|---|
| 720 × 1280 | 25 Mbit/s | empty | **122.4 MB** | **115 s** | **255 s** | 344 MB | 255 MB | **1407 MB** |
| 720 × 1280 | 25 Mbit/s | with the cache | 0 MB | **63 s** | **195 s** | 344 MB | 254 MB | **1395 MB** |
| 720 × 1280 | 100 Mbit/s | empty | 122.4 MB | 80 s | 218 s | 344 MB | 255 MB | **1407 MB** |
| 720 × 1280 | 100 Mbit/s | with the cache | 0 MB | 62 s | 203 s | 344 MB | 254 MB | **1399 MB** |
| 2400 × 1080 | 25 Mbit/s | empty | **122.4 MB** | **126 s** | **478 s** | 344 MB | 255 MB | **1498 MB** |
| 2400 × 1080 | 25 Mbit/s | with the cache | 0 MB | **73 s** | **398 s** | 344 MB | 254 MB | **1485 MB** |
| 2400 × 1080 | 100 Mbit/s | empty | 122.4 MB | 87 s | 439 s | 344 MB | 255 MB | **1498 MB** |
| 2400 × 1080 | 100 Mbit/s | with the cache | 0 MB | 74 s | 431 s | 344 MB | 254 MB | **1488 MB** |

## PT-85 after each deploy (2026-11-26)

`node tools/web/check.js URL OUT --pt85`: Chromium as a computer (1280 × 720), 50 Mbit/s, an empty cache. SwiftShader of the workspace draws 0.4 to 0.6 frames a second here, so the ride of 300 m does not end in the time of the test.

| Build | Start | First frame | Can move | First move | Ride | The pack people | Errors |
|---|---|---|---|---|---|---|---|
| Step 1 (`32feaeec2693`) | `bai_truoc&ride` | 59 s | 179 s | 1.26 m | 85 m in 600 s | — | none |
| Step 1 (`32feaeec2693`) | `hem` | 61 s | 125 s | 1.16 m | — | — | none |
| Step 2 (`f416161ee448`) | `bai_truoc&ride` | 44 s | 171 s | 1.26 m | 258 m in 1500 s | there at the end (`waiting` 0) | none |
| Step 2 (`f416161ee448`) | `hem` | 44 s | 109 s | 1.16 m | — | — | none |
