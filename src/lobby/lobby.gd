extends Node2D
## The lobby (waiting screen) before a run: title, the hero idling on the
## stage's grass, the chosen class with its base stats (icons), the stage, and
## Start / Quit. Start (Enter, or A on a pad) loads the run scene. The class
## switches with the ‹ › buttons or Left / Right; the choice is saved (Prefs.hero).

const DATA := "res://assets/data/"
const SPRITES := "res://assets/sprites/custom/"
const RUN_SCENE := "res://src/run/run.tscn"
const STAGES_PATH := "res://assets/data/stages.json"
const HERO_SCALE := 6.0

const GOLD := Color("c9a65a")
const TEXT := Color("f2ecd8")
const MUTED := Color("b9b2a0")
const PANEL := Color("2a2438")
const PANEL_HOVER := Color("3b3352")
const SHADOW := Color(0, 0, 0, 0.7)

var _hero: SpriteSheet
var _class: Dictionary
var _stage: Dictionary
var _stages: Stages
var _stage_n := 1
var _t := 0.0
var _scroll := Vector2.ZERO
var _layer: CanvasLayer
var _classes := {}
var _class_ids: Array[String] = []
var _dirty_stats := false   # equipment changed: rebuild the menu when the panel closes
var _slot_mode := false       # true when using a character slot (phase 3)


func _ready() -> void:
	_classes = GameData.load_json(DATA + "classes.json")
	for id: String in _classes:
		if not id.begins_with("_"):
			_class_ids.append(id)
	_stages = Stages.load_default()
	var prefs := Prefs.current()
	if not prefs.is_fixed():
		prefs.ensure_slots()
		if prefs.active_slot == null:
			var all := prefs.slot_store().list()
			for e: Dictionary in all:
				if e.get("slot") != null:
					prefs.select_slot(String(e["id"]))
					break
		if prefs.active_slot != null:
			_slot_mode = true
			prefs.hero = prefs.active_slot.cls
			prefs.stage_target = clampi(prefs.stage_target, 1, prefs.active_slot.unlocked(_stages.count()))
	_stage_n = prefs.stage_target if _slot_mode else 1
	_stage_n = clampi(_stage_n, 1, _stages.count())
	_stage = _stages.load_stage(_stage_n)
	_load_class(prefs.hero)
	_build_ui()
	get_viewport().size_changed.connect(func() -> void:
		if _layer != null:
			_layer.queue_free()
		_build_ui())


func _load_class(id: String) -> void:
	if not _classes.has(id):
		id = _class_ids[0]
	_class = _classes[id]
	var sprite := String(_class.get("sprite", "swordsman"))
	_hero = SpriteSheet.load_dir(SPRITES + sprite, sprite)
	if _hero != null and not _hero.layer_names().is_empty():
		_hero.compose_layers()   # equipment will pass its layers here


## Next / previous class (step +1 / -1): saved for the run, the menu rebuilt.
## In slot mode the class is fixed (design/progression.md).
func switch_class(step: int) -> void:
	if _slot_mode:
		return
	var i := _class_ids.find(Prefs.current().hero)
	var id := _class_ids[posmod(i + step, _class_ids.size())]
	Prefs.current().set_value("hero", id)
	_load_class(id)
	if _layer != null:
		_layer.queue_free()
	_build_ui()


func switch_stage(step: int) -> void:
	var prefs := Prefs.current()
	var max_n := _stages.count()
	if _slot_mode and prefs.active_slot != null:
		max_n = prefs.active_slot.unlocked(_stages.count())
	_stage_n = clampi(_stage_n + step, 1, max_n)
	prefs.set_value("stage_target", _stage_n) # persisted in settings; slot unlocked limits it
	_stage = _stages.load_stage(_stage_n)
	if _layer != null:
		_layer.queue_free()
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		switch_class(-1)
	elif event.is_action_pressed("ui_right"):
		switch_class(1)


func _process(delta: float) -> void:
	_t += delta
	_scroll += Vector2(18.0, 6.0) * delta   # the field drifts slowly behind the menu
	queue_redraw()


