class_name FallingTrees
extends RefCounted
## Cây đổ (Rừng Âm U's own event, design/region-events-plan.md §4B): `waves` times, `interval` s apart,
## a forest tree within `range` px of the player is marked and, `warn` s later, falls toward where the
## player stood: a strip `length` long, `width` wide from its foot. The run hurts the player once per
## tree and the monsters inside; the trunk lies there `linger` s as a wall, then fades.
##
## Example:
##   trees.start(cfg)                         # run_config.json events.falling_trees
##   for f in trees.step(dt, player_pos, tree_feet, rng): ... trees.hits(f, p) ...

const SOURCE := "event.falling_trees"

var marks: Array = []   # [{a: Vector2 foot, d: Vector2 fall direction, t: seconds before it lands}]
var logs: Array = []    # [{a, d, t: seconds left}] fallen trunks (walls)
var length := 150.0
var width := 46.0
var warn := 1.2
var linger := 4.0
var _waves_left := 0
var _interval := 2.5
var _next := 0.0
var _range := 300.0
var _used: Array = []   # feet already picked this event
var felled: Array = []  # feet of trees that fell this run: drawn as stumps from then on (not reset by start)


func start(cfg: Dictionary) -> void:
	marks.clear()
	logs.clear()
	_used.clear()
	_waves_left = int(cfg.get("waves", 3))
	_interval = float(cfg.get("interval", 2.5))
	warn = float(cfg.get("warn", 1.2))
	length = float(cfg.get("length", 150.0))
	width = float(cfg.get("width", 46.0))
	linger = float(cfg.get("linger", 4.0))
	_range = float(cfg.get("range", 300.0))
	_next = 0.0


## Advances by [param dt]; [param feet] = the region's tree positions. Returns the trees that landed.
func step(dt: float, player: Vector2, feet: Array, rng: RandomNumberGenerator) -> Array:
	var landed := []
	for i in range(marks.size() - 1, -1, -1):
		marks[i]["t"] = float(marks[i]["t"]) - dt
		if float(marks[i]["t"]) <= 0.0:
			landed.append(marks[i])
			felled.append(marks[i]["a"])
			logs.append({"a": marks[i]["a"], "d": marks[i]["d"], "t": linger})
			marks.remove_at(i)
	for i in range(logs.size() - 1, -1, -1):
		logs[i]["t"] = float(logs[i]["t"]) - dt
		if float(logs[i]["t"]) <= 0.0:
			logs.remove_at(i)
	if _waves_left > 0:
		_next -= dt
		if _next <= 0.0:
			_next = _interval
			_waves_left -= 1
			var foot := _pick(player, feet, rng)
			var d := (player - foot).normalized() if player.distance_to(foot) > 1.0 else Vector2.RIGHT
			marks.append({"a": foot, "d": d, "t": warn})
	return landed


## The nearest unused tree in range; none in range: a spot `range`/2 from the player (a tree falls anyway).
func _pick(player: Vector2, feet: Array, rng: RandomNumberGenerator) -> Vector2:
	var best := Vector2.INF
	for f: Vector2 in feet:
		if f in _used or f.distance_to(player) > _range:
			continue
		if best == Vector2.INF or f.distance_to(player) < best.distance_to(player):
			best = f
	if best == Vector2.INF:
		best = player + Vector2.from_angle(rng.randf() * TAU) * _range * 0.5
	_used.append(best)
	return best


func busy() -> bool:
	return _waves_left > 0 or not marks.is_empty() or not logs.is_empty()


## True when [param p] lies in the strip of tree [param f] ({a, d}).
func hits(f: Dictionary, p: Vector2, pad := 0.0) -> bool:
	var rel: Vector2 = p - f["a"]
	var along := rel.dot(f["d"])
	var side := absf(rel.dot((f["d"] as Vector2).orthogonal()))
	return along >= 0.0 and along <= length + pad and side <= width * 0.5 + pad


## Fallen trunks are walls: pushes a body of radius [param r] out of each sideways.
func push_out(p: Vector2, r: float) -> Vector2:
	for lg: Dictionary in logs:
		var w := width * 0.3   # the trunk itself, thinner than the crown's hit strip
		var rel: Vector2 = p - lg["a"]
		var along := rel.dot(lg["d"])
		var n := (lg["d"] as Vector2).orthogonal()
		var side := rel.dot(n)
		if along >= 0.0 and along <= length and absf(side) < w + r:
			p += n * ((w + r) * signf(side if side != 0.0 else 1.0) - side)
	return p


## Telegraph: the strip outlined bright on the ground, its fill growing; fallen: a dark trunk + crown,
## fading out over its last second.
func draw(c: CanvasItem) -> void:
	for mk: Dictionary in marks:
		var k := 1.0 - clampf(float(mk["t"]) / maxf(0.01, warn), 0.0, 1.0)
		var pts := _strip(mk, length)
		c.draw_colored_polygon(_strip(mk, length * k), Color(0.95, 0.85, 0.55, 0.22))
		c.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1.0, 0.92, 0.6, 0.9), 3.0)
	for lg: Dictionary in logs:
		var a := clampf(float(lg["t"]), 0.0, 1.0)
		var d: Vector2 = lg["d"]
		var foot: Vector2 = lg["a"]
		c.draw_line(foot, foot + d * length * 0.75, Color(0.22, 0.13, 0.07, a), 16.0)
		c.draw_line(foot, foot + d * length * 0.75, Color(0.45, 0.29, 0.15, a), 10.0)
		c.draw_circle(foot + d * length * 0.8, width * 0.5, Color(0.12, 0.25, 0.14, a))
		c.draw_circle(foot + d * length * 0.8, width * 0.38, Color(0.2, 0.42, 0.22, a))


func _strip(f: Dictionary, len: float) -> PackedVector2Array:
	var d: Vector2 = f["d"]
	var n := d.orthogonal() * width * 0.5
	var a: Vector2 = f["a"]
	return PackedVector2Array([a + n, a + d * len + n, a + d * len - n, a - n])
