class_name GeoProjection
extends RefCounted
## The projection of plan 0004 (D4): WGS 84 degrees to UTM zone 48N
## (EPSG:32648), and UTM to game coordinates.
##
## The game origin is a UTM point. Game X is east, game -Z is north, 1 unit is 1 m.
## The formulas are the Krüger series of order 6 (Karney 2011). The error is
## less than 1 mm in the UTM zone.

const A := 6378137.0
const F := 1.0 / 298.257223563
const K0 := 0.9996
const FALSE_EASTING := 500000.0

var origin_e := 0.0
var origin_n := 0.0
var central_meridian := 105.0
var _n := 0.0
var _a := 0.0
var _e := 0.0
var _alpha: Array[float] = []
var _beta: Array[float] = []


func _init(utm_e := 0.0, utm_n := 0.0, zone := 48) -> void:
	origin_e = utm_e
	origin_n = utm_n
	central_meridian = zone * 6.0 - 183.0
	var n := F / (2.0 - F)
	_n = n
	_e = sqrt(F * (2.0 - F))
	var n2 := n * n
	var n3 := n2 * n
	var n4 := n3 * n
	var n5 := n4 * n
	var n6 := n5 * n
	_a = A / (1.0 + n) * (1.0 + n2 / 4.0 + n4 / 64.0 + n6 / 256.0)
	_alpha = [
		n / 2.0 - 2.0 * n2 / 3.0 + 5.0 * n3 / 16.0 + 41.0 * n4 / 180.0 - 127.0 * n5 / 288.0 + 7891.0 * n6 / 37800.0,
		13.0 * n2 / 48.0 - 3.0 * n3 / 5.0 + 557.0 * n4 / 1440.0 + 281.0 * n5 / 630.0 - 1983433.0 * n6 / 1935360.0,
		61.0 * n3 / 240.0 - 103.0 * n4 / 140.0 + 15061.0 * n5 / 26880.0 + 167603.0 * n6 / 181440.0,
		49561.0 * n4 / 161280.0 - 179.0 * n5 / 168.0 + 6601661.0 * n6 / 7257600.0,
		34729.0 * n5 / 80640.0 - 3418889.0 * n6 / 1995840.0,
		212378941.0 * n6 / 319334400.0,
	]
	_beta = [
		n / 2.0 - 2.0 * n2 / 3.0 + 37.0 * n3 / 96.0 - n4 / 360.0 - 81.0 * n5 / 512.0 + 96199.0 * n6 / 604800.0,
		n2 / 48.0 + n3 / 15.0 - 437.0 * n4 / 1440.0 + 46.0 * n5 / 105.0 - 1118711.0 * n6 / 3870720.0,
		17.0 * n3 / 480.0 - 37.0 * n4 / 840.0 - 209.0 * n5 / 4480.0 + 5569.0 * n6 / 90720.0,
		4397.0 * n4 / 161280.0 - 11.0 * n5 / 504.0 - 830251.0 * n6 / 7257600.0,
		4583.0 * n5 / 161280.0 - 108847.0 * n6 / 3991680.0,
		20648693.0 * n6 / 638668800.0,
	]


## Makes the projection from the "origin" record of data/geo/build/world.json.
static func from_world(world: Dictionary) -> GeoProjection:
	var origin: Dictionary = world.get("origin", {})
	var zone := int(world.get("epsg", 32648)) - 32600
	return GeoProjection.new(float(origin.get("utm_e", 0.0)), float(origin.get("utm_n", 0.0)), zone)


## Degrees to UTM: [easting, northing]. A Vector2 has only 32-bit floats, so the
## functions give UTM values and degrees in a PackedFloat64Array.
func to_utm(lon: float, lat: float) -> PackedFloat64Array:
	var phi := deg_to_rad(lat)
	var lam := deg_to_rad(lon - central_meridian)
	var s := sin(phi)
	var t := sinh(_atanh(s) - _e * _atanh(_e * s))
	var xi1 := atan2(t, cos(lam))
	var eta1 := _atanh(sin(lam) / sqrt(1.0 + t * t))
	var xi := xi1
	var eta := eta1
	for j in 6:
		var k := 2.0 * (j + 1)
		xi += _alpha[j] * sin(k * xi1) * cosh(k * eta1)
		eta += _alpha[j] * cos(k * xi1) * sinh(k * eta1)
	return PackedFloat64Array([FALSE_EASTING + K0 * _a * eta, K0 * _a * xi])


## UTM to degrees: [lon, lat].
func utm_to_lonlat(easting: float, northing: float) -> PackedFloat64Array:
	var xi := northing / (K0 * _a)
	var eta := (easting - FALSE_EASTING) / (K0 * _a)
	var xi1 := xi
	var eta1 := eta
	for j in 6:
		var k := 2.0 * (j + 1)
		xi1 -= _beta[j] * sin(k * xi) * cosh(k * eta)
		eta1 -= _beta[j] * cos(k * xi) * sinh(k * eta)
	var chi := asin(sin(xi1) / cosh(eta1))
	var lam := atan2(sinh(eta1), cos(xi1))
	# The conformal latitude to the geodetic latitude, by iteration.
	var phi := chi
	for i in 8:
		phi = asin(tanh(_atanh(sin(chi)) + _e * _atanh(_e * sin(phi))))
	return PackedFloat64Array([central_meridian + rad_to_deg(lam), rad_to_deg(phi)])


## Degrees to game Vector2(X, Z). The game values are small, so 32 bits are enough.
func to_game(lon: float, lat: float) -> Vector2:
	var utm := to_utm(lon, lat)
	return Vector2(utm[0] - origin_e, -(utm[1] - origin_n))


## Game (X, Z) to degrees: [lon, lat].
func game_to_lonlat(x: float, z: float) -> PackedFloat64Array:
	return utm_to_lonlat(x + origin_e, origin_n - z)


static func _atanh(x: float) -> float:
	return 0.5 * log((1.0 + x) / (1.0 - x))