func _draw() -> void:
	var size := get_viewport_rect().size
	var view := Rect2(_scroll, size)
	draw_set_transform(-_scroll)
	RunGround.draw(self, view.grow(64.0), 1.0e9, _stages.ground(_stage_n) if _stages != null else {})
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.05, 0.55))
	# darker bands top and bottom frame the screen
	for k in 6:
		var a := 0.08 * (6 - k)
		draw_rect(Rect2(0, k * 14, size.x, 14), Color(0, 0, 0, a))
		draw_rect(Rect2(0, size.y - (k + 1) * 14, size.x, 14), Color(0, 0, 0, a))
	# hero stage: a stone pedestal with a rune ring in the class colour
	var feet := Vector2(PEDESTAL_X, PEDESTAL_Y)
	var col := Color(String(_class.get("color", "c9a65a")))
	_ellipse(feet + Vector2(0, 10), Vector2(150, 40), Color(0, 0, 0, 0.35))
	_ellipse(feet + Vector2(0, 6), Vector2(132, 34), Color("2a2533"))
	_ellipse(feet, Vector2(132, 34), Color("4a4458"))
	_ellipse(feet, Vector2(118, 28), Color("5c556c"))
	for k in 24:   # rune ring turning slowly
		var ang := k * TAU / 24.0 + _t * 0.35
		var p := feet + Vector2(cos(ang) * 104.0, sin(ang) * 24.0)
		var lit := 0.55 + 0.45 * sin(_t * 2.0 + k * 0.8)
		draw_rect(Rect2(p - Vector2(3, 2), Vector2(6, 4)), Color(col, lit))
	_ellipse(feet + Vector2(0, -2), Vector2(70, 14), Color(col, 0.18 + 0.08 * sin(_t * 2.0)))
	if _hero != null:
		_hero.draw(self, "idle", _t, feet, HERO_SCALE)


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 40:
		var ang := k * TAU / 40.0
		pts.append(c + Vector2(cos(ang) * r.x, sin(ang) * r.y))
	draw_colored_polygon(pts, col)


