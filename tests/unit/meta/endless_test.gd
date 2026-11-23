extends RefCounted
## Chế độ Vô tận (design/endless.md): the stage loops in Vòng, each tougher; the wave clock wraps.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_spans_wrap_at_duration() -> void:
	var s := Endless.spans(299.9, 300.1, 300.0)
	_check(s.size() == 2, "a step over the end of the stage does not split: %s" % [s])
	_check(is_equal_approx(float(s[1][0]), 0.0) and float(s[1][1]) < 0.2, "the waves do not start again at 0: %s" % [s])
	_check(Endless.spans(10.0, 10.1, 300.0).size() == 1, "a plain step splits")


func test_cycles_get_tougher() -> void:
	var e := Endless.load_default()
	_check(Endless.cycle(299.0, 300.0) == 0 and Endless.cycle(301.0, 300.0) == 1, "Vòng count is off")
	_check(is_equal_approx(e.hp_mul(0), 1.0) and e.hp_mul(2) > e.hp_mul(1), "hp does not grow per Vòng")
	_check(e.damage_mul(1) > 1.0, "damage does not grow per Vòng")


func test_base_stage_skips_boss_stages() -> void:
	var e := Endless.load_default()
	var st := Stages.load_default()
	_check(e.base_stage(10, st) == 9, "best 10 (a boss stage) should play stage 9, got %d" % e.base_stage(10, st))
	_check(e.base_stage(0, st) == 1, "a new slot should play stage 1")


func test_slot_keeps_best_time() -> void:
	var s := Slot.new({})
	s.record_endless(125.0)
	s.record_endless(90.0)
	_check(is_equal_approx(s.endless_best, 125.0), "the longest Vô tận time is not kept")
	var back := Slot.new({})
	back.from_dict(s.to_dict())
	_check(is_equal_approx(back.endless_best, 125.0), "endless_best is not saved")
