extends Node2D
## The title screen, the game's first scene. Hướng C "Hoàng hôn trước trận" (design-web/games/bach-ai/specs/title.md,
## user 2026-11-26 chose it and approved the web set): a dusk sky, ridges of pass gates fading toward the horizon, one
## great gate on the near hill against the sun; the name over a soft dark wash; a horizontal text menu. The first item
## is the main action: "Tiếp tục" (the character played last) or "Chơi" when there is none; then "Chọn nhân vật",
## "Cài đặt", "Thoát".
##
## Command line (after `--`), for shots: --force-slots (a preview character), --title-settings (open the settings).

const CHARACTERS_SCENE := "res://src/front/characters.tscn"
const LOBBY_SCENE := "res://src/lobby/lobby.tscn"
const SKY := ["1a1030", "2e1640", "4a1c48", "7a2a44", "b0443a", "e0703a", "f2a04a"]
const RIDGES := ["8a3a48", "62283e", "421c32", "2a1224"]
const NIGHT := Color("140a14")

var _t := 0.0
var _layer: CanvasLayer
var _menu: Control


func _ready() -> void:
	Sfx.music("menu")
	var prefs := Prefs.current()
	if not prefs.is_fixed():
		prefs.ensure_slots()
	_build()
	if OS.get_cmdline_user_args().has("--title-settings"):
		_show_settings.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _ridge(row: int, x: float) -> float:
	return 330.0 + row * 46.0 + sin(x / (140.0 - row * 20.0) + row) * (14.0 + row * 6.0)


