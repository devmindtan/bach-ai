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
const TREE_SCENE := "res://src/front/skill_tree.tscn"
const DECK_SCENE := "res://src/front/deck.tscn"
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
	Sfx.music("menu")
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
	var sprite := FrontArt.hero_sprite(_class)
	_hero = SpriteSheet.load_dir(SPRITES + sprite, sprite)
	if _hero != null and not _hero.layer_names().is_empty():
		var slot := Prefs.current().active_slot
		var worn: Array = slot.profile.equipped(slot.cls).values() if slot != null and slot.cls == id else []
		_hero.compose_layers(_hero.gear_overrides(worn))   # worn items drawn on the hero


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _layer != null and _layer.get_child(0).get_child(0).visible:
		get_tree().change_scene_to_file(CHARACTERS_SCENE)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## Hướng A "Trại lửa" (design-web/screens/lobby.md, user 2026-11-26): a night camp; the hero sits by the fire and
## every menu entry is an object on a wooden post round it.
func _draw() -> void:
	var size := get_viewport_rect().size
	var horizon := size.y * 0.56
	for k in 24:   # night sky in bands
		var f := float(k) / 23.0
		draw_rect(Rect2(0, horizon * f, size.x, horizon / 23.0 + 1.0), Color("0b1030").lerp(Color("2a2448"), f))
	for k in 46:   # stars, kept off the text corners
		var p := Vector2(float(k * 97 % int(size.x)), float(k * 53 % 300))
		if (p.x < 320.0 and p.y < 150.0) or (p.x > size.x - 260.0 and p.y < 70.0):
			continue
		var tw := 0.6 + 0.4 * sin(_t * 2.0 + k)
		draw_rect(Rect2(p, Vector2(3, 3)), Color(1.0, 0.96, 0.78, tw))
	var moon := Vector2(size.x - 210.0, 98.0)
	draw_circle(moon, 36.0, Color(0.95, 0.9, 0.78, 0.08))
	draw_circle(moon, 28.0, Color("f3e6c8"))
	draw_circle(moon + Vector2(8, 5), 22.0, Color("d8c8a0"))
	draw_circle(moon - Vector2(3, 3), 22.0, Color("f3e6c8"))
	var tree_pts := PackedVector2Array([Vector2(0, horizon)])   # the treeline
	for k in 33:
		tree_pts.append(Vector2(size.x * k / 32.0, horizon - (70.0 if k % 2 == 0 else 26.0) - float(k * 37 % 30)))
	tree_pts.append(Vector2(size.x, horizon))
	draw_colored_polygon(tree_pts, Color("0d1a12"))
	draw_rect(Rect2(0, horizon, size.x, size.y - horizon), Color("16220f"))
	for k in 6:   # grass in darker strips toward the bottom
		draw_rect(Rect2(0, horizon + k * 52.0, size.x, 52.0), Color(0, 0, 0, 0.05 * k))
	var fire := Vector2(FIRE_X, FIRE_Y)
	var flick := 0.85 + 0.15 * sin(_t * 9.0) * sin(_t * 5.3)
	for k in 5:   # warm light on the ground
		_ellipse(fire + Vector2(0, 8), Vector2(380.0 - k * 64.0, 130.0 - k * 22.0), Color(1.0, 0.6, 0.16, 0.03 * flick))
	if _hero != null:
		_hero.draw(self, "idle", _t, fire + Vector2(-110, 30), FrontArt.scale_of(_hero, HERO_SCALE))
	draw_rect(Rect2(fire + Vector2(-34, 18), Vector2(68, 12)), Color("5a3618"))   # logs
	draw_rect(Rect2(fire + Vector2(-28, 24), Vector2(56, 10)), Color("6a4020"))
	var h := 40.0 * flick
	draw_rect(Rect2(fire + Vector2(-18, 18 - h * 0.75), Vector2(36, h * 0.75)), Color("d9361e"))
	draw_rect(Rect2(fire + Vector2(-11, 18 - h), Vector2(22, h)), Color("ff9a2a"))
	draw_rect(Rect2(fire + Vector2(-5, 18 - h * 0.55), Vector2(10, h * 0.55)), Color("fff2a0"))
	for k in 4:   # sparks rising
		var sp := fmod(_t * 0.7 + k * 0.25, 1.0)
		draw_rect(Rect2(fire + Vector2(sin(k * 2.3 + _t) * 14.0, -h - sp * 90.0), Vector2(3, 3)), Color(1.0, 0.8, 0.3, 1.0 - sp))


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 40:
		var ang := k * TAU / 40.0
		pts.append(c + Vector2(cos(ang) * r.x, sin(ang) * r.y))
	draw_colored_polygon(pts, col)


const FIRE_X := 640.0
const FIRE_Y := 470.0
const WOOD := Color("2a1e14")
const WOOD_EDGE := Color("5a3e24")
const EMBER := Color("ffd36b")

var _sign_name: Label
var _sign_desc: Label


