extends RefCounted
## Unit tests for area-of-effect skill hitboxes: a monster the player sees inside
## the effect must take damage. The spatial hash is keyed by the monster's feet
## while hitboxes live in body space (a lightning bolt's hit box sits ~45 px above
## the feet) and a boss body is wider than 32 px, so the query padding has to
## cover both (lesson 2026-11-17: lightning / meteor / holy column hit nothing).

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


## A monster whose body centre sits [param up] px above its feet (a tall sprite:
## feet at the bottom of the frame, body in the middle).
func _tall() -> Enemies:
	var monsters := {
		"bolt": {"sprite": "bolt", "behaviour": "chase", "hp": 100.0, "damage": 1.0, "speed": 30.0, "xp": 1.0, "scale": 2},
	}
	var cfg := {"world": {"spawn_ring": [700.0, 800.0], "despawn_distance": 1300.0, "arena_half": 1400.0},
		"separation": {"cell": 48.0, "push": 60.0}, "max_enemies": 50}
	# 24x72 frame, anchor at the feet [12, 62]; body centre [12, 30] -> 64 px above the feet at scale 2
	var sheet := SpriteSheet.from_meta("bolt", {"frames": 1, "frame_size": [24, 72], "fps": 8.0, "anchor": [12.0, 62.0],
		"body": {"anim": "default", "center": [12.0, 30.0], "radius": 8.0}})
	var e := Enemies.new(monsters, cfg, {"bolt": sheet}, 1)
	e.player_hit_radius = 14.0
	return e


## A monster whose body circle is centred on its feet (a flat slime), body radius 10.
func _flat(radius := 10.0) -> Enemies:
	var monsters := {
		"blob": {"sprite": "blob", "behaviour": "chase", "hp": 100.0, "damage": 1.0, "speed": 30.0, "xp": 1.0, "scale": 2},
	}
	var cfg := {"world": {"spawn_ring": [700.0, 800.0], "despawn_distance": 1300.0, "arena_half": 1400.0},
		"separation": {"cell": 48.0, "push": 60.0}, "max_enemies": 50}
	var sheet := SpriteSheet.from_meta("blob", {"frames": 1, "frame_size": [24, 24], "fps": 8.0, "anchor": [12.0, 12.0],
		"body": {"anim": "default", "center": [12.0, 12.0], "radius": radius * 0.5}})
	var e := Enemies.new(monsters, cfg, {"blob": sheet}, 1)
	e.player_hit_radius = 14.0
	return e


func _settle(e: Enemies) -> void:
	e.step(0.0001, Vector2(0, 300), Vector2(0, 300))


func _rect(center: Vector2, half_w: float, half_h: float) -> SpriteHitbox:
	var hb := SpriteHitbox.new()
	hb.shape = "rect"
	hb.center = center
	hb.half_w = half_w
	hb.half_h = half_h
	hb.active_to = INF
	return hb


func _circle(center: Vector2, radius: float) -> SpriteHitbox:
	var hb := SpriteHitbox.new()
	hb.shape = "circle"
	hb.center = center
	hb.radius = radius
	hb.active_to = INF
	return hb


## A bolt-like effect (lightning, meteor, holy column) draws its hit box ~45 px
## above the feet the hash is keyed by; it must still hit the monster standing there.
func test_rect_hit_box_finds_the_monster_below_it() -> void:
	var e := _tall()
	e.spawn("bolt", Vector2(100, 0))
	_settle(e)
	var hits := e.hit_box(_rect(Vector2(100, -45), 33.0, 32.0), 10.0)
	_check(hits == 1, "a monster whose body is inside the bolt's box must be hit, hits=%d" % hits)
	_check(e.hp[0] < 100.0, "and take the damage, hp=%s" % e.hp[0])


## A wide floor effect (quake, stomp) reaches monsters away from its centre; the
## hash query must cover the whole rectangle, not a 32 px circle.
func test_rect_hit_box_reaches_its_corner() -> void:
	var e := _flat()
	e.spawn("blob", Vector2(55, 0))
	_settle(e)
	var hits := e.hit_box(_rect(Vector2.ZERO, 60.0, 45.0), 10.0)
	_check(hits == 1, "a monster inside the rect's right part must be hit, hits=%d" % hits)


