class_name Enemies
extends RefCounted
## Every monster of a run as parallel packed arrays (no node per monster), so
## hundreds can move, collide and be drawn each frame. Arrays are allocated once
## at max_enemies; dead slots are swap-removed.
##
## Example:
##   var e := Enemies.new(monsters_json, run_config, sheets)
##   e.spawn("slime", Vector2(800, 0))
##   var contact := e.step(delta, player_pos, player_center)   # largest contact damage this frame
##   e.hit_circle(center, 80.0, 12.0)                           # kills land in kill_pos / kill_xp

enum { MOVE, WINDUP, DASH, DYING }
enum { CHASE, SWARM, CHARGE, BOSS_SLIME, SHOOT, ZIGZAG, BOSS_TREE, HOP, SUPPORT, FLEE }

const HURT_FLASH := 0.12
const KNOCKBACK_DECAY := 10.0

var count := 0
var capacity := 0

# per monster
var pos := PackedVector2Array()
var knock := PackedVector2Array()
var dash_dir := PackedVector2Array()
var kind := PackedInt32Array()
var state := PackedInt32Array()
var hp := PackedFloat32Array()
var hp_cap := PackedFloat32Array()   # hp at spawn: the most a species regen heals back to
var shell_on := PackedByteArray()   # 1 = Côn trùng's shell still takes the next hit
var calm_t := PackedFloat32Array()   # seconds since the last hit (Nhầy regen waits for it)
var timer := PackedFloat32Array()     # state timer (windup / dash / dying)
var charge_cd := PackedFloat32Array()
var flash := PackedFloat32Array()
var anim_t := PackedFloat32Array()
var phase := PackedFloat32Array()
var flip := PackedByteArray()          # 1 = drawn mirrored (player is to the left)
var hp_show := PackedFloat32Array()    # seconds the hp bar stays visible (set on every hit)
# statuses (assets/data/statuses.json): seconds left and strength
var slow_t := PackedFloat32Array()
var slow_mul := PackedFloat32Array()   # speed multiplier while slowed
var stun_t := PackedFloat32Array()     # stunned: no movement, timers stop
var freeze_t := PackedFloat32Array()   # frozen: same as stunned, drawn in ice
var bleed_t := PackedFloat32Array()
var bleed_dps := PackedFloat32Array()
var burn_t := PackedFloat32Array()
var shock_t := PackedFloat32Array()   # shock mark: a later shock hit arcs here
var tongue_t := PackedFloat32Array()   # Cóc Độc Bào Tử tongue: > 0 aiming s left, < 0 shooting (s since), 0 none
var tongue_len := PackedFloat32Array()  # how far the tongue reaches now
var tongue_dir := PackedVector2Array()  # where it aims (set as the aim starts)
var summon_t := PackedFloat32Array()  # when a boss called this monster (_time), -1 when not called (absorb)
var phase_t := PackedFloat32Array()   # boss phase 2 transition seconds left (> 0: invulnerable, still)
var phase_on := PackedByteArray()      # 1 = this boss entered phase 2 (its transition started)
var flee_t := PackedFloat32Array()    # Yêu tinh vàng: seconds spent fleeing (the portal opens at flee_time)
var burn_dps := PackedFloat32Array()
var dot_wait := PackedFloat32Array()   # time to the next damage-over-time tick
var bleed_src := PackedStringArray()
## Ánh sáng / Bóng tối statuses (statuses.json holy_mark / corrode, design/species.md E5/E6)
var holy_t := PackedFloat32Array()
var holy_dmg := PackedFloat32Array()   # the marking hit: the burst deals burst_mul of it
var holy_src := PackedStringArray()
var corrode_t := PackedFloat32Array()
var corrode_n := PackedByteArray()     # stacks
var corrode_src := PackedStringArray()
var status_defs := {}                  # statuses.json "statuses" (set by the run): numbers of holy_mark / corrode
var status_fx: Array = []              # [sprite, world pos] bursts this step; the run draws and clears them
var burn_src := PackedStringArray()
const DOT_TICK := 0.5
## Shock arcs since the last drain (pairs of points, for the run to draw).
var shock_lines := PackedVector2Array()

# per kind (index = kind id)
var kind_ids: Array[String] = []
var k_sheet: Array[SpriteSheet] = []
var k_rage_sheet: Array = []   # SpriteSheet or null: drawn while the boss is enraged (rage_sprite)
var k_behaviour := PackedInt32Array()
var k_hp := PackedFloat32Array()
var k_damage := PackedFloat32Array()
var k_speed := PackedFloat32Array()
var k_radius := PackedFloat32Array()
## How far a monster's body reaches from the point the spatial hash stores (its
## feet): body radius + how far the body centre sits above the feet. The widest
## kind's value; hit-box queries add it so no body at the edge is skipped.
var max_hit_r := 0.0
var k_xp := PackedFloat32Array()
var k_scale := PackedFloat32Array()
var k_center := PackedVector2Array()     # body centre relative to the anchor point (facing right)
var k_death_time := PackedFloat32Array()
var k_extra: Array[Dictionary] = []
var k_elite := PackedByteArray()    # 1 = an elite kind ("<id>@elite", run_config "elite")
var k_boss := PackedByteArray()     # 1 = a boss (HUD bar, the stage is won when it dies)
## Boss-specific events, emitted for BossFx (src/run/boss_fx.gd) to draw.
signal slam_done(pos: Vector2)
signal split_done(pos: Vector2)

# hits since the last drain_hits() (the run shows them as damage numbers)
var hit_pos := PackedVector2Array()
var hit_val := PackedFloat32Array()
var hit_crit := PackedByteArray()        # 1 = that hit was a crit (its number draws as one)
var hit_src := PackedStringArray()       # damage source of that hit (hit sparks: physical melee)
var hit_tag := PackedByteArray()         # species x element of that hit: 0 plain, 1 weak, 2 resisted (number colour)
## Species (species.json, design/species.md): weak / resist by element; set by set_species.
var species := {}
var k_phase := PackedByteArray()   # 1 = the kind's species flies through props and other monsters (Linh hồn)
var element_of := {}
var contact_bleed := {}   # the last step's contact came from a bite_bleed species: its bite_bleed {time, dps_mul}, else {}   # damage source (skill id) -> element; sources not in it take no species change
var crit_chance := 0.0   # Chí mạng of direct hits (the run sets it from the stats, 6C.2)
var crit_mul := 1.75
var _crit_next := false
var crits_by := {}       # source -> crits landed
var crit_heavy := 0      # crits on elites / bosses since the last drain_hits (hitstop, shake)
var hp_bar_time := 2.0

# kills since the last drain_kills() (the run turns them into gems)
var kill_pos := PackedVector2Array()
var kill_xp := PackedFloat32Array()
var kill_elite := PackedByteArray()   # 1 = the kill was an elite (drops a chest)
var kill_boss := PackedByteArray()
var kill_gold := PackedFloat32Array()   # coins the kill drops (gold_drop, Yêu tinh vàng)
var kill_chest := PackedByteArray()     # 1 = the kill drops a chest (elites, chest_drop)
var gold_trail := PackedVector2Array()  # coins dropped by fleeing monsters this step
var escaped := PackedVector2Array()     # where fleeing monsters escaped through their portal this step
## Boss landings since the last drain (positions, for the run to draw the dust).
var slams := PackedVector2Array()
var total_kills := 0
## Per damage source (skill id, "" when unnamed), for the end-of-run table:
## damage actually dealt (overkill not counted), hits, kills.
var damage_by := {}
var hits_by := {}
var kills_by := {}
var kills_kind := {}   # monster id (no "@elite") -> kills this run: the Album unlocks a monster at its first kill

var spawn_ring := Vector2(760, 860)
var despawn_distance := 1300.0
var arena_half := 1400.0
var obstacles: Obstacles = null   # the stage's rocks / trees: monsters slide round them (design/obstacles.md)
var player_hit_radius := 14.0
# monster bolts (behaviour "shoot", design 6A): slow, straight, dodgeable
var bolt_pos := PackedVector2Array()
var bolt_vel := PackedVector2Array()
var bolt_life := PackedFloat32Array()
var bolt_dmg := PackedFloat32Array()
var bolt_kind := PackedInt32Array()      # the shooter's kind (its bolt sprite, bolt radius)
var bolt_pops := PackedVector2Array()    # where bolts burst this step (the run draws a pop)
var _player_center := Vector2.ZERO
# elite affixes (run_config.json elite.affixes, design 6A): one per elite, by index into affix_ids
var affix := PackedInt32Array()          # -1 = none
var uid := PackedInt32Array()            # unique per spawn (survives swap-removes): "hit once" sets
var _next_uid := 1
var hunted := PackedByteArray()          # 1 = the marked elite of a Săn tinh anh challenge
var buffed := PackedByteArray()          # 1 = spawned under the boss's aura (boss_aura)
## The living boss's passive (monsters.json "aura", set by the run while the boss lives; {} otherwise):
## hp_mul, damage_mul, regen (share of max hp per second) for every monster spawned under it (user 2026-11-21).
var boss_aura: Dictionary = {}
var affix_ids: Array[String] = []
var _affix_defs: Array[Dictionary] = []
var _split_q: Array = []
# boss shockwaves (Vua Thạch Nhầy enraged, design 6A): rings running out from a slam
var wave_pos := PackedVector2Array()
var wave_r := PackedFloat32Array()
var wave_max := PackedFloat32Array()
var wave_hit := PackedInt32Array()       # 1 once it has hit the player (one hit per ring)
var wave_def: Array[Dictionary] = []
# Cổ Thụ Trụi Lá root walls (design/bosses.md): segment a-b, seconds left (warn first, then standing)
var wall_a := PackedVector2Array()
var wall_b := PackedVector2Array()
var wall_t := PackedFloat32Array()
var wall_def: Array = []
var absorb_lines: Array = []   # [from, to] minions pulled into a boss this step (the run draws root tethers)
var tongue_pull: Array = []   # [boss centre] when a tongue caught the hero this step (the run pulls the hero in)
var wave_knock: Array = []    # [wave centre, px/s] when a knockback shockwave hit the hero this step
var phase_push: Array = []   # [boss pos, push px/s] when a boss starts its phase 2 transition (the run pushes the hero)
var raged: Array[int] = []              # boss indices that just turned enraged this step (the run announces it)                 # [kind, pos]: monsters to spawn after this step (Phân thân)
# death bursts ("explode" on a monster, design 6A Bọ Lửa): a warning ring, then a blast
var blast_pos := PackedVector2Array()
var blast_t := PackedFloat32Array()      # seconds left before it goes off
var blast_r := PackedFloat32Array()
var blast_dmg := PackedFloat32Array()
var blast_total := PackedFloat32Array()  # its full delay (the ring fills as it counts down)
var blasts_done := PackedVector2Array()  # blasts that went off this step (the run draws them)
var blast_root := PackedByteArray()      # 1 = a Mộc Yêu root (drawn as roots, not a burst)
var roots_done := PackedVector2Array()
var heal_pulses: Array = []   # [centre, radius] of Hồn Đầm heals this step (the run draws them)
# poison pools (Cóc Độc, design 6A): hurt a player standing inside until they dry up
var pool_pos := PackedVector2Array()
var pool_t := PackedFloat32Array()
var pool_total := PackedFloat32Array()
var pool_r := PackedFloat32Array()
var player_in_pool := false   # the player stands in a monster's poison pool (drawn: Run poison look)
var pool_purple := PackedByteArray()   # 1 = a Cóc Độc Bào Tử spore pool (drawn purple)
var pool_dmg := PackedFloat32Array()   # roots that erupted this step (the run draws them)
var bonus_by := {}   # extra damage added by passives ("vs_status": Cộng hưởng nguyên tố), end report
var far_mul := 0.0             # class passive Mắt ưng: extra damage on monsters farther than far_px from the hero
var far_px := 0.0
var hero_at := Vector2.ZERO      # the hero's position this step (Mắt ưng distance)
var vs_status_mul := 0.0        # class passive: extra damage taken by monsters with a status   # set by the run from the class sprite's body

