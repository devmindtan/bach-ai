extends Node2D
## Album (bách khoa) screen (design/ux/album.md, prototype design-web/screen-album.html, user approved
## 2026-11-23): tabs Quái / Boss / Kỹ năng (Q / E, LB / RB), a 7-column grid on the left, the chosen
## entry's details on the right. A monster or boss unlocks at its first kill (slot.bestiary); locked ones
## show as a dark silhouette with "?". Esc: lobby.
##
## Command line (after `--`), for shots: --album-tab=N (0 Quái, 1 Boss, 2 Kỹ năng), --album-sel=N,
## --album-all (every monster unlocked).

const LOBBY_SCENE := "res://src/lobby/lobby.tscn"
const COLS := 6   # journal: the grid on the left page (design-web screen-album-journal)
const CELL := 70.0
const LEFT_PAGE := Rect2(110, 74, 470, 572)
const RIGHT_PAGE := Rect2(660, 74, 470, 572)
const WEAK := Color("ff6a78")
const RESIST := Color("a9a9b8")
const TABS := ["Quái", "Boss", "Kỹ năng"]

var _slot: Slot
var _monsters := {}
var _species := {}
var _where := {}          # monster id -> "Đồng cỏ, Rừng Âm U" (regions whose waves spawn it)
var _skills: Array = []   # [{id, name, element, cls, cooldown, desc}]
var _sheets := {}
var _tab := 0
var _sel := 0
var _all := false
var _layer: CanvasLayer
var _cells: Array = []


func _ready() -> void:
	Sfx.music("menu")
	var prefs := Prefs.current()
	if prefs.is_fixed():
		prefs.ensure_preview_slot()
	else:
		prefs.ensure_slots()
	_slot = prefs.active_slot
	if _slot == null:
		get_tree().change_scene_to_file.call_deferred("res://src/front/characters.tscn")
		return
	_monsters = GameData.load_json("res://assets/data/monsters.json")
	_species = GameData.load_json("res://assets/data/species.json")
	_where = monster_regions(Stages.load_default())
	_skills = skill_entries()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--album-tab="):
			_tab = clampi(int(a.get_slice("=", 1)), 0, TABS.size() - 1)
		elif a.begins_with("--album-sel="):
			_sel = int(a.get_slice("=", 1))
		elif a == "--album-all":
			_all = true
	_build()


func _draw() -> void:
	Journal.draw_desk(self, get_viewport_rect().size)
	Journal.draw_book(self, Journal.BOOK)


## Monster ids of the tab: plain monsters or bosses, in monsters.json order.
func entries(tab: int) -> Array:
	if tab == 2:
		return _skills
	var out := []
	for id: String in _monsters:
		var m = _monsters[id]
		if m is Dictionary and bool(m.get("boss", false)) == (tab == 1):
			out.append(id)
	return out


## True once monster [param id] has been killed (or every one with --album-all).
func unlocked(id: String) -> bool:
	return _all or int(_slot.bestiary.get(id, 0)) > 0


## Every class's skills for the Kỹ năng tab: {id, name, element, cls, cooldown, desc}.
static func skill_entries() -> Array:
	var out := []
	var classes := GameData.load_json("res://assets/data/classes.json")
	var elems: Dictionary = GameData.load_json("res://assets/data/species.json").get("elements", {})
	var dash_listed := false
	for cls: String in classes:   # every class (user 2026-11-26: the archer and assassin were missing)
		if cls.begins_with("_"):
			continue
		var pool := GameData.load_json("res://assets/data/" + String(classes[cls].get("upgrades", "upgrades_%s.json" % cls)))
		for u: Dictionary in pool.get("upgrades", []):
			if u.get("kind") != "skill" or (u.get("id") == "dash" and dash_listed):
				continue
			if u.get("id") == "dash":
				dash_listed = true
			var sp: Dictionary = pool.get("skills", {}).get(u["id"], {})
			out.append({"id": u["id"], "name": u.get("name", u["id"]), "element": String(elems.get(u.get("element", ""), "")),
				"cls": String(classes.get(cls, {}).get("name", cls)), "cooldown": float(sp.get("cooldown", 0.0)),
				"desc": String(u.get("desc", "")), "sp": sp, "hero": FrontArt.hero_sprite(classes.get(cls, {}))})
	return out


