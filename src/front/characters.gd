extends Node2D
## Character select, "Các cuốn sổ" (design-web/games/bach-ai/screen-characters-journal.html, approved 2026-11-26):
## an open journal; the left page lists one notebook per character (hero, name, class, highest stage) and
## "+ Viết sổ mới"; the right page shows the chosen one (portrait, worn items, ledger, passive; seal "Dùng sổ
## này", Đổi tên / Xóa sổ) or the create page (class sketches with lock stamps, a name line, seal "Viết sổ").
## Esc goes back to the title.
##
## Command line (after `--`), for shots: --force-slots (preview slots, nothing is
## written), --front-create (open the create panel).

const TITLE_SCENE := "res://src/front/title.tscn"
const LOBBY_SCENE := "res://src/lobby/lobby.tscn"
const DATA := "res://assets/data/"

var _classes := {}
var _class_ids: Array[String] = []
var _sheets := {}          # class id -> SpriteSheet
var _entries: Array = []   # [{id, slot, error}]
var _chosen := ""          # slot id shown in the panel; "+" = the create panel
var _create_class := ""
var _t := 0.0
var _layer: CanvasLayer
var _equip_defs := {}
var _unlocks := Unlocks.load_default()


func _ready() -> void:
	Sfx.music("menu")
	var cls := GameData.load_json(DATA + "classes.json")
	for id: String in cls:
		if not id.begins_with("_"):
			_classes[id] = cls[id]
			_class_ids.append(id)
			_sheets[id] = FrontArt.hero_sheet(cls[id])
	_create_class = _class_ids[0]
	var items := GameData.load_json(DATA + "items.json")
	_equip_defs = items.get("equipment", {})
	var prefs := Prefs.current()
	if not prefs.is_fixed():
		prefs.ensure_slots()
	_reload()
	for cid: String in _class_ids:   # the first class this player may create (user 2026-11-26: classes unlock)
		if _unlocks.class_open(_entries, cid):
			_create_class = cid
			break
	_chosen = prefs.active_slot.id if prefs.active_slot != null else ""
	if _chosen == "" or _entry(_chosen).is_empty():
		_chosen = String(_entries[0]["id"]) if not _entries.is_empty() else "+"
	if OS.get_cmdline_user_args().has("--front-create") or _entries.is_empty():
		_chosen = "+"
	_build()


func _reload() -> void:
	var prefs := Prefs.current()
	_entries = prefs.preview_entries() if prefs.is_fixed() else prefs.slot_store().list()


func _entry(id: String) -> Dictionary:
	for e: Dictionary in _entries:
		if String(e["id"]) == id:
			return e
	return {}


func _process(delta: float) -> void:
	_t += delta



func _draw() -> void:
	Journal.draw_desk(self, get_viewport_rect().size)
	Journal.draw_book(self, Journal.BOOK)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(TITLE_SCENE)


func _rebuild() -> void:
	if _layer != null:
		_layer.queue_free()
	_build()


