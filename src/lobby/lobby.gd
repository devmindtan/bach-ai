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


## Hướng B "Sổ hành trình" (design-web/games/bach-ai/specs/lobby.md, user 2026-11-26 chose it in the Design Lab): a
## travel journal open on a wooden desk; the left page is the character, the right page the contents.
const BOOK := Rect2(70, 40, 1100, 640)
const INK := Color("3a2414")
const INK_RED := Color("8a2a1a")
const PAPER := Color("e8d8b0")
const PAPER_DARK := Color("c8b088")
const EDGE := Color("8a6a3a")
const PORTRAIT := Rect2(130, 170, 220, 220)


func _draw() -> void:
	var size := get_viewport_rect().size
	for k in int(size.y / 6.0) + 1:   # the desk: planks in two browns
		draw_rect(Rect2(0, k * 6.0, size.x, 6.0), Color("3a2414") if k % 2 == 0 else Color("42291a"))
	draw_rect(BOOK.grow(14).grow_individual(0, 0, 0, 0), Color("2a0c08"))   # cover edge
	draw_rect(BOOK.grow(10), Color("5a1a14"))                                  # leather cover
	draw_rect(Rect2(BOOK.position + Vector2(0, BOOK.size.y + 10), Vector2(BOOK.size.x, 10)), Color(0, 0, 0, 0.45))   # shadow
	for k in 3:   # bookmark ribbons out of the right edge
		draw_rect(Rect2(BOOK.end.x + 4, BOOK.position.y + 60 + k * 50, 44, 36), [Color("3a6a8a"), Color("6a8a3a"), Color("8a3a6a")][k])
		draw_rect(Rect2(BOOK.end.x + 4, BOOK.position.y + 60 + k * 50, 44, 36), Color(0, 0, 0, 0.4), false, 3.0)
	var half := BOOK.size.x * 0.5
	for side in 2:   # the two pages: paper, a shaded gutter, a dashed inner frame
		var pg := Rect2(BOOK.position + Vector2(half * side, 0), Vector2(half, BOOK.size.y))
		draw_rect(pg, PAPER)
		draw_rect(pg, EDGE, false, 4.0)
		var gx := pg.end.x - 12.0 if side == 0 else pg.position.x
		draw_rect(Rect2(gx, pg.position.y + 4, 12, pg.size.y - 8), PAPER_DARK)
		var inner := pg.grow(-12)
		var y := inner.position.y
		while y < inner.end.y:   # dashed frame, left and right
			draw_rect(Rect2(inner.position.x, y, 2, 6), Color("b89a6a"))
			draw_rect(Rect2(inner.end.x - 2, y, 2, 6), Color("b89a6a"))
			y += 12.0
		var x := inner.position.x
		while x < inner.end.x:   # top and bottom
			draw_rect(Rect2(x, inner.position.y, 6, 2), Color("b89a6a"))
			draw_rect(Rect2(x, inner.end.y - 2, 6, 2), Color("b89a6a"))
			x += 12.0
	draw_rect(PORTRAIT, Color("d8c498"))   # the portrait, drawn in ink
	draw_rect(PORTRAIT, EDGE, false, 4.0)
	if _hero != null:
		_hero.draw(self, "idle", _t, PORTRAIT.position + Vector2(PORTRAIT.size.x * 0.5, PORTRAIT.size.y - 26), FrontArt.scale_of(_hero, 4.0))


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 40:
		var ang := k * TAU / 40.0
		pts.append(c + Vector2(cos(ang) * r.x, sin(ang) * r.y))
	draw_colored_polygon(pts, col)


var _desc: Label


