class_name AskSlip
extends Control
## The confirm slip of [method Notice.ask] (web screen-notices-journal ?view=delete / reset): dims the screen, a paper slip
## with a red pin, the title in red ink, the text, the cost line, "Không hỏi lại (Space)" when it has a key, and
## "Thôi (Esc)" / the red action "(Enter)". It owns the keys while open; ← → move between the two buttons.

const W := 520.0

var _key := ""
var _yes: Callable
var _skip := false
var _box: Label
var _no_b: Button
var _yes_b: Button


func setup(key: String, title: String, text: String, cost: String, yes: String, on_yes: Callable) -> void:
	_key = key
	_yes = on_yes
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.043, 0.031, 0.063, 0.66)
	dim.size = size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Journal.PAPER
	sb.border_color = Journal.EDGE
	sb.set_border_width_all(4)
	sb.set_content_margin_all(28)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_offset = Vector2(0, 8)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(W, 0)
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(Journal.ink(title, 30, Journal.INK_RED))
	var t := Journal.ink(text, 20)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = W - 56
	v.add_child(t)
	if cost != "":
		v.add_child(Journal.ink(cost, 18, Journal.INK_SOFT))
	if key != "":
		_box = Journal.ink("", 18)
		_box.mouse_filter = Control.MOUSE_FILTER_STOP   # a click ticks it too (user 2026-11-28)
		_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_box.gui_input.connect(func(e: InputEvent) -> void:
			var m := e as InputEventMouseButton
			if m != null and m.pressed and m.button_index == MOUSE_BUTTON_LEFT:
				_toggle_skip())
		v.add_child(_box)
		_paint_box()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	_no_b = _button("Thôi (Esc)", false)
	_no_b.pressed.connect(_close)
	row.add_child(_no_b)
	_yes_b = _button(yes + " (Enter)", true)
	_yes_b.pressed.connect(_accept)
	row.add_child(_yes_b)
	p.position = (size - p.get_combined_minimum_size()) * 0.5
	p.position = p.position.round()
	var pin := Control.new()   # the red pin on the slip's top edge (web .ask::before)
	pin.position = p.position + Vector2(roundf(W * 0.5), 0)
	pin.draw.connect(func() -> void:
		pin.draw_circle(Vector2.ZERO, 9.0, Color("5a0c08"))
		pin.draw_circle(Vector2.ZERO, 7.0, Journal.SEAL))
	add_child(pin)
	_yes_b.call_deferred("grab_focus")


func _button(text: String, red: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 22)
	for st in ["normal", "hover", "focus", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Journal.SEAL if red else Color("ddcca0")
		s.border_color = Journal.GOLD if st != "normal" else (Color("5a0c08") if red else Journal.INK)
		s.set_border_width_all(4 if st != "normal" else 3)
		s.content_margin_left = 16
		s.content_margin_right = 16
		s.content_margin_top = 4
		s.content_margin_bottom = 4
		b.add_theme_stylebox_override(st, s)
	for k in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Color("ffe0b0") if red else Journal.INK)
	b.focus_neighbor_left = NodePath()
	return b


func _toggle_skip() -> void:
	_skip = not _skip
	_paint_box()


func _paint_box() -> void:
	_box.text = ("[✓]" if _skip else "[  ]") + "  Không hỏi lại (Space)"


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		if event is InputEventKey:
			get_viewport().set_input_as_handled()
		return
	match k.keycode:
		KEY_ESCAPE:
			_close()
		KEY_ENTER, KEY_KP_ENTER:   # the labels say it: Enter is the action, Esc backs out
			_accept()
		KEY_SPACE:
			if _box != null:
				_toggle_skip()
		KEY_LEFT:
			_no_b.grab_focus()
		KEY_RIGHT:
			_yes_b.grab_focus()
	get_viewport().set_input_as_handled()


func _accept() -> void:
	if _skip and _key != "":
		var prefs := Prefs.current()
		if not prefs.skip_confirm.has(_key):
			var list: Array = prefs.skip_confirm.duplicate()
			list.append(_key)
			prefs.set_value("skip_confirm", list)
	var cb := _yes
	_close()
	cb.call()


func _close() -> void:
	get_parent().queue_free()
