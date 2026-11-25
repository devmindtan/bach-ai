extends Node2D
## The equipment screen of the chosen character (design/ux/equipment.md): a paper
## doll (the hero on a pedestal with the five slots round it and the stats with
## gear under it), the bag of the chosen slot as a list, and the viewed item
## in a fixed layout: name in its rarity colour, rarity · slot · class, text, the
## change against what is worn (▲ green better, ▼ red worse, changed stats only)
## and "Mặc" or "Bỏ ra". Changes are saved at once. Esc goes back to the lobby.
##
## Command line (after `--`), for shots: --equip-slot=<slot>, --equip-view=<item id>, --equip-plus=<0..5>.

const LOBBY_SCENE := "res://src/lobby/lobby.tscn"
const SLOT_NAME := {"head": "Mũ", "chest": "Áo", "legs": "Quần", "arms": "Tay", "feet": "Giày", "weapon": "Vũ khí", "shield": "Khiên", "quiver": "Bao tên"}
const RARITY_NAME := {"common": "Thường", "rare": "Hiếm", "epic": "Sử thi", "legendary": "Huyền thoại"}
const RARITY := {"common": Color("e8e2d0"), "rare": Color("6fb7ff"), "epic": Color("c38df5"), "legendary": Color("f2b64a")}
const UP := Color("8fe08a")
const DOWN := Color("ff8a8a")
## Stats compared and shown: [key, name, format, lower is better]
const STATS := [["max_hp", "Máu tối đa", "%d", false], ["damage", "Sát thương", "%d", false],
	["armor", "Giáp", "%d", false], ["move_speed", "Tốc độ chạy", "%d", false],
	["cooldown", "Hồi chiêu", "×%.2f", true], ["area", "Vùng đánh", "×%.2f", false],
	["magnet", "Tầm hút", "×%.2f", false], ["regen", "Hồi máu", "%.1f/giây", false]]
# where each slot sits round the hero (left column, local to the doll)
const DOLL := Vector2(380, 380)
const CELL := Vector2(76, 76)

var _equip_plus := -1   # --equip-plus (shots)
var _slot_data: Slot
var _prof: Profile
var _cls := ""
var _class := {}
var _hero: SpriteSheet
var _sel := "head"      # the chosen equipment slot
var _view := ""         # the item shown in the detail column
var _filter := "head"   # bag tab: "all" or a slot (follows the chosen slot)
var _sort := "rarity"   # bag order: "rarity" (rarest first) or "new" (newest first)
var _bag_scroll := 0    # keeps the bag's scroll position across rebuilds
var _t := 0.0
var _scroll := Vector2.ZERO
var _layer: CanvasLayer
var _slot_buttons := {}   # slot -> its Button round the hero (lit as a drop target while dragging)
var _drag_lit := false
var _drag_shot := ""   # --equip-drag=<item>


func _ready() -> void:
	Sfx.music("menu")
	var prefs := Prefs.current()
	if prefs.is_fixed():
		prefs.ensure_preview_slot()
	elif prefs.active_slot == null:
		prefs.ensure_slots()
	_slot_data = prefs.active_slot
	if _slot_data == null:
		get_tree().change_scene_to_file.call_deferred("res://src/front/characters.tscn")
		return
	_prof = _slot_data.profile
	_cls = _slot_data.cls
	_class = GameData.load_json("res://assets/data/classes.json").get(_cls, {})
	_hero = FrontArt.hero_sheet(_class, _prof.equipped(_cls).values())
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--equip-slot="):
			_sel = a.get_slice("=", 1)
			_filter = _sel
		elif a == "--equip-all":
			_filter = "all"
		elif a == "--equip-new":
			_sort = "new"
		elif a.begins_with("--equip-view="):
			_view = a.get_slice("=", 1)
		elif a.begins_with("--equip-drag="):   # shots: the slot a dragged bag item fits, lit
			_drag_shot = a.get_slice("=", 1)
		elif a.begins_with("--equip-plus="):   # shots: Cường hoá level of the viewed item
			_equip_plus = int(a.get_slice("=", 1))
	if _equip_plus >= 0 and _view != "":
		_prof.plus[_view] = _equip_plus
	if _view == "":
		_view = _default_view()
	_build()
	if _drag_shot != "":
		_light_target(bag_drag_data(_drag_shot))


