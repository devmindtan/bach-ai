extends RefCounted
## Unit tests for Buffs: random timed spawns near the player, pick-up, timers,
## expiry on the ground, and the pseudo-upgrades fed to PlayerStats.

var failures: Array[String] = []

const DEFS := {
	"power": {"name": "Ngọc sức mạnh", "duration": 8.0, "effects": {"damage": {"mul": 0.5}}},
	"shield": {"name": "Khiên từ", "duration": 6.0, "effects": {"magnet": {"mul": 3.0}}, "invulnerable": true},
}
const CFG := {"first_after": 5.0, "spawn_every": [10.0, 10.0], "spawn_ring": [100.0, 100.0],
	"lifetime": 20.0, "blink": 4.0, "max_on_field": 2, "collect_radius": 20.0}


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _step(b: Buffs, seconds: float, player := Vector2.ZERO) -> Array:
	var got := []
	var t := 0.0
	while t < seconds - 0.0001:
		got.append_array(b.step(0.1, player))
		t += 0.1
	return got


func test_first_buff_spawns_after_first_after_on_the_ring() -> void:
	var b := Buffs.new(DEFS, CFG, 7)
	_step(b, 4.9, Vector2(1000, 1000))
	_check(b.ground.is_empty(), "nothing before 5 s")
	_step(b, 0.2, Vector2(1000, 1000))
	_check(b.ground.size() == 1, "one buff at 5 s, got %d" % b.ground.size())
	var d := (b.ground[0]["pos"] as Vector2).distance_to(Vector2(1000, 1000))
	_check(absf(d - 100.0) < 0.5, "spawned on the 100 px ring, got %.1f" % d)


func test_walking_onto_a_buff_activates_it_and_it_runs_out() -> void:
	var b := Buffs.new(DEFS, CFG, 7)
	b.ground.append({"id": "power", "pos": Vector2(10, 0), "age": 0.0})
	var got := b.step(0.1, Vector2.ZERO)
	_check(got == ["power"] and b.ground.is_empty(), "picked up within 20 px, got %s" % [got])
	_check(b.is_active("power"), "power active")
	_step(b, 7.8)
	_check(b.is_active("power"), "still active before 8 s")
	_step(b, 0.3)
	_check(not b.is_active("power"), "gone after 8 s")


func test_buff_left_on_the_ground_disappears_after_lifetime() -> void:
	var b := Buffs.new(DEFS, {"first_after": 999.0, "spawn_every": [999.0, 999.0], "lifetime": 20.0}, 1)
	b.ground.append({"id": "shield", "pos": Vector2(500, 0), "age": 0.0})
	_step(b, 19.9)
	_check(b.ground.size() == 1, "still there at 19.9 s")
	_step(b, 0.3)
	_check(b.ground.is_empty(), "gone after 20 s")


func test_active_buffs_become_level_one_upgrades() -> void:
	var b := Buffs.new(DEFS, CFG, 1)
	b.activate("shield")
	_check(b.invulnerable(), "shield makes the hero invulnerable")
	var up: Array = b.as_upgrades()
	_check(up.size() == 1 and up[0]["id"] == "shield" and up[0]["effects"].has("magnet"), "one pseudo upgrade, got %s" % [up])
	_check(b.levels() == {"shield": 1}, "level 1 while active")
	var s := PlayerStats.compute({"magnet": 1.0}, up, b.levels())
	_check(is_equal_approx(float(s["magnet"]), 4.0), "magnet x4 with the shield, got %s" % s["magnet"])


# Regression (user 2026-11-20 "hitbox ăn các buff có vấn đề"): pick-up compared centre to centre with a
# fixed 22 px, ignoring the hero's body radius, so a buff whose 36 px badge visibly overlapped the hero
# was not taken. The circles touching (hero body radius + collect_radius) must pick it up.
func test_buff_touching_the_hero_body_is_picked_up() -> void:
	var b := Buffs.new(DEFS, CFG, 7)
	b.ground.append({"id": "power", "pos": Vector2(30, 0), "age": 0.0})   # body 14 + badge 20 > 30
	var got := b.step(0.1, Vector2.ZERO, 14.0)
	_check(got.has("power"), "badge overlapping the hero body is taken, got %s" % [got])
	b.ground.append({"id": "shield", "pos": Vector2(40, 0), "age": 0.0})   # 14 + 20 < 40: not touching
	_check(b.step(0.1, Vector2.ZERO, 14.0).is_empty(), "a buff beyond touch stays on the ground")
