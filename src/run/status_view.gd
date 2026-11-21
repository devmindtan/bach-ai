class_name StatusView
extends RefCounted
## How statuses look on monsters (statuses.json): which ones are drawn (at most max_shown, by priority), where
## and at which whole scale (tiled on big bodies), and the drawing itself. First slice taken out of run.gd
## (roadmap items 6-7, review 2026-11-21: split the 3,000-line run script by responsibility).
##
## Example:
##   var view := StatusView.new(status_defs, 2, sprite_scale)
##   view.draw_on_monsters(canvas, enemies, sheets, clock, visible_rect, vfx_alpha)

var defs: Dictionary
var max_shown := 2
var sprite_scale := 2.0


func _init(p_defs: Dictionary, p_max_shown := 2, p_sprite_scale := 2.0) -> void:
	defs = p_defs
	max_shown = p_max_shown
	sprite_scale = p_sprite_scale


## The statuses to draw on one monster: at most max_shown, highest "priority" first (review 2026-11-21:
## burn + shock + slow + bleed stacked into clutter). Statuses not drawn still act.
func visible(list: Array) -> Array:
	if list.size() <= 1:
		return list
	var sorted := list.duplicate()
	sorted.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int(defs.get(a, {}).get("priority", 0)) > int(defs.get(b, {}).get("priority", 0)))
	return sorted.slice(0, max_shown)


## Where to draw a status sprite on a body of [param radius] px: [[offset, scale], ...]. The sprites are made
## for a body of radius 8 art px. A tiled status ("tile": the burn) never blows one sprite up (user
## 2026-11-20: blurry on big monsters): several at a whole scale no larger than the sprite scale, in a row
## along the lower half of the body; others one sprite at the nearest whole scale (fractions smear pixel art).
func spots(radius: float, tile: bool) -> Array:
	if not tile:
		return [[Vector2.ZERO, maxf(1.0, roundf(radius / 8.0))]]
	var full := 8.0 * sprite_scale
	if radius <= full:
		return [[Vector2.ZERO, clampf(roundf(radius / 8.0), 1.0, sprite_scale)]]
	var n := clampi(roundi(radius / full * 1.5), 2, 5)   # user 2026-11-20: tall flames all over the body hid it
	var out := []
	for k in n:
		var t := (k + 0.5) / n * 2.0 - 1.0          # -1 .. 1 across the body
		out.append([Vector2(t * radius * 0.7, radius * (0.35 + 0.25 * (1.0 - absf(t)))), sprite_scale])
	return out


## Draws the visible statuses of every living monster in [param view] on [param canvas], see-through
## (statuses.json alpha x the Cài đặt "Hiệu ứng" level [param vfx_alpha]).
func draw_on_monsters(canvas: CanvasItem, enemies: Enemies, sheets: Dictionary, clock: float, view: Rect2,
		vfx_alpha: float) -> void:
	for i in enemies.count:
		if enemies.state[i] == Enemies.DYING or not view.has_point(enemies.pos[i]):
			continue
		for st in visible(enemies.statuses_of(i)):
			var d: Dictionary = defs.get(st, {})
			var sh: SpriteSheet = sheets.get(String(d.get("sprite", "")))
			if sh == null:
				continue
			var r := enemies.k_radius[enemies.kind[i]]
			var p := enemies.center_of(i)
			if String(d.get("at", "body")) == "head":
				p.y -= r
			var k := 0
			for spot: Array in spots(r, bool(d.get("tile", false))):
				sh.draw(canvas, "loop", clock + i * 0.17 + k * 0.29, p + (spot[0] as Vector2), float(spot[1]),
					false, Color(1, 1, 1, float(d.get("alpha", 1.0)) * vfx_alpha))
				k += 1
