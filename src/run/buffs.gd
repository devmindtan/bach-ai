class_name Buffs
extends RefCounted
## Temporary buffs: they appear at random near the player (items.json "buffs",
## run_config.json "buffs"), lie on the ground for a while, and when walked onto
## run for their duration. Active buffs feed PlayerStats as level-1 upgrades, so
## every stat formula, the HUD and the character sheet see them like cards.
##
## Example:
##   var b := Buffs.new(items["buffs"], cfg["buffs"], seed)
##   for id in b.step(delta, player_center): print("got ", id)
##   PlayerStats.compute(base, pool + b.as_upgrades(), levels.merged(b.levels()))

var defs: Dictionary
var ground: Array = []      # [{id, pos, age}]
var active := {}            # id -> seconds left

var _rng := RandomNumberGenerator.new()
var _next := 0.0
var _first_after := 15.0
var _every := Vector2(25.0, 40.0)
var _ring := Vector2(160.0, 300.0)
var lifetime := 20.0
var blink := 4.0
var _max_on_field := 2
var _collect := 22.0
var _picked: Array = []


func _init(p_defs: Dictionary, cfg: Dictionary, seed_value: int) -> void:
	defs = p_defs
	_rng.seed = seed_value
	_first_after = float(cfg.get("first_after", 15.0))
	var ev: Array = cfg.get("spawn_every", [25.0, 40.0])
	_every = Vector2(float(ev[0]), float(ev[1]))
	var rg: Array = cfg.get("spawn_ring", [160.0, 300.0])
	_ring = Vector2(float(rg[0]), float(rg[1]))
	lifetime = float(cfg.get("lifetime", 20.0))
	blink = float(cfg.get("blink", 4.0))
	_max_on_field = int(cfg.get("max_on_field", 2))
	_collect = float(cfg.get("collect_radius", 22.0))
	_next = _first_after


## Advances timers, spawns, ground lifetime and pick-up. Returns the ids picked up. A buff is taken when
## its badge circle (collect_radius) touches the hero's body circle ([param player_radius], user 2026-11-20).
func step(dt: float, player_center: Vector2, player_radius := 0.0) -> Array:
	for id: String in active.keys():
		active[id] = float(active[id]) - dt
		if float(active[id]) <= 0.0:
			active.erase(id)
	_next -= dt
	if _next <= 0.0:
		_next = _rng.randf_range(_every.x, _every.y)
		if ground.size() < _max_on_field and not defs.is_empty():
			# shields granted by equipment are not ground pickups (user 2026-11-18)
			var ids := defs.keys().filter(func(id: String) -> bool:
				return not bool((defs.get(id, {}) as Dictionary).get("special_only", false)))
			var a := _rng.randf() * TAU
			var r := _rng.randf_range(_ring.x, _ring.y)
			ground.append({"id": ids[_rng.randi() % ids.size()], "pos": player_center + Vector2(cos(a), sin(a)) * r, "age": 0.0})
	var got := []
	_picked = got
	var i := 0
	while i < ground.size():
		var g: Dictionary = ground[i]
		g["age"] = float(g["age"]) + dt
		if (g["pos"] as Vector2).distance_to(player_center) <= _collect + player_radius:
			got.append(g["id"])
			activate(String(g["id"]))
			ground.remove_at(i)
			continue
		if float(g["age"]) >= lifetime:
			ground.remove_at(i)
			continue
		i += 1
	return got


## A ground buff's pick-up circle radius (px).
func collect_radius() -> float:
	return _collect


## Ids picked up by the last step().
func picked_ids() -> Array:
	return _picked


## Starts (or refreshes) buff [param id]: for its own duration, or [param seconds]
## when given (Hộ thể's shield lasts 4 s, not the pickup's 6 s).
func activate(id: String, seconds := -1.0) -> void:
	active[id] = seconds if seconds > 0.0 else float(defs.get(id, {}).get("duration", 8.0))


func is_active(id: String) -> bool:
	return active.has(id)


func time_left(id: String) -> float:
	return float(active.get(id, 0.0))


## True while a buff with "invulnerable" runs (the shield).
func invulnerable() -> bool:
	for id: String in active:
		if bool(defs.get(id, {}).get("invulnerable", false)):
			return true
	return false


## Active buffs as upgrade entries ({id, name, effects}) for PlayerStats.
func as_upgrades() -> Array:
	var out := []
	for id: String in active:
		var d: Dictionary = defs.get(id, {})
		out.append({"id": id, "name": d.get("name", id), "kind": "buff", "effects": d.get("effects", {})})
	return out


## {id: 1} for every active buff.
func levels() -> Dictionary:
	var out := {}
	for id: String in active:
		out[id] = 1
	return out