var _hash: SpatialHash
var _hashed_count := 0
var _push := 60.0
var _query := PackedInt32Array()
var spawn_hp_mul := 1.0   # set by the run each frame: monsters spawned later have more hp (time_scale)
var _rng := RandomNumberGenerator.new()
var _crit_rng := RandomNumberGenerator.new()   # its own stream: crit rolls must not shift spawns (a run stays reproducible)
var _time := 0.0
var _target := Vector2.ZERO   # the player position this step (boss jump targets)
var _slam_i := -1


func _init(monsters: Dictionary, cfg: Dictionary, sheets: Dictionary, seed_value := 0) -> void:
	_rng.seed = seed_value
	_crit_rng.seed = seed_value * 31 + 7
	BossFxNode.attach(self)
	var world: Dictionary = cfg.get("world", {})
	var ring: Array = world.get("spawn_ring", [760.0, 860.0])
	spawn_ring = Vector2(float(ring[0]), float(ring[1]))
	despawn_distance = float(world.get("despawn_distance", 1300.0))
	arena_half = float(world.get("arena_half", 1400.0))
	var sep: Dictionary = cfg.get("separation", {})
	_hash = SpatialHash.new(float(sep.get("cell", 48.0)))
	_push = float(sep.get("push", 60.0))
	capacity = int(cfg.get("max_enemies", 200))
	# packed arrays are values: each member is resized on its own
	pos.resize(capacity)
	knock.resize(capacity)
	dash_dir.resize(capacity)
	kind.resize(capacity)
	state.resize(capacity)
	hp.resize(capacity)
	timer.resize(capacity)
	charge_cd.resize(capacity)
	flash.resize(capacity)
	hp_cap.resize(capacity)
	calm_t.resize(capacity)
	shell_on.resize(capacity)
	anim_t.resize(capacity)
	phase.resize(capacity)
	flip.resize(capacity)
	hp_show.resize(capacity)
	affix.resize(capacity)
	uid.resize(capacity)
	buffed.resize(capacity)
	hunted.resize(capacity)
	phase_on.resize(capacity)
	tongue_dir.resize(capacity)
	for a: Variant in [slow_t, slow_mul, stun_t, freeze_t, bleed_t, bleed_dps, burn_t, burn_dps, shock_t, flee_t, dot_wait, phase_t, summon_t, tongue_t, tongue_len]:
		a.resize(capacity)
	bleed_src.resize(capacity)
	holy_t.resize(capacity)
	holy_dmg.resize(capacity)
	holy_src.resize(capacity)
	corrode_t.resize(capacity)
	corrode_n.resize(capacity)
	corrode_src.resize(capacity)
	burn_src.resize(capacity)
	hp_bar_time = float(cfg.get("ui", {}).get("hp_bar_time", 2.0))
	var world_scale := float(world.get("sprite_scale", 2))
	var elite: Dictionary = cfg.get("elite", {})
	var defs: Dictionary = elite.get("affixes", {})
	for aid: String in defs:
		if not aid.begins_with("_"):
			affix_ids.append(aid)
			_affix_defs.append(defs[aid])
	for id: String in monsters:
		if id.begins_with("_"):
			continue
		var m: Dictionary = monsters[id]
		_register(id, m, sheets.get(String(m.get("sprite", id))), world_scale, {})
		k_rage_sheet[-1] = sheets.get(String(m.get("rage_sprite", "")))
		# every monster also has an elite kind, spawned by waves as "<id>@elite"
		if not elite.is_empty() and not bool(m.get("boss", false)):
			_register(id + "@elite", m, sheets.get(String(m.get("sprite", id))), world_scale, elite)


const BEHAVIOURS := {"chase": CHASE, "swarm": SWARM, "charge": CHARGE, "boss_slime": BOSS_SLIME, "shoot": SHOOT, "zigzag": ZIGZAG, "boss_tree": BOSS_TREE, "hop": HOP, "support": SUPPORT, "flee": FLEE}


## One monster kind; [param elite] = multipliers (hp_mul, damage_mul, scale_mul,
## xp_mul), empty for a normal kind.
func _register(id: String, m: Dictionary, sheet: SpriteSheet, world_scale: float, elite: Dictionary) -> void:
	var is_elite := not elite.is_empty()
	kind_ids.append(id)
	k_sheet.append(sheet)
	k_rage_sheet.append(null)
	k_behaviour.append(BEHAVIOURS.get(String(m.get("behaviour", "chase")), CHASE))
	k_hp.append(float(m.get("hp", 10.0)) * float(elite.get("hp_mul", 1.0)))
	k_damage.append(float(m.get("damage", 5.0)) * float(elite.get("damage_mul", 1.0)))
	k_speed.append(float(m.get("speed", 50.0)) * float(elite.get("speed_mul", 1.0)))
	k_xp.append(float(m.get("xp", 1.0)) * float(elite.get("xp_mul", 1.0)))
	var sc := float(m.get("scale", world_scale)) * float(elite.get("scale_mul", 1.0))
	k_scale.append(sc)
	# body circle measured from the sprite's pixels (json "body"), never typed in data
	var body := SpriteHitbox.body(sheet, Vector2.ZERO, sc)
	if body == null:
		push_error("Enemies: sprite of %s has no body circle; regenerate it in Sprite Lab" % id)
		body = SpriteHitbox.new()
		body.radius = 8.0 * sc
	k_radius.append(body.radius)
	k_center.append(body.center)
	max_hit_r = maxf(max_hit_r, body.radius + body.center.length())
	k_death_time.append(sheet.duration("death") if sheet != null and sheet.has_animation("death") else 0.4)
	k_extra.append(m)
	k_phase.append(1 if has_trait(k_extra.size() - 1, "phase") else 0)   # kinds added after set_species too
	k_elite.append(1 if is_elite else 0)
	k_boss.append(1 if bool(m.get("boss", false)) else 0)


## Species table (species.json) and the element of each damage source (skill id -> element).
func set_species(table: Dictionary, elements_by_source: Dictionary) -> void:
	species = table
	element_of = elements_by_source
	k_phase.resize(k_extra.size())
	for k in k_extra.size():
		k_phase[k] = 1 if has_trait(k, "phase") else 0


## Thánh ấn runs out -> a light burst; Ăn mòn runs out -> its stacks go (design/species.md E5/E6).
func _step_light_dark(i: int, delta: float) -> void:
	if corrode_t[i] > 0.0:
		corrode_t[i] -= delta
		if corrode_t[i] <= 0.0:
			corrode_n[i] = 0
	if holy_t[i] > 0.0:
		holy_t[i] -= delta
		if holy_t[i] <= 0.0:
			var hd: Dictionary = status_defs.get("holy_mark", {})
			var c := center_of(i)
			status_fx.append([String(hd.get("burst_sprite", "light-burst")), c])
			hit_circle(c, float(hd.get("burst_radius", 40.0)), holy_dmg[i] * float(hd.get("burst_mul", 0.1)), 0.0, holy_src[i])
			holy_dmg[i] = 0.0


## A monster dying with burst_at Ăn mòn stacks or more bursts: one stack to every monster within burst_radius.
func _corrode_burst(i: int) -> void:
	var cd: Dictionary = status_defs.get("corrode", {})
	if corrode_n[i] < int(cd.get("burst_at", 2)):
		return
	var c := center_of(i)
	status_fx.append([String(cd.get("burst_sprite", "shadow-burst")), c])
	var near := PackedInt32Array()
	var rad := float(cd.get("burst_radius", 56.0))
	_hash.query(c, rad, near)
	for j in near:
		if j != i and state[j] != DYING and center_of(j).distance_to(c) <= rad + k_radius[kind[j]]:
			apply_status(j, "corrode", {}, 0.0, corrode_src[i])
	corrode_n[i] = 0


## The species entry of kind [param k] (species.json), {} without one.
func _species_of(k: int) -> Dictionary:
	return species.get("species", {}).get(String(k_extra[k].get("species", "")), {})


## Thú (species trait enrage): speed x enrage.speed_mul below enrage.below of its spawn hp, else 1.
func enrage_mul(i: int) -> float:
	if not has_trait(kind[i], "enrage") or hp_cap[i] <= 0.0:
		return 1.0
	var en: Dictionary = _species_of(kind[i]).get("enrage", {})
	return float(en.get("speed_mul", 1.3)) if hp[i] < hp_cap[i] * float(en.get("below", 0.3)) else 1.0