const ROW_H := 64.0
const BOTTOM_ROW := 108.0   # top of the stage card / start button row, from the bottom
const PEDESTAL_X := 300.0
const PEDESTAL_Y := 470.0


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_layer = layer
	var root := Control.new()
	root.size = get_viewport_rect().size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var vp := get_viewport_rect().size
	var menu := Control.new()   # everything but the settings page (hidden while it shows)
	menu.size = vp
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(menu)
	var accent := Color(String(_class.get("color", "c9a65a")))

	# top bar: title left, settings / quit right
	var title := _label("BÁCH ẢI", 46, GOLD)
	title.position = Vector2(32, 18)
	menu.add_child(title)
	var sub := _label("Vượt trăm ải", 16, MUTED)
	sub.position = Vector2(36, 74)
	menu.add_child(sub)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var top_buttons := [_button("Nhân vật", func() -> void: _show_slots(root, menu)),
		_button("Trang bị", func() -> void: _show_equipment(root, menu)),
		_button("Cài đặt", func() -> void: _show_settings(root, menu)),
		_button("Thoát", func() -> void: get_tree().quit())]
	top.position = Vector2(vp.x - 32 - top_buttons.size() * 140 - (top_buttons.size() - 1) * 10, 26)
	menu.add_child(top)
	for b in top_buttons:
		b.custom_minimum_size = Vector2(140, 42)
		b.add_theme_font_size_override("font_size", 18)
		top.add_child(b)

	# hero stage (drawn in _draw): arrows either side, name and role under it
	if not _slot_mode:
		var prev := _arrow("‹", func() -> void: switch_class(-1))
		prev.position = Vector2(PEDESTAL_X - 230, PEDESTAL_Y - 150)
		prev.custom_minimum_size = Vector2(52, 64)
		menu.add_child(prev)
		var nxt := _arrow("›", func() -> void: switch_class(1))
		nxt.position = Vector2(PEDESTAL_X + 178, PEDESTAL_Y - 150)
		nxt.custom_minimum_size = Vector2(52, 64)
		menu.add_child(nxt)
	var cname := _label(String(_class.get("name", "")), 40, TEXT)
	cname.position = Vector2(PEDESTAL_X - 260, PEDESTAL_Y + 50)
	cname.size = Vector2(520, 50)
	cname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(cname)
	var role := _label(String(_class.get("role", "")), 18, accent.lightened(0.35))
	role.position = Vector2(PEDESTAL_X - 260, PEDESTAL_Y + 100)
	role.size = Vector2(520, 26)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(role)
	var dots := _label(" ".join(_class_ids.map(func(id: String) -> String: return "●" if _classes[id] == _class else "○")), 16, MUTED)
	dots.position = Vector2(PEDESTAL_X - 260, PEDESTAL_Y + 130)
	dots.size = Vector2(520, 24)
	dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(dots)

	# right: the class card (stats, passive, starting skill, skill set)
	var card := _card()
	card.position = Vector2(620, 104)
	card.custom_minimum_size = Vector2(vp.x - 620 - 32, 0)
	menu.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 12)
	card.add_child(cv)
	# stats with the worn equipment (green where it adds something)
	var base: Dictionary = _class.get("stats", {})
	var prof := Prefs.current().profile()
	var cid := Prefs.current().hero
	var stats := PlayerStats.compute(base, prof.as_upgrades(cid), prof.levels(cid))
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 10)
	cv.add_child(tiles)
	for t in [["heart", "Máu", "max_hp", "%d"], ["sword", "Sát thương", "damage", "%d"],
			["boot", "Tốc độ", "move_speed", "%d"], ["magnet", "Tầm hút", "magnet", "×%.1f"]]:
		var val := float(stats.get(t[2], 0.0))
		var txt: String = (t[3] % roundi(val)) if t[3] == "%d" else (t[3] % val)
		tiles.add_child(_tile(t[0], t[1], txt, not is_equal_approx(val, float(base.get(t[2], val)))))
	var pv: Dictionary = _class.get("passive", {})
	if not pv.is_empty():
		cv.add_child(_section("Nội tại", accent))
		cv.add_child(_feature(String(pv.get("id", "")), String(pv.get("name", "")), String(pv.get("desc", "")), accent))
	var pool := GameData.load_json(DATA + String(_class.get("upgrades", "")))
	var ups: Dictionary = {}
	for u: Dictionary in pool.get("upgrades", []):
		ups[u["id"]] = u
	for sid: String in _class.get("start_skills", {}):
		cv.add_child(_section("Chiêu khởi đầu", GOLD))
		var u: Dictionary = ups.get(sid, {})
		cv.add_child(_feature(sid, String(u.get("name", sid)), String(u.get("desc", "")), GOLD))
	var skills := ups.values().filter(func(u: Dictionary) -> bool: return u.get("kind") == "skill")
	cv.add_child(_section("Bộ chiêu (%d chiêu · %d thẻ chỉ số)" % [skills.size(), ups.size() - skills.size()], GOLD))
	var icons := HFlowContainer.new()
	icons.add_theme_constant_override("h_separation", 8)
	icons.add_theme_constant_override("v_separation", 8)
	cv.add_child(icons)
	for u: Dictionary in skills:
		icons.add_child(_icon_tile(String(u.get("icon", u["id"])), String(u.get("name", "")), String(u.get("desc", ""))))

	# bottom: stage and start
	var stage_card := _card()
	stage_card.position = Vector2(620, vp.y - BOTTOM_ROW)
	stage_card.custom_minimum_size = Vector2(0, ROW_H)
	menu.add_child(stage_card)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 10)
	sh.alignment = BoxContainer.ALIGNMENT_CENTER
	stage_card.add_child(sh)
	var pick_stage := Button.new()
	pick_stage.text = "Chọn ải"
	pick_stage.custom_minimum_size = Vector2(110, 42)
	pick_stage.add_theme_font_size_override("font_size", 16)
	pick_stage.add_theme_stylebox_override("normal", _style(PANEL, 6))
	pick_stage.add_theme_stylebox_override("hover", _style(PANEL_HOVER, 6))
	pick_stage.pressed.connect(func() -> void: _show_stage_select(root, menu))
	sh.add_child(pick_stage)
	if _slot_mode:
		var prev_s := _arrow("‹", func() -> void: switch_stage(-1))
		prev_s.custom_minimum_size = Vector2(36, 40)
		prev_s.add_theme_font_size_override("font_size", 22)
		sh.add_child(prev_s)
	var sname := String(_stage.get("name", ""))
	if sname == "" or sname == String(_stage.get("region", "")):
		sname = String(_stage.get("region", "Ải %d" % _stage_n))
	sh.add_child(_label("Ải %d · %s" % [_stage_n, sname], 22, GOLD))
	if _slot_mode:
		var next_s := _arrow("›", func() -> void: switch_stage(1))
		next_s.custom_minimum_size = Vector2(36, 40)
		next_s.add_theme_font_size_override("font_size", 22)
		sh.add_child(next_s)
	var dur := int(_stage.get("duration", 0))
	sh.add_child(_stat("clock", "", "%02d:%02d" % [dur / 60, dur % 60]))
	if _stages.is_boss(_stage_n):
		sh.add_child(_label("BOSS", 18, Color("ffd36b")))
	var start := _button("Bắt đầu  ▶", func() -> void:
		Prefs.current().set_value("stage_target", _stage_n)
		get_tree().change_scene_to_file(RUN_SCENE))
	start.custom_minimum_size = Vector2(300, ROW_H)
	start.add_theme_font_size_override("font_size", 26)
	start.add_theme_stylebox_override("normal", _style(accent.darkened(0.45), 8))
	start.add_theme_stylebox_override("hover", _style(accent.darkened(0.25), 8))
	start.add_theme_stylebox_override("focus", _style(accent.darkened(0.25), 8))
	start.position = Vector2(vp.x - 32 - 300, vp.y - BOTTOM_ROW)
	menu.add_child(start)
	start.call_deferred("grab_focus")

	# Pending milestone reward (slot): claim without entering a run.
	if _slot_mode and Prefs.current().active_slot != null and not Prefs.current().active_slot.pending.is_empty():
		var slot: Slot = Prefs.current().active_slot
		var claim := _button("Nhận phần thưởng mốc ải %d" % int(slot.pending[0]), func() -> void: _show_milestone_claim(root, menu, slot, int(slot.pending[0])))
		claim.custom_minimum_size = Vector2(360, 46)
		claim.add_theme_font_size_override("font_size", 18)
		claim.add_theme_stylebox_override("normal", _style(Color("4a3a10"), 8))
		claim.add_theme_stylebox_override("hover", _style(Color("6a5218"), 8))
		claim.position = Vector2(620, vp.y - BOTTOM_ROW - 58)
		menu.add_child(claim)
	if OS.get_cmdline_user_args().has("--lobby-settings"):   # shots of the settings page
		_show_settings.call_deferred(root, menu)
	if OS.get_cmdline_user_args().has("--lobby-gear"):       # shots of the equipment page
		_show_equipment.call_deferred(root, menu)
	if OS.get_cmdline_user_args().has("--lobby-slots"):      # shots of the slot page
		_show_slots.call_deferred(root, menu)
	if OS.get_cmdline_user_args().has("--lobby-stages"):     # shots of the stage grid
		_show_stage_select.call_deferred(root, menu)

	var hint := _label("Enter: bắt đầu  ·  ← / →: đổi class  ·  Trong trận: WASD di chuyển, Space lướt, Tab nhân vật, Esc tạm dừng", 14, MUTED)
	hint.position = Vector2(32, vp.y - 30)
	menu.add_child(hint)


