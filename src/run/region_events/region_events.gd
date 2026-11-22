class_name RegionEvents
extends RefCounted
## Each region's own event (design/region-events-plan.md, design/events.md): Lốc cỏ, Cây đổ, Nước độc
## dâng. Holds the three events and the run's schedule; steps them (damage, drops, calls) and draws them
## on the run's canvas. Split out of run.gd (roadmap tech debt 6, 2026-11-21), like BossView.
##
## Example:
##   region_ev.run = self; region_ev.times.append([180.0, "tornado"])
##   region_ev.step(dt)   # in _tick;  region_ev.draw()   # in _draw, on the floor

var run   # the Run node (untyped: run.gd's private helpers are reached by name, as BossView does)
var times: Array = []   # [time, kind] this run's own event
var tornado := Tornado.new()     # Lốc cỏ (Đồng cỏ)
var trees := FallingTrees.new()  # Cây đổ (Rừng Âm U)
var tide := PoisonTide.new()     # Nước độc dâng (Đầm Lầy Độc)

const OWN_EVENTS := ["tornado", "falling_trees", "poison_tide"]


func step(dt: float) -> void:
	var ev: Dictionary = run.cfg.get("events", {})
	for oe: Array in times:
		if run.clock - dt < float(oe[0]) and float(oe[0]) <= run.clock and String(oe[1]) == "tornado" and not tornado.busy():
			tornado.start(ev.get("tornado", {}), run.player_pos, run.rng)
			run.wave_call = "Sự kiện vùng: Lốc cỏ! Né khỏi đường lốc, dụ quái vào"
			run.wave_call_t = 3.0
			Sfx.play("boss_spawn")
		if run.clock - dt < float(oe[0]) and float(oe[0]) <= run.clock and String(oe[1]) == "falling_trees" and not trees.busy():
			trees.start(ev.get("falling_trees", {}))
			run.wave_call = "Sự kiện vùng: Cây đổ! Tránh dải sáng dưới gốc cây"
			run.wave_call_t = 3.0
			Sfx.play("boss_spawn")
		if run.clock - dt < float(oe[0]) and float(oe[0]) <= run.clock and String(oe[1]) == "poison_tide" and not tide.busy():
			tide.start(ev.get("poison_tide", {}), run.player_pos, run.obstacles.pools if run.obstacles != null else [], run.rng)
			run.wave_call = "Sự kiện vùng: Nước độc dâng! Ra khỏi vũng đang sôi"
			run.wave_call_t = 3.0
			Sfx.play("boss_spawn")
	if tide.busy():
		tide.step(dt)
		if tide.inside(run.player_pos):
			run.poison_t = run.POISON_LOOK
			if not run.god and not run.buffs.invulnerable():   # no armor, like the marsh pools
				run.hp -= tide.dps * dt
				run.damage_taken += tide.dps * dt
				run._add_to(run.taken_by, PoisonTide.SOURCE, tide.dps * dt)
		if not tide.busy():   # sunk: the gems where the pools were
			for q: Vector2 in tide.dropped:
				run.pickups.drop(Pickups.COIN, q, 1.0)
	if trees.busy():
		var fc: Dictionary = ev.get("falling_trees", {})
		var feet := []
		if run.obstacles != null:
			for so: Dictionary in run.obstacles.solids:
				if String(so.get("sprite", "")).contains("tree"):
					feet.append(so["p"])
		for f: Dictionary in trees.step(dt, run.player_pos, feet, run.rng):
			Sfx.play("quake")
			run.shake.add(5.0)
			for k in 3:   # three touching circles along the strip (one hit per monster in practice)
				var q: Vector2 = f["a"] + (f["d"] as Vector2) * trees.length * (k * 2 + 1) / 6.0
				run.enemies.hit_circle(q, maxf(trees.width * 0.5, trees.length / 6.0), float(fc.get("monster_damage", 60.0)) / 3.0, 60.0, FallingTrees.SOURCE)
			if trees.hits(f, run.player_pos, run.PLAYER_BODY) and not run.god and not run.buffs.invulnerable() and run._dash_left <= 0.0:
				if not run._spend_ward():
					run._take_hit(float(fc.get("player_damage", 14.0)), FallingTrees.SOURCE)
	if not tornado.busy():
		return
	var tc: Dictionary = ev.get("tornado", {})
	if tornado.step(dt):
		run.enemies.hit_circle(tornado.pos, tornado.radius, float(tc.get("monster_damage", 30.0)), 160.0, Tornado.SOURCE)
	if tornado.hits(run.player_pos) and run.invuln <= 0.0 and not run.god and not run.buffs.invulnerable() and run._dash_left <= 0.0:
		if not run._spend_ward():
			run._take_hit(float(tc.get("player_damage", 8.0)), Tornado.SOURCE)
	if not tornado.busy():   # it just ended: seeds along its path
		for q: Vector2 in tornado.seed_spots():
			run.pickups.drop(Pickups.COIN, q, 1.0)


## The region's own event, drawn on the floor under the monsters.
func draw() -> void:
	tornado.draw(run, run.clock)
	trees.draw(run)
	tide.draw(run, run.clock)
