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

## Item 1 (D11): the line of the times and the parts of the start (e1e8ded33e6e). No old Godot process (2026-11-26)

`https://9809ba89-vung-tau.fifo.workers.dev/?start=bai_truoc&ride`, the processor 4 times slower. A value in bold is over its target of D10 (at 25 Mbit/s).

| Size | Network | Cache | Over the network before the first frame | First frame | Can move | Heap of the engine | JavaScript heap | Page (renderer + GPU) | Parts: download / compile / engine / world / move |
|---|---|---|---|---|---|---|---|---|---|
| 720 × 1280 | 25 Mbit/s | empty | **122.4 MB** | **102 s** | **196 s** | 344 MB | 255 MB | **1409 MB** | 47.3 / 5.4 / 5.1 / 46.5 / 95.3 s |
| 720 × 1280 | 25 Mbit/s | with the cache | 0 MB | **59 s** | **155 s** | 344 MB | 254 MB | **1395 MB** | 4.6 / 2.7 / 5.2 / 45.7 / 97.2 s |
| 720 × 1280 | 100 Mbit/s | empty | 122.4 MB | 73 s | 169 s | 344 MB | 255 MB | **1411 MB** | 18.9 / 1.9 / 5.4 / 45.9 / 97.5 s |
| 720 × 1280 | 100 Mbit/s | with the cache | 0 MB | 61 s | 169 s | 344 MB | 254 MB | **1397 MB** | 4.7 / 1.9 / 5.4 / 47.6 / 109.5 s |
| 2400 × 1080 | 25 Mbit/s | empty | **122.4 MB** | **115 s** | **358 s** | 344 MB | 255 MB | **1495 MB** | 49.3 / 5.5 / 5.8 / 51.3 / 246.4 s |
| 2400 × 1080 | 25 Mbit/s | with the cache | 0 MB | **72 s** | **314 s** | 344 MB | 254 MB | **1484 MB** | 8.5 / 2.4 / 6 / 50.2 / 245.1 s |
| 2400 × 1080 | 100 Mbit/s | empty | 122.4 MB | 80 s | 317 s | 344 MB | 255 MB | **1497 MB** | 19 / 1.7 / 5.1 / 48 / 236.1 s |
| 2400 × 1080 | 100 Mbit/s | with the cache | 0 MB | 71 s | 311 s | 344 MB | 254 MB | **1487 MB** | 8.2 / 1.2 / 5.5 / 48.9 / 243 s |

## The measure of D13: the pictures of the people (2026-11-26)

`tools/web/people_forms.gd` (the renderer of the web build, Compatibility, in the workspace) with the 40 scenes of the pack `people` (the mid and far levels of 20 people), for each form of `gltf/embedded_image_handling`. The pack is made with `tools/web/make_pack.gd` and compressed with `tools/web/compress.js`.

| Form | The pack | The pack with Brotli | The imported scenes | The load of the 40 scenes | The memory of their textures |
|---|---|---|---|---|---|
| Now: no compression (3) | 93.4 MB | 81.3 MB | 93.3 MB | 0.7 s | 262.8 MB |
| Basis Universal (2) | 56.8 MB | **16.7 MB** | 56.7 MB | 1.2 s | **79.2 MB** |
| Small lossy pictures (1: the pictures out of the scenes, WebP, quality 0.7, with mipmaps) | 17.1 MB | 9.3 MB | 9.7 MB (and 100 picture files) | 1.1 s | 256.2 MB |

walker_1 at 5 m, in the light of noon (the mid level, then the far level), in each form: I see no loss in Basis Universal or in the lossy form.

![walker_1 at 5 m in each form](d13_walker_1_5m.png)

**My choice: Basis Universal**, on the web and on a computer (one import for all platforms; the look at 5 m is the same). The lossy form is 7.4 MB smaller over the network (about 2.4 s at 25 Mbit/s), but the engine keeps its pictures with no compression in the memory of the graphics (256 MB against 79 MB): the memory is the target of D16. It also puts 100 picture files of Godot in `assets/world/` (plan 0023 keeps only the files of World there). `tools/world/fetch.py` writes the import of a person with Basis Universal (`import_params()`); the other models keep their import.

