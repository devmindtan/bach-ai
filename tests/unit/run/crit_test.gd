extends RefCounted
## Chí mạng (6C.2, design/gameplay-rules.md): a direct hit crits with crit_chance for crit_mul damage and
## is flagged so its number draws as a crit; damage over time never crits; screen shake decays to rest.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _enemies() -> Enemies:
	var monsters := {
		"blob": {"sprite": "blob", "behaviour": "chase", "hp": 18.0, "damage": 8.0, "speed": 40.0, "xp": 2.0, "scale": 2},
	}
	var cfg := {"world": {"spawn_ring": [700.0, 800.0], "despawn_distance": 1300.0, "arena_half": 1400.0},
		"separation": {"cell": 48.0, "push": 60.0}, "max_enemies": 50}
	# body centred on the anchor, radius 6.5 px x scale 2 = 13
	var blob := SpriteSheet.from_meta("blob", {"frames": 1, "frame_size": [24, 24], "fps": 8.0, "anchor": [12.0, 12.0],
		"body": {"anim": "default", "center": [12.0, 12.0], "radius": 6.5}})
	var e := Enemies.new(monsters, cfg, {"blob": blob}, 1)
	e.player_hit_radius = 14.0
	return e


func _settle(e: Enemies) -> void:
	# one tiny step builds the spatial hash without moving anything noticeably
	e.step(0.0001, Vector2(0, 300), Vector2(0, 300))


func test_a_sure_crit_multiplies_the_hit_and_flags_it() -> void:
	var e := _enemies()
	e.crit_chance = 1.0
	e.crit_mul = 2.0
	e.spawn("blob", Vector2(30, 0))
	_settle(e)
	e.hit_circle(Vector2.ZERO, 60.0, 5.0, 0.0, "blade_arc")
	_check(e.hit_val.size() == 1 and is_equal_approx(e.hit_val[0], 10.0), "5 x 2 = 10, got %s" % [e.hit_val])
	_check(e.hit_crit.size() == 1 and e.hit_crit[0] == 1, "the hit is flagged a crit")
	_check(e.crits_by.get("blade_arc", 0) == 1, "crits counted by source")


func test_no_crit_chance_no_crit() -> void:
	var e := _enemies()
	e.crit_chance = 0.0
	e.spawn("blob", Vector2(30, 0))
	_settle(e)
	e.hit_circle(Vector2.ZERO, 60.0, 5.0)
	_check(is_equal_approx(e.hit_val[0], 5.0) and e.hit_crit[0] == 0, "plain hit")


func test_event_damage_never_crits() -> void:
	var e := _enemies()
	e.crit_chance = 1.0
	e.crit_mul = 2.0
	e.spawn("blob", Vector2(30, 0))
	_settle(e)
	e.hit_circle(Vector2.ZERO, 60.0, 5.0, 0.0, Tornado.SOURCE)
	_check(is_equal_approx(e.hit_val[0], 5.0), "an event's hit is not a crit")


func test_shake_decays_to_rest() -> void:
	var s := ScreenShake.new()
	s.add(6.0)
	var first := s.step(0.016, 1).length()
	for k in 60:
		s.step(0.016, k)
	_check(first > 0.0 and s.step(0.016, 99) == Vector2.ZERO, "shakes, then rests after a second")
	s.enabled = false
	s.add(6.0)
	_check(s.step(0.016, 3) == Vector2.ZERO, "off in the settings: no shake")


func test_crit_rolls_do_not_shift_the_spawn_stream() -> void:
	# regression: crits drew from the spawn RNG, so a run with crits spawned elsewhere than one without
	var a := _enemies()
	var b := _enemies()
	b.crit_chance = 0.5
	a.spawn("blob", Vector2(30, 0))
	b.spawn("blob", Vector2(30, 0))
	_settle(a)
	_settle(b)
	for k in 10:
		b.hit_circle(Vector2.ZERO, 60.0, 0.1)
		a.hit_circle(Vector2.ZERO, 60.0, 0.1)
	_check(a.ring_point(Vector2.ZERO) == b.ring_point(Vector2.ZERO), "the next spawn point is the same with or without crit rolls")


## design/rogue-kits.md, Liên hoàn: each hero hit within combo_window s adds a stack (max combo_max); a full stack
## makes the next hit a sure crit and starts over; a pause longer than the window drops the stacks.
func test_combo_stacks_to_a_sure_crit_and_drops_after_a_pause() -> void:
	var e := _enemies()
	e.crit_chance = 0.0
	e.combo_per = 0.03
	e.combo_max = 3
	e.combo_window = 2.0
	e.spawn("blob", Vector2(30, 0))
	e.hp[0] = 9999.0
	_settle(e)
	for k in 3:
		e.hit_circle(Vector2.ZERO, 60.0, 1.0, 0.0, "throw_knife")
	_check(e.combo == 3, "three hits, three stacks, got %d" % e.combo)
	e.drain_hits()
	e.hit_circle(Vector2.ZERO, 60.0, 1.0, 0.0, "throw_knife")
	_check(e.hit_crit.size() == 1 and e.hit_crit[0] == 1, "the hit after a full stack is a crit")
	_check(e.combo == 0, "and the chain starts over, got %d" % e.combo)
	e.hit_circle(Vector2.ZERO, 60.0, 1.0, 0.0, "throw_knife")
	e.step(2.5, Vector2(0, 300), Vector2(0, 300))
	_check(e.combo == 0, "a 2.5 s pause drops the stacks, got %d" % e.combo)
