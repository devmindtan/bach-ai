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
##   --spawn-only=ID[,ID] only the waves of these monsters spawn, from the start (shots)
##   --event=K@T     run event K (ring | collect | hunt | tornado | root_snare | poison_tide) at T seconds (shots)
##   --show-special-fx=T  every special card's effect drawn once at T seconds, look only (shots)
##   --pool-here     a poison pool under the hero's start (shots of the poison look)
##   --vfx=N         Cài đặt "Hiệu ứng" level for shots (0 Đầy đủ, 1 Giảm, 2 Tối thiểu)
##   --debug-overlay show the F1 debug overlay from the start (shots)
##   --hitboxes      draw hit areas: effects (red while dealing damage), monster
##                   bodies, the player's body and pickup radius
##   --bench=N       keep N monsters alive around a god-mode autopilot, print
##                   frame timings after 600 frames, then quit

const PLAYER_BODY := 8.0   # the hero's foot radius against rocks and trees
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
var endless := false         # Chế độ Vô tận (design/endless.md); --endless for shots
var _endless: Endless
var challenge_id := ""        # playing a challenge (design/challenge.md); --challenge=ID for shots
var _win_on_boss := true
var boss_stage := false
const POISON_LOOK := 0.2   # s the poison look stays after leaving a pool
var poison_t := 0.0
var root_t := 0.0     # the hero is rooted (Rễ trói): seconds left
var bleed_t := 0.0     # the hero bleeds (a Thú bite, design/species.md): seconds left
var bleed_dps := 0.0
var _pool_here := false      # --pool-here          # > 0: the hero stands in poison (pool look)
var _outro_t := -1.0          # the boss outro: seconds left (-1 not started, 0 over)
var _last_boss_name := "Boss"   # a wave of this stage spawns a boss: won only by killing it
var _delayed: Array = []
var _mark_sprite := ""   # Đánh dấu's reticle (tier sprite), drawn over the marked monster
var _clone := {}   # Phân thân (design/rogue-kits.md): {pos, life, face} while the shadow stands
var _casting_clone := false
var _clone_pass := false   # this cast is the shadow's (half damage)
var _traps: Array = []   # Bẫy gai (design/rogue-kits.md): armed traps {pos, sid, life, dmg, sc, sprite, kb, trigger}
var _pets := {}   # Chim ưng (design/rogue-kits.md): skill id -> {pos, state idle|dive|back, target, dmg, sc, t}
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
var _shot_gold_chest := false   # --gold-chest
var _level_now := false          # --level-now
var _gold_left := 0         # picks left from an opened Rương vàng (their panels say so)
var _chest_sprite := "chest"
var _gold_chest_sprite := "chest-gold"
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
var _xp_rng := RandomNumberGenerator.new()   # its own stream: XP drop rolls must not shift spawns
var _owned_count_done := false     # Đa phép already gave its +1 to the skills owned when picked
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
var _ward_charges := 0     # Bàn thạch: one-hit block, spent on contact
var _ward_buff := ""       # buff id whose aura shows the ward is still up
var level := 1
var xp := 0.0
var gold := 0
var rarity: CardRarity = null   # card rarity rolls and their pity (design/card-rarity.md)
var rerolls := 0   # Đổi charges left this run (6C.3)
var banishes := 0  # Loại charges left
var skips := 0     # Bỏ qua charges left
var banished: Array[String] = []   # cards out of the deck for this run
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
var _absorb_fx: Array = []   # [{a, b, t}] Hấp thụ đệ tethers fading out
var _hp_min := INF                  # lowest hp this run (the balance log)
var _knock := Vector2.ZERO          # px/s the hero is being pushed (boss transition, shockwave), decays
var _rage_t := 0.0                    # seconds the "nổi giận" call still shows
var _rage_seen := false
var _boss_hp_share := -1.0
var wave_call := ""                   # the latest wave call ("Bầy dơi kéo tới!"), shown by the HUD
var wave_call_t := 0.0                # seconds the wave call still shows
var _end_t := 0.0
# floating damage numbers (ring buffer, sizes from run_config "ui")
var _num_pos := PackedVector2Array()
var _num_val := PackedFloat32Array()
var mark_style := "ring"   # run_config marks.style (roadmap F); --mark-style= in shots
var _marks_cfg := {}
var _sil_cache := {}       # sprite name -> white silhouette SpriteSheet (outline mark)
var _num_tag := PackedByteArray()    # 1 = weak element (red), 2 = resisted (grey): design/species.md
var _num_crit := PackedByteArray()   # 1 = that number is a crit (bigger, orange, "!")
var shake := ScreenShake.new()       # camera shake (6C.2); Cài đặt can turn it off
var _hitstop := 0.0                  # s the sim stays frozen after a crit on an elite / boss
var _crit_cfg: Dictionary = {}
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
var deck_cards: Array = []   # the active deck's card ids (design/skill-tree-v2.md §2)
var bosses_killed := 0   # this run, for Mảnh thẻ
var chests_opened := 0   # this run, for Mảnh thẻ
var challenges := ChallengeEvents.new()   # Vòng thử thách / Thu thập sao / Săn tinh anh (challenge_events.gd)
var _forced_events: Array = []   # --event=K@T
var obstacles: Obstacles = null   # the stage's rocks / trees / poison pools (design/obstacles.md)
var _obstacle_view := ObstacleView.new()   # rocks / trees drawing (obstacle_view.gd)
var _sheet := RunSheet.new()   # character sheet / card preview data (run_sheet.gd)
var _kill_drops := KillDrops.new()
var _level := LevelFlow.new()
var region_ev := RegionEvents.new()   # the region's own event (region_events.gd)
var _heal_fx: Array = []   # [{p, r, t}] Hồn Đầm heal rings being drawn
var _spawn_only := ""   # --spawn-only=ID (shots)
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
var hit_spark_sprite := ""   # --hit-spark=a|b|c (shots: compare the spark options)
var dash_at := -1.0          # --dash-at=T (shots)
var monster_hp_mul := 1.0    # --monster-hp=N (shots: monsters live long enough to show statuses)
var _status_all: Array[String] = []   # --status-all=a,b (shots: every monster gets these statuses)
var _status_all_t := 0.0
var damage_taken := 0.0   # end-of-run table
var healed := 0.0
var end_tab := "dealt"   # --end-tab=dealt|taken|heal (shots): the end report view shown first
var escape_sprite := ""   # monsters.json escape_sprite: drawn where a fleeing monster got away
var taken_by := {}     # end report (roadmap B, 2026-11-22): hp lost by source ("monster", "pool", "event.*")
var still_t := 0.0   # seconds the hero has not walked (Mắt ưng)
var reduced_by := {}   # damage prevented by source ("armor", "passive", "ward")
var heal_by := {}      # hp healed by source ("regen", a card id, "milestone", ...)


## Rows of a ledger for the end report: [{name (Vietnamese), value, share}] largest first. Names: "monster" Quái,
## "pool" Vũng độc, event sources by run_config events.source_names, "armor" Giáp, "passive" the class passive,
## "ward" the stone shell, "regen", "bloodthirst", "vs_status", card ids by their card name.
func ledger_rows(d: Dictionary) -> Array:
	var total := 0.0
	for k: String in d:
		total += float(d[k])
	var names := {"monster": "Quái", "pool": "Vũng độc", "bleed": "Chảy máu (Thú cắn)", "armor": "Giáp", "ward": "Vỏ đá (Bàn thạch)",
		"regen": "Hồi máu theo thời gian", "bloodthirst": "Khát máu", "heal": "Khác",
		"passive": String(passive().get("name", "Nội tại")), "vs_status": String(passive().get("name", "Nội tại")), "far": String(passive().get("name", "Nội tại"))}
	var ev: Dictionary = cfg.get("events", {}).get("source_names", {})
	var out := []
	for k: String in d:
		var nm := String(names.get(k, ev.get(k, upgrade(k).get("name", k))))
		out.append({"name": nm, "value": float(d[k]), "share": float(d[k]) / maxf(1.0, total)})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["value"]) > float(y["value"]))
	return out


## What a hit of [param amount] costs after armor and the passive, recorded by source (taken / prevented).
func _account_hit(amount: float, src := "monster") -> float:
	var after_armor := amount * armor_mul(float(stats.get("armor", 0.0)), _armor_k)
	var taken := maxf(1.0, after_armor * damage_taken_mul())
	_add_to(reduced_by, "armor", amount - after_armor)
	_add_to(reduced_by, "passive", after_armor - after_armor * damage_taken_mul())
	_add_to(taken_by, src, taken)
	return taken


func _add_to(d: Dictionary, key: String, v: float) -> void:
	if v > 0.0:
		d[key] = float(d.get(key, 0.0)) + v
var _demo_pick_t := 0.0

var _sprite_scale := 2.0
var _gem_sprite := "exp-gem"    # from items.json pickups
var _coin_sprite := "gold-coin"
var _arena_half := 1400.0
var _hit_center := Vector2(0, -26)
var _camera: Camera2D
var _status_max_shown := 2   # statuses.json max_shown
var _status_view_cache: StatusView
var _vfx_alpha := 1.0      # Cài đặt "Hiệu ứng": fades skill / status effects, never bolts or bodies
var _ground: GroundLayer   # cached arena floor (src/run/ground_layer.gd)
var _hud: RunHud
var _panels: RunPanels


func _init() -> void:   # helpers get the run before _ready: tests build a Run with .new()
	_sheet.run = self
	_level.run = self
	_kill_drops.run = self