## Item 1 again, with the people (before item 2; e1e8ded33e6e). No old Godot process (2026-11-26)

`https://9809ba89-vung-tau.fifo.workers.dev/?start=bai_truoc&ride`, the processor 4 times slower. A value in bold is over its target of D10 (at 25 Mbit/s).

| Size | Network | Cache | Over the network before the first frame | First frame | Can move | Heap of the engine | JavaScript heap | Page (renderer + GPU) | Parts: download / compile / engine / world / move | The people there: time, page, heap of the engine |
|---|---|---|---|---|---|---|---|---|---|---|
| 720 × 1280 | 25 Mbit/s | empty | **122.4 MB** | **105 s** | **206 s** | 344 MB | 255 MB | **1412 MB** | 46.9 / 5.3 / 5.4 / 49.7 / 101 s | 316 s, 2288 MB, 713 MB |
| 720 × 1280 | 25 Mbit/s | with the cache | 0 MB | **59 s** | **160 s** | 344 MB | 254 MB | **1394 MB** | 5.1 / 2.2 / 4.9 / 45.5 / 100.9 s | 392 s, 2302 MB, 713 MB |

## Item 2 (D13): the pictures of the people with Basis Universal (d548ae950ce8). No old Godot process (2026-11-26)

`https://51a0d3af-vung-tau.fifo.workers.dev/?start=bai_truoc&ride`, the processor 4 times slower. A value in bold is over its target of D10 (at 25 Mbit/s).

| Size | Network | Cache | Over the network before the first frame | First frame | Can move | Heap of the engine | JavaScript heap | Page (renderer + GPU) | Parts: download / compile / engine / world / move | The people there: time, page, heap of the engine |
|---|---|---|---|---|---|---|---|---|---|---|
| 720 × 1280 | 25 Mbit/s | empty | **122.4 MB** | **114 s** | **211 s** | 344 MB | 255 MB | **1409 MB** | 52.7 / 5.8 / 6.7 / 50.9 / 97.8 s | 230 s, 2013 MB, 594 MB |
| 720 × 1280 | 25 Mbit/s | with the cache | 0 MB | **53 s** | **145 s** | 344 MB | 253 MB | **1400 MB** | 4.6 / 1.4 / 3.2 / 42.3 / 91.6 s | 169 s, 2004 MB, 495 MB |
| 720 × 1280 | 100 Mbit/s | empty | 122.4 MB | 78 s | 170 s | 344 MB | 255 MB | **1412 MB** | 19.2 / 1.7 / 5.6 / 49.6 / 92.7 s | 186 s, 2010 MB, 594 MB |
| 720 × 1280 | 100 Mbit/s | with the cache | 0 MB | 53 s | 143 s | 344 MB | 251 MB | **1412 MB** | 4.1 / 1.9 / 3 / 43 / 90.1 s | 158 s, 1990 MB, 495 MB |
| 2400 × 1080 | 25 Mbit/s | empty | **122.4 MB** | **107 s** | **347 s** | 344 MB | 255 MB | **1501 MB** | 47.4 / 5.2 / 5.4 / 46.8 / 238.4 s | 404 s, 2100 MB, 594 MB |
| 2400 × 1080 | 25 Mbit/s | with the cache | 0 MB | **66 s** | **317 s** | 344 MB | 253 MB | **1493 MB** | 8 / 2.2 / 3.7 / 46 / 247.5 s | 349 s, 2067 MB, 495 MB |
| 2400 × 1080 | 100 Mbit/s | empty | 122.4 MB | 81 s | 330 s | 344 MB | 255 MB | **1502 MB** | 18.8 / 1.7 / 5.5 / 48.9 / 247 s | 379 s, 2099 MB, 594 MB |
| 2400 × 1080 | 100 Mbit/s | with the cache | 0 MB | 60 s | 289 s | 344 MB | 251 MB | **1497 MB** | 7.3 / 1.7 / 3 / 42.4 / 231.4 s | 320 s, 2104 MB, 594 MB |