## A stat tile: icon over the value, the name under it.
func _tile(icon: String, name: String, value: String, boosted := false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(Color("231d30"), 8))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	p.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	var tex := TextureRect.new()
	tex.texture = UiIcons.texture(icon)
	tex.custom_minimum_size = Vector2(28, 28)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h.add_child(tex)
	h.add_child(_label(value, 24, Color("8ee08e") if boosted else TEXT))
	var n := _label(name + (" (có trang bị)" if boosted else ""), 14, MUTED)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	return p


func _section(text: String, col: Color) -> Label:
	return _label(text, 16, col)


## Icon, name and description of a passive or skill.
func _feature(icon: String, name: String, desc: String, col: Color) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var frame := PanelContainer.new()
	var st := _style(Color("1d1828"), 4)
	st.border_color = col
	frame.add_theme_stylebox_override("panel", st)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(frame)
	var tex := TextureRect.new()
	tex.texture = UiIcons.texture(icon)
	tex.custom_minimum_size = Vector2(40, 40)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(tex)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(_label(name, 20, TEXT))
	var d := _label(desc, 14, MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	return h


func _icon_tile(icon: String, name: String, desc: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(Color("1d1828"), 4))
	p.tooltip_text = name + "\n" + desc
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var tex := TextureRect.new()
	tex.texture = UiIcons.texture(icon)
	tex.custom_minimum_size = Vector2(36, 36)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(tex)
	return p


## Settings over the lobby: the menu column hides, the shared settings panel
## shows centred on a card; "Quay lại" brings the menu back.
func _show_settings(root: Control, menu: Control) -> void:
	menu.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var card := PanelContainer.new()
	var st := _style(Color(0.09, 0.08, 0.13, 0.95), 24)
	card.add_theme_stylebox_override("panel", st)
	center.add_child(card)
	card.add_child(SettingsPanel.build(func() -> void:
		center.queue_free()
		menu.visible = true))


const SLOT_NAME := {"head": "Đầu", "chest": "Ngực", "arms": "Tay", "legs": "Chân", "weapon": "Vũ khí"}
const RARITY := {"common": Color("e8e2d0"), "rare": Color("6fb7ff"), "epic": Color("c38df5")}


## Stage select: a grid of 3 regions x 10 stages (design/progression.md). Locked
## cells are dim with a lock, cleared ones show ✓, boss/milestone cells have a
## gold frame, and the playable frontier is highlighted.
func _show_stage_select(root: Control, menu: Control) -> void:
	menu.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _style(Color(0.09, 0.08, 0.13, 0.97), 20))
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	col.add_child(_label("Chọn ải", 30, GOLD))
	col.add_child(_label("Vượt ải để mở ải tiếp theo; ải 10/20/30 là ải boss, thưởng mốc vĩnh viễn.", 14, MUTED))
	var prefs := Prefs.current()
	var best := prefs.active_slot.best if _slot_mode and prefs.active_slot != null else 0
	var unlocked := mini(best + 1, _stages.count())
	var regions: Array = _stages.regions()
	for r: Dictionary in regions:
		var from := int(r.get("from", 1))
		var to := int(r.get("to", 10))
		col.add_child(_label(String(r.get("name", "Vùng")), 18, GOLD))
		var grid := HBoxContainer.new()
		grid.add_theme_constant_override("separation", 6)
		col.add_child(grid)
		for n in range(from, to + 1):
			var b := Button.new()
			b.custom_minimum_size = Vector2(64, 56)
			b.add_theme_font_size_override("font_size", 20)
			var locked := n > unlocked
			var cleared := _slot_mode and prefs.active_slot != null and prefs.active_slot.won(n)
			var boss := _stages.is_boss(n)
			if n == _stage_n:
				b.text = str(n)
				b.add_theme_stylebox_override("normal", _style(Color("4a5a2a"), 6))
			elif locked:
				b.text = "×"
				b.add_theme_stylebox_override("normal", _style(Color("1d1828"), 6))
			elif cleared:
				b.text = "✓ %d" % n
				b.add_theme_stylebox_override("normal", _style(Color("23402a"), 6))
			else:
				b.text = str(n)
				b.add_theme_stylebox_override("normal", _style(PANEL, 6))
			if boss:
				b.add_theme_stylebox_override("normal", _style(Color("4a3a10") if not locked else Color("2a2218"), 6))
			b.disabled = locked
			var tip := "Ải %d" % n
			if boss:
				tip += " · BOSS · thưởng mốc"
			b.tooltip_text = tip
			b.pressed.connect(func() -> void:
				_stage_n = n
				prefs.set_value("stage_target", n)
				_stage = _stages.load_stage(n)
				center.queue_free()
				menu.visible = true
				_layer.queue_free()
				_build_ui())
			grid.add_child(b)
	var back := _button("Quay lại", func() -> void:
		center.queue_free()
		menu.visible = true)
	back.custom_minimum_size = Vector2(220, 44)
	back.add_theme_font_size_override("font_size", 18)
	col.add_child(back)
	back.call_deferred("grab_focus")