## The camp props: [icon, name, what it does, position, feature lock ("" = open), action].
func _props(root: Control, menu: Control) -> Array:
	return [
		["nav_settings", "Cài đặt", "Âm thanh, hiển thị, phím.", Vector2(40, 400), "", func() -> void: _show_settings(root, menu)],
		["nav_equipment", "Trang bị", "Thay mũ, áo, giày, vũ khí; cường hoá đồ bằng vàng.", Vector2(140, 250), "",
			func() -> void: get_tree().change_scene_to_file(EQUIPMENT_SCENE)],
		["nav_tree", "Cây kỹ năng", "Điểm kỹ năng mở chỉ số lâu dài cho nhân vật này.", Vector2(300, 170), "tree",
			func() -> void: get_tree().change_scene_to_file(TREE_SCENE)],
		["nav_album", "Album", "Bách khoa: quái, boss và kỹ năng; quái mở khi hạ lần đầu.", Vector2(470, 120), "",
			func() -> void: get_tree().change_scene_to_file("res://src/front/album.tscn")],
		["nav_stages", "Lên đường", "Chọn ải rồi vào trận.", Vector2(680, 300), "",
			func() -> void: get_tree().change_scene_to_file(STAGE_SCENE)],
		["nav_deck", "Bộ thẻ", "Chọn thẻ mang vào trận: 8 chiêu, 6 chỉ số.", Vector2(830, 170), "deck",
			func() -> void: get_tree().change_scene_to_file(DECK_SCENE)],
		["nav_gacha", "Quay đồ", "Dùng đá quay trang bị hiếm.", Vector2(990, 250), "gacha",
			func() -> void: get_tree().change_scene_to_file("res://src/front/gacha.tscn")],
		["nav_missions", _missions_label(), "Nhiệm vụ hằng ngày và phần thưởng chờ nhận.", Vector2(1110, 400), "",
			func() -> void: get_tree().change_scene_to_file("res://src/front/missions.tscn")],
		["nav_title", "Về tiêu đề", "Về màn hình tiêu đề.", Vector2(1110, 560), "",
			func() -> void: get_tree().change_scene_to_file(TITLE_SCENE)],
	]


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

	# top left: who is at the camp (no panel: the night is the frame)
	var slot_now: Slot = Prefs.current().active_slot if _slot_mode else null
	var cname := _label(slot_now.name if slot_now != null else String(_class.get("name", "")), 44, TEXT)
	cname.position = Vector2(28, 16)
	menu.add_child(cname)
	var role := _label("%s · %s" % [String(_class.get("name", "")), ("Ải %d" % slot_now.best) if slot_now != null else String(_class.get("role", ""))], 22, accent.lightened(0.35))
	role.position = Vector2(30, 70)
	menu.add_child(role)
	var base: Dictionary = _class.get("stats", {})
	var stats := PlayerStats.compute(base, [], {})
	if slot_now != null:   # equipment + skill tree of the character
		var lasting := SkillTree.lasting(slot_now)
		stats = PlayerStats.compute(base, lasting[0], lasting[1])
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 16)
	srow.position = Vector2(30, 104)
	menu.add_child(srow)
	for it in [["heart", "%d" % roundi(float(stats.get("max_hp", 0))), "Máu tối đa"], ["sword", "%d" % roundi(float(stats.get("damage", 0))), "Sát thương"],
			["boot", "%d" % roundi(float(stats.get("move_speed", 0))), "Tốc độ chạy"]]:
		srow.add_child(_small_stat(it[0], it[1], it[2]))
	if slot_now != null:   # top right: the purse
		var purse := HBoxContainer.new()
		purse.add_theme_constant_override("separation", 20)
		menu.add_child(purse)
		for it in [["coin", str(slot_now.gold), "Vàng"], ["gem", str(slot_now.gems), "Đá (quay đồ)"]]:
			purse.add_child(_small_stat(it[0], it[1], it[2]))
		purse.position = Vector2(vp.x - 28 - purse.get_combined_minimum_size().x - 20, 22)

	# the props round the fire; ←/→ (and ↑/↓) walk them in a ring, the sign below explains the one in focus
	var props := _props(root, menu)
	var buttons: Array[Button] = []
	for pr: Array in props:
		var b := _prop(pr, pr[1] == "Lên đường")
		menu.add_child(b)
		buttons.append(b)
	for k in buttons.size():
		var nxt := buttons[(k + 1) % buttons.size()].get_path()
		var prv := buttons[(k + buttons.size() - 1) % buttons.size()].get_path()
		buttons[k].focus_neighbor_right = nxt
		buttons[k].focus_neighbor_left = prv
		buttons[k].focus_neighbor_bottom = nxt
		buttons[k].focus_neighbor_top = prv
	var sign := PanelContainer.new()
	sign.add_theme_stylebox_override("panel", _wood(Color("3a2818"), Color("6a4a2c"), 18))
	sign.position = Vector2(vp.x * 0.5 - 300, vp.y - 128)
	sign.custom_minimum_size = Vector2(600, 96)
	menu.add_child(sign)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 2)
	sign.add_child(sv)
	_sign_name = _label("", 30, EMBER)
	sv.add_child(_sign_name)
	_sign_desc = _label("", 18, Color("e0d0a8"))
	_sign_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sv.add_child(_sign_desc)
	var keys := _label("← → chọn · Enter", 16, Color("a89070"))
	keys.position = Vector2(sign.position.x + 600 - 170, sign.position.y + 12)
	menu.add_child(keys)
	buttons[4].call_deferred("grab_focus")   # Lên đường

	if OS.get_cmdline_user_args().has("--lobby-settings"):   # shots of the settings page
		_show_settings.call_deferred(root, menu)

	var hint := _label("Esc: đổi nhân vật", 16, Color("8a8070"))   # in-run keys are shown when a run starts
	hint.position = Vector2(28, vp.y - 30)
	menu.add_child(hint)


