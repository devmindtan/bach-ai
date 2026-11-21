extends RefCounted
## Review 2026-11-21: an F1 overlay with fps, sim time, monsters, effects, floor redraws and missing FX.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_overlay_text_lists_the_run_numbers() -> void:
	var r: Node = Run.new()
	r.cfg = {"max_enemies": 200}
	var t: String = r.debug_overlay_text(2.5)
	for part in ["FPS", "Mô phỏng 2.50 ms", "Quái 0 / 200", "Hiệu ứng 0", "Thiếu FX: không"]:
		_check(t.contains(part), "overlay shows '%s', got %s" % [part, t])
	r.missing_fx.append("x:burst")
	_check(r.debug_overlay_text(1.0).contains("Thiếu FX: x:burst"), "missing effects listed")
	r.free()
