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
##   --god           the hero takes no damage (shots of the win screen)
##   --stage=N       play waves/stage_00N.json (stage 10: Vua Slime)
##   --dash-at=T     dash at T seconds (needs the dash card, e.g. --skills=dash:1)
##   --monster-hp=N  monsters have N x hp (shots of statuses)
##   --status-all=a,b  every 0.5 s put these statuses on every monster (shots)
##   --pause-view=settings|character  with --pause-at, open that page (shots)
##   --pause-at=T    open the pause panel at T seconds (shots)
##   --offer=a,b,c   the first level-up offers these upgrade ids (shots of the cards)
##   --rewards=a,b   start with these level milestone rewards (shots/tests: design/progression.md)
##   --milestone=N   open the level-N milestone pick at the start (shots)
##   --pick-card=ID  take count card ID at the start and open its skill pick (shots)
##   --no-auto-pick  the demo stops at the first level-up panel (for shots)
##   --hitboxes      draw hit areas: effects (red while dealing damage), monster
##                   bodies, the player's body and pickup radius
##   --bench=N       keep N monsters alive around a god-mode autopilot, print
##                   frame timings after 600 frames, then quit

const DATA := "res://assets/data/"
const SPRITES := "res://assets/sprites/custom/"
const STEP := 1.0 / 60.0
var class_id := "knight"   # Prefs.current().hero (the lobby choice, or --class=)
var stage_number := 1        # --stage=N or from the active slot
var _stage_arg_set := false
var _rewards_arg := false
var stages: Stages
var stage_ground: Dictionary = {}
var run_music := "run"   # the song of this stage's region, or the challenge song
var playing_slot: Slot
var tree_owner: Slot          # whose skill tree applies (the active slot; the preview one in shots)
var skill_tree: SkillTree
var run_result: Dictionary = {}
var _boss_dead := false
var _boss_music := false                # the boss song is on (a boss is alive)
var _boss_check_t := 0.0
var challenge_id := ""        # playing a challenge (design/challenge.md); --challenge=ID for shots
var _win_on_boss := true
var _delayed: Array = []
var profile: Profile                # equipment (Prefs.current().profile())
var won_items: Array[String] = []   # equipment won this run (end screen)
var _gear_plus := 0                   # --gear-plus=N: Cường hoá level of the --gear items (shots)
var specials: Array = []              # Hiệu ứng đặc biệt of worn legendary items (Profile.specials)
var _special_t: Array[float] = []     # per special: seconds to its next trigger (or cooldown left)
var _item_revive_used := false
var elite_kills := 0                  # elites and bosses downed this run (Nhiệm vụ ngày)
var _special_kills: Array[int] = []   # per special: kills counted toward its next kill_proc
var _gear: Array[String] = []       # --gear=a,b (shots: wear these)   # self casts waiting for their pulse (count > 1)
var _chest_open := false   # the next level-up panel comes from a chest
var _chest_sprite := "chest"
var _essence_sprite := "essence-pickup"

enum State { PLAYING, LEVEL_UP, PAUSED, DEAD, WON }

var state := State.PLAYING
var cfg: Dictionary
var class_data: Dictionary
var pool: Dictionary          # upgrades_<class>.json
var stage: Dictionary
var base_stats: Dictionary
var stats: Dictionary
var levels: Dictionary = {}   # upgrade id -> level
var milestones: Milestones    # assets/data/milestones.json
var rewards: Array[String] = []   # level milestone rewards picked in this run (they end with it)
var _ms_queue: Array[int] = []    # milestone levels reached, their pick not shown yet
var _ms_done: Array[int] = []     # milestone levels already offered in this run
var ms_level := 0                 # the milestone level whose pick is open (0 = a normal level-up)
var skill_extra := {}             # skill id -> count added by Thêm đòn / Thêm phép on that skill only
var skill_pick := 0               # > 0: the open panel picks the skill a count card adds to
var _pick_card := ""              # --pick-card=ID (shots)
var _guardian_t := 0.0        # Hộ thể: seconds until the next shield
var _guardian_every := 0.0    # 0 = the slot does not own it
var _guardian_buff := ""
var _guardian_time := 0.0
var _undying_used := false    # Bất tử revives once per run

var enemies: Enemies
var pickups: Pickups
var waves: WaveScheduler
var xp_curve: XpCurve
var rng := RandomNumberGenerator.new()
var sheets: Dictionary = {}   # sprite name -> SpriteSheet

# player
var player_pos := Vector2.ZERO
var facing := Vector2.RIGHT     # last move direction (8-dir)
var face_left := false          # the hero is drawn in the side view only; left = mirrored
var attack_dir := Vector2.RIGHT # towards the nearest monster, snapped to the slash's 4 directions
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
var zones: Array[Dictionary] = []
var _affix_tags: Array = []
var _rage_t := 0.0                    # seconds the "nổi giận" call still shows
var _rage_seen := false
var _boss_hp_share := -1.0
var wave_call := ""                   # the latest wave call ("Bầy dơi kéo tới!"), shown by the HUD
var wave_call_t := 0.0                # seconds the wave call still shows
var _end_t := 0.0
# floating damage numbers (ring buffer, sizes from run_config "ui")
var _num_pos := PackedVector2Array()
var _num_val := PackedFloat32Array()
var _num_t := PackedFloat32Array()   # age in seconds, -1 = free
var _num_next := 0
var _num_life := 0.7
var _num_rise := 36.0
var _num_size := 16

# options
var demo := false
var sim_steps := 1
var bench := 0
var show_hitboxes := false
var auto_pick := true
var offer: Array[String] = []   # forced cards for the first level-up (--offer)
var forced_walk := Vector2.ZERO
var pause_at := -1.0
var level_view := "cards"   # level-up: "cards", "character" (Tab) or "hidden" (H), design/ux/level-up.md
var _level_view_arg := ""   # --level-view=character|hidden (shots): open that view on the first level-up
var pause_view := ""   # "settings" / "character": the --pause-at pause opens that page (shots)
var god := false
var buffs: Buffs
var status_defs := {}        # statuses.json "statuses"
var _shock_fx: Array = []    # [{a, b, t}] shock arcs being drawn
var _buff_defs := {}
var _forced_buffs: Array[String] = []   # --buff=a,b (shots)
var _ground_buffs: Array[String] = []   # --buff-ground=a,b (shots)
var _dash_left := 0.0      # seconds of the current dash left
var _dash_dir := Vector2.RIGHT
var _dash_cd := 0.0
var _dash_hit_half := false
var _dash_from := Vector2.ZERO
var _dash_trail := 0.0      # afterimages stay this long after the dash
var dash_at := -1.0          # --dash-at=T (shots)
var monster_hp_mul := 1.0    # --monster-hp=N (shots: monsters live long enough to show statuses)
var _status_all: Array[String] = []   # --status-all=a,b (shots: every monster gets these statuses)
var _status_all_t := 0.0
var damage_taken := 0.0   # end-of-run table
var healed := 0.0
var _bench_frames := 0
var _bench_tick_us: PackedInt64Array = []
var _bench_frame_us: PackedInt64Array = []
var _bench_last_us := 0
var _demo_pick_t := 0.0

var _sprite_scale := 2.0
var _gem_sprite := "exp-gem"    # from items.json pickups
var _coin_sprite := "gold-coin"
var _arena_half := 1400.0
var _hit_center := Vector2(0, -26)
var _camera: Camera2D
var _hud: RunHud
var _panels: RunPanels


