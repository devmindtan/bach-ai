extends Node2D
## Stage and mode select (design/ux/stage-select.md, after Vampire Survivors' stage
## selection): game modes in a left column (Vượt ải; the coming ones shown locked),
## the mode's stages as a grid of regions x stages in the middle, the chosen stage's
## details on the right (boss, time, difficulty against stage 1, monsters, rewards,
## wins) and one main action, "Bắt đầu ▶". Esc / "Quay lại" go back to the lobby.
##
## Command line (after `--`), for shots: --force-slots is not needed (fixed mode
## uses the preview character), --stage-pick=N chooses stage N.

const LOBBY_SCENE := "res://src/lobby/lobby.tscn"
const RUN_SCENE := "res://src/run/run.tscn"
const TILE := Vector2(56, 52)
const MODES := [["campaign", "Vượt ải", "30 ải, mở dần", true],
	["endless", "Vô tận", "Sắp có", false], ["trials", "Thử thách", "Sắp có", false]]
const BOSS_GOLD := Color("f2c14e")
const TILE_LOCKED := Color("15121e")
const TILE_CLEARED := Color("1f3a26")

var _stages: Stages
var _monsters := {}
var _sheets := {}
var _slot: Slot
var _n := 1
var _scroll := Vector2.ZERO
var _layer: CanvasLayer


func _ready() -> void:
	_stages = Stages.load_default()
	_monsters = GameData.load_json("res://assets/data/monsters.json")
	var prefs := Prefs.current()
	if prefs.is_fixed():
		prefs.ensure_preview_slot()
	elif prefs.active_slot == null:
		prefs.ensure_slots()
	_slot = prefs.active_slot
	if _slot == null:
		get_tree().change_scene_to_file.call_deferred("res://src/front/characters.tscn")
		return
	_n = clampi(prefs.stage_target, 1, _slot.unlocked(_stages.count()))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stage-pick="):
			_n = clampi(int(a.get_slice("=", 1)), 1, _stages.count())
	_build()


func _process(delta: float) -> void:
	_scroll += Vector2(18.0, 6.0) * delta
	queue_redraw()


func _draw() -> void:
	FrontArt.backdrop(self, _scroll, get_viewport_rect().size, _stages.ground(_n) if _stages != null else {})


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(LOBBY_SCENE)


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
	var title := UiKit.label("Chọn ải", 34, UiKit.GOLD)
	title.position = Vector2(40, 24)
	root.add_child(title)
	var who := UiKit.label("%s  ·  đã vượt ải %d" % [_slot.name, _slot.best], 15, UiKit.MUTED)
	who.position = Vector2(42, 70)
	root.add_child(who)
	var back := UiKit.button("Quay lại  (Esc)", func() -> void: get_tree().change_scene_to_file(LOBBY_SCENE), Vector2(180, 42), 17)
	back.position = Vector2(root.size.x - 40 - 180, 28)
	root.add_child(back)

	# left: game modes (only the campaign for now; the others shown locked)
	var modes := VBoxContainer.new()
	modes.position = Vector2(40, 104)
	modes.add_theme_constant_override("separation", 10)
	root.add_child(modes)
	modes.add_child(UiKit.label("Chế độ", 16, UiKit.GOLD))
	for m in MODES:
		modes.add_child(_mode_button(m[1], m[2], m[3], m[0] == "campaign"))

	# middle: the stage grid, a row per region
	var grid := VBoxContainer.new()
	grid.position = Vector2(284, 104)
	grid.add_theme_constant_override("separation", 6)
	root.add_child(grid)
	var unlocked := _slot.unlocked(_stages.count())
	var chosen_tile: Button = null
	for r: Dictionary in _stages.regions():
		grid.add_child(UiKit.label(String(r.get("name", "")), 17, UiKit.GOLD))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		grid.add_child(row)
		for n in range(int(r.get("from", 1)), int(r.get("to", 10)) + 1):
			var t := _tile(n, n > unlocked)
			row.add_child(t)
			if n == _n:
				chosen_tile = t
	var legend := UiKit.label("✓ đã vượt  ·  viền vàng + đầu lâu: ải boss  ·  mờ: chưa mở", 13, UiKit.MUTED)
	grid.add_child(legend)
	# the mode's rules and progress under the grid (like the mode window of Vampire Survivors)
	var info := UiKit.panel(Color(0.09, 0.08, 0.13, 0.9), 16)
	info.position = Vector2(284, 440)
	info.custom_minimum_size = Vector2(614, 0)
	root.add_child(info)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 6)
	info.add_child(iv)
	iv.add_child(UiKit.label("Vượt ải", 20, UiKit.TEXT))
	for line in ["Trụ hết giờ hoặc hạ boss để vượt ải; vượt ải nào thì mở ải kế tiếp.",
			"Mỗi ải mạnh hơn ải trước: quái nhiều máu, đánh đau và đông hơn.",
			"Ải 10, 20, 30 có boss. Cấp 10, 20, 30 trong trận: chọn phần thưởng mốc."]:
		var l := UiKit.label("•  " + line, 14, UiKit.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(580, 0)
		iv.add_child(l)
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 12)
	iv.add_child(bar_row)
	var total := _stages.count()
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(440, 22)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.draw.connect(func() -> void:
		bar.draw_rect(Rect2(0, 6, 440, 10), Color("2a2438"))
		bar.draw_rect(Rect2(0, 6, 440.0 * float(_slot.best) / float(total), 10), Color("5f9a5a"))
		for b in range(_stages.data.get("boss_every", 10), total + 1, int(_stages.data.get("boss_every", 10))):
			bar.draw_rect(Rect2(440.0 * float(b) / float(total) - 1, 2, 2, 18), BOSS_GOLD))
	bar_row.add_child(bar)
	var prog := UiKit.label("Đã vượt %d / %d ải" % [_slot.best, total], 15, UiKit.TEXT)
	prog.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(prog)
	# its bottom lines up with the detail column's (104 + 500) once laid out
	(func() -> void: info.position.y = 604.0 - info.size.y).call_deferred()

	# right: the chosen stage, then the main action under it
	var panel := UiKit.panel(Color(0.09, 0.08, 0.13, 0.96), 18)
	panel.position = Vector2(root.size.x - 40 - 330, 104)
	panel.custom_minimum_size = Vector2(330, 500)
	panel.size = Vector2(330, 500)
	root.add_child(panel)
	_detail(panel, unlocked)
	var start := UiKit.button("Bắt đầu  ▶", func() -> void: _start(), Vector2(330, 64), 26, UiKit.PRIMARY)
	start.position = Vector2(root.size.x - 40 - 330, 616)
	start.disabled = _n > unlocked
	root.add_child(start)
	if not start.disabled:
		start.call_deferred("grab_focus")
	elif chosen_tile != null:
		chosen_tile.call_deferred("grab_focus")


