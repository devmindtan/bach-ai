extends RefCounted
## Unit test: a projectile uses the flight animation closest to its direction
## (fly_000..fly_337 from Sprite Lab lib/dirs16.py), else the 4-direction one.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_nearest_angle_animation_is_used() -> void:
	var r: Node = Run.new()
	r.sheets["x"] = SpriteSheet.from_meta("x", {"frames": 4, "frame_size": [8, 8], "fps": 8.0, "anchor": [4.0, 4.0],
		"animations": [{"name": "fly_000", "start": 0, "frames": 1}, {"name": "fly_090", "start": 1, "frames": 1},
			{"name": "fly_180", "start": 2, "frames": 1}, {"name": "fly_270", "start": 3, "frames": 1}]})
	_check(r._fly_anim("x", "fly_", Vector2(0.2, 1.0)) == "fly_090", "mostly down -> fly_090")
	_check(r._fly_anim("x", "fly_", Vector2(1.0, -0.1)) == "fly_000", "right, a little up -> fly_000 (wraps at 360)")
	r.sheets["y"] = SpriteSheet.from_meta("y", {"frames": 1, "frame_size": [8, 8], "fps": 8.0, "anchor": [4.0, 4.0],
		"animations": [{"name": "fly_left", "start": 0, "frames": 1}]})
	_check(r._fly_anim("y", "fly_", Vector2(-1.0, 0.1)) == "fly_left", "no angle animations -> 4-direction name")
	r.free()