## Character slots: play / rename / delete / create (design/progression.md).
func _show_slots(root: Control, menu: Control) -> void:
	menu.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _style(Color(0.09, 0.08, 0.13, 0.97), 22))
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(940, 0)
	card.add_child(col)
	col.add_child(_label("Nhân vật", 32, GOLD))
	var prefs := Prefs.current()
	var store := prefs.slot_store()
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	col.add_child(body)
	var refresh := func() -> void: pass
	refresh = func() -> void:
		for c in body.get_children():
			c.queue_free()
		var entries := store.list()
		if entries.is_empty():
			body.add_child(_label("Chưa có nhân vật. Tạo một nhân vật để bắt đầu.", 16, MUTED))
		for e: Dictionary in entries:
			var id := String(e["id"])
			var s: Slot = e["slot"]
			if s == null:
				var broken := PanelContainer.new()
				broken.add_theme_stylebox_override("panel", _style(Color("3a2020"), 10))
				var bl := _label("Slot %s: không đọc được (%s) — chỉ có thể xoá." % [id, String(e["error"])], 16, Color("ff9a9a"))
				broken.add_child(bl)
				var bd := Button.new()
				bd.text = "Xóa"
				bd.add_theme_stylebox_override("normal", _style(PANEL, 8))
				bd.pressed.connect(func() -> void:
					store.delete(id)
					refresh.call())
				broken.add_child(bd)
				body.add_child(broken)
				continue
			body.add_child(_slot_row(s, id, store, refresh))
		# create row: name + class
		var make := HBoxContainer.new()
		make.add_theme_constant_override("separation", 10)
		var name_edit := LineEdit.new()
		name_edit.placeholder_text = "Tên nhân vật"
		name_edit.custom_minimum_size = Vector2(220, 44)
		make.add_child(name_edit)
		var class_pick := OptionButton.new()
		for cid: String in _class_ids:
			class_pick.add_item(String(_classes[cid].get("name", cid)))
		make.add_child(class_pick)
		var make_b := Button.new()
		make_b.text = "Tạo mới"
		make_b.custom_minimum_size = Vector2(150, 44)
		make_b.add_theme_stylebox_override("normal", _style(PANEL, 8))
		make_b.pressed.connect(func() -> void:
			var cls := _class_ids[clampi(class_pick.selected, 0, _class_ids.size() - 1)]
			var n := name_edit.text.strip_edges()
			if n == "":
				n = "Nhân vật %d" % (store.list().size() + 1)
			var created := store.create(n, cls)
			if created == null:
				make_b.tooltip_text = "Đã đầy 4 slot."
				return
			prefs.select_slot(created.id)
			_slot_mode = true
			_stage_n = 1
			_stage = _stages.load_stage(1)
			refresh.call())
		make.add_child(make_b)
		if store.list().size() >= 4:
			make_b.disabled = true
			name_edit.disabled = true
			class_pick.disabled = true
		body.add_child(make)
	var back := _button("Quay lại", func() -> void:
		center.queue_free()
		menu.visible = true
		_layer.queue_free()
		_build_ui())
	back.custom_minimum_size = Vector2(220, 46)
	back.add_theme_font_size_override("font_size", 18)
	col.add_child(back)
	refresh.call()
	back.call_deferred("grab_focus")


