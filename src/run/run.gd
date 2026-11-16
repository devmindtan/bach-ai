extends Node2D
## One run of one stage: the player survives the stage's waves until the clock
## runs out. Monsters and pickups are packed arrays (Enemies, Pickups) drawn in
## _draw; the HUD and the level-up / pause / end panels live on a CanvasLayer.
##
## Command line (after `--`):
##   --seed=N        fixed random seed
##   --demo          autopilot moves and picks the first card (for shots)
##   --sim-steps=N   simulate N fixed steps per frame (fast-forward for shots)
##   --walk=X,Y      the demo walks in a fixed direction (shots of each view)
##   --no-auto-pick  the demo stops at the first level-up panel (for shots)
##   --hitboxes      draw hit areas: effects (red while dealing damage), monster
##                   bodies, the player's body and pickup radius
##   --bench=N       keep N monsters alive around a god-mode autopilot, print
##                   frame timings after 600 frames, then quit

const DATA := "res://assets/data/"
const SPRITES := "res://assets/sprites/custom/"
const STEP := 1.0 / 60.0
const CLASS_ID := "knight"
const STAGE_FILE := "waves/stage_001.json"

enum State { PLAYING, LEVEL_UP, PAUSED, DEAD, WON }

var state := State.PLAYING
var cfg: Dictionary
var class_data: Dictionary
var pool: Dictionary          # upgrades_<class>.json
var stage: Dictionary
var base_stats: Dictionary
var stats: Dictionary
var levels: Dictionary = {}   # upgrade id -> level

var enemies: Enemies
var pickups: Pickups
var waves: WaveScheduler
var xp_curve: XpCurve
var rng := RandomNumberGenerator.new()
var sheets: Dictionary = {}   # sprite name -> SpriteSheet

# player
var player_pos := Vector2.ZERO
var facing := Vector2.RIGHT     # last move direction (8-dir)
var attack_dir := Vector2.RIGHT # snapped to 4 directions for the sweep
var hp := 100.0
var invuln := 0.0
var level := 1
var xp := 0.0
var gold := 0
var clock := 0.0
var duration := 300.0
var pending_levels := 0
var choices: Array[String] = []
var _moving := false
var _anim := "idle"
var _anim_t := 0.0
var _action_left := 0.0       # time left on a one-shot animation (attack / hurt)
var _blade_cd := 0.5
var _whirl_cd := 1.0
var _tier_cd := {}
var _whirl_left := 0.0
var _whirl_ticks_done := 0
var _fx: Array[Dictionary] = []
var _end_t := 0.0

# options
var demo := false
var sim_steps := 1
var bench := 0
var show_hitboxes := false
var auto_pick := true
var forced_walk := Vector2.ZERO
var _bench_frames := 0
var _bench_tick_us: PackedInt64Array = []
var _bench_frame_us: PackedInt64Array = []
var _bench_last_us := 0
var _demo_pick_t := 0.0

var _sprite_scale := 2.0
var _arena_half := 1400.0
var _hit_center := Vector2(0, -26)
var _camera: Camera2D
var _hud: RunHud
var _panels: RunPanels


func _ready() -> void:
	_parse_args()
	RunInput.register()
	cfg = GameData.load_json(DATA + "run_config.json")
	var classes := GameData.load_json(DATA + "classes.json")
	class_data = classes.get(CLASS_ID, {})
	pool = GameData.load_json(DATA + String(class_data.get("upgrades", "")))
	stage = GameData.load_json(DATA + STAGE_FILE)
	var monsters := GameData.load_json(DATA + "monsters.json")
	duration = float(stage.get("duration", 300.0))
	_sprite_scale = float(cfg.get("world", {}).get("sprite_scale", 2))
	_arena_half = float(cfg.get("world", {}).get("arena_half", 1400.0))
	xp_curve = XpCurve.from_config(cfg.get("xp", {}))

	var names: Array[String] = [String(class_data.get("sprite", "swordsman")), "exp-gem", "gold-coin"]
	for m: String in monsters:
		if not m.begins_with("_"):
			names.append(String(monsters[m].get("sprite", m)))
	for sk: String in pool.get("skills", {}):
		var sd: Dictionary = pool["skills"][sk]
		names.append(String(sd.get("sprite", sk)))
		for tn in sd.get("tier_sprites", []):
			names.append(String(tn))
	for n in names:
		if not sheets.has(n):
			sheets[n] = SpriteSheet.load_dir(SPRITES + n, n)

	enemies = Enemies.new(monsters, cfg, sheets, rng.seed)
	_update_body()
	pickups = Pickups.new(cfg.get("pickups", {}), 400)
	waves = WaveScheduler.new(stage.get("waves", []))
	base_stats = class_data.get("stats", {})
	for sk: String in class_data.get("start_skills", {}):
		levels[sk] = int(class_data["start_skills"][sk])
	_recompute_stats()
	hp = float(stats.get("max_hp", 100.0))

	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = RunHud.new()
	_hud.run = self
	layer.add_child(_hud)
	_panels = RunPanels.new()
	_panels.run = self
	layer.add_child(_panels)

	if bench > 0:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		for i in bench:
			var a := rng.randf() * TAU
			enemies.spawn(enemies.kind_ids[i % enemies.kind_ids.size()],
				Vector2(cos(a), sin(a)) * rng.randf_range(140.0, 700.0))