## Item 3 (D14): the far levels first (09cf5f9c3445). No old Godot process (2026-11-26)

`https://1e202e10-vung-tau.fifo.workers.dev/?start=bai_truoc&ride`, the processor 4 times slower. A value in bold is over its target of D10 (at 25 Mbit/s).

| Size | Network | Cache | Over the network before the first frame | First frame | Can move | Heap of the engine | JavaScript heap | Page (renderer + GPU) | Parts: download / compile / engine / world / move | The people there: time, page, heap of the engine |
|---|---|---|---|---|---|---|---|---|---|---|
| 720 × 1280 | 25 Mbit/s | empty | **94 MB** | **93 s** | **187 s** | 344 MB | 198 MB | **1300 MB** | 37.2 / 5.3 / 5.1 / 47.2 / 96.1 s | 401 s, 2295 MB, 608 MB |
| 720 × 1280 | 25 Mbit/s | with the cache | 0 MB | **51 s** | **143 s** | 344 MB | 561 MB | **2267 MB** | 4.1 / 1.8 / 3.6 / 40.7 / 91.3 s | 344 s, 2318 MB, 713 MB |
| 720 × 1280 | 100 Mbit/s | empty | 94 MB | 69 s | 158 s | 344 MB | 198 MB | **1299 MB** | 14.7 / 1.7 / 5.1 / 45.7 / 90 s | 431 s, 2432 MB, 713 MB |
| 720 × 1280 | 100 Mbit/s | with the cache | 0 MB | 52 s | 141 s | 344 MB | 563 MB | **2275 MB** | 4 / 1.7 / 3.6 / 41.5 / 88.8 s | 369 s, 2323 MB, 713 MB |
| 2400 × 1080 | 25 Mbit/s | empty | **94 MB** | **98 s** | **329 s** | 344 MB | 198 MB | **1394 MB** | 36.9 / 5.4 / 5.5 / 48 / 233.7 s | — |
| 2400 × 1080 | 25 Mbit/s | with the cache | 0 MB | **62 s** | **283 s** | 344 MB | 196 MB | **1374 MB** | 7.2 / 1.2 / 4.9 / 42.4 / 219.9 s | — |
| 2400 × 1080 | 100 Mbit/s | empty | 94 MB | 70 s | 302 s | 344 MB | 198 MB | **1393 MB** | 14.5 / 1.7 / 5 / 43.9 / 233.6 s | — |
| 2400 × 1080 | 100 Mbit/s | with the cache | 0 MB | 65 s | 286 s | 344 MB | 197 MB | **1380 MB** | 7 / 1.3 / 4.8 / 45.8 / 220.4 s | — |

## R15 before item 4: the build of item 3 (09cf5f9c3445) (2026-11-26)

R15: `https://1e202e10-vung-tau.fifo.workers.dev/?start=bai_truoc&ride`, 720 × 1280, 100 Mbit/s, a disk cache of 50 MB, two visits (each a new browser on the same profile; the second with no HTTP cache, as a phone). **Fail**: the second visit gets 204.5 MB of packs over the network.

| Visit | Packs over the network | All over the network | First frame | Can move | The pack people there |
|---|---|---|---|---|---|
| first | 204.5 MB | 212.5 MB | 63 s | 147 s | 374 s |
| second | 204.5 MB | 212.5 MB | 66 s | 152 s | 382 s |

## R15 after item 4 (df663736c421) (2026-11-26)

R15: `https://3e18add5-vung-tau.fifo.workers.dev/?start=bai_truoc&ride`, 720 × 1280, 100 Mbit/s, a disk cache of 50 MB, two visits (each a new browser on the same profile; the second with no HTTP cache, as a phone). Pass: the second visit gets 0 MB of packs over the network.