func _ready() -> void:
	_parse_args()
	RunInput.register()
	cfg = GameData.load_json(DATA + "run_config.json")
	stages = Stages.load_default()
	milestones = Milestones.load_default()
	var prefs := Prefs.current()
	if prefs.active_slot != null and not prefs.is_fixed():
		playing_slot = prefs.active_slot
		if not _stage_arg_set:
			stage_number = clampi(prefs.stage_target, 1, stages.count())
	stage_number = clampi(stage_number, 1, stages.count())
	if challenge_id == "":
		challenge_id = prefs.challenge_target
	if challenge_id != "" and not Challenges.load_default().get_def(challenge_id).is_empty():
		stage = Challenges.load_default().build(challenge_id)   # a stage with the challenge's rules
		stage_number = int(Challenges.load_default().get_def(challenge_id).get("base", stage_number))
		_win_on_boss = bool(stage.get("win_on_boss", true))
	else:
		challenge_id = ""
		stage = stages.load_stage(stage_number)
	stage_ground = stages.ground(stage_number)
	# each region and the challenges have their own song (design/regions.md)
	run_music = String(Challenges.load_default().data.get("music", "run")) if challenge_id != "" \
		else String(stages.region(stage_number).get("music", "run"))
	Sfx.music(run_music)
	duration = float(stage.get("duration", 300.0))
	var monsters := GameData.load_json(DATA + "monsters.json")
	var classes := GameData.load_json(DATA + "classes.json")
	class_id = String(playing_slot.cls) if playing_slot != null and not prefs.is_fixed() else prefs.hero
	if not classes.has(class_id):
		class_id = "knight"
	class_data = classes.get(class_id, {})
	pool = GameData.load_json(DATA + String(class_data.get("upgrades", "")))
	_sprite_scale = float(cfg.get("world", {}).get("sprite_scale", 2))
	_arena_half = float(cfg.get("world", {}).get("arena_half", 1400.0))
	xp_curve = XpCurve.from_config(cfg.get("xp", {}))
	var ui: Dictionary = cfg.get("ui", {})
	_num_life = float(ui.get("damage_number_time", 0.7))
	_num_rise = float(ui.get("damage_number_rise", 36.0))
	_num_size = int(ui.get("damage_number_size", 16))
	var n_max := maxi(1, int(ui.get("max_damage_numbers", 96)))
	_num_pos.resize(n_max)
	_num_val.resize(n_max)
	_num_t.resize(n_max)
	_num_t.fill(-1.0)

	var items := GameData.load_json(DATA + "items.json")
	_gem_sprite = String(items.get("pickups", {}).get("xp_gem", {}).get("sprite", "exp-gem"))
	_coin_sprite = String(items.get("pickups", {}).get("gold", {}).get("sprite", "gold-coin"))
	_chest_sprite = String(items.get("pickups", {}).get("chest", {}).get("sprite", "chest"))
	_essence_sprite = String(items.get("pickups", {}).get("essence", {}).get("sprite", "essence-pickup"))
	var names: Array[String] = [String(class_data.get("sprite", "swordsman")), _gem_sprite, _coin_sprite, _chest_sprite, _essence_sprite, "stomp-i"]
	_buff_defs = items.get("buffs", {})
	status_defs = GameData.load_json(DATA + "statuses.json").get("statuses", {})
	for st: String in status_defs:
		names.append(String(status_defs[st].get("sprite", "")))
	for b: String in _buff_defs:
		names.append(String(_buff_defs[b].get("sprite", b)))
		if _buff_defs[b].has("aura"):
			names.append(String(_buff_defs[b]["aura"]))
	for m: String in monsters:
		if not m.begins_with("_"):
			names.append(String(monsters[m].get("sprite", m)))
			if monsters[m].has("bolt_sprite"):   # a shooter's bolt
				names.append(String(monsters[m]["bolt_sprite"]))
	for sk: String in pool.get("skills", {}):
		var sd: Dictionary = pool["skills"][sk]
		names.append(String(sd.get("sprite", sk)))
		for tn in sd.get("impact_tiers", []):
			names.append(String(tn))
		if sd.has("zone") and sd["zone"].get("kind", "") == "burn":
			names.append(String(sd["zone"].get("sprite", "scorch")))
		for tn in sd.get("tier_sprites", []):
			names.append(String(tn))
	for n in names:
		if not sheets.has(n):
			sheets[n] = SpriteSheet.load_dir(SPRITES + n, n)
	# the hero is layered: compose it here; equipment will pass its layers as overrides
	var hero_sheet: SpriteSheet = sheets.get(names[0])
	if hero_sheet != null and not hero_sheet.layer_names().is_empty():
		hero_sheet.compose_layers()

	enemies = Enemies.new(monsters, cfg, sheets, rng.seed)
	enemies.scale_kinds(stages.hp_mul(stage_number) * float(stage.get("hp_mul", 1.0)), stages.damage_mul(stage_number))
	for k in enemies.k_hp.size():
		enemies.k_hp[k] *= monster_hp_mul
	enemies.vs_status_mul = passive_vs_status()
	_update_body()
	pickups = Pickups.new(cfg.get("pickups", {}), 400)
	buffs = Buffs.new(_buff_defs, cfg.get("buffs", {}), rng.seed + 7)
	for id in _forced_buffs:
		buffs.activate(id)
	for k in _ground_buffs.size():
		buffs.ground.append({"id": _ground_buffs[k], "pos": Vector2(120.0 + 70.0 * k, -60.0), "age": 0.0})
	waves = WaveScheduler.new(stage.get("waves", []))
	base_stats = class_data.get("stats", {})
	profile = playing_slot.profile if playing_slot != null else prefs.profile()
	tree_owner = prefs.active_slot
	for id in _gear:
		profile.add(id)
		profile.equip(class_id, id)
		if _gear_plus > 0:
			profile.plus[id] = _gear_plus
	set_specials(profile.specials(class_id) if profile != null else [])
	var hero_layers: SpriteSheet = sheets.get(String(class_data.get("sprite", "")))
	if hero_layers != null and not hero_layers.layer_names().is_empty() and profile != null:
		hero_layers.compose_layers(hero_layers.gear_overrides(profile.equipped(class_id).values()))   # worn items show
	for sk: String in class_data.get("start_skills", {}):
		# keep a higher level forced by --skills
		levels[sk] = maxi(int(levels.get(sk, 0)), int(class_data["start_skills"][sk]))
	apply_rewards()
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

	# --milestone=N (shots): the level milestone pick opens at the start
	if not _ms_queue.is_empty():
		_open_level_up.call_deferred()
	elif _pick_card != "":   # --pick-card=ID (shots): its skill pick at the start
		(func() -> void:
			choices.assign([_pick_card])
			state = State.LEVEL_UP
			pending_levels += 1
			choose(0)).call_deferred()

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
		elif a.begins_with("--buff="):
			# Debug/shots: start with these buffs active, e.g. --buff=magnetic_shield,power_orb
			for id in a.get_slice("=", 1).split(",", false):
				_forced_buffs.append(id)
		elif a.begins_with("--buff-ground="):
			# Debug/shots: these buffs lie on the ground near the start
			for id in a.get_slice("=", 1).split(",", false):
				_ground_buffs.append(id)
		elif a.begins_with("--status-all="):
			for st in a.get_slice("=", 1).split(",", false):
				_status_all.append(st)
		elif a.begins_with("--monster-hp="):
			monster_hp_mul = maxf(0.01, float(a.get_slice("=", 1)))
		elif a.begins_with("--boss-hp="):
			_boss_hp_share = float(a.get_slice("=", 1))
		elif a.begins_with("--gear-plus="):
			_gear_plus = int(a.get_slice("=", 1))
		elif a.begins_with("--gear="):
			for id in a.get_slice("=", 1).split(",", false):
				_gear.append(id)
		elif a.begins_with("--stage="):
			stage_number = maxi(1, int(a.get_slice("=", 1)))
			_stage_arg_set = true
		elif a.begins_with("--dash-at="):
			dash_at = float(a.get_slice("=", 1))
		elif a == "--god":
			god = true
		elif a.begins_with("--pause-view="):
			pause_view = a.get_slice("=", 1)
		elif a.begins_with("--pause-at="):
			pause_at = float(a.get_slice("=", 1))
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
		elif a.begins_with("--offer="):
			# Debug/shots: the first level-up offers these cards, e.g. --offer=earth_strike,haste,back_slash
			for id in a.get_slice("=", 1).split(",", false):
				offer.append(id)
		elif a.begins_with("--pick-card="):
			_pick_card = a.get_slice("=", 1)
		elif a.begins_with("--level-view="):
			_level_view_arg = a.get_slice("=", 1)
		elif a.begins_with("--challenge="):
			challenge_id = a.get_slice("=", 1)
		elif a.begins_with("--milestone="):
			_ms_queue.append(int(a.get_slice("=", 1)))
		elif a.begins_with("--rewards="):
			# Debug/shots/tests: milestone rewards the slot owns, e.g. --rewards=earthquake,bloodthirst
			_rewards_arg = true
			for id in a.get_slice("=", 1).split(",", false):
				rewards.append(id)
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
			open_pause()
		elif state == State.PAUSED:
			resume()
	elif event.is_action_pressed("dash") and state == State.PLAYING:
		try_dash()
	elif state == State.LEVEL_UP and event.is_action_pressed("character"):
		toggle_level_view("character")
	elif state == State.LEVEL_UP and event.is_action_pressed("peek"):
		toggle_level_view("hidden")
	elif event.is_action_pressed("character"):
		if state == State.PLAYING:
			open_pause()
			_panels.show_character()
		elif state == State.PAUSED:
			resume()
	elif state == State.LEVEL_UP and level_view == "cards":   # no blind picks
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
	if pause_at >= 0.0 and clock >= pause_at:
		pause_at = -1.0
		open_pause()
		if pause_view == "settings":
			_panels.show_settings()
		elif pause_view == "character":
			_panels.show_character()
		return
	_move_player(dt)
	_spawn(clock - dt, clock)
	var contact := enemies.step(dt, player_pos, player_pos + _hit_center)
	if contact > 0.0 and invuln <= 0.0 and bench == 0 and not god and not buffs.invulnerable() and _dash_left <= 0.0:
		_take_hit(contact)
	invuln = maxf(0.0, invuln - dt)
	var had := buffs.active.size()
	buffs.step(dt, player_pos + _hit_center)
	if buffs.active.size() != had or not buffs.picked_ids().is_empty():
		_recompute_stats()
	_step_guardian(dt)
	step_specials(dt)
	var before := hp
	hp = minf(float(stats["max_hp"]), hp + float(stats.get("regen", 0.0)) * dt)
	healed += maxf(0.0, hp - before)
	_skills(dt)
	if not _status_all.is_empty():
		_status_all_t -= dt
		if _status_all_t <= 0.0:
			_status_all_t = 0.5
			for i in enemies.count:
				for st in _status_all:
					if st != "shock" or i % 6 == 0:
						enemies.apply_status(i, st, {"time": 1.0, "mul": 0.5, "dps_mul": 0.01, "chain": 2, "radius": 120.0}, 1.0, "test")
	_drain_shocks(dt)
	_drops()
	var essence_before := pickups.essence
	var got := pickups.step(dt, player_pos + _hit_center, float(stats.get("magnet", 1.0)))
	gold += int(got.y)
	if got.y > 0.0:
		Sfx.play("coin")
	if pickups.essence > essence_before:
		Sfx.play("essence")
	if got.x > 0.0:
		Sfx.play("gem")
		_gain_xp(got.x)
	if pickups.chests > 0 and state == State.PLAYING:   # a chest from an elite: one extra pick
		pickups.chests -= 1
		Sfx.play("chest")
		if rng.randf() < float(cfg.get("rewards", {}).get("chest_item_chance", 0.0)):
			_win_item()
		pending_levels += 1
		_log_level("chest -> +1 pick")
		_chest_open = true
		_open_level_up()
	for p in enemies.bolt_pops:   # monster bolts that burst (hit or out of range)
		_add_fx(_bolt_sprite_at(p), "pop", _sprite_scale, 0.0, -1.0, p)
	enemies.bolt_pops.clear()
	if not enemies.blasts_done.is_empty():
		Sfx.play("fire")
	for p in enemies.blasts_done:   # death bursts that went off
		_add_fx("stomp-i", "burst", _sprite_scale * 1.2, 0.0, -1.0, p)
	enemies.blasts_done.clear()
	if not enemies.slams.is_empty():
		Sfx.play("boss_slam")
	for p in enemies.slams:   # boss landings: a dust ring where it hit the ground
		_add_fx("stomp-i", "burst", _sprite_scale * 1.6, 0.0, -1.0, p)
	enemies.slams.clear()
	_step_fx(dt)
	step_zones(dt)
	if not enemies.hit_pos.is_empty():
		Sfx.play("hit")
	_step_damage_numbers(dt)
	_rage_t = maxf(0.0, _rage_t - dt)
	wave_call_t = maxf(0.0, wave_call_t - dt)
	var bi := enemies.boss_index()
	if bi >= 0 and _boss_hp_share > 0.0:   # shots: show phase 2 without a long fight
		enemies.hp[bi] = enemies.k_hp[enemies.kind[bi]] * _boss_hp_share
		_boss_hp_share = -1.0
	if bi >= 0 and not _rage_seen and enemies.enraged(bi):   # phase 2: called out once
		_rage_seen = true
		_rage_t = 2.0
		Sfx.play("boss_spawn")
	_boss_check_t -= dt
	if _boss_check_t <= 0.0:   # the boss song while a boss lives
		_boss_check_t = 0.5
		var boss := enemies.boss_index() >= 0
		if boss != _boss_music:
			_boss_music = boss
			Sfx.music("boss" if boss else run_music)
			if boss:
				Sfx.play("boss_spawn")
	if hp <= 0.0:
		_die()
	elif (clock >= duration or (_boss_dead and _win_on_boss)) and bench == 0:
		_win()


func _move_player(dt: float) -> void:
	_dash_cd = maxf(0.0, _dash_cd - dt)
	_dash_trail = maxf(0.0, _dash_trail - dt)
	if dash_at >= 0.0 and clock >= dash_at:
		dash_at = -1.0
		try_dash()
	if _dash_left > 0.0:
		_dash_step(dt)
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if demo:
		dir = forced_walk if forced_walk != Vector2.ZERO else _autopilot()
	_moving = dir.length_squared() > 0.01
	if _moving:
		facing = dir.normalized()
		if absf(facing.x) > 0.1:
			face_left = facing.x < 0.0
			_update_body()
		player_pos += dir.limit_length(1.0) * float(stats["move_speed"]) * dt
		player_pos = player_pos.clamp(Vector2(-_arena_half, -_arena_half), Vector2(_arena_half, _arena_half))
	_action_left = maxf(0.0, _action_left - dt)
	if _action_left <= 0.0:
		_set_anim("run" if _moving else "idle")


## Dash (the dash card): along the walk direction (or facing), fast, no damage
## taken, slashing the monsters on the way. Returns true when it started.
func try_dash() -> bool:
	if int(levels.get("dash", 0)) <= 0 or _dash_cd > 0.0 or _dash_left > 0.0:
		return false
	var sp: Dictionary = pool.get("skills", {}).get("dash", {})
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if demo and forced_walk != Vector2.ZERO:
		dir = forced_walk
	if dir.length_squared() < 0.01:
		dir = Vector2.LEFT if face_left else Vector2.RIGHT
	_dash_dir = dir.normalized()
	_dash_from = player_pos
	_dash_left = float(sp.get("time", 0.18))
	_dash_trail = _dash_left + 0.12
	_dash_hit_half = false
	_dash_cd = skill_cooldown("dash")
	if absf(_dash_dir.x) > 0.1:
		face_left = _dash_dir.x < 0.0
		_update_body()
	_play_action(String(sp.get("anim", "dash")))
	Sfx.skill("dash")
	return true


func _dash_step(dt: float) -> void:
	var sp: Dictionary = pool.get("skills", {}).get("dash", {})
	var total := maxf(0.01, float(sp.get("time", 0.18)))
	var dist := float(sp.get("distance", 130.0))
	var step := minf(dt, _dash_left)
	player_pos += _dash_dir * dist / total * step
	player_pos = player_pos.clamp(Vector2(-_arena_half, -_arena_half), Vector2(_arena_half, _arena_half))
	_dash_left -= step
	# two cuts along the path: covering the half just travelled each time
	var r := dist * 0.25 + float(sp.get("hit_radius", 26.0))
	var back := _dash_dir * dist * 0.25
	if not _dash_hit_half and _dash_left <= total * 0.5:
		_dash_hit_half = true
		enemies.hit_circle(player_pos + _hit_center - back, r, skill_damage("dash"), 120.0, "dash", on_hit("dash"))
	elif _dash_left <= 0.0:
		enemies.hit_circle(player_pos + _hit_center - back, r, skill_damage("dash"), 120.0, "dash", on_hit("dash"))


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
		# close in, then creep (the slash aims itself at the nearest monster)
		dir = -nearest.normalized() if hurt else nearest.normalized() * (1.0 if best > 45.0 * 45.0 else 0.2)
	var home := -player_pos / maxf(1.0, _arena_half) * 1.5
	return (dir * 0.6 + crowd + home).limit_length(1.0)


func _spawn(t0: float, t1: float) -> void:
	if bench > 0:
		while enemies.living() < bench and enemies.count < enemies.capacity:
			enemies.spawn(enemies.kind_ids[rng.randi() % enemies.kind_ids.size()], enemies.ring_point(player_pos))
		return
	for call in waves.announcements(t0, t1):   # a big wave is called before it comes
		wave_call = call
		wave_call_t = 2.6
		Sfx.play("boss_spawn")
	for id in waves.advance(t0, t1):
		enemies.spawn(id, enemies.ring_point(player_pos))


