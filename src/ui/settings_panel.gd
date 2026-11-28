class_name SettingsPanel
extends RefCounted
## The settings rows (shared by the lobby and the pause menu): each row is a
## label and a value button that cycles the option, saved through Prefs.current().
##
## Example:
##   var col := SettingsPanel.build(func() -> void: back_to_menu())
##   center.add_child(col)

# journal ink on paper: the pause menu's settings sit on a paper sheet since the in-run panels took the journal
# look (the old pale text on dark cards was unreadable there, 2026-11-27)
const TEXT := Color("3a2414")
const MUTED := Color("5a3a24")
const GOLD := Color("8a2a1a")
const CARD := Color("ddcca0")
const CARD_HOVER := Color("efe2bf")

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
	_row(col, "Rung màn hình", func() -> String: return "Bật" if Prefs.current().screen_shake else "Tắt",
		func() -> void: Prefs.current().set_value("screen_shake", not Prefs.current().screen_shake))
	_row(col, "Hiệu ứng", func() -> String: return String(Prefs.VFX_NAMES[Prefs.current().vfx]),
		func() -> void: Prefs.current().set_value("vfx", (Prefs.current().vfx + 1) % 3))   # fewer effects in busy late game
	_row(col, "Hỏi trước khi làm", func() -> String: return "Luôn" if Prefs.current().skip_confirm.is_empty() else "Bỏ qua %d" % Prefs.current().skip_confirm.size(),
		func() -> void: Prefs.current().set_value("skip_confirm", []))
	if DisplayServer.is_touchscreen_available() or "--touch" in OS.get_cmdline_user_args():   # phones only (J4)
		_row(col, "Cần điều khiển", func() -> String: return String(Prefs.TOUCH_NAMES[Prefs.current().touch_stick]),
			func() -> void: Prefs.current().set_value("touch_stick", (Prefs.current().touch_stick + 1) % 3))
	_row(col, "Nhạc", func() -> String: return "%d%%" % Prefs.current().music_volume,
		func() -> void: Prefs.current().set_value("music_volume", next_volume(Prefs.current().music_volume)))
	_row(col, "Hiệu ứng âm thanh", func() -> String: return "%d%%" % Prefs.current().sfx_volume,
		func() -> void: Prefs.current().set_value("sfx_volume", next_volume(Prefs.current().sfx_volume)))
	var hint := _label("Tỉ lệ là số nguyên; cửa sổ nhỏ hơn 1280×720 thì thu cả khung để pixel không méo.", 13, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)
	var back := _button("Quay lại", on_back)
	col.add_child(back)
	return col


## The next volume step (audio.json "volume" step, 20 %): 0 → 20 → … → 100 → 0.
static func next_volume(v: int) -> int:
	var step := int(GameData.load_json("res://assets/data/audio.json").get("volume", {}).get("step", 20))
	return 0 if v >= 100 else mini(100, (v / step + 1) * step)


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
	b.add_theme_stylebox_override("hover", _style(CARD_HOVER, Journal.GOLD))
	b.add_theme_stylebox_override("focus", _style(CARD_HOVER, Journal.GOLD))
	b.add_theme_stylebox_override("pressed", _style(CARD_HOVER, Journal.GOLD))
	for k in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(k, TEXT)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


static func _style(bg: Color, edge: Color = Color("8a2a1a")) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(3)
	s.set_content_margin_all(6)
	return s


