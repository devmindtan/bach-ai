class_name SettingsPanel
extends RefCounted
## The settings rows (shared by the lobby and the pause menu): each row is a
## label and a value button that cycles the option, saved through Prefs.current().
##
## Example:
##   var col := SettingsPanel.build(func() -> void: back_to_menu())
##   center.add_child(col)

const TEXT := Color("f2ecd8")
const MUTED := Color("b9b2a0")
const GOLD := Color("c9a65a")
const CARD := Color("2a2438")
const CARD_HOVER := Color("3b3352")

const SCALE_NAMES := ["Tự động", "×1", "×2", "×3"]


## A column with the title, one row per option and a back button.
static func build(on_back: Callable) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(440, 0)
	var title := _label("Cài đặt", 34, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_row(col, "Toàn màn hình", func() -> String: return "Bật" if Prefs.current().fullscreen else "Tắt",
		func() -> void: Prefs.current().set_value("fullscreen", not Prefs.current().fullscreen))
	_row(col, "Tỉ lệ hiển thị", func() -> String:
			var s: String = SCALE_NAMES[Prefs.current().scale]
			var k := Prefs.current().current_scale()
			var shown := ("%d" % roundi(k)) if is_equal_approx(k, roundf(k)) else ("%.2f" % k)
			return s + (" (×%s)" % shown if Prefs.current().scale == 0 else ""),
		func() -> void: Prefs.current().set_value("scale", (Prefs.current().scale + 1) % SCALE_NAMES.size()))
	_row(col, "Số sát thương", func() -> String: return "Hiện" if Prefs.current().damage_numbers else "Ẩn",
		func() -> void: Prefs.current().set_value("damage_numbers", not Prefs.current().damage_numbers))
	_row(col, "Thanh máu quái", func() -> String: return "Hiện" if Prefs.current().monster_hp else "Ẩn",
		func() -> void: Prefs.current().set_value("monster_hp", not Prefs.current().monster_hp))
	var hint := _label("Tỉ lệ luôn là số nguyên để pixel và chữ sắc nét.", 13, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)
	var back := _button("Quay lại", on_back)
	col.add_child(back)
	return col


static func _row(col: VBoxContainer, name: String, value: Callable, toggle: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := _label(name, 18, TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var b := _button(value.call(), Callable())
	b.custom_minimum_size = Vector2(170, 40)
	b.pressed.connect(func() -> void:
		toggle.call()
		b.text = value.call())
	row.add_child(b)
	col.add_child(row)
	if col.get_child_count() == 2:
		b.call_deferred("grab_focus")


static func _label(s: String, sz: int, c: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func _button(s: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = s
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_stylebox_override("normal", _style(CARD))
	b.add_theme_stylebox_override("hover", _style(CARD_HOVER))
	b.add_theme_stylebox_override("focus", _style(CARD_HOVER))
	b.add_theme_stylebox_override("pressed", _style(CARD_HOVER))
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


static func _style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = GOLD
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(6)
	return s