func _take_hit(amount: float) -> void:
	var taken := maxf(1.0, (amount - float(stats.get("armor", 0.0))) * damage_taken_mul())
	hp -= taken
	damage_taken += taken
	invuln = float(cfg.get("player", {}).get("hit_invuln", 0.6))
	Sfx.play("hurt")
	_retaliate()
	_play_action("hurt")


## Tinh hoa a kill drops: run_config.json "essence" (elite / boss), else 0.
func essence_drop(elite: bool, boss: bool) -> int:
	var e: Dictionary = cfg.get("essence", {})
	if boss:
		return int(e.get("boss", 0))
	if elite:
		return int(e.get("elite", 0))
	return 0


func _drops() -> void:
	if enemies.kill_pos.is_empty():
		return
	Sfx.play("kill")
	count_special_kills(enemies.kill_pos.size())
	var gold_chance := float(cfg.get("pickups", {}).get("gold_chance", 0.1))
	var heal_frac := heal_on_kill()   # Khát máu: elites and bosses feed the hero
	for i in enemies.kill_pos.size():
		pickups.drop(Pickups.GEM, enemies.kill_pos[i], enemies.kill_xp[i])
		if enemies.kill_elite[i] == 1 or enemies.kill_boss[i] == 1:
			elite_kills += 1
		if enemies.kill_elite[i] == 1:
			pickups.drop(Pickups.CHEST, enemies.kill_pos[i] + Vector2(-10, 0), 1.0)
		var ess := essence_drop(enemies.kill_elite[i] == 1, enemies.kill_boss[i] == 1)
		if ess > 0:   # Tinh hoa: the skill-tree material
			pickups.drop(Pickups.ESSENCE, enemies.kill_pos[i] + Vector2(0, -12), float(ess))
		if enemies.kill_boss[i] == 1:
			_boss_dead = true
		if heal_frac > 0.0 and (enemies.kill_elite[i] == 1 or enemies.kill_boss[i] == 1):
			heal_max(heal_frac)
		if rng.randf() < gold_chance:
			pickups.drop(Pickups.COIN, enemies.kill_pos[i] + Vector2(10, 0), 1.0)
	enemies.drain_kills()


# --- skills ------------------------------------------------------------------

func _skills(dt: float) -> void:
	var skills: Dictionary = pool.get("skills", {})
	if clock < 0.05:
		printerr("DBG keys=", skills.keys(), " levels=", levels)
	if levels.get("blade_arc", 0) > 0:
		var s: Dictionary = skills["blade_arc"]
		_blade_cd -= dt
		if _blade_cd <= 0.0:
			_blade_cd = skill_cooldown("blade_arc")
			var dmg := skill_damage("blade_arc")
			var sc := _sprite_scale * skill_size("blade_arc")
			var sprite := String(s.get("sprite", "sword-slash"))
			_aim()
			_add_fx(sprite, _slash_anim(attack_dir), sc, dmg, -1.0, null, "blade_arc")
			# amount: one more slash at each next nearest monster's side
			var extra := amount_for("blade_arc")
			if extra > 0:
				var done := [attack_dir]
				for i in enemies.nearest_n(player_pos + _hit_center, extra + 4):
					var d2 := slash_dir(enemies.center_of(i) - (player_pos + _hit_center))
					if not done.has(d2):
						done.append(d2)
						_add_fx(sprite, _slash_anim(d2), sc, dmg, -1.0, null, "blade_arc")
						if done.size() > extra:
							break
			var back := int(levels.get("back_slash", 0))
			if back > 0:
				var mul := float(s.get("back_damage_mul", 0.5)) + float(s.get("back_damage_per_level", 0.25)) * (back - 1)
				_add_fx(sprite, _slash_anim(-attack_dir), sc, dmg * mul, -1.0, null, "back_slash")
	if levels.get("whirlwind", 0) > 0:
		var w: Dictionary = skills["whirlwind"]
		if _whirl_left > 0.0:
			_whirl_left -= dt
			var dur := float(w.get("duration", 0.9))
			var ticks := maxi(1, int(w.get("ticks", 3)) + amount_for("whirlwind"))
			var due := int(floor((dur - maxf(_whirl_left, 0.0)) / dur * ticks)) + 1
			while _whirl_ticks_done < mini(due, ticks):
				_whirl_ticks_done += 1
				var dmg := skill_damage("whirlwind")
				for fx in _fx:
					if fx["anim"] == "spin":
						var hb := SpriteHitbox.of(fx["sheet"], "spin", player_pos + _hit_center, float(fx["scale"]))
						if hb != null:
							enemies.hit_box(hb, dmg, 90.0, "whirlwind", on_hit("whirlwind"))
		else:
			_whirl_cd -= dt
			if _whirl_cd <= 0.0:
				_whirl_cd = skill_cooldown("whirlwind")
				_whirl_left = float(w.get("duration", 0.9))
				_whirl_ticks_done = 0
				var sc := _sprite_scale * skill_size("whirlwind")
				_add_fx(String(w.get("sprite", "whirlwind")), "spin", sc, 0.0, _whirl_left)
				Sfx.skill("whirlwind")


## The slash never follows the walk: it always points at the nearest living
## monster (snapped to the slash sprite's 4 directions). With no monster left
## it keeps its last direction. Standing still, the hero turns to face it.
	# Data-driven skills (skills.<id>.cast in upgrades_<class>.json): nearest / self /
	# random / wave. blade_arc and whirlwind above have their own timing; "active"
	# (the dash) is cast by the player.
	var di := 0
	while di < _delayed.size():
		var dc: Dictionary = _delayed[di]
		dc["t"] = float(dc["t"]) - dt
		if float(dc["t"]) <= 0.0:
			var fx := _add_fx(dc["sprite"], dc["anim"], dc["sc"], dc["dmg"], -1.0, player_pos + _hit_center, dc["sid"], dc["kb"])
			if bool(dc["under"]) and not fx.is_empty():
				fx["under"] = true
			_delayed.remove_at(di)
		else:
			di += 1
	for sid: String in skills:
		var ts: Dictionary = skills[sid]
		var how := String(ts.get("cast", ""))
		if sid == "holy_column" and int(levels.get(sid, 0)) > 0 and float(_tier_cd.get(sid, 0.0)) - dt <= 0.0:
			print("DBG holy cast, pool=", enemies.living_within(player_pos + _hit_center, float(ts.get("cast_range", 300.0))).size(), " sheet=", sheets.has(_skill_sprite(sid, ts)))
		if how == "" or how == "active" or int(levels.get(sid, 0)) <= 0:
			continue
		var cd_left := float(_tier_cd.get(sid, 0.0)) - dt
		_tier_cd[sid] = cd_left
		if cd_left <= 0.0:
			_tier_cd[sid] = skill_cooldown(sid)
			_cast(sid, ts, how)


## Statuses skill [param sid] puts on what it hits at its current level
## (skills.<id>.on_hit entries whose "from" level is reached).
func on_hit(sid: String) -> Array:
	var out := []
	var lv := int(levels.get(sid, 0))
	for e: Dictionary in pool.get("skills", {}).get(sid, {}).get("on_hit", []):
		if lv >= int(e.get("from", 1)):
			out.append(e)
	return out


## Sprite of a skill at its current level (tier_sprites I-V, else "sprite").
## The entry of [param names] for skill [param sid]'s level ("" when empty).
func _tier_name(names: Array, sid: String) -> String:
	if names.is_empty():
		return ""
	return String(names[clampi(int(levels.get(sid, 1)) - 1, 0, names.size() - 1)])


func _skill_sprite(sid: String, ts: Dictionary) -> String:
	var tier_names: Array = ts.get("tier_sprites", [])
	if tier_names.is_empty():
		return String(ts.get("sprite", sid))
	return String(tier_names[clampi(int(levels.get(sid, 1)) - 1, 0, tier_names.size() - 1)])


## How many casts at the current level (skills.<id>.count per level, default 1).
func _skill_count(sid: String, ts: Dictionary) -> int:
	var c: Array = ts.get("count", [])
	var base := 1 if c.is_empty() else maxi(1, int(c[clampi(int(levels.get(sid, 1)) - 1, 0, c.size() - 1)]))
	return base + amount_for(sid)


## Count added to skill [param sid] on top of its level: the count cards put on it
## (Thêm đòn / Thêm phép, one chosen skill each) plus Đa phép (a level milestone,
## the only thing adding to every skill).
func amount_for(sid: String) -> int:
	return int(skill_extra.get(sid, 0)) + int(stats.get("amount", 0.0))


## The count of skill [param sid] now, as the skill uses it: casts / targets /
## projectiles; slashes for Chém kiếm; ticks for Lốc xoáy.
func skill_count_now(sid: String) -> int:
	var ts: Dictionary = pool.get("skills", {}).get(sid, {})
	match sid:
		"blade_arc":
			return 1 + amount_for(sid)
		"whirlwind":
			return maxi(1, int(ts.get("ticks", 3)) + amount_for(sid))
	return _skill_count(sid, ts)


## Where skill [param sid]'s count comes from, one line each (character sheet):
## its level, the count cards put on it, Đa phép.
func count_parts(sid: String) -> String:
	var own := int(skill_extra.get(sid, 0))
	var all := int(stats.get("amount", 0.0))
	var lines := ["Theo cấp của chiêu: ×%d" % (skill_count_now(sid) - own - all)]
	if own > 0:
		lines.append("Thẻ Thêm đòn / Thêm phép chọn chiêu này: +%d" % own)
	if all > 0:
		lines.append("Đa phép (mốc cấp, mọi chiêu): +%d" % all)
	return "\n".join(lines)


## A count card's +1 (pick_skill) goes on skill [param sid].
func add_skill_extra(sid: String, n := 1) -> void:
	skill_extra[sid] = int(skill_extra.get(sid, 0)) + n


## Skills a count card can go on: owned attacks (not the player-cast dash).
func skill_pick_ids() -> Array[String]:
	var out: Array[String] = []
	var defs: Dictionary = pool.get("skills", {})
	for u: Dictionary in pool.get("upgrades", []):
		var sid := String(u.get("id", ""))
		if u.get("kind") == "skill" and int(levels.get(sid, 0)) > 0 and String(defs.get(sid, {}).get("cast", "")) != "active":
			out.append(sid)
	return out


func _cast(sid: String, ts: Dictionary, how: String) -> void:
	var dmg := skill_damage(sid)
	var sc := _sprite_scale * skill_size(sid)
	var sprite := _skill_sprite(sid, ts)
	var center := player_pos + _hit_center
	var kb := float(ts.get("knockback", 140.0))
	var to_target := attack_dir if attack_dir.length_squared() > 0.01 else Vector2.RIGHT
	var target_i := enemies.nearest(center, INF)
	if target_i >= 0:
		to_target = (enemies.center_of(target_i) - center).normalized()
	match how:
		"nearest":
			# one burst toward each of the nearest monsters (count: more of them);
			# anim_prefix plays the direction, at_target drops it on the monster
			var n := _skill_count(sid, ts)
			var targets := enemies.nearest_n(center, n)
			if targets.is_empty():
				targets = [-1]
			var prefix := String(ts.get("anim_prefix", ""))
			var on_target := bool(ts.get("at_target", false))
			for k in mini(n, targets.size()):
				var dir := to_target
				var aim := center + to_target * float(ts.get("cast_range", 140.0))
				if int(targets[k]) >= 0:
					dir = (enemies.center_of(targets[k]) - center).normalized()
					aim = enemies.center_of(targets[k])
				var anim := String(ts.get("anim", "burst"))
				if prefix != "":
					anim = _fly_anim(sprite, prefix, dir)
				if on_target:
					# drop the effect so its damage area covers the monster (the
					# art's anchor is not its head: a hammer strike's box sits to
					# one side of the frame)
					var probe := SpriteHitbox.of(sheets.get(sprite), anim, Vector2.ZERO, sc)
					if probe != null:
						aim -= probe.center
				_add_fx(sprite, anim, sc, dmg, -1.0, aim, sid, kb)
		"self":
			# count: pulses 0.25 s apart
			for k in _skill_count(sid, ts):
				_delayed.append({"t": 0.25 * k, "sid": sid, "sprite": sprite, "sc": sc, "dmg": dmg, "kb": kb,
					"anim": String(ts.get("anim", "burst")), "under": bool(ts.get("under_hero", false))})
		"random":
			var pool_i := enemies.living_within(center, float(ts.get("cast_range", 300.0)))
			# a ranged skill (min_range) skips monsters close to the hero while farther ones exist
			var min_r := float(ts.get("min_range", 0.0))
			if min_r > 0.0:
				var far := pool_i.filter(func(i: int) -> bool: return enemies.pos[i].distance_to(center) >= min_r)
				if not far.is_empty():
					pool_i = far
			for k in _skill_count(sid, ts):
				if pool_i.is_empty():
					break
				var i: int = pool_i.pop_at(rng.randi() % pool_i.size())
				_add_fx(sprite, String(ts.get("anim", "burst")), sc, dmg, -1.0, enemies.pos[i], sid, kb)
		"projectile":
			# fired at the nearest monster; several fan out 12 degrees apart
			var n := _skill_count(sid, ts)
			var speed := float(ts.get("speed", 340.0))
			for k in n:
				var dv := to_target.rotated(deg_to_rad(12.0 * (k - (n - 1) * 0.5)))
				var anim := _fly_anim(sprite, String(ts.get("anim_prefix", "fly_")), dv)
				# leaves from in front of the hero, not from its face (user 2026-11-18)
				var fx := _add_fx(sprite, anim, sc, 0.0, float(ts.get("duration", 1.2)), center + dv * 18.0, sid, kb)
				if fx.is_empty():
					continue
				fx["vel"] = dv * speed
				fx["shot"] = {"damage": dmg, "explode": bool(ts.get("explode", false)), "pierce": int(ts.get("pierce", 0)),
					"impact": String(ts.get("impact", "impact")), "wait": 0.0,
					"impact_sprite": _tier_name(ts.get("impact_tiers", []), sid)}
		"wave":
			# straight at the nearest monster, then behind, then both sides
			var first := to_target.normalized()
			var dirs := [first, -first, first.orthogonal(), -first.orthogonal()]
			for k in mini(_skill_count(sid, ts), dirs.size()):
				var dv: Vector2 = dirs[k]
				var fx := _add_fx(sprite, _fly_anim(sprite, String(ts.get("anim_prefix", "fly_")), dv), sc, dmg, float(ts.get("duration", 0.9)), center, sid, kb)
				if not fx.is_empty():
					fx["vel"] = dv * float(ts.get("speed", 300.0))
					fx["rehit"] = float(ts.get("rehit", 0.25))


