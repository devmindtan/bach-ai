extends RefCounted
## Unit tests for Stages (assets/data/stages.json, design/progression.md): the
## difficulty curve, boss stages, which wave file a stage plays, rewards.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_scaling_rises_every_stage_without_jumps() -> void:
	var s := Stages.load_default()
	_check(s.count() == 30, "30 stages")
	_check(is_equal_approx(s.hp_mul(1), 1.0) and is_equal_approx(s.damage_mul(1), 1.0) and is_equal_approx(s.rate_mul(1), 1.0), "stage 1 is x1")
	for n in range(2, s.count() + 1):
		for f: String in ["hp_mul", "damage_mul", "rate_mul"]:
			var a: float = s.call(f, n - 1)
			var b: float = s.call(f, n)
			_check(b >= a, "%s rises at stage %d (%.3f -> %.3f)" % [f, n, a, b])
			_check(b <= a * 1.25, "%s does not jump more than 25%% at stage %d (%.3f -> %.3f)" % [f, n, a, b])


func test_boss_and_milestone_stages() -> void:
	var s := Stages.load_default()
	_check(s.is_boss(10) and s.is_boss(20) and s.is_boss(30), "10, 20, 30 are boss stages")
	_check(not s.is_boss(1) and not s.is_boss(11) and not s.is_boss(29), "others are not")


func test_each_stage_has_waves_and_a_boss_where_it_should() -> void:
	var s := Stages.load_default()
	var monsters := GameData.load_json("res://assets/data/monsters.json")
	for n in range(1, s.count() + 1):
		var st := s.load_stage(n)
		var waves: Array = st.get("waves", [])
		_check(not waves.is_empty(), "stage %d has waves" % n)
		_check(int(st.get("number", 0)) == n, "stage %d knows its number" % n)
		var has_boss := false
		for w: Dictionary in waves:
			var m: Variant = monsters.get(String(w.get("monster", "")))
			if m is Dictionary and bool(m.get("boss", false)):   # any region's boss
				has_boss = true
		_check(has_boss == s.is_boss(n), "stage %d: boss in waves = %s" % [n, s.is_boss(n)])
	_check(s.region(15).get("id") == "dark_forest" and s.region(30).get("id") == "poison_marsh", "regions by stage")


func test_waves_are_scaled_by_stage_but_the_boss_stays_single() -> void:
	var s := Stages.load_default()
	var one := s.load_stage(1)
	var nine := s.load_stage(9)
	_check(float(nine["waves"][0]["rate"]) > float(one["waves"][0]["rate"]), "stage 9 spawns faster than stage 1 (same file)")
	var boss_burst := 0
	var monsters := GameData.load_json("res://assets/data/monsters.json")
	for w: Dictionary in s.load_stage(30)["waves"]:
		var m: Variant = monsters.get(String(w.get("monster", "")))
		if m is Dictionary and bool(m.get("boss", false)):   # any region's boss
			boss_burst = int(w.get("burst", 0))
	_check(boss_burst == 1, "one boss at stage 30, got %d" % boss_burst)


func test_rewards_first_win_more_than_repeat() -> void:
	var s := Stages.load_default()
	var first := s.rewards(5, true)
	var again := s.rewards(5, false)
	_check(int(first["gems"]) > int(again["gems"]) and int(again["gems"]) > 0, "first win gives more gems")
	_check(int(s.rewards(10, true)["gems"]) > int(first["gems"]), "boss stage first win gives the most")
	_check(int(s.rewards(20, false)["gold"]) > int(s.rewards(2, false)["gold"]), "gold grows with the stage")
