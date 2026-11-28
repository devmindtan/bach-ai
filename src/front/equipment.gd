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
const RARITY := {"common": Color("6a6a6a"), "rare": Color("3a6aaa"), "epic": Color("7a3ab8"), "legendary": Color("c0801a")}   # ink on paper (journal)
const UP := Color("2a7a3a")
const DOWN := Journal.INK_RED
const LEFT_PAGE := Rect2(110, 74, 470, 572)    # inside the book's dashed frames
const RIGHT_PAGE := Rect2(660, 74, 470, 572)
## Stats compared and shown: [key, name, format, lower is better]
const STATS := [["max_hp", "Máu tối đa", "%d", false], ["damage", "Sát thương", "%d", false],
	["armor", "Giáp", "%d", false], ["move_speed", "Tốc độ chạy", "%d", false],
	["cooldown", "Hồi chiêu", "×%.2f", true], ["area", "Vùng đánh", "×%.2f", false],
	["regen", "Hồi máu", "%.1f/giây", false], ["magnet", "Tầm hút", "×%.2f", false]]
## each stat's icon (the lobby's STAT_ROWS icons; web screen-equipment-journal ?view=full, approved 2026-11-28)
const STAT_ICON := {"max_hp": "heart", "damage": "sword", "armor": "shield", "move_speed": "boot", "cooldown": "haste",
	"area": "reach", "regen": "regen", "magnet": "magnet"}
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
		elif a == "--equip-enhance":   # shots: the Cường hoá sheet open
			_toggle_enhance.call_deferred()
		elif a.begins_with("--equip-plus="):   # shots: Cường hoá level of the viewed item
			_equip_plus = int(a.get_slice("=", 1))
	if _equip_plus >= 0 and _view != "":
		_prof.plus[_view] = _equip_plus
	if _view == "":
		_view = _default_view()
	_build()
	if "--note-shot" in OS.get_cmdline_user_args():   # shots: the corner notes (web screen-notices ?view=toast)
		_note_worn(_view, true)
		Notice.note("Thiếu vàng", "Cần 240 vàng, đang có 120", UiIcons.texture("coin"), true)
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


func _draw() -> void:
	Journal.draw_desk(self, get_viewport_rect().size)
	Journal.draw_book(self, Journal.BOOK)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _enh_layer != null:
		_toggle_enhance()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(LOBBY_SCENE)
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_C:
		_toggle_enhance()
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode in [KEY_Q, KEY_E]:
		var slots := Profile.slots_for(_cls)   # Q / E: the previous / next slot (web hint)
		var i := slots.find(_sel)
		_sel = String(slots[posmod(i + (1 if (event as InputEventKey).physical_keycode == KEY_E else -1), slots.size())])
		_filter = _sel
		_view = _default_view()
		_rebuild()


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
	Journal.back_tab(root, func() -> void: get_tree().change_scene_to_file(LOBBY_SCENE))   # "Trở lại" (web .back-tab)
	var title := Journal.ink("Trang bị", 44)
	title.position = LEFT_PAGE.position + Vector2(0, -8)
	root.add_child(title)
	var sub := Journal.ink("%s · %s" % [_slot_data.name, String(_class.get("name", _cls))], 20, Journal.INK_RED)
	sub.position = LEFT_PAGE.position + Vector2(2, 48)
	root.add_child(sub)
	var hint := Journal.ink("←↑↓→ chọn món · Q / E đổi chỗ mặc · Enter mặc · Esc về sổ", 15, Journal.PAPER)
	hint.position = Vector2(Journal.BOOK.position.x, Journal.BOOK.end.y + 14)
	root.add_child(hint)
	_doll(root)
	_bag(root)
	_detail(root)


# --- paper doll ----------------------------------------------------------------

