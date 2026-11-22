extends RefCounted
## User 2026-11-22: monsters grow stronger silently (no call), only from stage 6, by map (each region its
## own per-minute rates in stages.json regions[].time_scale).

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_silent_from_stage_6_by_region() -> void:
	var cfg := GameData.load_json("res://assets/data/run_config.json")
	var ts: Dictionary = cfg["time_scale"]
	_check(String(ts.get("call", "")) == "", "no on-screen call")
	var st := GameData.load_json("res://assets/data/stages.json")
	var regions: Array = st["regions"]
	var meadow: Dictionary = regions[0].get("time_scale", {})
	var marsh: Dictionary = regions[2].get("time_scale", {})
	_check(is_equal_approx(Run.time_scale_mul(ts, meadow, 5, 240.0, "hp"), 1.0), "stage 5: no growth")
	_check(Run.time_scale_mul(ts, meadow, 6, 240.0, "hp") > 1.0, "stage 6: grows")
	_check(Run.time_scale_mul(ts, marsh, 25, 240.0, "hp") > Run.time_scale_mul(ts, meadow, 8, 240.0, "hp"), "the marsh grows faster than the meadow")
	_check(is_equal_approx(Run.time_scale_mul(ts, meadow, 8, 30.0, "damage"), 1.0), "nothing before the first minute")