## Côn trùng (species trait swarm): speed x swarm.speed_mul with swarm.count of its species within
## swarm.radius px (itself included), else 1.
func swarm_mul(i: int) -> float:
	if not has_trait(kind[i], "swarm"):
		return 1.0
	var sw: Dictionary = _species_of(kind[i]).get("swarm", {})
	var sid := String(k_extra[kind[i]].get("species", ""))
	var near := PackedInt32Array()
	_hash.query(pos[i], float(sw.get("radius", 80.0)), near)
	var n := 0
	for j in near:
		if state[j] != DYING and String(k_extra[kind[j]].get("species", "")) == sid and pos[j].distance_to(pos[i]) <= float(sw.get("radius", 80.0)):
			n += 1
	return float(sw.get("speed_mul", 1.2)) if n >= int(sw.get("count", 3)) else 1.0


## Nhầy (species trait regen): after regen.delay s without a hit it heals regen.pct of its spawn hp a
## second, up to that hp; Bỏng stops it (design/species.md).
func _step_regen(i: int, delta: float) -> void:
	calm_t[i] += delta
	if burn_t[i] > 0.0 or hp[i] >= hp_cap[i] or not has_trait(kind[i], "regen"):
		return
	var rg: Dictionary = species["species"][String(k_extra[kind[i]].get("species", ""))].get("regen", {})
	if calm_t[i] >= float(rg.get("delay", 2.0)):
		hp[i] = minf(hp_cap[i], hp[i] + hp_cap[i] * float(rg.get("pct", 0.03)) * delta)


## True when kind [param k]'s species has behaviour trait [param t] (species.json traits).
func has_trait(k: int, t: String) -> bool:
	return species.get("species", {}).get(String(k_extra[k].get("species", "")), {}).get("traits", []).has(t)


## Damage multiplier for kind [param k] hit by [param element]: mul_weak / mul_resist of its species,
## bosses take boss_scale of the change (design/species.md).
func species_mul(k: int, element: String) -> float:
	if element == "" or species.is_empty():
		return 1.0
	var sp: Dictionary = species.get("species", {}).get(String(k_extra[k].get("species", "")), {})
	var mul := 1.0
	if sp.get("weak", []).has(element):
		mul = float(species.get("mul_weak", 1.5))
	elif sp.get("resist", []).has(element):
		mul = float(species.get("mul_resist", 0.6))
	if k_boss[k] == 1:
		mul = 1.0 + (mul - 1.0) * float(species.get("boss_scale", 0.5))
	return mul


## True when kind [param k]'s species never takes [param status] (species.json immune_status).
func immune(k: int, status: String) -> bool:
	return species.get("species", {}).get(String(k_extra[k].get("species", "")), {}).get("immune_status", []).has(status)


## Kind index of a monster id, or -1.
func kind_of(id: String) -> int:
	return kind_ids.find(id)


## Multiplies every kind's base hp and damage (stage difficulty scaling).
func scale_kinds(hp_m: float, dmg_m: float) -> void:
	for k in k_hp.size():
		k_hp[k] *= hp_m
		k_damage[k] *= dmg_m


## Adds one monster at [param p]; returns false when the run is at max_enemies.
func spawn(id: String, p: Vector2) -> bool:
	var k := kind_of(id)
	if k < 0:
		return false
	if count >= capacity:
		# a boss or an event monster (spawn_dist) must come even at the cap: the farthest plain
		# monster from where it appears makes room (a dropped boss left a boss stage unwinnable)
		if k_boss[k] == 0 and not k_extra[k].has("spawn_dist"):
			return false
		var far := -1
		var best := -1.0
		for j in count:
			if k_boss[kind[j]] == 0 and k_elite[kind[j]] == 0:
				var d := pos[j].distance_squared_to(p)
				if d > best:
					best = d
					far = j
		if far < 0:
			return false
		_remove(far)
	var i := count
	count += 1
	pos[i] = p
	knock[i] = Vector2.ZERO
	dash_dir[i] = Vector2.ZERO
	kind[i] = k
	state[i] = MOVE
	hp[i] = k_hp[k] * (1.0 if k_boss[k] == 1 else spawn_hp_mul)   # bosses keep their designed hp
	hp_cap[i] = hp[i]
	holy_t[i] = 0.0
	corrode_t[i] = 0.0
	corrode_n[i] = 0
	shell_on[i] = 1 if has_trait(k, "shell") else 0
	calm_t[i] = 0.0
	timer[i] = 0.0
	charge_cd[i] = float(k_extra[k].get("charge_cooldown", 2.0)) * _rng.randf()
	flash[i] = 0.0
	anim_t[i] = _rng.randf() * 2.0
	phase[i] = _rng.randf() * TAU
	flip[i] = 0
	hp_show[i] = 0.0
	affix[i] = -1
	uid[i] = _next_uid
	_next_uid += 1
	buffed[i] = 1 if (k_boss[k] == 0 and not boss_aura.is_empty()) else 0
	hunted[i] = 0
	if buffed[i] == 1:
		hp[i] *= float(boss_aura.get("hp_mul", 1.0))
	if k_elite[k] == 1 and not affix_ids.is_empty():   # every elite gets one affix
		affix[i] = _rng.randi() % affix_ids.size()
	slow_t[i] = 0.0
	slow_mul[i] = 1.0
	stun_t[i] = 0.0
	freeze_t[i] = 0.0
	bleed_t[i] = 0.0
	bleed_dps[i] = 0.0
	burn_t[i] = 0.0
	shock_t[i] = 0.0
	flee_t[i] = 0.0
	phase_t[i] = 0.0
	phase_on[i] = 0
	summon_t[i] = -1.0
	tongue_t[i] = 0.0
	tongue_len[i] = 0.0
	burn_dps[i] = 0.0
	dot_wait[i] = DOT_TICK
	return true


## A spawn point on the ring around [param center], kept inside the arena.
func ring_point(center: Vector2) -> Vector2:
	var a := _rng.randf() * TAU
	var r := _rng.randf_range(spawn_ring.x, spawn_ring.y)
	var p := center + Vector2(cos(a), sin(a)) * r
	return p.clamp(Vector2(-arena_half, -arena_half), Vector2(arena_half, arena_half))


## Body centre of monster [param i] in the world (mirrored with the sprite).
func center_of(i: int) -> Vector2:
	var c := k_center[kind[i]]
	if flip[i] == 1:
		c.x = -c.x
	return pos[i] + c


## Moves every monster one step towards the player. Returns the largest
## contact damage a living monster deals this frame (0 when none touches).
func step(delta: float, player_pos: Vector2, player_center: Vector2) -> float:
	hero_at = player_pos
	contact_bleed = {}
	var regen := float(boss_aura.get("regen", 0.0))
	if regen > 0.0:   # the aura heals its monsters over time (up to their buffed max)
		var hm := float(boss_aura.get("hp_mul", 1.0)) * spawn_hp_mul
		for j in count:
			if buffed[j] == 1 and state[j] != DYING:
				hp[j] = minf(k_hp[kind[j]] * hm, hp[j] + k_hp[kind[j]] * regen * delta)
	_time += delta
	_target = player_pos
	_player_center = player_center
	# 1. timers, and remove monsters whose death animation is over. Removal
	#    swap-moves the last slot, so it must happen before the hash is built.
	var i := 0
	while i < count:
		if freeze_t[i] <= 0.0:   # frozen in ice: the animation stops
			anim_t[i] += delta
		flash[i] = maxf(0.0, flash[i] - delta)
		hp_show[i] = maxf(0.0, hp_show[i] - delta)
		if state[i] != DYING:
			_step_status(i, delta)
		if state[i] == DYING:
			timer[i] += delta
			if timer[i] >= k_death_time[kind[i]]:
				_remove(i)
				continue
		i += 1
	# 2. spatial hash of the living (indices stay valid until the next step;
	#    spawns after this are covered by _hashed_count in hit_arc)
	_hash.clear()
	for j in count:
		if state[j] != DYING:
			_hash.insert(j, pos[j])
	_hashed_count = count
	# 3. move
	var contact := 0.0
	for n in count:
		if state[n] == DYING:
			continue
		var k := kind[n]
		var to_player := player_pos - pos[n]
		var dist := to_player.length()
		if dist > despawn_distance:
			pos[n] = ring_point(player_pos)
			continue
		var dir := to_player / dist if dist > 0.001 else Vector2.ZERO
		flip[n] = 1 if to_player.x < 0.0 else 0
		if k_behaviour[k] == FLEE:   # runs away from the player: faces its way of running (bug 2026-11-22)
			flip[n] = 1 - flip[n]
		var stopped := stun_t[n] > 0.0 or freeze_t[n] > 0.0
		_slam_i = -1
		if k_boss[k] == 1 and phase_on[n] == 0:   # hp set without a hit (a shot's --boss-hp) also starts phase 2
			_check_phase(n)
		if phase_t[n] > 0.0:   # transforming: stands still, shakes (drawn by the run)
			phase_t[n] = maxf(0.0, phase_t[n] - delta)
			stopped = true
		var vel := Vector2.ZERO if stopped else _velocity(n, k, dir, dist, delta) * (slow_mul[n] if slow_t[n] > 0.0 else 1.0)
		if phase_on[n] == 1 and not stopped:
			vel *= float(_phase2(n).get("speed_mul", 1.0))
		if _slam_i == n:   # a boss landed: its slam hits a player within reach
			var reach := k_radius[k] * float(k_extra[k].get("slam_reach", 2.5))
			if (pos[n] + vel * delta).distance_to(player_center) < reach + player_hit_radius:
				contact = maxf(contact, float(k_extra[k].get("slam_damage", k_damage[k])))
		# separation: push away from overlapping neighbours (same cell block)
		var r := k_radius[k]
		_query.clear()
		_hash.query(pos[n], r * 2.0, _query)
		var push := Vector2.ZERO
		var ghost := k < k_phase.size() and k_phase[k] == 1   # Linh hồn: no crowding, no props
		for j in _query:
			if j == n or ghost or (kind[j] < k_phase.size() and k_phase[kind[j]] == 1):
				continue
			var d := pos[n] - pos[j]
			var min_d := r + k_radius[kind[j]]
			var l2 := d.length_squared()
			if l2 < min_d * min_d:
				if l2 < 0.0001:
					d = Vector2(cos(phase[n]), sin(phase[n]))
					l2 = 1.0
				var l := sqrt(l2)
				push += d / l * (min_d - l) / min_d
		vel *= float(_affix_def(n).get("speed_mul", 1.0))   # Nhanh
		vel *= enrage_mul(n)   # Thú: faster when nearly dead
		vel *= swarm_mul(n)   # Côn trùng: faster in a swarm
		if holy_t[n] > 0.0 and k_phase.size() > k and k_phase[k] == 1:   # Thánh ấn slows Linh hồn
			vel *= float(status_defs.get("holy_mark", {}).get("spirit_speed_mul", 0.7))
		vel += push * _push
		knock[n] = knock[n] * maxf(0.0, 1.0 - KNOCKBACK_DECAY * delta)
		pos[n] += (vel + knock[n]) * delta
		pos[n] = pos[n].clamp(Vector2(-arena_half, -arena_half), Vector2(arena_half, arena_half))
		if obstacles != null and not ghost and not has_trait(k, "hop_over"):   # Lưỡng cư hops over props
			pos[n] = obstacles.push_out(pos[n], r)
		if not wall_a.is_empty() and k_boss[k] == 0:   # root walls block plain monsters too
			pos[n] = push_out_walls(pos[n], r)
		if not stopped and (center_of(n) - player_center).length() < r + player_hit_radius:
			var cd := contact_damage(n)
			if cd > contact and has_trait(k, "bite_bleed"):   # Thú (Sói): the bite bleeds
				contact_bleed = _species_of(k).get("bite_bleed", {})
			contact = maxf(contact, cd)
	contact = maxf(contact, _step_waves(delta, player_center))
	for q: Array in _split_q:   # monsters from Phân thân, spawned after the loop over the living
		if int(q[0]) >= 0 and spawn(kind_ids[int(q[0])], q[1]) and q.size() > 2 and bool(q[2]):
			summon_t[count - 1] = _time   # called by a boss: absorbed if left alive
	_split_q.clear()
	contact = maxf(contact, _step_walls(delta, player_center))
	contact = maxf(contact, _step_tongues(delta, player_center))
	return maxf(maxf(maxf(contact, _step_bolts(delta, player_center)), _step_blasts(delta, player_center)), _step_pools(delta, player_center))