func _default_view() -> String:
	var worn := String(_prof.equipped(_cls).get(_sel, ""))
	if worn != "":
		return worn
	var c := _prof.choices(_cls, _sel)
	return String(c[0]) if not c.is_empty() else ""


func _process(delta: float) -> void:
	if _drag_lit and not get_viewport().gui_is_dragging():
		_drag_lit = false
		_rebuild()
	_t += delta
	_scroll += Vector2(18.0, 6.0) * delta
	queue_redraw()


func _draw() -> void:
	FrontArt.backdrop(self, _scroll, get_viewport_rect().size)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(LOBBY_SCENE)


func _rebuild() -> void:
	_slot_buttons.clear()
	if _layer != null:
		_layer.queue_free()
	_hero = FrontArt.hero_sheet(_class, _prof.equipped(_cls).values())   # worn items show on the hero
	_build()


func _build() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	var root := Control.new()
	root.size = get_viewport_rect().size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	var title := UiKit.label("Trang bị · %s" % _slot_data.name, 34, UiKit.GOLD)
	title.position = Vector2(40, 24)
	root.add_child(title)
	var sub := UiKit.label("%s  ·  bấm món để xem · kéo vào ô để mặc, kéo về túi để tháo" % String(_class.get("name", _cls)), 15, UiKit.MUTED)
	sub.position = Vector2(42, 70)
	root.add_child(sub)
	var back := UiKit.button("Quay lại " + UiKit.hint("Esc"), func() -> void: get_tree().change_scene_to_file(LOBBY_SCENE), Vector2(180, 42), 17)
	back.position = Vector2(root.size.x - 40 - 180, 28)
	root.add_child(back)
	_doll(root)
	_bag(root)
	_detail(root)


# --- paper doll ----------------------------------------------------------------

func _doll(root: Control) -> void:
	var panel := UiKit.panel(Color(0.09, 0.08, 0.13, 0.94), 0)
	panel.position = Vector2(40, 104)
	panel.custom_minimum_size = Vector2(DOLL.x + 20, 576)
	panel.size = panel.custom_minimum_size
	root.add_child(panel)
	var doll := Control.new()
	doll.position = Vector2(50, 114)
	doll.size = DOLL
	doll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(doll)
	var hero := Control.new()
	hero.position = Vector2(80, 0)
	hero.size = Vector2(220, 300)
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	doll.add_child(hero)
	var col := Color(String(_class.get("color", "c9a65a")))
	hero.draw.connect(func() -> void:
		FrontArt.pedestal(hero, Vector2(110, 250), col, _t, 0.62)
		if _hero != null:
			_hero.draw(hero, "idle", _t, Vector2(110, 250), FrontArt.scale_of(_hero, 5.0)))
	var tick := Timer.new()   # the hero idles and the ring turns
	tick.wait_time = 1.0 / 15.0
	tick.autostart = true
	tick.timeout.connect(hero.queue_redraw)
	hero.add_child(tick)
	var worn := _prof.equipped(_cls)
	var slots := Profile.slots_for(_cls)
	for i in slots.size():   # the class's own slots: the first half down the left, the rest down the right
		var slot := String(slots[i])
		var cell := _slot_cell(slot, String(worn.get(slot, "")))
		var half := ceili(slots.size() / 2.0)
		cell.position = Vector2(0 if i < half else 300, 20 + 110 * (i if i < half else i - half))
		doll.add_child(cell)
	# stats with the worn gear
	var base: Dictionary = _class.get("stats", {})
	var st := _stats_with(worn)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.position = Vector2(54, 590)
	root.add_child(grid)
	for t in [["heart", "Máu", "max_hp", "%d"], ["sword", "Sát thương", "damage", "%d"],
			["boot", "Tốc độ", "move_speed", "%d"], ["magnet", "Tầm hút", "magnet", "×%.1f"]]:
		var val := float(st.get(t[2], 0.0))
		var txt: String = (t[3] % roundi(val)) if t[3] == "%d" else (t[3] % val)
		var c := UiKit.panel(UiKit.PANEL_DARK, 6, Color("4a4458"))
		c.custom_minimum_size = Vector2(88, 0)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		c.add_child(v)
		var top := HBoxContainer.new()
		top.alignment = BoxContainer.ALIGNMENT_CENTER
		top.add_theme_constant_override("separation", 4)
		top.add_child(UiKit.icon(t[0], 18.0))
		var boosted := not is_equal_approx(val, float(base.get(t[2], val)))
		var vl := UiKit.label(txt, 18, UP if boosted else UiKit.TEXT)
		vl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(vl)
		v.add_child(top)
		var nl := UiKit.label(t[1], 12, UiKit.MUTED)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nl)
		grid.add_child(c)


