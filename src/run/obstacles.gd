class_name Obstacles
extends RefCounted
## Vật cản of a stage (design/obstacles.md): solid props (rocks, trees) scattered from a seed so a stage
## always looks the same, kept `clear_start` px from the centre and `spacing` px apart; they block the
## player and the monsters (push_out). Poison pools (the marsh) hurt the player standing in them
## (in_pool, pool_dps) but block nothing. A grid of CELL px keeps push_out cheap for many monsters.
##
## Example:
##   var o := Obstacles.new(stages.region(n).get("obstacles", {}), arena_half, n * 7919)
##   player_pos = o.push_out(player_pos, body_radius)

const CELL := 128.0

var solids: Array = []   # [{p: Vector2, r: float, sprite: String}]
var pools: Array = []    # [{p: Vector2, r: float}]
var pool_dps := 0.0
var _grid := {}          # Vector2i cell -> [solid index]
var _max_r := 0.0


func _init(def: Dictionary, arena_half: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var clear := float(def.get("clear_start", 220.0))
	var spacing := float(def.get("spacing", 90.0))
	var lim := arena_half - 40.0
	for kind: Dictionary in def.get("solid", []):
		var placed := 0
		var tries := 0
		while placed < int(kind.get("count", 0)) and tries < int(kind.get("count", 0)) * 20:
			tries += 1
			var p := Vector2(rng.randf_range(-lim, lim), rng.randf_range(-lim, lim))
			if p.length() < clear or not _free(p, spacing):
				continue
			add_solid(p, float(kind.get("radius", 12.0)), String(kind.get("sprite", "")))
			placed += 1
	var pd: Dictionary = def.get("pools", {})
	pool_dps = float(pd.get("dps", 0.0))
	var made := 0
	var tries2 := 0
	while made < int(pd.get("count", 0)) and tries2 < int(pd.get("count", 0)) * 20:
		tries2 += 1
		var q := Vector2(rng.randf_range(-lim, lim), rng.randf_range(-lim, lim))
		var r := float(pd.get("radius", 40.0))
		if q.length() < clear or not _free(q, r + 30.0) or not _pool_free(q, r * 2.5):
			continue
		add_pool(q, r)
		made += 1


func add_solid(p: Vector2, r: float, sprite: String) -> void:
	solids.append({"p": p, "r": r, "sprite": sprite})
	_max_r = maxf(_max_r, r)
	var c := _cell(p)
	if not _grid.has(c):
		_grid[c] = []
	_grid[c].append(solids.size() - 1)


func add_pool(p: Vector2, r: float) -> void:
	pools.append({"p": p, "r": r})


## [param p] moved out of every solid it overlaps (a body of radius [param r]); unchanged when clear.
func push_out(p: Vector2, r: float) -> Vector2:
	if solids.is_empty():
		return p
	var c := _cell(p)
	var reach := int(ceil((r + _max_r) / CELL))
	for gx in range(c.x - reach, c.x + reach + 1):
		for gy in range(c.y - reach, c.y + reach + 1):
			for i: int in _grid.get(Vector2i(gx, gy), []):
				var s: Dictionary = solids[i]
				var d: Vector2 = p - s["p"]
				var need := float(s["r"]) + r
				var l := d.length()
				if l < need:
					p = (s["p"] as Vector2) + (d / l if l > 0.001 else Vector2.RIGHT) * need
	return p


## True when [param p] stands in a poison pool.
func in_pool(p: Vector2) -> bool:
	for pl: Dictionary in pools:
		if p.distance_to(pl["p"]) <= float(pl["r"]):
			return true
	return false


func _free(p: Vector2, spacing: float) -> bool:
	for s: Dictionary in solids:
		if p.distance_to(s["p"]) < spacing:
			return false
	return true


func _pool_free(p: Vector2, spacing: float) -> bool:
	for pl: Dictionary in pools:
		if p.distance_to(pl["p"]) < spacing:
			return false
	return true


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))
