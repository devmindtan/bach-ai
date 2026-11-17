extends Node2D
## The lobby (waiting screen) before a run: title, the hero idling on the
## stage's grass, the chosen class with its base stats (icons), the stage, and
## Start / Quit. Start (Enter, or A on a pad) loads the run scene. The class
## switches with the ‹ › buttons or Left / Right; the choice is saved (Prefs.hero).

const DATA := "res://assets/data/"
const SPRITES := "res://assets/sprites/custom/"
const RUN_SCENE := "res://src/run/run.tscn"
const STAGE_FILE := "waves/stage_001.json"
const HERO_SCALE := 5.0

const GOLD := Color("c9a65a")
const TEXT := Color("f2ecd8")
const MUTED := Color("b9b2a0")
const PANEL := Color("2a2438")
const PANEL_HOVER := Color("3b3352")
const SHADOW := Color(0, 0, 0, 0.7)

var _hero: SpriteSheet
var _class: Dictionary
var _stage: Dictionary
var _t := 0.0
var _scroll := Vector2.ZERO
var _layer: CanvasLayer
var _classes := {}
var _class_ids: Array[String] = []


func _ready() -> void:
	_classes = GameData.load_json(DATA + "classes.json")
	for id: String in _classes:
		if not id.begins_with("_"):
			_class_ids.append(id)
	_stage = GameData.load_json(DATA + STAGE_FILE)
	_load_class(Prefs.current().hero)
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
func switch_class(step: int) -> void:
	var i := _class_ids.find(Prefs.current().hero)
	var id := _class_ids[posmod(i + step, _class_ids.size())]
	Prefs.current().set_value("hero", id)
	_load_class(id)
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
	RunGround.draw(self, view.grow(64.0), 1.0e9)
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.05, 0.45))
	# hero on a soft shadow, left of centre
	var feet := Vector2(size.x * 0.32, size.y * 0.66)
	draw_set_transform(feet, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 70.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	if _hero != null:
		_hero.draw(self, "idle", _t, feet, HERO_SCALE)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_layer = layer
	var root := Control.new()
	root.size = get_viewport_rect().size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var vp := get_viewport_rect().size

	var title := _label("BÁCH ẢI", 72, GOLD)
	title.position = Vector2(0, 40)
	title.size = Vector2(vp.x, 90)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var sub := _label("Vượt trăm ải bằng một thanh kiếm", 20, MUTED)
	sub.position = Vector2(0, 122)
	sub.size = Vector2(vp.x, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub)

	# right column: class card, stage card, buttons
	var col := VBoxContainer.new()
	col.position = Vector2(vp.x * 0.56, vp.y * 0.30)
	col.custom_minimum_size = Vector2(380, 0)
	col.add_theme_constant_override("separation", 14)
	root.add_child(col)

	var card := _card()
	col.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	card.add_child(cv)
	# class name between ‹ › (Left / Right also switch)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	cv.add_child(head)
	var prev := _arrow("‹", func() -> void: switch_class(-1))
	head.add_child(prev)
	var cname := _label(String(_class.get("name", "")), 30, TEXT)
	cname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(cname)
	head.add_child(_arrow("›", func() -> void: switch_class(1)))
	var stats: Dictionary = _class.get("stats", {})
	cv.add_child(_stat("heart", "Máu", "%d" % roundi(float(stats.get("max_hp", 0)))))
	cv.add_child(_stat("sword", "Sát thương", "%d" % roundi(float(stats.get("damage", 0)))))
	cv.add_child(_stat("boot", "Tốc độ", "%d" % roundi(float(stats.get("move_speed", 0)))))

	var stage_card := _card()
	col.add_child(stage_card)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	stage_card.add_child(sv)
	sv.add_child(_label("Ải %d · %s" % [int(_stage.get("number", 1)), String(_stage.get("name", ""))], 26, GOLD))
	var dur := int(_stage.get("duration", 0))
	sv.add_child(_stat("clock", "Trụ vững", "%02d:%02d" % [dur / 60, dur % 60]))

	var start := _button("Bắt đầu", func() -> void: get_tree().change_scene_to_file(RUN_SCENE))
	col.add_child(start)
	# settings and quit share one row so the column stays short
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	for b in [_button("Cài đặt", func() -> void: _show_settings(root, col)),
			_button("Thoát", func() -> void: get_tree().quit())]:
		b.custom_minimum_size.x = 0
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	if OS.get_cmdline_user_args().has("--lobby-settings"):   # shots of the settings page
		_show_settings.call_deferred(root, col)
	start.call_deferred("grab_focus")
	_keep_above.call_deferred(col, vp.y - HINT_SPACE)

	var hint := _label("Enter: bắt đầu  ·  ← / →: đổi class  ·  Trong trận: WASD di chuyển, Space lướt, Tab nhân vật, Esc tạm dừng", 16, MUTED)
	hint.position = Vector2(0, vp.y - 40)
	hint.size = Vector2(vp.x, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)


const HINT_SPACE := 56.0   # the key hint line at the bottom of the screen


## Once laid out, lift the column so its bottom stays above `bottom`
## (a button added to it once ran off the screen, over the key hint).
func _keep_above(col: Control, bottom: float) -> void:
	col.position.y = minf(col.position.y, bottom - col.get_combined_minimum_size().y)


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