func _ready() -> void:
	region_ev.run = self
	_obstacle_view.run = self
	challenges.run = self
	RunArgs.apply(self)
	RunInput.register()
	cfg = GameData.load_json(DATA + "run_config.json")
	_armor_k = float(cfg.get("player", {}).get("armor_k", 15.0))
	_cd_floor = float(cfg.get("player", {}).get("cooldown_floor", 0.0))
	stages = Stages.load_default()
	milestones = Milestones.load_default()
	var prefs := Prefs.current()
	if prefs.active_slot != null and not prefs.is_fixed():
		playing_slot = prefs.active_slot
		if not _stage_arg_set:
			stage_number = clampi(prefs.stage_target, 1, stages.count())
	stage_number = clampi(stage_number, 1, stages.count())
	if challenge_id == "" and not endless:
		challenge_id = prefs.challenge_target
	endless = endless or prefs.endless_target
	if endless:   # Vô tận (design/endless.md): the highest won non-boss stage, looping in Vòng
		_endless = Endless.load_default()
		challenge_id = ""
		if not _stage_arg_set:
			stage_number = _endless.base_stage(playing_slot.best if playing_slot != null else prefs.preview_best, stages)
	if challenge_id != "" and not Challenges.load_default().get_def(challenge_id).is_empty():
		stage = Challenges.load_default().build(challenge_id)   # a stage with the challenge's rules
		stage_number = int(Challenges.load_default().get_def(challenge_id).get("base", stage_number))
		_win_on_boss = bool(stage.get("win_on_boss", true))
	else:
		challenge_id = ""
		stage = stages.load_stage(stage_number)
	stage_ground = stages.ground(stage_number)
	challenges.ring_cfg = cfg.get("events", {}).get("ring", {})
	challenges.ring_times = []
	for ev: Dictionary in stages.region(stage_number).get("events", []):
		if not events_open(cfg, stage_number) or not event_enabled(cfg, String(ev.get("kind", ""))):
			continue   # stages before events.min_stage are quiet; --event below still forces one
		if String(ev.get("kind", "")) == "ring" and challenge_id == "":
			challenges.ring_times.append(float(ev.get("t", 60.0)))
		elif String(ev.get("kind", "")) in RegionEvents.OWN_EVENTS and challenge_id == "":
			region_ev.times.append([float(ev.get("t", 150.0)), String(ev["kind"])])
		elif String(ev.get("kind", "")) in ["collect", "hunt"] and challenge_id == "":
			challenges.field_times.append([float(ev.get("t", 120.0)), String(ev["kind"])])
	for fe: Array in _forced_events:   # --event (shots)
		match String(fe[1]):
			"ring": challenges.ring_times = [fe[0]]
			"tornado", "root_snare", "poison_tide": region_ev.times = [fe]
			_: challenges.field_times = [fe]
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
	_num_crit.resize(n_max)
	_num_tag.resize(n_max)
	_crit_cfg = cfg.get("crit", {})
	_level.reset_actions()
	shake.enabled = Prefs.current().screen_shake
	_num_t.resize(n_max)
	_num_t.fill(-1.0)

	var items := GameData.load_json(DATA + "items.json")
	_gem_sprite = String(items.get("pickups", {}).get("xp_gem", {}).get("sprite", "exp-gem"))
	_coin_sprite = String(items.get("pickups", {}).get("gold", {}).get("sprite", "gold-coin"))
	_chest_sprite = String(items.get("pickups", {}).get("chest", {}).get("sprite", "chest"))
	_gold_chest_sprite = String(items.get("pickups", {}).get("gold_chest", {}).get("sprite", "chest-gold"))
	_essence_sprite = String(items.get("pickups", {}).get("essence", {}).get("sprite", "essence-pickup"))
	var names: Array[String] = [hero_sprite_name(), _gem_sprite, _coin_sprite, _chest_sprite, _gold_chest_sprite, _essence_sprite, "stomp-i"]
	_buff_defs = items.get("buffs", {})
	var status_file := GameData.load_json(DATA + "statuses.json")
	status_defs = status_file.get("statuses", {})
	_status_max_shown = int(status_file.get("max_shown", 2))
	for st: String in status_defs:
		names.append(String(status_defs[st].get("sprite", "")))
		if status_defs[st].has("burst_sprite"):   # Thánh ấn / Ăn mòn bursts
			names.append(String(status_defs[st]["burst_sprite"]))
	names.append_array(special_fx_sprites())
	names.append(RootSnare.SPRITE)   # Rễ trói (Rừng Âm U's event)
	for b: String in _buff_defs:
		if not bool(_buff_defs[b].get("special_only", false)):
			names.append(String(_buff_defs[b].get("sprite", b)))
		if _buff_defs[b].has("aura"):
			names.append(String(_buff_defs[b]["aura"]))
		if _buff_defs[b].has("aura_back"):
			names.append(String(_buff_defs[b]["aura_back"]))
		if _buff_defs[b].has("break_sprite"):   # one-shot when the ward spends its hit
			names.append(String(_buff_defs[b]["break_sprite"]))
	for kind: Dictionary in stages.region(stage_number).get("obstacles", {}).get("solid", []):
		names.append(String(kind.get("sprite", "")))
	for m: String in monsters:
		if not m.begins_with("_"):
			names.append(String(monsters[m].get("sprite", m)))
			if monsters[m].has("bolt_sprite"):   # a shooter's bolt
				names.append(String(monsters[m]["bolt_sprite"]))
			if monsters[m].has("escape_sprite"):   # the gold goblin's escape puff (was typed in kill_drops, bug 2026-11-22)
				names.append(String(monsters[m]["escape_sprite"]))
				escape_sprite = String(monsters[m]["escape_sprite"])
			if monsters[m].has("rage_sprite"):   # a boss's red body while enraged
				names.append(String(monsters[m]["rage_sprite"]))
			if monsters[m].has("root_sprite"):   # Mộc Yêu's roots
				names.append(String(monsters[m]["root_sprite"]))
	var deck_cfg: Dictionary = CardTree.load_default().data.get("deck", {"skills": 8, "stats": 6, "slots": 3})
	deck_cards = Deck.active(playing_slot if not Prefs.current().is_fixed() else null, pool.get("upgrades", []),
		class_data.get("start_skills", {}).keys(), deck_cfg)
	var in_run := skills_in_run()   # only the skills this run can use (roadmap item 3, review 2026-11-21)
	for sk: String in pool.get("skills", {}):
		if not in_run.has(sk):
			continue
		var sd: Dictionary = pool["skills"][sk]
		names.append(String(sd.get("sprite", sk)))
		for tn in sd.get("impact_tiers", []):
			names.append(String(tn))
		if sd.has("zone") and sd["zone"].get("kind", "") == "burn":
			names.append(String(sd["zone"].get("sprite", "scorch")))
		for tn in sd.get("tier_sprites", []):
			names.append(String(tn))
	for u: Dictionary in pool.get("upgrades", []):   # a stat card with its own look (Kết liễu's burst, by tier)
		for tn in u.get("fx_tiers", []):
			names.append(String(tn))
	var hf: Dictionary = cfg.get("hit_feel", {})   # cảm giác đánh: the hit spark
	if not hf.is_empty():
		names.append(hit_spark_sprite if hit_spark_sprite != "" else String(hf.get("sprite", "hit-spark-a")))
	for n in names:
		if not sheets.has(n):
			sheets[n] = SpriteSheet.load_dir(SPRITES + n, n)
	# the hero is layered: compose it here; equipment will pass its layers as overrides
	var hero_sheet: SpriteSheet = sheets.get(names[0])
	if hero_sheet != null and not hero_sheet.layer_names().is_empty():
		hero_sheet.compose_layers()

	enemies = Enemies.new(monsters, cfg, sheets, rng.seed)
	var elems := {}
	for u: Dictionary in pool.get("upgrades", []):
		if u.has("element"):
			elems[String(u["id"])] = String(u["element"])
	enemies.status_defs = status_defs
	_marks_cfg = cfg.get("marks", {})
	if mark_style == "ring":
		mark_style = String(_marks_cfg.get("style", "ring"))
	enemies.set_species(GameData.load_json("res://assets/data/species.json"), elems)   # design/species.md
	if challenge_id == "" and bench == 0:   # the region's props, seeded by the stage (same map every time)
		obstacles = Obstacles.new(stages.region(stage_number).get("obstacles", {}), _arena_half, stage_number * 7919 + 13)
		enemies.obstacles = obstacles
	if _pool_here and obstacles != null:
		obstacles.pools.append({"p": player_pos, "r": 60.0})
		obstacles.pool_dps = maxf(obstacles.pool_dps, 1.0)
	var bal: Dictionary = cfg.get("balance", {})   # global tuning (run_config.json balance, 2026-11-20)
	enemies.scale_kinds(stages.hp_mul(stage_number) * float(stage.get("hp_mul", 1.0)) * float(bal.get("monster_hp_mul", 1.0)),
		stages.damage_mul(stage_number) * float(bal.get("monster_damage_mul", 1.0)))
	for k in enemies.k_xp.size():   # fewer monsters must not mean slower levels: each gives more xp
		enemies.k_xp[k] *= float(bal.get("xp_mul", 1.0))
	for k in enemies.k_hp.size():
		enemies.k_hp[k] *= monster_hp_mul
	enemies.vs_status_mul = passive_vs_status()
	enemies.far_mul = float(passive().get("far_mul", 0.0))   # Mắt ưng (archer)
	enemies.far_px = float(passive().get("far_px", 200.0))
	_apply_hit_stats()
	_update_body()
	pickups = Pickups.new(cfg.get("pickups", {}), 400)
	if _shot_gold_chest:
		pickups.drop(Pickups.GOLD_CHEST, player_pos + Vector2(60, 0), 1.0)   # inside the magnet: it is picked up
	if _level_now:
		pending_levels += 1
		_level.open.call_deferred()
		if "--banish-mode" in OS.get_cmdline_user_args():   # shots: Loại armed
			(func() -> void: _panels.toggle_banish()).call_deferred()
	buffs = Buffs.new(_buff_defs, cfg.get("buffs", {}), rng.seed + 7)
	seed_xp_drops(rng.seed)
	for id in _forced_buffs:
		buffs.activate(id)
	for k in _ground_buffs.size():
		buffs.ground.append({"id": _ground_buffs[k], "pos": Vector2(120.0 + 70.0 * k, -60.0), "age": 0.0})
	var wave_list: Array = stage.get("waves", [])
	var mdefs := GameData.load_json(DATA + "monsters.json")
	for w: Variant in wave_list:   # a boss among the waves: the stage is won by killing it (stage_won)
		if w is Dictionary and bool(mdefs.get(String(w.get("monster", "")).get_slice("@", 0), {}).get("boss", false)):
			boss_stage = challenge_id == "" or _win_on_boss
	if _spawn_only != "":   # shots: one species alone, its waves moved to the start
		var only: Array = []
		for w: Dictionary in wave_list:
			if String(w.get("monster", "")) in _spawn_only.split(","):
				var w2 := w.duplicate()
				w2["t_to"] = 1.0 if w.has("burst") else float(w2.get("t_to", 300.0)) - float(w2.get("t_from", 0.0))
				w2["t_from"] = 1.0 if w.has("burst") else 0.0
				only.append(w2)
		wave_list = only
	var spawn_mul := float(cfg.get("balance", {}).get("spawn_mul", 1.0))
	if spawn_mul != 1.0:   # fewer, stronger monsters (balance 2026-11-20); bosses and event monsters untouched
		var scaled: Array = []
		for w: Dictionary in wave_list:
			var m: Dictionary = monsters.get(String(w.get("monster", "")).get_slice("@", 0), {})
			if bool(m.get("boss", false)) or m.has("spawn_dist"):
				scaled.append(w)
				continue
			var w2 := w.duplicate()
			for key in ["rate", "rate_end"]:
				if w2.has(key):
					w2[key] = float(w2[key]) * spawn_mul
			if w2.has("burst"):
				w2["burst"] = maxi(1, roundi(float(w2["burst"]) * spawn_mul))
			scaled.append(w2)
		wave_list = scaled
	waves = WaveScheduler.new(wave_list)
	base_stats = class_data.get("stats", {})
	profile = playing_slot.profile if playing_slot != null else prefs.profile()
	tree_owner = prefs.active_slot
	for id in _gear:
		profile.add(id)
		profile.equip(class_id, id)
		if _gear_plus > 0:
			profile.plus[id] = _gear_plus
	set_specials(card_specials())   # specials come from cards now, not items (user 2026-11-20)
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
	if VirtualStick.wanted(Prefs.current().touch_stick):   # phones (J4)
		var stick := VirtualStick.new()
		stick.run = self
		layer.add_child(stick)
		layer.move_child(stick, _panels.get_index())   # under the panels, over the HUD

	# --milestone=N (shots): the level milestone pick opens at the start
	if not _ms_queue.is_empty():
		_level.open.call_deferred()
	elif _pick_card != "":   # --pick-card=ID (shots): its skill pick at the start
		(func() -> void:
			choices.assign([_pick_card])
			state = State.LEVEL_UP
			pending_levels += 1
			_level.choose(0)).call_deferred()

	if bench > 0:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		for i in bench:
			var a := rng.randf() * TAU
			enemies.spawn(enemies.kind_ids[i % enemies.kind_ids.size()],
				Vector2(cos(a), sin(a)) * rng.randf_range(140.0, 700.0))


func _process(delta: float) -> void:
	if bench > 0:
		_dbg().bench_sample()
	var t0 := Time.get_ticks_usec()
	var slow := 1.0
	if _outro_t > 0.0:   # the boss outro: the world slows, the timer runs in real time
		_outro_t = maxf(0.0, _outro_t - delta)
		slow = float(cfg.get("boss_outro", {}).get("time_scale", 0.35))
	for _i in sim_steps:
		_tick((STEP if sim_steps > 1 or bench > 0 else minf(delta, 0.05)) * slow)
	var sim_us := Time.get_ticks_usec() - t0
	if bench > 0 or _debug != null:
		_dbg().add_tick(sim_us)
	_camera.position = player_pos.round()
	if OS.get_cmdline_user_args().has("--count-log") and Engine.get_process_frames() % 300 == 0:
		printerr("GK: t=%.0f alive=%d" % [clock, enemies.living()])
	shake.enabled = Prefs.current().screen_shake   # the pause menu's Cài đặt can turn it off mid-run
	_vfx_alpha = Prefs.current().vfx_alpha()       # Cài đặt "Hiệu ứng" (also mid-run)
	_camera.offset = shake.step(delta, Engine.get_process_frames())
	queue_redraw()
	_hud.queue_redraw()


## Level-up view keys come here, before the GUI: Tab is also Godot's focus key and
## the card buttons ate it (user 2026-11-18), so it is taken and marked handled.
func _input(event: InputEvent) -> void:
	if state != State.LEVEL_UP:
		return
	if event is InputEventKey and event.pressed and not event.echo and level_view == "cards":   # Đổi / Loại / Bỏ qua
		var done := true
		match event.keycode:
			KEY_R: _level.reroll()
			KEY_X:
				if _panels != null: _panels.toggle_banish()
			_: done = false   # Bỏ qua has no key: S also walks, a tap must not throw a level away
		if done:
			get_viewport().set_input_as_handled()
			return
	var v := "character" if event.is_action_pressed("character") else ("hidden" if event.is_action_pressed("peek") else "")
	if v == "":
		return
	_level.toggle_view(v)
	if is_inside_tree():
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		toggle_debug_overlay()   # review 2026-11-21: fps / sim / monsters / FX at a glance
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		if state == State.PLAYING:
			open_pause()
		elif state == State.PAUSED:
			resume()
	elif event.is_action_pressed("dash") and state == State.PLAYING:
		try_dash()
	elif event.is_action_pressed("character"):
		if state == State.PLAYING:
			open_pause()
			_panels.show_character()
		elif state == State.PAUSED:
			resume()
	elif state == State.LEVEL_UP and level_view == "cards":   # no blind picks
		for i in 3:
			if event.is_action_pressed("choose_%d" % (i + 1)) and i < choices.size():
				_level.choose(i)
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
			_level.choose(0)
		return
	if state != State.PLAYING:
		return
	if _hitstop > 0.0:   # a crit on an elite / boss: the world holds for a few frames (6C.2)
		_hitstop -= dt
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
	if _outro_t < 0.0 and endless:   # Vô tận: the waves start again at each Vòng
		for span: Array in Endless.spans(clock - dt, clock, duration):
			_spawn(float(span[0]), float(span[1]))
	elif _outro_t < 0.0:   # no new monster once the boss has fallen
		_spawn(clock - dt, clock)
	challenges.step(dt)
	region_ev.step(dt)
	_hp_min = minf(_hp_min, hp)
	for i in range(_absorb_fx.size() - 1, -1, -1):
		_absorb_fx[i]["t"] = float(_absorb_fx[i]["t"]) - dt
		if float(_absorb_fx[i]["t"]) <= 0.0:
			_absorb_fx.remove_at(i)
	_step_pools_hazard(dt)
	_step_bleed(dt)
	enemies.spawn_hp_mul = time_mul(wave_clock(), "hp") * endless_mul("hp")   # stronger each minute (time_scale) / Vòng
	var contact := enemies.step(dt, player_pos, player_pos + _hit_center) * time_mul(wave_clock(), "damage") * endless_mul("damage")
	if god and contact > 0.0 and invuln <= 0.0:   # balance runs: count what would have been taken, keep the hp
		damage_taken += _account_hit(contact)   # god (balance runs): counted by source too
		invuln = float(cfg.get("player", {}).get("hit_invuln", 0.6))
	if contact > 0.0 and invuln <= 0.0 and bench == 0 and not god and not buffs.invulnerable() and _dash_left <= 0.0:
		if not _spend_ward():
			_take_hit(contact)
			if not enemies.contact_bleed.is_empty():   # Sói: the bite bleeds
				bleed_t = maxf(bleed_t, float(enemies.contact_bleed.get("time", 3.0)))
				bleed_dps = maxf(bleed_dps if bleed_t > 0.0 else 0.0, contact * float(enemies.contact_bleed.get("dps_mul", 0.25)))
		else:
			_add_to(reduced_by, "ward", contact)
	invuln = maxf(0.0, invuln - dt)
	var had := buffs.active.size()
	buffs.step(dt, player_pos + _hit_center, enemies.player_hit_radius if enemies != null else 0.0)
	if buffs.active.size() != had or not buffs.picked_ids().is_empty():
		_recompute_stats()
	_step_guardian(dt)
	step_specials(dt)
	var before := hp
	hp = minf(float(stats["max_hp"]), hp + float(stats.get("regen", 0.0)) * dt)
	healed += maxf(0.0, hp - before)
	_add_to(heal_by, "regen", hp - before)
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
	_kill_drops.step()
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
	if pickups.gold_chests > 0 and state == State.PLAYING:   # Rương vàng: several picks, gold, a sure item
		pickups.gold_chests -= 1
		open_gold_chest()
		_level.open()
	elif pickups.chests > 0 and state == State.PLAYING:   # a chest from an elite: one extra pick
		pickups.chests -= 1
		Sfx.play("chest")
		if rng.randf() < float(cfg.get("rewards", {}).get("chest_item_chance", 0.0)):
			_win_item()
		pending_levels += 1
		_level.log_level("chest -> +1 pick")
		chests_opened += 1
		_chest_open = true
		_level.open()
	for p in enemies.bolt_pops:   # monster bolts that burst (hit or out of range)
		_add_fx(_bolt_sprite_at(p), "pop", _sprite_scale, 0.0, -1.0, p)
	enemies.bolt_pops.clear()
	if not enemies.blasts_done.is_empty():
		Sfx.play("fire")
	for p in enemies.blasts_done:   # death bursts that went off
		_add_fx("stomp-i", "burst", _sprite_scale * 1.2, 0.0, -1.0, p)
	enemies.blasts_done.clear()
	if not enemies.roots_done.is_empty():
		Sfx.play("quake")
	var boss_i := enemies.boss_index()
	var root_sprite := String(enemies.k_extra[enemies.kind[boss_i]].get("root_sprite", "tree-roots")) if boss_i >= 0 else "tree-roots"
	for p in enemies.roots_done:   # Mộc Yêu roots spearing up
		_add_fx(root_sprite, "erupt", _sprite_scale * 1.3, 0.0, -1.0, p)
	enemies.roots_done.clear()
	for hp_ in enemies.heal_pulses:   # Hồn Đầm heals: a green ring running out (drawn for 0.5 s)
		_heal_fx.append({"p": hp_[0], "r": float(hp_[1]), "t": 0.0})
	enemies.heal_pulses.clear()
	var hk := 0
	while hk < _heal_fx.size():
		_heal_fx[hk]["t"] = float(_heal_fx[hk]["t"]) + dt
		if float(_heal_fx[hk]["t"]) > 0.5:
			_heal_fx.remove_at(hk)
			continue
		hk += 1
	if not enemies.slams.is_empty():
		Sfx.play("boss_slam")
	for p in enemies.slams:   # boss landings: a dust ring where it hit the ground
		_add_fx("stomp-i", "burst", _sprite_scale * 1.6, 0.0, -1.0, p)
	enemies.slams.clear()
	_step_fx(dt)
	_step_pets(dt)
	_step_clone(dt)
	_step_traps(dt)
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
		var pn := enemies.phase_name(bi)
		if pn != "":   # also across the screen: the boss may be off screen (its own label would be cut)
			wave_call = "%s · %s!" % [String(enemies.k_extra[enemies.kind[bi]].get("name", "Boss")), pn]
			wave_call_t = 3.0
		Sfx.play("boss_spawn")
	_boss_check_t -= dt
	if _boss_check_t <= 0.0:   # the boss song while a boss lives
		_boss_check_t = 0.5
		var boss := enemies.boss_index() >= 0
		_update_boss_aura()
		if boss != _boss_music:
			_boss_music = boss
			Sfx.music("boss" if boss else run_music)
			if boss:
				Sfx.play("boss_spawn")
	if hp <= 0.0:
		_die()
	elif stage_won() and bench == 0:
		if boss_stage and _outro_t < 0.0:
			_start_boss_outro()
		elif not boss_stage or _outro_t == 0.0:
			_win()