## Shockwave rings grow; one hurts the player once when its edge passes over them.
func _step_waves(delta: float, player_center: Vector2) -> float:
	var hit := 0.0
	var w := 0
	while w < wave_pos.size():
		var d: Dictionary = wave_def[w]
		wave_r[w] += float(d.get("speed", 260.0)) * delta
		var edge := absf(wave_pos[w].distance_to(player_center) - wave_r[w])
		if wave_hit[w] == 0 and edge < float(d.get("width", 12.0)) * 0.5 + player_hit_radius * 0.5:
			wave_hit[w] = 1
			hit = maxf(hit, float(d.get("damage", 20.0)))
			if d.has("knock"):
				wave_knock.append([wave_pos[w], float(d["knock"])])
		if d.has("knock"):   # the ring throws plain monsters back too
			for j in count:
				if k_boss[kind[j]] == 0 and state[j] != DYING:
					var off := pos[j] - wave_pos[w]
					if absf(off.length() - wave_r[w]) < float(d.get("width", 12.0)):
						knock[j] = off.normalized() * float(d["knock"])
		if wave_r[w] >= wave_max[w]:
			wave_pos.remove_at(w)
			wave_r.remove_at(w)
			wave_max.remove_at(w)
			wave_hit.remove_at(w)
			wave_def.remove_at(w)
			continue
		w += 1
	return hit


## The affix of monster [param i] (run_config.json elite.affixes entry), {} when none.
func _affix_def(i: int) -> Dictionary:
	var a := affix[i]
	return _affix_defs[a] if a >= 0 and a < _affix_defs.size() else {}


## Vietnamese name and colour of monster [param i]'s affix (["", white] when none).
func affix_label(i: int) -> Array:
	var d := _affix_def(i)
	return [String(d.get("name", "")), Color(String(d.get("color", "#ffffff")))]


## A warning ring at [param p] that goes off after [param delay] s ([param root]:
## a Mộc Yêu root, else a death burst).
func _add_blast(p: Vector2, delay: float, r: float, dmg: float, root: bool) -> void:
	blast_pos.append(p)
	blast_t.append(delay)
	blast_total.append(delay)
	blast_r.append(r)
	blast_dmg.append(dmg)
	blast_root.append(1 if root else 0)


## Mộc Yêu (design/bosses.md): walks slowly; every root_every s (enraged:
## rage_root_every) root_count roots (rage_root_count) erupt after root_delay s,
## one under the player and the rest within root_spread of it; every
## summon_every s it calls summon_count monsters of the summon list around it.
## charge_cd counts the roots, timer the call.
func _boss_tree(i: int, k: int, dir: Vector2, dist: float, speed: float, delta: float) -> Vector2:
	var e: Dictionary = k_extra[k]
	var rage := enraged(i)
	charge_cd[i] -= delta
	if charge_cd[i] <= 0.0:
		charge_cd[i] = float(e.get("rage_root_every" if rage else "root_every", 4.0))
		var target := pos[i] + dir * dist   # where the player stands (dir, dist run from pos)
		var n := int(e.get("rage_root_count" if rage else "root_count", 3))
		var spread := float(e.get("root_spread", 90.0))
		for r in n:
			var p := target if r == 0 else target + Vector2.from_angle(_rng.randf() * TAU) * spread * sqrt(_rng.randf())
			_add_blast(p, float(e.get("root_delay", 0.9)), float(e.get("root_radius", 30.0)), float(e.get("root_damage", 25.0)), true)
		anim_t[i] = 0.0
	timer[i] -= delta
	if timer[i] <= 0.0:
		timer[i] = float(e.get("summon_every", 12.0)) * (float(_phase2(i).get("cd_mul", 1.0)) if phase_on[i] == 1 else 1.0)
		var list: Array = e.get("summon", [])
		for s in int(e.get("summon_count", 3)):
			if list.is_empty():
				break
			var ki := kind_ids.find(String(list[s % list.size()]))
			if ki >= 0:
				_split_q.append([ki, pos[i] + Vector2.from_angle(s * TAU / 3.0 + phase[i]) * 40.0, phase_on[i] == 1])
	if phase_on[i] == 1 and phase_t[i] <= 0.0:
		_tree_phase2(i, e, dir, dist, delta)
	return dir * speed


## Cổ Thụ Trụi Lá (design/bosses.md): every root_wall.every s a wall of thorny roots across the hero's path
## (perpendicular to boss -> hero, ahead of the hero), warning warn s then standing time s; minions it
## called that are still alive absorb.after s later are pulled in, each healing heal_each of max hp
## (at most heal_max per call). charge_cd is used by the roots, flee_t (unused by bosses) by the wall.
func _tree_phase2(i: int, e: Dictionary, dir: Vector2, dist: float, delta: float) -> void:
	var w: Dictionary = e.get("root_wall", {})
	if not w.is_empty():
		flee_t[i] -= delta
		if flee_t[i] <= 0.0:
			flee_t[i] = float(w.get("every", 7.0))
			var hero := pos[i] + dir * dist
			var c := hero + dir * float(w.get("ahead", 70.0))
			var half := dir.orthogonal() * float(w.get("length", 260.0)) * 0.5
			wall_a.append(c - half)
			wall_b.append(c + half)
			wall_t.append(float(w.get("warn", 0.6)) + float(w.get("time", 4.0)))
			wall_def.append(w)
	var ab: Dictionary = e.get("absorb", {})
	if ab.is_empty():
		return
	var healed := 0.0
	for j in count:
		if summon_t[j] >= 0.0 and state[j] != DYING and _time - summon_t[j] >= float(ab.get("after", 6.0)):
			summon_t[j] = -1.0
			state[j] = DYING   # pulled in: gone without a kill (no drop)
			timer[j] = k_death_time[kind[j]]
			absorb_lines.append([center_of(j), center_of(i)])
			healed += float(ab.get("heal_each", 0.02))
	if healed > 0.0:
		hp[i] = minf(hp_cap[i], hp[i] + hp_cap[i] * minf(healed, float(ab.get("heal_max", 0.1))))   # its own spawn hp


## A poison pool at [param p] for [param time] s: a player within [param r] takes
## [param dmg] (the run's hurt cooldown spaces the hits).
func add_pool(p: Vector2, time: float, r: float, dmg: float, purple := false) -> void:
	pool_purple.append(1 if purple else 0)
	pool_pos.append(p)
	pool_t.append(time)
	pool_total.append(time)
	pool_r.append(r)
	pool_dmg.append(dmg)


func _step_pools(delta: float, player_center: Vector2) -> float:
	var hit := 0.0
	player_in_pool = false
	var b := 0
	while b < pool_pos.size():
		pool_t[b] -= delta
		if pool_t[b] <= 0.0:
			pool_pos.remove_at(b)
			pool_t.remove_at(b)
			pool_total.remove_at(b)
			pool_r.remove_at(b)
			pool_dmg.remove_at(b)
			pool_purple.remove_at(b)
			continue
		if pool_pos[b].distance_to(player_center) < pool_r[b] + player_hit_radius * 0.5:
			hit = maxf(hit, pool_dmg[b])
			player_in_pool = true
		b += 1
	return hit


## Yêu tinh vàng (design/events.md, after Diablo's treasure goblin): never attacks; runs straight away
## from the player dropping a coin every trail_every s; after flee_time it stops and channels a portal
## (WINDUP, channel s); a hit interrupts it (back to running); when the channel ends it escapes.
func _flee(i: int, k: int, dir: Vector2, speed: float, delta: float) -> Vector2:
	var e: Dictionary = k_extra[k]
	match state[i]:
		WINDUP:
			if flash[i] > 0.0:   # hit while channelling: the portal breaks
				state[i] = MOVE
				flee_t[i] = float(e.get("flee_time", 15.0)) - 2.0
				return -dir * speed
			timer[i] -= delta
			if timer[i] <= 0.0:
				escaped.append(pos[i])
				state[i] = DYING   # gone through the portal: no kill, no drops
				timer[i] = 99.0
			return Vector2.ZERO
		_:
			flee_t[i] += delta
			var every := float(e.get("trail_every", 1.0))
			if floorf(flee_t[i] / every) > floorf((flee_t[i] - delta) / every):
				gold_trail.append(pos[i])
			if flee_t[i] >= float(e.get("flee_time", 15.0)):
				state[i] = WINDUP
				timer[i] = float(e.get("channel", 2.0))
				anim_t[i] = 0.0
				return Vector2.ZERO
			return -dir * speed