| Visit | Packs over the network | All over the network | First frame | Can move | The pack people there |
|---|---|---|---|---|---|
| first | 207.7 MB | 215.7 MB | 65 s | 144 s | 197 s |
| second | 0 MB | 8 MB | 50 s | 131 s | 160 s |

## Item 4 (D15): the page keeps the packs (df663736c421). No old Godot process (2026-11-26)

`https://3e18add5-vung-tau.fifo.workers.dev/?start=bai_truoc&ride`, the processor 4 times slower. A value in bold is over its target of D10 (at 25 Mbit/s).

| Size | Network | Cache | Over the network before the first frame | First frame | Can move | Heap of the engine | JavaScript heap | Page (renderer + GPU) | Parts: download / compile / engine / world / move | The people there: time, page, heap of the engine |
|---|---|---|---|---|---|---|---|---|---|---|
| 720 × 1280 | 25 Mbit/s | empty | **94 MB** | **86 s** | **168 s** | 344 MB | 206 MB | **1332 MB** | 38 / 5.3 / 4.2 / 40.7 / 83.8 s | 223 s, 1899 MB, 412 MB |
| 720 × 1280 | 25 Mbit/s | with the cache | 0 MB | **50 s** | **146 s** | 344 MB | 294 MB | **1283 MB** | 3.9 / 0.9 / 3.9 / 39.3 / 97.4 s | 152 s, 1949 MB, 412 MB |
| 720 × 1280 | 100 Mbit/s | empty | 94 MB | 65 s | 152 s | 344 MB | 206 MB | **1329 MB** | 16.1 / 1.6 / 4.2 / 41.9 / 86.6 s | 199 s, 1913 MB, 412 MB |
| 720 × 1280 | 100 Mbit/s | with the cache | 0 MB | 49 s | 141 s | 344 MB | 301 MB | **1286 MB** | 4.1 / 1 / 2.3 / 39.5 / 92.9 s | 148 s, 1941 MB, 412 MB |
| 2400 × 1080 | 25 Mbit/s | empty | **94 MB** | **89 s** | **295 s** | 344 MB | 206 MB | **1428 MB** | 37.9 / 5.3 / 4.2 / 40.5 / 208.4 s | 447 s, 2088 MB, 412 MB |
| 2400 × 1080 | 25 Mbit/s | with the cache | 0 MB | **57 s** | **283 s** | 344 MB | 294 MB | **1379 MB** | 6.5 / 0.9 / 4.1 / 40 / 215.6 s | 304 s, 2201 MB, 412 MB |
| 2400 × 1080 | 100 Mbit/s | empty | 94 MB | 68 s | 280 s | 344 MB | 206 MB | **1424 MB** | 16.1 / 1.6 / 4.1 / 41.5 / 210.3 s | 415 s, 1990 MB, 412 MB |
| 2400 × 1080 | 100 Mbit/s | with the cache | 0 MB | 57 s | 268 s | 344 MB | 294 MB | **1371 MB** | 6.3 / 1.2 / 4.3 / 39.5 / 214.2 s | 288 s, 2098 MB, 412 MB |

## Item 5 (D7, D12): the loading screen and the load by time (a0d368c1d8d8). No old Godot process (2026-11-26)

`https://14385bf5-vung-tau.fifo.workers.dev/?start=bai_truoc&ride`, the processor 4 times slower. A value in bold is over its target of D10 (at 25 Mbit/s).