func _move_player(dt: float) -> void:
	if _knock.length_squared() > 1.0:   # pushed (a boss transforming, a shockwave): slides, decays
		player_pos += _knock * dt
		_knock *= exp(-5.0 * dt)
		player_pos = _keep_inside(player_pos)
		if obstacles != null:
			player_pos = obstacles.push_out(player_pos, PLAYER_BODY)
		player_pos = enemies.push_out_walls(player_pos, PLAYER_BODY)
	for pp: Array in enemies.phase_push:   # a boss starts phase 2: the hero is pushed away and the screen shakes
		var away: Vector2 = player_pos - pp[0]
		_knock += (away.normalized() if away.length() > 1.0 else Vector2.RIGHT) * float(pp[1])
		shake.add(6.0)
	enemies.phase_push.clear()
	for tp: Array in enemies.tongue_pull:   # Cóc Độc Bào Tử's tongue caught the hero: dragged to the boss
		var to: Vector2 = tp[0] - player_pos
		_knock = to.normalized() * maxf(0.0, to.length() - 30.0) * 5.0   # decays at 5/s: covers that distance
		shake.add(5.0)
	enemies.tongue_pull.clear()
	for wk: Array in enemies.wave_knock:   # a knockback shockwave: thrown away from its centre
		var off: Vector2 = player_pos - wk[0]
		_knock += (off.normalized() if off.length() > 1.0 else Vector2.RIGHT) * float(wk[1])
	enemies.wave_knock.clear()
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
	if root_t > 0.0:   # Rễ trói: rooted, cannot walk (attacks go on; the dash still breaks free)
		root_t = maxf(0.0, root_t - dt)
		dir = Vector2.ZERO
	_moving = dir.length_squared() > 0.01
	still_t = 0.0 if _moving else still_t + dt   # Mắt ưng counts how long the hero has stood still
	if _moving:
		facing = dir.normalized()
		if absf(facing.x) > 0.1:
			face_left = facing.x < 0.0
			_update_body()
		player_pos += dir.limit_length(1.0) * float(stats["move_speed"]) * dt
		player_pos = _keep_inside(player_pos)
		if obstacles != null:
			player_pos = obstacles.push_out(player_pos, PLAYER_BODY)
		player_pos = enemies.push_out_walls(player_pos, PLAYER_BODY)
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
	_leave_clone(player_pos)
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
	player_pos = _keep_inside(player_pos)
	if obstacles != null:
		player_pos = obstacles.push_out(player_pos, PLAYER_BODY)
	player_pos = enemies.push_out_walls(player_pos, PLAYER_BODY)   # a root wall is solid: no dashing through
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
		var near := float(enemies.k_extra[enemies.kind_of(id)].get("spawn_dist", 0.0)) if enemies.kind_of(id) >= 0 else 0.0
		if near > 0.0:   # event monsters (Yêu tinh vàng) appear on screen, not on the far spawn ring
			enemies.spawn(id, player_pos + Vector2.from_angle(rng.randf() * TAU) * near)
		else:
			enemies.spawn(id, enemies.ring_point(player_pos))


## The hero's bleed (a Thú bite): bleed_dps hp a second while bleed_t lasts; god / invulnerable skip it.
func _step_bleed(dt: float) -> void:
	if bleed_t <= 0.0:
		return
	bleed_t = maxf(0.0, bleed_t - dt)
	if god or buffs.invulnerable():
		return
	var d := bleed_dps * dt
	hp -= d
	damage_taken += d
	_add_to(taken_by, "bleed", d)


func _take_hit(amount: float, src := "monster") -> void:
	var taken := _account_hit(amount, src)
	shake.add(clampf(taken * float(_crit_cfg.get("shake_per_hurt", 0.25)), 2.0, 7.0))   # a boss slam shakes harder
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

## Level-up panel title: where the pick comes from and how many more wait
## (user 2026-11-18: several picks in a row read as a bug without it).
func level_up_title(chest: bool) -> String:
	return _level.title(chest)

## Level-up views (design/ux/level-up.md): [param v] "character" or "hidden"
## opens that view; asking for the open one goes back to the cards. Only while
## choosing; the run stays paused in every view.
func toggle_level_view(v: String) -> void:
	_level.toggle_view(v)

## Charges of Đổi / Loại / Bỏ qua for a new run (run_config.json level_actions, 6C.3).
func reset_level_actions() -> void:
	_level.reset_actions()

## Đổi: a new hand for one charge; false (nothing changes) without one.
func reroll() -> bool:
	return _level.reroll()

## Loại: card [param index] leaves the deck for the rest of the run, then a new hand.
func banish(index: int) -> bool:
	return _level.banish(index)

## Bỏ qua: the level is used without a card, for skip_gold gold.
func skip_level() -> bool:
	return _level.skip_level()

## Applies choice [param index] of the open level-up and continues the run.
func choose(index: int) -> void:
	_level.choose(index)


# --- skills ------------------------------------------------------------------

func _skills(dt: float) -> void:
	var skills: Dictionary = pool.get("skills", {})
	if levels.get("blade_arc", 0) > 0:
		var s: Dictionary = skills["blade_arc"]
		_blade_cd -= dt
		if _blade_cd <= 0.0:
			_blade_cd = skill_cooldown("blade_arc")
			var dmg := skill_damage("blade_arc")
			var sc := _sprite_scale * skill_size("blade_arc")
			var sprite := _skill_sprite("blade_arc", s)   # tier I-V by level
			_aim()
			var off := float(s.get("offset", 0.0)) * skill_size("blade_arc")
			_add_fx(sprite, _slash_anim(attack_dir), sc, dmg, -1.0, null, "blade_arc")["offset"] = attack_dir * off
			# amount: one more slash at each next nearest monster's side
			var extra := amount_for("blade_arc")
			if extra > 0:
				var done := [attack_dir]
				for i in enemies.nearest_n(player_pos + _hit_center, extra + 4):
					var d2 := slash_dir(enemies.center_of(i) - (player_pos + _hit_center))
					if not done.has(d2):
						done.append(d2)
						_add_fx(sprite, _slash_anim(d2), sc, dmg, -1.0, null, "blade_arc")["offset"] = d2 * off
						if done.size() > extra:
							break
			var back := int(levels.get("back_slash", 0))
			if back > 0:
				var mul := float(s.get("back_damage_mul", 0.5)) + float(s.get("back_damage_per_level", 0.25)) * (back - 1)
				_add_fx(sprite, _slash_anim(-attack_dir), sc, dmg * mul, -1.0, null, "back_slash")["offset"] = -attack_dir * off
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
				var fx := _add_fx(_skill_sprite("whirlwind", w), "spin", sc, 0.0, _whirl_left)
				if bool(w.get("under_hero", false)) and not fx.is_empty():
					fx["under"] = true   # a ring around the hero: keep him on top
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
	if tree_owner != null and lv > 0:   # statuses the card tree adds (design/skill-tree-v2.md)
		out.append_array(_card_tree().on_hit(tree_owner, sid))
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
	return int(skill_extra.get(sid, 0)) + int(stats.get("amount", 0.0)) + int(stats.get("skill_count." + sid, 0.0))


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
	if how == "projectile" and not _clone.is_empty() and not _casting_clone:   # Phân thân: the shadow fires too
		_casting_clone = true   # guards both nested casts against firing the shadow again
		_clone_pass = false
		_cast(sid, ts, how)
		var saved := player_pos
		player_pos = _clone["pos"]
		_clone_pass = true
		_cast(sid, ts, how)
		_clone_pass = false
		_casting_clone = false
		player_pos = saved
		return
	var dmg := skill_damage(sid) * (float(cfg.get("clone", {}).get("damage_mul", 0.5)) if _clone_pass else 1.0)
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
		"mark":
			# Đánh dấu: keep the mark on a living monster in reach; else move it to the one with the most hp
			var lv := clampi(int(levels.get(sid, 1)) - 1, 0, 4)
			var muls: Array = ts.get("mark_mul", [0.25])
			enemies.mark_mul = float(muls[mini(lv, muls.size() - 1)])
			var cur := enemies.index_of_uid(enemies.mark_uid)
			if cur < 0 or enemies.center_of(cur).distance_to(center) > float(ts.get("cast_range", 420.0)):
				var best := -1
				for i in enemies.living_within(center, float(ts.get("cast_range", 420.0))):
					if best < 0 or enemies.hp[i] > enemies.hp[best]:
						best = i
				enemies.mark_uid = enemies.uid[best] if best >= 0 else -1
			_mark_sprite = sprite
		"trap":
			# Bẫy gai: armed traps between the hero and the nearest monster (around the hero when none), at most trap_max
			for k in _skill_count(sid, ts):
				var spot := center + to_target.rotated((k - 1) * 0.6) * 90.0
				if target_i >= 0:
					spot = center.lerp(enemies.center_of(target_i), 0.55) + Vector2(rng.randf_range(-24, 24), rng.randf_range(-24, 24))
				_traps.append({"pos": spot, "sid": sid, "life": float(ts.get("trap_life", 8.0)), "dmg": dmg, "sc": sc,
					"sprite": sprite, "kb": kb, "trigger": float(ts.get("trigger", 22.0))})
			while _traps.size() > int(ts.get("trap_max", 6)):
				_traps.pop_front()
		"orbit":
			# Lốc dao (design/rogue-kits.md): the spin follows the hero for duration (by level), cutting every rehit s
			var durs: Variant = ts.get("duration", 2.5)
			var life := float(durs[clampi(int(levels.get(sid, 1)) - 1, 0, (durs as Array).size() - 1)]) if durs is Array else float(durs)
			var fx := _add_fx(sprite, String(ts.get("anim", "spin")), sc, dmg, life, null, sid, kb)
			if not fx.is_empty():
				fx["rehit"] = float(ts.get("rehit", 0.3))
		"pet":
			# Chim ưng: the companion dives at the monster with the most hp in cast_range
			var best := -1
			for i in enemies.living_within(center, float(ts.get("cast_range", 360.0))):
				if best < 0 or enemies.hp[i] > enemies.hp[best]:
					best = i
			_step_pets(0.0)
			if best >= 0 and _pets.has(sid):
				var pet: Dictionary = _pets[sid]
				pet["state"] = "dive"
				pet["target"] = enemies.center_of(best)
				pet["dmg"] = dmg
				pet["sc"] = sc
				pet["sprite"] = sprite
				pet["kb"] = kb
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
		"crowd":
			# Cột thánh quang (2026-11-22): each column on the thickest crowd left, the next ones on other crowds
			var near := enemies.living_within(center, float(ts.get("cast_range", 300.0)))
			if near.size() > 60:   # nearest 60 are enough, keeps it O(60^2)
				near.sort_custom(func(x: int, y: int) -> bool: return enemies.pos[x].distance_squared_to(center) < enemies.pos[y].distance_squared_to(center))
				near.resize(60)
			var pts: Array = near.map(func(i: int) -> Vector2: return enemies.pos[i])
			for j: int in crowd_pick(pts, float(ts.get("crowd_radius", 60.0)), _skill_count(sid, ts)):
				_add_fx(sprite, String(ts.get("anim", "burst")), sc, dmg, -1.0, pts[j], sid, kb)
		"projectile":
			# fired at the nearest monster; several fan out 12 degrees apart
			var n := _skill_count(sid, ts)
			var speed := float(ts.get("speed", 340.0))
			var charge := 0.0   # Tên tích lực (design/rogue-kits.md): share of charge_time the hero has stood still
			if ts.has("charge_time"):
				charge = clampf(still_t / maxf(0.01, float(ts["charge_time"])), 0.0, 1.0)
				dmg *= 1.0 + charge * float(ts.get("charge_mul", 1.0))
				sc *= 1.0 + charge * float(ts.get("charge_size", 0.5))
			for k in n:
				var dv := to_target.rotated(deg_to_rad(12.0 * (k - (n - 1) * 0.5)))
				var anim := _fly_anim(sprite, String(ts.get("anim_prefix", "fly_")), dv)
				# leaves from in front of the hero, not from its face (user 2026-11-18)
				var fx := _add_fx(sprite, anim, sc, 0.0, float(ts.get("duration", 1.2)) * range_mul(), center + dv * 18.0, sid, kb)
				if fx.is_empty():
					continue
				fx["vel"] = dv * speed
				fx["impact_scale"] = float(ts.get("impact_scale", 1.0))   # undoes the shot's own px_scale for its blast (Lưới)
				if bool(ts.get("boomerang", false)):   # Dao hồi (design/rogue-kits.md): out for out_time s, then home back
					var outs: Array = ts.get("out_time", [0.4])
					fx["boomerang"] = float(outs[clampi(int(levels.get(sid, 1)) - 1, 0, outs.size() - 1)])
					fx["prefix"] = String(ts.get("anim_prefix", "fly_"))
				var bounces: Array = ts.get("bounce", [0])   # Tên nảy (design/rogue-kits.md): bounces by level
				fx["bounce"] = int(bounces[clampi(int(levels.get(sid, 1)) - 1, 0, bounces.size() - 1)])
				fx["bounce_range"] = float(ts.get("bounce_range", 180.0))
				fx["bounce_mul"] = float(ts.get("bounce_mul", 0.1))
				fx["prefix"] = String(ts.get("anim_prefix", "fly_"))
				fx["shot"] = {"damage": dmg, "explode": bool(ts.get("explode", false)), "pierce": int(ts.get("pierce", 0)) + int(round(charge * float(ts.get("charge_pierce", 0)))),
					"impact": String(ts.get("impact", "impact")), "wait": 0.0,
					"impact_sprite": _tier_name(ts.get("impact_tiers", []), sid)}
		"wave":
			# Sóng kiếm (cleave-wave-redesign.md): a fan toward the nearest monster, widening as it flies,
			# each monster hit once; level >= split.from breaks into small blades at the end
			var lv := int(levels.get(sid, 1))
			var spreads: Array = ts.get("spread_deg", [0])
			var spread := float(spreads[clampi(lv - 1, 0, spreads.size() - 1)])
			for deg: float in wave_fan(_skill_count(sid, ts), spread):
				var dv := to_target.normalized().rotated(deg_to_rad(deg))
				_launch_wave(sprite, ts, dv, center, sc, dmg, sid, kb, float(ts.get("duration", 0.9)), lv, true)


