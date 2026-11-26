extends RefCounted
## HUD 6D.1 (design/ux/hud.md): arrows at the screen edge point at a boss or elite off screen, kept
## clear of the top and bottom HUD bands; the boss bar's "recent damage" trail holds, then catches up.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_edge_point_sits_on_the_inner_rect_along_the_direction() -> void:
	var area := Rect2(20, 80, 1240, 540)   # screen minus margins and the HUD bands
	var c := area.get_center()
	var right := RunHud.edge_point(c, Vector2(1, 0), area)
	_check(is_equal_approx(right.x, area.end.x) and is_equal_approx(right.y, c.y), "straight right: on the right edge, got %s" % right)
	var up := RunHud.edge_point(c, Vector2(0, -1), area)
	_check(is_equal_approx(up.y, area.position.y), "straight up: under the top band, got %s" % up)
	var diag := RunHud.edge_point(c, Vector2(1, 1).normalized(), area)
	_check(area.grow(0.01).has_point(diag) and (is_equal_approx(diag.x, area.end.x) or is_equal_approx(diag.y, area.end.y)), "diagonal: on an edge, got %s" % diag)


func test_trail_holds_then_catches_up() -> void:
	var t := RunHud.trail_step(1.0, 0.6, 0.0, 0.1)   # just hit: trail stays, hold starts
	_check(is_equal_approx(t[0], 1.0) and t[1] > 0.0, "the trail holds right after a hit, got %s" % [t])
	var trail := 1.0
	var hold := float(t[1])
	for k in 30:
		var r := RunHud.trail_step(trail, 0.6, hold, 0.05)
		trail = r[0]
		hold = r[1]
	_check(absf(trail - 0.6) < 0.01, "after 1.5 s the trail caught up to the bar, got %.2f" % trail)
	var up := RunHud.trail_step(0.4, 0.7, 0.0, 0.05)   # healed: the trail jumps up with the bar
	_check(is_equal_approx(up[0], 0.7), "a rising bar lifts the trail at once")


## User 2026-11-26: giáp ảo (an armor buff such as Khiên ảo +12) shows as a grey part after the hp on the hp bar:
## the hp the extra armor saves, i.e. hp x (damage taken without it / with it - 1).
func test_ward_extra_is_the_hp_the_buff_armor_saves() -> void:
	const RunScript := preload("res://src/run/run.gd")
	var k := 15.0
	var extra: float = RunScript.ward_extra(100.0, 14.0, 12.0, k)
	var expect := 100.0 * (RunScript.armor_mul(2.0, k) / RunScript.armor_mul(14.0, k) - 1.0)
	_check(is_equal_approx(extra, expect), "ward extra %.2f, expected %.2f" % [extra, expect])
	_check(extra > 0.0, "an armor buff adds a grey part")
	_check(is_zero_approx(RunScript.ward_extra(100.0, 2.0, 0.0, k)), "no buff armor: no grey part")
