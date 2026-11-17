extends Node2D
## Character select (design/ux/front-end.md): the character slots in a column on the
## left (hero, name, class, highest stage) and the chosen one in a big panel on the
## right (hero on a pedestal, progress, stats with equipment, passive, worn
## items; Chơi / Đổi tên / Xóa). "+ Tạo nhân vật" turns the panel into
## two class cards, a name field and "Tạo nhân vật". Esc goes back to the title.
##
## Command line (after `--`), for shots: --force-slots (preview slots, nothing is
## written), --front-create (open the create panel).

const TITLE_SCENE := "res://src/front/title.tscn"
const LOBBY_SCENE := "res://src/lobby/lobby.tscn"
const DATA := "res://assets/data/"
const LEFT := Vector2(40, 104)
const TILE := Vector2(360, 92)
const PANEL_POS := Vector2(420, 104)
const PANEL_SIZE := Vector2(820, 576)

var _classes := {}
var _class_ids: Array[String] = []
var _sheets := {}          # class id -> SpriteSheet
var _entries: Array = []   # [{id, slot, error}]
var _chosen := ""          # slot id shown in the panel; "+" = the create panel
var _create_class := ""
var _t := 0.0
var _scroll := Vector2.ZERO
var _layer: CanvasLayer
var _equip_defs := {}


func _ready() -> void:
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
	_scroll += Vector2(18.0, 6.0) * delta
	queue_redraw()


func _draw() -> void:
	FrontArt.backdrop(self, _scroll, get_viewport_rect().size)


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
	var title := UiKit.label("Chọn nhân vật", 34, UiKit.GOLD)
	title.position = Vector2(40, 24)
	root.add_child(title)
	var sub := UiKit.label("Mỗi nhân vật có class, túi đồ, tiến độ ải và vàng, đá riêng (tối đa %d)." % SlotStore.MAX, 15, UiKit.MUTED)
	sub.position = Vector2(42, 70)
	root.add_child(sub)
	var back := UiKit.button("Quay lại  (Esc)", func() -> void: get_tree().change_scene_to_file(TITLE_SCENE), Vector2(180, 42), 17)
	back.position = Vector2(root.size.x - 40 - 180, 28)
	root.add_child(back)

	# left: one tile per slot, then "+ Tạo nhân vật"
	var col := VBoxContainer.new()
	col.position = LEFT
	col.add_theme_constant_override("separation", 10)
	root.add_child(col)
	var first_focus: Control = null
	for e: Dictionary in _entries:
		var tile := _slot_tile(e)
		col.add_child(tile)
		if String(e["id"]) == _chosen:
			first_focus = tile
	if _entries.size() < SlotStore.MAX:
		var add := _tile_button(_chosen == "+")
		var row := HBoxContainer.new()
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 18
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(UiKit.label("+  Tạo nhân vật", 22, UiKit.GOLD))
		(row.get_child(0) as Label).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add.add_child(row)
		add.pressed.connect(func() -> void:
			_chosen = "+"
			_rebuild())
		col.add_child(add)
		if _chosen == "+":
			first_focus = add

	# right: the chosen slot, a broken file, or the create panel
	var panel := UiKit.panel(Color(0.09, 0.08, 0.13, 0.96), 20)
	panel.position = PANEL_POS
	panel.custom_minimum_size = PANEL_SIZE
	panel.size = PANEL_SIZE
	root.add_child(panel)
	var e := _entry(_chosen)
	if _chosen == "+":
		_create_panel(panel)
	elif e.get("slot") == null:
		_broken_panel(panel, e)
	else:
		_slot_panel(panel, e["slot"])
	if first_focus != null:
		first_focus.call_deferred("grab_focus")