func _parse_args() -> void:
	var seeded := false
	for a in OS.get_cmdline_user_args():
		if a == "--demo":
			demo = true
		elif a.begins_with("--seed="):
			rng.seed = int(a.get_slice("=", 1))
			seeded = true
		elif a.begins_with("--walk="):
			var xy := a.get_slice("=", 1).split(",")
			forced_walk = Vector2(float(xy[0]), float(xy[1])).normalized()
			demo = true
		elif a.begins_with("--skills="):
			# Debug/testing: force skill levels, e.g. --skills=frost_nova:5,earth_strike:5
			for pair in a.get_slice("=", 1).split(","):
				var kv := pair.split(":")
				if kv.size() == 2:
					levels[kv[0]] = int(kv[1])
			demo = true
		elif a == "--no-auto-pick":
			auto_pick = false
		elif a == "--hitboxes":
			show_hitboxes = true
		elif a.begins_with("--sim-steps="):
			sim_steps = maxi(1, int(a.get_slice("=", 1)))
		elif a.begins_with("--bench="):
			bench = maxi(1, int(a.get_slice("=", 1)))
			demo = true
	if not seeded:
		rng.randomize()


func _process(delta: float) -> void:
	if bench > 0:
		_bench_sample()
	var t0 := Time.get_ticks_usec()
	for _i in sim_steps:
		_tick(STEP if sim_steps > 1 or bench > 0 else minf(delta, 0.05))
	if bench > 0 and _bench_frames > 60:
		_bench_tick_us.append(Time.get_ticks_usec() - t0)
	_camera.position = player_pos.round()
	queue_redraw()
	_hud.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state == State.PLAYING:
			state = State.PAUSED
			_panels.show_pause()
		elif state == State.PAUSED:
			resume()
	elif state == State.LEVEL_UP:
		for i in 3:
			if event.is_action_pressed("choose_%d" % (i + 1)) and i < choices.size():
				choose(i)
	elif (state == State.DEAD or state == State.WON) and event.is_action_pressed("restart"):
		restart()


# --- simulation --------------------------------------------------------------

func _tick(dt: float) -> void:
	_anim_t += dt
	if state == State.DEAD:
		_end_t += dt
		return
	if state == State.LEVEL_UP and demo and auto_pick:
		_demo_pick_t += dt
		if _demo_pick_t > 0.4:
			choose(0)
		return
	if state != State.PLAYING:
		return
	clock += dt
	_move_player(dt)
	_spawn(clock - dt, clock)
	var contact := enemies.step(dt, player_pos, player_pos + _hit_center)
	if contact > 0.0 and invuln <= 0.0 and bench == 0:
		_take_hit(contact)
	invuln = maxf(0.0, invuln - dt)
	hp = minf(float(stats["max_hp"]), hp + float(stats.get("regen", 0.0)) * dt)
	_skills(dt)
	_drops()
	var got := pickups.step(dt, player_pos + _hit_center, float(stats.get("magnet", 1.0)))
	gold += int(got.y)
	if got.x > 0.0:
		_gain_xp(got.x)
	_step_fx(dt)
	if hp <= 0.0:
		_die()
	elif clock >= duration and bench == 0:
		_win()


