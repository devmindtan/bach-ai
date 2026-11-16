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


func show_level_up(ids: Array[String]) -> void:
	var root := _open("Lên cấp! Chọn một", false)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	root.add_child(row)
	for i in ids.size():
		var u: Dictionary = run.upgrade(ids[i])
		var lv := int(run.levels.get(ids[i], 0))
		var b := Button.new()
		b.custom_minimum_size = Vector2(300, 190)
		b.focus_mode = Control.FOCUS_ALL
		b.add_theme_stylebox_override("normal", _style(CARD))
		b.add_theme_stylebox_override("hover", _style(CARD_HOVER))
		b.add_theme_stylebox_override("focus", _style(CARD_HOVER))
		b.add_theme_stylebox_override("pressed", _style(CARD_HOVER))
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 16
		v.offset_right = -16
		v.offset_top = 14
		v.offset_bottom = -14
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.alignment = BoxContainer.ALIGNMENT_CENTER   # content centred top-bottom: cards with short text are not top-heavy
		v.add_theme_constant_override("separation", 8)
		b.add_child(v)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		# the card's icon (ui-icons animation named like the upgrade id), 3x = 48 px in a framed tile
		var tile := PanelContainer.new()
		var ts := _style(Color("1d1828"))
		ts.set_content_margin_all(4)
		tile.add_theme_stylebox_override("panel", ts)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		icon.texture = UiIcons.texture(ids[i])
		icon.custom_minimum_size = Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(icon)
		head.add_child(tile)
		var title := _label("%d. %s" % [i + 1, u.get("name", ids[i])], 22, TEXT)
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(title)
		v.add_child(head)
		var tag := "Mới" if lv == 0 else "Cấp %d → %d" % [lv, lv + 1]
		v.add_child(_label("%s · tối đa %d" % [tag, int(u.get("max_level", 1))], 14, BORDER))
		var d := _label(String(u.get("desc", "")), 16, MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(260, 0)
		v.add_child(d)
		var idx := i
		b.pressed.connect(func() -> void: run.choose(idx))
		row.add_child(b)
		if i == 0:
			b.call_deferred("grab_focus")


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


func _style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = BORDER
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	return s
