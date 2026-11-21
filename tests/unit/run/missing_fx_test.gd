extends RefCounted
## Review 2026-11-21: a mistyped effect name failed silently ("nothing on screen"). _add_fx / _ring_fx now
## record and warn, once per sprite:anim.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_missing_effect_is_reported_once() -> void:
	var r: Node = Run.new()
	var fx: Dictionary = r._add_fx("no-such-sprite", "burst", 2.0, 0.0)
	r._add_fx("no-such-sprite", "burst", 2.0, 0.0)
	r._ring_fx(100.0, "also-missing", "burst")
	_check(fx.is_empty(), "nothing is drawn")
	_check(r.missing_fx == PackedStringArray(["no-such-sprite:burst", "also-missing:burst"]),
		"each missing effect recorded once, got %s" % [r.missing_fx])
	r.free()