## Indices of [param n] points on the thickest crowds: each pick has the most points within [param radius],
## and points within that radius of a pick are left out of the next picks (columns spread over crowds).
static func crowd_pick(pts: Array, radius: float, n: int) -> Array:
	var r2 := radius * radius
	var left: Array = range(pts.size())
	var out := []
	while out.size() < n and not left.is_empty():
		var best := -1
		var best_score := -1
		for i: int in left:
			var score := 0
			for j: int in left:
				if (pts[i] as Vector2).distance_squared_to(pts[j]) <= r2:
					score += 1
			if score > best_score:
				best_score = score
				best = i
		out.append(best)
		left = left.filter(func(j: int) -> bool: return (pts[best] as Vector2).distance_squared_to(pts[j]) > r2)
	return out


## Angles (degrees) of [param n] waves fanned [param spread] apart around the aim: 1 -> [0], 2 -> [-s, s],
## 3 -> [-s, 0, s]; more keep the same step.
static func wave_fan(n: int, spread: float) -> Array:
	if n <= 1:
		return [0.0]
	var out := []
	for k in n:
		var t := float(k) - (n - 1) / 2.0
		out.append(t * (spread * 2.0 if n == 2 else spread))
	return out


## Scale factor of a flying wave at [param t] (0 start .. 1 end of its flight): grow.from -> grow.to[level].
static func wave_grow(grow: Dictionary, level: int, t: float) -> float:
	var to: Array = grow.get("to", [1.0])
	return lerpf(float(grow.get("from", 1.0)), float(to[clampi(level - 1, 0, to.size() - 1)]), clampf(t, 0.0, 1.0))


func _launch_wave(sprite: String, ts: Dictionary, dv: Vector2, at: Vector2, sc: float, dmg: float, sid: String,
		kb: float, life: float, lv: int, main: bool) -> void:
	var fx := _add_fx(sprite, _fly_anim(sprite, String(ts.get("anim_prefix", "fly_")), dv), sc, dmg, life, at, sid, kb)
	if fx.is_empty():
		return
	fx["vel"] = dv * float(ts.get("speed", 300.0))
	fx["hit_once"] = {}
	fx["base_scale"] = float(fx["scale"])
	fx["grow"] = ts.get("grow", {}) if main else {}
	fx["lv"] = lv
	var sp: Dictionary = ts.get("split", {})
	if main and not sp.is_empty() and lv >= int(sp.get("from", 99)):
		fx["split"] = sp


## A wave that reaches the end of its flight at level >= split.from breaks into small blades.
func _split_wave(fx: Dictionary) -> void:
	var sp: Dictionary = fx["split"]
	var ts: Dictionary = pool.get("skills", {}).get(String(fx["source"]), {})
	var dv := (fx["vel"] as Vector2).normalized()
	for deg: float in wave_fan(int(sp.get("count", 3)), float(sp.get("spread_deg", 60)) / 2.0):
		_launch_wave(String((fx["sheet"] as SpriteSheet).name), ts, dv.rotated(deg_to_rad(deg)), fx["pos"],
			float(fx["base_scale"]) * float(sp.get("scale", 0.55)) / float((fx["sheet"] as SpriteSheet).meta.get("px_scale", 1.0)),
			float(fx["damage"]) * float(sp.get("damage_mul", 0.4)), String(fx["source"]), 60.0,
			float(sp.get("duration", 0.45)), int(fx["lv"]), false)


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
## A skill's base damage before its own cards: "scale" {stat: coefficient} sums stat x coefficient
## (e.g. {"damage": 1.0, "armor": 1.0}: hits harder with more armor; roadmap 2026-11-21, after
## Brotato's per-weapon scaling); without "scale", damage x damage_mul.
## "Scale theo: sát thương ×1.0 + giáp ×1.0" for a skill with "scale", "" otherwise.
func scale_text(id: String) -> String:
	return _sheet.scale_text(id)


static func skill_base(sp: Dictionary, st: Dictionary) -> float:
	var sc: Dictionary = sp.get("scale", {})
	if sc.is_empty():
		return float(st.get("damage", 0.0)) * float(sp.get("damage_mul", 1.0))
	var total := 0.0
	for k: String in sc:
		total += float(st.get(k, 0.0)) * float(sc[k])
	return total


func skill_damage(id: String, st: Dictionary = {}) -> float:
	if st.is_empty():
		st = stats
	var sp: Dictionary = pool.get("skills", {}).get(id, {})
	var dmg := skill_base(sp, st) * PlayerStats.skill_mul(st, "skill_damage." + id)
	if passive_active():
		dmg *= 1.0 + float(class_data.get("passive", {}).get("damage_mul", 0.0))
	return dmg


## The class passive (classes.json "passive"), {} when none.
func passive() -> Dictionary:
	return class_data.get("passive", {})


## Range multiplier of projectiles: Mắt ưng's still_range_mul while the hero has stood still (1 otherwise).
func range_mul() -> float:
	return 1.0 + float(passive().get("still_range_mul", 0.0)) if passive().has("still_s") and passive_active() else 1.0


## True while a low-hp passive is on (hp under passive.hp_below of max).
func passive_active() -> bool:
	var p := passive()
	if p.has("still_s"):   # Mắt ưng: standing still long enough
		return still_t >= float(p["still_s"])
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
	# every lasting reduction together stops at -40% (run_config player.cooldown_floor, user 2026-11-20);
	# timed buffs (Rune tốc độ) come on top of the cap (user 2026-11-23)
	var floor_mul := float(cfg.get("player", {}).get("cooldown_floor", 0.0))
	var bsum := buff_cooldown_sum()
	var lasting := float(st.get("cooldown", 1.0)) - bsum
	return float(sp.get("cooldown", 1.0)) * maxf(floor_mul, lasting * own) * maxf(0.2, 1.0 + bsum)


