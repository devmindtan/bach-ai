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


func test_storm_lingers_two_seconds_pulsing_by_tier() -> void:
	# user 2026-11-22: Bão sét stays 2 s; pulses in that time = its bolt columns (I/II 2, III/IV 3, V 4),
	# each pulse shocks like a strike
	var r := _run()
	var zd: Dictionary = r.pool["skills"]["storm"]["zone"]
	_check(String(zd.get("kind", "")) == "pulse" and is_equal_approx(float(zd.get("time", 0.0)), 2.0), "a 2 s pulse zone")
	_check((zd.get("pulses", []) as Array).map(func(v: Variant) -> int: return int(v)) == [2, 2, 3, 3, 4], "pulses by tier I..V: %s" % [zd.get("pulses")])
	r.levels["storm"] = 5
	r.enemies.spawn("blob", Vector2(0, 0))
	r.enemies.step(0.0001, Vector2(0, 900), Vector2(0, 900))
	r.spawn_zone(zd, _sheet("lightning-storm-v"), "spell", 1.0, Vector2(0, 0), "storm", 40.0)
	var z: Dictionary = r.zones[0]
	r.step_zones(float(z["wait"]) + 0.001)
	var hp0: float = r.enemies.hp[0]
	var pulses := 0
	for i in 220:   # 2.2 s
		var before: float = r.enemies.hp[0]
		r.step_zones(0.01)
		if r.enemies.hp[0] < before:
			pulses += 1
	_check(pulses == 4, "tier V: 4 pulses in 2 s, got %d" % pulses)
	_check(r.enemies.hp[0] < hp0 and r.enemies.statuses_of(0).has("shock"), "the pulses hurt and shock")
	_check(r.zones.is_empty(), "gone after 2 s")
	r.free()
