extends RefCounted
## Unit tests for the hero's view choice (down / up / side) from a direction.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_vertical_directions_use_front_and_back() -> void:
	_check(Run._view(Vector2.DOWN) == "down", "down -> front view")
	_check(Run._view(Vector2.UP) == "up", "up -> back view")


func test_horizontal_and_diagonal_use_side() -> void:
	_check(Run._view(Vector2.LEFT) == "side", "left -> side")
	_check(Run._view(Vector2(1, 1).normalized()) == "side", "diagonal -> side")
	_check(Run._view(Vector2(0.3, 1).normalized()) == "down", "mostly down -> front")