## The flight animation closest to direction [param d]: "<prefix><degrees>" when
## the sprite has angle animations (fly_000..fly_337, Sprite Lab lib/dirs16.py),
## else the 4-direction "<prefix>right/left/up/down".
func _fly_anim(sprite: String, prefix: String, d: Vector2) -> String:
	var sheet: SpriteSheet = sheets.get(sprite)
	var want := fposmod(rad_to_deg(d.angle()), 360.0)
	var best := ""
	var best_gap := 999.0
	if sheet != null:
		for n in sheet.animation_names():
			var tail := n.trim_prefix(prefix)
			if n.begins_with(prefix) and tail.length() == 3 and tail.is_valid_int():
				var gap := absf(fposmod(want - float(tail) + 180.0, 360.0) - 180.0)
				if gap < best_gap:
					best_gap = gap
					best = n
	return best if best != "" else prefix + _dir_name(d)


static func _dir_name(d: Vector2) -> String:
	if absf(d.x) >= absf(d.y):
		return "right" if d.x >= 0.0 else "left"
	return "down" if d.y > 0.0 else "up"


## Skill numbers, shared by casting, the HUD and the character sheet so they never
## disagree. [param st] defaults to the current stats (pass others for previews).
func skill_damage(id: String, st: Dictionary = {}) -> float:
	if st.is_empty():
		st = stats
	var sp: Dictionary = pool.get("skills", {}).get(id, {})
	var dmg := float(st.get("damage", 0.0)) * float(sp.get("damage_mul", 1.0)) * PlayerStats.skill_mul(st, "skill_damage." + id)
	if passive_active():
		dmg *= 1.0 + float(class_data.get("passive", {}).get("damage_mul", 0.0))
	return dmg


## The class passive (classes.json "passive"), {} when none.
func passive() -> Dictionary:
	return class_data.get("passive", {})


## True while a low-hp passive is on (hp under passive.hp_below of max).
func passive_active() -> bool:
	var p := passive()
	if not p.has("hp_below") or stats.is_empty():
		return false
	return hp > 0.0 and hp < float(stats.get("max_hp", 1.0)) * float(p["hp_below"])


## Multiplier on damage the hero takes (passive taken_mul while active).
func damage_taken_mul() -> float:
	return 1.0 + float(passive().get("taken_mul", 0.0)) if passive_active() else 1.0


## Extra damage against monsters that have a status (passive vs_status_mul).
func passive_vs_status() -> float:
	return float(passive().get("vs_status_mul", 0.0))


## Size multiplier of a skill's effect (area stat x skill size x per-skill area).
func skill_size(id: String, st: Dictionary = {}) -> float:
	if st.is_empty():
		st = stats
	var sp: Dictionary = pool.get("skills", {}).get(id, {})
	return float(st.get("area", 1.0)) * float(sp.get("size_mul", 1.0)) * PlayerStats.skill_mul(st, "skill_area." + id)


## Seconds between casts: the skill's own "cooldown" x the cooldown stat (one
## multiplier for EVERY skill, x1.00 for a class, -10% per Nhanh tay level; user
## 2026-11-17) x the skill's own card multiplier (skill_cd.<id>, e.g. the dash).
func skill_cooldown(id: String, st: Dictionary = {}) -> float:
	if st.is_empty():
		st = stats
	var sp: Dictionary = pool.get("skills", {}).get(id, {})
	var own := PlayerStats.skill_mul(st, "skill_cd." + id)   # e.g. the dash card's -12% per level
	return float(sp.get("cooldown", 1.0)) * float(st.get("cooldown", 1.0)) * own


## Cooldown shown on the HUD: [seconds left, cooldown, active]. active = the skill
## is running now (whirlwind spinning).
func cooldown_state(id: String) -> Array:
	var total := skill_cooldown(id)
	match id:
		"blade_arc":
			return [maxf(0.0, _blade_cd), total, false]
		"whirlwind":
			return [0.0 if _whirl_left > 0.0 else maxf(0.0, _whirl_cd), total, _whirl_left > 0.0]
		"dash":
			return [_dash_cd, total, _dash_left > 0.0]
		_:
			return [maxf(0.0, float(_tier_cd.get(id, 0.0))), total, false]