## Hồn Đầm (design 6A): hovers at keep_range from the player; every heal_every s
## it heals every other living non-boss monster within heal_radius by heal_pct
## of its max hp (timer counts the heal).
func _support(i: int, k: int, dir: Vector2, dist: float, speed: float, delta: float) -> Vector2:
	var e: Dictionary = k_extra[k]
	timer[i] -= delta
	if timer[i] <= 0.0:
		timer[i] = float(e.get("heal_every", 3.0))
		var c := center_of(i)
		var r := float(e.get("heal_radius", 120.0))
		var pct := float(e.get("heal_pct", 0.25))
		for j in count:
			if j == i or state[j] == DYING or k_boss[kind[j]] == 1:
				continue
			if center_of(j).distance_to(c) <= r:
				hp[j] = minf(hp_cap[j], hp[j] + hp_cap[j] * pct)   # its own spawn hp (later monsters have more)
		heal_pulses.append([c, r])
		anim_t[i] = 0.0
	var keep := float(e.get("keep_range", 220.0))
	if dist < keep - 20.0:
		return -dir * speed
	if dist > keep + 40.0:
		return dir * speed
	return dir.orthogonal() * speed * 0.4   # drifts sideways at its range


## Cóc Độc: crawls; every hop_every s within hop_range it crouches (WINDUP,
## windup s), leaps to where the player stood in hop_time s and leaves a pool.
func _hopper(i: int, k: int, dir: Vector2, dist: float, speed: float, delta: float) -> Vector2:
	var e: Dictionary = k_extra[k]
	match state[i]:
		WINDUP:
			timer[i] -= delta
			if timer[i] <= 0.0:
				state[i] = DASH
				var ht := float(e.get("hop_time", 0.5))
				timer[i] = ht
				dash_dir[i] = (dash_dir[i] - pos[i]) / ht
				anim_t[i] = 0.0
			return Vector2.ZERO
		DASH:
			timer[i] -= delta
			if timer[i] <= 0.0:
				state[i] = MOVE
				charge_cd[i] = float(e.get("hop_every", 2.5))
				var pl: Dictionary = e.get("pool", {})
				if not pl.is_empty():
					add_pool(pos[i] + dash_dir[i] * delta, float(pl.get("time", 3.0)), float(pl.get("radius", 28.0)), float(pl.get("damage", 8.0)))
			return dash_dir[i]
		_:
			charge_cd[i] -= delta
			if charge_cd[i] <= 0.0 and dist < float(e.get("hop_range", 240.0)):
				state[i] = WINDUP
				timer[i] = float(e.get("windup", 0.4))
				dash_dir[i] = pos[i] + dir * dist   # where the player stands now
				anim_t[i] = 0.0
				return Vector2.ZERO
			return dir * speed


## Counts down death bursts; one that goes off with the player inside hurts.
func _step_blasts(delta: float, player_center: Vector2) -> float:
	var hit := 0.0
	var b := 0
	while b < blast_pos.size():
		blast_t[b] -= delta
		if blast_t[b] > 0.0:
			b += 1
			continue
		if blast_pos[b].distance_to(player_center) < blast_r[b] + player_hit_radius:
			hit = maxf(hit, blast_dmg[b])
		if blast_root[b] == 1:
			roots_done.append(blast_pos[b])
		else:
			blasts_done.append(blast_pos[b])
		blast_root.remove_at(b)
		blast_t.remove_at(b)   # packed arrays are values: remove from each one itself
		blast_r.remove_at(b)
		blast_dmg.remove_at(b)
		blast_total.remove_at(b)
		blast_pos.remove_at(b)
	return hit


## Shooter: closes in when far, backs off when the player comes near, strafes in
## between; every shoot_every s within shoot_range it aims (WINDUP: the attack
## animation is the warning) and spits one bolt at where the player is then.
func _shooter(i: int, k: int, dir: Vector2, dist: float, speed: float, delta: float) -> Vector2:
	var e: Dictionary = k_extra[k]
	charge_cd[i] -= delta
	if state[i] == WINDUP:
		timer[i] -= delta
		if timer[i] <= 0.0:
			state[i] = MOVE
			charge_cd[i] = float(e.get("shoot_every", 2.6))
			fire_bolt(i, (_player_center - center_of(i)).normalized())
		return Vector2.ZERO
	var keep := float(e.get("keep_range", 220.0))
	if charge_cd[i] <= 0.0 and dist < float(e.get("shoot_range", 320.0)):
		state[i] = WINDUP
		timer[i] = float(e.get("windup", 0.5))
		anim_t[i] = 0.0
		return Vector2.ZERO
	if dist > keep + 30.0:
		return dir * speed
	if dist < keep - 30.0:
		return -dir * speed * 0.8
	return dir.orthogonal() * speed * 0.6 * (1.0 if fmod(phase[i], 2.0) < 1.0 else -1.0)


## Spawns a bolt from monster [param i] along [param dir] (its kind's bolt_speed,
## bolt_damage or damage, bolt_range).
func fire_bolt(i: int, dir: Vector2) -> void:
	var k := kind[i]
	var e: Dictionary = k_extra[k]
	var speed := float(e.get("bolt_speed", 150.0))
	bolt_pos.append(center_of(i))
	bolt_vel.append(dir * speed)
	bolt_life.append(float(e.get("bolt_range", 420.0)) / speed)
	bolt_dmg.append(float(e.get("bolt_damage", k_damage[k])))
	bolt_kind.append(k)


## Moves bolts; returns the damage of one touching the player (it bursts).
func _step_bolts(delta: float, player_center: Vector2) -> float:
	var hit := 0.0
	var b := 0
	while b < bolt_pos.size():
		bolt_pos[b] += bolt_vel[b] * delta
		bolt_life[b] -= delta
		var r := float(k_extra[bolt_kind[b]].get("bolt_radius", 5.0))
		var touch := bolt_pos[b].distance_to(player_center) < r + player_hit_radius
		if touch or bolt_life[b] <= 0.0:
			if touch:
				hit = maxf(hit, bolt_dmg[b])
			bolt_pops.append(bolt_pos[b])
			bolt_pos.remove_at(b)
			bolt_vel.remove_at(b)
			bolt_life.remove_at(b)
			bolt_dmg.remove_at(b)
			bolt_kind.remove_at(b)
			continue
		b += 1
	return hit


func _velocity(i: int, k: int, dir: Vector2, dist: float, delta: float) -> Vector2:
	var speed := k_speed[k]
	match k_behaviour[k]:
		SWARM:
			var wobble := float(k_extra[k].get("wobble", 0.0))
			return dir * speed + dir.orthogonal() * sin(_time * 3.0 + phase[i]) * wobble
		CHARGE:
			var e: Dictionary = k_extra[k]
			charge_cd[i] -= delta
			match state[i]:
				WINDUP:
					timer[i] -= delta
					if timer[i] <= 0.0:
						state[i] = DASH
						timer[i] = float(e.get("dash_time", 0.35))
					return Vector2.ZERO
				DASH:
					timer[i] -= delta
					if timer[i] <= 0.0:
						state[i] = MOVE
						charge_cd[i] = float(e.get("charge_cooldown", 2.2))
					return dash_dir[i] * float(e.get("dash_speed", 300.0))
				_:
					if charge_cd[i] <= 0.0 and dist < float(e.get("charge_range", 180.0)):
						state[i] = WINDUP
						timer[i] = float(e.get("windup", 0.45))
						dash_dir[i] = dir
						anim_t[i] = 0.0
						return Vector2.ZERO
			return dir * speed
		BOSS_SLIME:
			return _boss_slime(i, k, dir, speed, delta)
		SHOOT:
			return _shooter(i, k, dir, dist, speed, delta)
		FLEE:
			return _flee(i, k, dir, speed, delta)
		SUPPORT:
			return _support(i, k, dir, dist, speed, delta)
		HOP:
			return _hopper(i, k, dir, dist, speed, delta)
		BOSS_TREE:
			return _boss_tree(i, k, dir, dist, speed, delta)
		ZIGZAG:   # Ma Trơi: sharp alternating diagonals every zig_time s (design 6A)
			var e: Dictionary = k_extra[k]
			var leg := floori((_time + phase[i]) / maxf(0.05, float(e.get("zig_time", 0.5))))
			var side := 1.0 if leg % 2 == 0 else -1.0
			return dir.rotated(deg_to_rad(float(e.get("zig_angle", 55.0))) * side) * speed
		_:
			return dir * speed