func _doll(root: Control) -> void:
	var doll := Control.new()
	doll.position = LEFT_PAGE.position + Vector2(45, 78)
	doll.size = DOLL
	doll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(doll)
	var hero := Control.new()   # the portrait: a sketch box, the hero idling in it
	hero.position = Vector2(100, 30)
	hero.size = Vector2(180, 250)
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	doll.add_child(hero)
	hero.draw.connect(func() -> void:
		hero.draw_rect(Rect2(Vector2.ZERO, hero.size), Color("d8c498"))
		hero.draw_rect(Rect2(Vector2.ZERO, hero.size), Journal.EDGE, false, 4.0)
		if _hero != null:
			_hero.draw(hero, "idle", _t, Vector2(90, 220), FrontArt.scale_of(_hero, 4.0)))
	var tick := Timer.new()   # the hero idles
	tick.wait_time = 1.0 / 12.0
	tick.autostart = true
	tick.timeout.connect(hero.queue_redraw)
	hero.add_child(tick)
	var worn := _prof.equipped(_cls)
	var slots := Profile.slots_for(_cls)
	for i in slots.size():   # the class's own slots: the first half down the left, the rest down the right
		var slot := String(slots[i])
		var cell := _slot_cell(slot, String(worn.get(slot, "")))
		var half := ceili(slots.size() / 2.0)
		cell.position = Vector2(0 if i < half else 300, 110 * (i if i < half else i - half))
		doll.add_child(cell)
	# stats with the worn gear: a two-column ledger under the doll
	var base: Dictionary = _class.get("stats", {})
	var st := _stats_with(worn)
	var grid := GridContainer.new()   # web ?view=full: eight stats with icons in two columns
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 0)
	grid.position = LEFT_PAGE.position + Vector2(0, 416)
	root.add_child(grid)
	for s in STATS:
		var val := float(st.get(s[0], 0.0))
		var boosted := not is_equal_approx(val, float(base.get(s[0], val)))
		var row := Journal.ledger(String(STAT_ICON[s[0]]), String(s[1]), _fmt(s[2], val), 17, UP if boosted else Journal.INK)
		row.custom_minimum_size.x = (LEFT_PAGE.size.x - 22) * 0.5
		grid.add_child(row)


