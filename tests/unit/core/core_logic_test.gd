extends RefCounted
## Unit tests for the pure run logic in src/core (XpCurve, UpgradeRoller,
## WaveScheduler, SpatialHash, PlayerStats). No files, no scene tree.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _pool() -> Array:
	return [
		{"id": "a", "max_level": 2, "weight": 1, "effects": {"damage": {"mul": 0.15}}},
		{"id": "b", "max_level": 1, "weight": 1, "effects": {"max_hp": {"add": 20.0}}},
		{"id": "c", "max_level": 5, "weight": 1, "effects": {"cooldown": {"mul": -0.10}}},
		{"id": "d", "max_level": 3, "weight": 0, "effects": {}},
	]


# --- XpCurve -----------------------------------------------------------------

func test_xp_curve_big_gain_gives_at_most_one_level() -> void:
	# user 2026-11-18: one big pickup (elite x8, boss 200) gave many level-ups at once
	var c := XpCurve.from_config({"base": 6.0, "growth": 1.22, "flat": 2.0, "max_levels_per_gain": 1, "overflow_keep": 0.5})
	var r := c.add(1, 0.0, 200.0)
	_check(int(r[2]) == 1 and int(r[0]) == 2, "200 xp at level 1 gives one level, got %s" % [r])
	_check(float(r[1]) <= c.xp_to_next(2) * 0.5, "overflow kept at most half the next bar, got %.1f" % float(r[1]))


func test_run_config_caps_levels_per_gain() -> void:
	var cfg := GameData.load_json("res://assets/data/run_config.json")
	_check(int(cfg["xp"].get("max_levels_per_gain", 0)) == 1, "run_config xp.max_levels_per_gain must be 1")


func test_xp_curve_first_levels_follow_formula() -> void:
	var c := XpCurve.new(6.0, 1.22, 2.0)
	_check(c.xp_to_next(1) == 6, "L1 should need 6, got %d" % c.xp_to_next(1))
	# 6*1.22 + 2 = 9.32 -> 9
	_check(c.xp_to_next(2) == 9, "L2 should need 9, got %d" % c.xp_to_next(2))


func test_xp_curve_is_monotonic() -> void:
	var c := XpCurve.new(6.0, 1.22, 2.0)
	for l in range(1, 60):
		if c.xp_to_next(l + 1) < c.xp_to_next(l):
			_check(false, "xp_to_next drops at level %d" % l)
			return


func test_xp_add_carries_over_multiple_levels() -> void:
	var c := XpCurve.new(6.0, 1.22, 2.0)
	var r := c.add(1, 0.0, 6.0 + 9.0 + 1.0)
	_check(r[0] == 3 and r[2] == 2, "16 xp from L1 should reach L3 (+2), got %s" % [r])
	_check(is_equal_approx(r[1], 1.0), "1 xp should remain, got %s" % r[1])


func test_xp_add_ignores_negative() -> void:
	var c := XpCurve.new(6.0, 1.22, 2.0)
	var r := c.add(2, 3.0, -50.0)
	_check(r[0] == 2 and is_equal_approx(r[1], 3.0) and r[2] == 0, "negative xp should be ignored, got %s" % [r])


# --- UpgradeRoller -----------------------------------------------------------

func test_roll_returns_distinct_ids() -> void:
	var rng := RandomNumberGenerator.new()
	for seed in 50:
		rng.seed = seed
		var ids := UpgradeRoller.roll(_pool(), {}, 3, rng)
		var seen := {}
		for id in ids:
			seen[id] = true
		if seen.size() != ids.size():
			_check(false, "seed %d gave duplicates %s" % [seed, ids])
			return


func test_roll_skips_maxed_and_zero_weight() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ids := UpgradeRoller.roll(_pool(), {"a": 2, "b": 1}, 3, rng)
	_check(ids.size() == 1 and ids[0] == "c", "only c is rollable, got %s" % [ids])


func test_roll_is_deterministic_for_seed() -> void:
	var r1 := RandomNumberGenerator.new()
	var r2 := RandomNumberGenerator.new()
	r1.seed = 42
	r2.seed = 42
	_check(UpgradeRoller.roll(_pool(), {}, 3, r1) == UpgradeRoller.roll(_pool(), {}, 3, r2),
		"same seed should give the same roll")


func test_roll_empty_pool() -> void:
	var rng := RandomNumberGenerator.new()
	_check(UpgradeRoller.roll([], {}, 3, rng).is_empty(), "empty pool should give no ids")