## A boss body is wider than the old 32 px padding: its edge touching a circle
## must count as a hit.
func test_circle_hit_box_reaches_a_boss_body() -> void:
	var e := _flat(84.0)   # body radius 42 px (a boss)
	e.spawn("blob", Vector2(80, 0))
	_settle(e)
	var hits := e.hit_box(_circle(Vector2.ZERO, 40.0), 10.0)
	_check(hits == 1, "a boss whose body overlaps the circle edge must be hit, hits=%d" % hits)


# --- the whole cast path -----------------------------------------------------

## A run with real skill data and sprites, and one flat monster to hit.
func _run(cls: String, levels: Dictionary) -> Node:
	var r: Node = Run.new()
	var classes := GameData.load_json("res://assets/data/classes.json")
	r.class_data = classes[cls]
	r.pool = GameData.load_json("res://assets/data/" + String(classes[cls]["upgrades"]))
	r.base_stats = classes[cls]["stats"]
	r.levels = levels.duplicate()
	r.milestones = Milestones.load_default()
	r._recompute_stats()
	r.rng = RandomNumberGenerator.new()
	r.rng.seed = 3
	r.sheets = {}
	for sk: String in r.pool.get("skills", {}):
		var sd: Dictionary = r.pool["skills"][sk]
		for n: Variant in sd.get("tier_sprites", [sd.get("sprite", sk)]):
			r.sheets[String(n)] = SpriteSheet.load_dir("res://assets/sprites/custom/" + String(n), String(n))
		r.sheets[String(sd.get("sprite", sk))] = SpriteSheet.load_dir("res://assets/sprites/custom/" + String(sd.get("sprite", sk)), String(sd.get("sprite", sk)))
	r.enemies = _flat()
	return r


## Steps the effects until they finish (their animations are under a second).
func _run_fx(r: Node) -> void:
	for i in 240:
		if r._fx.is_empty():
			return
		r._step_fx(1.0 / 60.0)


## Meteor (random, a tall rect box) must damage the monster it lands on.
func test_random_cast_damages_the_monster_it_lands_on() -> void:
	var r := _run("mage", {"meteor": 1})
	var e: Enemies = r.enemies
	e.spawn("blob", Vector2(120, 0))
	_settle(e)
	var ts: Dictionary = r.pool["skills"]["meteor"]
	r._cast("meteor", ts, "random")
	_check(not r._fx.is_empty(), "the meteor cast must create its effect")
	_run_fx(r)
	_check(e.hp[0] < 100.0, "the monster under the meteor must take damage, hp=%s" % e.hp[0])
	r.free()


## A quake rift (random, a circle on the monster) must damage the monster it opens under.
func test_random_circle_cast_damages_the_monster_it_opens_under() -> void:
	var r := _run("knight", {"earthquake": 1})
	var e: Enemies = r.enemies
	e.spawn("blob", Vector2(100, 0))
	_settle(e)
	var ts: Dictionary = r.pool["skills"]["earthquake"]
	r._cast("earthquake", ts, "random")
	_check(not r._fx.is_empty(), "the quake cast must create its effect")
	_run_fx(r)
	_check(e.hp[0] < 100.0, "the monster over the rift must take damage, hp=%s" % e.hp[0])
	r.free()


## A burst cast at the nearest monster must not fly past it: a monster hugging
## the hero has to be hit (the burst used to always land cast_range px away).
func test_nearest_cast_does_not_overshoot_a_close_monster() -> void:
	var r := _run("knight", {"earth_strike": 1})
	var e: Enemies = r.enemies
	e.spawn("blob", Vector2(40, 0))
	_settle(e)
	var ts: Dictionary = r.pool["skills"]["earth_strike"]
	r._cast("earth_strike", ts, "nearest")
	_check(not r._fx.is_empty(), "the stomp cast must create its effect")
	_run_fx(r)
	_check(e.hp[0] < 100.0, "a monster 40 px away must be hit, hp=%s" % e.hp[0])
	r.free()


