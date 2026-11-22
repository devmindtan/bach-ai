extends RefCounted
## Lôi ấn (design/special-fx-redesign.md H3): the old effect showed only at the hero; each struck monster now
## gets its own bolt ("strike" of ward-shock) and the hero a rune ("cast").

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_each_struck_monster_gets_a_bolt() -> void:
	var r: Node = Run.new()
	var classes := GameData.load_json("res://assets/data/classes.json")
	r.class_data = classes["mage"]
	r.pool = GameData.load_json("res://assets/data/upgrades_mage.json")
	r.base_stats = classes["mage"]["stats"]
	r.levels = {"arcane_bolt": 1}
	var monsters := {"blob": {"sprite": "blob", "behaviour": "chase", "hp": 1000.0, "damage": 1.0, "speed": 0.0, "xp": 1.0, "scale": 2}}
	var blob := SpriteSheet.from_meta("blob", {"frames": 1, "frame_size": [24, 24], "fps": 8.0, "anchor": [12.0, 12.0],
		"body": {"anim": "default", "center": [12.0, 12.0], "radius": 6.0}})
	r.enemies = Enemies.new(monsters, {"max_enemies": 20, "separation": {"push": 0.0}}, {"blob": blob}, 1)
	r._recompute_stats()
	r.sheets["ward-shock"] = SpriteSheet.load_dir("res://assets/sprites/custom/ward-shock", "ward-shock")
	r.sheets["ward-shock-strike"] = SpriteSheet.load_dir("res://assets/sprites/custom/ward-shock-strike", "ward-shock-strike")
	for k in 3:
		r.enemies.spawn("blob", Vector2(60 + 40 * k, 0))
	r.enemies.step(0.0001, Vector2(0, 900), Vector2(0, 900))
	r.trigger_special({"kind": "chain_shock", "count": 6, "chain": 2, "radius": 120.0, "fx": "ward-shock", "strike_fx": "ward-shock-strike", "damage_mul": 1.7})
	var strikes: Array = r._fx.filter(func(f: Dictionary) -> bool: return String(f["anim"]) == "strike")
	var casts: Array = r._fx.filter(func(f: Dictionary) -> bool: return String(f["anim"]) == "cast")
	_check(strikes.size() == 3, "a bolt on each of the 3 monsters, got %d" % strikes.size())
	_check(casts.size() == 1, "the rune at the hero")
	r.free()