func _tile_button(on: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = TILE
	b.focus_mode = Control.FOCUS_ALL
	var border := Color.WHITE if on else UiKit.GOLD
	b.add_theme_stylebox_override("normal", UiKit.style(UiKit.PANEL_HOVER if on else UiKit.PANEL, 8, border, 3 if on else 2))
	for st in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(st, UiKit.style(UiKit.PANEL_HOVER, 8, Color.WHITE, 3))
	return b


## A slot in the left column: hero, name, class, highest stage.
func _slot_tile(e: Dictionary) -> Button:
	var id := String(e["id"])
	var s: Slot = e["slot"]
	var b := _tile_button(id == _chosen)
	b.pressed.connect(func() -> void:
		_chosen = id
		_rebuild())
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -12
	row.offset_top = 8
	row.offset_bottom = -8
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	if s == null:
		var bad := UiKit.label("Không đọc được (%s)" % String(e["error"]), 18, Color("ff9a9a"))
		bad.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bad)
		b.add_theme_stylebox_override("normal", UiKit.style(Color("2a1a20"), 8, Color("a04848")))
		return b
	var box := _hero_box(s.cls, Vector2(76, 76), 2.0)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(v)
	var name := UiKit.label(s.name, 21, UiKit.TEXT)
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(name)
	var cls_name := String(_classes.get(s.cls, {}).get("name", s.cls))
	v.add_child(UiKit.label("%s  ·  Ải %d" % [cls_name, s.best], 15, _accent(s.cls).lightened(0.35)))
	if Prefs.current().active_slot != null and Prefs.current().active_slot.id == id:
		v.add_child(UiKit.label("Chơi lần trước", 13, UiKit.MUTED))
	return b


func _accent(cls: String) -> Color:
	return Color(String(_classes.get(cls, {}).get("color", "c9a65a")))


## The class's idle hero at [param scale]: in a dark box with a shadow, or (k > 0) on a
## pedestal of size k whose lowest edge stays inside the box (feet 50k + 6 px above it).
func _hero_box(cls: String, box: Vector2, scale: float, k := 0.0) -> Control:
	var pedestal := k > 0.0
	var c := Control.new()
	c.custom_minimum_size = box
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sheet: SpriteSheet = _sheets.get(cls)
	var col := _accent(cls)
	c.draw.connect(func() -> void:
		var feet := Vector2(box.x * 0.5, box.y - (50.0 * k + 6.0 if pedestal else 6.0))
		if pedestal:
			FrontArt.pedestal(c, feet, col, _t, k)
		else:
			c.draw_rect(Rect2(Vector2.ZERO, box), UiKit.PANEL_DARK)
			c.draw_rect(Rect2(Vector2(10, box.y - 9), Vector2(box.x - 20, 4)), Color(0, 0, 0, 0.4))
		if sheet != null:
			sheet.draw(c, "idle", _t if pedestal else 0.0, feet, scale))
	if pedestal:
		c.set_process(true)
		var tick := Timer.new()   # the hero idles and the rune ring turns
		tick.wait_time = 1.0 / 15.0
		tick.autostart = true
		tick.timeout.connect(c.queue_redraw)
		c.add_child(tick)
	return c


func _section(text: String) -> Label:
	return UiKit.label(text, 16, UiKit.GOLD)