func _build() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	var root := Control.new()
	root.size = get_viewport_rect().size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	Journal.back_tab(root, func() -> void: get_tree().change_scene_to_file(TITLE_SCENE))   # "Trở lại" (web .back-tab)
	var half := Journal.BOOK.size.x * 0.5
	var left := _page(root, Rect2(Journal.BOOK.position + Vector2(40, 34), Vector2(half - 80, Journal.BOOK.size.y - 68)))
	var right_rect := Rect2(Journal.BOOK.position + Vector2(half + 40, 34), Vector2(half - 80, Journal.BOOK.size.y - 68))
	var right := _page(root, right_rect)
	left.add_child(Journal.ink("Các cuốn sổ", 44))
	var sub := Journal.ink("Mỗi nhân vật một cuốn sổ riêng: túi đồ, tiến độ, vàng, đá (tối đa %d)" % SlotStore.MAX, 18, Journal.INK_SOFT)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	left.add_child(gap)
	var first_focus: Control = null
	for e: Dictionary in _entries:
		var row := _slot_row(e)
		left.add_child(row)
		if String(e["id"]) == _chosen:
			first_focus = row
	if _entries.size() < SlotStore.MAX:
		var add := _row_button(_chosen == "+")
		add.text = "+  Viết sổ mới"
		add.add_theme_font_size_override("font_size", 26)
		add.custom_minimum_size = Vector2(0, 64)
		add.add_theme_color_override("font_color", Journal.INK_RED)
		add.pressed.connect(func() -> void:
			_chosen = "+"
			_rebuild())
		left.add_child(add)
		if _chosen == "+":
			first_focus = add
	var hint := Journal.ink("↑ ↓ chọn sổ · Enter · Esc về tiêu đề", 15, Journal.PAPER)
	hint.position = Vector2(Journal.BOOK.position.x, Journal.BOOK.end.y + 14)
	root.add_child(hint)

	var e := _entry(_chosen)
	if _chosen == "+":
		_create_page(right, root, right_rect)
	elif e.get("slot") == null:
		_broken_page(right, e)
	else:
		_slot_page(right, root, right_rect, e["slot"])
	if first_focus != null:
		first_focus.call_deferred("grab_focus")


func _page(root: Control, r: Rect2) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.position = r.position
	v.size = r.size
	v.custom_minimum_size = r.size
	v.add_theme_constant_override("separation", 4)
	root.add_child(v)
	return v


