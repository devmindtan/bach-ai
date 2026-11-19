class_name RunGround
extends RefCounted
## Draws the arena floor: grass tiles with a few deterministic tufts, darker
## outside the arena, and the region's terrain patches (ground.patch: forest dirt,
## marsh water, meadow clover) in clusters of round merged blobs, so regions differ in
## shape, not only in colour (design/regions.md). Only the tiles inside the view are drawn.
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
const PATCH_CELL := 4   # tiles per terrain-patch block
const PATCH_R := 50.0   # blob radius: > half a tile's diagonal (45), so merged patches have no holes


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
	var patch: Dictionary = palette.get("patch", {})
	var share := float(patch.get("share", 0.0))
	var pcol := Color(String(patch.get("color", "000000")))
	var pkind := String(patch.get("kind", ""))
	var pseed := int(patch.get("seed", 0))   # each region its own patch layout
	var x0 := floori(view.position.x / TILE)
	var y0 := floori(view.position.y / TILE)
	var x1 := ceili(view.end.x / TILE)
	var y1 := ceili(view.end.y / TILE)
	var patches: Array = []   # [p, h, tx, ty] of the patch tiles in view (one tile of margin: blobs overhang)
	for ty in range(y0 - 1, y1 + 1):
		for tx in range(x0 - 1, x1 + 1):
			var p := Vector2(tx * TILE, ty * TILE)
			var h := _hash(tx, ty)
			var inside := absf(p.x + TILE * 0.5) < arena_half and absf(p.y + TILE * 0.5) < arena_half
			if not inside:
				canvas.draw_rect(Rect2(p, Vector2(TILE, TILE)), outside)
				continue
			canvas.draw_rect(Rect2(p, Vector2(TILE, TILE)), grass[h % grass.size()])
			if share > 0.0 and patch_at(tx, ty, share, pseed):
				patches.append([p, h])
				continue
			_props(canvas, p, h, props, tuft, flower, grass[0])
	# patches in three passes so neighbouring blobs merge: a darker lip, the body, then details
	for pt: Array in patches:
		_blob(canvas, pt[0], pt[1], PATCH_R + 4.0, pcol.darkened(0.3))
	for pt: Array in patches:
		_blob(canvas, pt[0], pt[1], PATCH_R, pcol)
	for pt: Array in patches:
		_patch_detail(canvas, pt[0], pt[1], pkind, pcol)
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


## True when tile ([param tx], [param ty]) lies in a terrain patch: blocks of PATCH_CELL tiles are
## patch with chance [param share]; each tile reads its block through a small jitter, so patches
## cluster with ragged borders instead of filling single tiles or clean squares.
static func patch_at(tx: int, ty: int, share: float, seed := 0) -> bool:
	if share <= 0.0:
		return false
	var h := _hash(tx * 3 + 11 + seed, ty * 5 - 7)
	var jx := (h % 3) - 1
	var jy := ((h >> 5) % 3) - 1
	var cx := floori(float(tx + jx) / PATCH_CELL)
	var cy := floori(float(ty + jy) / PATCH_CELL)
	return float(_hash(cx + 9001 + seed * 131, cy - 4049 + seed * 257) % 10000) / 10000.0 < share


## A patch tile's blob: a circle a little wider than half the tile's diagonal (so the blobs of
## neighbouring patch tiles leave no holes) plus two smaller lobes, jittered: round, uneven borders.
static func _blob(canvas: CanvasItem, p: Vector2, h: int, r: float, col: Color) -> void:
	var c := p + Vector2(TILE, TILE) * 0.5 + Vector2((h % 9) - 4, ((h >> 4) % 9) - 4)
	canvas.draw_circle(c, r - float((h >> 8) % 5), col)
	for k in 2:
		var a := float((h >> (12 + k * 4)) % 16) / 16.0 * TAU
		canvas.draw_circle(c + Vector2.from_angle(a) * r * 0.55, r * 0.55, col)


## The kind's detail on a patch tile: dirt (pebbles, exposed roots), water (ripples, glints), clover.
static func _patch_detail(canvas: CanvasItem, p: Vector2, h: int, kind: String, col: Color) -> void:
	var light := col.lightened(0.18)
	var q := p + Vector2(12 + (h >> 4) % 30, 12 + (h >> 8) % 30)
	match kind:
		"dirt":   # forest floor: pebbles and a root breaking the surface
			canvas.draw_rect(Rect2(q, Vector2(4, 3)), light)
			canvas.draw_rect(Rect2(q + Vector2(14, 9), Vector2(3, 2)), light)
			if h % 3 == 0:
				var r0 := p + Vector2(6, 20 + (h >> 10) % 24)
				for i in 6:
					canvas.draw_rect(Rect2(r0 + Vector2(i * 8, sin(i * 1.3 + h) * 3.0), Vector2(9, 3)), Color("4a3420"))
		"water":   # marsh shallows: ripple lines and a glint
			canvas.draw_rect(Rect2(q, Vector2(12, 1)), light)
			canvas.draw_rect(Rect2(q + Vector2(3, 3), Vector2(8, 1)), light.lerp(col, 0.4))
			if h % 2 == 0:
				canvas.draw_rect(Rect2(q + Vector2(-8, 16), Vector2(10, 1)), light)
			if h % 5 == 0:
				canvas.draw_rect(Rect2(q + Vector2(18, -4), Vector2(2, 2)), Color("b8d8a0"))
		"clover":   # meadow: brighter clover leaves
			for i in 5:
				var o := Vector2(((h >> (i * 3)) % 40) - 4, ((h >> (i * 3 + 7)) % 40) - 4)
				canvas.draw_rect(Rect2(q + o, Vector2(3, 3)), light)
				canvas.draw_rect(Rect2(q + o + Vector2(3, 1), Vector2(2, 2)), light)


static func _hash(x: int, y: int) -> int:
	# mixed so props do not line up on a visible grid
	var h := ((x * 73856093) ^ (y * 19349663)) & 0x7fffffff
	h = ((h ^ (h >> 16)) * 0x45d9f3b) & 0x7fffffff
	h = ((h ^ (h >> 16)) * 0x45d9f3b) & 0x7fffffff
	return h ^ (h >> 16)
