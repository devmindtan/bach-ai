class_name PoisonTide
extends RefCounted
## Nước độc dâng (Đầm Lầy Độc's own event, design/region-events-plan.md §4C): `pools` poison pools
## within `range` px of the player (the marsh's own first) boil for `warn` s, swell to `radius` over
## `grow` s, hold `hold` s, then sink back over `grow` s. Standing inside costs `dps` hp/s with no
## armor (the marsh pools' rule). When they sink, `gems` coins lie at the centres of the first pools.
##
## Example:
##   tide.start(cfg, player_pos, obstacles.pools, rng)   # run_config.json events.poison_tide
##   tide.step(dt); if tide.inside(player_pos): hp -= tide.dps * dt

const SOURCE := "event.poison_tide"
const PHASES := ["warn", "grow", "hold", "sink"]

var spots: Array = []   # [{p: Vector2, r0: float}] the pools that rise
var dps := 6.0
var radius := 110.0
var phase := ""         # "" (idle) | warn | grow | hold | sink
var t := 0.0            # seconds into the phase
var warn := 1.5
var _grow := 1.5
var _hold := 7.0
var _gems := 2
var dropped: Array = []   # set once when it sinks: where the gem coins lie


func start(cfg: Dictionary, player: Vector2, pools: Array, rng: RandomNumberGenerator) -> void:
	dps = float(cfg.get("dps", 6.0))
	radius = float(cfg.get("radius", 110.0))
	warn = float(cfg.get("telegraph", 1.5))
	_grow = maxf(0.05, float(cfg.get("grow", 1.5)))
	_hold = float(cfg.get("hold", 7.0))
	_gems = int(cfg.get("gems", 2))
	var rng_range := float(cfg.get("range", 280.0))
	spots.clear()
	dropped.clear()
	var near := pools.filter(func(pl: Dictionary) -> bool: return player.distance_to(pl["p"]) <= rng_range)
	near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return player.distance_to(a["p"]) < player.distance_to(b["p"]))
	for pl: Dictionary in near:
		if spots.size() < int(cfg.get("pools", 3)) and _apart(pl["p"]):
			spots.append({"p": pl["p"], "r0": float(pl["r"])})
	var tries := 0
	while spots.size() < int(cfg.get("pools", 3)) and tries < 40:   # not enough marsh pools nearby
		tries += 1
		var at := player + Vector2.from_angle(rng.randf() * TAU) * rng_range * (0.45 + 0.55 * rng.randf())
		if _apart(at):
			spots.append({"p": at, "r0": 24.0})
	phase = "warn"
	t = 0.0


## Pools far enough apart that a way out always stays open between them.
func _apart(p: Vector2) -> bool:
	for s: Dictionary in spots:
		if (s["p"] as Vector2).distance_to(p) < radius * 1.6:
			return false
	return true


func step(dt: float) -> void:
	if phase == "":
		return
	t += dt
	var dur := {"warn": warn, "grow": _grow, "hold": _hold, "sink": _grow}
	if t >= float(dur[phase]):
		t = 0.0
		var i := PHASES.find(phase)
		if i == PHASES.size() - 1:
			phase = ""
			for k in mini(_gems, spots.size()):
				dropped.append(spots[k]["p"])
		else:
			phase = PHASES[i + 1]


func busy() -> bool:
	return phase != ""


## The current radius of pool [param s].
func r_of(s: Dictionary) -> float:
	var r0 := float(s["r0"])
	match phase:
		"grow": return lerpf(r0, radius, t / _grow)
		"hold": return radius
		"sink": return lerpf(radius, r0, t / _grow)
	return r0


## True when [param p] stands in a risen pool (never during the telegraph).
func inside(p: Vector2) -> bool:
	if phase == "" or phase == "warn":
		return false
	for s: Dictionary in spots:
		if p.distance_to(s["p"]) <= r_of(s):
			return true
	return false


## Telegraph: bubbles boiling on each pool + a dashed ring at the reach it will swell to; risen: a
## green pool with a bright rim and bubbles.
func draw(c: CanvasItem, clock: float) -> void:
	if phase == "":
		return
	for s: Dictionary in spots:
		var p: Vector2 = s["p"]
		c.draw_set_transform(p, 0.0, Vector2.ONE)   # 2D round = inside()
		if phase == "warn":
			for i in 20:
				var a := i * TAU / 20.0 + clock
				c.draw_arc(Vector2.ZERO, radius, a, a + TAU / 40.0, 4, Color(0.6, 1.0, 0.35, 0.85), 3.0)
		else:
			var r := r_of(s)
			c.draw_circle(Vector2.ZERO, r, Color(0.35, 0.75, 0.2, 0.42))
			c.draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.7, 1.0, 0.4, 0.9), 3.0)
		c.draw_set_transform(Vector2.ZERO)
		for i in 5:   # bubbles
			var a := i * 2.3 + floorf(clock * 3.0 + i) * 1.7
			var q := p + Vector2(cos(a) * 0.6, sin(a) * 0.35) * (r_of(s) if phase != "warn" else float(s["r0"]))
			var k := fmod(clock * 2.0 + i * 0.37, 1.0)
			c.draw_arc(q - Vector2(0, k * 6.0), 2.0 + k * 3.0, 0.0, TAU, 10, Color(0.75, 1.0, 0.5, 1.0 - k), 1.5)