## A notebook row: ink-filled when chosen or focused (the web's .row.on).
func _row_button(on: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.border_color = Journal.DOTS
	flat.border_width_bottom = 2
	var inked := StyleBoxFlat.new()
	inked.bg_color = Journal.INK
	b.add_theme_stylebox_override("normal", inked if on else flat)
	for st in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(st, inked)
	b.add_theme_color_override("font_color", Journal.PAPER if on else Journal.INK)
	for k in ["font_focus_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Journal.GOLD)
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	return b


## A character in the left page: hero, name, class and highest stage.
func _slot_row(e: Dictionary) -> Button:
	var id := String(e["id"])
	var s: Slot = e["slot"]
	var on := id == _chosen
	var b := _row_button(on)
	b.custom_minimum_size = Vector2(0, 80)
	b.focus_entered.connect(func() -> void:
		if _chosen != id:
			_chosen = id
			_rebuild())
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	if s == null:
		var bad := Journal.ink("Không đọc được (%s)" % String(e["error"]), 20, Journal.INK_RED)
		bad.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bad)
		return b
	var box := _hero_box(s.cls, Vector2(64, 72), 2.0, 0.0, s.profile.equipped(s.cls).values())
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(v)
	var name := Journal.ink(s.name, 28, Journal.PAPER if on else Journal.INK)
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(name)
	var cls_name := String(_classes.get(s.cls, {}).get("name", s.cls))
	v.add_child(Journal.ink("%s · đã qua Ải %d" % [cls_name, s.best], 19, Journal.GOLD if on else Journal.INK_RED))
	return b


func _accent(cls: String) -> Color:
	return Color(String(_classes.get(cls, {}).get("color", "c9a65a")))


## The class's idle hero in a sketch box, feet near the bottom.
func _hero_box(cls: String, box: Vector2, scale: float, _k := 0.0, worn: Array = [], framed := false, on := false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = box
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sheet: SpriteSheet = _sheets.get(cls)
	if not worn.is_empty():   # this character's own look: its worn items drawn on the hero
		var key := cls + ":" + ",".join(PackedStringArray(worn))
		if not _sheets.has(key):
			_sheets[key] = FrontArt.hero_sheet(_classes.get(cls, {}), worn)
		sheet = _sheets[key]
	c.draw.connect(func() -> void:
		if framed:
			c.draw_rect(Rect2(Vector2.ZERO, box), Color("d8c498") if not on else Journal.INK)
			c.draw_rect(Rect2(Vector2.ZERO, box), Journal.GOLD if on else Journal.EDGE, false, 4.0)
		var feet := Vector2(box.x * 0.5, box.y - (box.y * 0.1 if framed else 2.0))
		if sheet != null:
			sheet.draw(c, "idle", _t if framed else 0.0, feet, FrontArt.scale_of(sheet, scale)))
	if framed:
		var tick := Timer.new()   # the hero idles
		tick.wait_time = 1.0 / 12.0
		tick.autostart = true
		tick.timeout.connect(c.queue_redraw)
		c.add_child(tick)
	return c


## The chosen notebook: portrait, name, ledger, passive, worn items; seal + Đổi tên / Xóa.
func _slot_page(v: VBoxContainer, root: Control, r: Rect2, s: Slot) -> void:
	var prefs := Prefs.current()
	var cd: Dictionary = _classes.get(s.cls, {})
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	v.add_child(top)
	top.add_child(_hero_box(s.cls, Vector2(160, 160), 3.6, 0.0, s.profile.equipped(s.cls).values(), true))
	var head := VBoxContainer.new()
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_theme_constant_override("separation", 2)
	top.add_child(head)
	var name := Journal.ink(s.name, 38)
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(name)
	var edit := LineEdit.new()
	edit.text = s.name
	edit.max_length = 18
	edit.visible = false
	edit.add_theme_font_size_override("font_size", 24)
	edit.add_theme_color_override("font_color", Journal.INK)
	var under := StyleBoxFlat.new()
	under.bg_color = Color(0, 0, 0, 0)
	under.border_color = Journal.INK
	under.border_width_bottom = 3
	for st in ["normal", "focus"]:
		edit.add_theme_stylebox_override(st, under)
	head.add_child(edit)
	head.add_child(Journal.ink("%s · %s" % [String(cd.get("name", s.cls)), String(cd.get("role", "")).to_lower()], 20, Journal.INK_RED))
	var gear := HBoxContainer.new()   # worn items: small sketch cells, empty ones blank
	gear.add_theme_constant_override("separation", 4)
	head.add_child(gear)
	var worn := s.profile.equipped(s.cls)
	const SLOT_NAMES := {"head": "Mũ", "chest": "Áo", "legs": "Quần", "arms": "Tay", "feet": "Giày", "weapon": "Vũ khí", "shield": "Khiên", "quiver": "Bao tên", "gloves": "Bao tay"}
	for slot: String in Profile.slots_for(s.cls):
		var item_id := String(worn.get(slot, ""))
		var d: Dictionary = _equip_defs.get(item_id, {})
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(40, 40)
		cell.draw.connect(func() -> void: Journal.draw_sketch(cell, Rect2(Vector2.ZERO, Vector2(40, 40))))
		if item_id != "":
			var ic := UiKit.icon(String(d.get("icon", item_id)), 34.0)
			ic.position = Vector2(3, 3)
			cell.add_child(ic)
			var rar := String(d.get("rarity", "common"))
			Tip.attach(cell, String(d.get("name", item_id)), String(d.get("desc", "")), UiKit.RARITY.get(rar, UiKit.GOLD),
				String(d.get("icon", item_id)), "%s · %s" % [UiKit.RARITY_NAME.get(rar, rar), SLOT_NAMES.get(slot, slot)])
		else:
			Tip.attach(cell, "%s: trống" % SLOT_NAMES.get(slot, slot), "Mặc đồ ở màn Trang bị (từ sảnh).")
		gear.add_child(cell)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	v.add_child(gap)
	var lasting := SkillTree.lasting(s)   # equipment + skill tree
	var st := PlayerStats.compute(cd.get("stats", {}), lasting[0], lasting[1])
	for t in [["star", "Ải cao nhất", str(s.best)], ["coin", "Vàng", str(s.gold)], ["gem", "Đá", str(s.gems)],
			["heart", "Máu", str(roundi(float(st.get("max_hp", 0))))], ["sword", "Sát thương", str(roundi(float(st.get("damage", 0))))],
			["boot", "Tốc độ chạy", str(roundi(float(st.get("move_speed", 0))))]]:
		v.add_child(Journal.ledger(t[0], t[1], t[2], 19))
	var pv: Dictionary = cd.get("passive", {})
	if not pv.is_empty():
		var n := Journal.note("Nội tại: " + String(pv.get("name", "")), String(pv.get("desc", "")), 17)
		v.add_child(n)
	# actions: the seal (main) at the page's bottom right, two ink words beside it
	var play := Journal.seal("Dùng sổ này ▶", Vector2(240, 62), 26)
	play.position = r.end - Vector2(240, 62)
	play.pressed.connect(func() -> void:
		if prefs.is_fixed():
			prefs.active_slot = s
		else:
			prefs.select_slot(s.id)
		get_tree().change_scene_to_file(LOBBY_SCENE))
	root.add_child(play)
	var rename := _ink_button("Đổi tên")
	rename.position = Vector2(r.position.x, r.end.y - 50)
	rename.pressed.connect(func() -> void:
		if not edit.visible:   # first press edits the name in place, the second saves
			edit.visible = true
			name.visible = false
			rename.text = "Lưu"
			edit.grab_focus()
			return
		var nn := edit.text.strip_edges()
		if nn != "":
			s.name = nn
		if not prefs.is_fixed():
			prefs.slot_store().save(s)
		_rebuild())
	root.add_child(rename)
	var del := _ink_button("Xóa sổ")
	del.position = Vector2(r.position.x + 120, r.end.y - 50)
	del.pressed.connect(func() -> void:   # always asks: a notebook cannot come back (web screen-notices ?view=delete)
		Notice.ask("", "Xóa sổ %s?" % s.name, "Mất hết túi đồ, tiến độ, vàng, đá của nhân vật này. Không lấy lại được.", "",
			"Xóa sổ", func() -> void:
				_delete(s.id)
				Notice.note("Đã xóa sổ %s" % s.name, "", null, true)))
	root.add_child(del)


## A plain word in ink that underlines in red when focused (secondary actions).
func _ink_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 22)
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.content_margin_left = 6
	flat.content_margin_right = 6
	var line := flat.duplicate() as StyleBoxFlat
	line.border_color = Journal.INK_RED
	line.border_width_bottom = 3
	b.add_theme_stylebox_override("normal", flat)
	for st in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(st, line)
	b.add_theme_color_override("font_color", Journal.INK_SOFT)
	for k in ["font_focus_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Journal.INK_RED)
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	return b


func _delete(id: String) -> void:
	var prefs := Prefs.current()
	if not prefs.is_fixed():
		prefs.slot_store().delete(id)
		if prefs.active_slot != null and prefs.active_slot.id == id:
			prefs.active_slot = null
			prefs.slot_id = ""
		_reload()
	_chosen = String(_entries[0]["id"]) if not _entries.is_empty() else "+"
	_rebuild()


func _broken_page(v: VBoxContainer, e: Dictionary) -> void:
	v.add_child(Journal.ink("Sổ bị hỏng", 38, Journal.INK_RED))
	var why := Journal.note("Không đọc được %s" % String(e.get("id", "")),
		"Lý do: %s. Các sổ khác vẫn chơi bình thường. Sổ này chỉ có thể xóa." % String(e.get("error", "")), 19)
	v.add_child(why)
	var del := _ink_button("Xóa sổ")
	del.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	del.pressed.connect(func() -> void:
		Notice.ask("", "Xóa sổ hỏng?", "Sổ này không đọc được; xóa thì mất hẳn.", "", "Xóa sổ",
			func() -> void: _delete(String(e.get("id", "")))))
	v.add_child(del)


## "Viết sổ mới": class sketches (2 per row, a red stamp on locked ones), a name line, the seal.
func _create_page(v: VBoxContainer, root: Control, r: Rect2) -> void:
	var prefs := Prefs.current()
	v.add_child(Journal.ink("Viết sổ mới", 38))
	v.add_child(Journal.ink("Chọn lớp (gắn với nhân vật, không đổi được)", 19, Journal.INK_SOFT))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for cid: String in _class_ids:
		grid.add_child(_class_card(cid, (r.size.x - 12.0) * 0.5))
	var cd: Dictionary = _classes[_create_class]
	var pv: Dictionary = cd.get("passive", {})
	v.add_child(Journal.note(String(cd.get("name", "")), "%s. Nội tại: %s." % [String(cd.get("role", "")), String(pv.get("name", ""))], 17))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	v.add_child(line)
	var lab := Journal.ink("Tên:", 24)
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(lab)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "%s %d" % [String(cd.get("name", "")), _entries.size() + 1]
	name_edit.max_length = 18
	name_edit.custom_minimum_size = Vector2(0, 40)
	name_edit.add_theme_font_size_override("font_size", 22)
	name_edit.add_theme_color_override("font_color", Journal.INK)
	name_edit.add_theme_color_override("font_placeholder_color", Journal.DOTS)
	name_edit.add_theme_color_override("caret_color", Journal.INK)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var under := StyleBoxFlat.new()
	under.bg_color = Color(0, 0, 0, 0)
	under.border_color = Journal.INK
	under.border_width_bottom = 3
	for st in ["normal", "focus"]:
		name_edit.add_theme_stylebox_override(st, under)
	line.add_child(name_edit)
	var make := Journal.seal("Viết sổ ▶", Vector2(240, 62), 26)
	make.position = r.end - Vector2(240, 62)
	make.disabled = prefs.is_fixed() or not _unlocks.class_open(_entries, _create_class)
	make.pressed.connect(func() -> void:
		var n := name_edit.text.strip_edges()
		if n == "":
			n = name_edit.placeholder_text
		var created := prefs.slot_store().create(n, _create_class)
		if created == null:
			return
		prefs.select_slot(created.id)
		_reload()
		_chosen = created.id
		_rebuild())
	root.add_child(make)


func _class_card(cid: String, w: float) -> Button:
	var cd: Dictionary = _classes[cid]
	var on := cid == _create_class
	var open := _unlocks.class_open(_entries, cid)
	var b := Button.new()
	b.custom_minimum_size = Vector2(w, 150)
	b.focus_mode = Control.FOCUS_ALL
	for st in ["normal", "hover", "focus", "pressed"]:
		var sb := StyleBoxFlat.new()
		var lit: bool = on or st != "normal"
		sb.bg_color = Journal.INK if on else Journal.SKETCH
		sb.border_color = Journal.GOLD if lit else Journal.INK
		sb.set_border_width_all(4 if lit else 3)
		b.add_theme_stylebox_override(st, sb)
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	b.pressed.connect(func() -> void:
		if not open:   # locked: the stamp says which stage opens it
			return
		_create_class = cid
		_rebuild())
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_top = 6
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var hero := _hero_box(cid, Vector2(w, 100), 3.0, 0.0, FrontArt.showcase_gear(cid))
	if not open:
		hero.modulate = Color(0.55, 0.5, 0.45, 0.7)
	v.add_child(hero)
	var nm := Journal.ink(String(cd.get("name", cid)), 24, Journal.PAPER if on else Journal.INK)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nm)
	if not open:
		var stamp := Journal.ink("Qua ải %d" % _unlocks.need("class_" + cid), 20, Journal.INK_RED)
		stamp.position = Vector2(w - 110, 8)
		stamp.rotation = 0.0   # straight: a rotated label blurs (user 2026-11-26)
		b.add_child(stamp)
	return b
