class_name RunGround
extends RefCounted
## Draws the arena floor: grass tiles with a few deterministic tufts, darker
## outside the arena. Only the tiles inside the view are drawn.
##
## Example (in a CanvasItem's _draw):
##   RunGround.draw(self, view_rect, 1400.0)
##   RunGround.draw(self, view_rect, 1400.0, region_ground)  # stages.json region palette

const TILE := 64.0
const GRASS := [Color("2f4a2c"), Color("33502f"), Color("2c4629")]
const TUFT := Color("3f6136")
const FLOWER := Color("b8b06a")
const OUTSIDE := Color("1b2419")
const EDGE := Color("151c14")


## [param palette] is a region's "ground" from stages.json: grass / tuft / flower
## / outside as colour strings. Missing keys use the meadow defaults.
static func draw(canvas: CanvasItem, view: Rect2, arena_half: float, palette: Dictionary = {}) -> void:
	var grass: Array[Color] = []
	for c: Variant in palette.get("grass", GRASS):
		grass.append(c if c is Color else Color(String(c)))
	if grass.is_empty():
		grass.assign(GRASS)
	var tuft := Color(String(palette.get("tuft", TUFT.to_html(false))))
	var flower := Color(String(palette.get("flower", FLOWER.to_html(false))))
	var outside := Color(String(palette.get("outside", OUTSIDE.to_html(false))))
	var props: Array = palette.get("props", ["tuft", "flower"])
	var x0 := floori(view.position.x / TILE)
	var y0 := floori(view.position.y / TILE)
	var x1 := ceili(view.end.x / TILE)
	var y1 := ceili(view.end.y / TILE)
	for ty in range(y0, y1):
		for tx in range(x0, x1):
			var p := Vector2(tx * TILE, ty * TILE)
			var h := _hash(tx, ty)
			var inside := absf(p.x + TILE * 0.5) < arena_half and absf(p.y + TILE * 0.5) < arena_half
			if not inside:
				canvas.draw_rect(Rect2(p, Vector2(TILE, TILE)), outside)
				continue
			canvas.draw_rect(Rect2(p, Vector2(TILE, TILE)), grass[h % grass.size()])
			_props(canvas, p, h, props, tuft, flower, grass[0])
	var r := Rect2(-arena_half, -arena_half, arena_half * 2.0, arena_half * 2.0)
	canvas.draw_rect(r, EDGE, false, 6.0)


## The region's decorations on one tile (design/regions.md): small, dark, low
## contrast so monsters and gems stay readable. Each kind takes its own hash slot.
static func _props(canvas: CanvasItem, p: Vector2, h: int, props: Array, tuft: Color, flower: Color, base: Color) -> void:
	var q := p + Vector2(8 + (h >> 4) % 44, 8 + (h >> 8) % 44)
	var dark := base.darkened(0.25)
	for k in props.size():
		var kind := String(props[k])
		var slot := (h >> (k * 3)) % 37
		match kind:
			"tuft":
				if slot < 7:
					canvas.draw_rect(Rect2(q, Vector2(2, 6)), tuft)
					canvas.draw_rect(Rect2(q + Vector2(4, 2), Vector2(2, 4)), tuft)
					canvas.draw_rect(Rect2(q + Vector2(-4, 2), Vector2(2, 4)), tuft)
					return
			"flower":
				if slot == 8 or slot == 9:
					canvas.draw_rect(Rect2(q, Vector2(4, 4)), flower)
					canvas.draw_rect(Rect2(q + Vector2(1, 4), Vector2(2, 3)), tuft)
					return
			"pebble":
				if slot == 10:
					canvas.draw_rect(Rect2(q, Vector2(8, 5)), base.lightened(0.18))
					canvas.draw_rect(Rect2(q + Vector2(1, 4), Vector2(7, 2)), dark)
					return
			"leaves":
				if slot < 6:
					for i in 3:
						var o := Vector2(((h >> (i * 2)) % 20) - 10, ((h >> (i * 3 + 5)) % 14) - 7)
						canvas.draw_rect(Rect2(q + o, Vector2(4, 2)), Color("4a3a22") if i % 2 else Color("3a2e1c"))
					return
			"mushroom":
				if slot == 7 or slot == 8:
					canvas.draw_rect(Rect2(q + Vector2(2, 4), Vector2(2, 4)), Color("c8c0b0").darkened(0.35))
					canvas.draw_rect(Rect2(q, Vector2(6, 4)), flower)
					canvas.draw_rect(Rect2(q + Vector2(1, 1), Vector2(1, 1)), flower.lightened(0.4))
					return
			"stump":
				if slot == 9:
					canvas.draw_rect(Rect2(q + Vector2(-2, 10), Vector2(18, 4)), dark)
					canvas.draw_rect(Rect2(q, Vector2(14, 11)), Color("3a2a18"))
					canvas.draw_rect(Rect2(q + Vector2(1, 0), Vector2(12, 3)), Color("6a5030"))
					canvas.draw_rect(Rect2(q + Vector2(5, 1), Vector2(4, 1)), Color("4a3820"))
					return
			"shade":   # canopy shadow blot over a whole tile corner
				if slot == 11:
					canvas.draw_rect(Rect2(p + Vector2(4, 4), Vector2(40, 28)), Color(0, 0, 0, 0.16))
					canvas.draw_rect(Rect2(p + Vector2(12, 0), Vector2(28, 40)), Color(0, 0, 0, 0.12))
					return
			"puddle":
				if slot < 4:
					var c := Color("2a3d33")
					canvas.draw_rect(Rect2(q + Vector2(-10, 0), Vector2(32, 10)), c)
					canvas.draw_rect(Rect2(q + Vector2(-4, -3), Vector2(22, 16)), c)
					canvas.draw_rect(Rect2(q + Vector2(0, 2), Vector2(6, 1)), flower.darkened(0.3))
					canvas.draw_rect(Rect2(q + Vector2(9, 5), Vector2(4, 1)), flower.darkened(0.3))
					return
			"reed":
				if slot == 5 or slot == 6:
					for i in 3:
						canvas.draw_rect(Rect2(q + Vector2(i * 3, -i % 2 * 3), Vector2(1, 10 - i)), tuft)
					canvas.draw_rect(Rect2(q + Vector2(3, -5), Vector2(2, 4)), Color("5a4020"))
					return
			"bubble":
				if slot == 7:
					canvas.draw_rect(Rect2(q, Vector2(3, 3)), flower)
					canvas.draw_rect(Rect2(q + Vector2(5, 3), Vector2(2, 2)), flower.darkened(0.2))
					return


static func _hash(x: int, y: int) -> int:
	# mixed so props do not line up on a visible grid
	var h := ((x * 73856093) ^ (y * 19349663)) & 0x7fffffff
	h = ((h ^ (h >> 16)) * 0x45d9f3b) & 0x7fffffff
	h = ((h ^ (h >> 16)) * 0x45d9f3b) & 0x7fffffff
	return h ^ (h >> 16)
