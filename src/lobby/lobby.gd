extends Node2D
## The preparation lobby of the chosen character (design/ux/front-end.md): the hero
## on its pedestal with its progress, the class card (stats with equipment, passive,
## skills, level milestones), equipment, stage choice and Start. Characters are
## chosen on the character screen (src/front/characters.tscn): "Nhân vật" and Esc go
## there, "Menu chính" goes to the title. Without a character it opens that screen.

const DATA := "res://assets/data/"
const SPRITES := "res://assets/sprites/custom/"
const CHARACTERS_SCENE := "res://src/front/characters.tscn"
const TITLE_SCENE := "res://src/front/title.tscn"
const EQUIPMENT_SCENE := "res://src/front/equipment.tscn"
const STAGE_SCENE := "res://src/front/stage_select.tscn"
const HERO_SCALE := 6.0

const GOLD := Color("c9a65a")
const TEXT := Color("f2ecd8")
const MUTED := Color("b9b2a0")
const PANEL := Color("2a2438")
const PANEL_HOVER := Color("3b3352")
const SHADOW := Color(0, 0, 0, 0.7)

var _hero: SpriteSheet
var _class: Dictionary
var _stages: Stages
var _stage_n := 1
var _t := 0.0
var _scroll := Vector2.ZERO
var _layer: CanvasLayer
var _classes := {}
var _class_ids: Array[String] = []
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
	if prefs.active_slot == null:
		if prefs.is_fixed():
			prefs.ensure_preview_slot()   # shots: the preview character
		else:
			get_tree().change_scene_to_file.call_deferred(CHARACTERS_SCENE)
			return
	if prefs.active_slot != null:
		_slot_mode = true
		prefs.hero = prefs.active_slot.cls
		prefs.stage_target = clampi(prefs.stage_target, 1, prefs.active_slot.unlocked(_stages.count()))
	_stage_n = prefs.stage_target if _slot_mode else 1
	_stage_n = clampi(_stage_n, 1, _stages.count())
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _layer != null and _layer.get_child(0).get_child(0).visible:
		get_tree().change_scene_to_file(CHARACTERS_SCENE)


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
	var title := _label("Chuẩn bị", 46, GOLD)   # the screen's name; the logo is on the title screen
	title.position = Vector2(32, 18)
	menu.add_child(title)
	var sub := _label("Trang bị, chọn ải rồi vào trận", 16, MUTED)
	sub.position = Vector2(36, 74)
	menu.add_child(sub)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var top_buttons := [_button("Nhân vật", func() -> void: get_tree().change_scene_to_file(CHARACTERS_SCENE)),
		_button("Cài đặt", func() -> void: _show_settings(root, menu)),
		_button("Menu chính", func() -> void: get_tree().change_scene_to_file(TITLE_SCENE))]
	top.position = Vector2(vp.x - 32 - top_buttons.size() * 140 - (top_buttons.size() - 1) * 10, 26)
	menu.add_child(top)
	for b in top_buttons:
		b.custom_minimum_size = Vector2(140, 42)
		b.add_theme_font_size_override("font_size", 18)
		top.add_child(b)

	# hero stage (drawn in _draw): name and role under it
	var slot_now: Slot = Prefs.current().active_slot if _slot_mode else null
	# slot mode: the slot's name big, "class · role" under it, then its progress
	var cname := _label(slot_now.name if slot_now != null else String(_class.get("name", "")), 40, TEXT)
	cname.clip_text = true
	cname.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cname.position = Vector2(PEDESTAL_X - 260, PEDESTAL_Y + 50)
	cname.size = Vector2(520, 50)
	cname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(cname)
	var role_txt := String(_class.get("role", ""))
	if slot_now != null:
		role_txt = "%s · %s" % [String(_class.get("name", "")), role_txt]
	var role := _label(role_txt, 18, accent.lightened(0.35))
	role.position = Vector2(PEDESTAL_X - 260, PEDESTAL_Y + 100)
	role.size = Vector2(520, 26)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(role)
	if slot_now != null:
		# progress: highest stage won, gold, gems (stops before the stage card at x 440)
		var prog := HBoxContainer.new()
		prog.add_theme_constant_override("separation", 16)
		prog.alignment = BoxContainer.ALIGNMENT_CENTER
		prog.position = Vector2(PEDESTAL_X - 140, PEDESTAL_Y + 132)
		prog.custom_minimum_size = Vector2(280, 26)
		menu.add_child(prog)
		for it in [["star", "Ải %d" % slot_now.best, "Ải cao nhất đã vượt"], ["coin", str(slot_now.gold), "Vàng"],
				["gem", str(slot_now.gems), "Đá (gacha, đợt 5)"]]:
			prog.add_child(_small_stat(it[0], it[1], it[2]))

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
	if Prefs.current().active_slot != null:   # equipment + skill tree of the character
		var lasting := SkillTree.lasting(Prefs.current().active_slot)
		stats = PlayerStats.compute(base, lasting[0], lasting[1])
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
	# unique skills are not in the card set: they come from the level milestones
	var skills := ups.values().filter(func(u: Dictionary) -> bool:
		return u.get("kind") == "skill" and not bool(u.get("unique", false)))
	var uniques := ups.values().filter(func(u: Dictionary) -> bool: return bool(u.get("unique", false)))
	var n_stat := ups.values().filter(func(u: Dictionary) -> bool: return u.get("kind") != "skill").size()
	cv.add_child(_section("Bộ chiêu (%d chiêu · %d thẻ chỉ số)" % [skills.size(), n_stat], GOLD))
	var icons := HFlowContainer.new()
	icons.add_theme_constant_override("h_separation", 8)
	icons.add_theme_constant_override("v_separation", 8)
	cv.add_child(icons)
	for u: Dictionary in skills:
		icons.add_child(_icon_tile(String(u.get("icon", u["id"])), String(u.get("name", "")), String(u.get("desc", ""))))
	# level milestones: what the class can pick at levels 10/20/30 of a run
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 8)
	cv.add_child(mrow)
	var head := _section("Mốc cấp 10 · 20 · 30", GOLD)
	head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mrow.add_child(head)
	for u: Dictionary in uniques:
		mrow.add_child(_icon_tile(String(u.get("icon", u["id"])), String(u.get("name", "")), String(u.get("desc", ""))))
	var note := _label("chọn trong trận", 14, MUTED)
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mrow.add_child(note)

	# bottom right: the equipment screen and the main action, choosing a stage
	# (stages and modes have their own screen: design/ux/stage-select.md)
	var start_x := vp.x - 32 - 300
	var gear := _button("Trang bị", func() -> void: get_tree().change_scene_to_file(EQUIPMENT_SCENE))
	gear.custom_minimum_size = Vector2(200, ROW_H)
	gear.add_theme_font_size_override("font_size", 22)
	gear.position = Vector2(start_x - 16 - 200, vp.y - BOTTOM_ROW)
	menu.add_child(gear)
	var start := _button("Chọn ải  ▶", func() -> void: get_tree().change_scene_to_file(STAGE_SCENE))
	start.custom_minimum_size = Vector2(300, ROW_H)
	start.add_theme_font_size_override("font_size", 26)
	start.add_theme_stylebox_override("normal", _style(accent.darkened(0.45), 8))
	start.add_theme_stylebox_override("hover", _style(accent.darkened(0.25), 8))
	start.add_theme_stylebox_override("focus", _style(accent.darkened(0.25), 8))
	start.position = Vector2(start_x, vp.y - BOTTOM_ROW)
	menu.add_child(start)
	start.call_deferred("grab_focus")

	if OS.get_cmdline_user_args().has("--lobby-settings"):   # shots of the settings page
		_show_settings.call_deferred(root, menu)

	var hint := _label("Enter: chọn ải  ·  Esc: chọn nhân vật  ·  Trong trận: WASD di chuyển, Space lướt, Tab nhân vật, Esc tạm dừng", 14, MUTED)
	hint.position = Vector2(32, vp.y - 30)
	menu.add_child(hint)


## A small icon + value (slot progress under the hero); the tooltip names it.
func _small_stat(icon: String, value: String, tip: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	Tip.attach(row, tip)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var tex := TextureRect.new()
	tex.texture = UiIcons.texture(icon)
	tex.custom_minimum_size = Vector2(20, 20)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tex)
	var l := _label(value, 17, TEXT)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	return row


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
	Tip.attach(p, name, desc, GOLD, icon)
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
	_dim(center)
	var card := PanelContainer.new()
	var st := _style(Color(0.09, 0.08, 0.13, 0.95), 24)
	card.add_theme_stylebox_override("panel", st)
	center.add_child(card)
	card.add_child(SettingsPanel.build(func() -> void:
		center.queue_free()
		menu.visible = true))




func _dim(center: Control) -> void:
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	center.draw.connect(func() -> void: center.draw_rect(Rect2(Vector2.ZERO, center.size), Color(0, 0, 0, 0.6)))


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