## End-of-run table, one row per damage source, most damage first:
## [{id, name, damage, share (0..1), hits, kills, dps}]. The back slash is its own row.
func damage_report() -> Array:
	var rows := []
	var total := 0.0
	for k: String in enemies.damage_by:
		total += float(enemies.damage_by[k])
	for k: String in enemies.damage_by:
		var d := float(enemies.damage_by[k])
		var u := upgrade(k)
		if u.is_empty() and profile != null and profile.defs.has(k):   # an item's special effect
			u = {"name": String(profile.defs[k].get("special", {}).get("name", profile.defs[k].get("name", k)))}
		rows.append({"id": k, "name": u.get("name", k if k != "" else "Khác"), "damage": d,
			"share": d / total if total > 0.0 else 0.0, "hits": int(enemies.hits_by.get(k, 0)),
			"kills": int(enemies.kills_by.get(k, 0)), "dps": d / maxf(1.0, clock)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["damage"] > b["damage"])
	return rows


## What a card does right now, in numbers, for the pause menu: one line per
## effect, e.g. "Hồi chiêu -40% (0.54 s) · áp lên: Chém kiếm, Lốc xoáy".
func card_effect_text(id: String) -> String:
	var u := upgrade(id)
	var lv := int(levels.get(id, 0))
	var parts := []
	var owned_skills := skill_info().map(func(si: Dictionary) -> String: return String(si["name"]))
	for key: String in u.get("effects", {}):
		var e: Dictionary = u["effects"][key]
		if key == "back_slash":
			var ba: Dictionary = pool.get("skills", {}).get("blade_arc", {})
			var pct := float(ba.get("back_damage_mul", 0.5)) + float(ba.get("back_damage_per_level", 0.25)) * (lv - 1)
			parts.append("Nhát chém sau %d%% sát thương của Chém kiếm" % roundi(pct * 100.0))
			continue
		var amount: String = ("%+d%%" % roundi(float(e["mul"]) * lv * 100.0)) if e.has("mul") else signed(float(e["add"]) * lv)
		if key.begins_with("skill_damage.") or key.begins_with("skill_area."):
			parts.append("%s %s" % ["Sát thương" if key.begins_with("skill_damage.") else "Vùng", amount])
			continue
		var line := "%s %s (hiện %s)" % [STAT_LABEL.get(key, key), amount, _fmt_stat(key, float(stats.get(key, 0.0)))]
		if key in ["damage", "cooldown", "area"] and not owned_skills.is_empty():
			line += " · áp lên: " + ", ".join(owned_skills)
		parts.append(line)
	return "\n".join(parts)


## Owned skills (kind "skill"), pool order: {id, name, level, max, damage, cooldown,
## size, base_damage, base_cooldown, sources}. sources = the cards changing this
## skill: [{id, name, level, what, text}], e.g. what "Hồi chiêu", text "-20%".
func skill_info() -> Array:
	var out := []
	var plain := PlayerStats.compute(base_stats, [], {})   # class stats, no cards
	for u: Dictionary in pool.get("upgrades", []):
		var id := String(u["id"])
		var lv := int(levels.get(id, 0))
		if u.get("kind") != "skill" or lv <= 0:
			continue
		var touches := {"damage": "Sát thương", "cooldown": "Hồi chiêu", "area": "Vùng",
			"skill_damage." + id: "Sát thương", "skill_area." + id: "Vùng", "skill_cd." + id: "Hồi chiêu"}
		var sources := []
		var lv_all := effect_levels()
		for v: Dictionary in effect_pool():
			var vl := int(lv_all.get(v["id"], 0))
			if vl <= 0:
				continue
			var effects: Dictionary = v.get("effects", {})
			for key: String in effects:
				var e: Dictionary = effects[key]
				if touches.has(key):
					var t: String = ("%+d%%" % roundi(float(e["mul"]) * vl * 100.0)) if e.has("mul") else signed(float(e["add"]) * vl)
					sources.append({"id": v["id"], "name": v.get("name", v["id"]), "level": vl, "what": touches[key], "text": t,
						"pct": float(e.get("mul", 0.0)) * vl * 100.0})
				elif key == "back_slash" and id == "blade_arc":
					var ba: Dictionary = pool.get("skills", {}).get("blade_arc", {})
					var pct := float(ba.get("back_damage_mul", 0.5)) + float(ba.get("back_damage_per_level", 0.25)) * (vl - 1)
					sources.append({"id": v["id"], "name": v.get("name", v["id"]), "level": vl, "what": "Nhát sau", "text": "%d%%" % roundi(pct * 100.0)})
		out.append({"id": id, "name": u.get("name", id), "level": lv, "max": int(u.get("max_level", 1)),
			"damage": skill_damage(id), "cooldown": skill_cooldown(id), "size": skill_size(id),
			"base_damage": skill_damage(id, plain), "base_cooldown": skill_cooldown(id, plain), "sources": sources,
			"statuses": on_hit(id), "count": skill_count_now(id), "count_parts": count_parts(id)})
	return out


func _aim() -> void:
	var center := player_pos + _hit_center
	var i := enemies.nearest(center, INF)
	if i < 0:
		return
	var d := enemies.center_of(i) - center
	attack_dir = slash_dir(d)
	if absf(d.x) > 1.0 and not _moving:   # standing still: turn towards the target
		face_left = d.x < 0.0
		_update_body()


## Direction to a target snapped to the slash sprite's 4 directions.
static func slash_dir(to_target: Vector2) -> Vector2:
	if absf(to_target.x) >= absf(to_target.y):
		return Vector2(signf(to_target.x) if to_target.x != 0.0 else 1.0, 0.0)
	return Vector2(0.0, signf(to_target.y))


func _slash_anim(d: Vector2) -> String:
	if d.x > 0.5:
		return "slash_right"
	if d.x < -0.5:
		return "slash_left"
	return "slash_down" if d.y > 0.0 else "slash_up"


## Adds an effect. By default it follows the player's body centre (strikes,
## shields, orbiting states). When [param world_pos] is given it is placed there
## in the world instead (projectiles / cast-out AOE). When [param damage] > 0 it
## hits once, on the animation's active frames, through the sprite hitbox.
## Adds an effect; returns it (empty when the sprite or animation is missing).
## A moving effect (fx["vel"]) with fx["rehit"] keeps hitting every rehit s.
func _add_fx(sprite: String, anim: String, sc: float, damage: float, life := -1.0, world_pos: Variant = null,
		source := "", knockback := 140.0) -> Dictionary:
	var sheet: SpriteSheet = sheets.get(sprite)
	if sheet == null or not sheet.has_animation(anim):
		return {}
	sc *= float(sheet.meta.get("px_scale", 1.0))   # drawn at double density (icefx): same size on screen
	var fx := {"sheet": sheet, "anim": anim, "t": 0.0, "scale": sc, "damage": damage, "done": damage <= 0.0,
		"life": life if life > 0.0 else sheet.duration(anim),
		"pos": world_pos, "follow": world_pos == null, "source": source, "kb": knockback,
		"effects": on_hit(source)}
	if bool(pool.get("skills", {}).get(source, {}).get("ground_fx", false)):
		fx["ground"] = true   # lies on the floor (frozen ground): drawn under the monsters
	_fx.append(fx)
	var zd: Dictionary = pool.get("skills", {}).get(source, {}).get("zone", {})
	if not zd.is_empty() and damage > 0.0 and world_pos != null:
		spawn_zone(zd, sheet, anim, sc, world_pos, source, damage)
	if source != "":   # a cast: its sound (audio.json "skills"; voices/gap keep it calm)
		Sfx.skill(source)
	return fx



# --- lasting zones (user 2026-11-18): what a skill leaves on the field -------------

## A zone where an effect lands: its centre, radius and start come from the
## effect sprite's own hitbox (no typed numbers), zd from the skill's "zone":
## burn: every "tick" s puts "burn" on monsters inside for "time" s (scorch drawn);
## pull: drags monsters inside toward the centre at "strength" px/s while the
## effect's damaging frames play (bosses are not moved).
func spawn_zone(zd: Dictionary, sheet: SpriteSheet, anim: String, sc: float, at: Vector2, src: String, dmg: float) -> void:
	var hb := SpriteHitbox.of(sheet, anim, at, sc)
	if hb == null:
		return
	var a := sheet.animation(anim)
	var act: Array = a.get("hitbox", {}).get("active", [0, 0])
	var start := SpriteHitbox.frame_time(a, int(act[0]))
	var hits := SpriteHitbox.frame_time(a, int(act[1]) + 1) - start
	var kind := String(zd.get("kind", "burn"))
	zones.append({"kind": kind, "pos": hb.center, "r": hb.radius * float(zd.get("radius_mul", 1.0)),
		"wait": start, "t": float(zd.get("time", hits)), "life": float(zd.get("time", hits)),
		"tick": 0.0, "src": src, "dmg": dmg, "zd": zd})


func step_zones(dt: float) -> void:
	var k := 0
	while k < zones.size():
		var z: Dictionary = zones[k]
		if float(z["wait"]) > 0.0:
			z["wait"] = float(z["wait"]) - dt
			k += 1
			continue
		z["t"] = float(z["t"]) - dt
		if float(z["t"]) <= 0.0:
			zones.remove_at(k)
			continue
		var zd: Dictionary = z["zd"]
		var c: Vector2 = z["pos"]
		if z["kind"] == "burn":
			z["tick"] = float(z["tick"]) - dt
			if float(z["tick"]) <= 0.0:
				z["tick"] = float(zd.get("tick", 0.5))
				for i in enemies.living_within(c, float(z["r"])):
					enemies.apply_status(i, "burn", zd.get("burn", {"time": 1.0, "dps_mul": 0.15}), float(z["dmg"]), String(z["src"]))
		elif z["kind"] == "pull":
			var pull := float(zd.get("strength", 60.0)) * dt
			for i in enemies.living_within(c, float(z["r"])):
				if enemies.k_boss[enemies.kind[i]] == 1:
					continue
				var d := c - enemies.center_of(i)
				if d.length() > 2.0:
					enemies.pos[i] += d.normalized() * minf(pull, d.length())
		k += 1


## Burn zones drawn as scorched ground under the monsters, fading out at the end.
func _draw_zones() -> void:
	for z in zones:
		if z["kind"] != "burn" or float(z["wait"]) > 0.0:
			continue
		var sh: SpriteSheet = sheets.get(String(z["zd"].get("sprite", "scorch")))
		if sh == null:
			continue
		var fade := clampf(float(z["t"]) / 0.6, 0.0, 1.0)
		sh.draw(self, "loop", clock, z["pos"], float(z["r"]) / (sh.frame_size.x * 0.5), false, Color(1, 1, 1, fade))


func _fx_pos(fx: Dictionary) -> Vector2:
	if bool(fx.get("follow", true)):
		return player_pos + _hit_center
	return fx.get("pos", player_pos + _hit_center)


func _step_fx(dt: float) -> void:
	var i := 0
	while i < _fx.size():
		var fx: Dictionary = _fx[i]
		fx["t"] = float(fx["t"]) + dt
		if fx.has("vel"):
			fx["pos"] = (fx["pos"] as Vector2) + (fx["vel"] as Vector2) * dt
		if fx.has("shot") and _step_shot(fx, dt):
			_fx.remove_at(i)
			continue
		if not fx["done"]:
			var hb := SpriteHitbox.of(fx["sheet"], fx["anim"], _fx_pos(fx), float(fx["scale"]))
			if hb == null:
				fx["done"] = true
			elif hb.is_active(float(fx["t"])) and float(fx.get("hit_wait", 0.0)) <= 0.0:
				enemies.hit_box(hb, float(fx["damage"]), float(fx.get("kb", 140.0)), String(fx.get("source", "")), fx.get("effects", []))
				if fx.has("rehit"):
					fx["hit_wait"] = float(fx["rehit"])
				else:
					fx["done"] = true
			fx["hit_wait"] = float(fx.get("hit_wait", 0.0)) - dt
		if float(fx["t"]) >= float(fx["life"]):
			_fx.remove_at(i)
		else:
			i += 1


# --- level milestone rewards (design/progression.md) ---------------------------
# Reaching level 10/20/30 of a run offers one of three rewards for the rest of
# that run: a unique skill (starts at level 1, levelled by cards), a passive,
# or a rule. Nothing is kept after the run (user 2026-11-17).
# What the slot picked at stages 10/20/30: a unique skill (starts at level 1,
# levelled by cards), a passive, or a rule that changes the run.

## Applies the owned rewards to this run: unique skills start at level 1, the
## passive/rule numbers are read once. Called from _ready.
func apply_rewards() -> void:
	if milestones == null:
		milestones = Milestones.load_default()
	for sk: String in milestones.skills(rewards):
		levels[sk] = maxi(int(levels.get(sk, 0)), 1)
	var g := milestones.with_key(rewards, "every")
	_guardian_every = float(g.get("every", 0.0))
	_guardian_buff = String(g.get("buff", "magnetic_shield"))
	_guardian_time = float(g.get("duration", 0.0))
	_guardian_t = _guardian_every


## Cards on a level-up: 3, or 4 with the Thêm lựa chọn rule.
func level_up_card_count() -> int:
	var n := 3
	if milestones != null:
		n = int(milestones.number(rewards, "cards", 3.0))
	return maxi(1, n)


## Khát máu: fraction of max hp an elite or boss kill heals (0 = not owned).
func heal_on_kill() -> float:
	return milestones.number(rewards, "heal_frac") if milestones != null else 0.0


## Heals [param frac] of max hp; returns how much was healed.
func heal_max(frac: float) -> float:
	var top := float(stats.get("max_hp", hp))
	var before := hp
	hp = minf(top, hp + top * frac)
	healed += hp - before
	return hp - before


## Hộ thể: the shield comes by itself every `every` seconds, for `duration` s.
func _step_guardian(dt: float) -> void:
	if _guardian_every <= 0.0:
		return
	_guardian_t -= dt
	if _guardian_t > 0.0:
		return
	_guardian_t += _guardian_every
	buffs.activate(_guardian_buff, _guardian_time)
	_recompute_stats()


# --- Hiệu ứng đặc biệt (legendary items, design/equipment.md) -----------------

## Sets the active item specials and their timers (each "every" starts full).
func set_specials(list: Array) -> void:
	specials = list
	_special_t.clear()
	_special_kills.clear()
	for sp: Dictionary in specials:
		_special_t.append(float(sp.get("every", 0.0)))
		_special_kills.append(0)


## Timed specials: shield, pulse, chain_shock, reset_cd fire every "every" s;
## retaliate's cooldown runs down here too.
func step_specials(dt: float) -> void:
	for k in specials.size():
		var sp: Dictionary = specials[k]
		_special_t[k] -= dt
		if sp.get("kind") == "low_hp_buff":   # Bàn thạch: low hp turns the shield on (own cooldown)
			if _special_t[k] <= 0.0 and hp < float(stats.get("max_hp", 100.0)) * float(sp.get("threshold", 0.3)):
				_special_t[k] = float(sp.get("cooldown", 30.0))
				_special_buff(sp)
			continue
		if not sp.has("every") or _special_t[k] > 0.0:
			continue
		_special_t[k] += float(sp["every"])
		trigger_special(sp)


## Fires one timed special now.
func trigger_special(sp: Dictionary) -> void:
	var src := String(sp.get("item", ""))
	var center := player_pos + _hit_center
	var dmg := float(stats.get("damage", 10.0)) * float(sp.get("damage_mul", 1.0))
	match String(sp.get("kind", "")):
		"shield":
			buffs.activate(String(sp.get("buff", "magnetic_shield")), float(sp.get("time", 3.0)))
			_recompute_stats()
			Sfx.play("holy")
		"pulse":
			var reach := float(sp.get("radius", 150.0)) * float(stats.get("area", 1.0))
			enemies.hit_circle(center, reach, dmg, float(sp.get("knockback", 160.0)), src)
			_ring_fx(reach)
			Sfx.play("quake")
		"chain_shock":
			for i in enemies.nearest_n(center, int(sp.get("count", 6))):
				enemies.hit_circle(enemies.center_of(i), 8.0, dmg, 0.0, src)
				enemies.apply_status(i, "shock", {"mul": 1.0, "chain": int(sp.get("chain", 2)),
					"radius": float(sp.get("radius", 120.0))}, dmg, src)
			Sfx.play("zap")
		"burn_aura":
			for i in enemies.living_within(center, float(sp.get("radius", 100.0))):
				enemies.apply_status(i, "burn", {"time": float(sp.get("time", 2.0)), "dps_mul": float(sp.get("damage_mul", 0.3))},
					float(stats.get("damage", 10.0)), src)
		"freeze_nova":
			var reach := float(sp.get("radius", 150.0)) * float(stats.get("area", 1.0))
			for i in enemies.living_within(center, reach):
				enemies.apply_status(i, "freeze", {"time": float(sp.get("time", 1.5))}, 0.0, src)
			_ring_fx(reach)
			Sfx.play("frost")
		"reset_cd":
			_blade_cd = 0.0
			if _whirl_left <= 0.0:
				_whirl_cd = 0.0
			for sid: String in _tier_cd:
				_tier_cd[sid] = 0.0
			_dash_cd = 0.0
			Sfx.play("holy")


## A ring burst drawn as big as the damage circle: the scale comes from the
## sprite's own hitbox radius, so what the player sees is what gets hit.
func _ring_fx(reach: float) -> void:
	var sheet: SpriteSheet = sheets.get("stomp-i")
	var hb := SpriteHitbox.of(sheet, "burst", Vector2.ZERO, 1.0) if sheet != null else null
	var r1 := hb.radius if hb != null and hb.radius > 0.0 else 25.0
	r1 *= float(sheet.meta.get("px_scale", 1.0)) if sheet != null else 1.0   # _add_fx applies px_scale again
	_add_fx("stomp-i", "burst", reach / r1, 0.0)


## A special's buff (shield / haste ...) for its "time".
func _special_buff(sp: Dictionary) -> void:
	if buffs == null:
		return
	buffs.activate(String(sp.get("buff", "magnetic_shield")), float(sp.get("time", 3.0)))
	_recompute_stats()
	Sfx.play("holy")


## kill_proc specials (Huyết quyền, Lưu tinh): every "every_kills" kills heal
## "heal_frac" of max hp and/or start "buff".
func count_special_kills(n: int) -> void:
	for k in specials.size():
		var sp: Dictionary = specials[k]
		if sp.get("kind") != "kill_proc":
			continue
		_special_kills[k] += n
		var every := maxi(1, int(sp.get("every_kills", 30)))
		while _special_kills[k] >= every:
			_special_kills[k] -= every
			if sp.has("heal_frac"):
				heal_max(float(sp["heal_frac"]))
			if sp.has("buff"):
				_special_buff(sp)


## On a hit taken: Phản chấn sends a damaging shockwave, Phong hành starts its
## buff; each with its own cooldown.
func _retaliate() -> void:
	for k in specials.size():
		var sp: Dictionary = specials[k]
		if sp.get("kind") == "hit_buff" and _special_t[k] <= 0.0:
			_special_t[k] = float(sp.get("cooldown", 8.0))
			_special_buff(sp)
			continue
		if sp.get("kind") != "retaliate" or _special_t[k] > 0.0:
			continue
		_special_t[k] = float(sp.get("cooldown", 2.0))
		var dmg := float(stats.get("damage", 10.0)) * float(sp.get("damage_mul", 1.5))
		var reach := float(sp.get("radius", 130.0)) * float(stats.get("area", 1.0))
		enemies.hit_circle(player_pos + _hit_center, reach, dmg, float(sp.get("knockback", 260.0)), String(sp.get("item", "")))
		_ring_fx(reach)
		Sfx.play("boss_slam")


## Tim bất diệt (item revive): once per run, back up with "hp" of max hp. True when
## it just happened.
func try_item_revive() -> bool:
	if _item_revive_used:
		return false
	for sp: Dictionary in specials:
		if sp.get("kind") == "revive":
			_item_revive_used = true
			hp = float(stats.get("max_hp", 100.0)) * float(sp.get("hp", 0.4))
			invuln = float(sp.get("invuln", 2.0))
			_play_action("hurt")
			Sfx.play("milestone")
			return true
	return false


## Bất tử: the first time hp runs out, the hero stands up with revive_hp of max
## hp and invuln s of immunity. True when it just happened (the run goes on).
func try_undying() -> bool:
	if _undying_used or milestones == null:
		return false
	var r := milestones.with_key(rewards, "revive_hp")
	if r.is_empty():
		return false
	_undying_used = true
	hp = float(stats.get("max_hp", 100.0)) * float(r.get("revive_hp", 0.5))
	invuln = float(milestones.number(rewards, "invuln", 2.0))
	_play_action("hurt")
	return true


## The owned milestone rewards for the character sheet: [{id, kind (Vietnamese
## caption), icon, name, desc}], in stage order.
func milestone_rows() -> Array:
	var out := []
	if milestones == null:
		return out
	var kinds := {"skill": "Chiêu độc nhất", "passive": "Nội tại", "rule": "Luật"}
	for id: String in rewards:
		var info := milestones.info(id, pool.get("upgrades", []))
		info["kind"] = String(kinds.get(String(info["kind"]), info["kind"]))
		out.append(info)
	return out


# --- progression -------------------------------------------------------------

func _gain_xp(amount: float) -> void:
	var before := level
	var r := xp_curve.add(level, xp, amount)
	level = r[0]
	xp = r[1]
	_queue_milestones(before, level)
	if int(r[2]) > 0:
		pending_levels += int(r[2])
		_log_level("xp %.0f -> +%d level(s), level %d" % [amount, int(r[2]), level])
		if state == State.PLAYING:
			_open_level_up()


## Milestone levels passed going from [param from] to [param to] join the queue
## (each once per run).
func _queue_milestones(from: int, to: int) -> void:
	if milestones == null:
		return
	for lv in milestones.milestone_levels():
		if from < lv and lv <= to and not _ms_done.has(lv) and not _ms_queue.has(lv):
			_ms_queue.append(lv)


## --log-levels: every source of a level-up pick, with the clock (diagnosis).
func _log_level(what: String) -> void:
	if OS.get_cmdline_user_args().has("--log-levels"):
		printerr("LEVEL %6.1fs pending %d: %s" % [clock, pending_levels, what])


## Level-up panel title: where the pick comes from and how many more wait
## (user 2026-11-18: several picks in a row read as a bug without it).
func level_up_title(chest: bool) -> String:
	var head := "Rương báu! Chọn một" if chest else "Lên cấp %d! Chọn một" % level
	var left := pending_levels - 1
	return head + (" (còn %d lượt)" % left if left > 0 else "")


func _open_level_up() -> void:
	# a milestone reached comes first: one of three rewards for the rest of the run
	if not _ms_queue.is_empty() and milestones != null:
		ms_level = _ms_queue.pop_front()
		_ms_done.append(ms_level)
		var offers := milestones.offers(ms_level, class_id).filter(func(id: String) -> bool: return not rewards.has(id))
		if not offers.is_empty():
			choices.assign(offers)
			state = State.LEVEL_UP
			_demo_pick_t = 0.0
			Sfx.play("milestone")
			_panels.show_milestone_pick(ms_level, choices)
			return
		ms_level = 0
	ms_level = 0
	choices = UpgradeRoller.roll(pool.get("upgrades", []), levels, level_up_card_count(), rng)
	if not offer.is_empty():
		choices = offer.duplicate()
		offer.clear()
	if choices.is_empty():
		pending_levels = 0
		hp = float(stats["max_hp"])
		return
	state = State.LEVEL_UP
	_demo_pick_t = 0.0
	if not _chest_open:
		Sfx.play("level_up")
	level_view = "cards"
	_panels.show_level_up(choices, level_up_title(_chest_open))
	_chest_open = false
	if _level_view_arg != "":
		toggle_level_view(_level_view_arg)
		_level_view_arg = ""


## Level-up views (design/ux/level-up.md): [param v] "character" or "hidden"
## opens that view; asking for the open one goes back to the cards. Only while
## choosing; the run stays paused in every view.
func toggle_level_view(v: String) -> void:
	if state != State.LEVEL_UP:
		return
	level_view = "cards" if level_view == v else v
	if _panels == null:
		return
	match level_view:
		"character": _panels.show_character()
		"hidden": _panels.show_peek()
		_: _panels.reshow()


## Applies choice [param index] of the open level-up and continues the run.
func choose(index: int) -> void:
	if state != State.LEVEL_UP or index >= choices.size():
		return
	var id := choices[index]
	if ms_level > 0:
		take_milestone(id)
		return
	if skill_pick > 0:   # the skill a count card goes on
		add_skill_extra(id, skill_pick)
		skill_pick = 0
		_after_pick()
		return
	levels[id] = int(levels.get(id, 0)) + 1
	var n_pick := int(upgrade(id).get("pick_skill", 0))
	if n_pick > 0 and not skill_pick_ids().is_empty():
		# Thêm đòn / Thêm phép: the player now picks the one skill it adds to
		skill_pick = n_pick
		choices = skill_pick_ids()
		_demo_pick_t = 0.0
		if _panels != null:
			_panels.show_skill_pick(String(upgrade(id).get("name", id)), choices)
		return
	_after_pick()


func _after_pick() -> void:
	var old_max := float(stats.get("max_hp", 100.0))
	_recompute_stats()
	hp += maxf(0.0, float(stats["max_hp"]) - old_max)
	pending_levels -= 1
	if _panels == null:   # unit tests
		return
	_panels.hide_all()
	state = State.PLAYING
	if pending_levels > 0:
		_open_level_up()


## Takes level milestone reward [param id] for the rest of this run, then goes on
## with the waiting level-ups (Bứt tốc adds its picks to them).
func take_milestone(id: String) -> void:
	if not rewards.has(id):
		rewards.append(id)
	apply_rewards()
	var old_max := float(stats.get("max_hp", 100.0))
	_recompute_stats()
	hp += maxf(0.0, float(stats["max_hp"]) - old_max)
	pending_levels += int(milestones.number([id], "picks_now"))
	_log_level("milestone %s -> +%d pick(s)" % [id, int(milestones.number([id], "picks_now"))])
	ms_level = 0
	if _panels == null:   # no scene (unit tests): the numbers only
		return
	_panels.hide_all()
	state = State.PLAYING
	if pending_levels > 0 or not _ms_queue.is_empty():
		_open_level_up()


func upgrade(id: String) -> Dictionary:
	for u: Dictionary in pool.get("upgrades", []):
		if u.get("id") == id:
			return u
	return {}


## What choosing upgrade [param id] changes, for the level-up card:
## { "lines": [[label, now, next], ...], "milestones": [levels], "milestone": text for the
## level about to be gained ("" when it is an ordinary level) }. Numbers come from
## PlayerStats with the upgrade one level higher, so the card shows real values.
func upgrade_preview(id: String) -> Dictionary:
	var u := upgrade(id)
	var lv := int(levels.get(id, 0))
	var nxt := lv + 1
	var max_lv := int(u.get("max_level", 1))
	# "after" is built from the same sources as the current stats (cards, milestones,
	# buffs, equipment, skill tree) plus this card one level up; built from the cards
	# alone it lost every lasting bonus and showed a drop (user 2026-11-18)
	var after_levels := effect_levels()
	after_levels[id] = nxt
	var after := PlayerStats.compute(base_stats, effect_pool(), after_levels)
	var lines := []
	var skills: Dictionary = pool.get("skills", {})
	if u.get("kind") == "skill" and skills.has(id):
		var sp: Dictionary = skills[id]
		lines.append(["Sát thương", "—" if lv == 0 else str(roundi(skill_damage(id, stats))), str(roundi(skill_damage(id, after)))])
		if lv == 0 or not is_equal_approx(skill_size(id, stats), skill_size(id, after)):
			lines.append(["Cỡ", "—" if lv == 0 else "×%.2f" % skill_size(id, stats), "×%.2f" % skill_size(id, after)])
		if sp.has("cooldown"):
			var cd_now := "—" if lv == 0 else "%.1fs" % skill_cooldown(id, stats)
			lines.append(["Hồi chiêu", cd_now, "%.1fs" % skill_cooldown(id, after)])
		# more casts at this level (count grows for dense hordes)
		var now_n := 0 if lv == 0 else _skill_count(id, sp)
		levels[id] = nxt
		var next_n := _skill_count(id, sp)
		levels[id] = lv
		if lv == 0:
			levels.erase(id)
		if next_n != now_n and (lv > 0 or next_n > 1):
			lines.append(["Số lượng", "—" if lv == 0 else str(now_n), str(next_n)])
	else:
		for key: String in u.get("effects", {}):
			if key == "back_slash":
				var ba: Dictionary = skills.get("blade_arc", {})
				var pct := func(l: int) -> String:
					return "—" if l <= 0 else "%d%%" % roundi(100.0 * (float(ba.get("back_damage_mul", 0.5)) + float(ba.get("back_damage_per_level", 0.25)) * (l - 1)))
				lines.append(["Nhát chém sau", pct.call(lv), pct.call(nxt)])
			else:
				lines.append([STAT_LABEL.get(key, key), _fmt_stat(key, float(stats.get(key, 0.0))), _fmt_stat(key, float(after.get(key, 0.0)))])
	# milestones: a new look (tier sprite) at a level, and the last level
	var milestones := [max_lv]
	var tiers: Array = skills.get(id, {}).get("tier_sprites", [])
	for i in range(1, tiers.size()):
		if tiers[i] != tiers[i - 1]:
			milestones.append(i + 1)
	var text := ""
	if tiers.size() > 1 and nxt <= tiers.size() and (nxt == 1 or tiers[nxt - 1] != tiers[nxt - 2]):
		text = "Bậc %s · hình mới" % ["I", "II", "III", "IV", "V"][mini(nxt, 5) - 1]
	# a level that adds a status (on_hit "from") is a milestone too
	for e: Dictionary in skills.get(id, {}).get("on_hit", []):
		var f := int(e.get("from", 1))
		if not milestones.has(f):
			milestones.append(f)
		if f == nxt:
			text = (text + " · " if text != "" else "") + "Thêm: " + String(status_defs.get(String(e.get("status", "")), {}).get("name", e.get("status", "")))
	if nxt == max_lv:
		text = (text + " · " if text != "" else "") + "Cấp tối đa"
	return {"lines": lines, "milestones": milestones, "milestone": text, "level": lv, "max": max_lv}


const STAT_LABEL := {"max_hp": "Máu tối đa", "damage": "Sát thương", "cooldown": "Hồi chiêu", "area": "Vùng đánh", "amount": "Số lượng",
	"move_speed": "Tốc độ chạy", "magnet": "Tầm hút", "regen": "Hồi máu", "armor": "Giáp"}


## "+20", "-0.5", "+1.5": a signed amount without a trailing ".0".
static func signed(v: float) -> String:
	var t := ("%+.1f" % v)
	return t.trim_suffix(".0")


static func _fmt_stat(key: String, v: float) -> String:
	match key:
		"cooldown":   # a multiplier on every skill's cooldown: shown as a change in percent
			var pct := roundi((v - 1.0) * 100.0)
			return "0%" if pct == 0 else "%+d%%" % pct
		"area", "magnet":
			return "×%.2f" % v
		"regen":
			return "%.1f/s" % v
		_:
			return str(roundi(v))


func _recompute_stats() -> void:
	stats = PlayerStats.compute(base_stats, effect_pool(), effect_levels())


## Card upgrades plus active buffs (as level-1 upgrades): what the stats are made of.
func effect_pool() -> Array:
	var out: Array = pool.get("upgrades", []).duplicate()
	if milestones != null:
		out.append_array(milestones.as_upgrades(rewards))   # milestone effects (Song kích)
	if buffs != null:
		out.append_array(buffs.as_upgrades())
	if profile != null:
		out.append_array(profile.as_upgrades(class_id))   # worn equipment
	if tree_owner != null:
		out.append_array(_tree().as_upgrades(tree_owner))   # skill tree nodes bought
	return out


func _tree() -> SkillTree:
	if skill_tree == null:
		skill_tree = SkillTree.load_default()
	return skill_tree


func effect_levels() -> Dictionary:
	var out := levels.duplicate()
	if milestones != null:
		out.merge(milestones.levels(rewards), true)
	if buffs != null:
		out.merge(buffs.levels(), true)
	if profile != null:
		out.merge(profile.levels(class_id), true)
	if tree_owner != null:
		out.merge(_tree().levels(tree_owner), true)
	return out


## A random equipment item for this class (shared ones too), added to the profile
## and saved; "" when there is none.
func _win_item() -> String:
	if profile == null:
		return ""
	var ids := []
	for id: String in profile.defs:
		var d: Dictionary = profile.defs[id]
		if not d.has("class") or String(d["class"]) == class_id:
			ids.append(id)
	if ids.is_empty():
		return ""
	var id: String = ids[rng.randi() % ids.size()]
	profile.add(id)
	Prefs.current().save_profile()
	won_items.append(id)
	return id


## Icon for a card, buff or status id: ui-icons, else the first frame of the
## buff badge / status sprite.
func icon_texture(id: String) -> Texture2D:
	# a card may borrow another icon ("icon" in upgrades_<class>.json)
	var t := UiIcons.texture(String(upgrade(id).get("icon", id)))
	if t != null:
		return t
	var sprite := String(buff_def(id).get("sprite", status_defs.get(id, {}).get("sprite", "")))
	var sh: SpriteSheet = sheets.get(sprite)
	if sh == null:
		return null
	var at := AtlasTexture.new()
	at.atlas = sh.texture
	at.region = sh.src_rect(0)
	return at


## Buff definition (items.json "buffs") or {} for a card id.
func buff_def(id: String) -> Dictionary:
	return _buff_defs.get(id, {})


func xp_needed() -> int:
	return xp_curve.xp_to_next(level)


func _finish(won: bool) -> void:
	var prefs := Prefs.current()
	run_result = {"won": won, "stage": stage_number, "collected": gold, "stage_gold": 0, "gems": 0, "first": false,
		"essence": pickups.essence if pickups != null else 0}
	if playing_slot != null and stages != null and not prefs.is_fixed():
		playing_slot.essence += int(run_result["essence"])   # Tinh hoa picked up is kept, won or lost
		if won and challenge_id != "":   # a challenge: Tẩy Tủy Đan, never stage progress
			var c := Challenges.load_default().record_win(playing_slot, challenge_id)
			playing_slot.gold += gold
			run_result["stage_gold"] = int(c["gold"])
			run_result["pills"] = int(c["pills"])
			run_result["first"] = bool(c["first"])
		elif won:
			var r := playing_slot.record_win(stage_number, stages)
			playing_slot.gold += gold   # coins picked up in the run, on top of stage gold
			run_result["stage_gold"] = int(r.get("gold", 0))
			run_result["gems"] = int(r.get("gems", 0))
			run_result["first"] = bool(r.get("first", false))
		else:
			playing_slot.gold += gold   # Thua: chỉ giữ vàng đã nhặt
		record_daily(playing_slot, won)
		prefs.slot_store().save(playing_slot)
	run_result["next"] = won and challenge_id == "" and stage_number < (stages.count() if stages != null else 30)
	run_result["challenge"] = challenge_id
	run_result["best"] = playing_slot.best if playing_slot != null else 0


## Nhiệm vụ ngày counters from this run (design/missions.md).
func record_daily(slot: Slot, won: bool) -> void:
	var d := Daily.load_default()
	d.add(slot, "runs", 1)
	d.add(slot, "kills", enemies.total_kills if enemies != null else 0)
	d.add(slot, "elite_kills", elite_kills)
	d.add(slot, "essence", int(run_result.get("essence", 0)))
	if won:
		d.add(slot, "challenge_wins" if challenge_id != "" else "stage_wins", 1)


func _die() -> void:
	if try_item_revive():
		print("Item revive: back up at %.0f hp" % hp)
		return
	if try_undying():
		print("Undying: back up at %.0f hp" % hp)
		return
	hp = 0.0
	state = State.DEAD
	_end_t = 0.0
	_set_anim("death")
	Sfx.music("")
	Sfx.play("lose")
	_finish(false)
	print("Run over: lost at %.1fs, level %d, kills %d" % [clock, level, enemies.total_kills])
	_panels.show_end(false)


func _win() -> void:
	state = State.WON
	Sfx.music("")
	Sfx.play("win")
	pickups.pull_all()
	if bool(cfg.get("rewards", {}).get("win_item", false)):
		_win_item()
	_finish(true)
	print("Run over: won, level %d, kills %d, gold %d" % [level, enemies.total_kills, gold])
	_panels.show_end(true)


## Pauses the run and shows the pause menu (Esc, or the HUD's gear button).
func open_pause() -> void:
	if state != State.PLAYING:
		return
	state = State.PAUSED
	_panels.show_pause()


## The upgrades taken so far, in card-pool order: [{id, name, level, max}].
func owned_upgrades() -> Array:
	var out := []
	for u: Dictionary in pool.get("upgrades", []):
		var lv := int(levels.get(u["id"], 0))
		if lv > 0:
			out.append({"id": u["id"], "name": u.get("name", u["id"]), "level": lv, "max": int(u.get("max_level", 1)),
				"skill": u.get("kind") == "skill", "desc": String(u.get("desc", ""))})
	return out


func resume() -> void:
	_panels.hide_all()
	state = State.PLAYING


func restart() -> void:
	get_tree().reload_current_scene()


func next_stage() -> void:
	var prefs := Prefs.current()
	prefs.set_value("stage_target", clampi(stage_number + 1, 1, stages.count() if stages != null else 30))
	get_tree().reload_current_scene()


func to_lobby() -> void:
	get_tree().change_scene_to_file("res://src/lobby/lobby.tscn")


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
	var b := SpriteHitbox.body(hero, Vector2.ZERO, _sprite_scale, face_left)
	if b == null:
		push_error("class sprite has no body circle; regenerate it in Sprite Lab")
		return
	_hit_center = b.center
	if enemies != null:
		enemies.player_hit_radius = b.radius


func _set_anim(anim: String) -> void:
	if _anim != anim:
		_anim = anim
		_anim_t = 0.0


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	var view := Rect2(_camera.position - get_viewport_rect().size * 0.5, get_viewport_rect().size).grow(64.0)
	RunGround.draw(self, view, _arena_half, stage_ground)
	var gem: SpriteSheet = sheets.get(_gem_sprite)
	var coin: SpriteSheet = sheets.get(_coin_sprite)
	for i in pickups.count:
		if view.has_point(pickups.pos[i]):
			var sh := gem if pickups.kind[i] == Pickups.GEM else coin
			if pickups.kind[i] == Pickups.CHEST:
				sh = sheets.get(_chest_sprite)
			elif pickups.kind[i] == Pickups.ESSENCE:
				sh = sheets.get(_essence_sprite)
			if sh != null:
				sh.draw(self, "idle", clock + i * 0.13, pickups.pos[i], _sprite_scale)
	_draw_boss_warnings()
	_draw_boss_waves()
	_draw_ground_buffs(view)
	_draw_zones()
	_draw_ground_fx()
	# dying monsters under the living ones
	for pass_dying in [true, false]:
		for i in enemies.count:
			if (enemies.state[i] == Enemies.DYING) != pass_dying or not view.has_point(enemies.pos[i]):
				continue
			var k := enemies.kind[i]
			var a := enemies.anim_of(i)
			var tint := Color(1.0, 0.55, 0.55) if enemies.flash[i] > 0.0 else _status_tint(i)
			if enemies.state[i] == Enemies.WINDUP:
				tint = Color(1.0, 0.8, 0.5)
			if enemies.k_boss[k] == 1 and enemies.enraged(i) and enemies.flash[i] <= 0.0:
				tint = Color(1.0, 0.62, 0.55)   # enraged: flushed red
			if enemies.k_elite[k] == 1:   # elite: a gold halo under it
				var hr := enemies.k_radius[k]
				var hc := enemies.center_of(i)
				var lab := enemies.affix_label(i)   # the affix colours the halo and names itself (6A)
				var hcol: Color = lab[1] if lab[0] != "" else Color(1.0, 0.82, 0.3)
				hcol.a = 0.5 + 0.3 * sin(clock * 5.0)
				draw_arc(hc + Vector2(0, hr * 0.6), hr * 1.1, 0.0, TAU, 32, hcol, 3.0)
				if lab[0] != "":
					_affix_tags.append([hc - Vector2(0, hr * 1.6 + 14.0), lab[0], lab[1]])
				if tint == Color.WHITE:
					tint = Color(1.0, 0.92, 0.75)
			enemies.k_sheet[k].draw(self, a[0], a[1], enemies.pos[i], enemies.k_scale[k],
				enemies.flip[i] == 1, tint)
	_draw_bolts()
	var hero: SpriteSheet = sheets.get(String(class_data.get("sprite", "swordsman")))
	if hero != null:
		var blink := invuln > 0.0 and state == State.PLAYING and int(invuln * 20.0) % 2 == 0
		var tint := Color(1, 1, 1, 0.45) if blink else Color.WHITE
		_draw_auras("back")
		_draw_fx(true)
		_draw_dash_trail(hero)
		hero.draw(self, _anim, _anim_t, player_pos, _sprite_scale, face_left, tint)
		_draw_auras("front")
	_draw_statuses(view)
	_draw_fx(false)
	if Prefs.current().monster_hp:
		_draw_monster_hp(view)
	if Prefs.current().damage_numbers:
		_draw_damage_numbers(view)
	_draw_affix_tags()
	if show_hitboxes:
		_draw_hitboxes(view)
	# hp bar under the hero
	var w := 44.0
	var bar := Rect2(player_pos + Vector2(-w * 0.5, 8.0), Vector2(w, 5.0))
	draw_rect(bar, Color(0.1, 0.05, 0.08))
	draw_rect(Rect2(bar.position, Vector2(w * clampf(hp / float(stats["max_hp"]), 0.0, 1.0), 5.0)), Color(0.85, 0.2, 0.25))


## Elite affix names, collected while drawing the monsters and drawn last so the
## hero and effects never cover them.
func _draw_affix_tags() -> void:
	var font := ThemeDB.fallback_font
	for t: Array in _affix_tags:
		var tw := font.get_string_size(t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var at: Vector2 = t[0] - Vector2(tw * 0.5, 0)
		draw_string_outline(font, at, t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0.05, 0.04, 0.08))
		draw_string(font, at, t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, t[2])
	_affix_tags.clear()


# --- damage numbers and monster hp bars ------------------------------------------

## Turns this frame's hits into floating numbers (a fixed ring: the oldest is
## reused when full) and ages them.
func _step_damage_numbers(dt: float) -> void:
	for i in _num_t.size():
		if _num_t[i] >= 0.0:
			_num_t[i] += dt
			if _num_t[i] > _num_life:
				_num_t[i] = -1.0
	for k in enemies.hit_pos.size():
		_num_pos[_num_next] = enemies.hit_pos[k] + Vector2(rng.randf_range(-6.0, 6.0), 0.0)
		_num_val[_num_next] = enemies.hit_val[k]
		_num_t[_num_next] = 0.0
		_num_next = (_num_next + 1) % _num_t.size()
	enemies.drain_hits()


## A flying projectile: hits when its fly hitbox (from the sprite) touches a
## monster. explode: the impact animation's hitbox deals the damage; else the fly
## hitbox does and it goes on through "pierce" more. Returns true when spent.
func _step_shot(fx: Dictionary, dt: float) -> bool:
	var sh: Dictionary = fx["shot"]
	sh["wait"] = float(sh["wait"]) - dt
	if float(sh["wait"]) > 0.0:
		return false
	var sheet: SpriteSheet = fx["sheet"]
	var p: Vector2 = fx["pos"]
	var hb := SpriteHitbox.of(sheet, fx["anim"], p, float(fx["scale"]))
	if hb == null or not enemies.overlaps(hb):
		return false
	var src := String(fx.get("source", ""))
	var impact := String(sh["impact"])
	var blast := String(sh.get("impact_sprite", ""))   # a blast drawn as its own sprite (firefx, by tier)
	if bool(sh["explode"]) and blast != "" and sheets.has(blast):
		var b2 := _add_fx(blast, impact, float(fx["scale"]), float(sh["damage"]), -1.0, p, src, float(fx.get("kb", 140.0)))
		if not b2.is_empty():
			b2["effects"] = fx.get("effects", [])
		return true
	if bool(sh["explode"]) and sheet.has_animation(impact):
		var boom := _add_fx(sheet.name, impact, float(fx["scale"]), float(sh["damage"]), -1.0, p, src, float(fx.get("kb", 140.0)))
		if not boom.is_empty():
			boom["effects"] = fx.get("effects", [])
		return true
	enemies.hit_box(hb, float(sh["damage"]), float(fx.get("kb", 140.0)), src, fx.get("effects", []))
	if blast != "" and sheets.has(blast):   # the hit flash from the skill's impact sprite (look only)
		_add_fx(blast, impact, float(fx["scale"]), 0.0, -1.0, p, src)
	elif sheet.has_animation(impact):
		_fx.append({"sheet": sheet, "anim": impact, "t": 0.0, "scale": fx["scale"], "damage": 0.0,
			"done": true, "life": sheet.duration(impact), "pos": p, "follow": false, "source": src})
	sh["pierce"] = int(sh["pierce"]) - 1
	sh["wait"] = 0.15
	return int(sh["pierce"]) < 0


## Skill effects; [param under] = only those drawn behind the hero (ground
## effects such as the stomp), else the rest, over it.
## Effects lying on the floor (skills with "ground_fx"): under the monsters and the hero.
func _draw_ground_fx() -> void:
	for fx in _fx:
		if bool(fx.get("ground", false)):
			var sh: SpriteSheet = fx["sheet"]
			sh.draw(self, fx["anim"], float(fx["t"]), _fx_pos(fx), float(fx["scale"]))


func _draw_fx(under: bool) -> void:
	for fx in _fx:
		if bool(fx.get("under", false)) != under or bool(fx.get("ground", false)):
			continue
		var sh: SpriteSheet = fx["sheet"]
		var looping: bool = fx["anim"] == "spin" or fx.has("shot")
		var t := fmod(float(fx["t"]), sh.duration(fx["anim"])) if looping else float(fx["t"])
		sh.draw(self, fx["anim"], t, _fx_pos(fx), float(fx["scale"]))


## Monster bolts (shooters, design 6A): each kind's bolt_sprite, "fly" looping.
func _draw_bolts() -> void:
	for b in enemies.bolt_pos.size():
		var sh: SpriteSheet = sheets.get(String(enemies.k_extra[enemies.bolt_kind[b]].get("bolt_sprite", "")))
		if sh != null:
			sh.draw(self, "fly", fmod(clock + b * 0.1, sh.duration("fly")), enemies.bolt_pos[b], _sprite_scale)


## The bolt sprite of the shooter kinds (pops are drawn with the first one found).
func _bolt_sprite_at(_p: Vector2) -> String:
	for k in enemies.k_extra.size():
		if enemies.k_extra[k].has("bolt_sprite"):
			return String(enemies.k_extra[k]["bolt_sprite"])
	return ""


func _drain_shocks(dt: float) -> void:
	var i := 0
	while i < _shock_fx.size():
		_shock_fx[i]["t"] = float(_shock_fx[i]["t"]) + dt
		if float(_shock_fx[i]["t"]) > 0.18:
			_shock_fx.remove_at(i)
		else:
			i += 1
	var l := enemies.shock_lines
	for k in range(0, l.size() - 1, 2):
		_shock_fx.append({"a": l[k], "b": l[k + 1], "t": 0.0})
	enemies.shock_lines.clear()


## Status sprites on monsters (statuses.json "at": body / head / feet) and the
## shock arcs. Drawn over the monsters, under the skill effects.
func _draw_statuses(view: Rect2) -> void:
	for i in enemies.count:
		if enemies.state[i] == Enemies.DYING or not view.has_point(enemies.pos[i]):
			continue
		for st in enemies.statuses_of(i):
			var d: Dictionary = status_defs.get(st, {})
			var sh: SpriteSheet = sheets.get(String(d.get("sprite", "")))
			if sh == null:
				continue
			# status sprites are made for a body of radius 8 px: scale to this monster
			var r := enemies.k_radius[enemies.kind[i]]
			var p := enemies.center_of(i)
			if String(d.get("at", "body")) == "head":
				p.y -= r
			sh.draw(self, "loop", clock + i * 0.17, p, r / 8.0)
	for s in _shock_fx:
		var a: Vector2 = s["a"]
		var b: Vector2 = s["b"]
		var pts := PackedVector2Array([a])
		for k in range(1, 5):
			var q := a.lerp(b, k / 5.0)
			pts.append(q + (b - a).orthogonal().normalized() * (6.0 if k % 2 else -6.0))
		pts.append(b)
		draw_polyline(pts, Color(0.5, 0.9, 1.0, 0.35), 6.0)   # glow
		draw_polyline(pts, Color("fff6a0"), 3.0)
		draw_polyline(pts, Color.WHITE, 1.0)
		var sk: SpriteSheet = sheets.get(String(status_defs.get("shock", {}).get("sprite", "")))
		if sk != null:
			sk.draw(self, "loop", float(s["t"]), b, _sprite_scale)


## Tint of monster [param i] from its statuses (freeze / burn / slow), or white.
func _status_tint(i: int) -> Color:
	for st in ["freeze", "burn", "bleed", "slow"]:
		var ok: bool = (st == "freeze" and enemies.freeze_t[i] > 0.0) or (st == "burn" and enemies.burn_t[i] > 0.0) \
			or (st == "bleed" and enemies.bleed_t[i] > 0.0) or (st == "slow" and enemies.slow_t[i] > 0.0)
		if ok and status_defs.get(st, {}).has("tint"):
			return Color(String(status_defs[st]["tint"]))
	return Color.WHITE


## Red circles where a boss is about to land (its slam reach), filling up as the
## landing nears.
func _draw_boss_waves() -> void:
	for w in enemies.wave_pos.size():
		var r := enemies.wave_r[w]
		var p := enemies.wave_pos[w]
		var wd := float(enemies.wave_def[w].get("width", 12.0))
		draw_arc(p, r, 0.0, TAU, 72, Color(0.55, 0.95, 0.6, 0.35), wd)
		draw_arc(p, r, 0.0, TAU, 72, Color(0.85, 1.0, 0.75, 0.95), 3.0)
	var bi := enemies.boss_index()
	if bi >= 0 and _rage_t > 0.0:
		var font := ThemeDB.fallback_font
		var name := String(enemies.k_extra[enemies.kind[bi]].get("name", "Boss")) + " nổi giận!"
		var tw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var at := enemies.center_of(bi) - Vector2(tw * 0.5, enemies.k_radius[enemies.kind[bi]] * 2.0 + 20.0)
		draw_string_outline(font, at, name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color(0.1, 0.02, 0.02))
		draw_string(font, at, name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.4, 0.3))


