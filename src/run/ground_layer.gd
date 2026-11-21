class_name GroundLayer
extends Node2D
## The arena floor as its own canvas item, drawn behind the run (show_behind_parent). RunGround.draw issues
## 1-2k draw_rect calls; redrawing them every frame cost ~7 ms at 1280x720 (bench 2026-11-21). This layer
## redraws only when the camera crosses a tile, over the view grown by MARGIN tiles, and Godot reuses the
## recorded commands in between.
##
## Example (in Run._ready / _process):
##   _ground = GroundLayer.new(); _ground.setup(arena_half, stage_ground); add_child(_ground)
##   _ground.follow(_camera.position, get_viewport_rect().size)

const MARGIN := 2   # tiles drawn beyond the view on every side

var arena_half := 1400.0
var palette: Dictionary = {}
var redraws := 0                 # how many times the floor was rebuilt (tests, debug overlay)
var _cell := Vector2i(1 << 30, 0)
var _view := Rect2()


func setup(p_arena_half: float, p_palette: Dictionary) -> void:
	arena_half = p_arena_half
	palette = p_palette
	show_behind_parent = true
	_cell = Vector2i(1 << 30, 0)


## Rebuilds the floor only when the view's top-left tile changes; returns true when it did.
func follow(camera_pos: Vector2, view_size: Vector2) -> bool:
	var top_left := camera_pos - view_size * 0.5
	var cell := Vector2i(floori(top_left.x / RunGround.TILE), floori(top_left.y / RunGround.TILE))
	if cell == _cell:
		return false
	_cell = cell
	_view = Rect2(top_left, view_size).grow(RunGround.TILE * MARGIN)
	redraws += 1
	queue_redraw()
	return true


func _draw() -> void:
	if _view.size != Vector2.ZERO:
		RunGround.draw(self, _view, arena_half, palette)
