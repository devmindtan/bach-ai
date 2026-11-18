extends RefCounted
## Lasting zones (user 2026-11-18): the meteor's crater burns monsters that walk
## in after it lands; the blizzard drags monsters toward its eye while it rages.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _run() -> Node:
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
	return r


func _sheet(name: String) -> SpriteSheet:
	return SpriteSheet.load_dir("res://assets/sprites/custom/" + name, name)


func test_meteor_leaves_a_burning_crater_after_it_lands() -> void:
	var r := _run()
	var sh := _sheet("meteor-fall")
	r.enemies.spawn("blob", Vector2(500, 0))   # far away at first
	r.enemies.step(0.0001, Vector2(0, 900), Vector2(0, 900))
	r.spawn_zone(r.pool["skills"]["meteor"]["zone"], sh, "strike", 2.0 * 0.5, Vector2(500, 0), "meteor", 40.0)
	var z: Dictionary = r.zones[0]
	_check(float(z["wait"]) > 0.4, "the zone waits for the impact, %.2fs" % float(z["wait"]))
	r.step_zones(0.1)
	_check(r.enemies.statuses_of(0).is_empty(), "nothing burns before the meteor lands")
	r.step_zones(float(z["wait"]) + 0.05)
	r.step_zones(0.05)
	_check(r.enemies.statuses_of(0).has("burn"), "a monster in the crater burns")
	r.free()


func test_a_pull_zone_drags_monsters_toward_its_centre() -> void:
	# kind "pull" stays available for later skills (not on the blizzard: user 2026-11-18)
	var r := _run()
	var sh := _sheet("blizzard-vortex")
	var at := Vector2(0, 0)
	r.spawn_zone({"kind": "pull", "strength": 70.0}, sh, "burst", 2.0 * 1.2 * 0.5, at, "test", 20.0)
	var z: Dictionary = r.zones[0]
	var p := Vector2(float(z["r"]) * 0.8, 0)
	r.enemies.spawn("blob", p)
	r.enemies.step(0.0001, Vector2(0, 900), Vector2(0, 900))
	var d0: float = r.enemies.center_of(0).distance_to(z["pos"])
	r.step_zones(float(z["wait"]) + 0.01)
	for k in 10:
		r.step_zones(0.05)
	var d1: float = r.enemies.center_of(0).distance_to(z["pos"])
	_check(d1 < d0 - 10.0, "pulled in: %.0f -> %.0f" % [d0, d1])
	r.free()
