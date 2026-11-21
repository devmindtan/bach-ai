extends RefCounted
## Review 2026-11-21: the arena floor was redrawn every frame (~7 ms). GroundLayer rebuilds it only when the
## camera crosses a 64 px tile.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_floor_redraws_only_when_the_camera_crosses_a_tile() -> void:
	var g := GroundLayer.new()
	g.setup(1400.0, {})
	var size := Vector2(1280, 720)
	_check(g.follow(Vector2(0, 0), size), "first frame draws the floor")
	for k in 30:   # moving 1 px a frame inside the same tile
		g.follow(Vector2(1 + k, 0), size)
	_check(g.redraws == 1, "30 small moves inside one tile: no redraw, got %d" % g.redraws)
	g.follow(Vector2(70, 0), size)
	_check(g.redraws == 2, "crossing a tile redraws once, got %d" % g.redraws)
	g.free()
