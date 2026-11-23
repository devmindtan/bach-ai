class_name RootSnare
extends RefCounted
## Rễ trói (Rừng Âm U's own event, design/region-events-plan.md §4B; replaced Cây đổ, user 2026-11-23):
## `waves` times, `interval` s apart, a root line starts at a forest tree within `range` px of the player and
## runs `length` px toward where the player stood, `width` wide. For `warn` s a glowing crack runs along it,
## then thorny roots burst up: whoever stands in it is rooted (the run: the hero `root_player` s, monsters
## `root_monster` s) and hurt once. The roots stay `linger` s, then sink.
##
## Example:
##   snare.start(cfg)                       # run_config.json events.root_snare
##   for ln in snare.step(dt, player_pos, tree_feet, rng): ... snare.hits(ln, p) ...

const SOURCE := "event.root_snare"
const SPRITE := "root-snare"
const CLUSTER := 26.0          # px between root clusters along a line
const BURST_FRAME := 4         # first frame of the burst in the sprite's "snare" animation (0-2 crack, 3 bulge)

var lines: Array = []   # [{a: Vector2 start, d: Vector2 direction, t: seconds since it appeared, hit: bool}]
var length := 220.0
var width := 28.0
var warn := 1.0
var linger := 1.2
var _waves_left := 0
var _interval := 2.2
var _next := 0.0
var _range := 320.0


func start(cfg: Dictionary) -> void:
	lines.clear()
	_waves_left = int(cfg.get("waves", 4))
	_interval = float(cfg.get("interval", 2.2))
	warn = float(cfg.get("warn", 1.0))
	length = float(cfg.get("length", 220.0))
	width = float(cfg.get("width", 28.0))
	linger = float(cfg.get("linger", 1.2))
	_range = float(cfg.get("range", 320.0))
	_next = 0.0


## Advances by [param dt]; [param feet] = the region's tree positions. Returns the lines whose roots burst
## this step (once each).
func step(dt: float, player: Vector2, feet: Array, rng: RandomNumberGenerator) -> Array:
	var burst := []
	for i in range(lines.size() - 1, -1, -1):
		var ln: Dictionary = lines[i]
		ln["t"] = float(ln["t"]) + dt
		if not bool(ln["hit"]) and float(ln["t"]) >= warn:
			ln["hit"] = true
			burst.append(ln)
		if float(ln["t"]) >= warn + linger + 0.4:   # +0.4: the sink frames
			lines.remove_at(i)
	if _waves_left > 0:
		_next -= dt
		if _next <= 0.0:
			_next = _interval
			_waves_left -= 1
			var a := _pick(player, feet, rng)
			var d := (player - a).normalized() if player.distance_to(a) > 1.0 else Vector2.RIGHT
			lines.append({"a": a, "d": d, "t": 0.0, "hit": false})
	return burst


## The nearest tree in range (roots come out of a tree); none: a spot 200 px from the player.
func _pick(player: Vector2, feet: Array, rng: RandomNumberGenerator) -> Vector2:
	var best := Vector2.INF
	for f: Vector2 in feet:
		if f.distance_to(player) > _range or f.distance_to(player) < 60.0:
			continue
		if best == Vector2.INF or f.distance_to(player) < best.distance_to(player):
			best = f
	if best == Vector2.INF:
		best = player + Vector2.from_angle(rng.randf() * TAU) * 200.0
	return best


func busy() -> bool:
	return _waves_left > 0 or not lines.is_empty()


## True when [param p] lies on root line [param ln] ({a, d}), [param pad] px wider.
func hits(ln: Dictionary, p: Vector2, pad := 0.0) -> bool:
	var rel: Vector2 = p - ln["a"]
	var along := rel.dot(ln["d"])
	var side := absf(rel.dot((ln["d"] as Vector2).orthogonal()))
	return along >= 0.0 and along <= length + pad and side <= width * 0.5 + pad


## Points along line [param ln] where a root cluster stands.
func cluster_points(ln: Dictionary) -> Array:
	var out := []
	var n := maxi(2, int(length / CLUSTER))
	for k in n:
		out.append((ln["a"] as Vector2) + (ln["d"] as Vector2) * (CLUSTER * 0.5 + k * CLUSTER))
	return out


## Draws every line with the root-snare sprite: the crack frames stretch over `warn`, then the burst, hold and
## sink frames. Clusters further along burst a little later so the roots run toward the player.
func draw(c: CanvasItem, sheets: Dictionary, scale: float) -> void:
	var sh: SpriteSheet = sheets.get(SPRITE)
	if sh == null:
		return
	var anim := sh.animation("snare")
	var frames := int(anim.get("frames", 11))
	var dens := scale * float(sh.meta.get("px_scale", 1.0))
	for ln: Dictionary in lines:
		var pts := cluster_points(ln)
		for k in pts.size():
			var t := float(ln["t"]) - k * 0.03
			var f: int
			if t < warn:
				f = clampi(int(t / maxf(0.01, warn) * 3.0), 0, 2) if t >= 0.0 else 0
			elif t < warn + 0.1:
				f = 3
			elif t < warn + 0.35:
				f = BURST_FRAME + mini(2, int((t - warn - 0.1) / 0.08))
			elif t < warn + linger:
				f = 7 + int(t * 4.0) % 2
			else:
				f = mini(frames - 1, 9 + int((t - warn - linger) / 0.2))
			sh.draw_index(c, int(anim.get("start", 0)) + f, pts[k], dens, k % 2 == 1)