func _draw_boss_warnings() -> void:
	for w in enemies.boss_telegraphs():
		var p: Vector2 = w[0]
		var r: float = w[1]
		draw_circle(p, r, Color(0.9, 0.1, 0.1, 0.16))
		draw_arc(p, r, 0.0, TAU, 48, Color(1.0, 0.3, 0.3, 0.8), 2.0)
	for b in enemies.blast_pos.size():   # Bọ Lửa: the ring fills up until it goes off
		var p := enemies.blast_pos[b]
		var r := enemies.blast_r[b]
		var k := 1.0 - enemies.blast_t[b] / maxf(0.01, enemies.blast_total[b])
		draw_circle(p, r * k, Color(1.0, 0.45, 0.1, 0.22))
		draw_arc(p, r, 0.0, TAU, 40, Color(1.0, 0.55, 0.2, 0.55 + 0.4 * k), 2.0)


## Afterimages of the hero along the dash path (the camera follows the hero, so
## without them a dash only shows as the ground sliding).
func _draw_dash_trail(hero: SpriteSheet) -> void:
	if _dash_trail <= 0.0:
		return
	var fade := clampf(_dash_trail / 0.3, 0.0, 1.0)
	for k in range(1, 4):
		var p := _dash_from.lerp(player_pos, float(k) / 4.0)
		hero.draw(self, _anim, _anim_t, p, _sprite_scale, face_left, Color(0.65, 0.85, 1.0, 0.18 * k * fade))