func _slot_row(s: Slot, id: String, store: SlotStore, refresh: Callable) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(PANEL, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var active := Prefs.current().active_slot != null and Prefs.current().active_slot.id == id
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	head.add_child(_label(("● " if active else "○ ") + s.name, 22, GOLD if active else TEXT))
	head.add_child(_label(String(_classes.get(s.cls, {}).get("name", s.cls)), 16, MUTED))
	v.add_child(_label("Ải cao nhất: %d  ·  Vàng: %d  ·  Đá: %d" % [s.best, s.gold, s.gems], 15, MUTED))
	var rw := s.rewards()
	var rw_names: Array[String] = []
	var ms := Milestones.load_default()
	var pool := GameData.load_json(DATA + String(_classes.get(s.cls, {}).get("upgrades", "")))
	for rid: String in rw:
		rw_names.append(String(ms.info(rid, pool.get("upgrades", [])).get("name", rid)))
	var pending_names := PackedStringArray()
	for x: Variant in s.pending:
		pending_names.append(str(x))
	var mtext := "Mốc: " + (", ".join(rw_names) if not rw_names.is_empty() else "chưa có")
	if not s.pending.is_empty():
		mtext += "  ·  Chờ chọn: " + ", ".join(pending_names)
	v.add_child(_label(mtext, 14, MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var edit := LineEdit.new()
	edit.text = s.name
	edit.custom_minimum_size = Vector2(200, 38)
	row.add_child(edit)
	var rename := Button.new()
	rename.text = "Đổi tên"
	rename.add_theme_stylebox_override("normal", _style(PANEL, 6))
	rename.pressed.connect(func() -> void:
		s.name = edit.text.strip_edges()
		if s.name == "":
			s.name = id
		store.save(s)
		refresh.call())
	row.add_child(rename)
	var play := Button.new()
	play.text = "Chọn" if not active else "Đang chơi"
	play.disabled = active
	play.add_theme_stylebox_override("normal", _style(PANEL, 6))
	play.pressed.connect(func() -> void:
		Prefs.current().select_slot(id)
		_slot_mode = true
		_stage_n = clampi(Prefs.current().stage_target, 1, s.unlocked(_stages.count()))
		_stage = _stages.load_stage(_stage_n)
		refresh.call())
	row.add_child(play)
	var del := Button.new()
	del.text = "Xóa"
	del.add_theme_stylebox_override("normal", _style(Color("4a2424"), 6))
	del.pressed.connect(func() -> void:
		store.delete(id)
		if Prefs.current().active_slot != null and Prefs.current().active_slot.id == id:
			Prefs.current().active_slot = null
			Prefs.current().slot_id = ""
			for e2: Dictionary in store.list():
				if e2.get("slot") != null:
					Prefs.current().select_slot(String(e2["id"]))
					break
		refresh.call())
	row.add_child(del)
	return p


## Pick a pending milestone reward for [param slot] at stage [param ms].
func _show_milestone_claim(root: Control, menu: Control, slot: Slot, ms: int) -> void:
	menu.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _style(Color(0.09, 0.08, 0.13, 0.96), 24))
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(860, 0)
	card.add_child(col)
	col.add_child(_label("Phần thưởng mốc ải %d" % ms, 32, GOLD))
	col.add_child(_label("Chọn 1 trong 3 phần thưởng vĩnh viễn cho %s." % slot.name, 16, MUTED))
	var milestones := Milestones.load_default()
	var offers: Array[String] = milestones.offers(ms, slot.cls)
	var pool := GameData.load_json(DATA + String(_classes.get(slot.cls, {}).get("upgrades", "")))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	for oid: String in offers:
		var info: Dictionary = milestones.info(oid, pool.get("upgrades", []))
		var b := Button.new()
		b.custom_minimum_size = Vector2(270, 210)
		b.add_theme_stylebox_override("normal", _style(PANEL, 12))
		b.add_theme_stylebox_override("hover", _style(PANEL_HOVER, 12))
		b.add_theme_stylebox_override("pressed", _style(PANEL_HOVER, 12))
		var vb := VBoxContainer.new()
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.offset_left = 12
		vb.offset_top = 10
		vb.offset_right = -12
		vb.offset_bottom = -10
		vb.add_theme_constant_override("separation", 4)
		b.add_child(vb)
		var tex := TextureRect.new()
		tex.texture = UiIcons.texture(String(info.get("icon", info.get("id", ""))))
		tex.custom_minimum_size = Vector2(48, 48)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(tex)
		var nm := _label(String(info.get("name", "")), 20, GOLD)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(nm)
		var kinds: Dictionary = {"skill": "Chiêu độc nhất", "passive": "Nội tại", "rule": "Luật"}
		var kl := _label(String(kinds.get(String(info.get("kind", "")), "")), 14, MUTED)
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(kl)
		var dl := _label(String(info.get("desc", "")), 12, TEXT)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size = Vector2(246, 88)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.add_child(dl)
		b.pressed.connect(func() -> void:
			slot.choose_milestone(ms, oid)
			if not Prefs.current().is_fixed():
				Prefs.current().slot_store().save(slot)
			center.queue_free()
			menu.visible = true
			_layer.queue_free()
			_build_ui())
		row.add_child(b)
	var back := _button("Để sau", func() -> void:
		center.queue_free()
		menu.visible = true)
	back.custom_minimum_size = Vector2(220, 44)
	back.add_theme_font_size_override("font_size", 18)
	col.add_child(back)


## Equipment of the chosen class: one row per slot (what is worn, its effect) and
## a picker to equip/unequip any fitting item in the bag; the total at the bottom.
func _show_equipment(root: Control, menu: Control) -> void:
	menu.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _style(Color(0.09, 0.08, 0.13, 0.96), 24))
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(700, 0)
	card.add_child(col)
	var cls := Prefs.current().hero
	var prof := Prefs.current().profile()
	col.add_child(_label("Trang bị · %s" % String(_class.get("name", "")), 30, GOLD))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	col.add_child(rows)
	var total := _label("", 15, MUTED)
	total.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var refresh := func() -> void: pass
	refresh = func() -> void:
		for c in rows.get_children():
			c.queue_free()
		for slot: String in Profile.SLOTS:
			rows.add_child(_gear_row(root, prof, cls, slot, refresh))
		var parts := []
		for slot: String in prof.equipped(cls):
			parts.append(String(prof.defs.get(prof.equipped(cls)[slot], {}).get("desc", "")))
		total.text = "Tổng: " + (" · ".join(parts) if not parts.is_empty() else "chưa mặc gì.")
	refresh.call()
	col.add_child(total)
	col.add_child(_label("Thắng ải hoặc mở rương tinh anh để nhận thêm trang bị. Bấm “Chọn” để mặc/bỏ.", 13, MUTED))
	var back := _button("Quay lại", func() -> void:
		center.queue_free()
		menu.visible = true
		if _dirty_stats:   # the stat tiles show the new equipment
			_dirty_stats = false
			_layer.queue_free()
			_build_ui())
	col.add_child(back)
	back.call_deferred("grab_focus")


func _gear_row(root: Control, prof: Profile, cls: String, slot: String, refresh: Callable) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(Color("231d30"), 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var sl := _label(String(SLOT_NAME.get(slot, slot)), 16, MUTED)
	sl.custom_minimum_size = Vector2(70, 0)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sl)
	var id := String(prof.equipped(cls).get(slot, ""))
	var d: Dictionary = prof.defs.get(id, {})
	var tex := TextureRect.new()
	tex.texture = UiIcons.texture(String(d.get("icon", id))) if id != "" else null
	tex.custom_minimum_size = Vector2(36, 36)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h.add_child(tex)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	v.add_child(_label(String(d.get("name", "Trống")), 18, RARITY.get(String(d.get("rarity", "common")), TEXT) if id != "" else MUTED))
	if id != "":
		v.add_child(_label(String(d.get("desc", "")), 13, MUTED))
	var choices := prof.choices(cls, slot)
	var b := _button("Chọn (%d)" % choices.size(), func() -> void:
		_show_gear_picker(root, prof, cls, slot, refresh))
	b.custom_minimum_size = Vector2(120, 40)
	b.add_theme_font_size_override("font_size", 16)
	b.disabled = choices.is_empty() and id == ""
	h.add_child(b)
	return p


## Pick one of the owned items for [param slot] (or unequip). Saved immediately.
func _show_gear_picker(root: Control, prof: Profile, cls: String, slot: String, refresh: Callable) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _style(Color(0.11, 0.1, 0.16, 0.98), 18))
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(520, 0)
	card.add_child(col)
	var worn_id := String(prof.equipped(cls).get(slot, ""))
	col.add_child(_label("Chọn trang bị · %s" % String(SLOT_NAME.get(slot, slot)), 24, GOLD))
	var opts: Array = prof.choices(cls, slot).duplicate()
	if not opts.has("") and worn_id != "":
		pass
	# list owned choices, then unequip
	for item_id: String in opts:
		var d: Dictionary = prof.defs.get(item_id, {})
		var row := Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(500, 52)
		row.add_theme_stylebox_override("normal", _style(Color("231d30"), 8))
		row.add_theme_stylebox_override("hover", _style(PANEL_HOVER, 8))
		row.add_theme_stylebox_override("pressed", _style(PANEL_HOVER, 8))
		var mark := " ✓" if item_id == worn_id else ""
		row.text = "  %s%s  —  %s" % [String(d.get("name", item_id)), mark, String(d.get("desc", ""))]
		row.add_theme_font_size_override("font_size", 18)
		row.add_theme_color_override("font_color", RARITY.get(String(d.get("rarity", "common")), TEXT))
		row.pressed.connect(func() -> void:
			prof.equip(cls, item_id)
			Prefs.current().save_profile()
			_dirty_stats = true
			overlay.queue_free()
			refresh.call())
		col.add_child(row)
	if worn_id != "":
		var off := Button.new()
		off.text = "  Bỏ trang bị"
		off.alignment = HORIZONTAL_ALIGNMENT_LEFT
		off.custom_minimum_size = Vector2(500, 46)
		off.add_theme_font_size_override("font_size", 18)
		off.add_theme_stylebox_override("normal", _style(Color("231d30"), 8))
		off.add_theme_stylebox_override("hover", _style(PANEL_HOVER, 8))
		off.add_theme_stylebox_override("pressed", _style(PANEL_HOVER, 8))
		off.pressed.connect(func() -> void:
			prof.unequip(cls, slot)
			Prefs.current().save_profile()
			_dirty_stats = true
			overlay.queue_free()
			refresh.call())
		col.add_child(off)
	if opts.is_empty() and worn_id == "":
		col.add_child(_label("Chưa có trang bị cho ô này. Thắng ải hoặc mở rương tinh anh để nhận.", 15, MUTED))
	var close := _button("Đóng", func() -> void: overlay.queue_free())
	close.custom_minimum_size = Vector2(220, 44)
	close.add_theme_font_size_override("font_size", 18)
	col.add_child(close)
	close.call_deferred("grab_focus")


func _arrow(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(40, 40)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_stylebox_override("normal", _style(PANEL_HOVER, 6))
	b.add_theme_stylebox_override("hover", _style(Color("4a4066"), 6))
	b.add_theme_stylebox_override("pressed", _style(Color("4a4066"), 6))
	b.pressed.connect(cb)
	return b


func _stat(icon: String, label: String, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var tex := TextureRect.new()
	tex.texture = UiIcons.texture(icon)
	tex.custom_minimum_size = Vector2(32, 32)
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	row.add_child(tex)
	var name := _label(label, 20, MUTED)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	row.add_child(_label(value, 22, TEXT))
	return row


func _card() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(PANEL, 16))
	return p


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(380, 52)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_stylebox_override("normal", _style(PANEL, 8))
	b.add_theme_stylebox_override("hover", _style(PANEL_HOVER, 8))
	b.add_theme_stylebox_override("focus", _style(PANEL_HOVER, 8))
	b.add_theme_stylebox_override("pressed", _style(PANEL_HOVER, 8))
	b.pressed.connect(cb)
	return b


func _label(s: String, sz: int, c: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_shadow_color", SHADOW)
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


func _style(bg: Color, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = GOLD
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(pad)
	return s
