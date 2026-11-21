extends RefCounted
## Giáp theo % (design/armor.md, user 2026-11-21, after Brotato): taken = 1 / (1 + armor / K), K in
## run_config player.armor_k; never immune however much armor; negative armor hurts more.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_armor_reduces_by_percent_with_diminishing_returns() -> void:
	_check(is_equal_approx(Run.armor_mul(0.0, 15.0), 1.0), "no armor: full damage")
	_check(is_equal_approx(Run.armor_mul(15.0, 15.0), 0.5), "15 armor: half")
	_check(Run.armor_mul(300.0, 15.0) > 0.04, "never immune")
	_check(Run.armor_mul(-15.0, 15.0) > 1.4, "negative armor: more damage")
	var cfg := GameData.load_json("res://assets/data/run_config.json")
	_check(float(cfg["player"].get("armor_k", 0.0)) > 0.0, "K in run_config player.armor_k")


func test_a_hit_on_armored_hero_uses_the_percent() -> void:
	var r: Node = Run.new()
	r.cfg = GameData.load_json("res://assets/data/run_config.json")
	r.stats = {"armor": 15.0, "max_hp": 100.0}
	r.hp = 100.0
	r._take_hit(40.0)
	_check(is_equal_approx(r.hp, 100.0 - 40.0 * Run.armor_mul(15.0, float(r.cfg["player"]["armor_k"])) * r.damage_taken_mul()),
		"40 dmg on 15 armor: %s hp left" % r.hp)
	r.free()
