extends Node2D
## The lobby (waiting screen) before a run: title, the hero idling on the
## stage's grass, the chosen class with its base stats (icons), the stage, and
## Start / Quit. Start (Enter, or A on a pad) loads the run scene.

const DATA := "res://assets/data/"
const SPRITES := "res://assets/sprites/custom/"
const RUN_SCENE := "res://src/run/run.tscn"
const CLASS_ID := "knight"
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


func _ready() -> void:
	_class = GameData.load_json(DATA + "classes.json").get(CLASS_ID, {})
	_stage = GameData.load_json(DATA + STAGE_FILE)
	var sprite := String(_class.get("sprite", "swordsman"))
	_hero = SpriteSheet.load_dir(SPRITES + sprite, sprite)
	if _hero != null and not _hero.layer_names().is_empty():
		_hero.compose_layers()   # equipment will pass its layers here
	_build_ui()


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
	cv.add_child(_label(String(_class.get("name", CLASS_ID)), 30, TEXT))
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
	col.add_child(_button("Thoát", func() -> void: get_tree().quit()))
	start.call_deferred("grab_focus")

	var hint := _label("Enter: bắt đầu  ·  WASD / mũi tên: di chuyển  ·  Esc: tạm dừng", 16, MUTED)
	hint.position = Vector2(0, vp.y - 40)
	hint.size = Vector2(vp.x, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)


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