## Vua Slime: crawls after the player; every jump_every s it winds up (windup s,
## the target is where the player is then: dash_dir holds it), jumps there in
## jump_time s and lands: a slam at the landing (slams; the step turns it into
## contact damage for a player within slam_reach x its body radius).
func _boss_slime(i: int, k: int, dir: Vector2, speed: float, delta: float) -> Vector2:
	var e: Dictionary = k_extra[k]
	match state[i]:
		WINDUP:
			timer[i] -= delta
			if timer[i] <= 0.0:
				state[i] = DASH
				var jt := float(e.get("jump_time", 0.6))
				timer[i] = jt
				dash_dir[i] = (dash_dir[i] - pos[i]) / jt   # target -> velocity
				anim_t[i] = 0.0
			return Vector2.ZERO
		DASH:
			timer[i] -= delta
			if timer[i] <= 0.0:
				state[i] = MOVE
				charge_cd[i] = float(e.get("rage_jump_every", 3.0)) if enraged(i) else float(e.get("jump_every", 5.0))
				timer[i] = float(e.get("volley", {}).get("every", 4.0)) * 0.5
				var land := pos[i] + dash_dir[i] * delta
				slams.append(land)
				var chain := phase_on[i] == 1 and e.has("chain_hops")   # Cóc Độc Bào Tử: leaps in a row
				var pl: Dictionary = e.get("rage_pool", e.get("pool", {})) if chain else e.get("pool", {})   # a poison pool where it lands
				if not pl.is_empty():
					add_pool(land, float(pl.get("time", 4.0)), float(pl.get("radius", 50.0)), float(pl.get("damage", 12.0)), chain)
				var third := true
				if chain:
					flee_t[i] += 1.0   # hops landed in this chain
					third = flee_t[i] >= float(e.get("chain_hops", 3))
					if not third:   # the next leap of the chain, a short crouch
						state[i] = WINDUP
						timer[i] = float(e.get("chain_windup", 0.3))
						dash_dir[i] = _target
						anim_t[i] = 0.0
					else:
						flee_t[i] = 0.0
						charge_cd[i] *= float(_phase2(i).get("cd_mul", 1.0))
						tongue_t[i] = -999.0   # the tongue comes between chains (MOVE starts it)
				if enraged(i) and e.has("shockwave") and third:   # phase 2: a ring runs out from the slam (the third leap)
					wave_pos.append(pos[i] + dash_dir[i] * delta)
					wave_r.append(k_radius[k])
					wave_max.append(float(e["shockwave"].get("max", 300.0)))
					wave_hit.append(0)
					wave_def.append(e["shockwave"])
				_slam_i = i
				slam_done.emit(pos[i] + dash_dir[i] * delta)
			return dash_dir[i]
		_:
			if phase_on[i] == 1 and e.has("tongue"):   # the tongue between chains: no leap while it aims and shoots
				if tongue_t[i] == -999.0:
					start_tongue(i)
				if tongue_t[i] != 0.0:
					return Vector2.ZERO
			charge_cd[i] -= delta
			if charge_cd[i] <= 0.0:
				state[i] = WINDUP
				timer[i] = float(e.get("rage_windup", 0.6)) if enraged(i) else float(e.get("windup", 0.9))
				dash_dir[i] = _target
				anim_t[i] = 0.0
				return Vector2.ZERO
			if phase_on[i] == 1 and e.has("tongue"):   # Cóc Độc Bào Tử: no spores in phase 2
				return dir * speed
			var vo: Dictionary = e.get("volley", {})
			if not vo.is_empty():   # spits a fan of slow bolts at the player
				timer[i] -= delta
				if timer[i] <= 0.0:
					timer[i] = float(vo.get("every", 4.0))
					var n := int(vo.get("count", 5))
					var spread := deg_to_rad(float(vo.get("spread_deg", 50.0)))
					var aim := (_player_center - center_of(i)).normalized()
					for b in n:
						fire_bolt(i, aim.rotated(spread * (float(b) / maxf(1.0, n - 1) - 0.5)))
	return dir * speed


## [param p] moved out of every standing root wall (a body of radius [param r]); unchanged when clear.
func push_out_walls(p: Vector2, r: float) -> Vector2:
	for w in wall_a.size():
		var d: Dictionary = wall_def[w]
		if wall_t[w] > float(d.get("time", 4.0)):
			continue   # still the warning
		var a := wall_a[w]
		var ab := wall_b[w] - a
		var t := clampf((p - a).dot(ab) / maxf(1.0, ab.length_squared()), 0.0, 1.0)
		var q := a + ab * t
		var need := float(d.get("thick", 14.0)) * 0.5 + r
		var off := p - q
		if off.length() < need:
			p = q + (off.normalized() if off.length() > 0.01 else ab.orthogonal().normalized()) * need
	return p


## Root walls: count down; the moment one rises it hurts a hero standing on it. Returns that damage.
func _step_walls(delta: float, player_center: Vector2) -> float:
	var hit := 0.0
	var w := 0
	while w < wall_a.size():
		var d: Dictionary = wall_def[w]
		var stand := float(d.get("time", 4.0))
		var before := wall_t[w]
		wall_t[w] -= delta
		if before > stand and wall_t[w] <= stand:   # rises now
			if push_out_walls(player_center, player_hit_radius) != player_center:
				hit = maxf(hit, float(d.get("damage", 20.0)))
		if wall_t[w] <= 0.0:
			wall_a.remove_at(w)
			wall_b.remove_at(w)
			wall_t.remove_at(w)
			wall_def.remove_at(w)
			continue
		w += 1
	return hit


## Starts boss [param i]'s tongue: windup s aiming at the hero (red flash), then it shoots.
func start_tongue(i: int) -> void:
	var tg: Dictionary = k_extra[kind[i]].get("tongue", {})
	tongue_t[i] = float(tg.get("windup", 1.0))
	tongue_len[i] = 0.0
	anim_t[i] = 0.0   # the mouth opens from the start
	tongue_dir[i] = (_player_center - center_of(i)).normalized() if _player_center != center_of(i) else Vector2.RIGHT
	if tongue_dir[i] == Vector2.ZERO:
		tongue_dir[i] = Vector2.RIGHT


## Tongues: aim (the aim follows nothing: it was set as the aim began), then shoot length px at speed;
## the tip touching the hero pulls the hero to the boss (tongue_pull) and stomps (returns its damage).
func _step_tongues(delta: float, player_center: Vector2) -> float:
	var hit := 0.0
	for i in count:
		if tongue_t[i] == 0.0 or tongue_t[i] == -999.0 or state[i] == DYING:
			continue
		var tg: Dictionary = k_extra[kind[i]].get("tongue", {})
		if tongue_t[i] > 0.0:
			tongue_t[i] = maxf(0.0, tongue_t[i] - delta)
			if tongue_t[i] <= 0.0:
				tongue_t[i] = -0.0001   # shooting
			continue
		tongue_t[i] -= delta
		var length := float(tg.get("length", 300.0))
		tongue_len[i] = minf(length, tongue_len[i] + float(tg.get("speed", 900.0)) * delta)
		var a := center_of(i)
		var b := a + tongue_dir[i] * tongue_len[i]
		var ab := b - a
		var t := clampf((player_center - a).dot(ab) / maxf(1.0, ab.length_squared()), 0.0, 1.0)
		if (a + ab * t).distance_to(player_center) <= float(tg.get("width", 10.0)) + player_hit_radius * 0.5:
			tongue_pull.append([a])
			hit = maxf(hit, float(tg.get("damage", 38.0)))
			slams.append(pos[i])
			tongue_t[i] = 0.0
			tongue_len[i] = 0.0
			continue
		if tongue_len[i] >= length:   # missed: it snaps back
			tongue_t[i] = 0.0
			tongue_len[i] = 0.0
	return hit


## The kind's "phase2" block (design/bosses.md "Chuyển pha"), {} when it has none.
func _phase2(i: int) -> Dictionary:
	return k_extra[kind[i]].get("phase2", {})


## Starts boss [param i]'s phase 2 once its hp reaches rage_at: transition s invulnerable and still,
## a push on the hero (phase_push), the announcement (raged), the body radius x radius_mul.
func _check_phase(i: int) -> void:
	if phase_on[i] == 1 or not enraged(i) or hp[i] <= 0.0:
		return
	phase_on[i] = 1
	raged.append(i)
	var p2 := _phase2(i)
	if p2.is_empty():
		return
	hp[i] = maxf(hp[i], 1.0)
	phase_t[i] = float(p2.get("transition", 1.5))
	phase_push.append([pos[i], float(p2.get("push", 160.0))])
	var ls: Dictionary = k_extra[kind[i]].get("leaf_storm", {})
	for n in int(ls.get("count", 0)):   # Bão lá rụng: the shed canopy flies out all round
		fire_bolt(i, Vector2.from_angle(TAU * n / float(ls["count"]) + phase[i]))
	k_radius[kind[i]] *= float(p2.get("radius_mul", 1.0))   # bosses are one of a kind
	anim_t[i] = 0.0


func in_transition(i: int) -> bool:
	return i >= 0 and i < count and phase_t[i] > 0.0


## The phase 2 name for the boss bar ("" before phase 2 or without one).
func phase_name(i: int) -> String:
	return String(_phase2(i).get("name", "")) if phase_on[i] == 1 else ""


## Contact damage of monster [param i] (phase 2 multiplies it).
func contact_damage(i: int) -> float:
	var d := k_damage[kind[i]]
	if buffed[i] == 1:   # the boss's aura
		d *= 1.0 + float(boss_aura.get("damage_mul", 0.0))
	if holy_t[i] > 0.0:   # Thánh ấn: blinded, it hits softer
		d *= float(status_defs.get("holy_mark", {}).get("contact_mul", 0.7))
	return d * float(_phase2(i).get("contact_mul", 1.0)) if phase_on[i] == 1 else d


## Boss [param i] is enraged: hp at or below its "rage_at" share (phase 2).
func enraged(i: int) -> bool:
	var e: Dictionary = k_extra[kind[i]]
	return e.has("rage_at") and hp[i] <= k_hp[kind[i]] * float(e["rage_at"])


## Index of the first living boss, or -1.
func boss_index() -> int:
	for i in count:
		if k_boss[kind[i]] == 1 and state[i] != DYING:
			return i
	return -1


## The dash lane of charger [param i] while it winds up, [from, to, width], when
## its kind has "telegraph" (Sói Rừng, design 6A); empty otherwise.
func charge_lane(i: int) -> Array:
	if i < 0 or i >= count or state[i] != WINDUP:
		return []
	var k := kind[i]
	var e: Dictionary = k_extra[k]
	if k_behaviour[k] != CHARGE or not bool(e.get("telegraph", false)):
		return []
	var from := center_of(i)
	var length := float(e.get("dash_speed", 300.0)) * float(e.get("dash_time", 0.35))
	return [from, from + dash_dir[i].normalized() * length, k_radius[k] * 2.0]


## Where a boss will land (WINDUP: the chosen spot; DASH: its course end) and the
## slam reach, for the run to draw the warning circle: [[pos, reach], ...].
func boss_telegraphs() -> Array:
	var out := []
	for i in count:
		if k_behaviour[kind[i]] != BOSS_SLIME or state[i] == DYING:
			continue
		var reach := k_radius[kind[i]] * float(k_extra[kind[i]].get("slam_reach", 2.5))
		if state[i] == WINDUP:
			out.append([dash_dir[i], reach])
		elif state[i] == DASH:
			out.append([pos[i] + dash_dir[i] * maxf(0.0, timer[i]), reach])
	return out


## Damages every living monster whose body overlaps [param hb] (a skill
## effect's SpriteHitbox, placed where the effect is drawn). Knockback pushes
## away from the hitbox centre. Returns how many were hit.
## How far a spatial-hash query around a hit box must reach so that every monster
## whose body touches it is returned: the box's own reach (a rect's half
## diagonal, a circle's radius; a rect reports radius 0) plus max_hit_r.
func _query_pad(hb: SpriteHitbox) -> float:
	var reach := hb.radius
	if hb.shape == "rect":
		reach = Vector2(hb.half_w, hb.half_h).length()
	return reach + max_hit_r


