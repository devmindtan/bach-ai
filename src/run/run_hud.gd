class_name RunHud
extends Control
## In-run HUD drawn from the run's state: xp bar across the top, level, clock,
## hp, kills and gold. Holds no state of its own.
##
## Example:
##   var hud := RunHud.new(); hud.run = run_node; canvas_layer.add_child(hud)

const XP_BAR := Color("4fa3e0")
const HP_BAR := Color("d9364a")
const BACK := Color(0.05, 0.05, 0.08, 0.85)
const TEXT := Color("f2ecd8")
const MUTED := Color("b9b2a0")
const SHADOW := Color(0, 0, 0, 0.7)

const TRAIL_HOLD := 0.5    # s the boss bar's recent-damage trail waits before catching up
const TRAIL_SPEED := 0.8   # bar widths a second it then shrinks
const EDGE_MARGIN := 26.0
const TOP_BAND := 96.0     # xp bar, hp, clock, boss bar: arrows stay below
const BOTTOM_BAND := 84.0  # skill bar: arrows stay above
const POINT_MAX := 6       # elite arrows at most (the nearest)

var run: Node
var _gear: TextureButton
var _trail := 1.0          # boss bar trail (fraction of max hp)
var _trail_hold := 0.0
var _trail_boss := -1


func _ready() -> void:
	# a Control under a CanvasLayer has no parent rect: size it to the viewport
	# (anchors alone left it 0x0, so panels and the HUD were laid out at the corner)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_make_gear()
	_fit()
	get_viewport().size_changed.connect(_fit)


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	if _gear != null:
		_gear.position = Vector2(size.x - 52, 20)


## The settings button (gear) at the right end of the HUD row: opens the pause menu.
func _make_gear() -> void:
	_gear = TextureButton.new()
	_gear.texture_normal = UiIcons.texture("gear")
	_gear.ignore_texture_size = true
	_gear.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_gear.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_gear.custom_minimum_size = Vector2(32, 32)
	_gear.size = Vector2(32, 32)
	Tip.attach(_gear, "Tạm dừng / Cài đặt", "Phím Esc.")
	_gear.focus_mode = Control.FOCUS_NONE
	_gear.mouse_entered.connect(func() -> void: _gear.modulate = Color(1.25, 1.25, 1.25))
	_gear.mouse_exited.connect(func() -> void: _gear.modulate = Color.WHITE)
	_gear.pressed.connect(func() -> void: run.open_pause())
	add_child(_gear)


## Every HUD element sits on one row: icons centred on ROW, text baselines
## placed so the glyphs (digits, capitals) are centred on the same line.
const ROW := 44.0
const GLYPH_MID := 0.36   # baseline - this x font size = visual middle of digits/capitals


func _baseline(center_y: float, sz: int) -> float:
	return roundf(center_y + sz * GLYPH_MID)