## Name, class, progress, stats, passive, worn items, actions.
func _slot_panel(panel: PanelContainer, s: Slot) -> void:
	var prefs := Prefs.current()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	panel.add_child(h)
	var cd: Dictionary = _classes.get(s.cls, {})
	h.add_child(_hero_box(s.cls, Vector2(280, 440), 6.0, 0.82))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var name_row := HBoxContainer.new()
	v.add_child(name_row)
	var name := UiKit.label(s.name, 34, UiKit.TEXT)
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name)
	var edit := LineEdit.new()
	edit.text = s.name
	edit.max_length = 18
	edit.visible = false
	edit.add_theme_font_size_override("font_size", 22)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(edit)
	v.add_child(UiKit.label("%s  ·  %s" % [String(cd.get("name", s.cls)), String(cd.get("role", ""))], 18, _accent(s.cls).lightened(0.35)))
	var prog := HBoxContainer.new()
	prog.add_theme_constant_override("separation", 22)
	v.add_child(prog)
	prog.add_child(UiKit.stat("star", "Ải %d" % s.best, "Ải cao nhất đã vượt"))
	prog.add_child(UiKit.stat("coin", str(s.gold), "Vàng"))
	prog.add_child(UiKit.stat("gem", str(s.gems), "Đá (gacha, đợt 5)"))
	# stats with the worn equipment
	var base: Dictionary = cd.get("stats", {})
	var st := PlayerStats.compute(base, s.profile.as_upgrades(s.cls), s.profile.levels(s.cls))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	v.add_child(grid)
	for t in [["heart", "Máu", "max_hp", "%d"], ["sword", "Sát thương", "damage", "%d"],
			["boot", "Tốc độ", "move_speed", "%d"], ["magnet", "Tầm hút", "magnet", "×%.1f"]]:
		var val := float(st.get(t[2], 0.0))
		var txt: String = (t[3] % roundi(val)) if t[3] == "%d" else (t[3] % val)
		var cell := UiKit.panel(UiKit.PANEL_DARK, 8, Color("4a4458"))
		cell.custom_minimum_size = Vector2(110, 0)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 0)
		cell.add_child(cv)
		var top := HBoxContainer.new()
		top.alignment = BoxContainer.ALIGNMENT_CENTER
		top.add_theme_constant_override("separation", 6)
		top.add_child(UiKit.icon(t[0], 20.0))
		var boosted := not is_equal_approx(val, float(base.get(t[2], val)))
		var vl := UiKit.label(txt, 20, Color("8fe08a") if boosted else UiKit.TEXT)
		vl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(vl)
		cv.add_child(top)
		var nl := UiKit.label(t[1], 13, UiKit.MUTED)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(nl)
		grid.add_child(cell)
	# passive
	var pv: Dictionary = cd.get("passive", {})
	if not pv.is_empty():
		v.add_child(_section("Nội tại"))
		v.add_child(_feature(String(pv.get("id", "")), String(pv.get("name", "")), String(pv.get("desc", ""))))
	# worn items: five slots, dim when empty
	v.add_child(_section("Trang bị"))
	var gear := HBoxContainer.new()
	gear.add_theme_constant_override("separation", 8)
	v.add_child(gear)
	var worn := s.profile.equipped(s.cls)
	const SLOT_NAMES := {"head": "Đầu", "chest": "Ngực", "arms": "Tay", "legs": "Chân", "weapon": "Vũ khí"}
	for slot: String in Profile.SLOTS:
		var cell := UiKit.panel(UiKit.PANEL_DARK, 6, UiKit.GOLD if worn.has(slot) else Color("4a4458"))
		cell.custom_minimum_size = Vector2(52, 52)
		var item_id := String(worn.get(slot, ""))
		var d: Dictionary = _equip_defs.get(item_id, {})
		var rar := String(d.get("rarity", "common"))
		if item_id != "":
			Tip.attach(cell, String(d.get("name", item_id)), String(d.get("desc", "")), UiKit.RARITY.get(rar, UiKit.GOLD),
				String(d.get("icon", item_id)), "%s · %s" % [UiKit.RARITY_NAME.get(rar, rar), SLOT_NAMES.get(slot, slot)])
		else:
			Tip.attach(cell, "%s: trống" % SLOT_NAMES.get(slot, slot), "Mặc đồ ở màn Trang bị (từ sảnh).")
		if item_id != "":
			cell.add_child(UiKit.icon(String(d.get("icon", item_id)), 36.0))
		gear.add_child(cell)
	# actions at the bottom
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var play := UiKit.button("Chơi  ▶", func() -> void:
		if prefs.is_fixed():
			prefs.active_slot = s
		else:
			prefs.select_slot(s.id)
		get_tree().change_scene_to_file(LOBBY_SCENE), Vector2(220, 56), 24, UiKit.PRIMARY)
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(play)
	var rename := UiKit.button("Đổi tên", func() -> void: pass, Vector2(110, 56), 17)
	rename.pressed.connect(func() -> void:
		if not edit.visible:   # first press edits the name in place, the second saves
			edit.visible = true
			name.visible = false
			rename.text = "Lưu"
			edit.grab_focus()
			return
		var n := edit.text.strip_edges()
		if n != "":
			s.name = n
		if not prefs.is_fixed():
			prefs.slot_store().save(s)
		_rebuild())
	row.add_child(rename)
	var del := UiKit.button("Xóa", func() -> void: pass, Vector2(110, 56), 17, UiKit.DANGER)
	del.pressed.connect(func() -> void:
		if del.text == "Xóa":   # asks once more
			del.text = "Chắc chắn?"
			return
		_delete(s.id))
	row.add_child(del)
	play.call_deferred("grab_focus")


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


