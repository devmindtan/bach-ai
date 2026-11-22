extends RefCounted
## Sóng kiếm redesign (design/cleave-wave-redesign.md): waves fan toward the target (no wasted back /
## side waves), each hits a monster once, the wave widens as it flies, level 4+ splits at the end.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_wave_fan_angles_by_level() -> void:
	var ts: Dictionary = GameData.load_json("res://assets/data/upgrades_knight.json")["skills"]["cleave_wave"]
	_check(Run.wave_fan(1, 0.0) == [0.0], "one wave straight at the target")
	var two: Array = Run.wave_fan(2, 15.0)
	_check(two.size() == 2 and is_equal_approx(absf(float(two[0])), 15.0) and float(two[0]) == -float(two[1]), "two waves at ±15°: %s" % [two])
	var three: Array = Run.wave_fan(3, 25.0)
	_check(three.has(0.0) and three.size() == 3, "three waves 0, ±25: %s" % [three])
	_check(ts.has("spread_deg") and ts.has("grow") and ts.has("split"), "data: spread_deg, grow, split")
	_check(not ts.has("rehit"), "no rehit: one hit per monster per wave")


func test_wave_scale_grows_along_its_flight() -> void:
	_check(is_equal_approx(Run.wave_grow({"from": 0.8, "to": [1.3]}, 1, 0.0), 0.8), "starts at 0.8")
	_check(is_equal_approx(Run.wave_grow({"from": 0.8, "to": [1.3]}, 1, 1.0), 1.3), "ends at 1.3")