func _draw() -> void:
	var size := get_viewport_rect().size
	for i in SKY.size():   # the sky in bands
		draw_rect(Rect2(0, i * 52.0, size.x, 52.0), Color(SKY[i]))
	draw_rect(Rect2(0, SKY.size() * 52.0, size.x, size.y), Color(SKY[-1]))
	draw_circle(Vector2(1040, 330), 74.0, Color("ffd890"))
	draw_circle(Vector2(1040, 330), 56.0, Color("fff0c0"))
	for row in RIDGES.size():   # far to near: the gates first, legs sunk deep, then the ridge over their feet
		var col := Color(RIDGES[row])
		for k in 9 - row:
			var gx := 120.0 + k * (150.0 + row * 40.0) + row * 37.0
			var gh := 16.0 + row * 10.0
			var gw := 10.0 + row * 5.0
			var gy := minf(_ridge(row, gx), _ridge(row, gx + gw * 3.0))
			draw_rect(Rect2(gx, gy - gh, gw, gh + 40.0), col)
			draw_rect(Rect2(gx + gw * 2.0, gy - gh, gw, gh + 40.0), col)
			draw_rect(Rect2(gx - 2.0, gy - gh - 5.0, gw * 3.0 + 4.0, 6.0), col)
		var pts := PackedVector2Array()
		var x := 0.0
		while x <= size.x:
			pts.append(Vector2(x, _ridge(row, x)))
			x += 8.0
		pts.append(Vector2(size.x, size.y))
		pts.append(Vector2(0, size.y))
		draw_colored_polygon(pts, col)
	# the great gate on the near hill: two pillars, a beam, a roof with upturned eaves, a red plaque
	var x0 := 930.0
	var x1 := 1150.0
	var top := 380.0
	draw_rect(Rect2(x0, top + 40, 34, 280), NIGHT)
	draw_rect(Rect2(x1 - 34, top + 40, 34, 280), NIGHT)
	draw_rect(Rect2(x0 - 40, top + 22, x1 - x0 + 80, 18), NIGHT)
	draw_rect(Rect2(x0 - 10, top + 52, x1 - x0 + 20, 12), NIGHT)
	draw_colored_polygon(PackedVector2Array([Vector2(x0 - 70, top + 6), Vector2(x0 - 40, top + 22), Vector2(x1 + 40, top + 22),
		Vector2(x1 + 70, top + 6), Vector2(x1 + 10, top - 12), Vector2(x0 - 10, top - 12)]), NIGHT)
	draw_rect(Rect2(x0 + 70, top - 34, x1 - x0 - 140, 24), NIGHT)
	draw_rect(Rect2((x0 + x1) * 0.5 - 22, top + 70, 44, 26), Color("c0283a"))
	var hill := PackedVector2Array()
	for k in 33:   # the near hill (a quadratic curve)
		var u := k / 32.0
		var p := Vector2(560, 720).lerp(Vector2(900, 560), u).lerp(Vector2(900, 560).lerp(Vector2(1280, 590), u), u)
		hill.append(p)
	hill.append(Vector2(1280, 720))
	draw_colored_polygon(hill, NIGHT)
	for k in 30:   # an oval wash behind the name and the menu, fading out smoothly
		var f := 1.0 - k / 30.0
		_ellipse(Vector2(300, 430), Vector2(500, 300) * f, Color(NIGHT, 0.032))


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 48:
		var ang := k * TAU / 48.0
		pts.append(c + Vector2(cos(ang) * r.x, sin(ang) * r.y))
	draw_colored_polygon(pts, col)


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
	var logo := UiKit.label("BÁCH ẢI", 104, Color("fff0d0"))   # the game's UI font: whole strokes, marks in place
	logo.add_theme_color_override("font_shadow_color", Color("6a1a14"))
	logo.add_theme_constant_override("shadow_offset_x", 0)
	logo.add_theme_constant_override("shadow_offset_y", 5)
	logo.add_theme_constant_override("outline_size", 0)
	logo.position = Vector2(60, 260)
	_menu.add_child(logo)
	var sub := UiKit.label("V Ư Ợ T   T R Ă M   Ả I", 24, Color("ffb070"))
	sub.position = Vector2(68, 400)
	_menu.add_child(sub)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	row.position = Vector2(72, 500)
	_menu.add_child(row)
	var slot := Prefs.current().active_slot
	var items: Array = []
	if slot != null:
		items.append(["Tiếp tục", "Ải %d · %s" % [slot.best, _class_name(slot.cls)], func() -> void: get_tree().change_scene_to_file(LOBBY_SCENE)])
	else:
		items.append(["Chơi", "Tạo nhân vật đầu tiên", func() -> void: get_tree().change_scene_to_file(CHARACTERS_SCENE)])
	items.append(["Chọn nhân vật", "", func() -> void: get_tree().change_scene_to_file(CHARACTERS_SCENE)])
	items.append(["Cài đặt", "", func() -> void: _show_settings()])
	items.append(["Thoát", "", func() -> void: get_tree().quit()])
	var buttons: Array[Button] = []
	for it: Array in items:
		var b := _item(String(it[0]), String(it[1]), it[2])
		row.add_child(b)
		buttons.append(b)
	for k in buttons.size():   # ←/→ walk the menu in a ring
		buttons[k].focus_neighbor_right = buttons[(k + 1) % buttons.size()].get_path()
		buttons[k].focus_neighbor_left = buttons[(k + buttons.size() - 1) % buttons.size()].get_path()
	buttons[0].call_deferred("grab_focus")

	var version := UiKit.label("Phiên bản " + String(ProjectSettings.get_setting("application/config/version", "")), 15, Color("a07868"))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.position = Vector2(root.size.x - 330, root.size.y - 34)
	version.size = Vector2(300, 22)
	_menu.add_child(version)
	var hint := UiKit.label("← → chọn  ·  Enter xác nhận", 15, Color("a07868"))
	hint.position = Vector2(72, root.size.y - 34)
	_menu.add_child(hint)


## A menu word (a flat text button: Godot sizes it from its text), muted; white with an ember underline when focused; a
## small second line under the main action.
func _item(title: String, line: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = title
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 30)
	var plain := StyleBoxEmpty.new()
	var on := StyleBoxFlat.new()
	on.bg_color = Color(0, 0, 0, 0)
	on.border_color = Color("ff7a3a")
	on.border_width_bottom = 4
	for st in ["normal", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, plain)
	b.add_theme_stylebox_override("focus", on)
	b.add_theme_stylebox_override("hover", on)
	b.add_theme_color_override("font_color", Color("c8a890"))
	for k in ["font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, Color("fff6e0"))
	b.pressed.connect(cb)
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	if line != "":
		var l := UiKit.label(line, 15, Color("e0b890"))
		l.position = Vector2(2, 50)
		b.add_child(l)
	return b


func _class_name(cls: String) -> String:
	return String(GameData.load_json("res://assets/data/classes.json").get(cls, {}).get("name", cls))



func _show_settings() -> void:
	_menu.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.get_child(0).add_child(center)
	UiKit.dim(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Journal.sheet_style())   # a loose sheet, like the journal's settings
	center.add_child(card)
	card.add_child(SettingsPanel.build(func() -> void:
		center.queue_free()
		_menu.visible = true))
	Journal.restyle(card.get_child(0))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _menu.visible:
		for c in _layer.get_child(0).get_children():
			if c is CenterContainer:
				c.queue_free()
		_menu.visible = true
