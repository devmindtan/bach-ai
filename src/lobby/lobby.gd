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


## Hướng B "Sổ hành trình" (design-web/games/bach-ai/specs/lobby.md, user 2026-11-26 approved the web set): a travel
## journal open on a wooden desk; the left page is the character, the right page the contents (or, with C, the stats
## appendix); three ribbons on the edge are Cài đặt, Đổi nhân vật, Tiêu đề.
const BOOK := Journal.BOOK
const RUN := preload("res://src/run/run.gd")   # armor_mul: what armour takes off a hit
const PORTRAIT := Rect2(130, 170, 220, 220)


func _draw() -> void:
	Journal.draw_desk(self, get_viewport_rect().size)
	Journal.draw_book(self, BOOK)
	Journal.draw_sketch(self, PORTRAIT)
	if _hero != null:
		_hero.draw(self, "idle", _t, PORTRAIT.position + Vector2(PORTRAIT.size.x * 0.5, PORTRAIT.size.y - 26), FrontArt.scale_of(_hero, 4.0))


var _desc: Label
var _contents: Control
var _appendix: Control


## The contents: [icon, name, page, what it does, feature lock ("" = open), action].
func _chapters() -> Array:
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
	var page_w := BOOK.size.x * 0.5 - 80.0

	# left page: who is travelling
	var slot_now: Slot = Prefs.current().active_slot if _slot_mode else null
	var cname := Journal.ink(slot_now.name if slot_now != null else String(_class.get("name", "")), 48)
	cname.position = Vector2(lx, BOOK.position.y + 22)
	menu.add_child(cname)
	var sub := "%s · %s" % [String(_class.get("name", "")), String(_class.get("role", "")).to_lower()]
	if slot_now != null:
		sub += " · đã qua Ải %d" % slot_now.best
	var subl := Journal.ink(sub, 20, Journal.INK_RED)
	subl.position = Vector2(lx, BOOK.position.y + 82)
	menu.add_child(subl)
	var st := _stat_table(slot_now)
	var rows := VBoxContainer.new()   # the six basics; the rest are in the appendix (user 2026-11-26)
	rows.add_theme_constant_override("separation", 0)
	rows.position = Vector2(PORTRAIT.end.x + 20, PORTRAIT.position.y - 6)
	rows.custom_minimum_size = Vector2(BOOK.position.x + BOOK.size.x * 0.5 - 40 - PORTRAIT.end.x - 20, 0)
	menu.add_child(rows)
	for key: String in ["max_hp", "damage", "armor", "move_speed", "crit_chance", "cooldown"]:
		var r: Dictionary = st[key]
		rows.add_child(Journal.ledger(String(r["icon"]), String(r["short"]), String(r["total"]), 18))
	var more := Journal.ink("Xem đủ chỉ số (C) ▸", 16, Journal.INK_RED)
	rows.add_child(more)
	var notes := VBoxContainer.new()
	notes.add_theme_constant_override("separation", 12)
	notes.position = Vector2(lx + 20, PORTRAIT.end.y + 36)
	notes.custom_minimum_size = Vector2(BOOK.size.x * 0.5 - 100, 0)
	menu.add_child(notes)
	var pv: Dictionary = _class.get("passive", {})
	if not pv.is_empty():
		notes.add_child(Journal.note(String(pv.get("name", "")), String(pv.get("desc", ""))))
	var pool := GameData.load_json(DATA + String(_class.get("upgrades", "")))
	for sid: String in _class.get("start_skills", {}):
		for u: Dictionary in pool.get("upgrades", []):
			if String(u.get("id", "")) == sid:
				notes.add_child(Journal.note(String(u.get("name", sid)), "Chiêu khởi đầu: " + String(u.get("desc", ""))))
	if slot_now != null:   # the purse: every resource the character holds (user 2026-11-26)
		var rule := ColorRect.new()
		rule.color = Journal.INK
		rule.position = Vector2(lx + 20, BOOK.end.y - 84)
		rule.size = Vector2(BOOK.size.x * 0.5 - 100, 3)
		menu.add_child(rule)
		var purse := GridContainer.new()
		purse.columns = 3
		purse.add_theme_constant_override("h_separation", 22)
		purse.add_theme_constant_override("v_separation", 0)
		purse.position = Vector2(lx + 20, BOOK.end.y - 76)
		menu.add_child(purse)
		for it in [["coin", "%d vàng" % slot_now.gold, "Vàng"], ["gem", "%d đá" % slot_now.gems, "Đá (quay đồ)"],
				["essence", "%d Tinh hoa" % slot_now.essence, "Tinh hoa: học Cây kỹ năng"],
				["nav_deck", "%d Mảnh thẻ" % slot_now.shards, "Mảnh thẻ: nâng Cây thẻ"],
				["pill", "%d Tẩy Tủy Đan" % slot_now.pills, "Tẩy Tủy Đan: tẩy lại Cây kỹ năng"]]:
			var cell := _small_stat(it[0], it[1], it[2])
			var pl := cell.get_child(1) as Label   # ink on paper: no outline or shadow
			pl.add_theme_color_override("font_color", Journal.INK)
			pl.add_theme_constant_override("outline_size", 0)
			pl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
			pl.add_theme_font_size_override("font_size", 18)
			purse.add_child(cell)

	# right page: the contents and the seal; C swaps in the stats appendix
	_contents = Control.new()
	_contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(_contents)
	var head := Journal.ink("Mục lục", 36)
	head.position = Vector2(rx, BOOK.position.y + 22)
	_contents.add_child(head)
	var rule2 := ColorRect.new()
	rule2.color = Journal.INK
	rule2.position = Vector2(rx, BOOK.position.y + 72)
	rule2.size = Vector2(page_w, 3)
	_contents.add_child(rule2)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.position = Vector2(rx - 8, BOOK.position.y + 86)
	list.custom_minimum_size = Vector2(BOOK.size.x * 0.5 - 64, 0)
	_contents.add_child(list)
	var buttons: Array[Button] = []
	for ch: Array in _chapters():
		var b := _chapter(ch)
		list.add_child(b)
		buttons.append(b)
	_desc = Journal.ink("", 18, Journal.INK_SOFT)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.position = Vector2(rx, BOOK.end.y - 168)
	_desc.size = Vector2(page_w, 52)
	_contents.add_child(_desc)
	var seal := Journal.seal("Lên đường  ▶")
	seal.position = Vector2(BOOK.end.x - 40 - 260, BOOK.end.y - 100)
	seal.pressed.connect(func() -> void: get_tree().change_scene_to_file(STAGE_SCENE))
	seal.focus_entered.connect(func() -> void: _desc.text = "Mở bản đồ, chọn ải rồi vào trận.")
	_contents.add_child(seal)
	buttons.append(seal)
	for k in buttons.size():   # ↑/↓ walk the contents and the seal in a ring
		buttons[k].focus_neighbor_bottom = buttons[(k + 1) % buttons.size()].get_path()
		buttons[k].focus_neighbor_top = buttons[(k + buttons.size() - 1) % buttons.size()].get_path()
	_appendix = _build_appendix(st, rx, page_w)
	_appendix.visible = OS.get_cmdline_user_args().has("--lobby-stats")
	_contents.visible = not _appendix.visible
	menu.add_child(_appendix)

	# the ribbons: icon tabs on the book's edge (→ from the contents, ↑ ↓ between them, ← back)
	var ribs: Array[Button] = []
	for k in 3:
		var r: Array = [["nav_settings", Color("3a6a8a"), "Cài đặt", "Cài đặt: âm thanh, hiển thị, phím.", func() -> void: _show_settings(root, menu)],
			["nav_character", Color("6a8a3a"), "Đổi nhân vật", "Đổi nhân vật: chọn hoặc tạo nhân vật khác (Esc).",
				func() -> void: get_tree().change_scene_to_file(CHARACTERS_SCENE)],
			["nav_title", Color("8a3a6a"), "Tiêu đề", "Tiêu đề: về màn hình tiêu đề.", func() -> void: get_tree().change_scene_to_file(TITLE_SCENE)]][k]
		var rb := Journal.ribbon(String(r[0]), r[1], String(r[2]))
		rb.position = Vector2(BOOK.end.x + 14, BOOK.position.y + 56 + k * 60)
		rb.pressed.connect(r[4])
		var say := String(r[3])
		rb.focus_entered.connect(func() -> void: _desc.text = say)
		menu.add_child(rb)
		ribs.append(rb)
	for k in 3:
		ribs[k].focus_neighbor_bottom = ribs[(k + 1) % 3].get_path()
		ribs[k].focus_neighbor_top = ribs[(k + 2) % 3].get_path()
		ribs[k].focus_neighbor_left = buttons[0].get_path()
	for b in buttons:
		b.focus_neighbor_right = ribs[0].get_path()
	if OS.get_cmdline_user_args().has("--lobby-ribbon"):   # shots of a ribbon in focus
		ribs[1].call_deferred("grab_focus")
	else:
		seal.call_deferred("grab_focus")

	if OS.get_cmdline_user_args().has("--lobby-settings"):   # shots of the settings page
		_show_settings.call_deferred(root, menu)

	var hint := _label("↑ ↓ chọn chương · → dải đánh dấu · Enter mở · C chỉ số · Esc đổi nhân vật", 15, Color("c8a878"))
	hint.position = Vector2(BOOK.position.x, vp.y - 28)
	menu.add_child(hint)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_C and _appendix != null:   # the stats appendix
		_appendix.visible = not _appendix.visible
		_contents.visible = not _appendix.visible
		get_viewport().set_input_as_handled()


