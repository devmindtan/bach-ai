extends RefCounted
## Bug 2026-11-21: the pause grid's level bar drew one segment per level, and an
## unlimited stat card's cap is 2^30, so the pause screen ran out of memory (OOM kill).

const Panels := preload("res://src/run/run_panels.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_unlimited_card_level_bar_has_no_segments() -> void:
	_check(Panels.badge_segments(1 << 30) == 0, "unlimited card: no per-level segments")
	_check(Panels.badge_segments(5) == 5, "capped card: one segment per level")
	_check(Panels._lv_text(5, 1 << 30).find("1073741824") < 0, "tooltip never shows 2^30")
