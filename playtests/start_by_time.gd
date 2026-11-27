extends RefCounted
# PT-87 start_by_time (plan 0031, D12, R12). The game starts on the scooter of
# the start of Bãi Trước (--ride), on Low. The play test measures the real time
# from the first frame of the world until the scooter can start (the clock runs
# and the showcase near the start is built). Run 1 runs at the full frame
# rate and writes the time in OUT/start_wait.json; run 2 runs at 3 frames each
# second (--max-fps=3, the frame rate of a slow phone) and reads it: the wait
# of run 2 is at most 1.5 times the wait of run 1 (the load goes by time, not
# by frames). The full frame rate of the workspace is only about 7 frames each
# second, so run 3 does the same at 1 frame each second (the web build in the
# workspace has about 0.5): before D12 its wait was 2.47 times the wait of
# run 1. Then the player pushes the stick up for 3 s: the scooter starts.
# The play test gives the longest frame of the ride (R9 of plan 0018 has no
# limit yet: report 0018, Q3). Screenshots: the street when the scooter can
# start, and after the start.
# Runs 2 and 3 need the file of run 1: run all the runs in order (a run of one
# phase removes the folder of the play test).
# sizes: 1280x720
# phase: --world=vung_tau --start=bai_truoc --start-time=09:00 --quality=low --ride
# phase: --world=vung_tau --start=bai_truoc --start-time=09:00 --quality=low --ride --max-fps=3
# phase: --world=vung_tau --start=bai_truoc --start-time=09:00 --quality=low --ride --max-fps=1
# phase: --world=vung_tau --start=bai_truoc --start-time=09:00 --quality=low --ride --web-start

## The wait at 3 frames each second, at most this times the wait at the full frame rate.
const MAX_RATIO := 1.5
## Plan 0031, R18 and R19: no frame after "can move" longer than the median
## frame of the same time plus this (ms).
const OVER_MEDIAN_MS := 250.0
## Run 4 (R19) records the frames after "can move" until the world is settled, at most this long (s).
const SETTLE_S := 180.0
const FILE := "start_wait.json"


func run(d: PlaytestDriver) -> void:
	var main := d.main()
	var player: Player = main.player
	var can_start := func() -> bool: return GameState.clock_running and not player.ride_hold
	d.expect(player.is_riding(), "the game starts on the scooter (--ride)")
	await d.wait_until(can_start, 600.0, "the scooter can start")
	var wait_s: float = (Time.get_ticks_msec() - main.first_frame_ms) / 1000.0
	var fps_cap := Engine.max_fps
	d.step("the scooter can start %.1f s (real time) after the first frame, at %s" % [
			wait_s, "%d frames each second at most" % fps_cap if fps_cap > 0 else "the full frame rate"])
	await d.screenshot("can_start")
	if GameState.has_arg("web-start"):
		await _after_can_move(d, main)
		return
	var path := d.out_dir.path_join(FILE)
	if d.phase == 1:
		var out := FileAccess.open(path, FileAccess.WRITE)
		out.store_string(JSON.stringify({"wait_s": wait_s}))
		out.close()
	else:
		var full: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		if d.expect(full is Dictionary, "the wait of run 1 is in %s (run the two runs in order)" % FILE):
			var ratio: float = wait_s / maxf(float(full.wait_s), 0.001)
			d.step("the wait at %d frames each second is %.2f times the wait at the full frame rate (%.1f s)" % [fps_cap, ratio, full.wait_s])
			d.expect(ratio <= MAX_RATIO, "the wait at %d frames each second is at most %.1f times the wait at the full frame rate: %.2f" % [fps_cap, MAX_RATIO, ratio])
	# The ride: the stick up for 3 s of game time. The longest frame of the ride.
	var start := player.global_position
	# The real time between frames: the delta of a frame stops at the time of 16 physics steps (about 283 ms).
	var frames: Array[float] = []
	var last := {"usec": Time.get_ticks_usec()}
	var record := func() -> void:
		var now := Time.get_ticks_usec()
		frames.append((now - int(last.usec)) / 1000.0)
		last.usec = now
	main.get_tree().process_frame.connect(record)
	await d.hold_stick(Vector2(0.0, -1.0), 3.0)
	main.get_tree().process_frame.disconnect(record)
	var moved := player.global_position.distance_to(start)
	d.expect(moved > 2.0, "the scooter starts: %.1f m in 3 s" % moved)
	frames.sort()
	if not frames.is_empty():
		d.step("the ride: %d frames, the longest %.0f ms" % [frames.size(), frames[-1]])
	await d.screenshot("started")


## Plan 0031, R19 (run 4, the start of the web build): the scooter can start
## before the town is complete (D19), and while the rest of the world builds,
## no frame is longer than the median frame plus OVER_MEDIAN_MS (R18).
func _after_can_move(d: PlaytestDriver, main: Node) -> void:
	var w := d.world()
	var town_left: int = w.town.pending() if w.town else 0
	d.step("when the scooter can start: %s" % (w.unsettled_reason() if not w.is_settled() else "the world is settled"))
	d.expect(town_left > 0, "the scooter can start before the town is complete: %d chunks of the town are left" % town_left)
	var frames: Array[float] = []
	var last := {"usec": Time.get_ticks_usec()}
	var record := func() -> void:
		var now := Time.get_ticks_usec()
		frames.append((now - int(last.usec)) / 1000.0)
		last.usec = now
	main.get_tree().process_frame.connect(record)
	var settled := await d.wait_until(func() -> bool: return w.is_settled(), SETTLE_S, "the rest of the world is built")
	main.get_tree().process_frame.disconnect(record)
	if frames.size() < 3:
		d.fail("too few frames after the scooter can start: %d" % frames.size())
		return
	var sorted := frames.duplicate()
	sorted.sort()
	var median: float = sorted[sorted.size() / 2]
	var longest: float = sorted[-1]
	d.step("after the scooter can start: %d frames until the world is settled (%s), the median frame %.0f ms, the longest %.0f ms" % [
			frames.size(), "yes" if settled else "no", median, longest])
	d.expect(longest <= median + OVER_MEDIAN_MS, "no frame after the scooter can start is longer than the median frame plus %.0f ms: %.0f ms (the median %.0f ms)" % [
			OVER_MEDIAN_MS, longest, median])
	await d.screenshot("settled")
