extends RefCounted
## User 2026-11-21: killing the boss ended the run at once. A boss stage now plays an outro first (field
## cleared, slow motion, victory call), and the stage is won when it is over.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_boss_death_starts_an_outro_before_the_win() -> void:
	var r: Node = Run.new()
	r.cfg = GameData.load_json("res://assets/data/run_config.json")
	var monsters := {"blob": {"sprite": "blob", "behaviour": "chase", "hp": 10.0, "damage": 1.0, "speed": 0.0, "xp": 1.0, "scale": 2}}
	var blob := SpriteSheet.from_meta("blob", {"frames": 1, "frame_size": [24, 24], "fps": 8.0, "anchor": [12.0, 12.0],
		"body": {"anim": "default", "center": [12.0, 12.0], "radius": 6.0}})
	r.enemies = Enemies.new(monsters, {"max_enemies": 4, "separation": {"push": 0.0}}, {"blob": blob}, 1)
	r.enemies.spawn("blob", Vector2(100, 0))
	r.boss_stage = true
	r._boss_dead = true
	r._start_boss_outro()
	_check(r.outro_left() > 2.0, "the outro lasts about 3 s, got %s" % r.outro_left())
	_check(r.enemies.living() == 0, "the field is cleared (monsters play their death)")
	_check(String(r.wave_call).begins_with("Chiến thắng!"), "a victory call, got '%s'" % r.wave_call)
	r.enemies = null
	r.free()