const STAT_ROWS := [["max_hp", "Máu tối đa", "Máu", "heart"], ["regen", "Hồi máu", "Hồi máu", "regen"], ["armor", "Giáp", "Giáp", "shield"],
	["damage", "Sát thương", "Sát thương", "sword"], ["crit_chance", "Chí mạng", "Chí mạng", "star"],
	["crit_mul", "Sát thương chí mạng", "ST chí mạng", "star"], ["cooldown", "Hồi chiêu", "Hồi chiêu", "haste"],
	["area", "Vùng đánh", "Vùng", "reach"], ["amount", "Số lượng", "Số lượng", "extra_strike"], ["move_speed", "Tốc độ chạy", "Tốc độ", "boot"],
	["magnet", "Tầm hút", "Tầm hút", "magnet"]]


## Every stat of the character with where it comes from: base (class + the run's crit base), equipment, skill tree, total.
func _stat_table(slot: Slot) -> Dictionary:
	var base: Dictionary = _class.get("stats", {})
	var ups: Array = []
	var lv := {}
	if slot != null:
		var lasting := SkillTree.lasting(slot)
		ups = lasting[0]
		lv = lasting[1]
	var bd := PlayerStats.breakdown(base, ups, lv)
	var crit: Dictionary = GameData.load_json(DATA + "run_config.json").get("crit", {})
	var extra := {"crit_chance": float(crit.get("chance", 0.05)), "crit_mul": float(crit.get("mul", 1.75))}
	var gear_ids: Dictionary = slot.profile.defs if slot != null else {}
	var out := {}
	for r: Array in STAT_ROWS:
		var key: String = r[0]
		var e: Dictionary = bd.get(key, {"base": float(base.get(key, 0.0)), "final": float(base.get(key, 0.0)), "parts": []})
		var parts := {"gear": [0.0, 0.0], "tree": [0.0, 0.0]}   # [add, mul]
		for p: Dictionary in e["parts"]:
			var src := "gear" if gear_ids.has(String(p["id"])) else "tree"
			parts[src][0] += float(p.get("add", 0.0))
			parts[src][1] += float(p.get("mul", 0.0))
		var b0 := float(e["base"]) + float(extra.get(key, 0.0))
		out[key] = {"name": r[1], "short": r[2], "icon": r[3], "base": _fmt(key, b0),
			"gear": _fmt_part(key, parts["gear"]), "tree": _fmt_part(key, parts["tree"]),
			"total": _fmt(key, float(e["final"]) + float(extra.get(key, 0.0)))}
	return out