func _move_player(dt: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if demo:
		dir = forced_walk if forced_walk != Vector2.ZERO else _autopilot()
	_moving = dir.length_squared() > 0.01
	if _moving:
		facing = dir.normalized()
		_update_body()
		attack_dir = Vector2(signf(facing.x), 0.0) if absf(facing.x) >= absf(facing.y) \
			else Vector2(0.0, signf(facing.y))
		player_pos += dir.limit_length(1.0) * float(stats["move_speed"]) * dt
		player_pos = player_pos.clamp(Vector2(-_arena_half, -_arena_half), Vector2(_arena_half, _arena_half))
	_action_left = maxf(0.0, _action_left - dt)
	if _action_left <= 0.0:
		_set_anim("run" if _moving else "idle")


## Demo / bench movement: walk to the nearest monster (so the sweep has
## something to hit), back off when hurt or crowded, keep away from the edge.
func _autopilot() -> Vector2:
	var nearest := Vector2.ZERO
	var best := INF
	var crowd := Vector2.ZERO
	for i in enemies.count:
		if enemies.state[i] == Enemies.DYING:
			continue
		var d := enemies.pos[i] - player_pos
		var l2 := d.length_squared()
		if l2 < best:
			best = l2
			nearest = d
		if l2 < 90.0 * 90.0 and l2 > 0.01:
			crowd -= d / l2 * 40.0
	var dir := Vector2.ZERO
	if best < INF:
		var hurt := hp < float(stats["max_hp"]) * 0.4
		# close in, then creep so the sweep (which follows facing) points at it
		dir = -nearest.normalized() if hurt else nearest.normalized() * (1.0 if best > 45.0 * 45.0 else 0.2)
	var home := -player_pos / maxf(1.0, _arena_half) * 1.5
	return (dir * 0.6 + crowd + home).limit_length(1.0)


func _spawn(t0: float, t1: float) -> void:
	if bench > 0:
		while enemies.living() < bench and enemies.count < enemies.capacity:
			enemies.spawn(enemies.kind_ids[rng.randi() % enemies.kind_ids.size()], enemies.ring_point(player_pos))
		return
	for id in waves.advance(t0, t1):
		enemies.spawn(id, enemies.ring_point(player_pos))


func _take_hit(amount: float) -> void:
	hp -= maxf(1.0, amount - float(stats.get("armor", 0.0)))
	invuln = float(cfg.get("player", {}).get("hit_invuln", 0.6))
	_play_action("hurt")


func _drops() -> void:
	if enemies.kill_pos.is_empty():
		return
	var gold_chance := float(cfg.get("pickups", {}).get("gold_chance", 0.1))
	for i in enemies.kill_pos.size():
		pickups.drop(Pickups.GEM, enemies.kill_pos[i], enemies.kill_xp[i])
		if rng.randf() < gold_chance:
			pickups.drop(Pickups.COIN, enemies.kill_pos[i] + Vector2(10, 0), 1.0)
	enemies.drain_kills()


# --- skills ------------------------------------------------------------------

func _skills(dt: float) -> void:
	var skills: Dictionary = pool.get("skills", {})
	var area := float(stats.get("area", 1.0))
	if levels.get("blade_arc", 0) > 0:
		var s: Dictionary = skills["blade_arc"]
		_blade_cd -= dt
		if _blade_cd <= 0.0:
			_blade_cd = float(stats["cooldown"]) * float(s.get("cooldown_mul", 1.0))
			var dmg := float(stats["damage"]) * float(s.get("damage_mul", 1.0)) \
				* PlayerStats.skill_mul(stats, "skill_damage.blade_arc")
			var sc := _sprite_scale * area * float(s.get("size_mul", 1.0)) \
				* PlayerStats.skill_mul(stats, "skill_area.blade_arc")
			var sprite := String(s.get("sprite", "sword-slash"))
			_aim(sheets.get(sprite), sc)
			_add_fx(sprite, _slash_anim(attack_dir), sc, dmg)
			var back := int(levels.get("back_slash", 0))
			if back > 0:
				var mul := float(s.get("back_damage_mul", 0.5)) + float(s.get("back_damage_per_level", 0.25)) * (back - 1)
				_add_fx(sprite, _slash_anim(-attack_dir), sc, dmg * mul)
			_play_action("attack")
	if levels.get("whirlwind", 0) > 0:
		var w: Dictionary = skills["whirlwind"]
		if _whirl_left > 0.0:
			_whirl_left -= dt
			var dur := float(w.get("duration", 0.9))
			var ticks := maxi(1, int(w.get("ticks", 3)))
			var due := int(floor((dur - maxf(_whirl_left, 0.0)) / dur * ticks)) + 1
			while _whirl_ticks_done < mini(due, ticks):
				_whirl_ticks_done += 1
				var dmg := float(stats["damage"]) * float(w.get("damage_mul", 0.6)) \
					* PlayerStats.skill_mul(stats, "skill_damage.whirlwind")
				for fx in _fx:
					if fx["anim"] == "spin":
						var hb := SpriteHitbox.of(fx["sheet"], "spin", player_pos + _hit_center, float(fx["scale"]))
						if hb != null:
							enemies.hit_box(hb, dmg, 90.0)
		else:
			_whirl_cd -= dt
			if _whirl_cd <= 0.0:
				var haste := float(stats["cooldown"]) / maxf(0.01, float(base_stats.get("cooldown", 1.0)))
				_whirl_cd = float(w.get("cooldown", 3.0)) * haste
				_whirl_left = float(w.get("duration", 0.9))
				_whirl_ticks_done = 0
				var sc := _sprite_scale * area * float(w.get("size_mul", 1.0)) \
					* PlayerStats.skill_mul(stats, "skill_area.whirlwind")
				_add_fx(String(w.get("sprite", "whirlwind")), "spin", sc, 0.0, _whirl_left)


## Auto-aim: turn the slash (4 directions) and the hero towards the nearest
## monster within twice the slash's reach (from its hitbox); otherwise keep
## the walking direction.
	# Tiered AOE skills (frost-nova / earth-strike): one-shot burst centred on
	# the player. Sprite is chosen by the skill's level (I-V), damage/area use
	# the same stats pipeline as the other skills.
	var tier_skills: Array = ["frost_nova", "earth_strike"]
	for tid in tier_skills:
		if levels.get(tid, 0) <= 0 or not skills.has(tid):
			continue
		var ts: Dictionary = skills[tid]
		var tier_names: Array = ts.get("tier_sprites", [])
		var sprite := String(ts.get("sprite", tid))
		if tier_names.size() > 0:
			var ti: int = clampi(int(levels[tid]) - 1, 0, tier_names.size() - 1)
			sprite = String(tier_names[ti])
		var cd_left := float(_tier_cd.get(tid, 0.0)) - dt
		_tier_cd[tid] = cd_left
		if cd_left <= 0.0:
			var haste := float(stats["cooldown"]) / maxf(0.01, float(base_stats.get("cooldown", 1.0)))
			_tier_cd[tid] = float(ts.get("cooldown", 3.5)) * haste
			var dmg := float(stats["damage"]) * float(ts.get("damage_mul", 1.0)) \
				* PlayerStats.skill_mul(stats, "skill_damage." + tid)
			var sc := _sprite_scale * area * float(ts.get("size_mul", 1.0)) \
				* PlayerStats.skill_mul(stats, "skill_area." + tid)
			_add_fx(sprite, "burst", sc, dmg)


func _aim(sheet: SpriteSheet, sc: float) -> void:
	var center := player_pos + _hit_center
	var hb := SpriteHitbox.of(sheet, "slash_right", center, sc)
	var reach := hb.radius * 2.0 if hb != null else 80.0
	var i := enemies.nearest(center, reach)
	if i < 0:
		return
	var d := enemies.center_of(i) - center
	attack_dir = Vector2(signf(d.x), 0.0) if absf(d.x) >= absf(d.y) else Vector2(0.0, signf(d.y))
	if absf(d.x) > 1.0 and not _moving:
		facing = Vector2(signf(d.x), 0.0)
		_update_body()


func _slash_anim(d: Vector2) -> String:
	if d.x > 0.5:
		return "slash_right"
	if d.x < -0.5:
		return "slash_left"
	return "slash_down" if d.y > 0.0 else "slash_up"


## Adds an effect drawn with its anchor on the player's body centre at
## [param sc]. When [param damage] > 0 it hits once, on the animation's active
## frames, through the hitbox stored in the sprite json (SpriteHitbox).
func _add_fx(sprite: String, anim: String, sc: float, damage: float, life := -1.0) -> void:
	var sheet: SpriteSheet = sheets.get(sprite)
	if sheet == null:
		return
	_fx.append({"sheet": sheet, "anim": anim, "t": 0.0, "scale": sc, "damage": damage, "done": damage <= 0.0,
		"life": life if life > 0.0 else sheet.duration(anim)})


func _step_fx(dt: float) -> void:
	var i := 0
	while i < _fx.size():
		var fx: Dictionary = _fx[i]
		fx["t"] = float(fx["t"]) + dt
		if not fx["done"]:
			var hb := SpriteHitbox.of(fx["sheet"], fx["anim"], player_pos + _hit_center, float(fx["scale"]))
			if hb == null:
				fx["done"] = true
			elif hb.is_active(float(fx["t"])):
				enemies.hit_box(hb, float(fx["damage"]))
				fx["done"] = true
		if float(fx["t"]) >= float(fx["life"]):
			_fx.remove_at(i)
		else:
			i += 1


# --- progression -------------------------------------------------------------

func _gain_xp(amount: float) -> void:
	var r := xp_curve.add(level, xp, amount)
	level = r[0]
	xp = r[1]
	if int(r[2]) > 0:
		pending_levels += int(r[2])
		if state == State.PLAYING:
			_open_level_up()


func _open_level_up() -> void:
	choices = UpgradeRoller.roll(pool.get("upgrades", []), levels, 3, rng)
	if choices.is_empty():
		pending_levels = 0
		hp = float(stats["max_hp"])
		return
	state = State.LEVEL_UP
	_demo_pick_t = 0.0
	_panels.show_level_up(choices)


## Applies choice [param index] of the open level-up and continues the run.
func choose(index: int) -> void:
	if state != State.LEVEL_UP or index >= choices.size():
		return
	var id := choices[index]
	levels[id] = int(levels.get(id, 0)) + 1
	var old_max := float(stats.get("max_hp", 100.0))
	_recompute_stats()
	hp += maxf(0.0, float(stats["max_hp"]) - old_max)
	pending_levels -= 1
	_panels.hide_all()
	state = State.PLAYING
	if pending_levels > 0:
		_open_level_up()


func upgrade(id: String) -> Dictionary:
	for u: Dictionary in pool.get("upgrades", []):
		if u.get("id") == id:
			return u
	return {}


func _recompute_stats() -> void:
	stats = PlayerStats.compute(base_stats, pool.get("upgrades", []), levels)


func xp_needed() -> int:
	return xp_curve.xp_to_next(level)


func _die() -> void:
	hp = 0.0
	state = State.DEAD
	_end_t = 0.0
	_set_anim("death")
	print("Run over: lost at %.1fs, level %d, kills %d" % [clock, level, enemies.total_kills])
	_panels.show_end(false)


func _win() -> void:
	state = State.WON
	pickups.pull_all()
	print("Run over: won, level %d, kills %d, gold %d" % [level, enemies.total_kills, gold])
	_panels.show_end(true)


func resume() -> void:
	_panels.hide_all()
	state = State.PLAYING


func restart() -> void:
	get_tree().reload_current_scene()


func _play_action(anim: String) -> void:
	var sheet: SpriteSheet = sheets.get(String(class_data.get("sprite", "swordsman")))
	if sheet == null or not sheet.has_animation(anim):
		return
	if anim == "attack" and _anim == "hurt" and _action_left > 0.0:
		return
	_anim = anim
	_anim_t = 0.0
	_action_left = sheet.duration(anim)


## Player body circle from the class sprite's json "body" (mirrored with the
## sprite): centre offset for contact / pickups / attack pivot, and radius.
func _update_body() -> void:
	var hero: SpriteSheet = sheets.get(String(class_data.get("sprite", "swordsman")))
	var b := SpriteHitbox.body(hero, Vector2.ZERO, _sprite_scale, facing.x < 0.0)
	if b == null:
		push_error("class sprite has no body circle; regenerate it in Sprite Lab")
		return
	_hit_center = b.center
	if enemies != null:
		enemies.player_hit_radius = b.radius


## Which drawn view a direction uses: "down" / "up" when it is mostly
## vertical, otherwise "side" (diagonals included; left = mirrored).
static func _view(d: Vector2) -> String:
	if absf(d.y) > absf(d.x) * 1.5:
		return "down" if d.y > 0.0 else "up"
	return "side"


func _set_anim(anim: String) -> void:
	if _anim != anim:
		_anim = anim
		_anim_t = 0.0


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	var view := Rect2(_camera.position - get_viewport_rect().size * 0.5, get_viewport_rect().size).grow(64.0)
	RunGround.draw(self, view, _arena_half)
	var gem: SpriteSheet = sheets.get("exp-gem")
	var coin: SpriteSheet = sheets.get("gold-coin")
	for i in pickups.count:
		if view.has_point(pickups.pos[i]):
			var sh := gem if pickups.kind[i] == Pickups.GEM else coin
			sh.draw(self, "idle", clock + i * 0.13, pickups.pos[i], _sprite_scale)
	# dying monsters under the living ones
	for pass_dying in [true, false]:
		for i in enemies.count:
			if (enemies.state[i] == Enemies.DYING) != pass_dying or not view.has_point(enemies.pos[i]):
				continue
			var k := enemies.kind[i]
			var a := enemies.anim_of(i)
			var tint := Color(1.0, 0.55, 0.55) if enemies.flash[i] > 0.0 else Color.WHITE
			if enemies.state[i] == Enemies.WINDUP:
				tint = Color(1.0, 0.8, 0.5)
			enemies.k_sheet[k].draw(self, a[0], a[1], enemies.pos[i], enemies.k_scale[k],
				enemies.flip[i] == 1, tint)
	var hero: SpriteSheet = sheets.get(String(class_data.get("sprite", "swordsman")))
	if hero != null:
		var blink := invuln > 0.0 and state == State.PLAYING and int(invuln * 20.0) % 2 == 0
		var tint := Color(1, 1, 1, 0.45) if blink else Color.WHITE
		var acting := (_anim == "attack" or _anim == "hurt") and _action_left > 0.0
		var dir := attack_dir if _anim == "attack" and acting else facing
		var side := _view(dir)
		var anim := _anim if side == "side" or not hero.has_animation(_anim + "_" + side) else _anim + "_" + side
		# while attacking the hero faces the slash (attack_dir), otherwise the walk
		var flip := dir.x < 0.0 and side == "side"
		hero.draw(self, anim, _anim_t, player_pos, _sprite_scale, flip, tint)
	for fx in _fx:
		var sh: SpriteSheet = fx["sheet"]
		var t := fmod(float(fx["t"]), sh.duration(fx["anim"])) if fx["anim"] == "spin" else float(fx["t"])
		sh.draw(self, fx["anim"], t, player_pos + _hit_center, float(fx["scale"]))
	if show_hitboxes:
		_draw_hitboxes(view)
	# hp bar under the hero
	var w := 44.0
	var bar := Rect2(player_pos + Vector2(-w * 0.5, 8.0), Vector2(w, 5.0))
	draw_rect(bar, Color(0.1, 0.05, 0.08))
	draw_rect(Rect2(bar.position, Vector2(w * clampf(hp / float(stats["max_hp"]), 0.0, 1.0), 5.0)), Color(0.85, 0.2, 0.25))


func _draw_hitboxes(view: Rect2) -> void:
	var body := Color(0.3, 1.0, 0.4, 0.8)
	for i in enemies.count:
		if enemies.state[i] != Enemies.DYING and view.has_point(enemies.pos[i]):
			draw_arc(enemies.center_of(i), enemies.k_radius[enemies.kind[i]], 0.0, TAU, 16, body, 1.0)
	var center := player_pos + _hit_center
	draw_arc(center, enemies.player_hit_radius, 0.0, TAU, 16, Color(0.3, 0.7, 1.0), 1.5)
	draw_arc(center, pickups.radius * float(stats.get("magnet", 1.0)), 0.0, TAU, 48, Color(0.3, 0.7, 1.0, 0.35), 1.0)
	for fx in _fx:
		var hb := SpriteHitbox.of(fx["sheet"], fx["anim"], center, float(fx["scale"]))
		if hb != null:
			var on: bool = hb.is_active(float(fx["t"])) or fx["anim"] == "spin"
			hb.draw(self, Color(1.0, 0.2, 0.2, 0.95) if on else Color(1.0, 0.6, 0.2, 0.4), 2.0 if on else 1.0)


# --- bench -------------------------------------------------------------------

func _bench_sample() -> void:
	var now := Time.get_ticks_usec()
	_bench_frames += 1
	if _bench_frames > 61:
		_bench_frame_us.append(now - _bench_last_us)
	_bench_last_us = now
	if _bench_frames >= 660:
		var tick := Array(_bench_tick_us)
		var frame := Array(_bench_frame_us)
		tick.sort()
		frame.sort()
		var avg_tick := 0.0
		for v: int in tick:
			avg_tick += v
		avg_tick /= maxf(1.0, tick.size())
		var avg_frame := 0.0
		for v: int in frame:
			avg_frame += v
		avg_frame /= maxf(1.0, frame.size())
		print("BENCH enemies=%d living=%d sim_ms avg=%.2f p95=%.2f frame_ms avg=%.2f p95=%.2f fps=%.0f" % [
			bench, enemies.living(), avg_tick / 1000.0, tick[int(tick.size() * 0.95)] / 1000.0,
			avg_frame / 1000.0, frame[int(frame.size() * 0.95)] / 1000.0, 1000000.0 / avg_frame])
		get_tree().quit()