## Buffs lying on the ground: the badge bobbing; blinking in the last seconds.
func _draw_ground_buffs(view: Rect2) -> void:
	for g: Dictionary in buffs.ground:
		var p: Vector2 = g["pos"]
		if not view.has_point(p):
			continue
		var left := buffs.lifetime - float(g["age"])
		if left < buffs.blink and int(left * 8.0) % 2 == 0:
			continue
		var sh: SpriteSheet = sheets.get(String(buff_def(g["id"]).get("sprite", "")))
		if sh != null:
			sh.draw(self, "idle", float(g["age"]), p, _sprite_scale)


## The aura of each running buff on [param layer] ("back" behind the hero,
## "front" over it). Auras use the hero's frame and feet anchor, so they are drawn
## at the hero's position and scale; each buff owns a zone (feet, sides, above the
## head, a bubble round the whole hero), in items.json order (shield last).
func _draw_auras(layer: String) -> void:
	for id: String in _buff_defs:
		if not buffs.is_active(id):
			continue
		var d := buff_def(id)
		if String(d.get("aura_layer", "front")) != layer:
			continue
		var sh: SpriteSheet = sheets.get(String(d.get("aura", "")))
		if sh == null or not sh.has_animation("loop"):
			continue
		sh.draw(self, "loop", clock, player_pos, _sprite_scale)


