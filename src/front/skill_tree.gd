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
const ORIGIN := Vector2(90, 168)
const STEP := Vector2(168, 112)
const NODE := 70.0
const KEY := 86.0
const UP := Color("8fe08a")
const STATS := [["max_hp", "Máu tối đa", "%d"], ["damage", "Sát thương", "%d"], ["armor", "Giáp", "%d"],
	["move_speed", "Tốc độ chạy", "%d"], ["cooldown", "Hồi chiêu", "×%.2f"], ["area", "Vùng đánh", "×%.2f"],
	["magnet", "Tầm hút", "×%.2f"], ["regen", "Hồi máu", "%.1f/giây"]]

var _slot: Slot
var _tree: SkillTree
var _class := {}
var _view := ""
var _reset_armed := false
var _scroll := Vector2.ZERO
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


## The first node a rank can be bought of, else the first one.
func _first_open() -> String:
	for n: Dictionary in _tree.nodes(_slot.cls):
		if _tree.why_not(_slot, String(n["id"])) == "":
			return String(n["id"])
	return String(_tree.nodes(_slot.cls)[0]["id"])


func _process(delta: float) -> void:
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
	var title := UiKit.label("Cây kỹ năng · %s" % _slot.name, 34, UiKit.GOLD)
	title.position = Vector2(40, 24)
	root.add_child(title)
	var wallet := HBoxContainer.new()
	wallet.add_theme_constant_override("separation", 22)
	wallet.position = Vector2(42, 72)
	root.add_child(wallet)
	wallet.add_child(UiKit.stat("essence", "%d Tinh hoa" % _slot.essence, "Tinh hoa: quái tinh anh và boss rơi; học nút.", 16))
	wallet.add_child(UiKit.stat("pill", "%d Tẩy Tủy Đan" % _slot.pills, "Tẩy Tủy Đan: thắng thử thách; đặt lại cây.", 16))
	wallet.add_child(UiKit.stat("coin", "%d vàng" % _slot.gold, "Vàng", 16))
	wallet.add_child(UiKit.label("Điểm đã dùng %d" % _tree.points(_slot), 16, UiKit.TEXT))
	var back := UiKit.button("Quay lại " + UiKit.hint("Esc"), func() -> void: get_tree().change_scene_to_file(LOBBY_SCENE), Vector2(180, 42), 17)
	back.position = Vector2(root.size.x - 40 - 180, 28)
	root.add_child(back)
	var edges := Control.new()
	edges.size = root.size
	edges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(edges)
	edges.draw.connect(func() -> void:
		for n: Dictionary in _tree.nodes(_slot.cls):
			for req: String in n.get("requires", []):
				var lit := _tree.rank(_slot, req) > 0
				edges.draw_line(_center(_tree.node(req)), _center(n), UiKit.GOLD if lit else Color("3a3448"), 5.0 if lit else 3.0))
	for n: Dictionary in _tree.nodes(_slot.cls):
		root.add_child(_node_button(n))
	_detail(root)


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
	var bg := Color("3a3020") if r >= mx else (Color("2c2838") if r > 0 else Color("16131e"))
	var border := UiKit.GOLD if r >= mx else (Color("c8d0e0") if r > 0 else (Color(UiKit.GOLD, 0.55) if learnable else Color("3a3448")))
	if id == _view:
		border = Color.WHITE
	var st := UiKit.style(bg, 4, border, 5 if key else 3)
	st.set_corner_radius_all(int(side / 2.0))
	b.add_theme_stylebox_override("normal", st)
	var hov := UiKit.style(UiKit.PANEL_HOVER, 4, Color.WHITE, 5 if key else 3)
	hov.set_corner_radius_all(int(side / 2.0))
	for s in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(s, hov)
	Tip.attach(b, String(n.get("name", id)))
	holder.add_child(b)
	var ic := UiKit.node_icon(String(n.get("vicon", "")), String(n.get("icon", "star")), side * 0.6)
	ic.position = (Vector2(side, side) - ic.custom_minimum_size) / 2.0
	ic.modulate = Color.WHITE if r > 0 else Color(0.5, 0.5, 0.56)
	b.add_child(ic)
	ic.size = ic.custom_minimum_size   # a Button is not a container: a 512 px SVG kept its own size otherwise
	var lv := UiKit.label("%d/%d" % [r, mx], 14, UiKit.GOLD if r >= mx else (UiKit.TEXT if r > 0 else UiKit.MUTED))
	lv.add_theme_stylebox_override("normal", UiKit.style(Color("100e16"), 3, Color(0, 0, 0, 0), 0))   # the edge passes under it
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.custom_minimum_size.x = 34
	lv.position = Vector2(side / 2.0 - 17, side + 2)
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(lv)
	b.pressed.connect(func() -> void:
		_view = id
		_reset_armed = false
		_rebuild())
	if id == _view:
		b.call_deferred("grab_focus")
	return holder


# --- detail and reset ---------------------------------------------------------------