## The contents: [icon, name, page, what it does, feature lock ("" = open), action].
func _chapters(root: Control, menu: Control) -> Array:
	return [
		["nav_equipment", "Trang bị", "I", "Mũ, áo, giày, vũ khí của nhân vật; cường hoá bằng vàng.", "",
			func() -> void: get_tree().change_scene_to_file(EQUIPMENT_SCENE)],
		["nav_tree", "Cây kỹ năng", "II", "Điểm kỹ năng mở chỉ số lâu dài.", "tree", func() -> void: get_tree().change_scene_to_file(TREE_SCENE)],
		["nav_deck", "Bộ thẻ", "III", "Chọn thẻ mang vào trận.", "deck", func() -> void: get_tree().change_scene_to_file(DECK_SCENE)],
		["nav_gacha", "Quay đồ", "IV", "Dùng đá quay trang bị hiếm.", "gacha",
			func() -> void: get_tree().change_scene_to_file("res://src/front/gacha.tscn")],
		["nav_missions", _missions_label(), "V", "Việc trong ngày và phần thưởng chờ nhận.", "",
			func() -> void: get_tree().change_scene_to_file("res://src/front/missions.tscn")],
		["nav_album", "Album", "VI", "Bách khoa: quái, boss và kỹ năng.", "",
			func() -> void: get_tree().change_scene_to_file("res://src/front/album.tscn")],
		["nav_settings", "Cài đặt", "VII", "Âm thanh, hiển thị, phím.", "", func() -> void: _show_settings(root, menu)],
		["nav_character", "Đổi nhân vật", "VIII", "Chọn hoặc tạo nhân vật khác (Esc).", "",
			func() -> void: get_tree().change_scene_to_file(CHARACTERS_SCENE)],
		["nav_title", "Về tiêu đề", "IX", "Về màn hình tiêu đề.", "", func() -> void: get_tree().change_scene_to_file(TITLE_SCENE)],
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
	var lx := BOOK.position.x + 40.0
	var rx := BOOK.position.x + BOOK.size.x * 0.5 + 36.0

	# left page: who is travelling
	var slot_now: Slot = Prefs.current().active_slot if _slot_mode else null
	var cname := _ink(slot_now.name if slot_now != null else String(_class.get("name", "")), 48, INK)
	cname.position = Vector2(lx, BOOK.position.y + 22)
	menu.add_child(cname)
	var sub := "%s · %s" % [String(_class.get("name", "")), String(_class.get("role", "")).to_lower()]
	if slot_now != null:
		sub += " · đã qua Ải %d" % slot_now.best
	var subl := _ink(sub, 20, INK_RED)
	subl.position = Vector2(lx, BOOK.position.y + 82)
	menu.add_child(subl)
	var base: Dictionary = _class.get("stats", {})
	var stats := PlayerStats.compute(base, [], {})
	if slot_now != null:   # equipment + skill tree of the character
		var lasting := SkillTree.lasting(slot_now)
		stats = PlayerStats.compute(base, lasting[0], lasting[1])
	var crit := float(GameData.load_json(DATA + "run_config.json").get("crit", {}).get("chance", 0.05)) + float(stats.get("crit_chance", 0.0))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	rows.position = Vector2(PORTRAIT.end.x + 20, PORTRAIT.position.y)
	rows.custom_minimum_size = Vector2(BOOK.position.x + BOOK.size.x * 0.5 - 40 - PORTRAIT.end.x - 20, 0)
	menu.add_child(rows)
	for it in [["heart", "Máu", "%d" % roundi(float(stats.get("max_hp", 0)))], ["sword", "Sát thương", "%d" % roundi(float(stats.get("damage", 0)))],
			["boot", "Tốc độ", "%d" % roundi(float(stats.get("move_speed", 0)))], ["magnet", "Tầm hút", "×%.1f" % float(stats.get("magnet", 1.0))],
			["star", "Chí mạng", "%d%%" % roundi(crit * 100.0)]]:
		rows.add_child(_ledger(it[0], it[1], it[2]))
	var notes := VBoxContainer.new()
	notes.add_theme_constant_override("separation", 14)
	notes.position = Vector2(lx + 20, PORTRAIT.end.y + 26)
	notes.custom_minimum_size = Vector2(BOOK.size.x * 0.5 - 100, 0)
	menu.add_child(notes)
	var pv: Dictionary = _class.get("passive", {})
	if not pv.is_empty():
		notes.add_child(_note(String(pv.get("name", "")), String(pv.get("desc", ""))))
	var pool := GameData.load_json(DATA + String(_class.get("upgrades", "")))
	for sid: String in _class.get("start_skills", {}):
		for u: Dictionary in pool.get("upgrades", []):
			if String(u.get("id", "")) == sid:
				notes.add_child(_note(String(u.get("name", sid)), "Chiêu khởi đầu: " + String(u.get("desc", ""))))
	if slot_now != null:   # the purse, at the foot of the page
		var purse := HBoxContainer.new()
		purse.add_theme_constant_override("separation", 26)
		purse.position = Vector2(lx + 20, BOOK.end.y - 62)
		menu.add_child(purse)
		for it in [["coin", "%d vàng" % slot_now.gold, "Vàng"], ["gem", "%d đá" % slot_now.gems, "Đá (quay đồ)"]]:
			purse.add_child(_small_stat(it[0], it[1], it[2]))
			var pl := purse.get_child(-1).get_child(1) as Label   # ink on paper: no outline or shadow
			pl.add_theme_color_override("font_color", INK)
			pl.add_theme_constant_override("outline_size", 0)
			pl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
			pl.add_theme_font_size_override("font_size", 22)

	# right page: the contents, then the seal that sets off
	var head := _ink("Mục lục", 36, INK)
	head.position = Vector2(rx, BOOK.position.y + 22)
	menu.add_child(head)
	var rule := ColorRect.new()
	rule.color = INK
	rule.position = Vector2(rx, BOOK.position.y + 72)
	rule.size = Vector2(BOOK.size.x * 0.5 - 80, 3)
	menu.add_child(rule)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	list.position = Vector2(rx - 8, BOOK.position.y + 84)
	list.custom_minimum_size = Vector2(BOOK.size.x * 0.5 - 64, 0)
	menu.add_child(list)
	var buttons: Array[Button] = []
	for ch: Array in _chapters(root, menu):
		var b := _chapter(ch)
		list.add_child(b)
		buttons.append(b)
	_desc = _ink("", 18, Color("5a3a24"))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.position = Vector2(rx, BOOK.end.y - 168)
	_desc.size = Vector2(BOOK.size.x * 0.5 - 80, 52)
	menu.add_child(_desc)
	var seal := Button.new()
	seal.text = "Lên đường  ▶"
	seal.add_theme_font_size_override("font_size", 28)
	seal.custom_minimum_size = Vector2(260, 68)
	seal.position = Vector2(BOOK.end.x - 40 - 260, BOOK.end.y - 100)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("d0402a") if st != "normal" else Color("a0281c")
		sb.border_color = Color("ffd36b") if st in ["focus", "hover"] else Color("5a0c08")
		sb.set_border_width_all(4)
		sb.shadow_color = Color(0, 0, 0, 0.4)
		sb.shadow_offset = Vector2(0, 4)
		seal.add_theme_stylebox_override(st, sb)
	seal.add_theme_color_override("font_color", Color("ffe0b0"))
	seal.add_theme_color_override("font_focus_color", Color("fff2d0"))
	seal.add_theme_color_override("font_hover_color", Color("fff2d0"))
	seal.pressed.connect(func() -> void: get_tree().change_scene_to_file(STAGE_SCENE))
	seal.focus_entered.connect(func() -> void: _desc.text = "Mở bản đồ, chọn ải rồi vào trận.")
	seal.mouse_entered.connect(func() -> void: seal.grab_focus())
	menu.add_child(seal)
	buttons.append(seal)
	for k in buttons.size():   # ↑/↓ walk the contents and the seal in a ring
		buttons[k].focus_neighbor_bottom = buttons[(k + 1) % buttons.size()].get_path()
		buttons[k].focus_neighbor_top = buttons[(k + buttons.size() - 1) % buttons.size()].get_path()
	seal.call_deferred("grab_focus")

	if OS.get_cmdline_user_args().has("--lobby-settings"):   # shots of the settings page
		_show_settings.call_deferred(root, menu)

	var hint := _label("↑ ↓ chọn chương · Enter mở · Esc đổi nhân vật", 15, Color("c8a878"))
	hint.position = Vector2(BOOK.position.x, vp.y - 28)
	menu.add_child(hint)


## Ink text on the page (no outline: the page is light).
func _ink(s: String, sz: int, c: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A stat written in the ledger: icon, name, dotted leader, value.
func _ledger(icon: String, name: String, value: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var ic := TextureRect.new()
	ic.texture = UiIcons.texture(icon)
	ic.custom_minimum_size = Vector2(22, 22)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var n := _ink(name, 21, INK)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(n)
	row.add_child(_ink(value, 21, INK))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.add_child(row)
	var dots := Label.new()   # the dotted rule under the line
	dots.text = "·".repeat(200)
	dots.clip_text = true
	dots.add_theme_font_size_override("font_size", 10)
	dots.add_theme_color_override("font_color", Color("a08060"))
	dots.custom_minimum_size = Vector2(10, 8)
	v.add_child(dots)
	return v


## A note on the page: a red title in ink, then its text.
func _note(title: String, text: String) -> Control:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("normal_font_size", 18)
	l.add_theme_color_override("default_color", INK)
	l.text = "[color=#%s][font_size=21]%s.[/font_size][/color] %s" % [INK_RED.to_html(false), title, text]
	return l


## One chapter of the contents: icon, name, dotted leader, page number; the chosen one is inked dark.
func _chapter(ch: Array) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 40)
	b.focus_mode = Control.FOCUS_ALL
	var plain := StyleBoxEmpty.new()
	var on := StyleBoxFlat.new()
	on.bg_color = INK
	for st in ["normal", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, plain)
	b.add_theme_stylebox_override("hover", on)
	b.add_theme_stylebox_override("focus", on)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -8
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var ic := TextureRect.new()
	ic.texture = UiKit.vector_texture("res://assets/icons/lobby/%s.svg" % String(ch[0]), 32)
	ic.custom_minimum_size = Vector2(32, 32)
	ic.modulate = INK
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ic)
	var nm := _ink(String(ch[1]), 24, INK)
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(nm)
	var lead := _ink("·".repeat(200), 14, Color("a08060"))
	lead.clip_text = true
	lead.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lead.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lead)
	var pg := _ink(String(ch[2]), 22, EDGE)
	pg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pg)
	var open := _open(String(ch[4]))
	if not open:
		nm.modulate = Color(1, 1, 1, 0.45)
	b.pressed.connect(func() -> void:
		if _open(String(ch[4])):
			(ch[5] as Callable).call())
	b.focus_entered.connect(func() -> void:
		for l: Control in [nm, pg]:
			l.add_theme_color_override("font_color", Color("ffd36b") if l == pg else PAPER)
		ic.modulate = PAPER
		_desc.text = String(ch[3]) if _open(String(ch[4])) else _lock_text(String(ch[4])))
	b.focus_exited.connect(func() -> void:
		nm.add_theme_color_override("font_color", INK)
		pg.add_theme_color_override("font_color", EDGE)
		ic.modulate = INK)
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	return b


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