func _draw_damage_numbers(view: Rect2) -> void:
	var font := ThemeDB.fallback_font
	for i in _num_t.size():
		var t := _num_t[i]
		if t < 0.0 or not view.has_point(_num_pos[i]):
			continue
		var u := t / _num_life
		var a := 1.0 if u < 0.6 else 1.0 - (u - 0.6) / 0.4
		var p := (_num_pos[i] - Vector2(30.0, _num_rise * u)).round()
		var txt := str(maxi(1, roundi(_num_val[i])))
		draw_string_outline(font, p, txt, HORIZONTAL_ALIGNMENT_CENTER, 60.0, _num_size, 4, Color(0.1, 0.05, 0.08, a))
		draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_CENTER, 60.0, _num_size, Color(1.0, 0.93, 0.6, a))


## Hp bar over each monster hit in the last ui.hp_bar_time seconds.
func _draw_monster_hp(view: Rect2) -> void:
	for i in enemies.count:
		if enemies.hp_show[i] <= 0.0 or enemies.state[i] == Enemies.DYING or not view.has_point(enemies.pos[i]):
			continue
		var k := enemies.kind[i]
		var r := enemies.k_radius[k]
		var w := maxf(16.0, r * 2.0)
		var top := (enemies.center_of(i) - Vector2(w * 0.5, r + 8.0)).round()
		var frac := clampf(enemies.hp[i] / enemies.k_hp[k], 0.0, 1.0)
		draw_rect(Rect2(top - Vector2(1, 1), Vector2(w + 2.0, 5.0)), Color(0.1, 0.05, 0.08))
		draw_rect(Rect2(top, Vector2(roundf(w * frac), 3.0)), Color(0.9, 0.25, 0.3))


func _draw_hitboxes(view: Rect2) -> void:
	var body := Color(0.3, 1.0, 0.4, 0.8)
	for i in enemies.count:
		if enemies.state[i] != Enemies.DYING and view.has_point(enemies.pos[i]):
			draw_arc(enemies.center_of(i), enemies.k_radius[enemies.kind[i]], 0.0, TAU, 16, body, 1.0)
	var center := player_pos + _hit_center
	draw_arc(center, enemies.player_hit_radius, 0.0, TAU, 16, Color(0.3, 0.7, 1.0), 1.5)
	draw_arc(center, pickups.radius * float(stats.get("magnet", 1.0)), 0.0, TAU, 48, Color(0.3, 0.7, 1.0, 0.35), 1.0)
	for fx in _fx:
		var hb := SpriteHitbox.of(fx["sheet"], fx["anim"], _fx_pos(fx), float(fx["scale"]))
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
