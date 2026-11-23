extends RefCounted
## Unit tests for class passives (classes.json "passive").

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _run(cls: String, levels: Dictionary) -> Node:
	var r: Node = Run.new()
	var classes := GameData.load_json("res://assets/data/classes.json")
	r.class_data = classes[cls]
	r.pool = GameData.load_json("res://assets/data/" + String(classes[cls]["upgrades"]))
	r.base_stats = classes[cls]["stats"]
	r.levels = levels
	r._recompute_stats()
	r.hp = float(r.stats["max_hp"])
	return r


func test_knight_unyielding_below_30_percent_hp() -> void:
	var r := _run("knight", {"blade_arc": 1})
	var full: float = r.skill_damage("blade_arc")
	_check(not r.passive_active(), "not active at full hp")
	r.hp = float(r.stats["max_hp"]) * 0.25
	_check(r.passive_active(), "active under 30% hp")
	_check(is_equal_approx(r.skill_damage("blade_arc"), full * 1.25), "+25%% damage, got %s vs %s" % [r.skill_damage("blade_arc"), full])
	_check(is_equal_approx(r.damage_taken_mul(), 0.7), "takes 30%% less, got %s" % r.damage_taken_mul())
	r.free()


func test_mage_resonance_sets_bonus_vs_statused_monsters() -> void:
	var r := _run("mage", {"arcane_bolt": 1})
	_check(is_equal_approx(r.passive_vs_status(), 0.2), "mage: +20%% vs monsters with a status")
	var k := _run("knight", {"blade_arc": 1})
	_check(is_zero_approx(k.passive_vs_status()), "knight: none")
	r.free()
	k.free()


func test_enemies_take_more_damage_while_they_have_a_status() -> void:
	var monsters := {"blob": {"sprite": "blob", "behaviour": "chase", "hp": 100.0, "damage": 1.0, "speed": 0.0, "xp": 1.0, "scale": 2}}
	var blob := SpriteSheet.from_meta("blob", {"frames": 1, "frame_size": [24, 24], "fps": 8.0, "anchor": [12.0, 12.0],
		"body": {"anim": "default", "center": [12.0, 12.0], "radius": 6.5}})
	var e := Enemies.new(monsters, {"max_enemies": 10, "separation": {"push": 0.0}}, {"blob": blob}, 1)
	e.vs_status_mul = 0.2
	e.spawn("blob", Vector2(30, 0))
	e.spawn("blob", Vector2(-30, 0))
	e.step(0.0001, Vector2(0, 900), Vector2(0, 900))
	e.apply_status(0, "slow", {"mul": 0.5, "time": 5.0}, 0.0, "x")
	e.hit_circle(Vector2.ZERO, 60.0, 10.0, 0.0, "bolt")
	_check(is_equal_approx(e.hp[0], 88.0), "slowed one takes 12, hp %s" % e.hp[0])
	_check(is_equal_approx(e.hp[1], 90.0), "plain one takes 10, hp %s" % e.hp[1])


func test_archer_hawk_eye_still_and_far() -> void:
	var r := _run("archer", {"quick_arrow": 1})
	_check(not r.passive_active(), "Mắt ưng is on before standing still")
	r.still_t = 1.2
	_check(r.passive_active(), "Mắt ưng is off after 1.2 s still")
	_check(is_equal_approx(r.range_mul(), 1.2), "standing still: range x1.2, got %s" % r.range_mul())
	r.still_t = 0.0
	_check(is_equal_approx(r.range_mul(), 1.0), "moving: range changed")
	var k := _run("knight", {"blade_arc": 1})
	_check(is_equal_approx(k.range_mul(), 1.0), "knight range changed by Mắt ưng")
	r.free()
	k.free()


func test_archer_far_hit_deals_more() -> void:
	var monsters := {"blob": {"sprite": "blob", "behaviour": "chase", "hp": 1000.0, "damage": 1.0, "speed": 0.0, "xp": 1.0, "scale": 2}}
	var cfg := {"world": {"spawn_ring": [700.0, 800.0], "despawn_distance": 1300.0, "arena_half": 1400.0},
		"separation": {"cell": 48.0, "push": 60.0}, "max_enemies": 50}
	var sheet := SpriteSheet.from_meta("blob", {"frames": 1, "frame_size": [24, 24], "fps": 8.0, "anchor": [12.0, 12.0],
		"body": {"anim": "default", "center": [12.0, 12.0], "radius": 5.0}})
	var e := Enemies.new(monsters, cfg, {"blob": sheet}, 1)
	e.far_mul = 0.3
	e.far_px = 200.0
	e.spawn("blob", Vector2(300, 0))   # far
	e.spawn("blob", Vector2(50, 0))    # near
	e.step(0.0001, Vector2.ZERO, Vector2.ZERO)
	e.hit_circle(Vector2(300, 0), 20.0, 10.0, 0.0, "quick_arrow")
	e.hit_circle(Vector2(50, 0), 20.0, 10.0, 0.0, "quick_arrow")
	var far_dmg := 1000.0 - e.hp[0]
	var near_dmg := 1000.0 - e.hp[1]
	_check(is_equal_approx(far_dmg, near_dmg * 1.3), "far hit %s should be 1.3x the near hit %s" % [far_dmg, near_dmg])
	var before := e.hp[0]
	e.hit_circle(Vector2(300, 0), 20.0, 10.0, 0.0, "event.root_snare")   # the map's damage: no Mắt ưng bonus
	_check(is_equal_approx(before - e.hp[0], near_dmg), "an event hit got the far bonus: %s vs %s" % [before - e.hp[0], near_dmg])
