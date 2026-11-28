extends Node2D
## The character-tree screen (design/ux/skill-tree.md, rules in design/skill-tree-v2.md §1), laid out
## like the card-tree screen: the class's nodes on a grid joined by edges (lit once the parent is
## learned); each node a round button with its own icon and rank "r/max" below; learned bright and gold,
## unlearned dark; keystones bigger. On the right the viewed node (text, stats before -> after, why it
## cannot be learned yet, "Học") and below it, as in Hades' Mirror of the Night, the reset box
## (1 Tẩy Tủy Đan + gold, every Tinh hoa back). Buying and resetting save at once. Esc: lobby.
##
## Command line (after `--`), for shots: --tree-view=<node id>.

const LOBBY_SCENE := "res://src/lobby/lobby.tscn"
const ORIGIN := Vector2(150, 196)   # the tree fills the journal's left page (design-web screen-tree-journal)
const STEP := Vector2(96, 100)
const NODE := 60.0
const KEY := 74.0
const RIGHT_PAGE := Rect2(660, 74, 470, 572)

var _slot: Slot
var _tree: SkillTree
var _class := {}
var _view := ""
var _reset_armed := false   # Tẩy tuỷ asks once more
var _layer: CanvasLayer


func _ready() -> void:
	Sfx.music("menu")
	var prefs := Prefs.current()
	if prefs.is_fixed():
		prefs.ensure_preview_slot()
	elif prefs.active_slot == null:
		prefs.ensure_slots()
	_slot = prefs.active_slot
	if _slot == null:
		get_tree().change_scene_to_file.call_deferred("res://src/front/characters.tscn")
		return
	_tree = SkillTree.load_default()
	if _tree.migrate(_slot):
		_save()
	_class = GameData.load_json("res://assets/data/classes.json").get(_slot.cls, {})
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tree-view="):
			_view = a.get_slice("=", 1)
	if _view == "":
		_view = _first_open()
	_build()
	if "--ask-reset" in OS.get_cmdline_user_args():   # shots: the Tẩy tuỷ confirm slip
		_reset.call_deferred()


## The first node a rank can be bought of, else the first one.
func _first_open() -> String:
	for n: Dictionary in _tree.nodes(_slot.cls):
		if _tree.why_not(_slot, String(n["id"])) == "":
			return String(n["id"])
	return String(_tree.nodes(_slot.cls)[0]["id"])


func _draw() -> void:
	Journal.draw_desk(self, get_viewport_rect().size)
	Journal.draw_book(self, Journal.BOOK)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(LOBBY_SCENE)
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_R:
		_reset()


func _rebuild() -> void:
	if _layer != null:
		_layer.queue_free()
	_build()


func _save() -> void:
	if not Prefs.current().is_fixed():
		Prefs.current().slot_store().save(_slot)


func _center(n: Dictionary) -> Vector2:
	return ORIGIN + Vector2(float(n.get("col", 0)) * STEP.x, float(n.get("row", 0)) * STEP.y)


func _build() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	var root := Control.new()
	root.size = get_viewport_rect().size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	Journal.back_tab(root, func() -> void: get_tree().change_scene_to_file(LOBBY_SCENE))   # "Trở lại" (web .back-tab)
	var title := Journal.ink("Cây kỹ năng", 44)
	title.position = Vector2(110, 66)
	root.add_child(title)
	var sub := Journal.ink("%s · mỗi hàng đắt hơn hàng trên" % String(_class.get("name", _slot.cls)), 20, Journal.INK_RED)
	sub.position = Vector2(112, 122)
	root.add_child(sub)
	var hint := Journal.ink("←↑↓→ chọn nút · Enter học · Esc về sổ", 15, Journal.PAPER)
	hint.position = Vector2(Journal.BOOK.position.x, Journal.BOOK.end.y + 14)
	root.add_child(hint)
	var edges := Control.new()
	edges.size = root.size
	edges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(edges)
	edges.draw.connect(func() -> void:
		for n: Dictionary in _tree.nodes(_slot.cls):
			for req: String in n.get("requires", []):
				var a := _center(_tree.node(req))   # solid ink once the parent is learned, dashed before (web)
				var b := _center(n)
				if _tree.rank(_slot, req) > 0:
					edges.draw_line(a, b, Journal.INK, 3.0)
				else:
					edges.draw_dashed_line(a, b, Journal.INK, 3.0, 6.0))
	for n: Dictionary in _tree.nodes(_slot.cls):
		root.add_child(_node_button(n))
	# web screen-tree-journal ?view=cost (approved 2026-11-27): the purse in the left page's corner
	var purse := _essence_tag(str(_slot.essence), 26, Journal.INK, 3)
	purse.position = Vector2(512, 74)
	root.add_child(purse)
	_detail(root)