## [param once]: when given, monsters whose uid is in it are skipped and each one hit is added, so a
## moving effect (Sóng kiếm) hits every monster once however long it overlaps (cleave-wave-redesign.md).
func hit_box(hb: SpriteHitbox, damage: float, knockback := 140.0, source := "", effects: Array = [], once: Variant = null) -> int:
	_query.clear()
	_hash.query(hb.center, _query_pad(hb), _query)
	for j in range(_hashed_count, count):   # spawned since the hash was built
		_query.append(j)
	var hits := 0
	for i in _query:
		if i >= count or state[i] == DYING:
			continue
		var c := center_of(i)
		if not hb.contains(c, k_radius[kind[i]]):
			continue
		if once is Dictionary:
			if (once as Dictionary).has(uid[i]):
				continue
			(once as Dictionary)[uid[i]] = true
		hits += 1
		var d := c - hb.center
		var dmg := damage
		var crit := not source.begins_with("event.") and crit_chance > 0.0 and _crit_rng.randf() < crit_chance
		if crit:   # Chí mạng: direct hits only (damage over time and events never crit)
			dmg *= crit_mul
			crits_by[source] = int(crits_by.get(source, 0)) + 1
			if k_elite[kind[i]] == 1 or k_boss[kind[i]] == 1:
				crit_heavy += 1
		_crit_next = crit
		_damage(i, dmg, d.normalized() * knockback if d.length_squared() > 1.0 else Vector2.ZERO, source)
		for e: Dictionary in effects:
			apply_status(i, String(e.get("status", "")), e, damage, source)
	return hits


## True when a living monster's body overlaps [param hb] (no damage).
func overlaps(hb: SpriteHitbox) -> bool:
	for i in living_within(hb.center, _query_pad(hb)):
		if hb.contains(center_of(i), k_radius[kind[i]]):
			return true
	return false


## Arc area around [param center] (half angle in radians; PI = full circle).
## Convenience for tests and effects without a sprite.
func hit_arc(center: Vector2, facing: Vector2, radius: float, half_angle: float, damage: float,
		knockback := 140.0, source := "", effects: Array = []) -> int:
	var hb := SpriteHitbox.new()
	hb.shape = "arc" if half_angle < PI else "circle"
	hb.center = center
	hb.radius = radius
	hb.dir = facing.normalized()
	hb.half_angle = half_angle
	return hit_box(hb, damage, knockback, source, effects)


## Fraction of monster [param i]'s hp left, for its hp bar: of the hp it spawned with (hp_cap), which grows with the
## run's time (spawn_hp_mul), not of its kind's base hp.
func hp_frac(i: int) -> float:
	return clampf(hp[i] / maxf(1.0, hp_cap[i]), 0.0, 1.0)


## Damages every living monster within [param radius] of [param center].
func hit_circle(center: Vector2, radius: float, damage: float, knockback := 90.0, source := "", effects: Array = []) -> int:
	return hit_arc(center, Vector2.RIGHT, radius, PI, damage, knockback, source, effects)


func _damage(i: int, amount: float, kb: Vector2, source := "") -> void:
	if phase_t[i] > 0.0:   # phase 2 transition: invulnerable, it only flashes
		flash[i] = HURT_FLASH
		return
	if phase_on[i] == 1:
		amount *= float(_phase2(i).get("damage_taken_mul", 1.0))
	var hp_before := hp[i]
	calm_t[i] = 0.0
	if vs_status_mul > 0.0 and (slow_t[i] > 0.0 or stun_t[i] > 0.0 or freeze_t[i] > 0.0 or bleed_t[i] > 0.0 or burn_t[i] > 0.0 or shock_t[i] > 0.0):
		bonus_by["vs_status"] = float(bonus_by.get("vs_status", 0.0)) + amount * vs_status_mul   # end report: indirect damage
		amount *= 1.0 + vs_status_mul
	if far_mul > 0.0 and _hero_source(source) and pos[i].distance_to(hero_at) > far_px:   # Mắt ưng: a far hit
		bonus_by["far"] = float(bonus_by.get("far", 0.0)) + amount * far_mul
		amount *= 1.0 + far_mul
	amount *= float(_affix_def(i).get("damage_taken_mul", 1.0))   # Giáp
	var smul := species_mul(kind[i], String(element_of.get(source, "")))   # loài: weak / resisted element
	if shell_on[i] == 1:   # Côn trùng: the shell takes the first hit
		shell_on[i] = 0
		amount *= float(_species_of(kind[i]).get("shell", {}).get("first_hit_mul", 0.5))
	amount *= smul
	if corrode_n[i] > 0:   # Ăn mòn: each stack, more damage taken from every source
		amount *= 1.0 + float(status_defs.get("corrode", {}).get("per_stack", 0.08)) * corrode_n[i]
	damage_by[source] = float(damage_by.get(source, 0.0)) + minf(amount, maxf(0.0, hp[i]))
	hits_by[source] = int(hits_by.get(source, 0)) + 1
	hp[i] -= amount
	flash[i] = HURT_FLASH
	hp_show[i] = hp_bar_time
	hit_pos.append(center_of(i) - Vector2(0.0, k_radius[kind[i]]))
	hit_val.append(amount)
	hit_crit.append(1 if _crit_next else 0)
	hit_tag.append(1 if smul > 1.0 else (2 if smul < 1.0 else 0))
	hit_src.append(source)
	_crit_next = false
	if state[i] != DASH and k_boss[kind[i]] == 0 and not has_trait(kind[i], "rooted"):   # bosses / Thực vật hold their ground
		knock[i] += kb
	_split(i, hp_before)
	_check_phase(i)
	if hp[i] <= 0.0:
		state[i] = DYING
		timer[i] = 0.0
		anim_t[i] = 0.0
		total_kills += 1
		kills_by[source] = int(kills_by.get(source, 0)) + 1
		var mid := kind_ids[kind[i]].get_slice("@", 0)
		kills_kind[mid] = int(kills_kind.get(mid, 0)) + 1
		kill_elite.append(k_elite[kind[i]])
		_corrode_burst(i)
		kill_boss.append(k_boss[kind[i]])
		kill_pos.append(pos[i])
		kill_xp.append(k_xp[kind[i]])
		kill_gold.append(float(k_extra[kind[i]].get("gold_drop", 0)))
		kill_chest.append(1 if bool(k_extra[kind[i]].get("chest_drop", false)) else 0)
		var ad := _affix_def(i)
		if ad.has("split_count"):   # Phân thân: plain monsters of its kind pop out
			var base := kind_of(kind_ids[kind[i]].get_slice("@", 0))
			for s in int(ad["split_count"]):
				_split_q.append([base, pos[i] + Vector2(cos(s * 2.1), sin(s * 2.1)) * 14.0])
		var ex: Dictionary = ad.get("explode", k_extra[kind[i]].get("explode", {}))
		if not ex.is_empty():   # Bọ Lửa: its body bursts after a warning
			_add_blast(center_of(i), float(ex.get("delay", 0.8)), float(ex.get("radius", 60.0)),
				float(ex.get("damage", k_damage[kind[i]] * float(ex.get("damage_mul", 1.0)))), false)


## Puts status [param status] on monster [param i]. [param p] holds its numbers
## (statuses.json / a skill's on_hit): time, mul (slow speed), dps_mul (bleed /
## burn: x hit damage per second), chain / mul / radius (shock). Re-applying keeps
## the longer time and the stronger effect. Damage over time is credited to
## [param source].
func apply_status(i: int, status: String, p: Dictionary, hit_damage: float, source: String) -> void:
	if i < 0 or i >= count or state[i] == DYING:
		return
	if immune(kind[i], status):   # loài: e.g. Nhầy / Linh hồn never bleed (design/species.md)
		return
	var t := float(p.get("time", 1.0))
	match status:
		"slow":
			slow_t[i] = maxf(slow_t[i], t)
			slow_mul[i] = minf(slow_mul[i] if slow_t[i] > t else 1.0, float(p.get("mul", 0.5)))
		"stun":
			stun_t[i] = maxf(stun_t[i], t)
		"freeze":
			freeze_t[i] = maxf(freeze_t[i], t)
		"bleed":
			bleed_t[i] = maxf(bleed_t[i], t)
			bleed_dps[i] = maxf(bleed_dps[i], hit_damage * float(p.get("dps_mul", 0.2)))
			bleed_src[i] = source
		"holy_mark":
			holy_t[i] = maxf(holy_t[i], float(p.get("time", status_defs.get("holy_mark", {}).get("time", 2.5))))
			holy_dmg[i] = maxf(holy_dmg[i], hit_damage)
			holy_src[i] = source
		"corrode":
			var cd: Dictionary = status_defs.get("corrode", {})
			corrode_t[i] = float(p.get("time", cd.get("time", 3.0)))
			corrode_n[i] = mini(int(cd.get("max_stacks", 3)), corrode_n[i] + 1)
			corrode_src[i] = source
		"burn":
			if has_trait(kind[i], "wet"):   # Lưỡng cư: wet skin, the burn dies down sooner
				t *= float(_species_of(kind[i]).get("wet", {}).get("burn_time_mul", 0.5))
			burn_t[i] = maxf(burn_t[i], t)
			burn_dps[i] = maxf(burn_dps[i], hit_damage * float(p.get("dps_mul", 0.3)))
			burn_src[i] = source
		"shock":
			if p.has("chain"):   # item Lôi xích: arcs to the nearest ones
				_shock(i, hit_damage * float(p.get("mul", 0.5)), int(p.get("chain", 2)), float(p.get("radius", 90.0)), source)
			else:
				_shock_spread(i, hit_damage * minf(float(p.get("mul", 0.4)), SHOCK_SPREAD_MAX), source)
				shock_t[i] = maxf(shock_t[i], float(p.get("time", 3.0)))


