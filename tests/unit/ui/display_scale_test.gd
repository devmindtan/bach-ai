extends RefCounted
## Display scale (Prefs.fit_scale): whole-number scales while the window holds the
## 1280x720 design, and a shrink below 1 when it does not (user 2026-11-17: a
## 1280x692 window piled the lobby's class card onto its buttons, because the
## layout always got a 720-high screen at scale 1 and ran off the bottom).

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_whole_number_scale_when_the_design_fits() -> void:
	_check(is_equal_approx(Prefs.fit_scale(Vector2(1280, 720), 0), 1.0), "1280x720: x1")
	_check(is_equal_approx(Prefs.fit_scale(Vector2(1366, 768), 0), 1.0), "1366x768: x1")
	_check(is_equal_approx(Prefs.fit_scale(Vector2(2560, 1440), 0), 2.0), "2560x1440: x2")
	_check(is_equal_approx(Prefs.fit_scale(Vector2(3840, 2160), 2), 2.0), "a chosen x2 that fits stays x2")


func test_a_smaller_window_shrinks_so_the_design_size_still_fits() -> void:
	var k := Prefs.fit_scale(Vector2(1280, 692), 0)
	_check(k < 1.0, "1280x692 shrinks, got %.3f" % k)
	_check(692.0 / k >= 719.9 and 1280.0 / k >= 1279.9, "the screen keeps 1280x720 design units, got %.1f x %.1f" % [1280.0 / k, 692.0 / k])
	var c := Prefs.fit_scale(Vector2(1920, 1000), 3)
	_check(1000.0 / c >= 719.9, "a chosen x3 that does not fit falls back to what fits, got %.2f" % c)


## User 2026-11-26 (lobby on a 1366x768 laptop, window ~1278x690): a canvas scaled by 0.96 with nearest
## filtering dropped one pixel row/column in ~25, so heroes drew with uneven, broken lines. Below the design size
## the game renders the whole 1280x720 frame 1:1 and shrinks the finished picture (viewport mode) instead.
func test_a_smaller_window_shrinks_the_finished_frame_not_the_canvas() -> void:
	_check(Prefs.fit_mode(Vector2(1278, 690)) == Window.CONTENT_SCALE_MODE_VIEWPORT, "1278x690: viewport mode (whole frame shrunk)")
	_check(Prefs.fit_mode(Vector2(1280, 720)) == Window.CONTENT_SCALE_MODE_DISABLED, "1280x720: 1:1, no shrink")
	_check(Prefs.fit_mode(Vector2(2560, 1440)) == Window.CONTENT_SCALE_MODE_DISABLED, "2560x1440: whole-number canvas scale")
