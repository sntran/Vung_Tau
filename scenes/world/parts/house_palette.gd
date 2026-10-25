class_name HousePalette
extends RefCounted
## The colors of the houses from data/world/palette.json (plan 0004, R10a to R10c).

const PATH := "res://data/world/palette.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


## Picks one entry of a list of {color, weight} by weight.
static func _by_weight(entries: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for entry: Dictionary in entries:
		total += float(entry.get("weight", 1.0))
	var pick := rng.randf() * total
	for entry: Dictionary in entries:
		pick -= float(entry.get("weight", 1.0))
		if pick <= 0.0:
			return entry
	return entries[entries.size() - 1]


## The paint of a wall: {color, stripe (or null), bold}. "avoid" is the color
## of the neighbor house, which this house must not have. "bold_allowed" is
## false when the street already has its share of bold walls.
static func wall(rng: RandomNumberGenerator, avoid: Variant = null, bold_allowed := true) -> Dictionary:
	var d := data()
	for attempt in 20:
		var result := {}
		if bold_allowed and rng.randf() < float(d.bold_share):
			var bold: Dictionary = d.bold_walls[rng.randi() % d.bold_walls.size()]
			result = {"color": Color(bold.color), "stripe": Color(bold.stripe) if bold.has("stripe") else null,
					"bold": true}
		else:
			result = {"color": Color(_by_weight(d.walls, rng).color), "stripe": null, "bold": false}
		if avoid == null or not (result.color as Color).is_equal_approx(avoid):
			return result
	return {"color": Color(d.walls[0].color), "stripe": null, "bold": false}


## The paints of a row of houses: neighbors differ, and not more bold walls
## than the share of the area ("homes" or "beach").
static func row(count: int, rng: RandomNumberGenerator, area := "homes") -> Array[Dictionary]:
	var d := data()
	var max_share := float(d.bold_max_beach) if area == "beach" else float(d.bold_max_homes)
	var max_bold := floori(count * max_share + 0.001)
	var result: Array[Dictionary] = []
	var bold := 0
	for i in count:
		var avoid: Variant = result[i - 1].color if i > 0 else null
		var paint := wall(rng, avoid, bold < max_bold)
		if paint.bold:
			bold += 1
		result.append(paint)
	return result


## True when the color is one of the wall colors of the palette.
static func is_wall_color(color: Color) -> bool:
	var d := data()
	for entry: Dictionary in d.walls + d.bold_walls + [d.villa_wall, d.unpainted]:
		if Color(entry.color).is_equal_approx(color):
			return true
	return false


## True when the palette has a two-color front with these two colors.
static func is_two_color(color: Color, stripe: Color) -> bool:
	for entry: Dictionary in data().bold_walls:
		if entry.has("stripe") and Color(entry.color).is_equal_approx(color) \
				and Color(entry.stripe).is_equal_approx(stripe):
			return true
	return false


static func is_bold(color: Color) -> bool:
	for entry: Dictionary in data().bold_walls:
		if Color(entry.color).is_equal_approx(color):
			return true
	return false


## A color of the accent list ("shutters", "rails", "frames", "signs", "awnings", "tiles").
static func accent(kind: String, rng: RandomNumberGenerator) -> Color:
	var list: Array = data().accents[kind]
	return Color(list[rng.randi() % list.size()])


## A color of corrugated metal: {color, kind}.
static func metal_roof(rng: RandomNumberGenerator) -> Dictionary:
	var entry := _by_weight(data().metal_roofs.colors, rng)
	return {"color": Color(entry.color), "kind": entry.kind}


## A color of a flat concrete roof terrace (D-0004-03).
static func terrace(rng: RandomNumberGenerator) -> Color:
	return Color(_by_weight(data().terraces.colors, rng).color)


static func roof_tile(rng: RandomNumberGenerator) -> Color:
	var list: Array = data().roof_tiles.colors
	return Color(list[rng.randi() % list.size()])


static func color_of(key: String) -> Color:
	return Color(data()[key].color)