## A milestone skill is a reward, not a card: it is offered only once the slot
## owns it (the run starts it at level 1), never before (design/progression.md).
func test_roll_skips_unowned_unique_skills() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var pool := _pool() + [{"id": "u", "unique": true, "max_level": 5, "weight": 1, "effects": {}}]
	var before := UpgradeRoller.roll(pool, {}, 9, rng)
	_check(not before.has("u"), "an unowned unique skill must not be offered, got %s" % [before])
	_check(before.size() == 3, "the three rollable ordinary upgrades are still offered (d has weight 0), got %s" % [before])
	var after := UpgradeRoller.roll(pool, {"u": 1}, 9, rng)
	_check(after.has("u"), "an owned unique skill is levelled by cards, got %s" % [after])


# --- WaveScheduler -----------------------------------------------------------

func test_wave_total_does_not_depend_on_step() -> void:
	var waves := [{"monster": "slime", "t_from": 0, "t_to": 100, "rate": 1.0, "rate_end": 3.0}]
	var coarse := WaveScheduler.new(waves)
	var fine := WaveScheduler.new(waves)
	var n_coarse := 0
	var n_fine := 0
	var t := 0.0
	while t < 100.0:
		n_coarse += coarse.advance(t, t + 0.5).size()
		t += 0.5
	t = 0.0
	for i in 6000:
		n_fine += fine.advance(t, t + 1.0 / 60.0).size()
		t += 1.0 / 60.0
	# integral of 1 -> 3 over 100 s = 200
	_check(absi(n_coarse - 200) <= 1, "coarse total should be ~200, got %d" % n_coarse)
	_check(absi(n_fine - 200) <= 1, "fine total should be ~200, got %d" % n_fine)


func test_wave_inactive_outside_window() -> void:
	var ws := WaveScheduler.new([{"monster": "bat", "t_from": 45, "t_to": 60, "rate": 10.0}])
	_check(ws.advance(0.0, 44.0).is_empty(), "no spawns before t_from")
	_check(ws.advance(61.0, 90.0).is_empty(), "no spawns after t_to")


func test_burst_fires_once() -> void:
	var ws := WaveScheduler.new([{"monster": "bat", "t_from": 120, "t_to": 120, "burst": 24}])
	_check(ws.advance(119.0, 119.9).is_empty(), "burst not before its time")
	_check(ws.advance(119.9, 120.1).size() == 24, "burst should spawn 24")
	_check(ws.advance(120.1, 200.0).is_empty(), "burst should not repeat")


# --- SpatialHash -------------------------------------------------------------

func test_spatial_hash_finds_neighbours_only() -> void:
	var h := SpatialHash.new(48.0)
	h.insert(0, Vector2(10, 10))
	h.insert(1, Vector2(-30, 20))
	h.insert(2, Vector2(500, 500))
	h.insert(3, Vector2(-5, -5))
	var out := PackedInt32Array()
	h.query(Vector2.ZERO, 40.0, out)
	_check(out.has(0) and out.has(1) and out.has(3), "near points should be found, got %s" % out)
	_check(not out.has(2), "far point should not be found")


func test_spatial_hash_clear() -> void:
	var h := SpatialHash.new(48.0)
	h.insert(0, Vector2.ZERO)
	h.clear()
	var out := PackedInt32Array()
	h.query(Vector2.ZERO, 100.0, out)
	_check(out.is_empty(), "cleared hash should be empty")


# --- PlayerStats -------------------------------------------------------------

func test_stats_apply_mul_and_add_per_level() -> void:
	var base := {"damage": 10.0, "max_hp": 100.0, "cooldown": 1.0}
	var s := PlayerStats.compute(base, _pool(), {"a": 2, "b": 1, "c": 3})
	_check(is_equal_approx(s["damage"], 13.0), "damage 10 * 1.30 = 13, got %s" % s["damage"])
	_check(is_equal_approx(s["max_hp"], 120.0), "max_hp 100 + 20 = 120, got %s" % s["max_hp"])
	_check(is_equal_approx(s["cooldown"], 0.7), "cooldown 1 * 0.7, got %s" % s["cooldown"])


func test_stats_multiplier_floor() -> void:
	var base := {"cooldown": 1.0}
	var s := PlayerStats.compute(base, _pool(), {"c": 50})
	_check(is_equal_approx(s["cooldown"], 0.2), "cooldown multiplier floors at 0.2, got %s" % s["cooldown"])


func test_stats_per_skill_key_defaults_to_one() -> void:
	var pool := [{"id": "w", "max_level": 5, "effects": {"skill_damage.whirlwind": {"mul": 0.25}}}]
	var s := PlayerStats.compute({}, pool, {"w": 2})
	_check(is_equal_approx(PlayerStats.skill_mul(s, "skill_damage.whirlwind"), 1.5), "1 + 0.25*2 = 1.5")
	_check(is_equal_approx(PlayerStats.skill_mul(s, "skill_area.whirlwind"), 1.0), "absent key = 1")
