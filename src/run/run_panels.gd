class_name RunPanels
extends Control
## Modal panels of a run: level-up (three upgrade cards, click or 1/2/3),
## pause, and the win / lose screen. Calls back into the run node.
##
## Example:
##   panels.show_level_up(["sharpen", "haste", "reach"])

const DIM := Color(0, 0, 0, 0.6)
const CARD := Color("2a2438")
const CARD_HOVER := Color("3b3352")
const BORDER := Color("c9a65a")
const TEXT := Color("f2ecd8")
const MUTED := Color("b9b2a0")
const STAT_ACCENT := Color("6aa6d8")   # stat cards; skills use the gold BORDER
const GAIN := Color("8ee08e")          # the value after the pick
const MILESTONE := Color("ffd36b")
const PIP_LOCKED := Color("1b1726")    # level not reached yet (dark, with a visible edge)
const PIP_EDGE := Color("6b6380")

var run: Node
var _box: Control


func _ready() -> void:
	# a Control under a CanvasLayer has no parent rect: size it to the viewport
	# (anchors alone left it 0x0, so panels and the HUD were laid out at the corner)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit()
	get_viewport().size_changed.connect(_fit)


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func hide_all() -> void:
	if _box != null:
		_box.queue_free()
		_box = null


## Level-up: three cards. Each shows the icon, kind and level, a row of level
## pips (owned / the one you get / still locked, milestones drawn as diamonds),
## the milestone reached by this pick, the real before -> after numbers, and the
## description. Content reads top-down from the top of the card.
func show_level_up(ids: Array[String]) -> void:
	var root := _open("Lên cấp! Chọn một", false)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	root.add_child(row)
	for i in ids.size():
		row.add_child(_upgrade_card(i, ids[i]))
	_fit_cards.call_deferred(row)


## A Button does not grow with its children: once laid out, give every card the
## height of the tallest content so no text runs past the frame and the row is even.
func _fit_cards(row: HBoxContainer) -> void:
	var h := 0.0
	for b in row.get_children():
		var v: Control = b.get_child(0)
		h = maxf(h, v.get_combined_minimum_size().y + 24.0)
	for b: Control in row.get_children():
		b.custom_minimum_size.y = maxf(180.0, h)


func _upgrade_card(i: int, id: String) -> Button:
	var u: Dictionary = run.upgrade(id)
	var pv: Dictionary = run.upgrade_preview(id)
	var skill: bool = u.get("kind") == "skill"
	var accent := BORDER if skill else STAT_ACCENT
	var b := Button.new()
	b.custom_minimum_size = Vector2(300, 180)   # grown to the tallest card by _fit_cards
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", _style(CARD, accent))
	b.add_theme_stylebox_override("hover", _style(CARD_HOVER, accent))
	b.add_theme_stylebox_override("focus", _style(CARD_HOVER, Color.WHITE))
	b.add_theme_stylebox_override("pressed", _style(CARD_HOVER, Color.WHITE))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_right = -14
	v.offset_top = 12
	v.offset_bottom = -12
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 8)
	b.add_child(v)
	# header: icon tile | name, kind and level
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tile := PanelContainer.new()
	var ts := _style(Color("1d1828"), accent)
	ts.set_content_margin_all(4)
	tile.add_theme_stylebox_override("panel", ts)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = UiIcons.texture(id)
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(icon)
	head.add_child(tile)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 2)
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_child(_label("%d. %s" % [i + 1, u.get("name", id)], 20, TEXT))
	var lv: int = pv["level"]
	var kind := ("CHIÊU" if skill else "CHỈ SỐ") + "  ·  " + ("Mới" if lv == 0 else "Cấp %d → %d" % [lv, lv + 1])
	names.add_child(_label(kind, 13, accent))
	head.add_child(names)
	v.add_child(head)
	# level pips + the milestone this pick reaches
	var pips := Control.new()
	pips.custom_minimum_size = Vector2(0, 18)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.draw.connect(func() -> void: _draw_pips(pips, lv, int(pv["max"]), pv["milestones"], accent))
	v.add_child(pips)
	if String(pv["milestone"]) != "":
		v.add_child(_label("★ " + String(pv["milestone"]), 14, MILESTONE))
	# real numbers: before -> after
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 2)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for line: Array in pv["lines"]:
		var k := _label(String(line[0]), 15, MUTED)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(k)
		var change := RichTextLabel.new()
		change.bbcode_enabled = true
		change.fit_content = true
		change.scroll_active = false
		change.autowrap_mode = TextServer.AUTOWRAP_OFF
		change.custom_minimum_size = Vector2(120, 0)
		change.add_theme_font_size_override("normal_font_size", 15)
		change.add_theme_font_size_override("bold_font_size", 15)
		change.mouse_filter = Control.MOUSE_FILTER_IGNORE
		change.text = "[right][color=#%s]%s[/color]  →  [b][color=#%s]%s[/color][/b][/right]" % [
			MUTED.to_html(false), line[1], GAIN.to_html(false), line[2]]
		grid.add_child(change)
	v.add_child(grid)
	var d := _label(String(u.get("desc", "")), 14, MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(270, 0)
	v.add_child(d)
	var idx := i
	b.pressed.connect(func() -> void: run.choose(idx))
	if i == 0:
		b.call_deferred("grab_focus")
	return b


## One pip per level: owned = filled, the level this pick gives = bright with a
## ring, locked = dark; milestone levels (new tier look, last level) are diamonds.
func _draw_pips(c: Control, owned: int, max_level: int, milestones: Array, accent: Color) -> void:
	var x := 0.0
	for l in range(1, max_level + 1):
		var col := accent if l <= owned else (Color.WHITE if l == owned + 1 else PIP_LOCKED)
		var cx := x + 9.0
		if milestones.has(l):
			var pts := PackedVector2Array([Vector2(cx, 0), Vector2(cx + 9, 9), Vector2(cx, 18), Vector2(cx - 9, 9)])
			c.draw_colored_polygon(pts, col)
			var ring := MILESTONE if l == owned + 1 else PIP_EDGE
			c.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), ring, 2.0)
		else:
			c.draw_rect(Rect2(x + 1, 4, 16, 10), col)
			c.draw_rect(Rect2(x + 1, 4, 16, 10), MILESTONE if l == owned + 1 else PIP_EDGE, false, 2.0)
		x += 24.0


