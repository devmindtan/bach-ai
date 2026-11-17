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
enum { CHASE, SWARM, CHARGE, BOSS_SLIME }

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
var burn_dps := PackedFloat32Array()
var dot_wait := PackedFloat32Array()   # time to the next damage-over-time tick
var bleed_src := PackedStringArray()
var burn_src := PackedStringArray()
const DOT_TICK := 0.5
## Shock arcs since the last drain (pairs of points, for the run to draw).
var shock_lines := PackedVector2Array()

# per kind (index = kind id)
var kind_ids: Array[String] = []
var k_sheet: Array[SpriteSheet] = []
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

# hits since the last drain_hits() (the run shows them as damage numbers)
var hit_pos := PackedVector2Array()
var hit_val := PackedFloat32Array()
var hp_bar_time := 2.0

# kills since the last drain_kills() (the run turns them into gems)
var kill_pos := PackedVector2Array()
var kill_xp := PackedFloat32Array()
var kill_elite := PackedByteArray()   # 1 = the kill was an elite (drops a chest)
var kill_boss := PackedByteArray()
## Boss landings since the last drain (positions, for the run to draw the dust).
var slams := PackedVector2Array()
var total_kills := 0
## Per damage source (skill id, "" when unnamed), for the end-of-run table:
## damage actually dealt (overkill not counted), hits, kills.
var damage_by := {}
var hits_by := {}
var kills_by := {}

var spawn_ring := Vector2(760, 860)
var despawn_distance := 1300.0
var arena_half := 1400.0
var player_hit_radius := 14.0
var vs_status_mul := 0.0        # class passive: extra damage taken by monsters with a status   # set by the run from the class sprite's body

var _hash: SpatialHash
var _hashed_count := 0
var _push := 60.0
var _query := PackedInt32Array()
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _target := Vector2.ZERO   # the player position this step (boss jump targets)
var _slam_i := -1


func _init(monsters: Dictionary, cfg: Dictionary, sheets: Dictionary, seed_value := 0) -> void:
	_rng.seed = seed_value
	var world: Dictionary = cfg.get("world", {})
	var ring: Array = world.get("spawn_ring", [760.0, 860.0])
	spawn_ring = Vector2(float(ring[0]), float(ring[1]))
	despawn_distance = float(world.get("despawn_distance", 1300.0))
	arena_half = float(world.get("arena_half", 1400.0))
	var sep: Dictionary = cfg.get("separation", {})
	_hash = SpatialHash.new(float(sep.get("cell", 48.0)))
	_push = float(sep.get("push", 60.0))
	capacity = int(cfg.get("max_enemies", 600))
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
	anim_t.resize(capacity)
	phase.resize(capacity)
	flip.resize(capacity)
	hp_show.resize(capacity)
	for a: Variant in [slow_t, slow_mul, stun_t, freeze_t, bleed_t, bleed_dps, burn_t, burn_dps, dot_wait]:
		a.resize(capacity)
	bleed_src.resize(capacity)
	burn_src.resize(capacity)
	hp_bar_time = float(cfg.get("ui", {}).get("hp_bar_time", 2.0))
	var world_scale := float(world.get("sprite_scale", 2))
	var elite: Dictionary = cfg.get("elite", {})
	for id: String in monsters:
		if id.begins_with("_"):
			continue
		var m: Dictionary = monsters[id]
		_register(id, m, sheets.get(String(m.get("sprite", id))), world_scale, {})
		# every monster also has an elite kind, spawned by waves as "<id>@elite"
		if not elite.is_empty() and not bool(m.get("boss", false)):
			_register(id + "@elite", m, sheets.get(String(m.get("sprite", id))), world_scale, elite)


const BEHAVIOURS := {"chase": CHASE, "swarm": SWARM, "charge": CHARGE, "boss_slime": BOSS_SLIME}