func _detail(root: Control) -> void:
	var x := ORIGIN.x + 4 * STEP.x + KEY / 2.0 + 40
	var w := root.size.x - 40 - x
	var panel := UiKit.panel(Color(0.09, 0.08, 0.13, 0.94), 16)
	panel.position = Vector2(x, 112)
	panel.custom_minimum_size = Vector2(w, 330)
	panel.size = panel.custom_minimum_size
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var n := _tree.node(_view)
	if n.is_empty():
		return
	var r := _tree.rank(_slot, _view)
	var mx := int(n.get("max_rank", 1))
	var owned := r > 0
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	head.add_child(UiKit.node_icon(String(n.get("vicon", "")), String(n.get("icon", "star")), 48.0))
	var hv := VBoxContainer.new()
	head.add_child(hv)
	hv.add_child(UiKit.label(String(n.get("name", _view)), 24, UiKit.GOLD if owned else UiKit.TEXT))
	hv.add_child(UiKit.label(("Then chốt · " if bool(n.get("keystone", false)) else "") + "Cấp %d / %d" % [r, mx], 14, UiKit.MUTED))
	var d := UiKit.label(String(n.get("desc", "")), 16, UiKit.TEXT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	var conds := []
	for q: String in n.get("requires", []):
		conds.append(String(_tree.node(q).get("name", q)))
	if int(n.get("requires_points", 0)) > 0:
		conds.append("đã dùng %d điểm" % int(n["requires_points"]))
	if not n.get("excludes", []).is_empty():
		conds.append("chỉ chọn một nút then chốt")
	if not conds.is_empty():
		var cl := UiKit.label("Cần: " + ", ".join(conds), 14, UiKit.MUTED)
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(cl)
	# stats before -> after: the next rank, or for a maxed node the last rank it gave
	var with_ := _slot.tree.duplicate()
	var without := _slot.tree.duplicate()
	if r < mx:
		with_.append(_view)
	else:
		without.erase(_view)
	var a := _stats(without)
	var c := _stats(with_)
	var rows := GridContainer.new()
	rows.columns = 2
	rows.add_theme_constant_override("h_separation", 14)
	v.add_child(rows)
	for s in STATS:
		var x0 := float(a.get(s[0], 0.0))
		var x1 := float(c.get(s[0], 0.0))
		if is_equal_approx(x0, x1):
			continue
		rows.add_child(UiKit.label(s[1], 15, UiKit.TEXT))
		var better := (x1 < x0) if s[0] == "cooldown" else (x1 > x0)
		rows.add_child(UiKit.label("%s → %s" % [_fmt(s[2], x0), _fmt(s[2], x1)], 15, UP if better else Color("ff8a8a")))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	if r >= mx:
		v.add_child(UiKit.label("Đã tối đa: có hiệu lực ở mọi trận của nhân vật này.", 14, UP))
	else:
		var why := _tree.why_not(_slot, _view)
		if why != "":
			var wl := UiKit.label(why, 14, Color("ff9a9a"))
			wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(wl)
		var buy := UiKit.button("Học  (%d Tinh hoa)" % _tree.cost(_view), func() -> void:
			if _tree.buy(_slot, _view):
				Sfx.play("buy")
				_save()
				_rebuild(), Vector2(0, 52), 20, UiKit.PRIMARY)
		buy.disabled = why != ""
		v.add_child(buy)
	_reset_box(root, x, w)


func _reset_box(root: Control, x: float, w: float) -> void:
	var panel := UiKit.panel(Color(0.09, 0.08, 0.13, 0.94), 16)
	panel.position = Vector2(x, 458)
	panel.custom_minimum_size = Vector2(w, 222)
	panel.size = panel.custom_minimum_size
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(UiKit.label("Đặt lại cây", 20, UiKit.TEXT))
	var cost := _tree.reset_cost(_slot)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	row.add_child(UiKit.stat("pill", "1", "Tẩy Tủy Đan", 16))
	row.add_child(UiKit.stat("coin", str(int(cost["gold"])), "Vàng", 16))
	v.add_child(UiKit.label("Hoàn %d Tinh hoa, bỏ mọi nút đã học." % _tree.spent(_slot), 14, UiKit.MUTED))
	var why := _tree.why_not_reset(_slot)
	if why != "":
		var wl := UiKit.label(why, 14, Color("ff9a9a"))
		wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(wl)
	var btn := UiKit.button("Chắc chắn đặt lại?" if _reset_armed else "Đặt lại", func() -> void:
		if not _reset_armed:   # asks once more
			_reset_armed = true
			_rebuild()
			return
		_reset_armed = false
		if _tree.reset(_slot):
			_save()
		_rebuild(), Vector2(0, 44), 17, UiKit.DANGER)
	btn.disabled = why != ""
	v.add_child(btn)


func _stats(tree_ids: Array) -> Dictionary:
	var keep := _slot.tree
	_slot.tree = tree_ids
	var lasting := SkillTree.lasting(_slot)
	_slot.tree = keep
	return PlayerStats.compute(_class.get("stats", {}), lasting[0], lasting[1])


func _fmt(f: String, x: float) -> String:
	return f % roundi(x) if f == "%d" else f % x
