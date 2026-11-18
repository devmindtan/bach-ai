extends Node2D
## The gacha screen (design/ux/gacha.md, rules in design/gacha.md): banners with
## their own pity counter on the left, the last pull's results in the middle, the
## published rates, the pity rule, the price and the Quay 1 / Quay 10 buttons on
## the right. Pulls save at once. Esc goes back to the lobby.
##
## Command line (after `--`), for shots: --gacha-demo (a 10-pull at the start).

const LOBBY_SCENE := "res://src/lobby/lobby.tscn"
const RNAME := {"common": "Thường", "rare": "Hiếm", "epic": "Sử thi", "legendary": "Huyền thoại"}

var _slot: Slot
var _g: Gacha
var _bid := "weapon"
var _last: Array = []
var _rng := RandomNumberGenerator.new()
var _scroll := Vector2.ZERO
var _layer: CanvasLayer


func _ready() -> void:
	Sfx.music("menu")
	var prefs := Prefs.current()
	if prefs.is_fixed():
		prefs.ensure_preview_slot()
		_rng.seed = 5
	else:
		prefs.ensure_slots()
		_rng.randomize()
	_slot = prefs.active_slot
	if _slot == null:
		get_tree().change_scene_to_file.call_deferred("res://src/front/characters.tscn")
		return
	_g = Gacha.load_default()
	if OS.get_cmdline_user_args().has("--gacha-demo"):
		_slot.gems = maxi(_slot.gems, _g.cost(10))
		_last = _g.pull(_slot, _bid, 10, _rng)
	_build()


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


func _pull(n: int) -> void:
	var got := _g.pull(_slot, _bid, n, _rng)
	if got.is_empty():
		return
	_last = got
	Sfx.play("gacha_pull")
	var best := ""
	for r: Dictionary in got:
		if r["rarity"] == "legendary" or (r["rarity"] == "epic" and best == ""):
			best = String(r["rarity"])
	if best != "":
		Sfx.play("gacha_legend" if best == "legendary" else "gacha_epic")
	if not Prefs.current().is_fixed():
		Prefs.current().slot_store().save(_slot)
	_rebuild()