## monster id -> the regions whose stage waves spawn it, by name ("Đồng cỏ, Rừng Âm U").
static func monster_regions(stages: Stages) -> Dictionary:
	var seen := {}
	for n in range(1, stages.count() + 1):
		var reg := String(stages.region(n).get("name", ""))
		for w: Dictionary in GameData.load_json(stages.waves_path(n)).get("waves", []):
			var id := String(w.get("monster", "")).get_slice("@", 0)
			if not seen.has(id):
				seen[id] = []
			if not (seen[id] as Array).has(reg):
				(seen[id] as Array).append(reg)
	var out := {}
	for id: String in seen:
		out[id] = ", ".join(seen[id])
	return out


func _unhandled_input(event: InputEvent) -> void:
	var n := entries(_tab).size()
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(LOBBY_SCENE)
		return
	var moved := true
	if event.is_action_pressed("ui_right"):
		_sel = mini(n - 1, _sel + 1)
	elif event.is_action_pressed("ui_left"):
		_sel = maxi(0, _sel - 1)
	elif event.is_action_pressed("ui_down"):
		_sel = mini(n - 1, _sel + COLS)
	elif event.is_action_pressed("ui_up"):
		_sel = maxi(0, _sel - COLS)
	elif _tab_key(event, 1):
		_tab = (_tab + 1) % TABS.size()
		_sel = 0
	elif _tab_key(event, -1):
		_tab = (_tab + TABS.size() - 1) % TABS.size()
		_sel = 0
	else:
		moved = false
	if moved:
		get_viewport().set_input_as_handled()
		_rebuild()


## Q / E on the keyboard, LB / RB on a gamepad switch tabs.
func _tab_key(event: InputEvent, dir: int) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return (event as InputEventKey).physical_keycode == (KEY_E if dir > 0 else KEY_Q)
	if event is InputEventJoypadButton and event.pressed:
		return (event as InputEventJoypadButton).button_index == (JOY_BUTTON_RIGHT_SHOULDER if dir > 0 else JOY_BUTTON_LEFT_SHOULDER)
	return false


func _rebuild() -> void:
	if _layer != null:
		_layer.queue_free()
	_build()


func _build() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	var root := Control.new()
	root.size = get_viewport_rect().size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	Journal.back_tab(root, func() -> void: get_tree().change_scene_to_file(LOBBY_SCENE))   # "Trở lại" (web .back-tab)
	var title := Journal.ink("Album", 44)
	title.position = LEFT_PAGE.position + Vector2(0, -8)
	root.add_child(title)
	var opened := 0
	var total := 0
	for t in 2:
		for id: String in entries(t):
			total += 1
			opened += 1 if unlocked(id) else 0
	var done := Journal.ink("Đã mở %d / %d quái · %d kỹ năng" % [opened, total, _skills.size()], 18, Journal.INK_RED)
	done.position = LEFT_PAGE.position + Vector2(2, 48)
	root.add_child(done)
	# tabs
	var tabs := HBoxContainer.new()
	tabs.position = LEFT_PAGE.position + Vector2(0, 84)
	tabs.add_theme_constant_override("separation", 8)
	root.add_child(tabs)
	for k in TABS.size():
		tabs.add_child(_tab_plate(k))
	Journal.restyle(tabs)
	var open_tab := tabs.get_child(_tab) as PanelContainer   # the open tab on ink (restyle made every plate a sketch box)
	open_tab.add_theme_stylebox_override("panel", UiKit.style(Journal.INK, 0, Journal.INK, 2))
	(open_tab.get_child(0) as Label).add_theme_color_override("font_color", Journal.GOLD)
	# grid
	var list := entries(_tab)
	_sel = clampi(_sel, 0, maxi(0, list.size() - 1))
	var scroll := ScrollContainer.new()   # more entries than the page holds scroll, the chosen one kept in view
	scroll.position = LEFT_PAGE.position + Vector2(0, 134)
	scroll.size = Vector2(LEFT_PAGE.size.x + 14, LEFT_PAGE.end.y - LEFT_PAGE.position.y - 134)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	var chosen: Control = null
	for i in list.size():
		var cell := _cell(list[i], i == _sel, i)
		grid.add_child(cell)
		if i == _sel:
			chosen = cell
	if chosen != null:
		(func() -> void: scroll.ensure_control_visible(chosen)).call_deferred()
	# detail
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.position = RIGHT_PAGE.position
	panel.custom_minimum_size = Vector2(RIGHT_PAGE.size.x, 0)
	root.add_child(panel)
	if not list.is_empty():
		_detail(panel, list[_sel])
	Journal.restyle(panel)
	var foot := Journal.ink("←↑↓→ chọn · %s đổi mục · %s về sổ" % ["Q / E" if not UiKit.using_pad() else "LB / RB",
		"Esc" if not UiKit.using_pad() else "B"], 15, Journal.PAPER)
	foot.position = Vector2(Journal.BOOK.position.x, Journal.BOOK.end.y + 14)
	root.add_child(foot)


