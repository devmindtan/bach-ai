extends Node2D
## The skill-tree screen of the chosen character (design/ux/skill-tree.md, rules in
## design/skill-tree.md): the wallet by the title; three branch columns of three
## tier cards joined by a line; the viewed node on the right (text, stats before ->
## after, why it cannot be bought yet, "Mở") and, at the bottom right as in Hades'
## Mirror of the Night, the reset box (1 Tẩy Tủy Đan + gold, every Tinh hoa back).
## Buying and resetting save at once. Esc goes back to the lobby.
##
## Command line (after `--`), for shots: --tree-view=<node id>.

const LOBBY_SCENE := "res://src/lobby/lobby.tscn"
const COL_W := 280.0
const CARD := Vector2(280, 132)
const UP := Color("8fe08a")
const LOCKED := Color("4a4458")
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
	_class = GameData.load_json("res://assets/data/classes.json").get(_slot.cls, {})
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tree-view="):
			_view = a.get_slice("=", 1)
	if _view == "":
		_view = _first_open()
	_build()


## The first node that can be bought, else the first one.
func _first_open() -> String:
	for b: Dictionary in _tree.branches(_slot.cls):
		for n: Dictionary in b["nodes"]:
			if not _slot.tree.has(String(n["id"])):
				return String(n["id"])
	return String(_tree.branches(_slot.cls)[0]["nodes"][0]["id"])


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
	# wallet
	var wallet := HBoxContainer.new()
	wallet.add_theme_constant_override("separation", 22)
	wallet.position = Vector2(42, 70)
	root.add_child(wallet)
	wallet.add_child(UiKit.stat("essence", "%d Tinh hoa" % _slot.essence, "Tinh hoa: quái tinh anh và boss rơi; mở node.", 16))
	wallet.add_child(UiKit.stat("pill", "%d Tẩy Tủy Đan" % _slot.pills, "Tẩy Tủy Đan: thắng thử thách; đặt lại cây.", 16))
	wallet.add_child(UiKit.stat("coin", "%d vàng" % _slot.gold, "Vàng", 16))
	var back := UiKit.button("Quay lại  (Esc)", func() -> void: get_tree().change_scene_to_file(LOBBY_SCENE), Vector2(180, 42), 17)
	back.position = Vector2(root.size.x - 40 - 180, 28)
	root.add_child(back)
	var branches: Array = _tree.branches(_slot.cls)
	for i in branches.size():
		_branch(root, branches[i], Vector2(40 + i * (COL_W + 16), 112))
	_detail(root)


# --- branches ---------------------------------------------------------------------

