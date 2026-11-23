# 0029 Small Vũng Tàu: the illustrated map

| Field | Value |
|---|---|
| Status | Draft |
| Branch | `feat/0029-map`. The pilot (R1 to R4) can start from the branch of plan 0009 now; the whole map waits for the houses of phase 3 of plan 0009 (D9). |
| Depends on | 0003 (the apps of the phone), 0009 (the town, the houses, and R16: the web build on Cloudflare), 0018 (the scooter on the map). |
| Changes | 0030 (the app Maps gets the illustrated map in place of its plain map). |

## 1. Goal

An illustrated map of Vũng Tàu in 2019, drawn from the game's own 3D town, in the way of [Small SF](https://smallsf.com/about): a view from above at 45°, cut into tiles, and each tile drawn again by an image model in one style. It has two uses:

- a web page on Cloudflare where anyone can drag and zoom the town;
- the app Maps on the player's phone (plan 0030), with the place of the player.

## 2. Out of scope

- Live data. The game is in 2019; nothing on the map is live.
- Moving traffic, boats, and people on the map (after the plan of traffic).
- A turn of the map to other directions (each direction is a new set of tiles).

## 3. Decisions

| # | Decision | Why |
|---|---|---|
| D1 | The source is the game's own 3D world of 2019, not the 3D tiles of Google. | The policies of the Map Tiles API of Google do not allow offline use or a cache of the tiles, and the tiles show the town of today, not of 2019. |
| D2 | The view: orthographic, 45° down, in one direction, as Small SF. The pilot shows two directions, and I choose one. | One direction is one set of tiles. |
| D3 | A tile is a square of 256 m of the ground (a chunk of the world), rendered at 2048 px (about 0.125 m for each pixel, near the scale of Small SF). The tiles overlap their neighbors. | The play area has about 45 km² of land, so about 700 to 900 tiles with the coast. |
| D4 | Each tile is drawn again by an image model, with a prompt and a drawn neighbor as the reference of the style. The model and its key are mine, in the workspace only: no key in the repository or in a log. A tile that is all water is not sent to the model; it gets a painted sea. | The way of Small SF. Its model made towns on the water. |
| D5 | The cost: a high quality image of GPT Image 2 costs about $0.21 at 1 024 × 1 024 (more at larger sizes, with retries and the input image). For about 800 tiles that is a few hundred dollars. The tool writes the cost of each tile, and stops at a limit that I set. | I pay for each call. |
| D6 | The seams: each join between two tiles takes the path of least difference (often along a street or a roof line), and blends over 14 px on each side. | The way of Small SF. |
| D7 | The check of each drawn tile against its render: the roads, the coastline, and the outlines of the big buildings must stay where they are, and no building may stand on a road or on the water. A tile that fails is drawn again (at most three times), then it goes on a list for my review. | An image model makes up things; the map shows real places. |
| D8 | The names on the map come from `data/geo/landmarks.json`, in Vietnamese with all the diacritics. | Design rule "Real words". |
| D9 | The pilot first: a square of 3 × 3 tiles at Bãi Trước, one tile of Núi Nhỏ, one tile of the boxes of the town, and one tile of the sea, in three styles: painted, as Small SF; pixel art, as [Isometric NYC](https://www.oxen.ai/blog/isometric-nyc); and an illustrated render of the game itself with no image model (flat colors, outlines, and soft shade in the shaders of the render). I choose the style and the direction. The whole map comes after the houses of phase 3 are on the streets near Bãi Trước and chợ Xóm Lưới. | Less is made up when the 3D source has the houses. The third style costs nothing, makes up nothing, and can be made again each time the town changes; an image model costs money for each new drawing. |
| D10 | Two outputs: the whole map as a deep-zoom pyramid in the R2 bucket of `vung-tau`, with a viewer (OpenSeadragon) at a path of the Worker; and a smaller pyramid in the game (at most 25 MB) for the app Maps. | The web build is already 321 MB (plan 0009, R16). |

## 4. Requirements

- **R1.** `tools/map/render`: a scenario of Godot renders each tile of D2 and D3 from the world of the game (High, 12:00, `--weather=clear` of plan 0028 when it exists), with a list of the tiles and their places.
- **R2.** `tools/map/redraw.py`: the drawing of D4, with the prompt and the references in `data/map/`, the cost of each tile, a stop at the cost limit, and a restart that keeps the tiles that are done.
- **R3.** The seams of D6, and the pyramid of D10.
- **R4.** The checks of D7, with a sheet of each tile next to its render for my review (`docs/map/`).
- **R5.** The web page: the viewer, the deploy to the Worker `vung-tau`, the credits (the image model, OpenStreetMap under the ODbL, the data of the town), and a link to the game.
- **R6.** The app Maps of plan 0030 shows the illustrated map in place of its plain map, with the same dot of the player, the scooter that the player rode last (plan 0018), and the names of the places. Its light follows the hour (a tint at night).
- **R7.** AGENTS.md, section 5: the commands, the limits, and the URL of the map.

## 5. Play-test scenarios

- **PT-83 `map_app`.** At 2400 × 1080, 720 × 1280, and 1280 × 720: the player opens Maps, drags and zooms with real touches and with the mouse, closes it, walks 50 m, and opens it again: the dot moved by 50 m on the map. Screenshots of each state, in the day and at night.

## 6. Acceptance criteria

| # | Criterion |
|---|---|
| 1 | I approved the pilot (the style and the direction). |
| 2 | Each tile of land is drawn and passed its checks or my review; the seams do not show at each zoom. |
| 3 | The web page loads on a phone and on a computer, and PT-83 passes. |

## 7. Open questions

- **Q1.** Which image model, and what cost limit? (I answer after the pilot.)
  - Note (2026-11-23): Claude cannot draw the tiles. It does not make images ([Claude Help Center](https://support.claude.com/en/articles/9002504-can-claude-produce-images)). It can write the tools, and it can look at each drawn tile next to its render for the review of D7.