| Size | Network | Cache | Over the network before the first frame | First frame | Can move | Heap of the engine | JavaScript heap | Page (renderer + GPU) | Parts: download / compile / engine / world / move | The people there: time, page, heap of the engine |
|---|---|---|---|---|---|---|---|---|---|---|
| 720 × 1280 | 25 Mbit/s | empty | **94.1 MB** | **86 s** | **140 s** | 344 MB | 206 MB | **1349 MB** | 37.8 / 5.1 / 4.2 / 41.2 / 54.7 s | 239 s, 1903 MB, 412 MB |
| 720 × 1280 | 25 Mbit/s | with the cache | 0 MB | **55 s** | **106 s** | 344 MB | 295 MB | **1293 MB** | 4.1 / 1 / 4.6 / 43.1 / 52.8 s | 173 s, 1843 MB, 412 MB |
| 720 × 1280 | 100 Mbit/s | empty | 94.1 MB | 66 s | 117 s | 344 MB | 206 MB | **1340 MB** | 16.3 / 1.5 / 4.5 / 41.9 / 53.1 s | 209 s, 1943 MB, 412 MB |
| 720 × 1280 | 100 Mbit/s | with the cache | 0 MB | 52 s | 106 s | 344 MB | 295 MB | **1295 MB** | 3.8 / 1 / 4.5 / 41.3 / 54.3 s | 172 s, 1875 MB, 412 MB |
| 2400 × 1080 | 25 Mbit/s | empty | **94.1 MB** | **94 s** | **211 s** | 344 MB | 206 MB | **1437 MB** | 38.7 / 5.1 / 4.7 / 43.3 / 120.5 s | 488 s, 2023 MB, 412 MB |
| 2400 × 1080 | 25 Mbit/s | with the cache | 0 MB | **56 s** | **176 s** | 344 MB | 294 MB | **1386 MB** | 6.8 / 0.9 / 4 / 38.9 / 118 s | 294 s, 1925 MB, 412 MB |
| 2400 × 1080 | 100 Mbit/s | empty | 94.1 MB | 67 s | 183 s | 344 MB | 206 MB | **1429 MB** | 16.3 / 1.5 / 4.4 / 39.9 / 114.3 s | 451 s, 2008 MB, 412 MB |
| 2400 × 1080 | 100 Mbit/s | with the cache | 0 MB | 63 s | 187 s | 344 MB | 294 MB | **1381 MB** | 7.3 / 1.2 / 4.3 / 44.3 / 122.3 s | 278 s, 1916 MB, 412 MB |

R6 (`check.js --loading`, the build `a0d368c1d8d8`): the loading screen at 1280 × 720, 2400 × 1080, and 720 × 1280 while the start pack downloads. At each size the screen goes at the first frame.

![The loading screen at 1280 × 720](r6_loading_1280x720.jpg)
![The loading screen at 2400 × 1080](r6_loading_2400x1080.jpg)
![The loading screen at 720 × 1280](r6_loading_720x1280.jpg)

## Item 6 (D16): the memory of the packs (3959b420ef61). No old Godot process (2026-11-26)

`https://11c7715a-vung-tau.fifo.workers.dev/?start=bai_truoc&ride`, the processor 4 times slower. A value in bold is over its target of D10 (at 25 Mbit/s).