## The cooldown "mul" of every active timed buff added up (e.g. Rune tốc độ -0.25): kept out of the cap.
func buff_cooldown_sum() -> float:
	if buffs == null:
		return 0.0
	var out := 0.0
	for u: Dictionary in buffs.as_upgrades():
		out += float(u.get("effects", {}).get("cooldown", {}).get("mul", 0.0))
	return out


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
		var ev_names: Dictionary = cfg.get("events", {}).get("source_names", {})
		if u.is_empty() and ev_names.has(k):   # an in-run event (Mưa thiên thạch)
			u = {"name": String(ev_names[k]), "icon": String(cfg["events"].get("source_icons", {}).get(k, "star"))}
		rows.append({"id": k, "name": u.get("name", "Khác"), "icon": String(u.get("icon", k)), "damage": d,   # never a raw id
			"share": d / total if total > 0.0 else 0.0, "hits": int(enemies.hits_by.get(k, 0)),
			"kills": int(enemies.kills_by.get(k, 0)), "dps": d / maxf(1.0, clock)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["damage"] > b["damage"])
	return rows


## What a card does right now, in numbers, for the pause menu: one line per
## effect, e.g. "Hồi chiêu -40% (0.54 s) · áp lên: Chém kiếm, Lốc xoáy".
func card_effect_text(id: String) -> String:
	return _sheet.card_effect_text(id)


## Owned skills (kind "skill"), pool order: {id, name, level, max, damage, cooldown,
## size, base_damage, base_cooldown, sources}. sources = the cards changing this
## skill: [{id, name, level, what, text}], e.g. what "Hồi chiêu", text "-20%".
func skill_info() -> Array:
	return _sheet.skill_info()


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
## The run's bench and F1 overlay live in RunDebug (src/run/run_debug.gd).
var _debug: RunDebug
var _boss_view := BossView.new(self)   # boss / monster mechanics drawing (src/run/boss_view.gd)


func _dbg() -> RunDebug:
	if _debug == null:
		_debug = RunDebug.new(self)
	return _debug


func toggle_debug_overlay() -> void:
	_dbg().toggle()


func debug_overlay_text(sim_ms: float) -> String:
	return _dbg().overlay_text(sim_ms)


## Effects that failed to show (sprite not loaded / animation missing), each "sprite:anim" once. Review
## 2026-11-21: _add_fx returned {} silently, so a mistyped effect name was just "nothing on screen".
var missing_fx: PackedStringArray = []


func _warn_missing_fx(sprite: String, anim: String, loaded: bool) -> void:
	var key := "%s:%s" % [sprite, anim]
	if missing_fx.has(key):
		return
	missing_fx.append(key)
	if loaded:
		push_warning("FX: sprite '%s' has no animation '%s' (effect not drawn)" % [sprite, anim])
	else:
		push_warning("FX: sprite '%s' is not loaded for this run (effect '%s' not drawn); add it to the run's sprite list or check the name" % [sprite, anim])


func _add_fx(sprite: String, anim: String, sc: float, damage: float, life := -1.0, world_pos: Variant = null,
		source := "", knockback := 140.0) -> Dictionary:
	var sheet: SpriteSheet = sheets.get(sprite)
	if sheet == null or not sheet.has_animation(anim):
		_warn_missing_fx(sprite, anim, sheet != null)
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
	var z := {"kind": kind, "pos": hb.center, "r": hb.radius * float(zd.get("radius_mul", 1.0)),
		"wait": start, "t": float(zd.get("time", hits)), "life": float(zd.get("time", hits)),
		"tick": 0.0, "src": src, "dmg": dmg, "zd": zd}
	if kind == "pulse":   # Bão sét (user 2026-11-22): pulses = the tier's bolt columns, evenly over the zone's time
		var pl: Array = zd.get("pulses", [2])
		var n := maxi(1, int(pl[clampi(int(levels.get(src, 1)) - 1, 0, pl.size() - 1)]))
		z["every"] = float(z["life"]) / n
		z["tick"] = float(z["every"]) * 0.5   # mid-slot: the last pulse lands before the zone ends
		z["sheet"] = sheet
		z["sc"] = sc
		z["at"] = at
	zones.append(z)


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
		elif z["kind"] == "pulse":
			z["tick"] = float(z["tick"]) - dt
			if float(z["tick"]) <= 0.0:
				z["tick"] = float(z["tick"]) + float(z["every"])
				enemies.hit_circle(c, float(z["r"]), float(z["dmg"]) * float(zd.get("damage_mul", 0.35)), 30.0,
					String(z["src"]), on_hit(String(z["src"])))
				Sfx.play("zap")
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
		if z["kind"] == "pulse" and float(z["wait"]) <= 0.0:   # the storm cloud lingers, bolts flickering
			var ps: SpriteSheet = z["sheet"]
			if ps.has_animation("linger"):
				var fade_p := clampf(float(z["t"]) / 0.4, 0.0, 1.0)
				ps.draw(self, "linger", float(z["life"]) - float(z["t"]), z["at"], float(z["sc"]), false, Color(1, 1, 1, fade_p))
			continue
		if z["kind"] != "burn" or float(z["wait"]) > 0.0:
			continue
		var sh: SpriteSheet = sheets.get(String(z["zd"].get("sprite", "scorch")))
		if sh == null:
			continue
		var fade := clampf(float(z["t"]) / 0.6, 0.0, 1.0)
		sh.draw(self, "loop", clock, z["pos"], float(z["r"]) / (sh.frame_size.x * 0.5), false, Color(1, 1, 1, fade))


func _fx_pos(fx: Dictionary) -> Vector2:
	if bool(fx.get("follow", true)):   # offset: a slash sits out in front (blade_arc "offset", user 2026-11-21)
		return player_pos + _hit_center + (fx.get("offset", Vector2.ZERO) as Vector2)
	return fx.get("pos", player_pos + _hit_center)


func _step_fx(dt: float) -> void:
	var i := 0
	while i < _fx.size():
		var fx: Dictionary = _fx[i]
		fx["t"] = float(fx["t"]) + dt
		if fx.has("boomerang") and float(fx["t"]) >= float(fx["boomerang"]) and _step_boomerang(fx):
			_fx.remove_at(i)
			continue
		if fx.has("vel"):
			fx["pos"] = (fx["pos"] as Vector2) + (fx["vel"] as Vector2) * dt
		if not (fx.get("grow", {}) as Dictionary).is_empty():   # Sóng kiếm widens as it flies
			fx["scale"] = float(fx["base_scale"]) * wave_grow(fx["grow"], int(fx["lv"]), float(fx["t"]) / float(fx["life"]))
		if fx.has("shot") and _step_shot(fx, dt):
			_fx.remove_at(i)
			continue
		if not fx["done"]:
			var hb := SpriteHitbox.of(fx["sheet"], fx["anim"], _fx_pos(fx), float(fx["scale"]))
			if hb == null:
				fx["done"] = true
			elif fx.has("hit_once"):   # each monster once, every step (Sóng kiếm)
				if hb.is_active(float(fx["t"])):
					enemies.hit_box(hb, float(fx["damage"]), float(fx.get("kb", 140.0)), String(fx.get("source", "")), fx.get("effects", []), fx["hit_once"])
			elif hb.is_active(float(fx["t"])) and float(fx.get("hit_wait", 0.0)) <= 0.0:
				enemies.hit_box(hb, float(fx["damage"]), float(fx.get("kb", 140.0)), String(fx.get("source", "")), fx.get("effects", []))
				if fx.has("rehit"):
					fx["hit_wait"] = float(fx["rehit"])
				else:
					fx["done"] = true
			fx["hit_wait"] = float(fx.get("hit_wait", 0.0)) - dt
		if float(fx["t"]) >= float(fx["life"]):
			if fx.has("split"):
				_split_wave(fx)
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
	set_specials(card_specials())   # a special card reward works at once
	# Đa phép: +N count to the skills owned right now, once (user 2026-11-20: not to skills learnt later)
	var tc := milestones.with_key(rewards, "owned_skill_count")
	if not tc.is_empty() and not _owned_count_done:
		_owned_count_done = true
		for sid: String in pool.get("skills", {}):
			if int(levels.get(sid, 0)) > 0:
				add_skill_extra(sid, int(tc["owned_skill_count"]))
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
func heal_max(frac: float, src := "heal") -> float:
	var top := float(stats.get("max_hp", hp))
	var before := hp
	hp = minf(top, hp + top * frac)
	healed += hp - before
	_add_to(heal_by, src, hp - before)
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

## The run's specials from its cards (the former item specials, user 2026-11-20): every card with a
## "special" at level >= 1, scaled by special_per_level for each level past the first (a key the special
## has is added; "x_mul" multiplies x by 1 + value per level). "item" = the card id (the damage source).
func card_specials() -> Array:
	var out := []
	for u: Dictionary in pool.get("upgrades", []):
		var lv := int(levels.get(String(u.get("id", "")), 0))
		if lv <= 0 or not u.has("special"):
			continue
		var sp: Dictionary = u["special"].duplicate()
		var per: Dictionary = u.get("special_per_level", {})
		for key: String in per:
			var step := float(per[key]) * (lv - 1)
			if sp.has(key):
				sp[key] = float(sp[key]) + step
			elif key.ends_with("_mul") and sp.has(key.trim_suffix("_mul")):
				var base := key.trim_suffix("_mul")
				var v := float(sp[base]) * maxf(0.1, 1.0 + step)
				sp[base] = roundi(v) if sp[base] is int else v
		sp["item"] = String(u["id"])
		out.append(sp)
	return out


## Sets the active specials and their timers (each "every" starts full).
var show_special_fx_at := -1.0   # --show-special-fx=T (shots): draw every special card's effect once at T s


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
	if show_special_fx_at >= 0.0 and clock >= show_special_fx_at:   # shots: every special card's look, once
		show_special_fx_at = -1.0
		for sp: Dictionary in specials:
			if String(sp.get("fx", "")) == "":
				continue
			if String(sp.get("kind", "")) in ["retaliate", "pulse", "freeze_nova", "burn_aura"]:
				_ring_fx(float(sp.get("radius", 120.0)), String(sp["fx"]), "shock" if sp["fx"] == "retaliate-shock" else "cast")
			else:
				_item_fx(sp)
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
			_special_buff(sp)
		"pulse":
			var reach := float(sp.get("radius", 150.0)) * float(stats.get("area", 1.0))
			enemies.hit_circle(center, reach, dmg, float(sp.get("knockback", 160.0)), src)
			var ring_sprite := String(sp.get("fx", "stomp-i"))
			_ring_fx(reach, ring_sprite, "cast" if ring_sprite != "stomp-i" else "burst")
			Sfx.play("quake")
		"chain_shock":
			for i in enemies.nearest_n(center, int(sp.get("count", 6))):
				if String(sp.get("strike_fx", "")) != "":   # a bolt falls on each struck monster (H3, 2026-11-22)
					_add_fx(String(sp["strike_fx"]), "strike", _sprite_scale, 0.0, -1.0, enemies.pos[i])
				enemies.hit_circle(enemies.center_of(i), 8.0, dmg, 0.0, src)
				enemies.apply_status(i, "shock", {"mul": 1.0, "chain": int(sp.get("chain", 2)),
					"radius": float(sp.get("radius", 120.0))}, dmg, src)
			_item_fx(sp)
			Sfx.play("zap")
		"burn_aura":
			for i in enemies.living_within(center, float(sp.get("radius", 100.0))):
				enemies.apply_status(i, "burn", {"time": float(sp.get("time", 2.0)), "dps_mul": float(sp.get("damage_mul", 0.3))},
					float(stats.get("damage", 10.0)), src)
			# no ring round the hero (user 2026-11-25: it only sets monsters on fire; the spinning ring took too much
			# room): the burning monsters show it. A card can still name an fx ring.
			if String(sp.get("fx", "")) != "":
				_ring_fx(float(sp.get("radius", 100.0)), String(sp["fx"]), "cast")
		"freeze_nova":
			var reach := float(sp.get("radius", 150.0)) * float(stats.get("area", 1.0))
			for i in enemies.living_within(center, reach):
				enemies.apply_status(i, "freeze", {"time": float(sp.get("time", 1.5))}, 0.0, src)
			var ring_sprite := String(sp.get("fx", "stomp-i"))
			_ring_fx(reach, ring_sprite, "cast" if ring_sprite != "stomp-i" else "burst")
			Sfx.play("frost")
		"reset_cd":
			_blade_cd = 0.0
			if _whirl_left <= 0.0:
				_whirl_cd = 0.0
			for sid: String in _tier_cd:
				_tier_cd[sid] = 0.0
			_dash_cd = 0.0
			_item_fx(sp)
			Sfx.play("holy")


## A ring burst drawn as big as the damage circle: the scale comes from the
## sprite's own hitbox radius, so what the player sees is what gets hit.
func _ring_fx(reach: float, sprite := "stomp-i", anim := "burst") -> void:
	var sheet: SpriteSheet = sheets.get(sprite)
	if sheet == null:
		_warn_missing_fx(sprite, anim, false)
		return
	var hb := SpriteHitbox.of(sheet, anim, Vector2.ZERO, 1.0)
	var r1 := hb.radius if hb != null and hb.radius > 0.0 else 25.0
	r1 *= float(sheet.meta.get("px_scale", 1.0))   # _add_fx applies px_scale again
	_add_fx(sprite, anim, reach / r1, 0.0)


## A legendary special's own one-shot visual, spawned at the hero (ward-* sprites).
func _item_fx(sp: Dictionary) -> void:
	var sprite := String(sp.get("fx", ""))
	if sprite != "":
		_add_fx(sprite, "cast", _sprite_scale, 0.0, -1.0)   # the hero's scale (2026-11-22: was 1); follows the hero (2026-11-23: Vĩnh cửu stayed behind)


## Bàn thạch spends its single charge: the stone shell cracks and flies apart.
func _spend_ward() -> bool:
	if _ward_charges <= 0 or _ward_buff == "" or not buffs.is_active(_ward_buff):
		return false
	_ward_charges -= 1
	buffs.active.erase(_ward_buff)
	var brk := String(_buff_defs.get(_ward_buff, {}).get("break_sprite", ""))
	if brk != "":
		_add_fx(brk, "break", 1.0, 0.0, -1.0)   # on the hero: follows it
	invuln = maxf(invuln, 0.5)
	Sfx.play("holy")
	return true


## A special's buff (shield / haste ...) for its "time".
func _special_buff(sp: Dictionary) -> void:
	if buffs == null:
		return
	var id := String(sp.get("buff", "magnetic_shield"))
	buffs.activate(id, float(sp.get("time", 3.0)))
	if bool(sp.get("ward", false)):   # a one-hit shield, not a timed immunity
		_ward_charges = 1
		_ward_buff = id
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
				heal_max(float(sp["heal_frac"]), String(sp.get("item", "special")))
			if sp.has("buff"):
				_special_buff(sp)
			_item_fx(sp)


## On a hit taken: Phản chấn sends a damaging shockwave, Phong hành starts its
## buff; each with its own cooldown.
func _retaliate() -> void:
	for k in specials.size():
		var sp: Dictionary = specials[k]
		if sp.get("kind") == "hit_buff" and _special_t[k] <= 0.0:
			_special_t[k] = float(sp.get("cooldown", 8.0))
			_special_buff(sp)
			_item_fx(sp)
			continue
		if sp.get("kind") != "retaliate" or _special_t[k] > 0.0:
			continue
		_special_t[k] = float(sp.get("cooldown", 2.0))
		var dmg := float(stats.get("damage", 10.0)) * float(sp.get("damage_mul", 1.5))
		var reach := float(sp.get("radius", 130.0)) * float(stats.get("area", 1.0))
		enemies.hit_circle(player_pos + _hit_center, reach, dmg, float(sp.get("knockback", 260.0)), String(sp.get("item", "")))
		var fx_sprite := String(sp.get("fx", "stomp-i"))
		_ring_fx(reach, fx_sprite, "shock" if fx_sprite == "retaliate-shock" else "burst")
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
			_item_fx(sp)
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
	var kinds := {"skill": "Chiêu độc nhất", "card": "Thẻ đặc biệt", "passive": "Nội tại", "rule": "Luật"}
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
		_level.log_level("xp %.0f -> +%d level(s), level %d" % [amount, int(r[2]), level])
		if state == State.PLAYING:
			_level.open()


## Milestone levels passed going from [param from] to [param to] join the queue
## (each once per run).
func _queue_milestones(from: int, to: int) -> void:
	if milestones == null:
		return
	for lv in milestones.milestone_levels():
		if from < lv and lv <= to and not _ms_done.has(lv) and not _ms_queue.has(lv):
			_ms_queue.append(lv)


## Skill ids a run can use: every skill card the level-ups may offer (deck_pool), the starting skills and
## any level already set (--skills, milestone skills). Only their sprites are loaded at the start.
## False when run_config events.<kind>.enabled is false: the region's times for it are skipped
## (--event still forces it for shots). Mưa thiên thạch is off since 2026-11-21 (user).
## Region events (every kind) run from run_config events.min_stage on; a missing key = always
## (design/region-events-plan.md §5, user 2026-11-21: stages 1-4 stay quiet).
static func events_open(config: Dictionary, stage: int) -> bool:
	return stage >= int(config.get("events", {}).get("min_stage", 1))


static func event_enabled(config: Dictionary, kind: String) -> bool:
	return bool(config.get("events", {}).get(kind, {}).get("enabled", true))


func skills_in_run() -> Dictionary:
	var out := {}
	for u: Variant in deck_pool():
		if u is Dictionary and String(u.get("kind", "")) == "skill":
			out[String(u["id"])] = true
	for sk: String in class_data.get("start_skills", {}):
		out[sk] = true
	for sk: String in levels:
		if int(levels[sk]) > 0:
			out[sk] = true
	return out


## The cards a level-up may offer: the active deck's cards and the non-deck cards (Deck.filter).
func deck_pool() -> Array:
	var cards: Array = pool.get("upgrades", []) if deck_cards.is_empty() else Deck.filter(pool.get("upgrades", []), deck_cards)
	cards = cards.filter(func(u: Dictionary) -> bool: return not stat_capped(u))   # user 2026-11-23
	if banished.is_empty():
		return cards
	return cards.filter(func(u: Dictionary) -> bool: return not banished.has(String(u.get("id", ""))))   # Loại (6C.3)


## True for a card whose only effect is the cooldown stat once every reduction together has reached
## run_config player.cooldown_floor: one more level would change nothing (user 2026-11-23: do not offer it).
func stat_capped(u: Dictionary) -> bool:
	var fx: Dictionary = u.get("effects", {})
	if fx.size() != 1 or not fx.has("cooldown"):
		return false
	var floor_mul := float(cfg.get("player", {}).get("cooldown_floor", 0.0))
	return floor_mul > 0.0 and float(stats.get("cooldown", 1.0)) - buff_cooldown_sum() <= floor_mul + 0.0001   # buffs pass the cap


## A new level-up hand from the deck (banished cards left out); the panel shows it.
func deal_hand() -> void:
	if rarity == null:
		rarity = CardRarity.load_default()
	# design/card-rarity.md: a tier per slot, richer in chests, no commons in the gold chest
	var source := "gold_chest" if _gold_left > 0 else ("chest" if _chest_open else "level")
	choices = rarity.roll(deck_pool(), levels, level_up_card_count(), rng, source, level)
	if not choices.is_empty():   # an empty deck must not leave the run stuck in LEVEL_UP
		state = State.LEVEL_UP


func _can_act() -> bool:
	return state == State.LEVEL_UP and ms_level == 0 and skill_pick == 0   # cards only, not milestones or a count pick


func _flip_reshow() -> void:
	if _panels != null:
		_panels.show_level_up(choices, _level.title(_chest_open))


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
		_level.open()


## Monster multiplier [param what] ("hp" | "damage") at run time [param t] s: 1 + step * full minute marks
## passed (run_config time_scale, user 2026-11-20).
## The clock the waves and the per-minute growth read: the run clock, or in Vô tận its time inside this Vòng.
func wave_clock() -> float:
	return fposmod(clock, maxf(1.0, duration)) if endless else clock


## Vòng (0-based) of a Vô tận run; 0 otherwise.
func endless_cycle() -> int:
	return Endless.cycle(clock, duration) if endless else 0


## Vô tận's per-Vòng monster growth ([param what]: "hp" or "damage"); 1 outside it.
func endless_mul(what: String) -> float:
	if not endless or _endless == null:
		return 1.0
	return _endless.hp_mul(endless_cycle()) if what == "hp" else _endless.damage_mul(endless_cycle())


func time_mul(t: float, what: String) -> float:
	return time_scale_mul(cfg.get("time_scale", {}), stages.region(stage_number).get("time_scale", {}) if stages != null else {},
		stage_number, t, what)


## Monster growth at clock [param t] (user 2026-11-22): none before time_scale.min_stage; the region's own
## per-minute rates (stages.json regions[].time_scale) over the run_config ones; 1 + rate x full minutes.
static func time_scale_mul(ts: Dictionary, region_ts: Dictionary, stage: int, t: float, what: String) -> float:
	var every := float(ts.get("every", 0.0))
	if every <= 0.0 or stage < int(ts.get("min_stage", 1)):
		return 1.0
	return 1.0 + float(region_ts.get(what, ts.get(what, 0.0))) * floorf(t / every)


## Sprites the special cards draw (their "special.fx"), loaded with the run. User 2026-11-20: the specials
## moved from items to cards and their effects stopped showing, because these were still read from items.json.
func special_fx_sprites() -> Array[String]:
	var out: Array[String] = []
	for u: Variant in pool.get("upgrades", []):
		if u is Dictionary and (u as Dictionary).has("special"):
			for key in ["fx", "strike_fx"]:   # strike_fx: drawn on each struck monster (Lôi ấn)
				var fx := String(u["special"].get(key, ""))
				if fx != "" and not out.has(fx):
					out.append(fx)
	return out


## Status look on monsters lives in StatusView (src/run/status_view.gd); these keep the run's API.
func visible_statuses(list: Array) -> Array:
	return _status_view().visible(list)


func status_spots(radius: float, tile: bool) -> Array:
	return _status_view().spots(radius, tile)


func _status_view() -> StatusView:
	if _status_view_cache == null or _status_view_cache.sprite_scale != _sprite_scale:
		_status_view_cache = StatusView.new(status_defs, int(_status_max_shown), _sprite_scale)
	return _status_view_cache


## Boss outro (user 2026-11-21: the run ended abruptly when the boss died): the field clears (every monster
## plays its death), the world slows for run_config boss_outro.time seconds, the screen shakes and a victory call
## names the boss; the win panel comes after.
func _start_boss_outro() -> void:
	var oc: Dictionary = cfg.get("boss_outro", {})
	_outro_t = float(oc.get("time", 3.0))
	var bi := enemies.boss_index()
	var boss_name := String(enemies.k_extra[enemies.kind[bi]].get("name", "Boss")) if bi >= 0 else _last_boss_name
	enemies.wipe()
	enemies.boss_aura = {}
	wave_call = String(oc.get("call", "Chiến thắng! Đã hạ %s")) % boss_name
	wave_call_t = _outro_t
	shake.add(float(oc.get("shake", 8.0)))
	Sfx.play("boss_slam")
	Sfx.music("")


## Seconds left of the boss outro (-1 before it, 0 when it is over).
func outro_left() -> float:
	return _outro_t


## True when the stage is won: a boss stage only by killing its boss (user 2026-11-21: the boss arrives
## after minute 5 and the timer alone no longer wins), any other stage at its duration.
func stage_won() -> bool:
	if endless:   # Vô tận never ends by the clock: only by dying
		return false
	if boss_stage:
		return _boss_dead
	return clock >= duration or (_boss_dead and _win_on_boss)


## The living boss's passive (monsters.json "aura") buffs every monster spawned while it lives; called out
## once when it starts (user 2026-11-21: during the boss fight monsters keep coming, few but strong).
func _update_boss_aura() -> void:
	var bi := enemies.boss_index()
	var aura: Dictionary = enemies.k_extra[enemies.kind[bi]].get("aura", {}) if bi >= 0 else {}
	if bi >= 0:
		_last_boss_name = String(enemies.k_extra[enemies.kind[bi]].get("name", "Boss"))   # for the outro call
	if not aura.is_empty() and enemies.boss_aura.is_empty():
		wave_call = "%s: %s" % [String(aura.get("name", "")), String(aura.get("short", ""))]   # short: fits the screen
		wave_call_t = 4.0
	enemies.boss_aura = aura


## Seeds the XP drop rolls (from the run seed; tests set their own).
func seed_xp_drops(seed_value: int) -> void:
	_xp_rng.seed = seed_value * 53 + 11


## Whether a kill drops its XP gem: always for an elite / boss ([param sure]), else with
## run_config balance.xp_drop_chance (user 2026-11-20: 80%, slower level-ups).
func drops_xp(sure: bool) -> bool:
	if sure:
		return true
	return _xp_rng.randf() < float(cfg.get("balance", {}).get("xp_drop_chance", 1.0))


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
	_level.log_level("milestone %s -> +%d pick(s)" % [id, int(milestones.number([id], "picks_now"))])
	ms_level = 0
	if _panels == null:   # no scene (unit tests): the numbers only
		return
	_panels.hide_all()
	state = State.PLAYING
	if pending_levels > 0 or not _ms_queue.is_empty():
		_level.open()


func upgrade(id: String) -> Dictionary:
	for u: Dictionary in pool.get("upgrades", []):
		if u.get("id") == id:
			return u
	if id.begins_with("filler_"):   # a slot the deck could not fill (design/card-rarity.md)
		if rarity == null:
			rarity = CardRarity.load_default()
		for f: Dictionary in rarity.cfg.get("fillers", []):
			if String(f.get("id", "")) == id:
				return f
	return {}


## What choosing upgrade [param id] changes, for the level-up card:
## { "lines": [[label, now, next], ...], "milestones": [levels], "milestone": text for the
## level about to be gained ("" when it is an ordinary level) }. Numbers come from
## PlayerStats with the upgrade one level higher, so the card shows real values.
func upgrade_preview(id: String) -> Dictionary:
	return _sheet.upgrade_preview(id)


const STAT_LABEL := {"max_hp": "Máu tối đa", "damage": "Sát thương", "cooldown": "Hồi chiêu", "area": "Vùng đánh", "amount": "Số lượng",
	"move_speed": "Tốc độ chạy", "magnet": "Tầm hút", "regen": "Hồi máu", "armor": "Giáp"}


## "+20", "-0.5", "+1.5": a signed amount without a trailing ".0".
static func signed(v: float) -> String:
	var t := ("%+.1f" % v)
	return t.trim_suffix(".0")


## Share of a hit that gets through [param armor] (design/armor.md, after Brotato): 1 / (1 + armor / k),
## so k armor halves a hit and more armor helps less and less, never to immunity; negative armor
## raises it: (k - 2a) / (k - a).
static func armor_mul(armor: float, k: float) -> float:
	k = maxf(1.0, k)
	if armor >= 0.0:
		return 1.0 / (1.0 + armor / k)
	return (k - 2.0 * armor) / (k - armor)


static var _armor_k := 15.0   # run_config player.armor_k (set in _ready; static so _fmt_stat can show the %)
static var _cd_floor := 0.0   # run_config player.cooldown_floor (set in _ready): the cooldown shown never goes past it


static func _fmt_stat(key: String, v: float) -> String:
	match key:
		"armor":   # the points and what they take off a hit
			return "%d (−%d%%)" % [roundi(v), roundi((1.0 - armor_mul(v, _armor_k)) * 100.0)] if v > 0.0 else str(roundi(v))
		"cooldown":   # a multiplier on every skill's cooldown: shown as a change in percent, capped like the cast
			var capped := _cd_floor > 0.0 and v < _cd_floor   # user 2026-11-23: the card showed -80% past the -40% cap
			var pct := roundi((maxf(v, _cd_floor) - 1.0) * 100.0)
			return ("0%" if pct == 0 else "%+d%%" % pct) + (" (tối đa)" if capped or (_cd_floor > 0.0 and is_equal_approx(v, _cd_floor)) else "")
		"area", "magnet":
			return "×%.2f" % v
		"regen":
			return "%.1f/s" % v
		_:
			return str(roundi(v))


func _recompute_stats() -> void:
	stats = compute_stats(effect_levels())
	_apply_hit_stats()


## The hero's hit stats the monsters apply to each hit: Chí mạng (run_config crit + crit_chance / crit_mul effects,
## 6C.2), Kết liễu and Liên hoàn (design/rogue-kits.md). Regression 2026-11-26: this sat after a return in
## RunSheet.stat_breakdown and never ran, so no crit ever happened.
func _apply_hit_stats() -> void:
	if enemies == null:
		return
	enemies.crit_chance = float(cfg.get("crit", {}).get("chance", 0.0)) + float(stats.get("crit_chance", 0.0))
	enemies.crit_mul = float(cfg.get("crit", {}).get("mul", 1.75)) + float(stats.get("crit_mul", 0.0))
	enemies.execute_below = float(stats.get("execute_below", 0.0))
	enemies.combo_per = float(stats.get("combo_per", 0.0))


## The hero's stats with [param lv] card levels, the balance multipliers applied (run_config balance:
## damage and AoE size, 2026-11-20). The level-up preview uses it too, so its numbers match the run's.
func compute_stats(lv: Dictionary) -> Dictionary:
	var st := PlayerStats.compute(base_stats, effect_pool(), lv)
	var bal: Dictionary = cfg.get("balance", {})
	st["damage"] = float(st.get("damage", 0.0)) * float(bal.get("player_damage_mul", 1.0))
	st["area"] = float(st.get("area", 1.0)) * float(bal.get("player_area_mul", 1.0))
	return st


## PlayerStats.breakdown with the same balance multipliers as compute_stats(), each shown as a
## "Độ khó" part, so the character sheet agrees with the level-up cards.
func stat_breakdown() -> Dictionary:
	return _sheet.stat_breakdown()


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
		out.append_array(_card_tree().as_upgrades(tree_owner))   # card tree nodes bought (Mảnh thẻ)
	return out


var card_tree: CardTree


func _card_tree() -> CardTree:
	if card_tree == null:
		card_tree = CardTree.load_default()
	return card_tree


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
		out.merge(_card_tree().levels(tree_owner), true)
	return out


## A random equipment item for this class (shared ones too), added to the profile
## and saved; "" when there is none.
## A chest at [param p]: a Rương vàng with run_config.json events.gold_chest.chance, else a plain one.
func _drop_chest(p: Vector2) -> void:
	pickups.drop(Pickups.chest_kind(rng, float(cfg.get("events", {}).get("gold_chest", {}).get("chance", 0.0))), p, 1.0)


## Opens a Rương vàng (design/events.md): `picks` card picks in a row, `gold` coins, a sure item,
## and it counts as `counts_as` chests for Mảnh thẻ.
func open_gold_chest() -> void:
	var g: Dictionary = cfg.get("events", {}).get("gold_chest", {})
	Sfx.play("chest")
	gold += int(g.get("gold", 30))
	_win_item()
	pending_levels += int(g.get("picks", 3))
	_gold_left = int(g.get("picks", 3))
	chests_opened += int(g.get("counts_as", 3))
	_chest_open = true
	_level.log_level("gold chest -> +%d picks" % int(g.get("picks", 3)))   # the panel title names it (no wave call over it)


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
	var t := UiIcons.card_texture(String(upgrade(id).get("icon", id)))
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
		"essence": pickups.essence if pickups != null else 0,
		"shards": CardTree.shards_for_run(CardTree.load_default().data.get("shards", {}), won, stage_number, bosses_killed, chests_opened)}
	if playing_slot != null and stages != null and not prefs.is_fixed():
		playing_slot.essence += int(run_result["essence"])   # Tinh hoa picked up is kept, won or lost
		playing_slot.shards += int(run_result["shards"])     # Mảnh thẻ (design/skill-tree-v2.md)
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
			if endless:
				run_result["endless_record"] = playing_slot.record_endless(clock)
		record_daily(playing_slot, won)
		if enemies != null:
			playing_slot.record_kills(enemies.kills_kind)   # Album (bách khoa): first kill unlocks a monster
		prefs.slot_store().save(playing_slot)
	run_result["next"] = won and challenge_id == "" and stage_number < (stages.count() if stages != null else 30)
	run_result["challenge"] = challenge_id
	run_result["endless"] = endless
	run_result["endless_time"] = clock if endless else 0.0
	run_result["endless_cycle"] = endless_cycle() + 1
	if endless:
		run_result["next"] = false
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
	print("Run over: lost at %.1fs, level %d, kills %d, hp_min %.0f, taken %.0f" % [clock, level, enemies.total_kills, _hp_min, damage_taken])
	_panels.show_end(false)


