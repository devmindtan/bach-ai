extends RefCounted
## Scale theo chỉ số (roadmap 2026-11-21, after Brotato's per-weapon scaling): a skill's "scale" sums
## stat x coefficient as its base damage; without "scale" it stays damage x damage_mul.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _run(cls: String) -> Node:
	var r: Node = Run.new()
	r.cfg = GameData.load_json("res://assets/data/run_config.json")
	r.pool = GameData.load_json("res://assets/data/upgrades_%s.json" % cls)
	return r


func test_scale_sums_stats() -> void:
	var r := _run("knight")
	r.pool["skills"]["probe"] = {"scale": {"damage": 1.0, "max_hp": 0.1, "armor": 2.0}}
	var st := {"damage": 20.0, "max_hp": 100.0, "armor": 5.0}
	_check(is_equal_approx(r.skill_damage("probe", st), 20.0 + 10.0 + 10.0), "20 + 100*0.1 + 5*2 = 40, got %s" % r.skill_damage("probe", st))
	r.pool["skills"]["plain"] = {"damage_mul": 1.5}
	_check(is_equal_approx(r.skill_damage("plain", st), 30.0), "no scale: damage x damage_mul")
	r.free()


func test_some_skills_scale_on_other_stats() -> void:
	var seen := {}
	for cls in ["knight", "mage"]:
		var r := _run(cls)
		for id: String in r.pool["skills"]:
			for k: String in r.pool["skills"][id].get("scale", {}):
				seen[k] = true
		r.free()
	for k in ["max_hp", "armor", "move_speed"]:
		_check(seen.has(k), "a skill scales on " + k)
