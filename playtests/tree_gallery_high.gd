extends "res://playtests/tree_gallery.gd"
# PT-52 tree_gallery, the High runs (plan 0020): the same test ground and
# checks as tree_gallery.gd, on High at 12:00 on day 1 and on 3 June 2019. High
# takes about three times longer than Low under lavapipe, so each run is in
# seven phases of two types. The last phase makes the sheets of High.
# sizes: 1280x720
# phase: --world=vung_tau --start-time=12:00 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --start-date=2019-06-03 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --start-date=2019-06-03 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --start-date=2019-06-03 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --start-date=2019-06-03 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --start-date=2019-06-03 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --start-date=2019-06-03 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --start-date=2019-06-03 --quality=high --renderer=forward_plus
# phase: --start-time=12:00

const HIGH_RUNS := ["1200_day1_high", "1200_june_high"]


func runs() -> Array:
	return HIGH_RUNS


func groups() -> int:
	return 7