func _draw() -> void:
	if run == null:
		return
	var font := ThemeDB.fallback_font
	var w := size.x
	_draw_wave_call(font)
	# design-web screen-hud-journal (approved 2026-11-26): three paper slips pinned to the top
	# left: name and level, the hp bar with its numbers, a thin xp bar
	var me := Rect2(16, 14, 330, 74)
	_slip(me, 0.0)
	draw_set_transform(me.get_center(), 0.0)
	var o := -me.size * 0.5
	var who := String(run.playing_slot.name) if run.get("playing_slot") != null else String(run.class_data.get("name", ""))
	_ink(font, o + Vector2(14, 30), who, 24)
	var lv := "Cấp %d" % run.level
	_ink(font, o + Vector2(me.size.x - 14 - font.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x, 30), lv, 22, Journal.INK_RED)
	var max_hp := float(run.stats["max_hp"])
	var hb := Rect2(o + Vector2(14, 38), Vector2(me.size.x - 28, 18))
	draw_rect(hb, Journal.PAPER)
	# giáp ảo (user 2026-11-26): a grey part after the hp, shrinking as the buff runs out; when hp + it is over the
	# max the whole bar scales to that total so the grey part always shows (the usual shield bar)
	var wd: Array = run.ward_now()
	var grey := float(wd[0]) * float(wd[1])
	var hp_total := maxf(max_hp, run.hp + grey)
	var x0 := roundf(hb.size.x * clampf(run.hp / hp_total, 0.0, 1.0))
	draw_rect(Rect2(hb.position, Vector2(x0, hb.size.y)), Color("c0283a"))
	if grey > 0.0:
		var gw := roundf(minf(hb.size.x - x0, hb.size.x * grey / hp_total))
		draw_rect(Rect2(hb.position + Vector2(x0, 0), Vector2(gw, hb.size.y)), Color("9a9a9a"))
		draw_rect(Rect2(hb.position + Vector2(x0, 0), Vector2(gw, 4)), Color("d0d0d0"))
	draw_rect(hb, Journal.INK, false, 3.0)
	_centered(font, Vector2(hb.get_center().x, hb.position.y + 15), "%d / %d" % [ceili(run.hp), roundi(max_hp)], 15)
	var xb := Rect2(o + Vector2(14, 60), Vector2(me.size.x - 28, 6))
	draw_rect(xb, Journal.PAPER)
	draw_rect(Rect2(xb.position, Vector2(xb.size.x * clampf(float(run.xp) / float(run.xp_needed()), 0.0, 1.0), xb.size.y)), Color("3a6aaa"))
	draw_rect(xb, Journal.INK, false, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0)
	_draw_passive(Vector2(me.end.x + 22, me.position.y + 22))
	_draw_buffs(font, Vector2(me.position.x + 4, me.end.y + 22))
	# middle: the clock on one line, "02:41 / 05:00 · Ải 11" (user 2026-11-26: horizontal, not stacked)
	var t := int(run.clock)
	var total := int(run.duration)
	var clock := "%02d:%02d" % [t / 60, t % 60]
	var tail := (" · Vòng %d" % (run.endless_cycle() + 1)) if run.endless else (" / %02d:%02d · Ải %d" % [total / 60, total % 60, run.stage_number])
	var cw := font.get_string_size(clock, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	var tw := font.get_string_size(tail, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var cw2 := ceilf((cw + tw + 28.0) * 0.5) * 2.0   # even sizes: the slip's centre stays on a whole pixel (sharp text)
	var cl := Rect2(roundf(w * 0.5 - cw2 * 0.5), 12, cw2, 46)
	_slip(cl, 0.0)
	draw_set_transform(cl.get_center(), 0.0)
	o = -cl.size * 0.5
	_ink(font, o + Vector2(14, 34), clock, 30)
	_ink(font, o + Vector2(14 + cw, 34), tail, 20, Journal.INK_SOFT)
	draw_set_transform(Vector2.ZERO, 0.0)
	# right: kills and gold (and Tinh hoa once there is some), icon + number pairs
	var pairs := [["skull", str(run.enemies.total_kills)], ["coin", str(run.gold)]]
	if run.pickups != null and run.pickups.essence > 0:
		pairs.append(["essence", str(run.pickups.essence)])
	var tw2 := 0.0
	for p: Array in pairs:
		tw2 += 38.0 + font.get_string_size(String(p[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 16.0
	var taw := ceilf((tw2 + 14.0) * 0.5) * 2.0   # even, whole-pixel width (sharp text)
	var ta := Rect2(roundf(w - 16 - 48 - taw), 14, taw, 44)   # left of the gear (touch pause)
	_slip(ta, 0.0)
	draw_set_transform(ta.get_center(), 0.0)
	o = -ta.size * 0.5
	var x := o.x + 14
	for p: Array in pairs:
		UiIcons.draw(self, String(p[0]), Vector2(x + 12, 0), 2.0)
		_ink(font, Vector2(x + 34, 9), String(p[1]), 24)
		x += 38.0 + font.get_string_size(String(p[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 16.0
	draw_set_transform(Vector2.ZERO, 0.0)
	_draw_skill_bar(font)
	_draw_pointers()
	_draw_boss_bar(font)


## A paper slip (web .slip): paper with an edge, a drop shadow and a red pin on top. Kept straight ([param tilt]
## 0): a tilted slip resampled its pixels and blurred the text (user 2026-11-26).
func _slip(r: Rect2, tilt: float) -> void:
	draw_set_transform(r.get_center(), tilt)
	var rr := Rect2(-r.size * 0.5, r.size)
	draw_rect(Rect2(rr.position + Vector2(0, 4), rr.size), Color(0, 0, 0, 0.4))
	draw_rect(rr, Journal.PAPER)
	draw_rect(rr, Journal.EDGE, false, 3.0)
	draw_circle(Vector2(0, rr.position.y), 7.0, Color("5a0c08"))
	draw_circle(Vector2(0, rr.position.y), 5.0, Journal.SEAL)
	draw_set_transform(Vector2.ZERO, 0.0)


func _ink(font: Font, p: Vector2, s: String, sz: int, col: Color = Journal.INK) -> void:
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)



const SLOT := 60.0
const SLOT_GAP := 8.0
const SLOT_BOTTOM := 14.0   # gap under the bar
const ACTIVE := Color("ffd36b")


## Where an arrow for a target in direction [param dir] from [param from] meets the edge of [param area].
static func edge_point(from: Vector2, dir: Vector2, area: Rect2) -> Vector2:
	var t := INF
	if dir.x > 0.0001:
		t = minf(t, (area.end.x - from.x) / dir.x)
	elif dir.x < -0.0001:
		t = minf(t, (area.position.x - from.x) / dir.x)
	if dir.y > 0.0001:
		t = minf(t, (area.end.y - from.y) / dir.y)
	elif dir.y < -0.0001:
		t = minf(t, (area.position.y - from.y) / dir.y)
	return from if t == INF else from + dir * t


## One step of the boss bar's recent-damage trail: [trail, hold]. A drop starts a TRAIL_HOLD wait
## (hold > 0), then the trail shrinks at TRAIL_SPEED (hold < 0) until it meets the bar; a rising bar
## lifts it at once.
static func trail_step(trail: float, frac: float, hold: float, dt: float) -> Array:
	if frac >= trail:
		return [frac, 0.0]
	if hold == 0.0:
		return [trail, TRAIL_HOLD]
	if hold > 0.0:
		var h := hold - dt
		return [trail, h if h > 0.0 else -1.0]
	var t := maxf(frac, trail - TRAIL_SPEED * dt)
	return [t, 0.0 if t <= frac else -1.0]


## Arrows at the screen edge for the boss (red, bigger) and the nearest elites (gold) off screen;
## nearer targets draw bolder (after Warframe players' notes and Starship Survivors' edge arrows).
func _draw_pointers() -> void:
	var e = run.enemies
	if e == null:
		return
	var sc := maxf(0.01, Prefs.current().current_scale())
	var vp := get_viewport_rect().size / sc
	var area := Rect2(EDGE_MARGIN, TOP_BAND, vp.x - EDGE_MARGIN * 2.0, vp.y - TOP_BAND - BOTTOM_BAND)
	var cam: Vector2 = run.camera_center()
	var half := vp * 0.5
	var elites := []
	for i in e.count:
		if e.state[i] == Enemies.DYING:
			continue
		var boss: bool = e.k_boss[e.kind[i]] == 1
		if not boss and e.k_elite[e.kind[i]] != 1:
			continue
		var d: Vector2 = e.pos[i] - cam
		if absf(d.x) < half.x and absf(d.y) < half.y:
			continue   # on screen
		if boss:
			_pointer(area, d, Color("ff4a5a"), 1.0, d.length(), true)
		else:
			elites.append([d.length(), d])
	elites.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for k in mini(POINT_MAX, elites.size()):
		_pointer(area, elites[k][1], Color("f2c14e"), 0.75, elites[k][0], false)


func _pointer(area: Rect2, d: Vector2, col: Color, size: float, dist: float, boss: bool) -> void:
	var dir := d.normalized()
	var p := edge_point(area.get_center(), dir, area)
	var near := clampf(1.0 - (dist - 700.0) / 900.0, 0.35, 1.0)   # just off screen: bold; far: faint
	var s := (24.0 + 8.0 * near) * size   # long and narrow: a fat triangle reads as no direction at 1x
	var c := Color(col, 0.55 + 0.45 * near)
	var side := dir.orthogonal()
	var tip := p + dir * s * 0.55
	var back := p - dir * s * 0.45
	var notch := p - dir * s * 0.2   # a notched tail: an arrowhead, not a wedge
	var pts := PackedVector2Array([tip, back + side * s * 0.32, notch, back - side * s * 0.32])
	var out := PackedVector2Array([tip + dir * 2.5, back + side * (s * 0.32 + 2.5) - dir * 1.5, notch - dir * 2.0, back - side * (s * 0.32 + 2.5) - dir * 1.5])
	draw_colored_polygon(out, Color(0.05, 0.03, 0.05, c.a))
	draw_colored_polygon(pts, c)
	if boss:   # a skull behind the arrow names it
		UiIcons.draw(self, "skull", p - dir * s * 1.1, 2.0)


## The boss's name and hp under the clock while one is alive.
## A wave call across the upper screen while run.wave_call_t runs (fades in the last 0.5 s).
func _draw_wave_call(font: Font) -> void:
	if run.wave_call_t <= 0.0 or run.wave_call == "":
		return
	var a := clampf(run.wave_call_t / 0.5, 0.0, 1.0)
	var sz := 30
	var w := font.get_string_size(run.wave_call, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var vp := get_viewport_rect().size / maxf(0.01, Prefs.current().current_scale())
	var p := Vector2(vp.x * 0.5 - w * 0.5, 150.0)
	draw_string_outline(font, p, run.wave_call, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 8, Color(0.08, 0.04, 0.04, a))
	draw_string(font, p, run.wave_call, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(1.0, 0.78, 0.35, a))


func _draw_boss_bar(font: Font) -> void:
	var i: int = run.enemies.boss_index()
	if i < 0:
		return
	var k: int = run.enemies.kind[i]
	# web screen-hud-journal ?view=boss: a paper slip under the clock, the name in red ink, the phase, the bar
	var slip := Rect2(roundf(size.x * 0.5 - 300), 100, 600, 66)   # under the top slips, clear of them
	_slip(slip, 0.0)
	draw_set_transform(slip.get_center(), 0.0)
	var o := -slip.size * 0.5
	var name := String(run.enemies.k_extra[k].get("name", run.enemies.kind_ids[k]))
	var phase := String(run.enemies.phase_name(i))   # phase 2 shows its own name (design/bosses.md)
	var enraged: bool = run.enemies.enraged(i)
	var tail := (" · " + phase if phase != "" else "") + (" · NỔI GIẬN" if enraged else "")
	var nw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	var tw := font.get_string_size(tail, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	_ink(font, Vector2(-(nw + tw) * 0.5, o.y + 28), name, 26, Journal.INK_RED)
	_ink(font, Vector2(-(nw + tw) * 0.5 + nw, o.y + 28), tail, 18, Journal.INK_RED if enraged else Journal.INK_SOFT)
	var bar := Rect2(o + Vector2(14, 36), Vector2(slip.size.x - 28, 20))
	var frac := clampf(run.enemies.hp[i] / run.enemies.k_hp[k], 0.0, 1.0)
	if i != _trail_boss:   # a new boss: the trail starts full (bosses spawn full; a shot's --boss-hp shows the trail)
		_trail_boss = i
		_trail = 1.0
		_trail_hold = 0.0
	var ts := trail_step(_trail, frac, _trail_hold, get_process_delta_time())
	_trail = ts[0]
	_trail_hold = ts[1]
	draw_rect(bar, Journal.PAPER)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _trail, bar.size.y)), Color("e0b0a0"))   # recent damage
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), Color("8a1a18"))
	var ex: Dictionary = run.enemies.k_extra[k]
	if ex.has("rage_at"):   # where the boss turns enraged: a gold notch over the bar
		var rx := bar.position.x + bar.size.x * float(ex["rage_at"])
		draw_rect(Rect2(rx - 2, bar.position.y - 3, 4, bar.size.y + 6), Color("c0801a"))
	draw_rect(bar, Journal.INK, false, 3.0)
	_centered(font, Vector2(0, bar.position.y + 16), "%d / %d" % [ceili(run.enemies.hp[i]), roundi(run.enemies.k_hp[k])], 16)
	draw_set_transform(Vector2.ZERO, 0.0)


## The class passive's icon after the hp bar: dim while it waits for its
## condition (Bất khuất: hp under 30%), bright with a frame while it is on.
func _draw_passive(c: Vector2) -> void:
	var pv: Dictionary = run.passive()
	if pv.is_empty():
		return
	var tex := UiIcons.texture(String(pv.get("id", "")))
	if tex == null:
		return
	var on: bool = run.passive_active() or not (pv.has("hp_below") or pv.has("still_s"))   # lit while it is on
	var r := Rect2(c - Vector2(13, 13), Vector2(26, 26))
	if on:
		var col := Color(String(run.class_data.get("color", "ffd36b")))
		draw_rect(r.grow(3), Color(col, 0.35 + 0.25 * sin(run.clock * 6.0)))
	draw_texture_rect(tex, r, false, Color.WHITE if on else Color(1, 1, 1, 0.4))


## Running buffs under the hp bar: the badge, a time bar under it, seconds
## left beside it.
func _draw_buffs(font: Font, at: Vector2) -> void:
	var x := at.x
	for id: String in run.buffs.active:
		var d: Dictionary = run.buff_def(id)
		var sh: SpriteSheet = run.sheets.get(String(d.get("sprite", "")))
		if sh == null:
			continue
		var c := Vector2(x + 14, at.y)
		sh.draw(self, "idle", 0.0, c, 1.5)
		var left := float(run.buffs.time_left(id))
		var total := maxf(0.01, float(d.get("duration", 8.0)))
		# time bar under the badge, in the badge's rim colour
		var bar := Rect2(c.x - 12, c.y + 16, 24, 3)
		draw_rect(bar, BACK)
		draw_rect(Rect2(bar.position, Vector2(roundf(24 * clampf(left / total, 0.0, 1.0)), 3)), Color(d.get("color", "f2ecd8")))
		_text(font, Vector2(c.x + 18, _baseline(c.y, 14)), "%d" % ceili(left), 14)
		x += 56


## Owned skills along the bottom centre: icon in a slot, a dark sweep for the
## cooldown left (clockwise from 12 o'clock), seconds left on longer cooldowns,
## gold frame while the skill is running (whirlwind spinning).
func _draw_skill_bar(font: Font) -> void:
	var skills: Array = run.skill_info()
	if skills.is_empty():
		return
	var w := skills.size() * SLOT + (skills.size() - 1) * SLOT_GAP
	var x := roundf(size.x * 0.5 - w * 0.5)
	var y := size.y - SLOT_BOTTOM - SLOT
	for si: Dictionary in skills:
		var r := Rect2(x, y, SLOT, SLOT)
		var cd: Array = run.cooldown_state(si["id"])
		draw_rect(r, Journal.PAPER)   # web .skills .sk: a paper slot framed in ink
		var tex: Texture2D = run.icon_texture(String(si["id"]))
		if tex != null:
			draw_texture_rect(tex, Rect2(r.position + Vector2(8, 8), Vector2(44, 44)), false)
		var left := float(cd[0])
		var total := maxf(0.01, float(cd[1]))
		if left > 0.0:   # the cooldown fills the slot from the bottom in dark ink (web .cd)
			var k := clampf(left / total, 0.0, 1.0)
			draw_rect(Rect2(r.position.x, r.end.y - r.size.y * k, r.size.x, r.size.y * k), Color(0.23, 0.14, 0.08, 0.73))
			if total >= 1.5:
				var t := ("%.1f" % left) if left < 10.0 else str(ceili(left))
				_centered(font, Vector2(r.get_center().x, _baseline(r.get_center().y, 16)), t, 16)
		draw_rect(r, ACTIVE if bool(cd[2]) else Journal.INK, false, 3.0)
		x += SLOT + SLOT_GAP


func _centered(font: Font, baseline_center: Vector2, s: String, sz: int) -> void:
	var sw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var p := Vector2(roundf(baseline_center.x - sw * 0.5), baseline_center.y)
	draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 4, SHADOW)
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, TEXT)


func _text(font: Font, p: Vector2, s: String, sz: int, col := TEXT) -> void:
	draw_string(font, p + Vector2(2, 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, SHADOW)
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
