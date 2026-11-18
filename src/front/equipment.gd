extends Node2D
## The equipment screen of the chosen character (design/ux/equipment.md): a paper
## doll (the hero on a pedestal with the five slots round it and the stats with
## gear under it), the bag of the chosen slot as a list, and the viewed item
## in a fixed layout: name in its rarity colour, rarity · slot · class, text, the
## change against what is worn (▲ green better, ▼ red worse, changed stats only)
## and "Mặc" or "Bỏ ra". Changes are saved at once. Esc goes back to the lobby.
##
## Command line (after `--`), for shots: --equip-slot=<slot>, --equip-view=<item id>.

const LOBBY_SCENE := "res://src/lobby/lobby.tscn"
const SLOT_NAME := {"head": "Đầu", "chest": "Ngực", "arms": "Tay", "legs": "Chân", "weapon": "Vũ khí"}
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
const SLOT_POS := {"head": Vector2(0, 40), "chest": Vector2(0, 150), "arms": Vector2(300, 40),
	"legs": Vector2(300, 150), "weapon": Vector2(150, 296)}
const CELL := Vector2(76, 76)

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
	_hero = FrontArt.hero_sheet(_class)
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
	if _view == "":
		_view = _default_view()
	_build()


func _default_view() -> String:
	var worn := String(_prof.equipped(_cls).get(_sel, ""))
	if worn != "":
		return worn
	var c := _prof.choices(_cls, _sel)
	return String(c[0]) if not c.is_empty() else ""


func _process(delta: float) -> void:
	_t += delta
	_scroll += Vector2(18.0, 6.0) * delta
	queue_redraw()


func _draw() -> void:
	FrontArt.backdrop(self, _scroll, get_viewport_rect().size)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(LOBBY_SCENE)


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
	var title := UiKit.label("Trang bị · %s" % _slot_data.name, 34, UiKit.GOLD)
	title.position = Vector2(40, 24)
	root.add_child(title)
	var sub := UiKit.label("%s  ·  chọn một ô, rồi chọn món trong túi để xem và mặc" % String(_class.get("name", _cls)), 15, UiKit.MUTED)
	sub.position = Vector2(42, 70)
	root.add_child(sub)
	var back := UiKit.button("Quay lại  (Esc)", func() -> void: get_tree().change_scene_to_file(LOBBY_SCENE), Vector2(180, 42), 17)
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
			_hero.draw(hero, "idle", _t, Vector2(110, 250), 5.0))
	var tick := Timer.new()   # the hero idles and the ring turns
	tick.wait_time = 1.0 / 15.0
	tick.autostart = true
	tick.timeout.connect(hero.queue_redraw)
	hero.add_child(tick)
	var worn := _prof.equipped(_cls)
	for slot: String in Profile.SLOTS:
		var cell := _slot_cell(slot, String(worn.get(slot, "")))
		cell.position = SLOT_POS[slot]
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
		var ic := UiKit.icon(String(d.get("icon", item)), 52.0)
		ic.position = (CELL - Vector2(52, 52)) * 0.5   # no anchors: a Button is not a container
		ic.size = Vector2(52, 52)
		b.add_child(ic)
	b.pressed.connect(func() -> void:
		_sel = slot
		_filter = slot
		_view = _default_view()
		_rebuild())
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

const TABS := [["all", "Tất cả"], ["head", "Đầu"], ["chest", "Ngực"], ["arms", "Tay"], ["legs", "Chân"], ["weapon", "Vũ khí"]]
const ORDER := ["legendary", "epic", "rare", "common"]
const MIXED := Color("f2c14e")
const GOLD_COLOR_FALLBACK := Color("c9a65a")


func _bag(root: Control) -> void:
	var panel := UiKit.panel(Color(0.09, 0.08, 0.13, 0.94), 16)
	panel.position = Vector2(456, 104)   # 16 px gaps between the three columns
	panel.custom_minimum_size = Vector2(388, 576)
	panel.size = panel.custom_minimum_size
	root.add_child(panel)
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
	for t in TABS:
		tabs.add_child(_pill(t[1], _filter == t[0], func() -> void:
			_filter = t[0]
			if t[0] != "all":
				_sel = t[0]
				_view = _default_view()
			_bag_scroll = 0
			_rebuild(), 56.0))
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
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for id: String in ids:
		list.add_child(_bag_row(id))
	scroll.scroll_vertical = _bag_scroll
	scroll.get_v_scroll_bar().value_changed.connect(func(val: float) -> void: _bag_scroll = int(val))


## Owned items the class can wear in the current tab, in the current order
## (the same item owned twice is one row with ×2).
func _bag_ids() -> Array:
	var ids := []
	for slot: String in Profile.SLOTS:
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


