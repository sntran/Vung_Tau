# Specs for World

Vũng Tàu gives World a **spec** for each model that it needs. World builds the model to the spec. World does not choose a size, a shape, a color, or a part of a model of this game: the spec gives them, and World asks when a value is not in the spec.

When World cannot build a spec with the rules that it has (for example a lamp with two curved arms, a pine with layers of flat branches, or swim clothes), World adds the rule as a general capability (a blueprint, a part, an option), with its tests, and then builds the spec with it. The rule is general; the values come from the spec.

## 1. The file

One file for each model: `data/world/specs/ID.json`. `ID` is the id of the model in `data/world/orders.json`.

| Field | Content |
|---|---|
| `id` | The id of the model in the game. |
| `what` | One line: what it is, in Vietnamese and English. |
| `uses` | Where the game uses it (the plan, the place, the count). |
| `year` | 2019. |
| `photos` | The photos that the values come from: `url`, `date`, `license`, `author`, `open` (true for CC0, CC BY, CC BY-SA, public domain), `file` (the copy in `docs/reference/photos/` for an open photo, R17 of plan 0026), and `shows`. |
| `envelope` | The size of the whole model: width (x), depth (y), and height (z) in meters, with a tolerance. The front of the model is −y. |
| `parts` | Each part: `name`, `shape` (a box, a cylinder, a profile, an arc, a sweep, or a part of World by its name), its sizes in meters, its place (from the base point of the model), its `count` and `spacing` when it repeats, its `role` (concrete, granite, plaster, paint, metal, glass, tile, wood, plant, cloth, skin, hair, emissive), and its `color` (sRGB). |
| `joints`, `ports`, `collision` | As World `docs/format.md` gives them. A part that the player walks on or stands against has a collision box. |
| `levels` | The triangle limits of near, mid, and far (plan 0023, D5: far at most 300). |
| `checks` | What the review sheet must show: the views (front, side, three quarters, far), and the values that World measures on the model (for example "the height to the top of the arm is 9.0 m ± 0.2 m"). |
| `status` | For each value: `Confirmed` (I know it), `Source` (from a photo or a page, with its reference), or `Check` (a guess). A spec with a `Check` value can be built, but the game does not use the model before I decide the value. |

## 2. The rules

- **A value comes from a photo or a source.** Write how it was measured: for example "the pole is 4.6 times the height of the person beside it (1.6 m): 7.4 m", or "the bays are 3.5 m: 70.9 m of the outline of OpenStreetMap over 20 bays". A value that nobody measured is `Check`.
- **Look at each photo.** Do not write a value from a photo that you did not look at. When a photo cannot be opened in the workspace, use the copy of R17 (plan 0026), or write the value as `Check`.
- **Sizes in meters, colors in sRGB, angles in degrees.**
- **One spec, one model.** A kit (the pieces of a sea wall, the lamps of a park) is one spec for each piece.
- **The spec is the contract.** World's review sheet shows the model next to the photos of the spec, from the same views, and lists the values of `checks` as measured. The architect of Vũng Tàu compares them. A model that does not meet its spec goes back to World with the differences.
- **World asks; it does not guess.** When a spec misses a value, World writes the question in the spec file (a field `questions`) on a branch, and Vũng Tàu answers it.