## One monster kind; [param elite] = multipliers (hp_mul, damage_mul, scale_mul,
## xp_mul), empty for a normal kind.
func _register(id: String, m: Dictionary, sheet: SpriteSheet, world_scale: float, elite: Dictionary) -> void:
	var is_elite := not elite.is_empty()
	kind_ids.append(id)
	k_sheet.append(sheet)
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
	k_elite.append(1 if is_elite else 0)
	k_boss.append(1 if bool(m.get("boss", false)) else 0)


## Kind index of a monster id, or -1.
func kind_of(id: String) -> int:
	return kind_ids.find(id)


## Adds one monster at [param p]; returns false when the run is at max_enemies.
func spawn(id: String, p: Vector2) -> bool:
	var k := kind_of(id)
	if k < 0 or count >= capacity:
		return false
	var i := count
	count += 1
	pos[i] = p
	knock[i] = Vector2.ZERO
	dash_dir[i] = Vector2.ZERO
	kind[i] = k
	state[i] = MOVE
	hp[i] = k_hp[k]
	timer[i] = 0.0
	charge_cd[i] = float(k_extra[k].get("charge_cooldown", 2.0)) * _rng.randf()
	flash[i] = 0.0
	anim_t[i] = _rng.randf() * 2.0
	phase[i] = _rng.randf() * TAU
	flip[i] = 0
	hp_show[i] = 0.0
	slow_t[i] = 0.0
	slow_mul[i] = 1.0
	stun_t[i] = 0.0
	freeze_t[i] = 0.0
	bleed_t[i] = 0.0
	bleed_dps[i] = 0.0
	burn_t[i] = 0.0
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
	_time += delta
	_target = player_pos
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
		var stopped := stun_t[n] > 0.0 or freeze_t[n] > 0.0
		_slam_i = -1
		var vel := Vector2.ZERO if stopped else _velocity(n, k, dir, dist, delta) * (slow_mul[n] if slow_t[n] > 0.0 else 1.0)
		if _slam_i == n:   # a boss landed: its slam hits a player within reach
			var reach := k_radius[k] * float(k_extra[k].get("slam_reach", 2.5))
			if (pos[n] + vel * delta).distance_to(player_center) < reach + player_hit_radius:
				contact = maxf(contact, float(k_extra[k].get("slam_damage", k_damage[k])))
		# separation: push away from overlapping neighbours (same cell block)
		var r := k_radius[k]
		_query.clear()
		_hash.query(pos[n], r * 2.0, _query)
		var push := Vector2.ZERO
		for j in _query:
			if j == n:
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
		vel += push * _push
		knock[n] = knock[n] * maxf(0.0, 1.0 - KNOCKBACK_DECAY * delta)
		pos[n] += (vel + knock[n]) * delta
		pos[n] = pos[n].clamp(Vector2(-arena_half, -arena_half), Vector2(arena_half, arena_half))
		if not stopped and (center_of(n) - player_center).length() < r + player_hit_radius:
			contact = maxf(contact, k_damage[k])
	return contact


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
				charge_cd[i] = float(e.get("jump_every", 5.0))
				slams.append(pos[i] + dash_dir[i] * delta)
				_slam_i = i
			return dash_dir[i]
		_:
			charge_cd[i] -= delta
			if charge_cd[i] <= 0.0:
				state[i] = WINDUP
				timer[i] = float(e.get("windup", 0.9))
				dash_dir[i] = _target
				anim_t[i] = 0.0
				return Vector2.ZERO
	return dir * speed


## Index of the first living boss, or -1.
func boss_index() -> int:
	for i in count:
		if k_boss[kind[i]] == 1 and state[i] != DYING:
			return i
	return -1


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


func hit_box(hb: SpriteHitbox, damage: float, knockback := 140.0, source := "", effects: Array = []) -> int:
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
		hits += 1
		var d := c - hb.center
		_damage(i, damage, d.normalized() * knockback if d.length_squared() > 1.0 else Vector2.ZERO, source)
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


## Damages every living monster within [param radius] of [param center].
func hit_circle(center: Vector2, radius: float, damage: float, knockback := 90.0, source := "", effects: Array = []) -> int:
	return hit_arc(center, Vector2.RIGHT, radius, PI, damage, knockback, source, effects)


