class_name FrontArt
extends RefCounted
## Drawing shared by the front-end screens (design/ux/front-end.md): the grass field
## drifting behind the menus, darkened and framed, and the stone pedestal with a
## rune ring in the class colour that a hero stands on.
##
## Example (in _draw):
##   FrontArt.backdrop(self, scroll, size, ground)
##   FrontArt.pedestal(self, Vector2(300, 470), Color("c94a4a"), t)


static func backdrop(canvas: CanvasItem, scroll: Vector2, size: Vector2, ground := {}) -> void:
	canvas.draw_set_transform(-scroll)
	RunGround.draw(canvas, Rect2(scroll, size).grow(64.0), 1.0e9, ground)
	canvas.draw_set_transform(Vector2.ZERO)
	canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.05, 0.55))
	for k in 6:   # darker bands top and bottom frame the screen
		var a := 0.08 * (6 - k)
		canvas.draw_rect(Rect2(0, k * 14, size.x, 14), Color(0, 0, 0, a))
		canvas.draw_rect(Rect2(0, size.y - (k + 1) * 14, size.x, 14), Color(0, 0, 0, a))


## A pedestal centred on [param feet]; [param k] scales it (1 = the lobby's).
static func pedestal(canvas: CanvasItem, feet: Vector2, col: Color, t: float, k := 1.0) -> void:
	ellipse(canvas, feet + Vector2(0, 10) * k, Vector2(150, 40) * k, Color(0, 0, 0, 0.35))
	ellipse(canvas, feet + Vector2(0, 6) * k, Vector2(132, 34) * k, Color("2a2533"))
	ellipse(canvas, feet, Vector2(132, 34) * k, Color("4a4458"))
	ellipse(canvas, feet, Vector2(118, 28) * k, Color("5c556c"))
	for i in 24:   # rune ring turning slowly
		var ang := i * TAU / 24.0 + t * 0.35
		var p := feet + Vector2(cos(ang) * 104.0, sin(ang) * 24.0) * k
		var lit := 0.55 + 0.45 * sin(t * 2.0 + i * 0.8)
		canvas.draw_rect(Rect2(p - Vector2(3, 2), Vector2(6, 4)), Color(col, lit))
	ellipse(canvas, feet + Vector2(0, -2) * k, Vector2(70, 14) * k, Color(col, 0.18 + 0.08 * sin(t * 2.0)))


static func ellipse(canvas: CanvasItem, c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var ang := i * TAU / 40.0
		pts.append(c + Vector2(cos(ang) * r.x, sin(ang) * r.y))
	canvas.draw_colored_polygon(pts, col)


## The class's hero sheet with its layers composed (null when missing).
static func hero_sheet(class_data: Dictionary) -> SpriteSheet:
	var sprite := String(class_data.get("sprite", "swordsman"))
	var sh := SpriteSheet.load_dir("res://assets/sprites/custom/" + sprite, sprite)
	if sh != null and not sh.layer_names().is_empty():
		sh.compose_layers()
	return sh
