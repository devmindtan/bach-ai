extends RefCounted
## User 2026-11-21: poison pools hurt only while the hero stands in them (no lingering poison) and the hero shows
## it (green tint + bubbles, Run.poison_t). Leaving the pool stops both within POISON_LOOK seconds.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_pool_hurts_and_shows_only_while_standing_in_it() -> void:
	var r: Node = Run.new()
	r.buffs = Buffs.new({}, {}, 1)
	r.obstacles = Obstacles.new({"pools": {"count": 0, "radius": 40.0, "dps": 4.0}}, 1400.0, 1)
	r.obstacles.pools.append({"p": Vector2.ZERO, "r": 40.0})
	r.hp = 100.0
	r.player_pos = Vector2.ZERO
	r._step_pools_hazard(1.0)
	_check(is_equal_approx(r.hp, 96.0), "4 hp lost in a second in the pool, got %s" % r.hp)
	_check(r.poison_t > 0.0, "the poison look is on")
	r.player_pos = Vector2(300, 0)
	r._step_pools_hazard(0.5)
	_check(is_equal_approx(r.hp, 96.0), "no damage once out (no lingering poison)")
	_check(r.poison_t == 0.0, "the look fades right after leaving")
	r.free()
