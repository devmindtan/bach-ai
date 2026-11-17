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
			if h % 5 == 0:
				var q := p + Vector2(8 + (h >> 4) % 44, 8 + (h >> 8) % 44)
				canvas.draw_rect(Rect2(q, Vector2(2, 6)), tuft)
				canvas.draw_rect(Rect2(q + Vector2(4, 2), Vector2(2, 4)), tuft)
				canvas.draw_rect(Rect2(q + Vector2(-4, 2), Vector2(2, 4)), tuft)
			elif h % 23 == 1:
				var f := p + Vector2(10 + (h >> 5) % 40, 10 + (h >> 9) % 40)
				canvas.draw_rect(Rect2(f, Vector2(4, 4)), flower)
	var r := Rect2(-arena_half, -arena_half, arena_half * 2.0, arena_half * 2.0)
	canvas.draw_rect(r, EDGE, false, 6.0)


static func _hash(x: int, y: int) -> int:
	var h := (x * 73856093) ^ (y * 19349663)
	return absi(h)