## Tinh hoa icon + number in a paper tag with a [param border] px frame (the purse; the node cost badges).
func _essence_tag(text: String, sz: int, col: Color, border: int) -> PanelContainer:
	var pc := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("ddcca0") if border > 2 else Journal.PAPER
	st.border_color = col
	st.set_border_width_all(border)
	st.content_margin_left = 6 if border > 2 else 2
	st.content_margin_right = 8 if border > 2 else 4
	pc.add_theme_stylebox_override("panel", st)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4 if border > 2 else 1)
	pc.add_child(h)
	var ic := TextureRect.new()
	ic.texture = UiIcons.texture("essence")
	var px := 22 if border > 2 else 14
	ic.custom_minimum_size = Vector2(px, px)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	h.add_child(Journal.ink(text, sz, col))
	return pc


func _node_button(n: Dictionary) -> Control:
	var id := String(n["id"])
	var r := _tree.rank(_slot, id)
	var mx := int(n.get("max_rank", 1))
	var learnable := _tree.why_not(_slot, id) == ""
	var key := bool(n.get("keystone", false))
	var side := KEY if key else NODE
	var holder := Control.new()
	holder.position = _center(n) - Vector2(side, side) / 2.0
	holder.size = Vector2(side, side + 22)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b := Button.new()
	b.custom_minimum_size = Vector2(side, side)
	b.size = Vector2(side, side)
	b.focus_mode = Control.FOCUS_ALL
	# sketch squares: learned rose ink, maxed red ink, open ones paper, closed ones faded; the viewed one ink + gold
	var on := id == _view
	var bg := Journal.INK if on else (Color("c88a7a") if r > 0 else Journal.SKETCH)   # web: learned rose, others paper
	var border := Journal.INK
	for s in ["normal", "hover", "focus", "pressed"]:
		var lit: bool = on or s != "normal"
		var st := StyleBoxFlat.new()
		st.bg_color = bg
		st.border_color = Journal.GOLD if lit else border
		st.set_border_width_all(4 if lit or key else 3)
		b.add_theme_stylebox_override(s, st)
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	Tip.attach(b, String(n.get("name", id)))
	holder.add_child(b)
	var ic := UiKit.node_icon(String(n.get("vicon", "")), String(n.get("icon", "star")), side * 0.6)
	ic.position = (Vector2(side, side) - ic.custom_minimum_size) / 2.0
	ic.modulate = Journal.GOLD if on else Journal.INK   # the node icons are drawn in ink (web: the tree svgs)
	b.add_child(ic)
	ic.size = ic.custom_minimum_size   # a Button is not a container: a 512 px SVG kept its own size otherwise
	var lv := Journal.ink("%d/%d" % [r, mx], 15, Journal.INK_RED if r >= mx else (Journal.INK if r > 0 else Journal.INK_SOFT))
	var tag := StyleBoxFlat.new()   # the edge passes under it
	tag.bg_color = Journal.PAPER
	tag.border_color = Journal.INK
	tag.set_border_width_all(2)
	lv.add_theme_stylebox_override("normal", tag)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.custom_minimum_size.x = 34
	lv.position = Vector2(side - 22, side - 14)   # the rank tag on the node's bottom-right corner (web .rk)
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(lv)
	if r < mx:   # the cost of its next rank on the node's top-left corner (web .pc)
		var pc := _essence_tag(str(_tree.cost(id)), 15, Journal.INK_RED, 2)
		pc.position = Vector2(-8, -10)
		holder.add_child(pc)
	b.focus_entered.connect(func() -> void:   # focus views a node; Enter / a click learns it (web: Enter học)
		if _view != id:
			_view = id
			_rebuild())
	b.pressed.connect(func() -> void:
		if _view == id:
			_learn()
		else:
			_view = id
			_rebuild())
	if id == _view:
		b.call_deferred("grab_focus")
	return holder


# --- detail and reset ---------------------------------------------------------------

