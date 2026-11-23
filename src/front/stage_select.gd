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
const BOSS_GOLD := Color("f2c14e")
const TILE_LOCKED := Color("15121e")
const TILE_CLEARED := Color("1f3a26")

var _stages: Stages
var _monsters := {}
var _sheets := {}
var _slot: Slot
var _n := 1
var _mode := "campaign"   # "campaign" or "trials" (design/challenge.md)
var _ch := ""             # the challenge shown in trials mode
var _challenges: Challenges
var _scroll := Vector2.ZERO
var _layer: CanvasLayer
var _detail_layer: CanvasLayer   # the Chi tiết overlay (design/ux/stage-detail.md), null when closed
var _run_cfg := {}
var _species := {}   # species.json (design/species.md): the detail table names each monster's species


func _ready() -> void:
	Sfx.music("menu")
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
	_run_cfg = GameData.load_json("res://assets/data/run_config.json")
	_species = GameData.load_json("res://assets/data/species.json")
	_n = clampi(prefs.stage_target, 1, _slot.unlocked(_stages.count()))
	_challenges = Challenges.load_default()
	if prefs.challenge_target != "" and _challenges.mode_open(_slot):
		_mode = "trials"
		_ch = prefs.challenge_target
	for a in OS.get_cmdline_user_args():
		if a == "--trials":   # shots of the challenge mode
			_mode = "trials"
	if _ch == "":
		_ch = _challenges.ids()[0]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stage-pick="):
			_n = clampi(int(a.get_slice("=", 1)), 1, _stages.count())
	_build()
	if OS.get_cmdline_user_args().has("--stage-detail"):   # shots of the Chi tiết overlay
		_open_detail()


func _process(delta: float) -> void:
	_scroll += Vector2(18.0, 6.0) * delta
	queue_redraw()