func _mode_button(name: String, line: String, open: bool, on: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(220, 64)
	b.focus_mode = Control.FOCUS_ALL if open else Control.FOCUS_NONE
	var bg := UiKit.PANEL_HOVER if on else (UiKit.PANEL if open else UiKit.PANEL_DARK)
	var border := Color.WHITE if on else (UiKit.GOLD if open else Color("4a4458"))
	for st in ["normal", "hover", "focus", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, UiKit.style(bg, 10, border, 3 if on else 2))
	b.disabled = not open
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_top = 8
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	v.add_child(UiKit.label(name, 20, UiKit.TEXT if open else Color("6a6478")))
	v.add_child(UiKit.label(line, 13, UiKit.MUTED if open else Color("5a5468")))
	return b


## A stage tile: the number centred from the font size, a check when won, a gold
## frame and a skull on boss stages, a white frame when chosen; dim when locked.
func _tile(n: int, locked: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = TILE
	b.focus_mode = Control.FOCUS_NONE if locked else Control.FOCUS_ALL
	var won := _slot.won(n)
	var boss := _stages.is_boss(n)
	var chosen := n == _n
	var bg := TILE_LOCKED if locked else (TILE_CLEARED if won else UiKit.PANEL)
	var border := BOSS_GOLD if boss else (Color("5f9a5a") if won else UiKit.GOLD)
	if locked:
		border = Color("6a5a2a") if boss else Color("3a3448")
	if chosen:
		border = Color.WHITE
	for st in ["normal", "disabled"]:
		b.add_theme_stylebox_override(st, UiKit.style(bg, 4, border, 3 if boss or chosen else 2))
	for st in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(st, UiKit.style(UiKit.PANEL_HOVER, 4, Color.WHITE, 3))
	b.disabled = locked
	Tip.attach(b, "Ải %d" % n, ("Vượt ải %d để mở." % (n - 1)) if locked else ("Đã vượt %d lần." % int(_slot.wins.get(str(n), 0)) if won else "Chưa vượt."),
		BOSS_GOLD if boss else UiKit.GOLD, "skull" if boss else "", "Ải boss" if boss else String(_stages.region(n).get("name", "")))
	b.pressed.connect(func() -> void:
		_n = n
		_rebuild())
	var art := Control.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(art)
	art.draw.connect(func() -> void:
		var font := ThemeDB.fallback_font
		var sz := 20
		var txt := str(n)
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var base := (TILE.y + font.get_ascent(sz) - font.get_descent(sz)) * 0.5
		art.draw_string(font, Vector2((TILE.x - w) * 0.5 + 1, base + 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, UiKit.SHADOW)
		art.draw_string(font, Vector2((TILE.x - w) * 0.5, base), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color("5a5468") if locked else UiKit.TEXT)
		if won:
			art.draw_string(font, Vector2(5, 4 + font.get_ascent(12)), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("8fd08a"))
		if boss:
			var tex := UiIcons.texture("skull")
			if tex != null:
				art.draw_texture_rect(tex, Rect2(TILE.x - 19, 4, 14, 14), false, Color(1, 1, 1, 0.35) if locked else Color.WHITE))
	return b


## The chosen stage: name and region, boss, time, difficulty against stage 1,
## monsters, rewards, wins.
func _detail(panel: PanelContainer, unlocked: int) -> void:
	var st := _stages.load_stage(_n)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var name := UiKit.label("Ải %d" % _n, 30, UiKit.TEXT)
	v.add_child(name)
	var sub := String(st.get("name", ""))
	if sub != String(st.get("region", "")):
		sub = "%s · %s" % [sub, String(st.get("region", ""))]
	var sl := UiKit.label(sub, 16, UiKit.GOLD)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sl)
	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 18)
	v.add_child(tags)
	var dur := int(st.get("duration", 300))
	tags.add_child(UiKit.stat("clock", "%02d:%02d" % [dur / 60, dur % 60], "Thời gian trụ", 16))
	if _stages.is_boss(_n):
		tags.add_child(UiKit.stat("skull", "BOSS", "Ải có boss: hạ boss là thắng", 16))
	if _n > unlocked:
		v.add_child(UiKit.label("Chưa mở: vượt ải %d trước." % (_n - 1), 15, Color("ff9a9a")))
	# difficulty against stage 1
	v.add_child(UiKit.label("Độ khó (so với ải 1)", 15, UiKit.MUTED))
	var diff := GridContainer.new()
	diff.columns = 2
	diff.add_theme_constant_override("h_separation", 24)
	diff.add_theme_constant_override("v_separation", 2)
	v.add_child(diff)
	for row in [["Máu quái", _stages.hp_mul(_n)], ["Sát thương quái", _stages.damage_mul(_n)], ["Mật độ quái", _stages.rate_mul(_n)]]:
		diff.add_child(UiKit.label(row[0], 15, UiKit.TEXT))
		var val := UiKit.label("×%.2f" % float(row[1]), 15, UiKit.TEXT)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		diff.add_child(val)
	# monsters in this stage
	v.add_child(UiKit.label("Quái xuất hiện", 15, UiKit.MUTED))
	var mons := HBoxContainer.new()
	mons.add_theme_constant_override("separation", 6)
	v.add_child(mons)
	var seen := []
	for w: Dictionary in st.get("waves", []):
		var id := String(w.get("monster", "")).get_slice("@", 0)
		if id != "" and not seen.has(id) and _monsters.has(id):
			seen.append(id)
			mons.add_child(_monster_box(id))
	# rewards and wins
	v.add_child(UiKit.label("Phần thưởng khi thắng", 15, UiKit.MUTED))
	var first := _stages.rewards(_n, true)
	var again := _stages.rewards(_n, false)
	var rw := HBoxContainer.new()
	rw.add_theme_constant_override("separation", 18)
	v.add_child(rw)
	var won_count := int(_slot.wins.get(str(_n), 0))
	rw.add_child(UiKit.stat("coin", str(int(first["gold"])), "Vàng mỗi lần thắng", 16))
	rw.add_child(UiKit.stat("gem", str(int(again["gems"] if won_count > 0 else first["gems"])),
		"Đá: lần đầu %d, các lần sau %d" % [int(first["gems"]), int(again["gems"])], 16))
	var note := "Đã vượt %d lần" % won_count if won_count > 0 else "Chưa vượt: lần đầu được %d đá" % int(first["gems"])
	v.add_child(UiKit.label(note, 14, UiKit.MUTED))


## A monster's first frame in a small box; the tooltip names it.
func _monster_box(id: String) -> Control:
	var m: Dictionary = _monsters[id]
	var sprite := String(m.get("sprite", id))
	if not _sheets.has(sprite):
		_sheets[sprite] = SpriteSheet.load_dir("res://assets/sprites/custom/" + sprite, sprite)
	var sheet: SpriteSheet = _sheets[sprite]
	var c := Control.new()
	c.custom_minimum_size = Vector2(56, 56)
	c.clip_contents = true
	Tip.attach(c, String(m.get("name", id)), "", UiKit.GOLD, "", "Quái vật")
	c.draw.connect(func() -> void:
		c.draw_rect(Rect2(Vector2.ZERO, c.size), UiKit.PANEL_DARK)
		if sheet == null:
			return
		# whole-number scale from the body radius, the body centred in the box
		var body := SpriteHitbox.body(sheet, Vector2.ZERO, 1.0)
		var r := body.radius if body != null else 8.0
		var k := clampf(floorf(18.0 / maxf(r, 1.0)), 1.0, 3.0)
		var off := body.center * k if body != null else Vector2(0, 8.0 * k)
		sheet.draw(c, sheet.animation_names()[0], 0.0, Vector2(28, 28) - off, k))
	return c


func _start() -> void:
	if _n > _slot.unlocked(_stages.count()):
		return
	Prefs.current().set_value("stage_target", _n)
	get_tree().change_scene_to_file(RUN_SCENE)
