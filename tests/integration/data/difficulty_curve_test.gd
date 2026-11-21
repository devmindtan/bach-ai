extends RefCounted
## Roadmap item 8 (review 2026-11-21): the stage difficulty curve has no sudden leap or drop, formula stages
## (2-9, 12-19, 22-29) included. Pressure = monster hp spawned per minute (waves x monster hp, the boss left
## out) x the stage's hp and damage multipliers. Each stage is harder than the one before, by at most 40%
## (2026-11-21 values: +7..+25%, boss stages +18..+27%, stage 11 +37%).

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _pressure(st: Stages, monsters: Dictionary, n: int) -> float:
	var d := st.load_stage(n)   # rates already scaled by the stage's rate_mul
	var dur := minf(300.0, float(d.get("duration", 300.0)))
	var tot := 0.0
	for w: Dictionary in d.get("waves", []):
		var m: Dictionary = monsters.get(String(w.get("monster", "")).get_slice("@", 0), {})
		if bool(m.get("boss", false)):
			continue
		var a := maxf(0.0, float(w.get("t_from", 0.0)))
		var b := minf(dur, float(w.get("t_to", dur)))
		if b < a:
			continue
		if w.has("rate"):
			tot += (float(w["rate"]) + float(w.get("rate_end", w["rate"]))) * 0.5 * (b - a) * float(m.get("hp", 0.0))
		else:
			tot += float(w.get("burst", 1)) * float(m.get("hp", 0.0))
	return tot / dur * 60.0 * st.hp_mul(n) * st.damage_mul(n)


func test_each_stage_is_harder_but_never_leaps() -> void:
	var st := Stages.load_default()
	var monsters := GameData.load_json("res://assets/data/monsters.json")
	var prev := _pressure(st, monsters, 1)
	for n in range(2, st.count() + 1):
		var p := _pressure(st, monsters, n)
		var r := p / maxf(1.0, prev)
		_check(r >= 1.0, "stage %d is not easier than %d (x%.2f)" % [n, n - 1, r])
		_check(r <= 1.4, "stage %d does not leap from %d (x%.2f, max x1.40)" % [n, n - 1, r])
		prev = p
