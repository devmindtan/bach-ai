class_name ChallengeEvents
extends RefCounted
## The region's shared challenges (design/events.md): Vòng thử thách (ChallengeRing), Thu thập sao and
## Săn tinh anh (FieldChallenge). Holds their schedule, starts them, pays out chest + coins, and draws
## them on the run's canvas. Split out of run.gd (roadmap tech debt 6, 2026-11-21), like RegionEvents.
##
## Example:
##   challenges.run = self; challenges.ring_times.append(60.0)
##   challenges.step(dt)   # in _tick;  challenges.draw()   # in _draw

var run   # the Run node (untyped: its private helpers are reached by name, as BossView does)
var ring := ChallengeRing.new()        # Vòng thử thách
var field := FieldChallenge.new()      # Thu thập sao / Săn tinh anh
var ring_cfg: Dictionary = {}
var ring_times: Array = []    # clock times the region opens a ring
var field_times: Array = []   # [time, "collect" | "hunt"]


func step(dt: float) -> void:
	_step_ring(dt)
	_step_field(dt)


func draw() -> void:
	_draw_ring()
	_draw_field()


## Thu thập sao / Săn tinh anh (FieldChallenge, user 2026-11-21): start at the region's event times when no other
## challenge runs; done drops a chest and coins at the hero.
func _step_field(dt: float) -> void:
	var ev: Dictionary = run.cfg.get("events", {})
	for fe: Array in field_times:
		if run.clock - dt < float(fe[0]) and float(fe[0]) <= run.clock and not field.active() and not ring.active:
			if fe[1] == "collect":
				var c: Dictionary = ev.get("collect", {})
				var pts := []
				for k in int(c.get("count", 5)):
					var p: Vector2 = run.player_pos + Vector2.from_angle(k * TAU / float(c.get("count", 5)) + run.rng.randf()) * float(c.get("spread", 260.0)) * run.rng.randf_range(0.5, 1.0)
					var lim: float = run._arena_half - 30.0
					pts.append(p.clamp(Vector2(-lim, -lim), Vector2(lim, lim)))
				field.start_collect(pts, float(c.get("limit", 20.0)), float(c.get("pick", 28.0)))
				run.wave_call = "Thu thập sao! Nhặt hết %d sao trong %d giây" % [pts.size(), roundi(field.limit)]
			else:
				var h: Dictionary = ev.get("hunt", {})
				var elite := _hunt_kind()
				if run.enemies.spawn(elite, run.player_pos + Vector2.from_angle(run.rng.randf() * TAU) * float(h.get("distance", 320.0))):
					run.enemies.hunted[run.enemies.count - 1] = 1
				field.start_hunt(float(h.get("limit", 25.0)))
				run.wave_call = "Săn tinh anh! Hạ con bị đánh dấu trong %d giây" % roundi(field.limit)
			run.wave_call_t = 3.0
	match field.step(dt, run.player_pos, run.enemies.hunted_alive()):
		"done":
			run._drop_chest(run.player_pos + Vector2(24, 0))
			var g := int(ev.get(field.kind if field.kind != "" else "collect", {}).get("gold", 10))
			for k in g:
				run.pickups.drop(Pickups.COIN, run.player_pos + Vector2.from_angle(k * 2.4) * (20.0 + 3.0 * k), 1.0)
			run.wave_call = "Hoàn thành thử thách!"
			run.wave_call_t = 2.5
			Sfx.play("chest")
		"fail":
			run.wave_call = "Thử thách thất bại"
			run.wave_call_t = 2.0


## The elite to hunt: the first elite of this run.stage's waves (the region's), else a goblin elite.
func _hunt_kind() -> String:
	for w: Variant in run.stage.get("waves", []):
		if w is Dictionary and String(w.get("monster", "")).ends_with("@elite"):
			return String(w["monster"])
	return "goblin@elite"


