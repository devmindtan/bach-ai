class_name MeteorShower
extends RefCounted
## Mưa thiên thạch (design/events.md, after Risk of Rain 2's Glowing Meteorite): for `duration` seconds a
## meteor is marked every `interval` s at a random point within `spread` px of the player and lands
## `warn` s later; at most `max_marks` marks at once. step() returns where meteors landed this step;
## the run hurts whatever stands inside (hits) — the player and the monsters alike.
##
## Example:
##   shower.start(cfg)          # run_config.json events.meteor
##   for p in shower.step(dt, player_pos, rng): if shower.hits(p, player_pos): ...

var active := false
var marks: Array = []   # [{p: Vector2, t: seconds left before it lands}]
var radius := 36.0
var warn := 1.2
var _left := 0.0
var _interval := 0.5
var _spread := 150.0
var _max := 4
var _next := 0.0


func start(cfg: Dictionary) -> void:
	active = true
	marks.clear()
	_left = float(cfg.get("duration", 10.0))
	_interval = maxf(0.05, float(cfg.get("interval", 0.6)))
	warn = float(cfg.get("warn", 1.2))
	radius = float(cfg.get("radius", 36.0))
	_spread = float(cfg.get("spread", 150.0))
	_max = int(cfg.get("max_marks", 4))
	_next = 0.0


## Advances by [param dt]; returns the points where meteors landed.
func step(dt: float, player: Vector2, rng: RandomNumberGenerator) -> Array:
	var landed := []
	for i in range(marks.size() - 1, -1, -1):
		marks[i]["t"] = float(marks[i]["t"]) - dt
		if float(marks[i]["t"]) <= 0.0:
			landed.append(marks[i]["p"])
			marks.remove_at(i)
	if active:
		_left -= dt
		_next -= dt
		if _left <= 0.0:
			active = false
		elif _next <= 0.0 and marks.size() < _max:
			for attempt in 8:   # marks never overlap (unreadable, and a double hit); no room: next step
				var at := player + Vector2.from_angle(rng.randf() * TAU) * _spread * sqrt(rng.randf())
				if _clear(at):
					marks.append({"p": at, "t": warn})
					_next = _interval
					break
	return landed


func _clear(at: Vector2) -> bool:
	for mk: Dictionary in marks:
		if (mk["p"] as Vector2).distance_to(at) < radius * 2.0:
			return false
	return true


## True while marks are still falling (the shower ends once the last one lands).
func busy() -> bool:
	return active or not marks.is_empty()


## True when [param who] stands inside a meteor landing at [param p].
func hits(p: Vector2, who: Vector2) -> bool:
	return p.distance_to(who) <= radius