## One owned item as a compact card: icon + name (rarity color) + rarity · slot +
## one-line desc; upgrade marker on the right (▲ green better / ▼ red worse / ⇅ mixed /
## "Đang mặc" green when this is the worn one). The same item owned twice folds to ×n.
func _bag_row(id: String) -> Button:
	var d: Dictionary = _prof.defs.get(id, {})
	var rarity := String(d.get("rarity", "common"))
	var col: Color = RARITY.get(rarity, UiKit.TEXT)
	var b := Button.new()
	b.custom_minimum_size = Vector2(340, 64)
	b.focus_mode = Control.FOCUS_ALL
	var on := id == _view
	var bg := Color(col, 0.10).blend(UiKit.PANEL_DARK) if not on else Color(col, 0.18).blend(UiKit.PANEL_DARK)
	b.add_theme_stylebox_override("normal", UiKit.style(bg, 6, Color.WHITE if on else Color(col, 0.55), 3 if on else 1))
	for st in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(st, UiKit.style(UiKit.PANEL_HOVER, 6, Color.WHITE, 3))
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 7
	h.offset_right = -10
	h.offset_top = 4
	h.offset_bottom = -4
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	# icon in a rarity frame
	var box := UiKit.panel(UiKit.PANEL_DARK, 3, col)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(UiKit.icon(String(d.get("icon", id)), 40.0))
	h.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var copies := _prof.bag.count(id)
	var nl := UiKit.label(String(d.get("name", id)) + ("  ×%d" % copies if copies > 1 else ""), 16, col)
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nl)
	if _prof.is_new(id):
		top.add_child(_badge("MỚI", Color("f2c14e")))
	var line := String(RARITY_NAME.get(rarity, rarity))
	if _filter == "all":
		line += "  ·  " + String(SLOT_NAME.get(String(d.get("slot", "")), ""))
	var ll := UiKit.label(line, 11, UiKit.MUTED)
	ll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(ll)
	var dl := UiKit.label(String(d.get("desc", "")), 12, UiKit.TEXT)
	dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dl.clip_text = true
	dl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	dl.custom_minimum_size.y = 0
	v.add_child(dl)
	var vd := _verdict(id)
	var mark: Control
	if vd == 2:
		mark = _badge("Đang mặc", UP)
	else:
		var sym: String = {1: "▲", -1: "▼", 0: "⇅"}[vd]
		var mcol: Color = {1: UP, -1: DOWN, 0: MIXED}[vd]
		mark = UiKit.label(sym, 20, mcol)
		Tip.attach(mark, {1: "Tốt hơn đồ đang mặc", -1: "Kém hơn đồ đang mặc", 0: "Có chỉ số hơn, có chỉ số kém"}[vd],
			"So với món đang mặc ở ô %s." % SLOT_NAME.get(String(d.get("slot", "")), ""), mcol)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(mark)
	b.pressed.connect(func() -> void:
		_view = id
		_sel = String(d.get("slot", _sel))
		_rebuild())
	return b


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
	v.add_theme_constant_override("separation", 10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
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
	banner.custom_minimum_size = Vector2(0, 220)
	v.add_child(banner)
	var bv := VBoxContainer.new()
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.add_theme_constant_override("separation", 2)
	banner.add_child(bv)
	var big_ic := UiKit.icon(String(d.get("icon", _view)), 120.0)
	big_ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bv.add_child(big_ic)
	# name over the icon area, rarity-tinted
	var lv := _prof.plus_of(_view)
	var name := UiKit.label(String(d.get("name", _view)) + ("  +%d" % lv if lv > 0 else ""), 22, rarity_col)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bv.add_child(name)
	# rarity stripe: label in rarity colour, slot class restricted
	var meta := String(RARITY_NAME.get(rarity, rarity))
	var who := ""
	if d.has("class"):
		who = "  ·  chỉ " + String(GameData.load_json("res://assets/data/classes.json").get(String(d["class"]), {}).get("name", d["class"]))
	meta += "  ·  " + String(SLOT_NAME.get(String(d.get("slot", "")), "")) + who
	var ml := UiKit.label(meta, 12, UiKit.MUTED)
	ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ml.custom_minimum_size = Vector2(320, 0)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ml.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bv.add_child(ml)
	var desc := UiKit.label(String(d.get("desc", "")), 16, UiKit.TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(desc)
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
	v.add_child(head)
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
	v.add_child(rows)
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
		v.add_child(UiKit.label("Không đổi chỉ số nào.", 15, UiKit.MUTED))
	var prefs := Prefs.current()
	# Cường hoá: +1..+5 with gold, each level +20% of the item's effects
	var el := UiKit.label("Cường hoá +%d/%d  ·  mỗi bậc +%d%% hiệu ứng" % [lv, Profile.MAX_PLUS, roundi(Profile.PLUS_STEP * 100)], 14, UiKit.MUTED)
	el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(el)   # a line of its own: beside the button it pushed the column off screen
	var cost := _prof.enhance_cost(_view)
	var eb := UiKit.button(("Cường hoá  %d vàng" % cost) if cost > 0 else "Đã tối đa", func() -> void:
		var wallet := {"v": _slot_data.gold}
		if _prof.enhance(_view, wallet):
			Sfx.play("enhance")
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