## "blade_arc 31% · cleave_wave 22% · ..." of enemies.damage_by, largest first (demo / balance runs).
func damage_shares() -> String:
	var total := 0.0
	for k: String in enemies.damage_by:
		total += float(enemies.damage_by[k])
	var keys: Array = enemies.damage_by.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return float(enemies.damage_by[a]) > float(enemies.damage_by[b]))
	var parts := []
	for k: String in keys:
		parts.append("%s %d%%" % [k, roundi(100.0 * float(enemies.damage_by[k]) / maxf(1.0, total))])
	return " · ".join(parts)


func _win() -> void:
	state = State.WON
	Sfx.music("")
	Sfx.play("win")
	pickups.pull_all()
	if bool(cfg.get("rewards", {}).get("win_item", false)):
		_win_item()
	_finish(true)
	print("Run over: won, level %d, kills %d, gold %d, hp_min %.0f/%.0f, taken %.0f" % [level, enemies.total_kills, gold, _hp_min, float(stats["max_hp"]), damage_taken])
	if demo:   # balance runs: each source's share of the damage dealt (cleave-wave-redesign.md step 5)
		print("GK: damage " + damage_shares())
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
			out.append({"id": u["id"], "name": u.get("name", u["id"]), "level": lv, "max": UpgradeRoller.cap(u),
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
	var sheet: SpriteSheet = sheets.get(hero_sprite_name())
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
	var hero: SpriteSheet = sheets.get(hero_sprite_name())
	var b := SpriteHitbox.body(hero, Vector2.ZERO, hero_scale(hero), face_left)
	if b == null:
		push_error("class sprite has no body circle; regenerate it in Sprite Lab")
		return
	_hit_center = b.center
	if enemies != null:
		enemies.player_hit_radius = b.radius


## Name of the hero sheet the run draws: the class's lpc_sprite when run_config hero_art is "lpc", else its sprite.
func hero_sprite_name() -> String:
	if String(cfg.get("hero_art", "")) == "lpc" and class_data.has("lpc_sprite"):
		return String(class_data["lpc_sprite"])
	return String(class_data.get("sprite", "swordsman"))


## Draw scale of the hero sheet: the world scale x its px_scale (an LPC hero, 64 px frames, is drawn at its own
## pixel size: px_scale 0.5; the old 48 px heroes have none).
func hero_scale(sheet: SpriteSheet) -> float:
	return _sprite_scale * (float(sheet.meta.get("px_scale", 1.0)) if sheet != null else 1.0)


func _set_anim(anim: String) -> void:
	if _anim != anim:
		_anim = anim
		_anim_t = 0.0


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	var view := Rect2(_camera.position - get_viewport_rect().size * 0.5, get_viewport_rect().size).grow(64.0)
	if _ground == null:   # the floor is its own cached layer (GroundLayer), redrawn per tile crossed
		_ground = GroundLayer.new()
		_ground.setup(_arena_half, stage_ground)
		add_child(_ground)
	_ground.follow(_camera.position, get_viewport_rect().size)
	_boss_view.draw_hazard_pools()
	_obstacle_view.draw(view, false)
	var gem: SpriteSheet = sheets.get(_gem_sprite)
	var coin: SpriteSheet = sheets.get(_coin_sprite)
	for i in pickups.count:
		if view.has_point(pickups.pos[i]):
			var sh := gem if pickups.kind[i] == Pickups.GEM else coin
			if pickups.kind[i] == Pickups.CHEST:
				sh = sheets.get(_chest_sprite)
			elif pickups.kind[i] == Pickups.GOLD_CHEST:
				sh = sheets.get(_gold_chest_sprite)
			elif pickups.kind[i] == Pickups.ESSENCE:
				sh = sheets.get(_essence_sprite)
			if sh != null:
				sh.draw(self, "idle", clock + i * 0.13, pickups.pos[i], _sprite_scale)
	_boss_view.draw_boss_warnings()
	_boss_view.draw_boss_waves()
	_draw_ground_buffs(view)
	_draw_zones()
	_draw_ground_fx()
	challenges.draw()
	region_ev.draw()
	_draw_charge_lanes(view)
	_boss_view.draw_pools(view)
	_boss_view.draw_root_walls()
	for h in _heal_fx:   # Hồn Đầm: a green ring sweeping out over the monsters it heals
		var k := float(h["t"]) / 0.5
		var r := float(h["r"]) * (0.3 + 0.7 * k)
		draw_circle(h["p"], r, Color(0.4, 1.0, 0.5, 0.10 * (1.0 - k)))
		draw_arc(h["p"], r, 0.0, TAU, 48, Color(0.55, 1.0, 0.6, 0.8 * (1.0 - k)), 3.0)
		for q in 6:
			var c: Vector2 = h["p"] + Vector2.from_angle(q * TAU / 6.0) * r * 0.7
			draw_rect(Rect2(c - Vector2(1, 4), Vector2(2, 8)), Color(0.7, 1.0, 0.7, 1.0 - k))   # "+" marks
			draw_rect(Rect2(c - Vector2(4, 1), Vector2(8, 2)), Color(0.7, 1.0, 0.7, 1.0 - k))
	# the boss's aura: a glow under every buffed monster, all drawn BEFORE any monster so no glow covers the
	# boss or another monster (2026-11-21: the split slimes' glows hid the king)
	if not enemies.boss_aura.is_empty() and mark_style == "ring":
		var gc := Color(String(enemies.boss_aura.get("color", "#ffffff")))
		for i in enemies.count:
			if enemies.buffed[i] == 1 and enemies.state[i] != Enemies.DYING and view.has_point(enemies.pos[i]):
				var gr := enemies.k_radius[enemies.kind[i]] * 1.3
				var feet := enemies.pos[i] + Vector2(0, -2)
				draw_circle(feet, gr, Color(gc, 0.25 + 0.1 * sin(clock * 4.0 + i)))
				draw_arc(feet, gr, 0.0, TAU, 20, Color(gc, 0.7), 1.5)
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
			if enemies.k_extra[k].has("tint") and enemies.flash[i] <= 0.0:   # Yêu tinh vàng glitters gold
				tint = Color(String(enemies.k_extra[k]["tint"]))
			if enemies.k_behaviour[k] == Enemies.FLEE and enemies.state[i] == Enemies.WINDUP:   # its escape portal
				var pc := enemies.pos[i] - Vector2(0, enemies.k_radius[k])
				var ch := float(enemies.k_extra[k].get("channel", 2.0))
				var grow := clampf(1.0 - enemies.timer[i] / maxf(0.01, ch), 0.0, 1.0)
				for q in 3:
					draw_arc(pc, (10.0 + 14.0 * grow) * (1.0 - 0.25 * q), clock * (3.0 + q) , clock * (3.0 + q) + 4.5, 20,
						Color(0.7, 0.35, 1.0, 0.9 - 0.25 * q), 3.0 - q)
			if enemies.k_boss[k] == 1 and enemies.enraged(i) and enemies.flash[i] <= 0.0 and enemies.k_rage_sheet[k] == null:
				tint = Color(1.0, 0.62, 0.55)   # enraged: flushed red (bosses without a red rage sheet)
			var mark_col := Color(0, 0, 0, 0)   # roadmap F: the elite / boss-buff mark drawn with the sprite
			if enemies.buffed[i] == 1 and not enemies.boss_aura.is_empty() and mark_style != "ring":
				mark_col = Color(String(enemies.boss_aura.get("color", "#ffffff")))
			if enemies.k_elite[k] == 1:   # elite: a gold halo under it
				var hr := enemies.k_radius[k]
				var hc := enemies.center_of(i)
				var lab := enemies.affix_label(i)   # the affix colours the halo and names itself (6A)
				var hcol: Color = lab[1] if lab[0] != "" else Color(1.0, 0.82, 0.3)
				if mark_style == "ring":
					hcol.a = 0.5 + 0.3 * sin(clock * 5.0)
					draw_arc(hc + Vector2(0, hr * 0.6), hr * 1.1, 0.0, TAU, 32, hcol, 3.0)
				else:
					mark_col = hcol
				if lab[0] != "":
					_affix_tags.append([hc - Vector2(0, hr * 1.6 + 14.0), lab[0], lab[1]])
				if tint == Color.WHITE:
					tint = Color(1.0, 0.92, 0.75)
			var lift := enemies.hop_lift(i) * enemies.k_scale[k]   # a hop: up the arc, the shadow stays down
			if lift > 0.0:
				var sr := enemies.k_radius[k]
				draw_set_transform(enemies.pos[i], 0.0, Vector2(1.0, 0.4))
				draw_circle(Vector2.ZERO, sr * (1.0 - 0.3 * lift / maxf(1.0, lift + sr)), Color(0, 0, 0, 0.3))
				draw_set_transform(Vector2.ZERO)
			var at := enemies.pos[i] - Vector2(0.0, lift)
			if enemies.in_transition(i):   # phase 2 transition: shakes; flashes only without a transform animation
				at += Vector2(sin(clock * 90.0) * 2.0, 0.0).round()
				if not enemies.sheet_of(i).has_animation("transform"):
					tint = Color(2.0, 2.0, 2.0) if int(clock * 12.0) % 2 == 0 else Color(1.6, 0.5, 0.45)
			if mark_col.a > 0.0 and enemies.state[i] != Enemies.DYING:
				_draw_mark(i, a, at, mark_col)
			enemies.sheet_of(i).draw(self, a[0], a[1], at, enemies.k_scale[k], enemies.flip[i] == 1, tint)
	_boss_view.draw_bolts()
	var hero: SpriteSheet = sheets.get(hero_sprite_name())
	if hero != null:
		var blink := invuln > 0.0 and state == State.PLAYING and int(invuln * 20.0) % 2 == 0
		var tint := Color(1, 1, 1, 0.45) if blink else Color.WHITE
		_draw_auras("back")
		_draw_fx(true)
		_draw_traps()
		_draw_dash_trail(hero)
		_draw_clone(hero)
		if poison_t > 0.0:   # standing in poison (user 2026-11-21): a pulsing green tint and rising bubbles
			var pz := 0.5 + 0.5 * sin(clock * 10.0)
			tint = Color(tint.r * (0.55 + 0.15 * pz), tint.g, tint.b * (0.45 + 0.15 * pz), tint.a)
		hero.draw(self, _anim, _anim_t, player_pos, hero_scale(hero), face_left, tint)
		if poison_t > 0.0:
			for q in 5:
				var life := fmod(clock * 1.4 + q * 0.37, 1.0)
				var bp := player_pos + _hit_center + Vector2(sin(q * 2.3 + clock * 2.0) * 10.0, 8.0 - life * 34.0)
				var br := 2.0 + (q % 2)
				draw_circle(bp, br, Color(0.45, 0.95, 0.35, 0.85 * (1.0 - life)))
				draw_arc(bp, br, 0.0, TAU, 8, Color(0.1, 0.35, 0.1, 0.9 * (1.0 - life)), 1.0)
		if bleed_t > 0.0:   # bleeding (Sói bite): red drops fall from the body
			for q in 4:
				var life := fmod(clock * 1.8 + q * 0.29, 1.0)
				var dp := (player_pos + _hit_center + Vector2(-10.0 + q * 7.0, 6.0 + life * 20.0)).round()
				var al := 1.0 - life
				draw_rect(Rect2(dp - Vector2(1, 1), Vector2(5, 6)), Color(0.18, 0.02, 0.04, al))   # dark rim: reads on red cloth
				draw_rect(Rect2(dp, Vector2(3, 4)), Color(0.95, 0.12, 0.16, al))
				draw_rect(Rect2(dp, Vector2(1, 1)), Color(1.0, 0.6, 0.6, al))
		_draw_auras("front")
	_obstacle_view.draw(view, true)   # a tree the hero walks behind: drawn again, see-through, over the hero
	_draw_statuses(view)
	_draw_fx(false)
	_draw_pets()
	_draw_combo()
	_draw_mark_reticle()
	if Prefs.current().monster_hp:
		_draw_monster_hp(view)
	if Prefs.current().damage_numbers:
		_draw_damage_numbers(view)
	_draw_affix_tags()
	if show_hitboxes:
		_draw_hitboxes(view)
	_draw_arena_mask(view)   # after the world, before the hero's bar: nothing shows past the edge (roadmap C)
	# hp bar under the hero
	var w := 44.0
	var bar := Rect2(player_pos + Vector2(-w * 0.5, 8.0), Vector2(w, 5.0))
	draw_rect(bar, Color(0.1, 0.05, 0.08))
	draw_rect(Rect2(bar.position, Vector2(w * clampf(hp / float(stats["max_hp"]), 0.0, 1.0), 5.0)), Color(0.85, 0.2, 0.25))


## The hero stays a body width plus its bar inside the edge, so the arena mask never cuts the hero or its hp bar.
func _keep_inside(p: Vector2) -> Vector2:
	var m := _arena_half - 26.0
	return p.clamp(Vector2(-m, -m), Vector2(m, m))


## The parts of [param view] outside the arena square ±[param half] (up to four rects, no overlap with the arena).
static func outside_rects(view: Rect2, half: float) -> Array:
	var out := []
	var l := view.position.x
	var t := view.position.y
	var r := view.end.x
	var b := view.end.y
	if l < -half:
		out.append(Rect2(l, t, minf(r, -half) - l, b - t))
	if r > half:
		out.append(Rect2(maxf(l, half), t, r - maxf(l, half), b - t))
	var x0 := maxf(l, -half)
	var x1 := minf(r, half)
	if x1 > x0:
		if t < -half:
			out.append(Rect2(x0, t, x1 - x0, minf(b, -half) - t))
		if b > half:
			out.append(Rect2(x0, maxf(t, half), x1 - x0, b - maxf(t, half)))
	return out


## Roadmap C (user 2026-11-22): cut everything at the arena edge. Solid outside colour over whatever spilled past
## it, then a thick dark band with a light inner line so the edge reads as a wall.
func _draw_arena_mask(view: Rect2) -> void:
	var rects := outside_rects(view, _arena_half)
	if rects.is_empty():
		return
	var pal: Dictionary = stage_ground if stage_ground is Dictionary else {}
	var outside := Color(String(pal.get("outside", "1b2419")))
	for rc: Rect2 in rects:
		draw_rect(rc, outside)
	var h := _arena_half
	draw_rect(Rect2(-h - 10.0, -h - 10.0, h * 2 + 20.0, h * 2 + 20.0), outside.darkened(0.45), false, 12.0)   # the wall band
	draw_rect(Rect2(-h + 1.0, -h + 1.0, h * 2 - 2.0, h * 2 - 2.0), outside.lightened(0.35), false, 2.0)   # light inner line


## The camera centre in world space (the HUD's edge arrows measure from it).
func camera_center() -> Vector2:
	return _camera.position if _camera != null else player_pos


## Elite affix names, collected while drawing the monsters and drawn last so the
## hero and effects never cover them.
## Roadmap F: the elite / boss-buff mark behind monster [param i] (drawn before its sprite) in [param col]:
## outline = its silhouette 1 source pixel out on 4 sides (user chose it 2026-11-23 over a crest and wisps).
func _draw_mark(i: int, a: Array, at: Vector2, col: Color) -> void:
	var k := enemies.kind[i]
	var pulse := float(_marks_cfg.get("alpha", 0.85)) * (0.75 + 0.25 * sin(clock * 5.0 + i))
	match mark_style:
		"outline":
			var sil := _silhouette(enemies.sheet_of(i))
			if sil == null:
				return
			var px := enemies.k_scale[k]
			for off: Vector2 in [Vector2(px, 0), Vector2(-px, 0), Vector2(0, px), Vector2(0, -px)]:
				sil.draw(self, a[0], a[1], at + off, enemies.k_scale[k], enemies.flip[i] == 1, Color(col, pulse))


## A white copy of [param sheet] (same frames, alpha kept) for the outline mark; made once per sprite.
func _silhouette(sheet: SpriteSheet) -> SpriteSheet:
	if sheet == null or sheet.texture == null:
		return null
	if _sil_cache.has(sheet.name):
		return _sil_cache[sheet.name]
	var img := sheet.texture.get_image()
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, c.a))
	var sil := SpriteSheet.from_meta(sheet.name + "#sil", sheet.meta)
	sil.texture = ImageTexture.create_from_image(img)
	_sil_cache[sheet.name] = sil
	return sil