func _damage(i: int, amount: float, kb: Vector2, source := "") -> void:
	var hp_before := hp[i]
	if vs_status_mul > 0.0 and (slow_t[i] > 0.0 or stun_t[i] > 0.0 or freeze_t[i] > 0.0 or bleed_t[i] > 0.0 or burn_t[i] > 0.0):
		amount *= 1.0 + vs_status_mul
	damage_by[source] = float(damage_by.get(source, 0.0)) + minf(amount, maxf(0.0, hp[i]))
	hits_by[source] = int(hits_by.get(source, 0)) + 1
	hp[i] -= amount
	flash[i] = HURT_FLASH
	hp_show[i] = hp_bar_time
	hit_pos.append(center_of(i) - Vector2(0.0, k_radius[kind[i]]))
	hit_val.append(amount)
	if state[i] != DASH and k_boss[kind[i]] == 0:   # bosses are not knocked back
		knock[i] += kb
	_split(i, hp_before)
	if hp[i] <= 0.0:
		state[i] = DYING
		timer[i] = 0.0
		anim_t[i] = 0.0
		total_kills += 1
		kills_by[source] = int(kills_by.get(source, 0)) + 1
		kill_elite.append(k_elite[kind[i]])
		kill_boss.append(k_boss[kind[i]])
		kill_pos.append(pos[i])
		kill_xp.append(k_xp[kind[i]])


## Puts status [param status] on monster [param i]. [param p] holds its numbers
## (statuses.json / a skill's on_hit): time, mul (slow speed), dps_mul (bleed /
## burn: x hit damage per second), chain / mul / radius (shock). Re-applying keeps
## the longer time and the stronger effect. Damage over time is credited to
## [param source].
func apply_status(i: int, status: String, p: Dictionary, hit_damage: float, source: String) -> void:
	if i < 0 or i >= count or state[i] == DYING:
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
		"burn":
			burn_t[i] = maxf(burn_t[i], t)
			burn_dps[i] = maxf(burn_dps[i], hit_damage * float(p.get("dps_mul", 0.3)))
			burn_src[i] = source
		"shock":
			_shock(i, hit_damage * float(p.get("mul", 0.5)), int(p.get("chain", 2)), float(p.get("radius", 90.0)), source)


## Status timers and damage over time for one living monster.
func _step_status(i: int, delta: float) -> void:
	slow_t[i] = maxf(0.0, slow_t[i] - delta)
	if slow_t[i] <= 0.0:
		slow_mul[i] = 1.0
	stun_t[i] = maxf(0.0, stun_t[i] - delta)
	freeze_t[i] = maxf(0.0, freeze_t[i] - delta)
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
func drain_hits() -> void:
	hit_pos.clear()
	hit_val.clear()


## Clears the kill buffers (call after turning them into drops).
func drain_kills() -> void:
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
			var n := int(e.get("split_count", 4))
			for k in n:
				var a := TAU * k / n + phase[i]
				spawn(String(e.get("split_into", "slime")), pos[i] + Vector2(cos(a), sin(a)) * (k_radius[kind[i]] + 12.0))


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
func anim_of(i: int) -> Array:
	var sheet := k_sheet[kind[i]]
	match state[i]:
		DYING:
			return ["death", timer[i]]
		WINDUP, DASH:
			if sheet.has_animation("attack"):
				return ["attack", anim_t[i]]
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
		slow_t[i] = slow_t[last]
		slow_mul[i] = slow_mul[last]
		stun_t[i] = stun_t[last]
		freeze_t[i] = freeze_t[last]
		bleed_t[i] = bleed_t[last]
		bleed_dps[i] = bleed_dps[last]
		burn_t[i] = burn_t[last]
		burn_dps[i] = burn_dps[last]
		dot_wait[i] = dot_wait[last]
		bleed_src[i] = bleed_src[last]
		burn_src[i] = burn_src[last]
	count = last
