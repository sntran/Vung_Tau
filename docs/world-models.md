# How Vũng Tàu makes its models in World

World works as the game Dreams of Media Molecule: World is the engine and the tools, and the person who plays makes the things. For this game, **Vũng Tàu makes its models**. It sculpts them with the tools of World, puts parts together, and uses the things of World again, as a player of Dreams uses the shapes, the sculpt tools, and the elements of other players. World does not make a model of this game, and does not choose its sizes, its shapes, or its colors. **The construction is in the game** (plan 0027): World gives the tools, the parts, and the labour, and streams each part of a model; this game glues the parts together. An edit builds only the parts that change.

The tools are in World: `docs/requests.md` (how a project asks), `docs/format.md` ("A sculpture", "A drawing", "A blueprint in data", "A person"), and `docs/skills.md`.

## 1. The three ways to make a model

Use the first way that can make the thing.

| Way | In Dreams | In World | For example |
|---|---|---|---|
| 1. Use an element again, with its options | Take an element of the Dreamiverse and change its settings | An order of a blueprint of World by its name, with the numbers of this game (`person`, `plant`, `scooter`, `street_house`, `building`, `mini`) | A walker of 40 years in a T-shirt; a coconut palm with its lean; Hải Âu from the words of `building` |
| 2. Change an element (remix) | Open the element and sculpt on it | The edit `{"free": true}` of an order, and then edits of its shapes, or parts from edits at its ports | A swim ring at the hands of a person; a lamp with a second arm |
| 3. Sculpt a new thing | Sculpt from shapes: add, take away, paint, blend, mirror, repeat | A drawing (`{"blueprint": "drawing"}`) of parts from edits (`docs/format.md`, "A sculpture"); a family of things is a blueprint in data | The pavilion with the orange roof; a piece of 2 m of the sea wall; the low lamp of the park |

## 2. The files

- `data/world/drawings/ID.json`: the drawing (way 3), or the order with its edits (ways 1 and 2), of each model of this game. `ID` is its id in `data/world/orders.json`.
- `data/world/blueprints/NAME.json`: a blueprint in data, for a family of things of this game with options (the pieces of the sea wall, the lamps of the park).
- `data/world/orders.json` and `data/world/lock.json` (plan 0023): the order and the bytes of each model.
- In each drawing, `sources` give the photos and how each size was measured (section 3), and `sizes` give each size with its source, or "estimate (no source)".

## 3. Sizes and photos

The look of the model comes from photos, not from a guess.

- **Look at each photo** before you take a value from it. Write its link, its date, its license, its author, and what it shows.
- **Write how each size was measured**: for example "the pole is 4.6 times the height of the person beside it (1.6 m): 7.4 m", or "70.9 m of the outline of OpenStreetMap over 20 bays: 3.5 m".
- **A photo of 2017 to 2021** is the best source for 2019. A size or a look that only an older or newer photo shows is "Check", and the game does not use the model before I decide it.
- **Open photos** (CC0, CC BY, CC BY-SA, public domain) are copied into `docs/reference/photos/` with their credits (plan 0026, R17). Other photos stay links.

## 4. The work: ask, look, edit

As a player of Dreams sculpts, looks, and sculpts again:

1. **Check** the order (`check_order`, `check_drawing`, or `check_blueprint` of World: milliseconds). Correct each error.
2. **Look at the far or the mid level first** (seconds to 2 minutes), next to the photos, from the same views (front, side, three quarters, far).
3. **Edit** with small changes (`edit_order`, or a new version of the drawing), and look again, until the model matches the photos.
4. **Build the near level** one time, when the mid level is right. A large building from edits takes minutes: do it before a review, not while a person waits. When World gives the parts of an order (plan 0027), an edit builds only the parts that change, and the game glues them.
5. **Keep** the last order and its lock in this repository. Make the review sheet (`tools/world/sheets.py`): the model next to its photos, with its sizes.

## 5. When a tool is missing

World gives tools, as Media Molecule gives the tools of Dreams. When this game cannot make a thing with the tools of World (a shape, a finish, a joint, a number that a rule does not let a request change), ask World for **the tool**, not for the model:

- Write what the tool does in general, in one or two lines.
- Give the smallest drawing of this game that needs it, and the error or the result that shows the gap.
- World adds the tool, with its tests, for every project. Then this game makes its model with it.

For example: "a garment `swim_trunks` for the person blueprint, as the other garments", not "a swimmer of Bãi Trước".

## 6. What World does

- It keeps its tools working: the evaluator of the edits, the shapes, the finishes, the levels, the maps, the people, the checks, and the factory.
- It corrects its faults (a wrong file, a check that passes a wrong order, a level that loses a color).
- It adds a tool when a project shows the need (section 5).
- It does not make, change, or keep a model of Vũng Tàu.
