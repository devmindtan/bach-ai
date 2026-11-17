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

var run: Node
var _gear: TextureButton


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
		_gear.position = Vector2(size.x - 44, ROW - 16)


## The settings button (gear) at the right end of the HUD row: opens the pause menu.
func _make_gear() -> void:
	_gear = TextureButton.new()
	_gear.texture_normal = UiIcons.texture("gear")
	_gear.ignore_texture_size = true
	_gear.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_gear.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_gear.custom_minimum_size = Vector2(32, 32)
	_gear.size = Vector2(32, 32)
	_gear.tooltip_text = "Tạm dừng / Cài đặt (Esc)"
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
	# xp: thin bar across the whole top edge
	var frac := clampf(float(run.xp) / float(run.xp_needed()), 0.0, 1.0)
	draw_rect(Rect2(0, 0, w, 10), BACK)
	draw_rect(Rect2(2, 2, (w - 4) * frac, 6), XP_BAR)
	# level: star with the number in its middle
	UiIcons.draw(self, "star", Vector2(32, ROW), 3.0)
	_centered(font, Vector2(32, _baseline(ROW + 2, 18)), str(run.level), 18)
	# hp: heart + bar with the number in its middle
	var max_hp := float(run.stats["max_hp"])
	UiIcons.draw(self, "heart", Vector2(78, ROW), 2.0)
	var bar := Rect2(96, ROW - 10, 200, 20)
	draw_rect(bar, BACK)
	draw_rect(Rect2(bar.position + Vector2(2, 2), Vector2((bar.size.x - 4) * clampf(run.hp / max_hp, 0.0, 1.0), 16)), HP_BAR)
	_centered(font, Vector2(bar.get_center().x, _baseline(ROW, 14)), "%d / %d" % [ceili(run.hp), roundi(max_hp)], 14)
	# clock: icon + elapsed, the total smaller on the same baseline
	var t := int(run.clock)
	var total := int(run.duration)
	var clock := "%02d:%02d" % [t / 60, t % 60]
	var cw := font.get_string_size(clock, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	var cx := w * 0.5 - cw * 0.5
	UiIcons.draw(self, "clock", Vector2(cx - 22, ROW), 2.0)
	_text(font, Vector2(cx, _baseline(ROW, 28)), clock, 28)
	_text(font, Vector2(cx + cw + 8, _baseline(ROW, 28)), "/ %02d:%02d" % [total / 60, total % 60], 16, MUTED)
	# kills and gold: icon + number pairs, right-aligned
	var gold := str(run.gold)
	var kills := str(run.enemies.total_kills)
	var gw := font.get_string_size(gold, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var kw := font.get_string_size(kills, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var x := w - 60 - gw   # the gear button sits at the right end
	_text(font, Vector2(x, _baseline(ROW, 22)), gold, 22)
	UiIcons.draw(self, "coin", Vector2(x - 22, ROW), 2.0)
	x -= 60 + kw
	_text(font, Vector2(x, _baseline(ROW, 22)), kills, 22)
	UiIcons.draw(self, "skull", Vector2(x - 22, ROW), 2.0)
	_draw_skill_bar(font)



const SLOT := 48.0
const SLOT_GAP := 8.0
const SLOT_BOTTOM := 18.0   # gap under the bar
const COOL := Color(0.02, 0.02, 0.05, 0.72)
const ACTIVE := Color("ffd36b")


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
		draw_rect(r, BACK)
		var tex := UiIcons.texture(si["id"])
		if tex != null:
			draw_texture_rect(tex, Rect2(r.position + Vector2(8, 8), Vector2(32, 32)), false)
		var left := float(cd[0])
		var total := maxf(0.01, float(cd[1]))
		if left > 0.0:
			_draw_sweep(r.grow(-2), clampf(left / total, 0.0, 1.0))
			if total >= 1.5:
				var t := ("%.1f" % left) if left < 10.0 else str(ceili(left))
				_centered(font, Vector2(r.get_center().x, _baseline(r.get_center().y, 16)), t, 16)
		var border := ACTIVE if bool(cd[2]) else (MUTED if left > 0.0 else TEXT)
		draw_rect(r, border, false, 2.0)
		x += SLOT + SLOT_GAP


## Dark sector over [param r] covering [param frac] of a turn, clockwise from the top.
func _draw_sweep(r: Rect2, frac: float) -> void:
	if frac >= 0.999:
		draw_rect(r, COOL)
		return
	var c := r.get_center()
	var half := r.size * 0.5
	var pts := PackedVector2Array([c])
	var steps := maxi(2, ceili(frac * 64.0))
	for i in steps + 1:
		var ang := -PI * 0.5 + TAU * frac * float(i) / float(steps)
		var d := Vector2(cos(ang), sin(ang))
		var k := minf(half.x / maxf(absf(d.x), 0.0001), half.y / maxf(absf(d.y), 0.0001))
		pts.append(c + d * k)
	draw_colored_polygon(pts, COOL)


func _centered(font: Font, baseline_center: Vector2, s: String, sz: int) -> void:
	var sw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var p := Vector2(roundf(baseline_center.x - sw * 0.5), baseline_center.y)
	draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 4, SHADOW)
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, TEXT)


func _text(font: Font, p: Vector2, s: String, sz: int, col := TEXT) -> void:
	draw_string(font, p + Vector2(2, 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, SHADOW)
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
