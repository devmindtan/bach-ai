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
var _t := 0.0
var _scroll := Vector2.ZERO
var _layer: CanvasLayer


func _ready() -> void:
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
	b.tooltip_text = "%s: %s" % [SLOT_NAME[slot], String(d.get("name", "trống"))]
	if item != "":
		var ic := UiKit.icon(String(d.get("icon", item)), 52.0)
		ic.position = (CELL - Vector2(52, 52)) * 0.5   # no anchors: a Button is not a container
		ic.size = Vector2(52, 52)
		b.add_child(ic)
	b.pressed.connect(func() -> void:
		_sel = slot
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

func _bag(root: Control) -> void:
	var panel := UiKit.panel(Color(0.09, 0.08, 0.13, 0.94), 16)
	panel.position = Vector2(456, 104)   # 16 px gaps between the three columns
	panel.custom_minimum_size = Vector2(388, 576)
	panel.size = panel.custom_minimum_size
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(UiKit.label("Túi đồ · %s" % SLOT_NAME.get(_sel, _sel), 22, UiKit.TEXT))
	var ids := _prof.choices(_cls, _sel)
	if ids.is_empty():
		var none := UiKit.label("Chưa có đồ cho ô này. Thắng ải hoặc mở rương tinh anh để nhận thêm.", 15, UiKit.MUTED)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size = Vector2(350, 0)
		v.add_child(none)
		return
	# the best first: legendary, epic, rare, common
	var order := ["legendary", "epic", "rare", "common"]
	ids.sort_custom(func(a: String, b: String) -> bool:
		return order.find(String(_prof.defs.get(a, {}).get("rarity", "common"))) < order.find(String(_prof.defs.get(b, {}).get("rarity", "common"))))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	v.add_child(list)
	var worn := String(_prof.equipped(_cls).get(_sel, ""))
	for id: String in ids:
		list.add_child(_bag_row(id, id == worn, _prof.bag.count(id)))


## One owned item: icon in its rarity frame, name in the rarity colour, rarity
## and "đang mặc"; the viewed item has a white frame. A list, not an icon grid:
## items of one slot look alike at 64 px.
func _bag_row(id: String, worn: bool, copies: int) -> Button:
	var d: Dictionary = _prof.defs.get(id, {})
	var rarity := String(d.get("rarity", "common"))
	var col: Color = RARITY.get(rarity, UiKit.TEXT)
	var b := Button.new()
	b.custom_minimum_size = Vector2(356, 64)
	b.focus_mode = Control.FOCUS_ALL
	var on := id == _view
	b.add_theme_stylebox_override("normal", UiKit.style(UiKit.PANEL_HOVER if on else UiKit.PANEL_DARK, 6, Color.WHITE if on else Color("4a4458"), 3 if on else 1))
	for st in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(st, UiKit.style(UiKit.PANEL_HOVER, 6, Color.WHITE, 3))
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_right = -8
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var box := UiKit.panel(UiKit.PANEL_DARK, 3, col)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(UiKit.icon(String(d.get("icon", id)), 40.0))
	h.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var nl := UiKit.label(String(d.get("name", id)) + ("  ×%d" % copies if copies > 1 else ""), 17, col)
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nl)
	var ll := UiKit.label(String(RARITY_NAME.get(rarity, rarity)) + ("  ·  ✓ đang mặc" if worn else ""), 13, UP if worn else UiKit.MUTED)
	ll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(ll)
	b.pressed.connect(func() -> void:
		_view = id
		_rebuild())
	return b


# --- detail ----------------------------------------------------------------------

func _detail(root: Control) -> void:
	var panel := UiKit.panel(Color(0.09, 0.08, 0.13, 0.94), 18)
	panel.position = Vector2(860, 104)
	panel.custom_minimum_size = Vector2(380, 576)
	panel.size = panel.custom_minimum_size
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	if _view == "" or not _prof.defs.has(_view):
		var l := UiKit.label("Chọn một món trong túi để xem.", 16, UiKit.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
		return
	var d: Dictionary = _prof.defs[_view]
	var rarity := String(d.get("rarity", "common"))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	var box := UiKit.panel(UiKit.PANEL_DARK, 6, RARITY.get(rarity, UiKit.GOLD))
	box.add_child(UiKit.icon(String(d.get("icon", _view)), 48.0))
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(box)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	var name := UiKit.label(String(d.get("name", _view)), 24, RARITY.get(rarity, UiKit.TEXT))
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(name)
	var who := ""
	if d.has("class"):
		who = "  ·  chỉ " + String(GameData.load_json("res://assets/data/classes.json").get(String(d["class"]), {}).get("name", d["class"]))
	hv.add_child(UiKit.label("%s  ·  %s%s" % [RARITY_NAME.get(rarity, rarity), SLOT_NAME.get(String(d.get("slot", "")), ""), who], 14, UiKit.MUTED))
	var desc := UiKit.label(String(d.get("desc", "")), 15, UiKit.TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	# change against what is worn in this slot
	var worn := _prof.equipped(_cls)
	var is_worn := String(worn.get(_sel, "")) == _view
	v.add_child(UiKit.label("Bỏ ra thì thay đổi" if is_worn else "So với đang mặc", 16, UiKit.GOLD))
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
	rows.add_theme_constant_override("v_separation", 4)
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
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var prefs := Prefs.current()
	var act := UiKit.button("Bỏ ra" if is_worn else "Mặc  ▶", func() -> void:
		if is_worn:
			_prof.unequip(_cls, _sel)
		else:
			_prof.equip(_cls, _view)
		prefs.save_profile()
		_rebuild(), Vector2(0, 56), 22, UiKit.PANEL if is_worn else UiKit.PRIMARY)
	v.add_child(act)


func _fmt(f: String, x: float) -> String:
	return f % roundi(x) if f == "%d" else f % x


## Stats of the class with [param worn] ({slot: item id}) on.
func _stats_with(worn: Dictionary) -> Dictionary:
	var ups := []
	var lv := {}
	for slot: String in worn:
		var id := String(worn[slot])
		var d: Dictionary = _prof.defs.get(id, {})
		ups.append({"id": id, "name": d.get("name", id), "kind": "item", "effects": d.get("effects", {})})
		lv[id] = 1
	return PlayerStats.compute(_class.get("stats", {}), ups, lv)
