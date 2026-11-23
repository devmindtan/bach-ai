class_name RegionEvents
extends RefCounted
## Each region's own event (design/region-events-plan.md, design/events.md): Lốc cỏ, Rễ trói (thay Cây đổ
## 2026-11-23), Nước độc dâng. Holds the three events and the run's schedule; steps them (damage, drops, calls) and draws them
## on the run's canvas. Split out of run.gd (roadmap tech debt 6, 2026-11-21), like BossView.
##
## Example:
##   region_ev.run = self; region_ev.times.append([180.0, "tornado"])
##   region_ev.step(dt)   # in _tick;  region_ev.draw()   # in _draw, on the floor

var run   # the Run node (untyped: run.gd's private helpers are reached by name, as BossView does)
var times: Array = []   # [time, kind] this run's own event
var tornado := Tornado.new()     # Lốc cỏ (Đồng cỏ)
var snare := RootSnare.new()     # Rễ trói (Rừng Âm U; replaced Cây đổ, user 2026-11-23)
var tide := PoisonTide.new()     # Nước độc dâng (Đầm Lầy Độc)

const OWN_EVENTS := ["tornado", "root_snare", "poison_tide"]


func step(dt: float) -> void:
	var ev: Dictionary = run.cfg.get("events", {})
	for oe: Array in times:
		if run.clock - dt < float(oe[0]) and float(oe[0]) <= run.clock and String(oe[1]) == "tornado" and not tornado.busy():
			tornado.start(ev.get("tornado", {}), run.player_pos, run.rng)
			run.wave_call = "Sự kiện vùng: Lốc cỏ! Né khỏi đường lốc, dụ quái vào"
			run.wave_call_t = 3.0
			Sfx.play("boss_spawn")
		if run.clock - dt < float(oe[0]) and float(oe[0]) <= run.clock and String(oe[1]) == "root_snare" and not snare.busy():
			snare.start(ev.get("root_snare", {}))
			run.wave_call = "Sự kiện vùng: Rễ trói! Tránh vết nứt sáng xanh"
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
	if snare.busy():
		var rc: Dictionary = ev.get("root_snare", {})
		var feet := []
		if run.obstacles != null:
			for so: Dictionary in run.obstacles.solids:
				if String(so.get("sprite", "")).contains("tree"):
					feet.append(so["p"])
		for ln: Dictionary in snare.step(dt, run.player_pos, feet, run.rng):
			Sfx.play("quake")
			run.shake.add(3.0)
			for q: Vector2 in snare.cluster_points(ln):   # monsters on the line: hurt and rooted
				run.enemies.hit_circle(q, snare.width * 0.5, float(rc.get("monster_damage", 40.0)) / 4.0, 0.0, RootSnare.SOURCE,
					[{"status": "stun", "time": float(rc.get("root_monster", 2.0))}])
			if snare.hits(ln, run.player_pos, run.PLAYER_BODY) and not run.god and not run.buffs.invulnerable() and run._dash_left <= 0.0:
				if not run._spend_ward():
					run._take_hit(float(rc.get("player_damage", 8.0)), RootSnare.SOURCE)
					run.root_t = float(rc.get("root_player", 0.8))   # rooted: cannot walk, still attacks
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
	snare.draw(run, run.sheets, run._sprite_scale)
	tide.draw(run, run.clock)
