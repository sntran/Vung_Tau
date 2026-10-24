class_name SunPosition
extends RefCounted
## The position of the sun for a place and a time (plan 0004, D9).
##
## The formulas are the NOAA solar position equations. They are accurate to
## about 0.1 degree, which is enough for the light of the game.

## Vũng Tàu uses UTC+7 (Indochina Time) all year.
const TIME_ZONE := 7.0


## Returns {"elevation", "azimuth"} in degrees. The azimuth is clockwise from north.
## "minutes" is the local clock time from midnight.
static func at(lat: float, lon: float, day_of_year: int, minutes: float) -> Dictionary:
	var hours := minutes / 60.0
	var gamma := TAU / 365.0 * (day_of_year - 1 + (hours - TIME_ZONE - 12.0) / 24.0)
	var eqtime := 229.18 * (0.000075 + 0.001868 * cos(gamma) - 0.032077 * sin(gamma)
			- 0.014615 * cos(2.0 * gamma) - 0.040849 * sin(2.0 * gamma))
	var decl := (0.006918 - 0.399912 * cos(gamma) + 0.070257 * sin(gamma) - 0.006758 * cos(2.0 * gamma)
			+ 0.000907 * sin(2.0 * gamma) - 0.002697 * cos(3.0 * gamma) + 0.00148 * sin(3.0 * gamma))
	var true_solar_minutes := minutes + eqtime + 4.0 * lon - 60.0 * TIME_ZONE
	var hour_angle := deg_to_rad(true_solar_minutes / 4.0 - 180.0)
	var phi := deg_to_rad(lat)
	var cos_zenith := sin(phi) * sin(decl) + cos(phi) * cos(decl) * cos(hour_angle)
	var elevation := rad_to_deg(asin(clampf(cos_zenith, -1.0, 1.0)))
	var azimuth := rad_to_deg(atan2(sin(hour_angle), cos(hour_angle) * sin(phi) - tan(decl) * cos(phi))) + 180.0
	return {"elevation": elevation, "azimuth": fposmod(azimuth, 360.0)}


## The unit vector from the ground to the sun, in game coordinates (X east, -Z north).
static func direction(elevation: float, azimuth: float) -> Vector3:
	var e := deg_to_rad(elevation)
	var a := deg_to_rad(azimuth)
	return Vector3(sin(a) * cos(e), sin(e), -cos(a) * cos(e))