## Stars to collect and the hunted elite's mark, with the challenge's count / time left over the hero.
func _draw_field() -> void:
	if not field.active():
		return
	var pulse := 0.5 + 0.5 * sin(run.clock * 6.0)
	if field.kind == "collect":
		for p: Vector2 in field.stars:
			var pts := PackedVector2Array()
			for k in 10:
				var a := -PI / 2.0 + k * PI / 5.0
				pts.append(p + Vector2.from_angle(a) * (11.0 if k % 2 == 0 else 5.0) * (1.0 + 0.15 * pulse))
			run.draw_colored_polygon(pts, Color(1.0, 0.85, 0.3))
			run.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.35, 0.2, 0.05), 1.5)
			run.draw_arc(p, 18.0 + 4.0 * pulse, 0.0, TAU, 20, Color(1.0, 0.9, 0.4, 0.5), 2.0)
	else:
		for i in run.enemies.count:
			if run.enemies.hunted[i] == 1 and run.enemies.state[i] != Enemies.DYING:
				var c: Vector2 = run.enemies.center_of(i)
				var r: float = run.enemies.k_radius[run.enemies.kind[i]] * 1.6
				run.draw_arc(c, r + 3.0 * pulse, 0.0, TAU, 28, Color(1.0, 0.3, 0.25, 0.9), 2.5)
	var left := ("Sao %d/%d" % [field.total - field.stars.size(), field.total]) if field.kind == "collect" else "Săn tinh anh"
	var txt := "%s · %d s" % [left, ceili(field.time_left())]
	run.draw_string(ThemeDB.fallback_font, run.player_pos + Vector2(-60, -64), txt, HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(1.0, 0.9, 0.5))


## Vòng thử thách (design/events.md): opens at the region's event times near the player; stand
## inside to charge it; done drops a chest and coins, time out fails it.
func _step_ring(dt: float) -> void:
	for t: float in ring_times:
		if run.clock - dt < t and t <= run.clock and not ring.active:
			var d := float(ring_cfg.get("distance", 220.0))
			ring.start(run.player_pos + Vector2.from_angle(run.rng.randf() * TAU) * d, float(ring_cfg.get("radius", 70.0)),
				float(ring_cfg.get("need", 8.0)), float(ring_cfg.get("limit", 30.0)), run._arena_half)
			run.wave_call = "Vòng thử thách! Đứng trong vòng %d giây" % roundi(ring.need)
			run.wave_call_t = 3.0
	match ring.step(dt, run.player_pos):
		"done":
			run._drop_chest(ring.center)
			for g in int(ring_cfg.get("gold", 10)):
				run.pickups.drop(Pickups.COIN, ring.center + Vector2.from_angle(g * 2.4) * (14.0 + 3.0 * g), 1.0)
			run.wave_call = "Hoàn thành thử thách!"
			run.wave_call_t = 2.5
			Sfx.play("chest")
		"fail":
			run.wave_call = "Thử thách thất bại"
			run.wave_call_t = 2.0


func _draw_ring() -> void:
	if not ring.active:
		return
	var c := ring.center
	var pulse := 0.5 + 0.5 * sin(run.clock * 4.0)
	run.draw_set_transform(c, 0.0, Vector2(1.0, 0.55))   # flat on the ground
	run.draw_circle(Vector2.ZERO, ring.radius, Color(1.0, 0.85, 0.3, 0.10 + (0.12 if ring.inside else 0.0)))
	run.draw_arc(Vector2.ZERO, ring.radius, 0.0, TAU, 64, Color(1.0, 0.85, 0.35, 0.5 + 0.3 * pulse), 3.0)
	run.draw_arc(Vector2.ZERO, ring.radius - 6.0, -PI / 2.0, -PI / 2.0 + TAU * ring.progress(), 64, Color(1.0, 0.95, 0.5), 5.0)
	run.draw_set_transform(Vector2.ZERO)
	var font := ThemeDB.fallback_font
	var txt := "%d s" % ceili(ring.time_left())
	var at := c + Vector2(-12.0, -ring.radius * 0.55 - 10.0)
	run.draw_string_outline(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0.05, 0.04, 0.08))
	run.draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.92, 0.5))