func _branch(root: Control, b: Dictionary, at: Vector2) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.position = at
	root.add_child(head)
	var box := UiKit.panel(UiKit.PANEL_DARK, 4, UiKit.GOLD)
	box.add_child(UiKit.icon(String(b.get("icon", "")), 32.0))
	head.add_child(box)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	hv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(hv)
	hv.add_child(UiKit.label(String(b.get("name", "")), 22, UiKit.TEXT))
	hv.add_child(UiKit.label(String(b.get("role", "")), 13, UiKit.MUTED))
	var nodes: Array = b.get("nodes", [])
	var y := at.y + 64
	# the line joining the tiers, lit up to the last node bought
	var line := Control.new()
	line.position = Vector2(at.x + COL_W * 0.5 - 2, y)
	line.size = Vector2(4, (CARD.y + 26) * (nodes.size() - 1) + 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(line)
	var lit := 0
	for n: Dictionary in nodes:
		if _slot.tree.has(String(n["id"])):
			lit += 1
	line.draw.connect(func() -> void:
		line.draw_rect(Rect2(Vector2.ZERO, line.size), LOCKED)
		if lit > 1:
			line.draw_rect(Rect2(0, 0, 4, (CARD.y + 26) * (lit - 1)), UiKit.GOLD))
	for i in nodes.size():
		var card := _node_card(nodes[i], i + 1)
		card.position = Vector2(at.x, y + i * (CARD.y + 26))
		root.add_child(card)


func _node_card(n: Dictionary, tier: int) -> Button:
	var id := String(n["id"])
	var owned := _slot.tree.has(id)
	var why := _tree.why_not(_slot, id)
	var buyable := why == ""
	var on := id == _view
	var b := Button.new()
	b.custom_minimum_size = CARD
	b.size = CARD
	b.focus_mode = Control.FOCUS_ALL
	var bg := Color("3a3020") if owned else (UiKit.PANEL if buyable else UiKit.PANEL_DARK)
	var border := UiKit.GOLD if owned else (Color(UiKit.GOLD, 0.6) if buyable else LOCKED)
	if on:
		border = Color.WHITE
	b.add_theme_stylebox_override("normal", UiKit.style(bg, 10, border, 3 if on or owned else 2))
	for st in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(st, UiKit.style(UiKit.PANEL_HOVER, 10, Color.WHITE, 3))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_right = -12
	v.offset_top = 10
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var dim := not owned and not buyable
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	var nm := UiKit.label(String(n.get("name", id)), 19, UiKit.GOLD if owned else (Color("8a8496") if dim else UiKit.TEXT))
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(nm)
	var tag := HBoxContainer.new()
	tag.add_theme_constant_override("separation", 4)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(tag)
	if owned:
		tag.add_child(UiKit.label("Đã mở ✓", 14, UP))
	else:
		tag.add_child(UiKit.icon("essence", 18.0))
		tag.add_child(UiKit.label(str(_tree.cost(id)), 16, UiKit.TEXT if _slot.essence >= _tree.cost(id) else Color("ff8a8a")))
	var d := UiKit.label(String(n.get("desc", "")), 15, Color("8a8496") if dim else UiKit.TEXT)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(d)
	var tier_l := UiKit.label("Tầng %d" % tier + ("" if owned or buyable else "  ·  " + why), 13, UiKit.MUTED)
	tier_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tier_l.custom_minimum_size.x = CARD.x - 24
	tier_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tier_l)
	for c in head.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.pressed.connect(func() -> void:
		_view = id
		_reset_armed = false
		_rebuild())
	if on:
		b.call_deferred("grab_focus")
	return b


# --- detail and reset ---------------------------------------------------------------

func _detail(root: Control) -> void:
	var x := 40 + 3 * (COL_W + 16)
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
	var owned := _slot.tree.has(_view)
	var name := UiKit.label(String(n.get("name", _view)), 24, UiKit.GOLD if owned else UiKit.TEXT)
	v.add_child(name)
	var br := ""
	for b: Dictionary in _tree.branches(_slot.cls):
		if String(b["id"]) == String(n["branch"]):
			br = String(b["name"])
	v.add_child(UiKit.label("%s · tầng %d" % [br, int(n["tier"])], 14, UiKit.MUTED))
	var d := UiKit.label(String(n.get("desc", "")), 16, UiKit.TEXT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	# stats before -> after (what this node adds; for a bought one, what it gives now)
	var with_ := _slot.tree.duplicate()
	var without := _slot.tree.duplicate()
	if not owned:
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
		rows.add_child(UiKit.label("%s → %s" % [_fmt(s[2], x0), _fmt(s[2], x1)], 15, UP))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	if owned:
		v.add_child(UiKit.label("Đã mở: có hiệu lực ở mọi trận của nhân vật này.", 14, UP))
	else:
		var why := _tree.why_not(_slot, _view)
		if why != "":
			var wl := UiKit.label(why, 14, Color("ff9a9a"))
			wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(wl)
		var buy := UiKit.button("Mở  (%d Tinh hoa)" % _tree.cost(_view), func() -> void:
			if _tree.buy(_slot, _view):
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
	v.add_child(UiKit.label("Hoàn %d Tinh hoa, bỏ mọi node đã mở." % _tree.spent(_slot), 14, UiKit.MUTED))
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
