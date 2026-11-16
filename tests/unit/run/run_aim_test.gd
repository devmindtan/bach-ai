extends RefCounted
## Unit tests for the slash aim: it points at the target (4 directions),
## whatever way the hero walks.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_slash_points_at_target_side() -> void:
	_check(Run.slash_dir(Vector2(-50, 10)) == Vector2.LEFT, "target to the left -> slash left")
	_check(Run.slash_dir(Vector2(5, 80)) == Vector2.DOWN, "target below -> slash down")
	_check(Run.slash_dir(Vector2(3, -40)) == Vector2.UP, "target above -> slash up")


func test_slash_on_top_of_target_defaults_right() -> void:
	_check(Run.slash_dir(Vector2.ZERO) == Vector2.RIGHT, "zero vector -> right, never (0, 0)")
