class_name Tornado
extends RefCounted
## Lốc cỏ (Đồng cỏ's own event, design/region-events-plan.md §4A): a telegraph ring of whirling grass
## appears `distance` px from the player, then a tornado runs straight through where the player stood
## at `speed` px/s for `duration` s. Every `tick` s it hurts the monsters inside; the run hurts the
## player on contact (hit_invuln spaces the hits). When it ends, `seeds` coins drop along its path.
##
## Example:
##   tornado.start(cfg, player_pos, rng)   # run_config.json events.tornado
##   if tornado.step(dt): enemies.hit_circle(tornado.pos, tornado.radius, ...)

const SOURCE := "event.tornado"   # damage source id (run_config.json events.source_names)

var pos := Vector2.ZERO
var dir := Vector2.RIGHT
var radius := 70.0
var warn := 1.5
var warn_left := 0.0   # > 0: telegraph only, no damage yet
var path: Array = []   # [Vector2] where it went, for the seed drops
var _left := 0.0
var _speed := 170.0
var _tick := 0.5
var _tick_left := 0.0
var _seeds := 3
var _active := false


func start(cfg: Dictionary, player: Vector2, rng: RandomNumberGenerator) -> void:
	radius = float(cfg.get("radius", 70.0))
	warn = float(cfg.get("telegraph", 1.5))
	warn_left = warn
	_left = float(cfg.get("duration", 9.0))
	_speed = float(cfg.get("speed", 170.0))
	_tick = maxf(0.05, float(cfg.get("tick", 0.5)))
	_tick_left = 0.0
	_seeds = int(cfg.get("seeds", 3))
	var from := Vector2.from_angle(rng.randf() * TAU)
	pos = player + from * float(cfg.get("distance", 220.0))
	dir = -from   # heads through the player's spot
	path = [pos]
	_active = true


## Advances by [param dt]; true on a damage tick (the monsters inside take a hit).
func step(dt: float) -> bool:
	if not _active:
		return false
	if warn_left > 0.0:
		warn_left -= dt
		return false
	pos += dir * _speed * dt
	_left -= dt
	if path.is_empty() or (path[-1] as Vector2).distance_to(pos) > 40.0:
		path.append(pos)
	if _left <= 0.0:
		_active = false
		return false
	_tick_left -= dt
	if _tick_left <= 0.0:
		_tick_left = _tick
		return true
	return false


## True while telegraphing or running.
func busy() -> bool:
	return _active


## True when [param who] is inside the running tornado (never during the telegraph).
func hits(who: Vector2) -> bool:
	return _active and warn_left <= 0.0 and pos.distance_to(who) <= radius


## Where the seed coins drop once it is over: spread evenly along the path it ran.
func seed_spots() -> Array:
	var out := []
	if path.size() < 2:
		return out
	for k in _seeds:
		out.append(path[int(float(k + 1) / float(_seeds + 1) * (path.size() - 1))])
	return out


## Drawn on the run's canvas: telegraph = a flat dashed ring filling in; running = a funnel of grass
## bands spinning, leaves flung round it (pale gold dust, no red: red is the monsters' attacks).
func draw(c: CanvasItem, clock: float) -> void:
	if not _active:
		return
	var dust := Color(0.93, 0.88, 0.62)
	if warn_left > 0.0:
		var k := 1.0 - warn_left / maxf(0.01, warn)
		c.draw_set_transform(pos, 0.0, Vector2(1.0, 0.55))
		for i in 16:   # dashed ring
			var a := i * TAU / 16.0 + clock * 2.0
			c.draw_arc(Vector2.ZERO, radius, a, a + TAU / 32.0, 6, Color(dust, 0.9), 3.0)
		c.draw_arc(Vector2.ZERO, radius * k, 0.0, TAU, 40, Color(dust, 0.6), 2.0)
		c.draw_set_transform(Vector2.ZERO)
		c.draw_line(pos, pos + dir * radius * 1.6, Color(dust, 0.8), 3.0)   # which way it will run
		return
	c.draw_set_transform(pos, 0.0, Vector2(1.0, 0.55))
	c.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(dust, 0.55), 2.0)   # its reach on the ground
	c.draw_set_transform(Vector2.ZERO)
	var greens := [Color(0.55, 0.78, 0.30), Color(0.36, 0.60, 0.22)]
	for b in 7:   # bottom (narrow) to top (wide)
		var y := -b * 16.0
		var w := 10.0 + b * 7.0
		var sway := sin(clock * 9.0 + b * 0.8) * (3.0 + b)
		var ctr := pos + Vector2(sway, y)
		c.draw_set_transform(ctr, 0.0, Vector2(1.0, 0.35))
		c.draw_arc(Vector2.ZERO, w, clock * 12.0 + b, clock * 12.0 + b + PI * 1.4, 18, greens[b % 2], 6.0)
		c.draw_arc(Vector2.ZERO, w, clock * 12.0 + b + PI, clock * 12.0 + b + PI * 1.6, 10, Color(dust, 0.9), 3.0)
		c.draw_set_transform(Vector2.ZERO)
	for i in 6:   # leaves flung round
		var a := clock * 7.0 + i * TAU / 6.0
		var q := pos + Vector2(cos(a) * radius * 0.9, -30.0 + sin(a) * 18.0 - i * 8.0)
		c.draw_rect(Rect2(q, Vector2(4, 3)), Color(0.78, 0.94, 0.48))