| Size | Network | Cache | Over the network before the first frame | First frame | Can move | Heap of the engine | JavaScript heap | Page (renderer + GPU) | Parts: download / compile / engine / world / move | Page when the player can move | The pack models there: time, page, heap of the engine | The people there: time, page, heap of the engine |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 720 × 1280 | 25 Mbit/s | empty | **94.1 MB** | **94 s** | **155 s** | 344 MB | 206 MB | **1346 MB** | 39.3 / 5.4 / 4.7 / 46.3 / 63.3 s | 1564 MB | 202 s, 1752 MB, 344 MB | 252 s, 1928 MB, 412 MB |
| 720 × 1280 | 25 Mbit/s | with the cache | 0 MB | **49 s** | **101 s** | 344 MB | 294 MB | **1310 MB** | 4 / 1.3 / 2.5 / 40.1 / 53.2 s | 1505 MB | 108 s, 1579 MB, 344 MB | 148 s, 1834 MB, 412 MB |
| 720 × 1280 | 100 Mbit/s | empty | 94.1 MB | 67 s | 119 s | 344 MB | 295 MB | **1339 MB** | 17 / 1.7 / 4.4 / 42.8 / 53.3 s | 1536 MB | 165 s, 1699 MB, 344 MB | 212 s, 1906 MB, 412 MB |
| 720 × 1280 | 100 Mbit/s | with the cache | 0 MB | 53 s | 110 s | 344 MB | 295 MB | **1302 MB** | 4 / 1.3 / 4.4 / 41.8 / 58.1 s | 1488 MB | 124 s, 1662 MB, 344 MB | 148 s, 1808 MB, 412 MB |
| 2400 × 1080 | 25 Mbit/s | empty | **94.1 MB** | **92 s** | **214 s** | 344 MB | 206 MB | **1435 MB** | 38.2 / 5.2 / 4.3 / 42.6 / 121.3 s | 1661 MB | 359 s, 1846 MB, 344 MB | 500 s, 2031 MB, 412 MB |
| 2400 × 1080 | 25 Mbit/s | with the cache | 0 MB | **53 s** | **161 s** | 344 MB | 562 MB | **2050 MB** | 6.7 / 1.1 / 2.5 / 37.5 / 110.6 s | 2410 MB | 182 s, 2359 MB, 344 MB | 293 s, 2656 MB, 412 MB |
| 2400 × 1080 | 100 Mbit/s | empty | 94.1 MB | 69 s | 183 s | 344 MB | 206 MB | **1427 MB** | 16.3 / 1.6 / 4.5 / 41.2 / 117 s | 1654 MB | 322 s, 1845 MB, 344 MB | 454 s, 2028 MB, 412 MB |
| 2400 × 1080 | 100 Mbit/s | with the cache | 0 MB | 52 s | 161 s | 344 MB | 294 MB | **1385 MB** | 6.7 / 1 / 2.4 / 36.7 / 108 s | 1577 MB | 214 s, 1717 MB, 344 MB | 307 s, 1925 MB, 412 MB |

## Item 6 again (D16): the longest frame of each pack (a7ae6d138072). No old Godot process (2026-11-26)

`https://743a0648-vung-tau.fifo.workers.dev/?start=bai_truoc&ride`, the processor 4 times slower. A value in bold is over its target of D10 (at 25 Mbit/s).

| Size | Network | Cache | Over the network before the first frame | First frame | Can move | Heap of the engine | JavaScript heap | Page (renderer + GPU) | Parts: download / compile / engine / world / move | Page when the player can move | The pack models there: time, page, heap of the engine | The people there: time, page, heap of the engine |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 720 × 1280 | 25 Mbit/s | empty | **94.1 MB** | **86 s** | **137 s** | 344 MB | 206 MB | **1346 MB** | 37.9 / 5.3 / 4.2 / 41 / 52.4 s | 1540 MB | 182 s, 1772 MB, 344 MB, longest frame 283 ms (325 upgrades wait after 0 s) | 230 s, 1973 MB, 412 MB, longest frame 283 ms (215 upgrades wait after 61 s) |
| 720 × 1280 | 25 Mbit/s | with the cache | 0 MB | **49 s** | **100 s** | 344 MB | 295 MB | **1306 MB** | 4.1 / 1.1 / 4 / 38.7 / 51 s | 1533 MB | 111 s, 1622 MB, 344 MB, longest frame 283 ms (325 upgrades wait after 0 s) | 137 s, 1818 MB, 412 MB, longest frame 283 ms (261 upgrades wait after 61 s) |

## Item 6, last (D16 measure, D12 wait in the frame): 03a7bbc736ac. No old Godot process (2026-11-26)

`https://61988614-vung-tau.fifo.workers.dev/?start=bai_truoc&ride`, the processor 4 times slower. A value in bold is over its target of D10 (at 25 Mbit/s).