func _feature(icon: String, title: String, desc: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var box := UiKit.panel(UiKit.PANEL_DARK, 4)
	box.add_child(UiKit.icon(icon, 36.0))
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	v.add_child(UiKit.label(title, 18, UiKit.TEXT))
	var d := UiKit.label(desc, 14, UiKit.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	return row


func _broken_panel(panel: PanelContainer, e: Dictionary) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	v.add_child(UiKit.label("Không đọc được nhân vật %s" % String(e.get("id", "")), 28, Color("ff9a9a")))
	var why := UiKit.label("Lý do: %s. Các nhân vật khác vẫn chơi bình thường. Nhân vật này chỉ có thể xóa." % String(e.get("error", "")), 17, UiKit.MUTED)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(why)
	var del := UiKit.button("Xóa", func() -> void: pass, Vector2(160, 48), 18, UiKit.DANGER)
	del.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	del.pressed.connect(func() -> void:
		if del.text == "Xóa":
			del.text = "Chắc chắn?"
			return
		_delete(String(e.get("id", ""))))
	v.add_child(del)


## Two class cards (hero, role, base stats, passive, starting skill), a name and "Tạo nhân vật".
func _create_panel(panel: PanelContainer) -> void:
	var prefs := Prefs.current()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	v.add_child(UiKit.label("Tạo nhân vật", 30, UiKit.TEXT))
	v.add_child(UiKit.label("Chọn class. Class gắn với nhân vật, không đổi được sau này.", 15, UiKit.MUTED))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 14)
	v.add_child(cards)
	for cid: String in _class_ids:
		cards.add_child(_class_card(cid))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Tên nhân vật (để trống: tự đặt)"
	name_edit.max_length = 18
	name_edit.custom_minimum_size = Vector2(0, 52)
	name_edit.add_theme_font_size_override("font_size", 18)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_edit)
	var make := UiKit.button("Tạo nhân vật  ▶", func() -> void:
		var n := name_edit.text.strip_edges()
		if n == "":
			n = "%s %d" % [String(_classes[_create_class].get("name", "")), _entries.size() + 1]
		if prefs.is_fixed():
			return
		var created := prefs.slot_store().create(n, _create_class)
		if created == null:
			return
		prefs.select_slot(created.id)
		_reload()
		_chosen = created.id
		_rebuild(), Vector2(260, 52), 20, UiKit.PRIMARY)
	row.add_child(make)


func _class_card(cid: String) -> Button:
	var cd: Dictionary = _classes[cid]
	var on := cid == _create_class
	var b := Button.new()
	b.custom_minimum_size = Vector2(383, 372)
	b.focus_mode = Control.FOCUS_ALL
	var acc := _accent(cid)
	b.add_theme_stylebox_override("normal", UiKit.style(acc.darkened(0.72) if on else UiKit.PANEL, 12, Color.WHITE if on else UiKit.GOLD, 3 if on else 2))
	for st in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(st, UiKit.style(acc.darkened(0.6), 12, Color.WHITE, 3))
	b.pressed.connect(func() -> void:
		_create_class = cid
		_rebuild())
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_right = -14
	v.offset_top = 10
	v.offset_bottom = -10
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var hero := _hero_box(cid, Vector2(355, 176), 4.0, 0.6)
	v.add_child(hero)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	var nm := UiKit.label(String(cd.get("name", cid)), 24, UiKit.TEXT)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	var role := UiKit.label(String(cd.get("role", "")), 15, acc.lightened(0.35))
	role.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(role)
	var stats: Dictionary = cd.get("stats", {})
	var sr := HBoxContainer.new()
	sr.add_theme_constant_override("separation", 16)
	sr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sr)
	sr.add_child(UiKit.stat("heart", str(roundi(float(stats.get("max_hp", 0)))), "Máu", 16))
	sr.add_child(UiKit.stat("sword", str(roundi(float(stats.get("damage", 0)))), "Sát thương", 16))
	sr.add_child(UiKit.stat("boot", str(roundi(float(stats.get("move_speed", 0)))), "Tốc độ", 16))
	var pv: Dictionary = cd.get("passive", {})
	v.add_child(UiKit.label("Nội tại: " + String(pv.get("name", "")), 16, UiKit.GOLD))
	var pd := UiKit.label(String(pv.get("desc", "")), 14, UiKit.MUTED)
	pd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(pd)
	var pool := GameData.load_json(DATA + String(cd.get("upgrades", "")))
	var start_names := PackedStringArray()
	for sk: String in cd.get("start_skills", {}):
		for u: Dictionary in pool.get("upgrades", []):
			if String(u.get("id", "")) == sk:
				start_names.append(String(u.get("name", sk)))
	v.add_child(UiKit.label("Chiêu khởi đầu: " + ", ".join(start_names), 15, UiKit.TEXT))
	for c in v.get_children():
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b
