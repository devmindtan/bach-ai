extends RefCounted
## MoveFeel (user 2026-11-28: walk eases in and out, the camera trails softly).

var failures: Array[String] = []


func test_walk_reaches_full_speed_after_accel_time() -> void:
	var v := Vector2.ZERO
	for i in 5:   # 5 × 0.02 s > 0.08 s
		v = MoveFeel.step_velocity(v, Vector2(150, 0), 150.0, 0.08, 0.1, 0.02)
	if not v.is_equal_approx(Vector2(150, 0)):
		failures.append("not at full speed after accel_s: %s" % v)


func test_first_step_is_not_full_speed() -> void:
	var v := MoveFeel.step_velocity(Vector2.ZERO, Vector2(150, 0), 150.0, 0.08, 0.1, 1.0 / 60.0)
	if v.x <= 0.0 or v.x >= 150.0:
		failures.append("first step should ease in, got %s" % v)


func test_stop_eases_out_then_rests() -> void:
	var v := MoveFeel.step_velocity(Vector2(150, 0), Vector2.ZERO, 150.0, 0.08, 0.1, 1.0 / 60.0)
	if v.x <= 0.0:
		failures.append("released key stopped dead")
	for i in 10:
		v = MoveFeel.step_velocity(v, Vector2.ZERO, 150.0, 0.08, 0.1, 1.0 / 60.0)
	if v != Vector2.ZERO:
		failures.append("still sliding after decel_s: %s" % v)


func test_zero_times_keep_the_old_snap() -> void:
	if MoveFeel.step_velocity(Vector2.ZERO, Vector2(150, 0), 150.0, 0.0, 0.0, 0.016) != Vector2(150, 0):
		failures.append("accel_s 0 must snap")
	if MoveFeel.follow(Vector2.ZERO, Vector2(50, 0), 0.0, 40.0, 0.016) != Vector2(50, 0):
		failures.append("follow_rate 0 must lock on")


func test_camera_trails_but_never_past_max_lag() -> void:
	var c := MoveFeel.follow(Vector2.ZERO, Vector2(10, 0), 9.0, 40.0, 1.0 / 60.0)
	if c.x <= 0.0 or c.x >= 10.0:
		failures.append("camera should ease toward the hero, got %s" % c)
	c = MoveFeel.follow(Vector2.ZERO, Vector2(200, 0), 9.0, 40.0, 1.0 / 60.0)
	if absf(c.x - 160.0) > 0.01:
		failures.append("camera lag not capped at 40 px: %s" % c)
