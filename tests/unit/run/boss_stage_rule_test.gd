extends RefCounted
## User 2026-11-21: on a boss stage the boss arrives after minute 5, and the stage is won only by killing it
## (the timer alone no longer wins it). Normal stages still end at their duration.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_boss_waves_start_at_five_minutes() -> void:
	for n in ["010", "020", "030"]:
		var d := GameData.load_json("res://assets/data/waves/stage_%s.json" % n)
		var dur := float(d.get("duration", 300.0))
		for w: Dictionary in d["waves"]:
			if String(w.get("monster", "")) in ["king_slime", "tree_boss", "toad_king"]:
				_check(float(w["t_from"]) >= dur, "stage %s: boss at %s s, want >= %s" % [n, w["t_from"], dur])


func test_boss_stage_is_won_only_by_killing_the_boss() -> void:
	var r: Node = Run.new()
	r.duration = 300.0
	r.boss_stage = true
	r.clock = 400.0
	_check(not r.stage_won(), "boss alive at 6:40: not won")
	r._boss_dead = true
	_check(r.stage_won(), "boss killed: won")
	r.boss_stage = false
	r._boss_dead = false
	r.clock = 300.0
	_check(r.stage_won(), "normal stage: won at its duration")
	r.free()