## The journal settings spread (design-web screen-settings-journal, approved 2026-11-26): the left page "Cài đặt ·
## Hình ảnh và điều khiển" and the right page "Âm thanh" (volume meters), one row per option; the focused row is
## ink with ◂ value ▸; ← → or Enter change it, Esc calls [param on_back]. Returns a full-screen control.
static func build_journal(on_back: Callable) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.custom_minimum_size = Vector2(1280, 720)   # fills the screen inside a CenterContainer too
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.draw.connect(func() -> void:
		Journal.draw_desk(root, root.size)
		Journal.draw_book(root, Journal.BOOK))
	var p := Prefs.current()
	var opts := [
		["Toàn màn hình", func() -> String: return "Bật" if p.fullscreen else "Tắt",
			func(_d: int) -> void: p.set_value("fullscreen", not p.fullscreen)],
		["Tỉ lệ hiển thị", func() -> String:
			var s: String = SCALE_NAMES[p.scale]
			var k := p.current_scale()
			var shown := ("%d" % roundi(k)) if is_equal_approx(k, roundf(k)) else ("%.2f" % k)
			return s + (" (×%s)" % shown if p.scale == 0 else ""),
			func(d: int) -> void: p.set_value("scale", posmod(p.scale + d, SCALE_NAMES.size()))],
		["Số sát thương", func() -> String: return "Hiện" if p.damage_numbers else "Ẩn",
			func(_d: int) -> void: p.set_value("damage_numbers", not p.damage_numbers)],
		["Thanh máu quái", func() -> String: return "Hiện" if p.monster_hp else "Ẩn",
			func(_d: int) -> void: p.set_value("monster_hp", not p.monster_hp)],
		["Rung màn hình", func() -> String: return "Bật" if p.screen_shake else "Tắt",
			func(_d: int) -> void: p.set_value("screen_shake", not p.screen_shake)],
		["Hiệu ứng", func() -> String: return String(Prefs.VFX_NAMES[p.vfx]),
			func(d: int) -> void: p.set_value("vfx", posmod(p.vfx + d, 3))],
		# Notice.ask "Không hỏi lại" ticks: Luôn = every confirm shows; Bỏ qua N = N kinds skipped, change it to ask again
		["Hỏi trước khi làm", func() -> String: return "Luôn" if p.skip_confirm.is_empty() else "Bỏ qua %d" % p.skip_confirm.size(),
			func(_d: int) -> void: p.set_value("skip_confirm", [])],
	]
	if DisplayServer.is_touchscreen_available() or "--touch" in OS.get_cmdline_user_args():   # phones only (J4)
		opts.append(["Cần điều khiển", func() -> String: return String(Prefs.TOUCH_NAMES[p.touch_stick]),
			func(d: int) -> void: p.set_value("touch_stick", posmod(p.touch_stick + d, 3))])
	var sound := [
		["Nhạc", func() -> String: return "%d%%" % p.music_volume, func(d: int) -> void: p.set_value("music_volume", step_volume(p.music_volume, d)), "music_volume"],
		["Hiệu ứng âm thanh", func() -> String: return "%d%%" % p.sfx_volume, func(d: int) -> void: p.set_value("sfx_volume", step_volume(p.sfx_volume, d)), "sfx_volume"],
	]
	var left := VBoxContainer.new()
	left.position = Vector2(110, 66)
	left.custom_minimum_size = Vector2(470, 0)
	left.add_theme_constant_override("separation", 2)
	root.add_child(left)
	left.add_child(Journal.ink("Cài đặt", 44))
	left.add_child(Journal.ink("Hình ảnh và điều khiển", 22, Journal.INK_RED))
	var right := VBoxContainer.new()
	right.position = Vector2(660, 66)
	right.custom_minimum_size = Vector2(470, 0)
	right.add_theme_constant_override("separation", 2)
	root.add_child(right)
	var h2 := Journal.ink("Âm thanh", 32)
	var under := StyleBoxFlat.new()   # .page h2: an ink rule under the heading
	under.bg_color = Color(0, 0, 0, 0)
	under.border_color = Journal.INK
	under.border_width_bottom = 3
	h2.add_theme_stylebox_override("normal", under)
	right.add_child(h2)
	var rows: Array[Button] = []
	for o: Array in opts:
		rows.append(_journal_row(left, o, ""))
	for o: Array in sound:
		rows.append(_journal_row(right, o, String(o[3])))
	var note := Journal.ink("Tỉ lệ hiển thị là số nguyên để pixel sắc nét; cửa sổ nhỏ hơn 1280×720 thì thu cả khung.", 20, Journal.INK_SOFT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(470, 0)
	right.add_child(note)
	Journal.back_tab(root, on_back)   # "Trở lại" (web .back-tab)
	var hint := Journal.ink("↑ ↓ chọn · ← → đổi · Esc về sổ", 15, Journal.PAPER)
	hint.position = Vector2(Journal.BOOK.position.x, Journal.BOOK.end.y + 14)
	root.add_child(hint)
	root.gui_input.connect(func(ev: InputEvent) -> void:
		if ev.is_action_pressed("ui_cancel"):
			root.accept_event()
			on_back.call())
	for r in rows:
		r.gui_input.connect(func(ev: InputEvent) -> void:
			if ev.is_action_pressed("ui_cancel"):
				r.accept_event()
				on_back.call()
			elif ev.is_action_pressed("ui_down"):
				r.accept_event()
				rows[(rows.find(r) + 1) % rows.size()].grab_focus()
			elif ev.is_action_pressed("ui_up"):
				r.accept_event()
				rows[(rows.find(r) + rows.size() - 1) % rows.size()].grab_focus())
	rows[0].call_deferred("grab_focus")
	return root


## One option row (web .opt): the name, then the value (a meter for a volume); focused: ink with ◂ value ▸.
static func _journal_row(col: VBoxContainer, o: Array, meter_key: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(470, 48)
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.border_color = Journal.DOTS
	flat.border_width_bottom = 2
	var inked := StyleBoxFlat.new()
	inked.bg_color = Journal.INK
	b.add_theme_stylebox_override("normal", flat)
	for st in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(st, inked)
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10
	h.offset_right = -10
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var name := Journal.ink(String(o[0]), 26)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(name)
	var meter := Control.new()
	if meter_key != "":
		meter.custom_minimum_size = Vector2(100, 14)
		meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(meter)
	var val := Journal.ink("", 26)
	val.custom_minimum_size = Vector2(200 if meter_key == "" else 80, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(val)
	var refresh := func() -> void:
		var on := b.has_focus()
		var v: String = (o[1] as Callable).call()
		val.text = ("◂ %s ▸" % v) if on else v
		name.add_theme_color_override("font_color", Journal.PAPER if on else Journal.INK)
		val.add_theme_color_override("font_color", Journal.GOLD if on else Journal.INK)
		meter.queue_redraw()
	if meter_key != "":
		meter.draw.connect(func() -> void:
			var c := Journal.PAPER if b.has_focus() else Journal.INK
			var k := float(Prefs.current().get(meter_key)) / 100.0
			meter.draw_rect(Rect2(Vector2.ZERO, meter.size), c, false, 2.0)
			meter.draw_rect(Rect2(Vector2.ZERO, Vector2(meter.size.x * k, meter.size.y)), c))
	b.focus_entered.connect(refresh)
	b.focus_exited.connect(refresh)
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	b.pressed.connect(func() -> void:
		(o[2] as Callable).call(1)
		refresh.call())
	b.gui_input.connect(func(ev: InputEvent) -> void:
		for d in [[&"ui_right", 1], [&"ui_left", -1]]:
			if ev.is_action_pressed(d[0]):
				b.accept_event()
				(o[2] as Callable).call(int(d[1]))
				refresh.call())
	col.add_child(b)
	refresh.call()
	return b


## A volume one step (audio.json "volume" step) up or down, 0..100.
static func step_volume(v: int, d: int) -> int:
	var step := int(GameData.load_json("res://assets/data/audio.json").get("volume", {}).get("step", 20))
	return clampi(v + d * step, 0, 100)