## A slot round the hero: its item (rarity frame) or an empty dim frame, the slot
## name under it; the chosen slot has a white frame.
func _slot_cell(slot: String, item: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var b := Button.new()
	b.custom_minimum_size = CELL
	b.focus_mode = Control.FOCUS_ALL
	var d: Dictionary = _prof.defs.get(item, {})
	var frame: Color = RARITY.get(String(d.get("rarity", "common")), Journal.INK) if item != "" else Journal.INK
	_sketch_styles(b, frame, slot == _sel)
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
	var l := Journal.ink(SLOT_NAME[slot], 18, Journal.INK_RED if slot == _sel else Journal.INK)
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
const BAG_COLS := 6
const BAG_GAP := 12
const BAG_CELL := Vector2(64, 64)
const DROP_OK := Color("2a7a3a")


## The bag's type tabs for this class: "Tất cả" then one per slot it wears.
func _tabs() -> Array:
	var out := [["all", "Tất cả"]]
	for slot: Variant in Profile.slots_for(_cls):
		out.append([String(slot), String(SLOT_NAME.get(String(slot), slot))])
	return out


func _bag(root: Control) -> void:
	var panel := Control.new()   # the right page's top: a drop target for worn items
	panel.position = RIGHT_PAGE.position + Vector2(0, -8)
	panel.size = Vector2(RIGHT_PAGE.size.x, _bag_height())
	root.add_child(panel)
	panel.set_drag_forwarding(Callable(), func(_p: Vector2, data: Variant) -> bool: return can_drop_on_bag(data),
		func(_p: Vector2, data: Variant) -> void: drop_on_bag(data))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.size = panel.size
	panel.add_child(v)
	var ids := _bag_ids()
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := Journal.ink("Túi đồ", 36)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var count := Journal.ink("%d món" % ids.size(), 18, Journal.INK_SOFT)
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(count)
	# type tabs, then the sort
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
		tabs.get_child(tabs.get_child_count() - 1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sort := HBoxContainer.new()
	sort.add_theme_constant_override("separation", 4)
	v.add_child(sort)
	var sl := Journal.ink("Xếp theo", 16, Journal.INK_SOFT)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sort.add_child(sl)
	for o in [["rarity", "Độ hiếm"], ["new", "Mới nhất"]]:
		sort.add_child(_pill(o[1], _sort == o[0], func() -> void:
			_sort = o[0]
			_rebuild(), 96.0))
	if ids.is_empty():
		var none := Journal.ink("Chưa có đồ ở đây. Thắng ải hoặc mở rương tinh anh để nhận thêm.", 18, Journal.INK_SOFT)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size = Vector2(RIGHT_PAGE.size.x, 0)
		v.add_child(none)
		return
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := GridContainer.new()   # icons only: the detail below shows the text
	list.columns = BAG_COLS
	list.add_theme_constant_override("h_separation", BAG_GAP)
	list.add_theme_constant_override("v_separation", BAG_GAP)
	scroll.add_child(list)
	for id: String in ids:
		list.add_child(_bag_cell(id))
	scroll.scroll_vertical = _bag_scroll
	scroll.get_v_scroll_bar().value_changed.connect(func(val: float) -> void: _bag_scroll = int(val))


## The bag's height on the page: the header, tabs and sort, then its rows of cells (1..2; more scroll).
func _bag_height() -> float:
	var rows := clampi(ceili(_bag_ids().size() / float(BAG_COLS)), 1, 2)
	return 126.0 + rows * (BAG_CELL.y + BAG_GAP)


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
	b.add_theme_font_size_override("font_size", 17)
	for st in ["normal", "hover", "focus", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Journal.INK if on else Color(0, 0, 0, 0)
		sb.border_color = Journal.INK_RED if st != "normal" else Journal.INK
		sb.set_border_width_all(2)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Journal.PAPER if on else Journal.INK)
	for k in ["font_focus_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Journal.GOLD if on else Journal.INK_RED)
	b.pressed.connect(cb)
	return b


## A sketch cell on the page: paper fill, a frame in [param frame] (rarity ink); chosen/focused: ink fill, gold frame.
func _sketch_styles(b: Button, frame: Color, on: bool) -> void:
	for st in ["normal", "hover", "focus", "pressed"]:
		var lit: bool = on or st != "normal"
		var sb := StyleBoxFlat.new()
		sb.bg_color = Journal.INK if on else Journal.SKETCH
		sb.border_color = Journal.GOLD if lit else frame
		sb.set_border_width_all(4 if lit else 3)
		b.add_theme_stylebox_override(st, sb)
	b.mouse_entered.connect(func() -> void: b.grab_focus())


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
	var col: Color = RARITY.get(rarity, Journal.INK)
	var b := Button.new()
	b.custom_minimum_size = BAG_CELL
	b.focus_mode = Control.FOCUS_ALL
	_sketch_styles(b, col, id == _view)   # the frame's ink is the rarity (journal: r1..r4)
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
		sb.bg_color = Journal.INK   # opaque: the icon must not show through the number
		tag.add_theme_stylebox_override("panel", sb)
		tag.position = Vector2(BAG_CELL.x - 30, 2)
		b.add_child(tag)
	if _prof.equipped(_cls).values().has(id):   # worn: a gold tick on the top-left corner (web .wr)
		var tick := _badge("✓", Journal.INK)
		var tb: StyleBoxFlat = tick.get_theme_stylebox("panel").duplicate()
		tb.bg_color = Journal.GOLD
		tb.border_color = Journal.INK
		tb.set_border_width_all(2)
		tick.add_theme_stylebox_override("panel", tb)
		tick.position = Vector2(-4, -6)
		b.add_child(tick)
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
	_note_worn(String(data["item"]), true)
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
	var off := String(_prof.equipped(_cls).get(String(data["slot"]), ""))
	_prof.unequip(_cls, String(data["slot"]))
	_note_worn(off, false)
	_after_change()
	return true


func _item_name(id: String) -> String:
	return String(_prof.defs.get(id, {}).get("name", id))


func _item_icon(id: String) -> String:
	return String(_prof.defs.get(id, {}).get("icon", id))


## The corner note after wearing / taking off [param id] (web screen-notices ?view=toast).
func _note_worn(id: String, on: bool) -> void:
	if id == "":
		return
	Notice.note(("Đã mặc %s" if on else "Đã bỏ ra %s") % _item_name(id), SLOT_NAME.get(String(_prof.defs.get(id, {}).get("slot", "")), ""),
		UiIcons.texture(_item_icon(id)))


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
		var sb := StyleBoxFlat.new()
		sb.bg_color = Journal.SKETCH
		sb.border_color = DROP_OK
		sb.set_border_width_all(5)
		b.add_theme_stylebox_override("normal", sb)


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
	var top := _bag_height() - 4.0
	var box := Rect2(RIGHT_PAGE.position + Vector2(0, top), Vector2(RIGHT_PAGE.size.x, RIGHT_PAGE.size.y - top))
	var v := VBoxContainer.new()
	v.position = box.position
	v.size = box.size
	v.add_theme_constant_override("separation", 6)
	v.alignment = BoxContainer.ALIGNMENT_BEGIN   # top-down (AGENTS.md: never centre card content vertically)
	root.add_child(v)
	v.add_child(Journal.dotted())
	if _view == "" or not _prof.defs.has(_view):
		var l := Journal.ink("Chọn một món trong túi để xem.", 20, Journal.INK_SOFT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
		return
	var d: Dictionary = _prof.defs[_view]
	if _prof.is_new(_view):   # looked at: no longer new (the bag shows it on the next rebuild)
		_prof.mark_seen(_view)
		Prefs.current().save_profile()
	var rarity := String(d.get("rarity", "common"))
	var rarity_col: Color = RARITY.get(rarity, Journal.INK)
	var lv := _prof.plus_of(_view)
	# head: the item in a sketch box, its name, rarity stamp and slot
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	v.add_child(head)
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(72, 72)
	cell.draw.connect(func() -> void:
		cell.draw_rect(Rect2(Vector2.ZERO, cell.custom_minimum_size), Journal.SKETCH)
		cell.draw_rect(Rect2(Vector2.ZERO, cell.custom_minimum_size), rarity_col, false, 4.0))
	var big_ic := UiKit.icon(String(d.get("icon", _view)), 48.0)
	big_ic.position = Vector2(12, 12)
	cell.add_child(big_ic)
	head.add_child(cell)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	var nrow := HBoxContainer.new()   # the name and, beside it, the rarity as an ink stamp (web .stamp)
	nrow.add_theme_constant_override("separation", 10)
	hv.add_child(nrow)
	var name := Journal.ink(String(d.get("name", _view)) + ("  +%d" % lv if lv > 0 else ""), 28)
	nrow.add_child(name)
	var stamp := Journal.ink(String(RARITY_NAME.get(rarity, rarity)), 16, rarity_col)
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0, 0, 0, 0)
	ssb.border_color = rarity_col
	ssb.set_border_width_all(2)
	ssb.content_margin_left = 6
	ssb.content_margin_right = 6
	stamp.add_theme_stylebox_override("normal", ssb)
	stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stamp.rotation = 0.0   # straight: a rotated label blurs (user 2026-11-26)
	nrow.add_child(stamp)
	var who := ""
	if d.has("class"):
		who = " · chỉ " + String(GameData.load_json("res://assets/data/classes.json").get(String(d["class"]), {}).get("name", d["class"]))
	hv.add_child(Journal.ink("%s%s" % [String(SLOT_NAME.get(String(d.get("slot", "")), "")), who], 18, Journal.INK_SOFT))
	# the text part scrolls; Cường hoá and Mặc stay pinned at the bottom
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var pad := MarginContainer.new()   # room for the scroll bar: it drew over the right column (user 2026-11-26)
	pad.add_theme_constant_override("margin_right", 18)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 2)
	pad.add_child(body)
	var desc := Journal.ink(String(d.get("desc", "")), 18)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(desc)
	_unlock_lines(body, d, _view)
	var worn := _prof.equipped(_cls)
	var is_worn := String(worn.get(_sel, "")) == _view
	body.add_child(Journal.ink("Đang mặc: thay đổi nếu tháo" if is_worn else "So với đang mặc:", 17, Journal.INK_SOFT))
	var after := worn.duplicate()
	if is_worn:
		after.erase(_sel)
	else:
		after[_sel] = _view
	var now := _stats_with(worn)
	var then := _stats_with(after)
	var changed := 0
	for s in STATS:
		var a := float(now.get(s[0], 0.0))
		var b := float(then.get(s[0], 0.0))
		if is_equal_approx(a, b):
			continue
		changed += 1
		var better: bool = (b < a) if s[3] else (b > a)
		body.add_child(Journal.ledger(String(STAT_ICON[s[0]]), s[1], "%s → %s %s" % [_fmt(s[2], a), _fmt(s[2], b), "▲" if better else "▼"], 18, UP if better else DOWN))
	if changed == 0:
		body.add_child(Journal.ink("Không đổi chỉ số nào.", 17, Journal.INK_SOFT))
	var prefs := Prefs.current()
	# bottom: Cường hoá (+20% of the item's effects per level, gold) as ink words, the seal Mặc / Bỏ ra
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var cost := _prof.enhance_cost(_view)   # web proposal approved 2026-11-26: a ledger line and "Cường hoá ▸ (C)"
	var col := VBoxContainer.new()   # the enhance line on its own full-width row above the link and the seal
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_sibling(col)
	v.move_child(col, row.get_index())
	col.add_child(Journal.ledger("coin", "Cường hoá +%d/%d (mỗi bậc +%d%%)" % [lv, _prof.max_plus(_view), roundi(Profile.PLUS_STEP * 100)],
		("%d vàng" % cost) if cost > 0 else "tối đa", 16))
	var eb := Journal.link("Cường hoá ▸ (C)", 18)
	eb.disabled = false   # opens the sheet; its seal checks the gold
	if cost > 0 and _slot_data.gold < cost:
		eb.tooltip_text = "Thiếu vàng: cần %d, đang có %d." % [cost, _slot_data.gold]
	eb.pressed.connect(_toggle_enhance)
	eb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(eb)
	var gap := Control.new()   # the link keeps its own width; the seal sits at the right
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	var act := Journal.seal("Bỏ ra" if is_worn else "Mặc ▶", Vector2(200, 60), 26)
	act.pressed.connect(func() -> void:
		if is_worn:
			_prof.unequip(_cls, _sel)
			_note_worn(_view, false)
		else:
			_prof.equip(_cls, _view)
			Sfx.play("buy")
			_note_worn(_view, true)
		prefs.save_profile()
		_rebuild())
	row.add_child(act)


var _enh_layer: CanvasLayer   # the Cường hoá sheet, null when closed


## The Cường hoá sheet the user approved (design-web screen-equipment-journal ?view=enhance, 2026-11-26): a slip
## pinned over the right page, one row per level +1..max with the main line at that level (+20% a level), the sub
## line it opens and its gold; done levels ticked, the next in ink; the seal enhances once; C / Esc close it.
func _toggle_enhance() -> void:
	if _enh_layer != null:
		_enh_layer.queue_free()
		_enh_layer = null
		return
	if _view == "" or not _prof.defs.has(_view):
		return
	_enh_layer = CanvasLayer.new()
	_enh_layer.layer = 5
	add_child(_enh_layer)
	var d: Dictionary = _prof.defs[_view]
	var now := _prof.plus_of(_view)
	var mx := _prof.max_plus(_view)
	var slip := Rect2(640, 56, 500, 610)
	var paper := Control.new()
	paper.position = slip.position
	paper.size = slip.size
	paper.mouse_filter = Control.MOUSE_FILTER_STOP
	paper.draw.connect(func() -> void:
		paper.draw_rect(Rect2(Vector2(0, 6), slip.size), Color(0, 0, 0, 0.45))
		paper.draw_rect(Rect2(Vector2.ZERO, slip.size), Journal.PAPER)
		paper.draw_rect(Rect2(Vector2.ZERO, slip.size), Journal.EDGE, false, 3.0)
		paper.draw_circle(Vector2(slip.size.x * 0.5, 0), 8.0, Color("5a0c08"))
		paper.draw_circle(Vector2(slip.size.x * 0.5, 0), 6.0, Journal.SEAL))
	_enh_layer.add_child(paper)
	var v := VBoxContainer.new()
	v.position = Vector2(26, 22)
	v.custom_minimum_size = Vector2(slip.size.x - 52, 0)
	v.add_theme_constant_override("separation", 0)
	paper.add_child(v)
	v.add_child(Journal.ink("Cường hoá · %s" % String(d.get("name", _view)), 28))
	v.add_child(Journal.ink("Đang +%d / %d · mỗi bậc +%d%% hiệu ứng" % [now, mx, roundi(Profile.PLUS_STEP * 100)], 19, Journal.INK_RED))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	v.add_child(gap)
	var names := {}
	for s in STATS:
		names[s[0]] = s[1]
	var subs := _prof.subs_of(_view)
	var base_cost := int(Profile.PLUS_COST.get(String(d.get("rarity", "common")), 30))
	for k in range(1, mx + 1):
		var parts := PackedStringArray()
		for e: String in d.get("effects", {}):
			var fx: Dictionary = d["effects"][e]
			var m := 1.0 + Profile.PLUS_STEP * k
			if fx.has("add"):
				var a := float(fx["add"]) * m
				parts.append("%s +%s" % [names.get(e, e), (str(roundi(a)) if is_equal_approx(a, roundf(a)) or a >= 10.0 else ("%.1f" % a).replace(".", ","))])
			elif fx.has("mul"):
				parts.append("%s %+d%%" % [names.get(e, e), roundi(float(fx["mul"]) * m * 100.0)])
		var si := Profile.SUB_AT.find(k)
		var opens := "mở dòng phụ %d: %s" % [si + 1, String(subs[si].get("desc", ""))] if si >= 0 and si < subs.size() else ""
		v.add_child(_enh_row(k, ", ".join(parts), opens, base_cost * k, k <= now, k == now + 1))
	var close := Journal.ink("C / Esc đóng", 18, Journal.INK_SOFT)
	close.position = Vector2(26, slip.size.y - 50)
	paper.add_child(close)
	var cost := _prof.enhance_cost(_view)
	var seal := Journal.seal(("Cường hoá ▸ %d" % cost) if cost > 0 else "Đã tối đa", Vector2(240, 60), 24)
	seal.position = slip.size - Vector2(266, 84)
	seal.disabled = cost <= 0 or _slot_data.gold < cost
	if cost > 0 and _slot_data.gold < cost:
		seal.tooltip_text = "Thiếu vàng: cần %d, đang có %d." % [cost, _slot_data.gold]
	seal.pressed.connect(func() -> void:
		_enhance()
		_enh_layer.queue_free()
		_enh_layer = null
		_toggle_enhance())
	paper.add_child(seal)


func _enh_row(k: int, line: String, opens: String, gold: int, done: bool, next: bool) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(448, 0)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var sb := StyleBoxFlat.new()
	sb.bg_color = Journal.INK if next else Color(0, 0, 0, 0)
	sb.border_color = Journal.DOTS
	sb.border_width_bottom = 2
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var ink := Journal.PAPER if next else (Journal.INK_SOFT if done else Journal.INK)
	var lv := Journal.ink("+%d" % k, 20, ink)
	lv.custom_minimum_size = Vector2(40, 0)
	lv.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(lv)
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 0)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(mid)
	var ll := Journal.ink(line, 18, ink)
	ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # never wider than the slip
	ll.custom_minimum_size = Vector2(280, 0)
	mid.add_child(ll)
	if opens != "":
		var o := Journal.ink(opens, 16, Color("9fe0a8") if next else Color("2a7a3a"))
		o.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		o.custom_minimum_size = Vector2(280, 0)
		mid.add_child(o)
	var g := Journal.ink("✓" if done else "%d vàng" % gold, 18, Journal.GOLD if next else ink)
	g.custom_minimum_size = Vector2(96, 0)
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	g.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(g)
	return p


## Cường hoá the viewed item once (+20% of its effects a level, gold).
func _enhance() -> void:
	if _view == "":
		return
	var wallet := {"v": _slot_data.gold}
	var cost := _prof.enhance_cost(_view)
	if _prof.enhance(_view, wallet):
		Sfx.play("enhance")
		Daily.load_default().add(_slot_data, "enhances", 1)
		_slot_data.gold = int(wallet["v"])
		Prefs.current().save_profile()
		Notice.note("Cường hoá %s +%d" % [_item_name(_view), _prof.plus_of(_view)], "−%d vàng · còn %d" % [cost, _slot_data.gold],
			UiIcons.texture(_item_icon(_view)))
		_rebuild()
	elif cost > 0 and _slot_data.gold < cost:
		Notice.note("Thiếu vàng", "Cần %d vàng, đang có %d" % [cost, _slot_data.gold], UiIcons.texture("coin"), true)


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
		var l := Journal.ink(text, 16, UP if on else Journal.INK_SOFT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(l)
