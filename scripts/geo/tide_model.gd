class_name TideModel
extends RefCounted
## The sea level from the tide constituents of data/geo/build/tide.json
## (plan 0005, D12, R8f). This is the same calculation as
## tools/geo/geodata/tidecalc.py and pyTMD with the FES nodal corrections:
## the sea level is the sum of f · A · cos(G + u − g) for each constituent.

const PATH := "res://data/geo/build/tide.json"
const MJD_UNIX := 40587.0
const MJD_J2000 := 51544.5
const CENTURY := 36525.0

## The constituents: [{doodson: PackedFloat64Array, nodal, amplitude, phase (radians)}].
var constituents: Array[Dictionary] = []
var tt_minus_ut1_s := 69.0
## The test values of tide.py: [[unix seconds, level], ...].
var tests: Array = []
var ridge_top := 0.0


## Reads the file. Returns null when it is not there.
static func open(path := PATH) -> TideModel:
	if not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return null
	var model := TideModel.new()
	var point: Dictionary = data.points[data.point].constituents
	for c: Dictionary in data.constituents:
		var constants: Dictionary = point[c.name]
		model.constituents.append({"doodson": PackedFloat64Array(c.doodson), "nodal": c.nodal,
				"amplitude": float(constants.amplitude), "phase": deg_to_rad(float(constants.phase))})
	model.tt_minus_ut1_s = float(data.get("tt_minus_ut1_s", 69.0))
	model.tests = data.get("tests", [])
	model.ridge_top = float(data.get("ridge_top_m", 0.0))
	return model


## The sea level in meters above mean sea level at the time (seconds since 1970, UTC).
func level(unix_seconds: float) -> float:
	var mjd := unix_seconds / 86400.0 + MJD_UNIX
	var t := (mjd + tt_minus_ut1_s / 86400.0 - MJD_J2000) / CENTURY
	var t2 := t * t
	var t3 := t2 * t
	var t4 := t3 * t
	# The mean longitudes in degrees (Meeus, the ASTRO5 terms in pyTMD).
	var s := 218.3164477 + 481267.88123421 * t - 1.5786e-3 * t2 + 1.855835e-6 * t3 - 1.53388e-8 * t4
	var elongation := 297.8501921 + 445267.1114034 * t - 1.8819e-3 * t2 + 1.83195e-6 * t3 - 8.8445e-9 * t4
	var h := s - elongation
	var p := 83.3532465 + 4069.0137287 * t - 1.032e-2 * t2 - 1.249172e-5 * t3
	var n := 125.04452 - 1934.136261 * t + 2.0708e-3 * t2 + 2.22222e-6 * t3
	var ps := 282.94 + 1.7192 * t
	s = fposmod(s, 360.0)
	h = fposmod(h, 360.0)
	p = fposmod(p, 360.0)
	n = fposmod(n, 360.0)
	ps = fposmod(ps, 360.0)
	var hour := 24.0 * fposmod(mjd, 1.0)
	var tau := 15.0 * hour - s + h
	var args := [tau, s, h, p, n, ps, 90.0]
	var nodal := _schureman(deg_to_rad(n))
	var total := 0.0
	for c in constituents:
		var g := 0.0
		var doodson: PackedFloat64Array = c.doodson
		for k in 7:
			g += doodson[k] * args[k]
		var fu := _nodal(c.nodal, nodal)
		total += fu.x * c.amplitude * cos(deg_to_rad(g) + fu.y - c.phase)
	return total


## I, ξ, ν, ν′, ν″ in radians from N (Schureman, pages 156, 45, and 46).
static func _schureman(n: float) -> Dictionary:
	var i := acos(0.913694997 - 0.035692561 * cos(n))
	var at1 := atan(1.01883 * tan(n / 2.0))
	var at2 := atan(0.64412 * tan(n / 2.0))
	var xi := -at1 - at2 + n
	xi = atan2(sin(xi), cos(xi))
	var nu := at1 - at2
	var nu_p := atan(sin(2.0 * i) * sin(nu) / (sin(2.0 * i) * cos(nu) + 0.3347))
	var nu_s := 0.5 * atan(pow(sin(i), 2) * sin(2.0 * nu) / (pow(sin(i), 2) * cos(2.0 * nu) + 0.0727))
	return {"i": i, "xi": xi, "nu": nu, "nu_p": nu_p, "nu_s": nu_s}


## The factor f (x) and the angle u in radians (y) of a kind of nodal correction.
static func _nodal(kind: String, a: Dictionary) -> Vector2:
	var i: float = a.i
	match kind:
		"m2":
			return Vector2(pow(cos(i / 2.0), 4) / 0.9154, 2.0 * a.xi - 2.0 * a.nu)
		"m4":
			var m2 := _nodal("m2", a)
			return Vector2(m2.x * m2.x, 2.0 * m2.y)
		"o1":
			return Vector2(sin(i) * pow(cos(i / 2.0), 2) / 0.38, 2.0 * a.xi - a.nu)
		"k1":
			return Vector2(sqrt(0.8965 * pow(sin(2.0 * i), 2) + 0.6001 * sin(2.0 * i) * cos(a.nu) + 0.1006), -a.nu_p)
		"k2":
			return Vector2(sqrt(19.0444 * pow(sin(i), 4) + 2.7702 * pow(sin(i), 2) * cos(2.0 * a.nu) + 0.0981),
					-2.0 * a.nu_s)
		"j1":
			return Vector2(sin(2.0 * i) / 0.7214, -a.nu)
		"mf":
			return Vector2(pow(sin(i), 2) / 0.1578, -2.0 * a.xi)
		"mm":
			return Vector2((2.0 / 3.0 - pow(sin(i), 2)) / 0.5021, 0.0)
	return Vector2(1.0, 0.0)