func _build() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	var root := Control.new()
	root.size = get_viewport_rect().size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	var title := UiKit.label("Gacha · %s" % _slot.name, 34, UiKit.GOLD)
	title.position = Vector2(40, 24)
	root.add_child(title)
	var wallet := HBoxContainer.new()
	wallet.add_theme_constant_override("separation", 22)
	wallet.position = Vector2(42, 70)
	root.add_child(wallet)
	wallet.add_child(UiKit.stat("gem", "%d đá" % _slot.gems, "Đá: thắng ải (lần đầu nhiều hơn).", 16))
	wallet.add_child(UiKit.stat("coin", "%d vàng" % _slot.gold, "Vàng", 16))
	var back := UiKit.button("Quay lại  (Esc)", func() -> void: get_tree().change_scene_to_file(LOBBY_SCENE), Vector2(180, 42), 17)
	back.position = Vector2(root.size.x - 40 - 180, 28)
	root.add_child(back)
	# left: banners with their own pity
	var left := VBoxContainer.new()
	left.position = Vector2(40, 112)
	left.add_theme_constant_override("separation", 10)
	root.add_child(left)
	for b: Dictionary in _g.banners():
		left.add_child(_banner_button(b))
	# middle: last results
	var mid := UiKit.panel(Color(0.09, 0.08, 0.13, 0.94), 16)
	mid.position = Vector2(316, 112)
	mid.custom_minimum_size = Vector2(584, 568)
	mid.size = mid.custom_minimum_size
	root.add_child(mid)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 10)
	mid.add_child(mv)
	mv.add_child(UiKit.label("Kết quả", 22, UiKit.TEXT))
	if _last.is_empty():
		var hint := UiKit.label("Chọn banner rồi bấm Quay 1 hoặc Quay 10. Món mới vào túi đồ; món trùng đổi thành vàng.", 15, UiKit.MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(540, 0)
		mv.add_child(hint)
	else:
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		mv.add_child(grid)
		for r: Dictionary in _last:
			grid.add_child(_result_card(r))
	# right: rates, pity rule, price, buttons
	var right := UiKit.panel(Color(0.09, 0.08, 0.13, 0.94), 16)
	right.position = Vector2(916, 112)
	right.custom_minimum_size = Vector2(324, 568)
	right.size = right.custom_minimum_size
	root.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	right.add_child(rv)
	rv.add_child(UiKit.label("Tỉ lệ mỗi lượt", 20, UiKit.TEXT))
	var rates: Dictionary = _g.data.get("rates", {})
	for r in Gacha.ORDER:
		if rates.has(r):
			var row := HBoxContainer.new()
			rv.add_child(row)
			var nl := UiKit.label(String(RNAME.get(r, r)), 16, UiKit.RARITY.get(r, UiKit.TEXT))
			nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(nl)
			row.add_child(UiKit.label("%.0f%%" % (float(rates[r]) * 100.0), 16, UiKit.TEXT))
	var rule := UiKit.label("Lượt thứ %d kể từ món huyền thoại gần nhất chắc chắn ra huyền thoại; ra huyền thoại thì đếm lại. Mỗi banner đếm riêng. Quay 1 và quay 10 cùng tỉ lệ. Chỉ ra đồ class này mặc được; món trùng đổi thành vàng." % _g.pity_at(), 14, UiKit.MUTED)
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(rule)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(spacer)
	for n in [1, 10]:
		var b := UiKit.button("Quay %d  ·  %d đá" % [n, _g.cost(n)], func() -> void: _pull(n),
			Vector2(0, 56 if n == 10 else 48), 20 if n == 10 else 17, UiKit.PRIMARY if n == 10 else UiKit.PANEL)
		b.disabled = _slot.gems < _g.cost(n)
		rv.add_child(b)
		if n == 10 and not b.disabled:
			b.call_deferred("grab_focus")


func _banner_button(b: Dictionary) -> Button:
	var id := String(b["id"])
	var on := id == _bid
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(260, 104)
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_stylebox_override("normal", UiKit.style(UiKit.PANEL_HOVER if on else UiKit.PANEL, 12, Color.WHITE if on else UiKit.GOLD, 3 if on else 2))
	for st in ["hover", "focus", "pressed"]:
		btn.add_theme_stylebox_override(st, UiKit.style(UiKit.PANEL_HOVER, 12, Color.WHITE, 3))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_top = 10
	v.offset_right = -14
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(v)
	for l in [UiKit.label("Banner " + String(b.get("name", id)), 20, UiKit.TEXT), UiKit.label(String(b.get("desc", "")), 13, UiKit.MUTED),
			UiKit.label("%d/%d lượt tới huyền thoại chắc chắn" % [int(_slot.pity.get(id, 0)), _g.pity_at()], 13, UiKit.RARITY["legendary"])]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	btn.pressed.connect(func() -> void:
		_bid = id
		_rebuild())
	return btn


func _result_card(r: Dictionary) -> PanelContainer:
	var d: Dictionary = _slot.profile.defs.get(String(r["id"]), {})
	var col: Color = UiKit.RARITY.get(String(r["rarity"]), UiKit.TEXT)
	var p := UiKit.panel(Color(col, 0.12).blend(UiKit.PANEL_DARK), 6, col)
	p.custom_minimum_size = Vector2(102, 150)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var ic := UiKit.icon(String(d.get("icon", r["id"])), 48.0)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var nm := UiKit.label(String(d.get("name", r["id"])), 13, col)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.custom_minimum_size.x = 88
	v.add_child(nm)
	var tag := UiKit.label(("Trùng → +%d vàng" % int(r["gold"])) if bool(r["dup"]) else "Mới", 12, UiKit.MUTED if bool(r["dup"]) else Color("8fe08a"))
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.custom_minimum_size.x = 88
	v.add_child(tag)
	Tip.attach(p, String(d.get("name", r["id"])), String(d.get("desc", "")), col, String(d.get("icon", r["id"])), String(RNAME.get(String(r["rarity"]), "")))
	return p