func _draw_affix_tags() -> void:
	var font := ThemeDB.fallback_font
	for t: Array in _affix_tags:
		var tw := font.get_string_size(t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var at: Vector2 = t[0] - Vector2(tw * 0.5, 0)
		draw_string_outline(font, at, t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0.05, 0.04, 0.08))
		draw_string(font, at, t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, t[2])
	_affix_tags.clear()


# --- damage numbers and monster hp bars ------------------------------------------

var _last_stop := -10.0   # clock of the last hit-feel hitstop


## Cảm giác đánh (run_config hit_feel): a spark on this frame's physical hits and a short hitstop when a
## melee strike connects (at most once every hitstop_gap s, so a crowd does not freeze the run).
func _hit_feel() -> void:
	var hf: Dictionary = cfg.get("hit_feel", {})
	if hf.is_empty() or enemies.hit_src.is_empty():
		return
	var stops: Array = hf.get("hitstop_sources", [])
	var sparks := 0
	var cap := int(hf.get("max_per_frame", 4)) if Prefs.current().vfx < 2 else 0
	var stop := false
	for k in enemies.hit_src.size():
		var src := enemies.hit_src[k]
		if String(enemies.element_of.get(src, "")) != "physical":
			continue
		if sparks < cap:
			sparks += 1
			_add_fx(hit_spark_sprite if hit_spark_sprite != "" else String(hf.get("sprite", "hit-spark-a")), "spark",
				_sprite_scale * float(hf.get("scale", 1.0)), 0.0, -1.0, enemies.hit_pos[k] + Vector2(0, 6))
		stop = stop or src in stops
	if stop and clock - _last_stop >= float(hf.get("hitstop_gap", 0.35)):
		_last_stop = clock
		_hitstop = maxf(_hitstop, float(hf.get("hitstop", 0.025)))


## Turns this frame's hits into floating numbers (a fixed ring: the oldest is
## reused when full) and ages them.
func _step_damage_numbers(dt: float) -> void:
	for i in _num_t.size():
		if _num_t[i] >= 0.0:
			_num_t[i] += dt
			if _num_t[i] > _num_life:
				_num_t[i] = -1.0
	_hit_feel()
	if enemies.crit_heavy > 0:   # a crit landed on an elite / boss: hitstop and a small shake
		_hitstop = float(_crit_cfg.get("hitstop", 0.035))
		shake.add(float(_crit_cfg.get("shake_crit", 2.0)))
	for k in enemies.hit_pos.size():
		_num_pos[_num_next] = enemies.hit_pos[k] + Vector2(rng.randf_range(-6.0, 6.0), 0.0)
		_num_val[_num_next] = enemies.hit_val[k]
		_num_crit[_num_next] = enemies.hit_crit[k] if k < enemies.hit_crit.size() else 0
		_num_tag[_num_next] = enemies.hit_tag[k] if k < enemies.hit_tag.size() else 0
		_num_t[_num_next] = 0.0
		_num_next = (_num_next + 1) % _num_t.size()
	enemies.drain_hits()
	for b: Array in enemies.status_fx:   # Thánh ấn / Ăn mòn bursts
		_add_fx(String(b[0]), "burst", _sprite_scale, 0.0, -1.0, b[1])
	enemies.status_fx.clear()
	if enemies.executes > 0:   # Kết liễu (design/rogue-kits.md): each execute readies Lướt and leaves its burst
		_dash_cd = 0.0
		var tier: String = "execute-" + ["i", "ii", "iii", "iv", "v"][clampi(int(levels.get("execute", 1)) - 1, 0, 4)]
		for p: Vector2 in enemies.exec_pos:
			_add_fx(tier, "burst", _sprite_scale, 0.0, -1.0, p)
		enemies.executes = 0
		enemies.exec_pos.clear()


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
		var b2 := _add_fx(blast, impact, float(fx["scale"]) * float(fx.get("impact_scale", 1.0)), float(sh["damage"]), -1.0, p, src, float(fx.get("kb", 140.0)))
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
	if int(fx.get("bounce", 0)) > 0 and _bounce(fx, p):
		return false
	sh["pierce"] = int(sh["pierce"]) - 1
	sh["wait"] = 0.15
	return int(sh["pierce"]) < 0


## Phân thân (design/rogue-kits.md): a dash leaves a shadow at [param at] for the hero's clone_time s (0 = no card).
func _leave_clone(at: Vector2) -> void:
	var life := float(stats.get("clone_time", 0.0))
	if life > 0.0:
		_clone = {"pos": at, "life": life, "face": face_left}


func _step_clone(dt: float) -> void:
	if _clone.is_empty():
		return
	_clone["life"] = float(_clone["life"]) - dt
	if float(_clone["life"]) <= 0.0:
		_clone = {}


## The shadow: the hero's own sprite in the card level's colour (I grey .. V violet-gold), see-through, fading out.
const CLONE_COLS := [Color(0.35, 0.35, 0.45), Color(0.3, 0.3, 0.6), Color(0.45, 0.25, 0.7), Color(0.6, 0.25, 0.75), Color(0.85, 0.6, 0.35)]


func _draw_clone(hero: SpriteSheet) -> void:
	if _clone.is_empty() or hero == null:
		return
	var col: Color = CLONE_COLS[clampi(int(levels.get("shadow_clone", 1)) - 1, 0, 4)]
	var a := clampf(float(_clone["life"]) / 0.5, 0.0, 1.0) * (0.55 + 0.1 * sin(clock * 12.0))
	hero.draw(self, "idle", clock, _clone["pos"], hero_scale(hero), bool(_clone["face"]), Color(col, a))