## The god hammer falls on the nearest monster, however far in its reach it is,
## and its strike_* animation is played (it used to ask for "burst" and draw nothing).
func test_god_hammer_falls_on_the_nearest_monster() -> void:
	var r := _run("knight", {"blade_arc": 1})
	# the knight pool does not own god_hammer in a plain run: give it the reward
	r.rewards.append("god_hammer")
	r.apply_rewards()
	r._recompute_stats()
	var e: Enemies = r.enemies
	e.spawn("blob", Vector2(200, 0))
	_settle(e)
	var ts: Dictionary = r.pool["skills"]["god_hammer"]
	r._cast("god_hammer", ts, "nearest")
	_check(not r._fx.is_empty(), "the hammer must draw an effect")
	_run_fx(r)
	_check(e.hp[0] < 100.0, "the hammer must hit the monster it falls on, hp=%s" % e.hp[0])
	r.free()


## User 2026-11-26: the archer and assassin burst skills (lib/roguefx.py) must create their effect and damage a
## monster where they land.
func test_archer_and_assassin_bursts_damage_the_monster() -> void:
	for pair: Array in [["archer", "arrow_rain", "crowd"],
			["assassin", "smoke_bomb", "self"], ["assassin", "shadow_strike", "nearest"]]:
		var sid := String(pair[1])
		var r := _run(String(pair[0]), {sid: 1})
		var e: Enemies = r.enemies
		e.spawn("blob", Vector2(30, 0) if String(pair[2]) == "self" else Vector2(120, 0))
		_settle(e)
		r._cast(sid, r.pool["skills"][sid], String(pair[2]))
		for dc: Dictionary in r._delayed:   # "self" pulses wait in _delayed; the run's skill step adds them at the hero
			r._add_fx(dc["sprite"], dc["anim"], dc["sc"], dc["dmg"], -1.0, r.player_pos + r._hit_center, dc["sid"], dc["kb"])
		r._delayed.clear()
		_check(not r._fx.is_empty(), "%s: the cast must create its effect" % sid)
		_run_fx(r)
		_check(e.hp[0] < 100.0, "%s: the monster must take damage, hp=%s" % [sid, e.hp[0]])
		r.free()


## design/rogue-kits.md, Tên nảy: an arrow with "bounce" hits a monster, then turns to the next nearest one it has
## not hit and hits it too, a little harder each bounce.
func test_ricochet_arrow_bounces_to_the_next_monster() -> void:
	var r := _run("archer", {"ricochet": 1})
	var e: Enemies = r.enemies
	e.spawn("blob", Vector2(90, 0))
	e.spawn("blob", Vector2(90, 110))
	_settle(e)
	r._cast("ricochet", r.pool["skills"]["ricochet"], "projectile")
	_check(not r._fx.is_empty(), "the cast fires an arrow")
	for i in 240:
		if r._fx.is_empty():
			break
		r._step_fx(1.0 / 60.0)
	_check(e.hp[0] < 100.0, "the first monster is hit, hp=%s" % e.hp[0])
	_check(e.hp[1] < 100.0, "the arrow bounces to the second monster, hp=%s" % e.hp[1])


## design/rogue-kits.md, Dao hồi: the dagger flies out, turns back to the hero and hits the same monster again on the
## way back, then ends at the hero.
func test_boomerang_dagger_hits_out_and_back() -> void:
	var r := _run("assassin", {"boomerang": 1})
	var e: Enemies = r.enemies
	e.spawn("blob", Vector2(70, 0))
	_settle(e)
	r._cast("boomerang", r.pool["skills"]["boomerang"], "projectile")
	var turned := false
	for i in 300:
		if r._fx.is_empty():
			break
		r._step_fx(1.0 / 60.0)
		for f: Dictionary in r._fx:
			if f.has("vel") and Vector2(f["vel"]).x < 0.0:
				turned = true
	_check(turned, "the dagger turns back toward the hero")
	_check(int(e.hits_by.get("boomerang", 0)) >= 2, "it hits on the way out and back, hits=%s" % e.hits_by.get("boomerang", 0))
	_check(r._fx.is_empty(), "it ends when it comes back")
	r.free()