func _fmt(key: String, v: float) -> String:
	match key:
		"crit_chance", "crit_mul":
			return "%d%%" % roundi(v * 100.0)
		"cooldown":
			return "%+d%%" % roundi((v - 1.0) * 100.0) if not is_equal_approx(v, 1.0) else "0%"
		"area", "magnet":
			return "×%.2f" % v
		"regen":
			return ("%.1f" % v).trim_suffix(".0") + "/giây"
		"amount":
			return "+%d" % roundi(v)
		"armor":
			var k := float(GameData.load_json(DATA + "run_config.json").get("player", {}).get("armor_k", 15.0))
			return "%d (−%d%%)" % [roundi(v), roundi((1.0 - RUN.armor_mul(v, k)) * 100.0)] if v > 0.0 else "0"
		_:
			return str(roundi(v))


func _fmt_part(key: String, am: Array) -> String:
	var bits := PackedStringArray()
	if not is_zero_approx(float(am[0])):
		bits.append(("%+d%%" % roundi(float(am[0]) * 100.0)) if key in ["crit_chance", "crit_mul"] else ("%+.1f" % float(am[0])).trim_suffix(".0"))
	if not is_zero_approx(float(am[1])):
		bits.append("%+d%%" % roundi(float(am[1]) * 100.0))
	return " ".join(bits) if not bits.is_empty() else "—"