| Size | Network | Cache | Over the network before the first frame | First frame | Can move | Heap of the engine | JavaScript heap | Page (renderer + GPU) | Parts: download / compile / engine / world / move | Page when the player can move | The pack models there: time, page, heap of the engine | The people there: time, page, heap of the engine |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 720 × 1280 | 25 Mbit/s | empty | **94.1 MB** | **85 s** | **135 s** | 344 MB | 206 MB | **1349 MB** | 38 / 5.4 / 4.1 / 39.7 / 52 s | 1544 MB | 179 s, 1734 MB, 344 MB, longest frame 8691 ms (373 upgrades wait after 60 s) | 227 s, 1954 MB, 412 MB, longest frame 8691 ms (197 upgrades wait after 61 s) |
| 720 × 1280 | 25 Mbit/s | with the cache | 0 MB | **49 s** | **97 s** | 344 MB | 295 MB | **1314 MB** | 3.9 / 1 / 3.9 / 38.5 / 49.4 s | 1500 MB | 104 s, 1657 MB, 344 MB, longest frame 8796 ms (359 upgrades wait after 60 s) | 134 s, 1817 MB, 412 MB, longest frame 8796 ms (253 upgrades wait after 60 s) |
| 720 × 1280 | 100 Mbit/s | empty | 94.1 MB | 63 s | 113 s | 344 MB | 206 MB | **1341 MB** | 15.9 / 1.5 / 4.2 / 40.2 / 51.4 s | 1543 MB | 155 s, 1731 MB, 344 MB, longest frame 8308 ms (373 upgrades wait after 60 s) | 200 s, 1927 MB, 412 MB, longest frame 8308 ms (215 upgrades wait after 61 s) |
| 720 × 1280 | 100 Mbit/s | with the cache | 0 MB | 45 s | 92 s | 344 MB | 294 MB | **1302 MB** | 3.8 / 0.9 / 2.3 / 36 / 48.6 s | 1478 MB | 98 s, 1602 MB, 344 MB, longest frame 8418 ms (345 upgrades wait after 61 s) | 124 s, 1771 MB, 412 MB, longest frame 8418 ms (257 upgrades wait after 61 s) |
| 2400 × 1080 | 25 Mbit/s | empty | **94.1 MB** | **90 s** | **198 s** | 344 MB | 206 MB | **1435 MB** | 37.7 / 5.1 / 4.4 / 41.5 / 107.2 s | 1647 MB | 336 s, 1801 MB, 344 MB, longest frame 8279 ms (275 upgrades wait after 61 s) | 466 s, 2051 MB, 412 MB, longest frame 10875 ms (309 upgrades wait after 63 s) |
| 2400 × 1080 | 25 Mbit/s | with the cache | 0 MB | **50 s** | **151 s** | 344 MB | 301 MB | **1389 MB** | 6.8 / 0.9 / 2.3 / 34.7 / 103.9 s | 1588 MB | 207 s, 1749 MB, 344 MB, longest frame 7634 ms (275 upgrades wait after 63 s) | 287 s, 1925 MB, 412 MB, longest frame 10359 ms (409 upgrades wait after 62 s) |
| 2400 × 1080 | 100 Mbit/s | empty | 94.1 MB | 63 s | 164 s | 344 MB | 206 MB | **1430 MB** | 15.6 / 1.4 / 3.8 / 37.1 / 103.7 s | 1642 MB | 297 s, 1749 MB, 344 MB, longest frame 7411 ms (275 upgrades wait after 63 s) | 411 s, 1998 MB, 412 MB, longest frame 10335 ms (345 upgrades wait after 62 s) |
| 2400 × 1080 | 100 Mbit/s | with the cache | 0 MB | 51 s | 150 s | 344 MB | 295 MB | **1381 MB** | 6.1 / 1 / 3.8 / 34.8 / 98.5 s | 1738 MB | 169 s, 1688 MB, 344 MB, longest frame 7256 ms (275 upgrades wait after 62 s) | 255 s, 1967 MB, 412 MB, longest frame 9992 ms (359 upgrades wait after 62 s) |
