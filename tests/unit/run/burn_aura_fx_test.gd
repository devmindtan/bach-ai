extends RefCounted
## Hoả y (design/special-fx-redesign.md H4): its flame ring was drawn at scale 1 from a 48 px frame (~24 px on a
## 100 px burn); now it is scaled to the card's radius like the other ring effects.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_flame_ring_matches_the_burn_radius() -> void:
	var r: Node = Run.new()
	var classes := GameData.load_json("res://assets/data/classes.json")
	r.class_data = classes["mage"]
	r.pool = GameData.load_json("res://assets/data/upgrades_mage.json")
	r.base_stats = classes["mage"]["stats"]
	r.levels = {"arcane_bolt": 1}
	r.enemies = Enemies.new({}, {"max_enemies": 4, "separation": {"push": 0.0}}, {}, 1)
	r._recompute_stats()
	var sh := SpriteSheet.load_dir("res://assets/sprites/custom/ward-burn", "ward-burn")
	r.sheets["ward-burn"] = sh
	r.trigger_special({"kind": "burn_aura", "fx": "ward-burn", "radius": 100.0, "damage_mul": 0.8, "time": 2.0})
	_check(r._fx.size() == 1, "one flame ring")
	if r._fx.size() == 1:
		var hb := SpriteHitbox.of(sh, "cast", Vector2.ZERO, float(r._fx[0]["scale"]))
		var want := 100.0   # the burn itself uses the plain radius
		_check(absf(hb.radius - want) < 2.0, "ring radius %.1f = burn radius %.1f" % [hb.radius, want])
	r.free()
