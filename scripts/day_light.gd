class_name DayLight
extends RefCounted
## Light by time of day: the sun angle and color, the sky colors, and the ambient light.
##
## The sea is at the high X end of the hẻm. Bãi Trước faces west, so the sun
## rises at the low X end and sets over the sea.

## Sky colors: [hour, top color, horizon color]. The same colors as the 2D prototype.
const SKY := [
	[0.0, "#0B1530", "#1C2A4A"],
	[5.0, "#1A2550", "#4B4A72"],
	[6.0, "#6E86C2", "#F2B48A"],
	[7.5, "#8EC5E8", "#F4E3C0"],
	[12.0, "#7FC3EC", "#DCEFF6"],
	[16.0, "#86B8DF", "#F3D9A6"],
	[18.0, "#4E5D9A", "#F29A5E"],
	[19.0, "#25305E", "#8A4E6A"],
	[20.0, "#0E1838", "#22305A"],
	[24.0, "#0B1530", "#1C2A4A"],
]
const SUNRISE_HOUR := 5.75
const SUNSET_HOUR := 18.25
## Lamps are on when the darkness is more than this value.
const LAMPS_ON_DARKNESS := 0.22


## Returns the darkness from 0.0 (full day) to 0.55 (night). Same curve as the 2D prototype.
static func darkness(minutes: int) -> float:
	var h := minutes / 60.0
	if h < 5.0:
		return 0.55
	if h < 7.0:
		return 0.55 - (h - 5.0) / 2.0 * 0.55
	if h < 17.0:
		return 0.0
	if h < 19.5:
		return (h - 17.0) / 2.5 * 0.55
	return 0.55


static func lamps_on(minutes: int) -> bool:
	return darkness(minutes) > LAMPS_ON_DARKNESS


## Returns [top color, horizon color] of the sky.
static func sky_colors(minutes: int) -> Array[Color]:
	var h := minutes / 60.0
	for i in SKY.size() - 1:
		var a: Array = SKY[i]
		var b: Array = SKY[i + 1]
		if h >= a[0] and h <= b[0]:
			var t: float = (h - a[0]) / (b[0] - a[0])
			return [Color(a[1]).lerp(Color(b[1]), t), Color(a[2]).lerp(Color(b[2]), t)]
	return [Color(SKY[0][1]), Color(SKY[0][2])]


## Returns the height of the sun from 0.0 (at the horizon or below) to 1.0 (at noon).
static func sun_height(minutes: int) -> float:
	var h := minutes / 60.0
	if h <= SUNRISE_HOUR or h >= SUNSET_HOUR:
		return 0.0
	return sin(PI * (h - SUNRISE_HOUR) / (SUNSET_HOUR - SUNRISE_HOUR))


## Returns the rotation in degrees for the DirectionalLight3D.
## By day it is the sun. At night it is a weak moon light from high up.
static func sun_rotation(minutes: int) -> Vector3:
	var h := minutes / 60.0
	if h > SUNRISE_HOUR and h < SUNSET_HOUR:
		var t := (h - SUNRISE_HOUR) / (SUNSET_HOUR - SUNRISE_HOUR)
		var elevation := 8.0 + 70.0 * sin(PI * t)
		# The sun moves from the low X end (east) to the high X end (west).
		# A yaw of -90 degrees points the light toward +X. At noon, the light
		# points toward -Z: Vũng Tàu is at 10° N, and in summer the noon sun
		# is a little to the north. Then the sun lights the house fronts.
		var yaw := lerpf(-90.0, 90.0, t)
		return Vector3(-elevation, yaw, 0.0)
	return Vector3(-55.0, 20.0, 0.0)


static func sun_color(minutes: int) -> Color:
	var height := sun_height(minutes)
	if height <= 0.0:
		return Color("#8FA6D6")
	return Color("#FFB070").lerp(Color("#FFF6E6"), clampf(height * 2.0, 0.0, 1.0))


static func sun_energy(minutes: int) -> float:
	var height := sun_height(minutes)
	if height <= 0.0:
		return 0.18
	return lerpf(0.5, 1.25, clampf(height * 1.6, 0.0, 1.0))


static func ambient_energy(minutes: int) -> float:
	return lerpf(0.75, 0.22, darkness(minutes) / 0.55)