func show_pause() -> void:
	var root := _open("Tạm dừng")
	var go_on := _button("Tiếp tục (Esc)", func() -> void: run.resume())
	root.add_child(go_on)
	go_on.call_deferred("grab_focus")
	root.add_child(_button("Chơi lại", func() -> void: run.restart()))
	root.add_child(_button("Về sảnh", func() -> void: run.to_lobby()))


func show_end(won: bool) -> void:
	var root := _open("Vượt ải!" if won else "Thất bại")
	var t := int(run.clock)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	row.add_child(_icon_value("clock", "%02d:%02d" % [t / 60, t % 60]))
	row.add_child(_icon_value("star", str(run.level)))
	row.add_child(_icon_value("skull", str(run.enemies.total_kills)))
	row.add_child(_icon_value("coin", str(run.gold)))
	root.add_child(row)
	var again := _button("Chơi lại (R)", func() -> void: run.restart())
	root.add_child(again)
	root.add_child(_button("Về sảnh", func() -> void: run.to_lobby()))
	again.call_deferred("grab_focus")


func _icon_value(icon: String, value: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var tex := TextureRect.new()
	tex.texture = UiIcons.texture(icon)
	tex.custom_minimum_size = Vector2(32, 32)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(tex)
	h.add_child(_label(value, 24, TEXT))
	return h


## A modal: dimmed screen, centred column with the title. boxed puts the column
## on a panel so it stays readable over a crowded field (pause, win, lose).
func _open(title: String, boxed := true) -> VBoxContainer:
	hide_all()
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_box = dim
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 18)
	if boxed:
		var panel := PanelContainer.new()
		var ps := _style(Color(0.09, 0.08, 0.13, 0.94))
		ps.content_margin_left = 40
		ps.content_margin_right = 40
		ps.content_margin_top = 24
		ps.content_margin_bottom = 28
		panel.add_theme_stylebox_override("panel", ps)
		center.add_child(panel)
		panel.add_child(root)
	else:
		center.add_child(root)
	var l := _label(title, 40, BORDER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(l)
	return root


func _label(s: String, sz: int, c: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(s: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = s
	b.custom_minimum_size = Vector2(260, 48)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_stylebox_override("normal", _style(CARD))
	b.add_theme_stylebox_override("hover", _style(CARD_HOVER))
	b.add_theme_stylebox_override("focus", _style(CARD_HOVER))
	b.pressed.connect(cb)
	return b


func _style(bg: Color, border := BORDER) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	return s