## One camp prop: a wooden frame with the icon, a post under it and its name; focus lifts it and lights it.
func _prop(pr: Array, main: bool) -> Button:
	var b := Button.new()
	b.position = pr[3]
	b.custom_minimum_size = Vector2(130, 150)
	b.focus_mode = Control.FOCUS_ALL
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, empty)
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.position = Vector2(17, 0)
	frame.custom_minimum_size = Vector2(96, 96)
	var normal := _wood(Color("5a1a14") if main else WOOD, Color("c0402e") if main else WOOD_EDGE, 12)
	var lit := _wood(Color("7a2418") if main else Color("3a2a1a"), EMBER, 12)
	lit.shadow_color = Color(1.0, 0.6, 0.16, 0.55)
	lit.shadow_size = 14
	frame.add_theme_stylebox_override("panel", normal)
	b.add_child(frame)
	var ic := TextureRect.new()
	ic.texture = UiKit.vector_texture("res://assets/icons/lobby/%s.svg" % String(pr[0]), 64)
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ic.custom_minimum_size = Vector2(64, 64)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(ic)
	var post := ColorRect.new()
	post.color = Color("4a3220")
	post.position = Vector2(59, 96)
	post.size = Vector2(12, 26)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(post)
	var nm := _label(String(pr[1]), 18, Color("c8b48a"))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.position = Vector2(-20, 122)
	nm.size = Vector2(170, 26)
	b.add_child(nm)
	b.pressed.connect(pr[5])
	b.focus_entered.connect(func() -> void:
		frame.add_theme_stylebox_override("panel", lit)
		frame.position.y = -8
		nm.add_theme_color_override("font_color", Color("fff2a0"))
		_sign_name.text = String(pr[1])
		_sign_desc.text = String(pr[2]) if _open(String(pr[4])) else _lock_text(String(pr[4])))
	b.focus_exited.connect(func() -> void:
		frame.add_theme_stylebox_override("panel", normal)
		frame.position.y = 0
		nm.add_theme_color_override("font_color", Color("c8b48a")))
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	_lock(b, String(pr[4]), Vector2(100, -8))
	return b


## A wooden board: dark plank, a thick edge and an inner bevel line.
func _wood(bg: Color, edge: Color, pad: int) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = edge
	st.set_border_width_all(4)
	st.set_content_margin_all(pad)
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_offset = Vector2(0, 6)
	st.shadow_size = 0
	return st


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




var _unlocks: Unlocks


## True when the active slot has opened lobby screen [param feature] ("" = always open).
func _open(feature: String) -> bool:
	if feature == "":
		return true
	if _unlocks == null:
		_unlocks = Unlocks.load_default()
	return _unlocks.is_open(Prefs.current().active_slot, feature)


func _lock_text(feature: String) -> String:
	return "Mở khi qua ải %d." % _unlocks.need(feature)


## A locked screen (design/ux/progressive-unlocks.md): the button is greyed and disabled, with a small
## "ải N" tag at [param tag_at] saying when it opens.
func _lock(b: Button, feature: String, tag_at: Vector2) -> void:
	if _open(feature):
		return
	b.disabled = true
	b.focus_mode = Control.FOCUS_NONE
	var dim := (b.get_theme_stylebox("normal") as StyleBoxFlat).duplicate() as StyleBoxFlat
	dim.border_color = Color("4a4458")   # keeps its frame, greyed (a bare disabled button lost the frame)
	b.add_theme_stylebox_override("disabled", dim)
	b.self_modulate = Color(1, 1, 1, 0.6)
	var tag := UiKit.label("ải %d" % _unlocks.need(feature), 13, UiKit.TEXT)
	var ts := UiKit.style(Color("3a3448"), 0, UiKit.GOLD, 2)
	ts.set_corner_radius_all(4)
	ts.content_margin_left = 4
	ts.content_margin_right = 4
	tag.add_theme_stylebox_override("normal", ts)
	tag.position = tag_at
	b.add_child(tag)


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


## "Nhiệm vụ", with how many rewards wait to be claimed (design/missions.md).
func _missions_label() -> String:
	var slot := Prefs.current().active_slot
	if slot == null:
		return "Nhiệm vụ"
	var d := Daily.load_default()
	d.ensure(slot, "2026-11-18" if Prefs.current().is_fixed() else "")
	var n := d.ready_count(slot)
	return "Nhiệm vụ (%d)" % n if n > 0 else "Nhiệm vụ"
