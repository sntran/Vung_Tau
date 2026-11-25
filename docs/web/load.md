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
