extends RefCounted
## Roadmap C (user 2026-11-22): the arena edge must cut everything: monsters, numbers and effects past the edge
## were drawn over the dark outside. The mask covers exactly the part of the view outside the arena.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_mask_covers_the_outside_only() -> void:
	var half := 1400.0
	var view := Rect2(Vector2(-1700, -300), Vector2(1280, 720))   # the left edge in view
	var rects: Array = Run.outside_rects(view, half)
	var arena := Rect2(Vector2(-half, -half), Vector2(half * 2, half * 2))
	var covered := 0.0
	for r: Rect2 in rects:
		_check(not r.intersects(arena), "a mask rect overlaps the arena: %s" % r)
		covered += r.get_area()
	_check(is_equal_approx(covered, 300.0 * 720.0), "covers the 300 px of view left of the edge, got %s" % covered)
	_check(Run.outside_rects(Rect2(Vector2(-640, -360), Vector2(1280, 720)), half).is_empty(), "nothing to mask in the middle")