## A slot round the hero: its item (rarity frame) or an empty dim frame, the slot
## name under it; the chosen slot has a white frame.
func _slot_cell(slot: String, item: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var b := Button.new()
	b.custom_minimum_size = CELL
	b.focus_mode = Control.FOCUS_ALL
	var d: Dictionary = _prof.defs.get(item, {})
	var frame: Color = RARITY.get(String(d.get("rarity", "common")), UiKit.GOLD) if item != "" else Color("4a4458")
	if slot == _sel:
		frame = Color.WHITE
	if item != "":
		var rr := String(d.get("rarity", "common"))
		b.add_theme_stylebox_override("normal", UiKit.rarity_style(rr, true, slot == _sel, 6))
		UiKit.rarity_corners(b, rr)   # no gem on the small cell (user 2026-11-20): the detail shows it
	else:
		b.add_theme_stylebox_override("normal", UiKit.style(UiKit.PANEL_DARK, 6, frame, 3 if slot == _sel else 2))
	for st in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(st, UiKit.style(UiKit.PANEL_HOVER, 6, Color.WHITE, 3))
	if item != "":
		var rar := String(d.get("rarity", "common"))
		Tip.attach(b, String(d.get("name", item)), String(d.get("desc", "")), RARITY.get(rar, UiKit.GOLD),
			String(d.get("icon", item)), "%s · %s" % [RARITY_NAME.get(rar, rar), SLOT_NAME[slot]])
	else:
		Tip.attach(b, "%s: trống" % SLOT_NAME[slot], "Chọn ô này rồi chọn món trong túi để mặc.")
	if item != "":
		var ic := UiKit.icon(String(d.get("icon", item)), 48.0)   # 24 px icon x2
		ic.position = (CELL - ic.custom_minimum_size) * 0.5   # no anchors: a Button is not a container
		ic.size = ic.custom_minimum_size
		b.add_child(ic)
	b.pressed.connect(func() -> void:
		_sel = slot
		_filter = slot
		_view = _default_view()
		_rebuild())
	b.set_drag_forwarding(func(_p: Vector2) -> Variant: return _start_drag(b, slot_drag_data(slot)),
		func(_p: Vector2, data: Variant) -> bool: return can_drop_on_slot(slot, data),
		func(_p: Vector2, data: Variant) -> void: drop_on_slot(slot, data))
	_slot_buttons[slot] = b
	box.add_child(b)
	var l := UiKit.label(SLOT_NAME[slot], 14, UiKit.TEXT if slot == _sel else UiKit.MUTED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(CELL.x, 0)
	box.add_child(l)
	if slot == _sel:
		b.call_deferred("grab_focus")
	return box


# --- bag -----------------------------------------------------------------------
# Inventory practice (design/ux/equipment.md): a few type tabs, a visible sort,
# a badge on new items until seen, and an upgrade mark against what is worn.

const TABS := [["all", "Tất cả"], ["head", "Mũ"], ["chest", "Áo"], ["legs", "Quần"], ["arms", "Tay"], ["feet", "Giày"], ["weapon", "Vũ khí"]]
const ORDER := ["legendary", "epic", "rare", "common"]
const MIXED := Color("f2c14e")
const GOLD_COLOR_FALLBACK := Color("c9a65a")
const BAG_COLS := 5
const BAG_GAP := 9
const BAG_CELL := Vector2(64, 64)
const DROP_OK := Color("8fe08a")


## The bag's type tabs for this class: "Tất cả" then one per slot it wears.
func _tabs() -> Array:
	var out := [["all", "Tất cả"]]
	for slot: Variant in Profile.slots_for(_cls):
		out.append([String(slot), String(SLOT_NAME.get(String(slot), slot))])
	return out


func _bag(root: Control) -> void:
	var panel := UiKit.panel(Color(0.09, 0.08, 0.13, 0.94), 16)
	panel.position = Vector2(456, 104)   # 16 px gaps between the three columns
	panel.custom_minimum_size = Vector2(388, 576)
	panel.size = panel.custom_minimum_size
	root.add_child(panel)
	panel.set_drag_forwarding(Callable(), func(_p: Vector2, data: Variant) -> bool: return can_drop_on_bag(data),
		func(_p: Vector2, data: Variant) -> void: drop_on_bag(data))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var ids := _bag_ids()
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := UiKit.label("Túi đồ", 22, UiKit.TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var count := UiKit.label("%d món" % ids.size(), 15, UiKit.MUTED)
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(count)
	# type tabs
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	v.add_child(tabs)
	for t in _tabs():
		tabs.add_child(_pill(t[1], _filter == t[0], func() -> void:
			_filter = t[0]
			if t[0] != "all":
				_sel = t[0]
				_view = _default_view()
			_bag_scroll = 0
			_rebuild(), 0.0))
		tabs.get_child(tabs.get_child_count() - 1).size_flags_horizontal = Control.SIZE_EXPAND_FILL   # 7 tabs share the column
	# sort, the active one highlighted
	var sort := HBoxContainer.new()
	sort.add_theme_constant_override("separation", 4)
	v.add_child(sort)
	var sl := UiKit.label("Xếp theo", 13, UiKit.MUTED)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sort.add_child(sl)
	for o in [["rarity", "Độ hiếm"], ["new", "Mới nhất"]]:
		sort.add_child(_pill(o[1], _sort == o[0], func() -> void:
			_sort = o[0]
			_rebuild(), 84.0))
	if ids.is_empty():
		var none := UiKit.label("Chưa có đồ ở đây. Thắng ải hoặc mở rương tinh anh để nhận thêm.", 15, UiKit.MUTED)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size = Vector2(350, 0)
		v.add_child(none)
		return
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(356, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := GridContainer.new()   # icons only: the detail column already shows the text
	list.columns = BAG_COLS
	list.add_theme_constant_override("h_separation", BAG_GAP)
	list.add_theme_constant_override("v_separation", BAG_GAP)
	scroll.add_child(list)
	for id: String in ids:
		list.add_child(_bag_cell(id))
	scroll.scroll_vertical = _bag_scroll
	scroll.get_v_scroll_bar().value_changed.connect(func(val: float) -> void: _bag_scroll = int(val))


## Owned items the class can wear in the current tab, in the current order
## (the same item owned twice is one row with ×2).
func _bag_ids() -> Array:
	var ids := []
	for slot: String in Profile.slots_for(_cls):
		if _filter == "all" or _filter == slot:
			for id: Variant in _prof.choices(_cls, slot):
				ids.append(String(id))
	if _sort == "new":
		ids.sort_custom(func(a: String, b: String) -> bool: return _prof.bag.rfind(a) > _prof.bag.rfind(b))
	else:
		ids.sort_custom(func(a: String, b: String) -> bool:
			var ra := ORDER.find(String(_prof.defs.get(a, {}).get("rarity", "common")))
			var rb := ORDER.find(String(_prof.defs.get(b, {}).get("rarity", "common")))
			return ra < rb if ra != rb else String(_prof.defs.get(a, {}).get("name", a)) < String(_prof.defs.get(b, {}).get("name", b)))
	return ids


func _pill(text: String, on: bool, cb: Callable, w: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 30)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", UiKit.TEXT if on else UiKit.MUTED)
	b.add_theme_stylebox_override("normal", UiKit.style(UiKit.PANEL_HOVER if on else UiKit.PANEL_DARK, 4, UiKit.GOLD if on else Color("3a3448"), 2 if on else 1))
	for st in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(st, UiKit.style(UiKit.PANEL_HOVER, 4, Color.WHITE, 2))
	b.pressed.connect(cb)
	return b


## How item [param id] compares with what is worn in its slot: 1 better, -1 worse,
## 0 mixed or equal, 2 when it is the worn one.
func _verdict(id: String) -> int:
	var slot := String(_prof.defs.get(id, {}).get("slot", ""))
	var worn := _prof.equipped(_cls)
	if String(worn.get(slot, "")) == id:
		return 2
	var after := worn.duplicate()
	after[slot] = id
	var a := _stats_with(worn)
	var b := _stats_with(after)
	var up := 0
	var down := 0
	for s in STATS:
		var x := float(a.get(s[0], 0.0))
		var y := float(b.get(s[0], 0.0))
		if is_equal_approx(x, y):
			continue
		if (y < x) if s[3] else (y > x):
			up += 1
		else:
			down += 1
	return 1 if up > 0 and down == 0 else (-1 if down > 0 and up == 0 else 0)


## One owned item as a square cell: the icon in its rarity frame and, top right, "+n" once enhanced
## (user 2026-11-19: the detail column already shows the text). Click: view it; drag it onto the
## matching slot round the hero: wear it.
func _bag_cell(id: String) -> Button:
	var d: Dictionary = _prof.defs.get(id, {})
	var rarity := String(d.get("rarity", "common"))
	var col: Color = RARITY.get(rarity, UiKit.TEXT)
	var b := Button.new()
	b.custom_minimum_size = BAG_CELL
	b.focus_mode = Control.FOCUS_ALL
	var on := id == _view
	b.add_theme_stylebox_override("normal", UiKit.rarity_style(rarity, true, on, 4))   # shared tier frame (design/card-rarity.md)
	for st in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(st, UiKit.rarity_style(rarity, true, true, 4))
	UiKit.rarity_corners(b, rarity)   # no gem here: the cell is too small (user 2026-11-20); the detail shows it
	Tip.attach(b, String(d.get("name", id)), String(d.get("desc", "")), col, String(d.get("icon", id)),
		"%s · %s" % [RARITY_NAME.get(rarity, rarity), SLOT_NAME.get(String(d.get("slot", "")), "")])
	var ic := UiKit.icon(String(d.get("icon", id)), 48.0)
	ic.position = (BAG_CELL - ic.custom_minimum_size) * 0.5   # a Button is not a container
	ic.size = ic.custom_minimum_size
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	var plus := plus_text(id)
	if plus != "":
		var tag := _badge(plus, Color("f2c14e"))
		var sb: StyleBoxFlat = tag.get_theme_stylebox("panel").duplicate()
		sb.bg_color = Color("16131e")   # opaque: the icon must not show through the number
		tag.add_theme_stylebox_override("panel", sb)
		tag.position = Vector2(BAG_CELL.x - 30, 2)
		b.add_child(tag)
	b.pressed.connect(func() -> void:
		_view = id
		_sel = String(d.get("slot", _sel))
		_rebuild())
	b.set_drag_forwarding(func(_p: Vector2) -> Variant: return _start_drag(b, bag_drag_data(id)), Callable(), Callable())
	return b


## "+n" for an enhanced item, "" otherwise (the bag cell's corner mark).
func plus_text(id: String) -> String:
	var n := _prof.plus_of(id)
	return "+%d" % n if n > 0 else ""


func bag_drag_data(id: String) -> Dictionary:
	return {"from": "bag", "item": id, "slot": String(_prof.defs.get(id, {}).get("slot", ""))}


## What dragging slot [param slot] carries: its worn item, or {} when it is empty.
func slot_drag_data(slot: String) -> Dictionary:
	var item := String(_prof.equipped(_cls).get(slot, ""))
	return {} if item == "" else {"from": "slot", "item": item, "slot": slot}


func can_drop_on_slot(slot: String, data: Variant) -> bool:
	return data is Dictionary and String(data.get("from", "")) == "bag" and String(data.get("slot", "")) == slot


## Wears the dragged bag item when it fits [param slot]; true when it did.
func drop_on_slot(slot: String, data: Variant) -> bool:
	if not can_drop_on_slot(slot, data) or not _prof.equip(_cls, String(data["item"])):
		return false
	Sfx.play("buy")
	_sel = slot
	_view = String(data["item"])
	_after_change()
	return true


func can_drop_on_bag(data: Variant) -> bool:
	return data is Dictionary and String(data.get("from", "")) == "slot"


## Takes the dragged worn item off; true when it did.
func drop_on_bag(data: Variant) -> bool:
	if not can_drop_on_bag(data):
		return false
	_prof.unequip(_cls, String(data["slot"]))
	_after_change()
	return true


func _after_change() -> void:
	if is_inside_tree():
		Prefs.current().save_profile()
		_hero = FrontArt.hero_sheet(_class, _prof.equipped(_cls).values())
		_rebuild.call_deferred()   # not during the drop callback of a control being freed


## Starts a drag of [param data] with the item's icon under the cursor and lights the slot it fits.
func _start_drag(from: Control, data: Dictionary) -> Variant:
	if data.is_empty():
		return null
	var d: Dictionary = _prof.defs.get(String(data["item"]), {})
	var ic := UiKit.icon(String(d.get("icon", data["item"])), 48.0)
	ic.modulate = Color(1, 1, 1, 0.85)
	var holder := Control.new()
	holder.add_child(ic)
	ic.position = -ic.custom_minimum_size * 0.5
	from.set_drag_preview(holder)
	_light_target(data)
	_drag_lit = true
	return data


## Lights the slot round the hero that a dragged bag item fits (green frame).
func _light_target(data: Dictionary) -> void:
	if String(data.get("from", "")) == "bag" and _slot_buttons.has(String(data.get("slot", ""))):
		var b: Button = _slot_buttons[String(data["slot"])]
		b.add_theme_stylebox_override("normal", UiKit.style(Color(DROP_OK, 0.15).blend(UiKit.PANEL_DARK), 6, DROP_OK, 4))


## A small rounded label (MỚI, Đang mặc).
func _badge(text: String, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UiKit.style(Color(col, 0.18), 0, col, 1)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiKit.label(text, 12, col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p


# --- detail ----------------------------------------------------------------------

## The viewed item, paper doll of its own effect: big rarity frame, name in its
## rarity colour, desc, the stats it changes against the worn one (only the lines
## that change), the action button (Mặc / Bỏ ra). Vertical space is filled with
## the banner, not left empty.
func _detail(root: Control) -> void:
	var panel := UiKit.panel(Color(0.09, 0.08, 0.13, 0.94), 16, GOLD_COLOR_FALLBACK)
	panel.position = Vector2(860, 104)
	panel.custom_minimum_size = Vector2(380, 576)
	panel.size = panel.custom_minimum_size
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.alignment = BoxContainer.ALIGNMENT_BEGIN   # top-down (AGENTS.md: never centre card content vertically)
	panel.add_child(v)
	if _view == "" or not _prof.defs.has(_view):
		var l := UiKit.label("Chọn một món trong túi để xem.", 17, UiKit.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
		return
	var d: Dictionary = _prof.defs[_view]
	if _prof.is_new(_view):   # looked at: no longer new (the bag shows it on the next rebuild)
		_prof.mark_seen(_view)
		Prefs.current().save_profile()
	var rarity := String(d.get("rarity", "common"))
	var rarity_col: Color = RARITY.get(rarity, UiKit.GOLD)
	# banner: the item, big, in its rarity frame
	var banner := PanelContainer.new()
	var bstyle := UiKit.style(UiKit.PANEL_DARK, 6, rarity_col, 2)
	bstyle.set_corner_radius_all(10)
	banner.add_theme_stylebox_override("panel", bstyle)
	banner.custom_minimum_size = Vector2(0, 150)   # room for Dòng phụ / Hiệu ứng đặc biệt below
	v.add_child(banner)
	var bv := VBoxContainer.new()
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.add_theme_constant_override("separation", 2)
	banner.add_child(bv)
	var big_ic := UiKit.icon(String(d.get("icon", _view)), 72.0)   # 24 px icon x3
	big_ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bv.add_child(big_ic)
	# name over the icon area, rarity-tinted
	var lv := _prof.plus_of(_view)
	var name := UiKit.label(String(d.get("name", _view)) + ("  +%d" % lv if lv > 0 else ""), 22, rarity_col)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bv.add_child(name)
	# rarity stripe: label in rarity colour, slot class restricted
	var badge := UiKit.rarity_badge(rarity, 14)   # the tier's gem + name, the bag cells only show the frame
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bv.add_child(badge)
	var meta := ""
	var who := ""
	if d.has("class"):
		who = "  ·  chỉ " + String(GameData.load_json("res://assets/data/classes.json").get(String(d["class"]), {}).get("name", d["class"]))
	meta = String(SLOT_NAME.get(String(d.get("slot", "")), "")) + who
	var ml := UiKit.label(meta, 12, UiKit.MUTED)
	ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ml.custom_minimum_size = Vector2(320, 0)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ml.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bv.add_child(ml)
	# the text part scrolls; Cường hoá and Mặc stay pinned at the bottom (a legendary
	# with dòng phụ, hiệu ứng đặc biệt and five stat rows pushed Mặc off the panel)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	var desc := UiKit.label(String(d.get("desc", "")), 16, UiKit.TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(desc)
	_unlock_lines(body, d, _view)
	# change against what is worn in this slot
	var worn := _prof.equipped(_cls)
	var is_worn := String(worn.get(_sel, "")) == _view
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	var cmp_label := UiKit.label("Đang mặc: thay đổi nếu tháo" if is_worn else "So với đang mặc", 15, UiKit.GOLD)
	cmp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cmp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cmp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(cmp_label)
	body.add_child(head)
	var after := worn.duplicate()
	if is_worn:
		after.erase(_sel)
	else:
		after[_sel] = _view
	var now := _stats_with(worn)
	var then := _stats_with(after)
	var rows := GridContainer.new()
	rows.columns = 3
	rows.add_theme_constant_override("h_separation", 14)
	rows.add_theme_constant_override("v_separation", 6)
	body.add_child(rows)
	var changed := 0
	for s in STATS:
		var a := float(now.get(s[0], 0.0))
		var b := float(then.get(s[0], 0.0))
		if is_equal_approx(a, b):
			continue
		changed += 1
		var better: bool = (b < a) if s[3] else (b > a)
		rows.add_child(UiKit.label(s[1], 15, UiKit.TEXT))
		rows.add_child(UiKit.label("%s → %s" % [_fmt(s[2], a), _fmt(s[2], b)], 15, UiKit.TEXT))
		rows.add_child(UiKit.label("▲" if better else "▼", 15, UP if better else DOWN))
	if changed == 0:
		body.add_child(UiKit.label("Không đổi chỉ số nào.", 15, UiKit.MUTED))
	var prefs := Prefs.current()
	# Cường hoá: +1..+5 with gold, each level +20% of the item's effects
	var el := UiKit.label("Cường hoá +%d/%d  ·  mỗi bậc +%d%% hiệu ứng" % [lv, _prof.max_plus(_view), roundi(Profile.PLUS_STEP * 100)], 14, UiKit.MUTED)
	el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(el)   # a line of its own: beside the button it pushed the column off screen
	var cost := _prof.enhance_cost(_view)
	var eb := UiKit.button(("Cường hoá  %d vàng" % cost) if cost > 0 else "Đã tối đa", func() -> void:
		var wallet := {"v": _slot_data.gold}
		if _prof.enhance(_view, wallet):
			Sfx.play("enhance")
			Daily.load_default().add(_slot_data, "enhances", 1)
			_slot_data.gold = int(wallet["v"])
			prefs.save_profile()
			_rebuild(), Vector2(0, 40), 15)
	eb.disabled = cost <= 0 or _slot_data.gold < cost
	if cost > 0 and _slot_data.gold < cost:
		Tip.attach(eb, "Thiếu vàng", "Cần %d vàng, đang có %d." % [cost, _slot_data.gold])
	eb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(eb)
	var act := UiKit.button("Bỏ ra" if is_worn else "Mặc  ▶", func() -> void:
		if is_worn:
			_prof.unequip(_cls, _sel)
		else:
			_prof.equip(_cls, _view)
			Sfx.play("buy")
		prefs.save_profile()
		_rebuild(), Vector2(0, 56), 22, UiKit.PANEL if is_worn else UiKit.PRIMARY)
	act.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(act)


func _fmt(f: String, x: float) -> String:
	return f % roundi(x) if f == "%d" else f % x


## Stats of the class with [param worn] ({slot: item id}) on.
## The skill tree counts too, so the numbers match the lobby's.
func _stats_with(worn: Dictionary) -> Dictionary:
	var lasting := SkillTree.lasting(_slot_data, worn)
	return PlayerStats.compute(_class.get("stats", {}), lasting[0], lasting[1])


## Dòng phụ and Hiệu ứng đặc biệt of item [param id] (design/equipment.md): the
## unlocked ones in colour, the locked ones muted with the Cường hoá level that opens them.
func _unlock_lines(v: VBoxContainer, d: Dictionary, id: String) -> void:
	# Dòng phụ, one line each, opening one by one at Profile.SUB_AT (user 2026-11-20: items carry no skills;
	# a higher tier only reaches a higher level and opens more sub lines)
	var subs := _prof.subs_of(id)
	var open_n := _prof.open_subs(id)
	for k in subs.size():
		var on := k < open_n
		var at := int(Profile.SUB_AT[mini(k, Profile.SUB_AT.size() - 1)])
		var text := "Dòng phụ %d: %s" % [k + 1, String(subs[k].get("desc", ""))] + ("" if on else "  (mở ở +%d)" % at)
		var l := UiKit.label(text, 14, UP if on else UiKit.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(l)