## The appendix page: every stat, base / equipment / skill tree / total.
func _build_appendix(st: Dictionary, rx: float, page_w: float) -> Control:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := Journal.ink("Phụ lục: chỉ số", 36)
	head.position = Vector2(rx, BOOK.position.y + 22)
	box.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 2)
	grid.position = Vector2(rx, BOOK.position.y + 80)
	box.add_child(grid)
	for h in ["Chỉ số", "Gốc", "Trang bị", "Cây", "Tổng"]:
		grid.add_child(Journal.ink(h, 16, Journal.EDGE))
	for r: Array in STAT_ROWS:
		var e: Dictionary = st[r[0]]
		grid.add_child(Journal.ink(String(e["name"]), 17))
		grid.add_child(Journal.ink(String(e["base"]), 17))
		grid.add_child(Journal.ink(String(e["gear"]), 17, Color("2a7a3a") if e["gear"] != "—" else Journal.INK))
		grid.add_child(Journal.ink(String(e["tree"]), 17, Color("2a7a3a") if e["tree"] != "—" else Journal.INK))
		grid.add_child(Journal.ink(String(e["total"]), 17, Journal.INK_RED))
	var foot := Journal.ink("C: về Mục lục.", 18, Journal.INK_SOFT)
	foot.position = Vector2(rx, BOOK.end.y - 60)
	box.add_child(foot)
	return box


## One chapter of the contents: icon, name, dotted leader, page number; the chosen one is inked dark.
func _chapter(ch: Array) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 44)
	b.focus_mode = Control.FOCUS_ALL
	var plain := StyleBoxEmpty.new()
	var on := StyleBoxFlat.new()
	on.bg_color = Journal.INK
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
	ic.modulate = Journal.INK
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ic)
	var nm := Journal.ink(String(ch[1]), 26)
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(nm)
	var lead := Journal.dotted(14)
	lead.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lead.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lead)
	var pg := Journal.ink(String(ch[2]), 22, Journal.EDGE)
	pg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pg)
	if not _open(String(ch[4])):
		nm.modulate = Color(1, 1, 1, 0.45)
	b.pressed.connect(func() -> void:
		if _open(String(ch[4])):
			(ch[5] as Callable).call())
	b.focus_entered.connect(func() -> void:
		nm.add_theme_color_override("font_color", Journal.PAPER)
		pg.add_theme_color_override("font_color", Journal.GOLD)
		ic.modulate = Journal.PAPER
		_desc.text = String(ch[3]) if _open(String(ch[4])) else _lock_text(String(ch[4])))
	b.focus_exited.connect(func() -> void:
		nm.add_theme_color_override("font_color", Journal.INK)
		pg.add_theme_color_override("font_color", Journal.EDGE)
		ic.modulate = Journal.INK)
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
	card.add_theme_stylebox_override("panel", Journal.sheet_style())   # a loose sheet over the journal
	center.add_child(card)
	card.add_child(SettingsPanel.build(func() -> void:
		center.queue_free()
		menu.visible = true))
	Journal.restyle(card.get_child(0))




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