## Status timers and damage over time for one living monster.
func _step_status(i: int, delta: float) -> void:
	_step_regen(i, delta)
	_step_light_dark(i, delta)
	slow_t[i] = maxf(0.0, slow_t[i] - delta)
	if slow_t[i] <= 0.0:
		slow_mul[i] = 1.0
	stun_t[i] = maxf(0.0, stun_t[i] - delta)
	freeze_t[i] = maxf(0.0, freeze_t[i] - delta)
	shock_t[i] = maxf(0.0, shock_t[i] - delta)
	if bleed_t[i] <= 0.0 and burn_t[i] <= 0.0:
		dot_wait[i] = DOT_TICK
		return
	dot_wait[i] -= delta
	if dot_wait[i] > 0.0:
		return
	dot_wait[i] += DOT_TICK
	if bleed_t[i] > 0.0:
		_damage(i, bleed_dps[i] * DOT_TICK, Vector2.ZERO, bleed_src[i])
	if burn_t[i] > 0.0 and state[i] != DYING:
		_damage(i, burn_dps[i] * DOT_TICK, Vector2.ZERO, burn_src[i])
	bleed_t[i] = maxf(0.0, bleed_t[i] - DOT_TICK)
	burn_t[i] = maxf(0.0, burn_t[i] - DOT_TICK)


## Spread damage never reaches half the hit (user 2026-11-18).
const SHOCK_SPREAD_MAX := 0.45


## A shock hit on monster [param i] arcs to every other living monster still
## carrying the shock mark, [param damage] each (design/gameplay-rules.md).
func _shock_spread(i: int, damage: float, source: String) -> void:
	var from := center_of(i)
	for j in count:
		if j != i and state[j] != DYING and shock_t[j] > 0.0:
			shock_lines.append(from)
			shock_lines.append(center_of(j))
			_damage(j, damage, Vector2.ZERO, source)


## Shock arcs from monster [param i] to the [param chain] nearest others within
## [param radius] for [param damage] each.
func _shock(i: int, damage: float, chain: int, radius: float, source: String) -> void:
	var from := center_of(i)
	var near := []
	for j in count:
		if j != i and state[j] != DYING:
			var d := center_of(j).distance_to(from)
			if d <= radius:
				near.append([d, j])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for k in mini(chain, near.size()):
		var j: int = near[k][1]
		shock_lines.append(from)
		shock_lines.append(center_of(j))
		_damage(j, damage, Vector2.ZERO, source)


## Status names on monster [param i] (for drawing): slow, stun, freeze, bleed, burn.
func statuses_of(i: int) -> Array[String]:
	var out: Array[String] = []
	if slow_t[i] > 0.0: out.append("slow")
	if stun_t[i] > 0.0: out.append("stun")
	if freeze_t[i] > 0.0: out.append("freeze")
	if bleed_t[i] > 0.0: out.append("bleed")
	if burn_t[i] > 0.0: out.append("burn")
	if shock_t[i] > 0.0: out.append("shock")
	if holy_t[i] > 0.0: out.append("holy_mark")
	if corrode_n[i] > 0: out.append("corrode")
	return out


## Index of the living monster whose body is nearest to [param p] within
## [param max_dist] (body edge), or -1.
func nearest(p: Vector2, max_dist: float) -> int:
	_query.clear()
	if is_inf(max_dist):   # unbounded: every monster
		for j in count:
			_query.append(j)
	else:
		_hash.query(p, max_dist + max_hit_r, _query)
		for j in range(_hashed_count, count):
			_query.append(j)
	var best := -1
	var best_d := INF
	for i in _query:
		if i >= count or state[i] == DYING:
			continue
		var d := center_of(i).distance_to(p) - k_radius[kind[i]]
		if d < best_d and d <= max_dist:
			best_d = d
			best = i
	return best


## The [param n] living monsters nearest to [param p] (body edge), closest first.
func nearest_n(p: Vector2, n: int) -> Array[int]:
	var all := []
	for i in count:
		if state[i] != DYING:
			all.append([center_of(i).distance_to(p) - k_radius[kind[i]], i])
	all.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out: Array[int] = []
	for k in mini(n, all.size()):
		out.append(int(all[k][1]))
	return out


## Clears the hit buffers (call after turning them into damage numbers).
## True for damage the hero deals (skills, cards), not the map's (events, poison pools).
static func _hero_source(source: String) -> bool:
	return source != "" and not source.begins_with("event.") and source != "pool"


func drain_hits() -> void:
	hit_pos.clear()
	hit_val.clear()
	hit_crit.clear()
	hit_tag.clear()
	hit_src.clear()
	crit_heavy = 0


## Clears the kill buffers (call after turning them into drops).
func drain_kills() -> void:
	kill_gold.clear()
	kill_chest.clear()
	kill_pos.clear()
	kill_xp.clear()
	kill_elite.clear()
	kill_boss.clear()


## A monster with split_at (fractions of its hp) spawns split_count split_into
## monsters around it each time a hit takes its hp across one of them.
func _split(i: int, hp_before: float) -> void:
	var e: Dictionary = k_extra[kind[i]]
	if not e.has("split_at"):
		return
	var full := k_hp[kind[i]]
	for f: Variant in e["split_at"]:
		var line := float(f) * full
		if hp_before > line and hp[i] <= line:
			split_done.emit(pos[i])
			var n := int(e.get("split_count", 4))
			for k in n:
				var a := TAU * k / n + phase[i]
				spawn(String(e.get("split_into", "slime")), pos[i] + Vector2(cos(a), sin(a)) * (k_radius[kind[i]] + 12.0))


## True while a marked (hunted) monster is alive.
func hunted_alive() -> bool:
	for i in count:
		if hunted[i] == 1 and state[i] != DYING:
			return true
	return false


## Every living monster starts dying (its death animation), without counting as a kill or dropping anything:
## the boss outro clears the field (user 2026-11-21).
func wipe() -> void:
	for i in count:
		if state[i] != DYING:
			state[i] = DYING
			timer[i] = 0.0
			anim_t[i] = 0.0


## Indices of living monsters whose centre is within [param radius] of [param p].
func living_within(p: Vector2, radius: float) -> Array[int]:
	var out: Array[int] = []
	var r2 := radius * radius
	for i in count:
		if state[i] != DYING and center_of(i).distance_squared_to(p) <= r2:
			out.append(i)
	return out


func living() -> int:
	var n := 0
	for i in count:
		if state[i] != DYING:
			n += 1
	return n


## Name of the animation monster [param i] plays now, and its local time.
## How high monster [param i] is drawn above its shadow, px (unscaled): a hop arc
## of hop_height while a hopper (or the toad boss) is in the air, else 0.
func hop_lift(i: int) -> float:
	if i < 0 or i >= count or state[i] != DASH:
		return 0.0
	var e: Dictionary = k_extra[kind[i]]
	if not e.has("hop_height"):
		return 0.0
	var ht := maxf(0.05, float(e.get("hop_time", e.get("jump_time", 0.5))))
	var t := 1.0 - clampf(timer[i] / ht, 0.0, 1.0)
	return float(e["hop_height"]) * sin(t * PI)


## The sheet monster [param i] is drawn with: its rage sheet (rage_sprite, a red body)
## while it is enraged (user 2026-11-19), else its own.
func sheet_of(i: int) -> SpriteSheet:
	var k := kind[i]
	if k_rage_sheet[k] != null and enraged(i):
		var tr := float(_phase2(i).get("transition", 0.0))
		if phase_t[i] > tr * 0.5 and not k_rage_sheet[k].has_animation("transform"):
			return k_sheet[k]   # no transform animation: the old body for the first half, it changes mid-flash
		return k_rage_sheet[k]
	return k_sheet[k]


func anim_of(i: int) -> Array:
	var sheet := k_sheet[kind[i]]
	if phase_t[i] > 0.0 and sheet_of(i).has_animation("transform"):   # the phase change, spread over the transition
		var tr := maxf(0.05, float(_phase2(i).get("transition", 1.5)))
		return ["transform", (1.0 - phase_t[i] / tr) * sheet_of(i).duration("transform") * 0.999]
	match state[i]:
		DYING:
			return ["death", timer[i]]
		WINDUP:   # a hopper crouches before it leaps (design/art/toads.md)
			if sheet.has_animation("crouch"):
				return ["crouch", anim_t[i]]
			if sheet.has_animation("attack"):
				return ["attack", anim_t[i]]
		DASH:   # in the air: the jump animation spread over the whole hop
			if sheet.has_animation("jump"):
				var ht := maxf(0.05, float(k_extra[kind[i]].get("hop_time", k_extra[kind[i]].get("jump_time", 0.5))))
				return ["jump", (1.0 - clampf(timer[i] / ht, 0.0, 1.0)) * sheet.duration("jump") * 0.999]
			if sheet.has_animation("attack"):
				return ["attack", anim_t[i]]
	if tongue_t[i] != 0.0 and tongue_t[i] != -999.0 and sheet.has_animation("attack"):   # mouth open for the tongue
		return ["attack", minf(anim_t[i], sheet.duration("attack") * 0.6)]
	if flash[i] > 0.0 and sheet.has_animation("hurt"):
		return ["hurt", HURT_FLASH - flash[i]]
	return ["move", anim_t[i]]


func _remove(i: int) -> void:
	var last := count - 1
	if i != last:
		pos[i] = pos[last]
		knock[i] = knock[last]
		dash_dir[i] = dash_dir[last]
		kind[i] = kind[last]
		state[i] = state[last]
		hp[i] = hp[last]
		timer[i] = timer[last]
		charge_cd[i] = charge_cd[last]
		flash[i] = flash[last]
		anim_t[i] = anim_t[last]
		phase[i] = phase[last]
		flip[i] = flip[last]
		hp_show[i] = hp_show[last]
		affix[i] = affix[last]
		uid[i] = uid[last]
		buffed[i] = buffed[last]
		hunted[i] = hunted[last]
		slow_t[i] = slow_t[last]
		slow_mul[i] = slow_mul[last]
		stun_t[i] = stun_t[last]
		freeze_t[i] = freeze_t[last]
		bleed_t[i] = bleed_t[last]
		bleed_dps[i] = bleed_dps[last]
		burn_t[i] = burn_t[last]
		shock_t[i] = shock_t[last]
		flee_t[i] = flee_t[last]
		phase_t[i] = phase_t[last]
		summon_t[i] = summon_t[last]
		tongue_t[i] = tongue_t[last]
		tongue_len[i] = tongue_len[last]
		tongue_dir[i] = tongue_dir[last]
		phase_on[i] = phase_on[last]
		burn_dps[i] = burn_dps[last]
		dot_wait[i] = dot_wait[last]
		bleed_src[i] = bleed_src[last]
		burn_src[i] = burn_src[last]
	count = last