func _draw() -> void:
	FrontArt.backdrop(self, _scroll, get_viewport_rect().size, _stages.ground(_n) if _stages != null else {})


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _detail_layer != null:
		_close_detail()
		get_viewport().set_input_as_handled()
		return
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
	var title := UiKit.label("Chọn ải" if _mode == "campaign" else "Thử thách", 34, UiKit.GOLD)
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
	modes.add_child(_mode_button("Vượt ải", "30 ải, mở dần", true, _mode == "campaign", func() -> void:
		_mode = "campaign"
		_rebuild()))
	var t_open := _challenges.mode_open(_slot)
	modes.add_child(_mode_button("Thử thách", ("%d thử thách" % _challenges.ids().size()) if t_open else "Mở khi vượt ải %d" % _challenges.mode_unlock(),
		t_open, _mode == "trials", func() -> void:
		_mode = "trials"
		_rebuild()))
	modes.add_child(_mode_button("Vô tận", "Sắp có", false, false, func() -> void: pass))
	if _mode == "trials":
		_build_trials(root)
		return

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
	for line in ["Ải thường: trụ hết giờ để vượt. Ải boss: boss ra ở phút 5, hạ boss mới thắng.",
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
	var info_id := info.get_instance_id()   # by id: a rebuild may free info first (a freed capture prints an error)
	(func() -> void:
		var inf := instance_from_id(info_id) as Control
		if inf != null:
			inf.position.y = 604.0 - inf.size.y).call_deferred()

	# right: the chosen stage, then the main action under it
	var panel := UiKit.panel(Color(0.09, 0.08, 0.13, 0.96), 18)
	panel.position = Vector2(root.size.x - 40 - 330, 104)
	panel.custom_minimum_size = Vector2(330, 500)
	panel.size = Vector2(330, 500)
	root.add_child(panel)
	_detail(panel, unlocked)
	var start := UiKit.button("Bắt đầu  ▶", func() -> void: _start(), Vector2(330, 64), 26, UiKit.PRIMARY)
	start.set_meta("sfx", "")   # ui_start instead of a click
	start.position = Vector2(root.size.x - 40 - 330, 616)
	start.disabled = _n > unlocked
	root.add_child(start)
	if not start.disabled:
		start.call_deferred("grab_focus")
	elif chosen_tile != null:
		chosen_tile.call_deferred("grab_focus")


func _mode_button(name: String, line: String, open: bool, on: bool, cb: Callable) -> Button:
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
	b.pressed.connect(cb)
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
	var mh := HBoxContainer.new()
	var ml := UiKit.label("Quái xuất hiện", 15, UiKit.MUTED)
	ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ml.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mh.add_child(ml)
	mh.add_child(UiKit.button("Chi tiết", _open_detail, Vector2(96, 30), 15))   # design/ux/stage-detail.md
	v.add_child(mh)
	v.add_child(_monster_row(st))
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
## The stage's monsters, one box each, at most MONSTER_ROW boxes: more show the first ones and a "+k" box
## (user 2026-11-22: a sixth monster spilled past the panel edge); the "+k" tip names the rest.
const MONSTER_ROW := 5


func _monster_row(st: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var ids := stage_monsters(st, _monsters)
	var shown := ids if ids.size() <= MONSTER_ROW else ids.slice(0, MONSTER_ROW - 1)
	for id: String in shown:
		row.add_child(_monster_box(id))
	if ids.size() > shown.size():
		var rest := ids.slice(shown.size())
		var more := UiKit.panel(UiKit.PANEL_DARK, 4)
		more.custom_minimum_size = Vector2(44, 44)
		var l := UiKit.label("+%d" % rest.size(), 16, UiKit.GOLD)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		more.add_child(l)
		Tip.attach(more, "Còn %d loại quái" % rest.size(), ", ".join(rest.map(func(id: String) -> String: return String(_monsters[id].get("name", id)))), UiKit.GOLD, "", "Quái vật")
		row.add_child(more)
	return row


## Monster ids of a stage's waves, in order of first appearance, known ones only.
static func stage_monsters(st: Dictionary, monsters: Dictionary) -> Array:
	var seen := []
	for w: Dictionary in st.get("waves", []):
		var id := String(w.get("monster", "")).get_slice("@", 0)
		if id != "" and not seen.has(id) and monsters.has(id):
			seen.append(id)
	return seen


func _monster_box(id: String) -> Control:
	var m: Dictionary = _monsters[id]
	var sprite := String(m.get("sprite", id))
	if not _sheets.has(sprite):
		_sheets[sprite] = SpriteSheet.load_dir("res://assets/sprites/custom/" + sprite, sprite)
	var sheet: SpriteSheet = _sheets[sprite]
	var c := Control.new()
	c.custom_minimum_size = Vector2(44, 44)   # six to a row: more wrapped under the Bắt đầu button
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
	Prefs.current().challenge_target = ""
	Prefs.current().set_value("stage_target", _n)
	Sfx.play("ui_start")
	get_tree().change_scene_to_file(RUN_SCENE)


# --- challenge mode (design/challenge.md) ------------------------------------------

## The challenges as cards in the middle, the chosen one on the right, then Bắt đầu.
func _build_trials(root: Control) -> void:
	var col := VBoxContainer.new()
	col.position = Vector2(284, 104)
	col.add_theme_constant_override("separation", 10)
	root.add_child(col)
	col.add_child(UiKit.label("Luật riêng, cày lại được; thắng nhận Tẩy Tủy Đan để đặt lại cây kỹ năng.", 15, UiKit.MUTED))
	var chosen: Button = null
	for id in _challenges.ids():
		var card := _challenge_card(id)
		col.add_child(card)
		if id == _ch:
			chosen = card
	# what the pills are for, under the cards (bottom lined up with the detail column)
	var info := UiKit.panel(Color(0.09, 0.08, 0.13, 0.9), 16)
	info.position = Vector2(284, 520)
	info.custom_minimum_size = Vector2(614, 84)
	info.size = info.custom_minimum_size
	root.add_child(info)
	var ih := HBoxContainer.new()
	ih.add_theme_constant_override("separation", 14)
	info.add_child(ih)
	ih.add_child(UiKit.icon("pill", 40.0))
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 2)
	ih.add_child(iv)
	iv.add_child(UiKit.label("Đang có %d Tẩy Tủy Đan" % _slot.pills, 18, UiKit.TEXT))
	iv.add_child(UiKit.label("Dùng ở Cây kỹ năng: 1 viên + vàng để đặt lại cây, hoàn đủ Tinh hoa.", 14, UiKit.MUTED))
	var panel := UiKit.panel(Color(0.09, 0.08, 0.13, 0.96), 18)
	panel.position = Vector2(root.size.x - 40 - 330, 104)
	panel.custom_minimum_size = Vector2(330, 500)
	panel.size = Vector2(330, 500)
	root.add_child(panel)
	_challenge_detail(panel)
	var start := UiKit.button("Bắt đầu  ▶", func() -> void:
		Prefs.current().challenge_target = _ch
		Sfx.play("ui_start")
		get_tree().change_scene_to_file(RUN_SCENE), Vector2(330, 64), 26, UiKit.PRIMARY)
	start.set_meta("sfx", "")   # ui_start instead of a click
	start.position = Vector2(root.size.x - 40 - 330, 616)
	start.disabled = not _challenges.is_open(_slot, _ch)
	root.add_child(start)
	if not start.disabled:
		start.call_deferred("grab_focus")
	elif chosen != null:
		chosen.call_deferred("grab_focus")


func _challenge_card(id: String) -> Button:
	var c := _challenges.get_def(id)
	var open := _challenges.is_open(_slot, id)
	var on := id == _ch
	var wins := int(_slot.challenge_wins.get(id, 0))
	var b := Button.new()
	b.custom_minimum_size = Vector2(614, 112)
	b.focus_mode = Control.FOCUS_ALL
	var border := Color.WHITE if on else (UiKit.GOLD if open else Color("3a3448"))
	b.add_theme_stylebox_override("normal", UiKit.style(UiKit.PANEL if open else TILE_LOCKED, 12, border, 3 if on else 2))
	b.add_theme_stylebox_override("disabled", UiKit.style(TILE_LOCKED, 12, border, 2))
	for st in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(st, UiKit.style(UiKit.PANEL_HOVER, 12, Color.WHITE, 3))
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 14
	h.offset_right = -14
	h.offset_top = 12
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var box := UiKit.panel(UiKit.PANEL_DARK, 4, UiKit.GOLD if open else Color("3a3448"))
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UiKit.icon("pill", 40.0)
	ic.modulate = Color.WHITE if open else Color(1, 1, 1, 0.35)
	box.add_child(ic)
	h.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	var nm := UiKit.label(String(c.get("name", id)), 21, UiKit.TEXT if open else Color("6a6478"))
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(nm)
	var right := ("Đã thắng %d lần" % wins) if wins > 0 else ("Chưa thắng" if open else "Mở khi vượt ải %d" % int(c.get("unlock", 0)))
	var rl := UiKit.label(right, 14, Color("8fd08a") if wins > 0 else UiKit.MUTED)
	rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(rl)
	var dl := UiKit.label(String(c.get("desc", "")), 15, UiKit.TEXT if open else Color("6a6478"))
	dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(dl)
	var dur := int(c.get("duration", 300))
	var ml := UiKit.label("Dựa trên ải %d  ·  %d phút  ·  Tẩy Tủy Đan +%d lần đầu, +%d các lần sau" % [
		int(c.get("base", 1)), dur / 60, int(_challenges.data.get("pills_first", 2)), int(_challenges.data.get("pills", 1))], 13, UiKit.MUTED)
	ml.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(ml)
	b.disabled = not open
	b.pressed.connect(func() -> void:
		_ch = id
		_rebuild())
	return b


func _challenge_detail(panel: PanelContainer) -> void:
	var c := _challenges.get_def(_ch)
	var st := _challenges.build(_ch)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(UiKit.label(String(c.get("name", _ch)), 30, UiKit.TEXT))
	var sl := UiKit.label("Dựa trên ải %d · %s" % [int(c.get("base", 1)), String(st.get("region", ""))], 16, UiKit.GOLD)
	v.add_child(sl)
	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 18)
	v.add_child(tags)
	var dur := int(st.get("duration", 180))
	tags.add_child(UiKit.stat("clock", "%02d:%02d" % [dur / 60, dur % 60], "Thời gian trụ", 16))
	if bool(st.get("boss", false)):
		tags.add_child(UiKit.stat("skull", "BOSS", "Có boss; trụ tới hết giờ" if not bool(st.get("win_on_boss", true)) else "Hạ boss là thắng", 16))
	if not _challenges.is_open(_slot, _ch):
		v.add_child(UiKit.label("Chưa mở: vượt ải %d trước." % int(c.get("unlock", 0)), 15, Color("ff9a9a")))
	var d := UiKit.label(String(c.get("desc", "")), 15, UiKit.TEXT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	v.add_child(UiKit.label("Độ khó (so với ải 1)", 15, UiKit.MUTED))
	var base := int(c.get("base", 1))
	var diff := GridContainer.new()
	diff.columns = 2
	diff.add_theme_constant_override("h_separation", 24)
	v.add_child(diff)
	for row in [["Máu quái", _stages.hp_mul(base) * float(st.get("hp_mul", 1.0))], ["Sát thương quái", _stages.damage_mul(base)]]:
		diff.add_child(UiKit.label(row[0], 15, UiKit.TEXT))
		var val := UiKit.label("×%.2f" % float(row[1]), 15, UiKit.TEXT)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		diff.add_child(val)
	v.add_child(UiKit.label("Quái xuất hiện", 15, UiKit.MUTED))
	v.add_child(_monster_row(st))
	v.add_child(UiKit.label("Phần thưởng khi thắng", 15, UiKit.MUTED))
	var rw := HBoxContainer.new()
	rw.add_theme_constant_override("separation", 18)
	v.add_child(rw)
	var first := int(_slot.challenge_wins.get(_ch, 0)) == 0
	rw.add_child(UiKit.stat("pill", "+%d" % (int(_challenges.data.get("pills_first", 2)) if first else int(_challenges.data.get("pills", 1))), "Tẩy Tủy Đan", 16))
	rw.add_child(UiKit.stat("coin", "+%d" % int(_stages.rewards(base, false)["gold"]), "Vàng", 16))



# --- Chi tiết: the stage's monsters, time marks and rewards (design/ux/stage-detail.md, roadmap D2) ---

const EVENT_NAMES := {"ring": "Vòng thử thách", "collect": "Thu thập sao", "hunt": "Săn tinh anh",
	"tornado": "Lốc xoáy", "falling_trees": "Cây đổ", "poison_tide": "Triều độc"}


## The stage's monsters for the detail table: [{id, name, hp, damage, speed, elite, boss}], hp and damage
## scaled by the stage ([param hp_mul], [param dmg_mul]), in order of first appearance.
static func detail_monsters(st: Dictionary, monsters: Dictionary, hp_mul: float, dmg_mul: float) -> Array:
	var out := []
	var elites := []
	for w: Dictionary in st.get("waves", []):
		var raw := String(w.get("monster", ""))
		if raw.get_slice("@", 1) == "elite":
			elites.append(raw.get_slice("@", 0))
	for id: String in stage_monsters(st, monsters):
		var m: Dictionary = monsters[id]
		out.append({"id": id, "name": String(m.get("name", id)), "hp": float(m.get("hp", 0)) * hp_mul,
			"damage": float(m.get("damage", 0)) * dmg_mul, "speed": float(m.get("speed", 0)),
			"elite": elites.has(id), "boss": bool(m.get("boss", false))})
	return out


## Time marks of the stage, sorted by time: [[seconds, text]]: a monster's first appearance, elite bursts,
## the boss, and the region's events (from stage [param min_stage]; [param cfg_events] enabled false skips).
static func detail_timeline(st: Dictionary, monsters: Dictionary, region_events: Array, n: int, min_stage: int, cfg_events: Dictionary) -> Array:
	var marks := []
	var seen := []
	for w: Dictionary in st.get("waves", []):
		var raw := String(w.get("monster", ""))
		var id := raw.get_slice("@", 0)
		if not monsters.has(id):
			continue
		var t := float(w.get("t_from", 0))
		var nm := String(monsters[id].get("name", id))
		if bool(monsters[id].get("boss", false)):
			marks.append([t, "BOSS: " + nm])
		elif raw.get_slice("@", 1) == "elite":
			marks.append([t, "%d %s tinh anh" % [int(w.get("burst", 1)), nm]])
		elif not seen.has(id):
			seen.append(id)
			if t > 0.0:
				marks.append([t, nm + " bắt đầu xuất hiện"])
	if n >= min_stage:
		for ev: Dictionary in region_events:
			var kind := String(ev.get("kind", ""))
			if not bool(cfg_events.get(kind, {}).get("enabled", true)):
				continue
			marks.append([float(ev.get("t", 0)), "Sự kiện: " + String(EVENT_NAMES.get(kind, kind))])
	marks.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return marks


## "Nhầy · yếu Lửa · kháng Vật lý" for species [param sid] (design/species.md), "" without one.
static func species_line(sid: String, table: Dictionary) -> String:
	var sp: Dictionary = table.get("species", {}).get(sid, {})
	if sp.is_empty():
		return ""
	var names: Dictionary = table.get("elements", {})
	var parts := [String(sp.get("name", sid))]
	if not sp.get("weak", []).is_empty():
		parts.append("yếu " + ", ".join(sp["weak"].map(func(e: String) -> String: return String(names.get(e, e)))))
	if not sp.get("resist", []).is_empty():
		parts.append("kháng " + ", ".join(sp["resist"].map(func(e: String) -> String: return String(names.get(e, e)))))
	return " · ".join(parts)


func _open_detail() -> void:
	if _detail_layer != null:
		return
	var st := _stages.load_stage(_n)
	_detail_layer = CanvasLayer.new()
	_detail_layer.layer = 5
	add_child(_detail_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_detail_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_detail_layer.add_child(center)
	var panel := UiKit.panel(UiKit.PANEL, 20)
	panel.custom_minimum_size = Vector2(980, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var head := HBoxContainer.new()
	var title := UiKit.label("Ải %d · %s" % [_n, String(st.get("name", ""))], 26, UiKit.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := UiKit.button("Đóng (Esc)", _close_detail, Vector2(120, 36), 16)
	head.add_child(close)
	close.call_deferred("grab_focus")   # gamepad: A closes it (J5)
	v.add_child(head)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	v.add_child(cols)
	# left: the monsters
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.custom_minimum_size = Vector2(520, 0)
	cols.add_child(left)
	left.add_child(UiKit.label("Quái của ải (đã tính độ khó)", 15, UiKit.MUTED))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 4)
	left.add_child(grid)
	for h in ["", "Tên", "Máu", "Sát thương", "Tốc độ"]:
		grid.add_child(UiKit.label(h, 14, UiKit.MUTED))
	for m: Dictionary in detail_monsters(st, _monsters, _stages.hp_mul(_n), _stages.damage_mul(_n)):
		grid.add_child(_monster_box(String(m["id"])))
		var nm := String(m["name"]) + ("  · BOSS" if m["boss"] else ("  · có tinh anh" if m["elite"] else ""))
		var nv := VBoxContainer.new()
		nv.add_theme_constant_override("separation", 0)
		nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nv.add_child(UiKit.label(nm, 15, BOSS_GOLD if m["boss"] else (UiKit.GOLD if m["elite"] else UiKit.TEXT)))
		nv.add_child(UiKit.label(species_line(String(_monsters[m["id"]].get("species", "")), _species), 13, UiKit.MUTED))
		grid.add_child(nv)
		for x in [roundi(m["hp"]), roundi(m["damage"]), roundi(m["speed"])]:
			var l := UiKit.label(str(x), 15, UiKit.TEXT)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			grid.add_child(l)
	# right: time marks and rewards
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var dur := int(st.get("duration", 300))
	right.add_child(UiKit.label("Mốc thời gian (trận %02d:%02d)" % [dur / 60, dur % 60], 15, UiKit.MUTED))
	var ev_cfg: Dictionary = _run_cfg.get("events", {})
	for mk: Array in detail_timeline(st, _monsters, _stages.region(_n).get("events", []), _n, int(ev_cfg.get("min_stage", 0)), ev_cfg):
		var t := int(mk[0])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var tl := UiKit.label("%02d:%02d" % [t / 60, t % 60], 15, UiKit.MUTED)
		tl.custom_minimum_size = Vector2(52, 0)
		row.add_child(tl)
		var txt := String(mk[1])
		var col := BOSS_GOLD if txt.begins_with("BOSS") else (Color("8fd0ff") if txt.begins_with("Sự kiện") else (UiKit.GOLD if txt.contains("tinh anh") else UiKit.TEXT))
		var xl := UiKit.label(txt, 15, col)
		xl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		xl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(xl)
		right.add_child(row)
	right.add_child(UiKit.label("Phần thưởng khi thắng", 15, UiKit.MUTED))
	var first := _stages.rewards(_n, true)
	var again := _stages.rewards(_n, false)
	right.add_child(UiKit.label("Vàng %d · Đá lần đầu %d · Đá các lần sau %d" % [int(first["gold"]), int(first["gems"]), int(again["gems"])], 15, UiKit.TEXT))


func _close_detail() -> void:
	if _detail_layer != null:
		_detail_layer.queue_free()
		_detail_layer = null
