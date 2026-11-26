extends GutTest
## Plan 0031, D11 and R11: the line of the times of the start on the web.


func test_the_line_has_the_times_the_frames_and_the_memory() -> void:
	var line := LoadTimes.line({"bytesMB": 122.4, "firstFrameS": 20.1, "canMoveS": 25.3, "pageMB": 640}, 31)
	assert_eq(line, "122.4 MB · first frame 20.1 s · ride 25.3 s · 31 fps · page 640 MB")


func test_the_line_has_no_memory_when_the_browser_does_not_give_it() -> void:
	var line := LoadTimes.line({"bytesMB": 3.0, "firstFrameS": 2.0, "canMoveS": 4.5}, 60)
	assert_eq(line, "3.0 MB · first frame 2.0 s · ride 4.5 s · 60 fps")


func test_the_line_is_empty_with_no_times() -> void:
	assert_eq(LoadTimes.line({}, 30), "")


## A build of a branch shows the line always; the build of main only with ?times.
func test_the_line_shows_on_a_branch_and_on_main_with_times() -> void:
	assert_true(LoadTimes.shows(true, "feat/0031-web-load", false))
	assert_true(LoadTimes.shows(true, "", false), "a build with no branch (a local export)")
	assert_false(LoadTimes.shows(true, "main", false))
	assert_true(LoadTimes.shows(true, "main", true))
	assert_false(LoadTimes.shows(false, "feat/0031-web-load", true), "a computer shows no line")


## The parts of the start (D11), in seconds, from the marks of the page in ms.
func test_the_parts_of_the_start() -> void:
	var parts := LoadTimes.parts({"downloadEnd": 12000.0, "compileStart": 3000.0, "compileEnd": 9000.0,
			"engine": 15000.0, "firstFrame": 21000.0, "canMove": 26000.0})
	assert_almost_eq(float(parts.downloadS), 12.0, 0.001)
	assert_almost_eq(float(parts.compileS), 6.0, 0.001)
	assert_almost_eq(float(parts.engineS), 3.0, 0.001, "from the end of the download and the compile")
	assert_almost_eq(float(parts.worldS), 6.0, 0.001)
	assert_almost_eq(float(parts.moveS), 5.0, 0.001)