## design/rogue-kits.md, Chim ưng: a companion that stays by the hero all run; on its cooldown it dives at the monster
## with the most hp in reach, rakes it, and flies back.
func test_companion_hawk_dives_at_the_toughest_monster() -> void:
	var r := _run("archer", {"hawk": 1})
	var e: Enemies = r.enemies
	e.spawn("blob", Vector2(60, 0))
	e.spawn("blob", Vector2(150, 40))
	_settle(e)
	e.hp[1] = 300.0   # the toughest
	e.hp_cap[1] = 300.0
	r._step_pets(0.1)
	_check(r._pets.has("hawk"), "the hawk is out with the hero")
	r._cast("hawk", r.pool["skills"]["hawk"], "pet")
	for i in 120:
		r._step_pets(1.0 / 60.0)
		r._step_fx(1.0 / 60.0)
	_check(e.hp[1] < 300.0, "it rakes the toughest monster, hp=%s" % e.hp[1])
	_check(is_equal_approx(e.hp[0], 100.0), "not the nearest one, hp=%s" % e.hp[0])
	_check(String(r._pets["hawk"]["state"]) == "idle", "it flies back to the hero")
	r.free()


## design/rogue-kits.md, Lốc dao: daggers circle the hero for the skill's duration and keep cutting a monster in the
## ring (it is hit again every rehit s), then stop.
func test_blade_orbit_keeps_cutting_round_the_hero() -> void:
	var r := _run("assassin", {"blade_ring": 1})
	var e: Enemies = r.enemies
	e.spawn("blob", Vector2(34, 0))
	_settle(e)
	r._cast("blade_ring", r.pool["skills"]["blade_ring"], "orbit")
	_check(not r._fx.is_empty(), "the daggers come out")
	for i in 60:
		r._step_fx(1.0 / 60.0)
	_check(int(e.hits_by.get("blade_ring", 0)) >= 2, "a monster in the ring is cut more than once, hits=%s" % e.hits_by.get("blade_ring", 0))
	for i in 300:
		r._step_fx(1.0 / 60.0)
	_check(r._fx.is_empty(), "the orbit ends after its duration")
	r.free()


## Regression 2026-11-26: crit chance / mul, Kết liễu and Liên hoàn reached the monsters only when the character
## panel built its breakdown; Ám sát's +15% crit did nothing in a run where the panel was never opened.
func test_hit_stats_reach_the_monsters_without_the_panel() -> void:
	var r := _run("assassin", {"execute": 5, "combo": 1})
	r._recompute_stats()
	var e: Enemies = r.enemies
	_check(e.crit_chance >= 0.15, "Ám sát crit chance reaches the monsters, got %s" % e.crit_chance)
	_check(e.execute_below > 0.1, "Kết liễu reaches the monsters, got %s" % e.execute_below)
	_check(e.combo_per > 0.0, "Liên hoàn reaches the monsters, got %s" % e.combo_per)
	r.free()


## design/rogue-kits.md, Bẫy gai: the cast lays an armed trap on the ground; nothing happens until a monster steps on
## it, then the thorns spring and hurt it.
func test_thorn_trap_waits_until_a_monster_steps_on_it() -> void:
	var r := _run("archer", {"thorn_trap": 1})
	var e: Enemies = r.enemies
	e.spawn("blob", Vector2(220, 0))
	_settle(e)
	r._cast("thorn_trap", r.pool["skills"]["thorn_trap"], "trap")
	_check(r._traps.size() == 1, "one trap is laid, got %d" % r._traps.size())
	for i in 30:
		r._step_traps(1.0 / 60.0)
	_check(r._traps.size() == 1 and is_equal_approx(e.hp[0], 100.0), "it waits while no monster is on it")
	e.pos[0] = Vector2(r._traps[0]["pos"])   # the monster walks onto it
	_settle(e)
	r._step_traps(1.0 / 60.0)
	_check(r._traps.is_empty(), "it springs")
	_run_fx(r)
	_check(e.hp[0] < 100.0, "the thorns hurt the monster on it, hp=%s" % e.hp[0])
	r.free()
