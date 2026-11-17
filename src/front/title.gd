extends Node2D
## The title screen, the game's first scene (design/ux/front-end.md, after Vampire
## Survivors' main menu and common menu guidance): the logo, the two heroes on their
## pedestals either side, and one column of buttons. The first is the main action:
## "Tiếp tục" (the character played last, with its class and stage) or "Chơi" when
## there is no character yet; then "Chọn nhân vật", "Cài đặt", "Thoát".
##
## Command line (after `--`), for shots: --force-slots (a preview character),
## --title-settings (open the settings).

const CHARACTERS_SCENE := "res://src/front/characters.tscn"
const LOBBY_SCENE := "res://src/lobby/lobby.tscn"
const MENU_W := 440.0
const HERO_SCALE := 6.0

var _heroes: Array = []   # [[SpriteSheet, accent Color]]
var _t := 0.0
var _scroll := Vector2.ZERO
var _layer: CanvasLayer
var _menu: Control


func _ready() -> void:
	var classes := GameData.load_json("res://assets/data/classes.json")
	for id: String in classes:
		if not id.begins_with("_"):
			_heroes.append([FrontArt.hero_sheet(classes[id]), Color(String(classes[id].get("color", "c9a65a")))])
	var prefs := Prefs.current()
	if not prefs.is_fixed():
		prefs.ensure_slots()
	_build()
	if OS.get_cmdline_user_args().has("--title-settings"):
		_show_settings.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	_scroll += Vector2(18.0, 6.0) * delta
	queue_redraw()


func _draw() -> void:
	var size := get_viewport_rect().size
	FrontArt.backdrop(self, _scroll, size)
	# the heroes stand either side of the menu, turned towards it
	var spots := [Vector2(230, 560), Vector2(size.x - 230, 560)]
	for i in mini(_heroes.size(), spots.size()):
		var sheet: SpriteSheet = _heroes[i][0]
		FrontArt.pedestal(self, spots[i], _heroes[i][1], _t + i * 1.7, 0.9)
		if sheet != null:
			sheet.draw(self, "idle", _t + i * 0.4, spots[i], HERO_SCALE, i == 1)


func _build() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	var root := Control.new()
	root.size = get_viewport_rect().size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	_menu = Control.new()
	_menu.size = root.size
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_menu)
	var logo := UiKit.label("BÁCH ẢI", 88, UiKit.GOLD)
	logo.add_theme_constant_override("shadow_offset_x", 4)
	logo.add_theme_constant_override("shadow_offset_y", 4)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.position = Vector2(0, 54)
	logo.size = Vector2(root.size.x, 110)
	_menu.add_child(logo)
	var sub := UiKit.label("Vượt trăm ải", 24, UiKit.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 168)
	sub.size = Vector2(root.size.x, 34)
	_menu.add_child(sub)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.position = Vector2((root.size.x - MENU_W) * 0.5, 262)
	col.custom_minimum_size = Vector2(MENU_W, 0)
	_menu.add_child(col)
	var slot := Prefs.current().active_slot
	var main: Button
	if slot != null:
		var prog := "đã vượt ải %d" % slot.best if slot.best > 0 else "chưa vượt ải nào"
		main = _primary("Tiếp tục", "%s  ·  %s  ·  %s" % [slot.name, _class_name(slot.cls), prog],
			func() -> void: get_tree().change_scene_to_file(LOBBY_SCENE))
	else:
		main = _primary("Chơi", "Tạo nhân vật đầu tiên", func() -> void: get_tree().change_scene_to_file(CHARACTERS_SCENE))
	col.add_child(main)
	col.add_child(UiKit.button("Chọn nhân vật", func() -> void: get_tree().change_scene_to_file(CHARACTERS_SCENE), Vector2(MENU_W, 54), 21))
	col.add_child(UiKit.button("Cài đặt", func() -> void: _show_settings(), Vector2(MENU_W, 54), 21))
	col.add_child(UiKit.button("Thoát", func() -> void: get_tree().quit(), Vector2(MENU_W, 54), 21))
	main.call_deferred("grab_focus")

	var version := UiKit.label("Phiên bản " + String(ProjectSettings.get_setting("application/config/version", "")), 14, UiKit.MUTED)
	version.position = Vector2(24, root.size.y - 34)
	_menu.add_child(version)
	var hint := UiKit.label("↑ ↓ chọn  ·  Enter xác nhận", 14, UiKit.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.position = Vector2(root.size.x - 424, root.size.y - 34)
	hint.size = Vector2(400, 22)
	_menu.add_child(hint)


func _class_name(cls: String) -> String:
	return String(GameData.load_json("res://assets/data/classes.json").get(cls, {}).get("name", cls))


## The main action: a big button with its title and a line under it.
func _primary(title: String, line: String, cb: Callable) -> Button:
	var b := UiKit.button("", cb, Vector2(MENU_W, 84), 28, UiKit.PRIMARY)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER   # a button's label is centred; its two lines are too
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var t := UiKit.label(title, 30, Color.WHITE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var l := UiKit.label(line, 15, Color("f2d8c8"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(l)
	return b


func _show_settings() -> void:
	_menu.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.get_child(0).add_child(center)
	UiKit.dim(center)
	var card := UiKit.panel(Color(0.09, 0.08, 0.13, 0.97), 24)
	center.add_child(card)
	card.add_child(SettingsPanel.build(func() -> void:
		center.queue_free()
		_menu.visible = true))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _menu.visible:
		for c in _layer.get_child(0).get_children():
			if c is CenterContainer:
				c.queue_free()
		_menu.visible = true