## A tab plate; a click opens tab [param k] (the mouse works as well as Q / E; user 2026-11-23).
func _tab_plate(k: int) -> Control:
	var p := UiKit.panel(UiKit.PANEL_DARK if k != _tab else UiKit.PANEL, 6, UiKit.GOLD if k == _tab else Color("3a3448"))
	p.custom_minimum_size = Vector2(150, 40)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var l := Journal.ink("%s  %d" % [TABS[k], entries(k).size()], 20, Journal.GOLD if k == _tab else Journal.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	p.gui_input.connect(func(ev: InputEvent) -> void:
		if _left_click(ev) and k != _tab:
			_tab = k
			_sel = 0
			_rebuild.call_deferred())
	return p


static func _left_click(ev: InputEvent) -> bool:
	return ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed \
		and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT


## A grid cell; a click selects it (index [param i]).
func _cell(e: Variant, on: bool, i := 0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(CELL, CELL)
	c.clip_contents = true   # a wide sprite (Dơi) must not spill into the next cell
	c.mouse_filter = Control.MOUSE_FILTER_STOP   # user 2026-11-23: the Album must work with the mouse
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.gui_input.connect(func(ev: InputEvent) -> void:
		if _left_click(ev) and i != _sel:
			_sel = i
			_rebuild.call_deferred())
	if _tab == 2:
		var ic := UiKit.card_icon(String(e["id"]), 56.0)
		if String(e.get("kind", "skill")) == "stat":
			ic.modulate = Journal.INK
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.position = Vector2(7, 7)
		c.add_child(ic)
	var id := "" if _tab == 2 else String(e)
	var lock := _tab < 2 and not unlocked(id)
	var boss := _tab == 1
	c.draw.connect(func() -> void:
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Journal.INK if on else Journal.SKETCH)   # a sketch cell on the page
		c.draw_rect(Rect2(Vector2(1.5, 1.5), c.size - Vector2(3, 3)), Journal.GOLD if on else (Journal.INK_RED if boss else Journal.INK), false, 3.0)
		if id != "":
			_draw_monster(c, id, c.size * 0.5, 36.0, lock)
		if lock:
			var f := ThemeDB.fallback_font
			c.draw_string(f, Vector2(0, c.size.y * 0.5 + 12), "?", HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 34, Journal.PAPER if on else Journal.DOTS))
	return c


## The monster's first frame, its body centred on [param at] with radius about [param r]; black when locked.
func _draw_monster(c: Control, id: String, at: Vector2, r: float, lock: bool) -> void:
	var m: Dictionary = _monsters[id]
	var sprite := String(m.get("sprite", id))
	if not _sheets.has(sprite):
		_sheets[sprite] = SpriteSheet.load_dir("res://assets/sprites/custom/" + sprite, sprite)
	var sheet: SpriteSheet = _sheets[sprite]
	if sheet == null:
		return
	# whole-number scale from the visible pixels of the first frame (frames carry empty margin: Yêu Tinh's is
	# wide), so every monster fills about the same box; centred on its visible rect, not the canvas
	var used := _used_rect(sheet)
	var k := maxf(1.0, floorf(r * 2.0 / maxf(1.0, maxf(used.size.x, used.size.y))))
	var mid := used.position + used.size * 0.5 - sheet.anchor
	var off := mid * k
	sheet.draw(c, sheet.animation_names()[0], 0.0, at - off, k, false, Color(0, 0, 0, 0.6) if lock else Color.WHITE)


var _used := {}


## The opaque pixels of [param sheet]'s first frame (cached by sprite name).
func _used_rect(sheet: SpriteSheet) -> Rect2:
	if _used.has(sheet.name):
		return _used[sheet.name]
	var r := Rect2(Vector2.ZERO, sheet.frame_size)
	if sheet.texture != null:
		var img := sheet.texture.get_image()
		img.decompress()
		var src := sheet.src_rect(sheet.frame_index(sheet.animation_names()[0], 0.0))
		var u := img.get_region(Rect2i(src)).get_used_rect()
		if u.size.x > 0:
			r = Rect2(u)
	_used[sheet.name] = r
	return r


func _detail(panel: PanelContainer, e: Variant) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var art := Control.new()
	art.custom_minimum_size = Vector2(0, 150)
	art.clip_contents = true
	v.add_child(art)
	if _tab == 2:
		var sk: Dictionary = e
		art.custom_minimum_size = Vector2(0, 190)
		var sim := SkillSim.new()   # the skill cast on a slime dummy, tiers I..V in turn
		sim.setup(sk.get("sp", {}), String(sk.get("hero", "swordsman")))
		sim.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.add_child(sim)
		var ic := UiKit.card_icon(String(sk["id"]), 40.0)
		ic.position = Vector2(RIGHT_PAGE.size.x - 48, 8)
		art.add_child(ic)
		v.add_child(UiKit.label(String(sk["name"]), 34, UiKit.TEXT))
		v.add_child(UiKit.label("%s · Hệ %s" % [sk["cls"], sk["element"]], 20, UiKit.GOLD))
		v.add_child(_row("Hồi chiêu", "%.1f s" % float(sk["cooldown"])))
		var d := UiKit.label(String(sk["desc"]), 17, UiKit.MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(RIGHT_PAGE.size.x, 0)
		v.add_child(d)
		return
	var id := String(e)
	var lock := not unlocked(id)
	var m: Dictionary = _monsters[id]
	art.draw.connect(func() -> void:
		art.draw_rect(Rect2(Vector2.ZERO, art.size), Color("d8c498"))   # the portrait sketch box
		art.draw_rect(Rect2(Vector2.ZERO, art.size), Journal.EDGE, false, 4.0)
		_draw_monster(art, id, art.size * 0.5, 66.0, lock))
	v.add_child(UiKit.label("???" if lock else String(m.get("name", id)), 34, UiKit.TEXT))
	var sp: Dictionary = _species.get("species", {}).get(String(m.get("species", "")), {})
	if lock:
		v.add_child(UiKit.label("Hạ một lần để mở", 20, UiKit.GOLD))
		return
	v.add_child(UiKit.label("%s · %s" % [sp.get("name", ""), _where.get(id, "")], 20, UiKit.GOLD))
	var names: Dictionary = _species.get("elements", {})
	var weak: Array = sp.get("weak", []).map(func(x: String) -> String: return String(names.get(x, x)))
	var res: Array = sp.get("resist", []).map(func(x: String) -> String: return String(names.get(x, x)))
	var el := HBoxContainer.new()
	el.add_theme_constant_override("separation", 14)
	if not weak.is_empty():
		el.add_child(UiKit.label("Yếu: " + ", ".join(weak), 18, WEAK))
	if not res.is_empty():
		el.add_child(UiKit.label("Kháng: " + ", ".join(res), 18, RESIST))
	if weak.is_empty() and res.is_empty():
		el.add_child(UiKit.label("Không yếu, không kháng hệ nào", 18, UiKit.MUTED))
	v.add_child(el)
	v.add_child(_row("Máu (ải 1)", str(roundi(float(m.get("hp", 0))))))
	v.add_child(_row("Sát thương", str(roundi(float(m.get("damage", 0))))))
	v.add_child(_row("Tốc độ", str(roundi(float(m.get("speed", 0))))))
	v.add_child(UiKit.label("Đã hạ: %d" % int(_slot.bestiary.get(id, 0)), 18, UiKit.MUTED))


func _row(k: String, val: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	var a := UiKit.label(k, 20, UiKit.MUTED)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	h.add_child(UiKit.label(val, 20, UiKit.TEXT))
	return h