## Bẫy gai (design/rogue-kits.md): a trap springs (its burst deals the damage) when a monster steps within its
## trigger radius; unsprung traps fade after their life.
func _step_traps(dt: float) -> void:
	var i := 0
	while i < _traps.size():
		var tr: Dictionary = _traps[i]
		tr["life"] = float(tr["life"]) - dt
		if not enemies.living_within(tr["pos"], float(tr["trigger"])).is_empty():
			var fx := _add_fx(String(tr["sprite"]), "burst", float(tr["sc"]), float(tr["dmg"]), -1.0, tr["pos"], String(tr["sid"]), float(tr["kb"]))
			if not fx.is_empty():
				fx["ground"] = true
			_traps.remove_at(i)
		elif float(tr["life"]) <= 0.0:
			_traps.remove_at(i)
		else:
			i += 1


## Armed traps lie on the ground as the burst's opening frame (the cracked ring), blinking in their last second.
func _draw_traps() -> void:
	for tr: Dictionary in _traps:
		var sheet: SpriteSheet = sheets.get(String(tr["sprite"]))
		if sheet == null or (float(tr["life"]) < 1.0 and int(float(tr["life"]) * 8.0) % 2 == 0):
			continue
		sheet.draw(self, "burst", 0.25, tr["pos"], float(tr["sc"]) * float(sheet.meta.get("px_scale", 1.0)))


## Chim ưng (design/rogue-kits.md): every owned "pet" skill keeps its companion by the hero; a dive flies to its
## target at dive_speed, rakes it (the strike fx deals the damage) and flies back.
func _step_pets(dt: float) -> void:
	var home := player_pos + _hit_center
	for sid: String in pool.get("skills", {}):
		var ts: Dictionary = pool["skills"][sid]
		if String(ts.get("cast", "")) != "pet" or int(levels.get(sid, 0)) <= 0:
			continue
		if not _pets.has(sid):
			_pets[sid] = {"pos": home + Vector2(-20, -36), "state": "idle", "t": 0.0, "sprite": _skill_sprite(sid, ts)}
		var pet: Dictionary = _pets[sid]
		pet["t"] = float(pet["t"]) + dt
		var t := float(pet["t"])
		var perch := home + Vector2(cos(t * 1.6) * 30.0, -38.0 + sin(t * 3.2) * 4.0)
		var speed := float(ts.get("dive_speed", 700.0)) * dt
		var pos: Vector2 = pet["pos"]
		match String(pet["state"]):
			"dive":
				var to: Vector2 = pet["target"]
				pos = pos.move_toward(to, speed)
				if pos.distance_to(to) <= 4.0:
					var fx := _add_fx(String(pet["sprite"]), String(ts.get("anim", "strike")), float(pet["sc"]), float(pet["dmg"]), -1.0, to, sid, float(pet.get("kb", 140.0)))
					if not fx.is_empty():
						fx["effects"] = on_hit(sid)
					pet["state"] = "back"
			"back":
				pos = pos.move_toward(perch, speed)
				if pos.distance_to(perch) <= 10.0:
					pet["state"] = "idle"
			_:
				pos = pos.lerp(perch, minf(1.0, dt * 8.0))
		pet["face"] = signf((pos - (pet["pos"] as Vector2)).x) if absf((pos - (pet["pos"] as Vector2)).x) > 0.01 else float(pet.get("face", 1.0))
		pet["pos"] = pos


## Liên hoàn (design/rogue-kits.md): the stacks as pips in an arc over the hero, in the card level's colour
## (I steel .. V gold); a full stack glows white.
const COMBO_COLS := [Color("b8c4d8"), Color("6fb7e0"), Color("c38df5"), Color("e0364a"), Color("f2c14e")]


func _draw_combo() -> void:
	if enemies == null or enemies.combo_per <= 0.0 or enemies.combo <= 0:
		return
	var col: Color = COMBO_COLS[clampi(int(levels.get("combo", 1)) - 1, 0, 4)]
	var full := enemies.combo >= enemies.combo_max
	var top := player_pos + _hit_center + Vector2(0, -44)
	for k in enemies.combo_max:
		var a := PI + PI * (float(k) + 0.5) / float(enemies.combo_max)
		var p := (top + Vector2(cos(a), sin(a) * 0.5) * 22.0).round()
		draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(0.05, 0.03, 0.08, 0.8))
		if k < enemies.combo:
			draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color.WHITE if full else col)


func _draw_mark_reticle() -> void:
	if _mark_sprite == "" or enemies == null or enemies.mark_uid < 0:
		return
	var i := enemies.index_of_uid(enemies.mark_uid)
	var sheet: SpriteSheet = sheets.get(_mark_sprite)
	if i < 0 or sheet == null:
		return
	sheet.draw(self, "mark", clock, enemies.center_of(i), _sprite_scale * float(sheet.meta.get("px_scale", 1.0)))


func _draw_pets() -> void:
	for sid: String in _pets:
		var pet: Dictionary = _pets[sid]
		var sheet: SpriteSheet = sheets.get(String(pet["sprite"]))
		if sheet == null or not sheet.has_animation("fly"):
			continue
		sheet.draw(self, "fly", float(pet["t"]), pet["pos"], _sprite_scale * float(sheet.meta.get("px_scale", 1.0)), float(pet.get("face", 1.0)) < 0.0)


## Dao hồi (design/rogue-kits.md): on its way back the dagger steers to the hero; true when it is back in the hand.
func _step_boomerang(fx: Dictionary) -> bool:
	var home := player_pos + _hit_center
	var to_home: Vector2 = home - (fx["pos"] as Vector2)
	if to_home.length() <= 16.0:
		return true
	var dv := to_home.normalized()
	fx["vel"] = dv * (fx["vel"] as Vector2).length()
	fx["anim"] = _fly_anim(String((fx["sheet"] as SpriteSheet).name), String(fx.get("prefix", "fly_")), dv)
	fx["life"] = maxf(float(fx["life"]), float(fx["t"]) + 0.5)   # keeps flying until it is back
	return false


## Tên nảy (design/rogue-kits.md): after a hit at [param p], the shot turns to the nearest monster it has not hit yet
## within its bounce_range, a little harder (bounce_mul). False when no such monster: it is spent like a plain hit.
func _bounce(fx: Dictionary, p: Vector2) -> bool:
	var hit: Array = fx.get("bounced_off", [])
	for i in enemies.nearest_n(p, 6):
		if enemies.center_of(i).distance_to(p) <= 14.0:   # the one just hit (or one hugging it)
			if not hit.has(enemies.uid[i]):
				hit.append(enemies.uid[i])
	fx["bounced_off"] = hit
	for i in enemies.nearest_n(p, 8):
		if hit.has(enemies.uid[i]) or enemies.center_of(i).distance_to(p) > float(fx.get("bounce_range", 180.0)):
			continue
		var dv := (enemies.center_of(i) - p).normalized()
		fx["vel"] = dv * (fx["vel"] as Vector2).length()
		fx["anim"] = _fly_anim(String((fx["sheet"] as SpriteSheet).name), String(fx.get("prefix", "fly_")), dv)
		fx["life"] = float(fx["t"]) + 0.8
		fx["bounce"] = int(fx["bounce"]) - 1
		var sh: Dictionary = fx["shot"]
		sh["damage"] = float(sh["damage"]) * (1.0 + float(fx.get("bounce_mul", 0.1)))
		sh["wait"] = 0.08
		return true
	return false


## Skill effects; [param under] = only those drawn behind the hero (ground
## effects such as the stomp), else the rest, over it.
## Effects lying on the floor (skills with "ground_fx"): under the monsters and the hero.
func _draw_ground_fx() -> void:
	for fx in _fx:
		if bool(fx.get("ground", false)):
			var sh: SpriteSheet = fx["sheet"]
			sh.draw(self, fx["anim"], float(fx["t"]), _fx_pos(fx), float(fx["scale"]), false, Color(1, 1, 1, _vfx_alpha * 0.85))   # the floor layer stays a little lower


func _draw_fx(under: bool) -> void:
	for fx in _fx:
		if bool(fx.get("under", false)) != under or bool(fx.get("ground", false)):
			continue
		var sh: SpriteSheet = fx["sheet"]
		var looping: bool = fx["anim"] == "spin" or fx.has("shot")
		var t := fmod(float(fx["t"]), sh.duration(fx["anim"])) if looping else float(fx["t"])
		sh.draw(self, fx["anim"], t, _fx_pos(fx), float(fx["scale"]), false, Color(1, 1, 1, _vfx_alpha))




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
	_status_view().draw_on_monsters(self, enemies, sheets, clock, view, _vfx_alpha)
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


## Vũng độc (design/obstacles.md): standing in a poison pool loses pool_dps hp a second (no armor,
## no hurt flinch, so walking through is a choice, not a stun).
func _step_pools_hazard(dt: float) -> void:
	poison_t = maxf(0.0, poison_t - dt)
	if enemies != null and enemies.player_in_pool:
		poison_t = POISON_LOOK
	if obstacles == null or obstacles.pools.is_empty() or god or buffs.invulnerable():
		return
	if obstacles.in_pool(player_pos):
		poison_t = POISON_LOOK
		var d := obstacles.pool_dps * dt
		hp -= d
		damage_taken += d
		_add_to(taken_by, "pool", d)


## Telegraphed charges (Sói Rừng, design 6A): the lane a winding-up charger will
## dash along, red, filling in as the dash comes.
func _draw_charge_lanes(view: Rect2) -> void:
	for i in enemies.count:
		if not view.has_point(enemies.pos[i]):
			continue
		var kk := enemies.kind[i]
		if enemies.state[i] == Enemies.DASH and enemies.k_behaviour[kk] == Enemies.CHARGE \
				and bool(enemies.k_extra[kk].get("telegraph", false)):   # Sói Rừng: a red eye streak trails the dash
			var c := enemies.center_of(i) - Vector2(0.0, enemies.k_radius[kk] * 0.6)
			var back := -enemies.dash_dir[i].normalized()
			for q in 3:
				draw_line(c + back * (8.0 + 12.0 * q), c + back * (22.0 + 12.0 * q), Color(1.0, 0.25, 0.15, 0.55 - 0.15 * q), 3.0 - q)
			continue
		var lane := enemies.charge_lane(i)
		if lane.is_empty():
			continue
		var a: Vector2 = lane[0]
		var b: Vector2 = lane[1]
		var n := (b - a).orthogonal().normalized() * float(lane[2]) * 0.5
		var w := float(enemies.k_extra[enemies.kind[i]].get("windup", 0.5))
		var t := clampf(1.0 - enemies.timer[i] / maxf(0.01, w), 0.0, 1.0)
		draw_colored_polygon(PackedVector2Array([a + n, b + n, b - n, a - n]), Color(0.9, 0.15, 0.1, 0.12 + 0.18 * t))
		draw_polyline(PackedVector2Array([a + n, b + n, b - n, a - n, a + n]), Color(1.0, 0.35, 0.25, 0.5 + 0.4 * t), 2.0)
		draw_line(a, a.lerp(b, t), Color(1.0, 0.5, 0.35, 0.7), 3.0)


## Tint of monster [param i] from its statuses (freeze / burn / slow), or white.
func _status_tint(i: int) -> Color:
	for st in ["freeze", "burn", "bleed", "slow"]:
		var ok: bool = (st == "freeze" and enemies.freeze_t[i] > 0.0) or (st == "burn" and enemies.burn_t[i] > 0.0) \
			or (st == "bleed" and enemies.bleed_t[i] > 0.0) or (st == "slow" and enemies.slow_t[i] > 0.0)
		if ok and status_defs.get(st, {}).has("tint"):
			return Color(String(status_defs[st]["tint"]))
	return Color.WHITE






## Afterimages of the hero along the dash path (the camera follows the hero, so
## without them a dash only shows as the ground sliding).
## The dash trail at the dash's level (skills.dash.trail_tiers): {count, color, streaks}.
func dash_trail_style() -> Dictionary:
	var tiers: Array = pool.get("skills", {}).get("dash", {}).get("trail_tiers", [])
	if tiers.is_empty():
		return {"count": 3, "color": "#a6d9ff"}
	return tiers[clampi(int(levels.get("dash", 1)) - 1, 0, tiers.size() - 1)]


func _draw_dash_trail(hero: SpriteSheet) -> void:
	if _dash_trail <= 0.0:
		return
	var fade := clampf(_dash_trail / 0.3, 0.0, 1.0)
	var st := dash_trail_style()
	var n := int(st.get("count", 3))
	var col := Color(String(st.get("color", "#a6d9ff")))
	if bool(st.get("streaks", false)):   # speed lines along the path, behind the ghosts
		var side := _dash_dir.orthogonal() * 7.0
		for k: int in [-1, 0, 1]:
			var a: Vector2 = _dash_from + _hit_center + side * k   # at the body's height, not the feet
			var b: Vector2 = a.lerp(player_pos + _hit_center + side * k, 0.85)
			draw_line(a.round(), b.round(), Color(col, 0.55 * fade), 2.0)
	for k in range(1, n + 1):
		var p := _dash_from.lerp(player_pos, float(k) / float(n + 1))
		hero.draw(self, _anim, _anim_t, p, hero_scale(hero), face_left, Color(col, 0.6 * float(k) / float(n) * fade))


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
		if layer == "back" and d.has("aura_back"):   # far half of a 3D orbit
			var back: SpriteSheet = sheets.get(String(d.get("aura_back", "")))
			if back != null and back.has_animation("loop"):
				back.draw(self, "loop", clock, player_pos, _sprite_scale)
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
		var crit := _num_crit[i] == 1
		var txt := str(maxi(1, roundi(_num_val[i]))) + ("!" if crit else "")
		var sz := roundi(_num_size * 1.4) if crit else _num_size
		var col := Color(1.0, 0.55, 0.15, a) if crit else Color(1.0, 0.93, 0.6, a)
		if _num_tag[i] == 1:   # weak element: red (design/species.md)
			col = Color(1.0, 0.36, 0.42, a)
		elif _num_tag[i] == 2:   # resisted: grey
			col = Color(0.66, 0.66, 0.7, a)
		draw_string_outline(font, p, txt, HORIZONTAL_ALIGNMENT_CENTER, 60.0, sz, 5 if crit else 4, Color(0.1, 0.05, 0.08, a))
		draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_CENTER, 60.0, sz, col)


## Hp bar over each monster hit in the last ui.hp_bar_time seconds.
func _draw_monster_hp(view: Rect2) -> void:
	for i in enemies.count:
		if enemies.hp_show[i] <= 0.0 or enemies.state[i] == Enemies.DYING or not view.has_point(enemies.pos[i]):
			continue
		var k := enemies.kind[i]
		var r := enemies.k_radius[k]
		var w := maxf(16.0, r * 2.0)
		var top := (enemies.center_of(i) - Vector2(w * 0.5, r + 8.0)).round()
		var frac := enemies.hp_frac(i)
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
	for g: Dictionary in buffs.ground:   # each ground buff's pick-up circle (taken when it touches the body)
		draw_arc(g["pos"], buffs.collect_radius(), 0.0, TAU, 24, Color(1.0, 0.9, 0.3, 0.9), 1.5)
	for fx in _fx:
		var hb := SpriteHitbox.of(fx["sheet"], fx["anim"], _fx_pos(fx), float(fx["scale"]))
		if hb != null:
			var on: bool = hb.is_active(float(fx["t"])) or fx["anim"] == "spin"
			hb.draw(self, Color(1.0, 0.2, 0.2, 0.95) if on else Color(1.0, 0.6, 0.2, 0.4), 2.0 if on else 1.0)



