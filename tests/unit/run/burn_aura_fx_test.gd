extends RefCounted
## Hoả y (user 2026-11-25): it only sets monsters on fire. The flame ring spinning round the hero took too much
## room; there is no ring now, the burning monsters show it (status-burn on each).

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_no_flame_ring_round_the_hero() -> void:
	var r: Node = Run.new()
	var classes := GameData.load_json("res://assets/data/classes.json")
	r.class_data = classes["mage"]
	r.pool = GameData.load_json("res://assets/data/upgrades_mage.json")
	r.base_stats = classes["mage"]["stats"]
	r.levels = {"arcane_bolt": 1}
	r.enemies = Enemies.new({}, {"max_enemies": 4, "separation": {"push": 0.0}}, {}, 1)
	r._recompute_stats()
	r.sheets["ward-burn"] = SpriteSheet.load_dir("res://assets/sprites/custom/ward-burn", "ward-burn")
	var sp: Dictionary = {}
	for u: Dictionary in r.pool["upgrades"]:
		if String(u.get("id", "")) == "sp_star_pants":
			sp = u["special"]
	r.trigger_special(sp)
	_check(r._fx.is_empty(), "Hoả y still draws %d effect(s) round the hero" % r._fx.size())
	r.free()
