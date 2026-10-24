class_name Lunar
extends RefCounted
## The Vietnamese lunar calendar (âm lịch), plan 0005, D13.
##
## This is the algorithm of Hồ Ngọc Đức ("Thuật toán tính âm lịch"), with the
## time zone UTC+7. tools/geo/geodata/lunar.py has the same algorithm.

const TIME_ZONE := 7.0


## The Julian day number of a date of the Gregorian calendar.
static func jd_from_date(day: int, month: int, year: int) -> int:
	var a := (14 - month) / 12
	var y := year + 4800 - a
	var m := month + 12 * a - 3
	var jd := day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
	if jd < 2299161:
		jd = day + (153 * m + 2) / 5 + 365 * y + y / 4 - 32083
	return jd


## The date {year, month, day} of a Julian day number.
static func date_from_jd(jd: int) -> Dictionary:
	var a := jd + 32044
	var b := (4 * a + 3) / 146097
	var c := a - (b * 146097) / 4
	var d := (4 * c + 3) / 1461
	var e := c - (1461 * d) / 4
	var m := (5 * e + 2) / 153
	return {"day": e - (153 * m + 2) / 5 + 1, "month": m + 3 - 12 * (m / 10), "year": b * 100 + d - 4800 + m / 10}


## The Julian day of the new moon number k after 1900-01-01.
static func new_moon(k: int) -> float:
	var t := k / 1236.85
	var t2 := t * t
	var t3 := t2 * t
	var dr := PI / 180.0
	var jd1 := 2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3
	jd1 += 0.00033 * sin((166.56 + 132.87 * t - 0.009173 * t2) * dr)
	var m := 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3
	var mpr := 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3
	var f := 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3
	var c1 := (0.1734 - 0.000393 * t) * sin(m * dr) + 0.0021 * sin(2 * dr * m)
	c1 = c1 - 0.4068 * sin(mpr * dr) + 0.0161 * sin(dr * 2 * mpr)
	c1 = c1 - 0.0004 * sin(dr * 3 * mpr)
	c1 = c1 + 0.0104 * sin(dr * 2 * f) - 0.0051 * sin(dr * (m + mpr))
	c1 = c1 - 0.0074 * sin(dr * (m - mpr)) + 0.0004 * sin(dr * (2 * f + m))
	c1 = c1 - 0.0004 * sin(dr * (2 * f - m)) - 0.0006 * sin(dr * (2 * f + mpr))
	c1 = c1 + 0.0010 * sin(dr * (2 * f - mpr)) + 0.0005 * sin(dr * (2 * mpr + m))
	var delta := 0.0
	if t < -11:
		delta = 0.001 + 0.000839 * t + 0.0002261 * t2 - 0.00000845 * t3 - 0.000000081 * t * t3
	else:
		delta = -0.000278 + 0.000265 * t + 0.000262 * t2
	return jd1 + c1 - delta


## The longitude of the sun in radians, 0 to 2π.
static func sun_longitude(jdn: float) -> float:
	var t := (jdn - 2451545.0) / 36525
	var t2 := t * t
	var dr := PI / 180.0
	var m := 357.52910 + 35999.05030 * t - 0.0001559 * t2 - 0.00000048 * t * t2
	var l0 := 280.46645 + 36000.76983 * t + 0.0003032 * t2
	var dl := (1.914600 - 0.004817 * t - 0.000014 * t2) * sin(dr * m)
	dl += (0.019993 - 0.000101 * t) * sin(dr * 2 * m) + 0.000290 * sin(dr * 3 * m)
	var lon := (l0 + dl) * dr
	return lon - PI * 2 * floorf(lon / (PI * 2))


static func _sun_sector(day_number: int, zone: float) -> int:
	return floori(sun_longitude(day_number - 0.5 - zone / 24.0) / PI * 6)


static func _new_moon_day(k: int, zone: float) -> int:
	return floori(new_moon(k) + 0.5 + zone / 24.0)


static func _month_11(year: int, zone: float) -> int:
	var off := jd_from_date(31, 12, year) - 2415021
	var k := floori(off / 29.530588853)
	var nm := _new_moon_day(k, zone)
	if _sun_sector(nm, zone) >= 9:
		nm = _new_moon_day(k - 1, zone)
	return nm


static func _leap_month_offset(a11: int, zone: float) -> int:
	var k := floori((a11 - 2415021.076998695) / 29.530588853 + 0.5)
	var i := 1
	var arc := _sun_sector(_new_moon_day(k + i, zone), zone)
	while true:
		var last := arc
		i += 1
		arc = _sun_sector(_new_moon_day(k + i, zone), zone)
		if arc == last or i >= 14:
			break
	return i - 1


## Returns {day, month, year, leap} of the lunar calendar for a solar date.
static func from_solar(day: int, month: int, year: int, zone := TIME_ZONE) -> Dictionary:
	var day_number := jd_from_date(day, month, year)
	var k := floori((day_number - 2415021.076998695) / 29.530588853)
	var month_start := _new_moon_day(k + 1, zone)
	if month_start > day_number:
		month_start = _new_moon_day(k, zone)
	var a11 := _month_11(year, zone)
	var b11 := a11
	var lunar_year := 0
	if a11 >= month_start:
		lunar_year = year
		a11 = _month_11(year - 1, zone)
	else:
		lunar_year = year + 1
		b11 = _month_11(year + 1, zone)
	var lunar_day := day_number - month_start + 1
	var diff := floori((month_start - a11) / 29.0)
	var leap := false
	var lunar_month := diff + 11
	if b11 - a11 > 365:
		var leap_diff := _leap_month_offset(a11, zone)
		if diff >= leap_diff:
			lunar_month = diff + 10
			if diff == leap_diff:
				leap = true
	if lunar_month > 12:
		lunar_month -= 12
	if lunar_month >= 11 and diff < 4:
		lunar_year -= 1
	return {"day": lunar_day, "month": lunar_month, "year": lunar_year, "leap": leap}
