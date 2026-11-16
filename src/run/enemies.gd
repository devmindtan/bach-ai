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
enum { CHASE, SWARM, CHARGE }

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

# per kind (index = kind id)
var kind_ids: Array[String] = []
var k_sheet: Array[SpriteSheet] = []
var k_behaviour := PackedInt32Array()
var k_hp := PackedFloat32Array()
var k_damage := PackedFloat32Array()
var k_speed := PackedFloat32Array()
var k_radius := PackedFloat32Array()
var k_xp := PackedFloat32Array()
var k_scale := PackedFloat32Array()
var k_center := PackedVector2Array()     # body centre relative to the anchor point (facing right)
var k_death_time := PackedFloat32Array()
var k_extra: Array[Dictionary] = []

# hits since the last drain_hits() (the run shows them as damage numbers)
var hit_pos := PackedVector2Array()
var hit_val := PackedFloat32Array()
var hp_bar_time := 2.0

# kills since the last drain_kills() (the run turns them into gems)
var kill_pos := PackedVector2Array()
var kill_xp := PackedFloat32Array()
var total_kills := 0

var spawn_ring := Vector2(760, 860)
var despawn_distance := 1300.0
var arena_half := 1400.0
var player_hit_radius := 14.0   # set by the run from the class sprite's body

var _hash: SpatialHash
var _hashed_count := 0
var _push := 60.0
var _query := PackedInt32Array()
var _rng := RandomNumberGenerator.new()
var _time := 0.0


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
	hp_bar_time = float(cfg.get("ui", {}).get("hp_bar_time", 2.0))
	var behaviours := {"chase": CHASE, "swarm": SWARM, "charge": CHARGE}
	var world_scale := float(world.get("sprite_scale", 2))
	for id: String in monsters:
		if id.begins_with("_"):
			continue
		var m: Dictionary = monsters[id]
		var sheet: SpriteSheet = sheets.get(String(m.get("sprite", id)))
		kind_ids.append(id)
		k_sheet.append(sheet)
		k_behaviour.append(behaviours.get(String(m.get("behaviour", "chase")), CHASE))
		k_hp.append(float(m.get("hp", 10.0)))
		k_damage.append(float(m.get("damage", 5.0)))
		k_speed.append(float(m.get("speed", 50.0)))
		k_xp.append(float(m.get("xp", 1.0)))
		var sc := float(m.get("scale", world_scale))
		k_scale.append(sc)
		# body circle measured from the sprite's pixels (json "body"), never typed in data
		var body := SpriteHitbox.body(sheet, Vector2.ZERO, sc)
		if body == null:
			push_error("Enemies: sprite of %s has no body circle; regenerate it in Sprite Lab" % id)
			body = SpriteHitbox.new()
			body.radius = 8.0 * sc
		k_radius.append(body.radius)
		k_center.append(body.center)
		k_death_time.append(sheet.duration("death") if sheet != null and sheet.has_animation("death") else 0.4)
		k_extra.append(m)


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
	# 1. timers, and remove monsters whose death animation is over. Removal
	#    swap-moves the last slot, so it must happen before the hash is built.
	var i := 0
	while i < count:
		anim_t[i] += delta
		flash[i] = maxf(0.0, flash[i] - delta)
		hp_show[i] = maxf(0.0, hp_show[i] - delta)
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
		var vel := _velocity(n, k, dir, dist, delta)
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
		if (center_of(n) - player_center).length() < r + player_hit_radius:
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
		_:
			return dir * speed


## Damages every living monster whose body overlaps [param hb] (a skill
## effect's SpriteHitbox, placed where the effect is drawn). Knockback pushes
## away from the hitbox centre. Returns how many were hit.
func hit_box(hb: SpriteHitbox, damage: float, knockback := 140.0) -> int:
	_query.clear()
	_hash.query(hb.center, hb.radius + 32.0, _query)
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
		_damage(i, damage, d.normalized() * knockback if d.length_squared() > 1.0 else Vector2.ZERO)
	return hits


## Arc area around [param center] (half angle in radians; PI = full circle).
## Convenience for tests and effects without a sprite.
func hit_arc(center: Vector2, facing: Vector2, radius: float, half_angle: float, damage: float,
		knockback := 140.0) -> int:
	var hb := SpriteHitbox.new()
	hb.shape = "arc" if half_angle < PI else "circle"
	hb.center = center
	hb.radius = radius
	hb.dir = facing.normalized()
	hb.half_angle = half_angle
	return hit_box(hb, damage, knockback)


## Damages every living monster within [param radius] of [param center].
func hit_circle(center: Vector2, radius: float, damage: float, knockback := 90.0) -> int:
	return hit_arc(center, Vector2.RIGHT, radius, PI, damage, knockback)


func _damage(i: int, amount: float, kb: Vector2) -> void:
	hp[i] -= amount
	flash[i] = HURT_FLASH
	hp_show[i] = hp_bar_time
	hit_pos.append(center_of(i) - Vector2(0.0, k_radius[kind[i]]))
	hit_val.append(amount)
	if state[i] != DASH:
		knock[i] += kb
	if hp[i] <= 0.0:
		state[i] = DYING
		timer[i] = 0.0
		anim_t[i] = 0.0
		total_kills += 1
		kill_pos.append(pos[i])
		kill_xp.append(k_xp[kind[i]])


## Index of the living monster whose body is nearest to [param p] within
## [param max_dist] (body edge), or -1.
func nearest(p: Vector2, max_dist: float) -> int:
	_query.clear()
	if is_inf(max_dist):   # unbounded: every monster
		for j in count:
			_query.append(j)
	else:
		_hash.query(p, max_dist + 32.0, _query)
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


## Clears the hit buffers (call after turning them into damage numbers).
func drain_hits() -> void:
	hit_pos.clear()
	hit_val.clear()


## Clears the kill buffers (call after turning them into drops).
func drain_kills() -> void:
	kill_pos.clear()
	kill_xp.clear()


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
	count = last