## The right page (web screen-tree-journal): the node's name, "Hàng · cấp", its text, the ledger (cost, Tinh hoa,
## requirements), the reset note and the seal "Học".
func _detail(root: Control) -> void:
	var n := _tree.node(_view)
	if n.is_empty():
		return
	var r := _tree.rank(_slot, _view)
	var mx := int(n.get("max_rank", 1))
	var v := VBoxContainer.new()
	v.position = RIGHT_PAGE.position + Vector2(0, -8)
	v.custom_minimum_size = Vector2(RIGHT_PAGE.size.x, 0)
	v.add_theme_constant_override("separation", 2)
	root.add_child(v)
	var h2 := Journal.ink(String(n.get("name", _view)), 32)
	var under := StyleBoxFlat.new()
	under.bg_color = Color(0, 0, 0, 0)
	under.border_color = Journal.INK
	under.border_width_bottom = 3
	h2.add_theme_stylebox_override("normal", under)
	v.add_child(h2)
	v.add_child(Journal.ink("Hàng %d · cấp %d/%d" % [int(n.get("row", 0)) + 1, r, mx], 20, Journal.INK_RED))
	var d := Journal.ink(String(n.get("desc", "")), 22)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(RIGHT_PAGE.size.x, 0)
	v.add_child(d)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	v.add_child(gap)
	var reqs := []
	for q: String in n.get("requires", []):
		reqs.append(String(_tree.node(q).get("name", q)))
	var price := _tree.cost(_view)
	var have := int(_slot.essence)
	if r >= mx:
		v.add_child(Journal.ledger("essence", "Giá", "đã đủ cấp", 20))
	else:
		v.add_child(Journal.ledger("essence", "Giá cấp %d" % (r + 1), "%d Tinh hoa" % price, 20))
		v.add_child(Journal.ledger("essence", "Đang có", "%d → %s" % [have, str(have - price) if have >= price else "thiếu %d" % (price - have)], 20))
	v.add_child(Journal.ledger("", "Cần", ", ".join(reqs) if not reqs.is_empty() else "—", 20))
	var note := Journal.ink("Tẩy tuỷ: 1 Tẩy Tủy Đan + vàng, trả lại mọi Tinh hoa.", 18, Journal.INK_SOFT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(RIGHT_PAGE.size.x, 0)
	v.add_child(note)
	var cost := _tree.reset_cost(_slot)   # web proposal approved 2026-11-26: Tẩy tuỷ (R), pressed twice
	var rs := Journal.link(("Chắc chắn tẩy tuỷ? Bấm lần nữa (R)" if _reset_armed else "Tẩy tuỷ ▸ (R) · 1 Tẩy Tủy Đan + %d vàng" % int(cost["gold"])), 18)
	rs.disabled = _tree.why_not_reset(_slot) != ""
	rs.tooltip_text = _tree.why_not_reset(_slot)
	rs.pressed.connect(_reset)
	v.add_child(rs)
	var src := Journal.ink("Tinh hoa: quái tinh anh rơi 1, trùm rơi 10; nhặt được giữ lại cả khi thua.", 18, Journal.INK_SOFT)
	src.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	src.custom_minimum_size = Vector2(RIGHT_PAGE.size.x, 0)
	v.add_child(src)
	var why := _tree.why_not(_slot, _view) if r < mx else "Đã tối đa."
	var buy := Journal.seal("Học ▶" if r >= mx else "Học ▶ −%d" % price, Vector2(260, 62), 26)
	if r < mx:
		var tw := buy.get_theme_font("font").get_string_size(buy.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		var ei := TextureRect.new()   # the Tinh hoa icon right after "−N" (web: Học ▶ −N + icon)
		ei.texture = UiIcons.texture("essence")
		ei.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ei.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ei.size = Vector2(24, 24)
		ei.position = Vector2(roundf(130 - 9 + tw * 0.5), 19)
		ei.mouse_filter = Control.MOUSE_FILTER_IGNORE
		buy.add_child(ei)
		buy.add_theme_constant_override("h_separation", 0)
		buy.text += "     "
		if have < price:
			var short := Journal.ink("Thiếu %d Tinh hoa" % (price - have), 20, Journal.INK_RED)
			short.position = RIGHT_PAGE.end - Vector2(short.get_minimum_size().x, 62 + 34)
			root.add_child(short)
	buy.position = RIGHT_PAGE.end - Vector2(260, 62)
	buy.focus_mode = Control.FOCUS_NONE   # the nodes own the arrows; Enter on a node learns it
	buy.disabled = why != ""
	buy.tooltip_text = why
	buy.pressed.connect(_learn)
	root.add_child(buy)


## Tẩy tuỷ: the first press asks, the second resets (1 Tẩy Tủy Đan + gold, every Tinh hoa back).
func _reset() -> void:
	if _tree.why_not_reset(_slot) != "" and not "--ask-reset" in OS.get_cmdline_user_args():
		Notice.note("Chưa tẩy tuỷ được", _tree.why_not_reset(_slot), UiIcons.texture("pill"), true)
		return
	var c := _tree.reset_cost(_slot)   # web screen-notices ?view=reset: the slip names what it costs and gives back
	var back := _tree.spent(_slot)
	Notice.ask("reset_tree", "Tẩy tuỷ cây kỹ năng?", "Bỏ hết các nút đã học, trả lại toàn bộ Tinh hoa.",
		"Tốn: 1 Tẩy Tủy Đan + %d vàng · Nhận lại: %d Tinh hoa" % [int(c["gold"]), back], "Tẩy tuỷ", func() -> void:
			if _tree.reset(_slot):
				_save()
				Notice.note("Đã tẩy tuỷ", "Nhận lại %d Tinh hoa · còn %d" % [back, _slot.essence], UiIcons.texture("essence"))
			_rebuild())


func _learn() -> void:
	var price := _tree.cost(_view)
	var why := _tree.why_not(_slot, _view)
	if _tree.buy(_slot, _view):
		Sfx.play("buy")
		_save()
		var n := _tree.node(_view)
		Notice.note("Đã học %s · cấp %d" % [String(n.get("name", _view)), _tree.rank(_slot, _view)],
			"−%d Tinh hoa · còn %d" % [price, _slot.essence], UiIcons.texture("essence"))
		_rebuild()
	elif why != "":
		Notice.note("Chưa học được", why, UiIcons.texture("essence"), true)
