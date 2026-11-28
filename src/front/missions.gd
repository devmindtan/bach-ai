extends Node2D
## Nhiệm vụ ngày screen (design/missions.md, design/ux/missions.md): today's
## missions as cards, top-down: name, task, a progress bar, the gem reward and a
## Nhận button when finished; a bonus row once all are claimed. Esc: lobby.
##
## Command line (after `--`), for shots: --missions-demo (some progress, one claimable).

const LOBBY_SCENE := "res://src/lobby/lobby.tscn"
const DONE := Color("2a7a3a")
const LEFT_PAGE := Rect2(110, 74, 470, 572)
const RIGHT_PAGE := Rect2(660, 74, 470, 572)

var _slot: Slot
var _d: Daily
var _layer: CanvasLayer


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
	_d = Daily.load_default()
	var date := "2026-11-18" if prefs.is_fixed() else ""   # shots: a fixed day, identical images
	var ids := _d.ensure(_slot, date)
	if OS.get_cmdline_user_args().has("--missions-demo"):
		for k in ids.size():
			var m := _d.mission(String(ids[k]))
			_d.add(_slot, String(m["stat"]), int(m["target"]) if k < 2 else int(m["target"]) / 2, date)
		_d.claim(_slot, String(ids[0]))
	_build()


func _draw() -> void:
	Journal.draw_desk(self, get_viewport_rect().size)
	Journal.draw_book(self, Journal.BOOK)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(LOBBY_SCENE)


func _rebuild() -> void:
	Prefs.current().save_profile()
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
	var hint := Journal.ink("↑ ↓ chọn · Enter nhận · Esc về sổ", 15, Journal.PAPER)
	hint.position = Vector2(Journal.BOOK.position.x, Journal.BOOK.end.y + 14)
	root.add_child(hint)
	# left page (web screen-missions-journal): today's tasks as rows: a tick box, name, task, a thin bar, progress · gems
	var list := VBoxContainer.new()
	list.position = LEFT_PAGE.position + Vector2(0, -8)
	list.custom_minimum_size = Vector2(LEFT_PAGE.size.x, 0)
	list.add_theme_constant_override("separation", 0)
	root.add_child(list)
	list.add_child(Journal.ink("Nhiệm vụ", 44))
	var sub := Journal.ink("Việc trong ngày · đổi lúc nửa đêm", 20, Journal.INK_RED)
	list.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	list.add_child(gap)
	var first: Button = null
	for id: String in _slot.daily["ids"]:
		var row := _row(id)
		list.add_child(row)
		if first == null:
			first = row
	# right page "Phần thưởng": each task's gems once done, the completion bonus, what waits to be claimed
	var right := VBoxContainer.new()
	right.position = RIGHT_PAGE.position + Vector2(0, -8)
	right.custom_minimum_size = Vector2(RIGHT_PAGE.size.x, 0)
	right.add_theme_constant_override("separation", 0)
	root.add_child(right)
	var h2 := Journal.ink("Phần thưởng", 32)
	var under := StyleBoxFlat.new()
	under.bg_color = Color(0, 0, 0, 0)
	under.border_color = Journal.INK
	under.border_width_bottom = 3
	h2.add_theme_stylebox_override("normal", under)
	right.add_child(h2)
	var ids: Array = _slot.daily["ids"]
	var waiting := 0
	for id: String in ids:
		var m := _d.mission(id)
		var done := _d.done(_slot, id)
		right.add_child(Journal.ledger("", String(m.get("name", id)), ("+%d đá" % int(m.get("gems", 0))) if done else "—", 20))
		if done and not _d.claimed(_slot, id):
			waiting += int(m.get("gems", 0))
	var bonus_got := bool(_slot.daily.get("bonus", false))
	right.add_child(Journal.ledger("", "Xong cả %d việc" % ids.size(), "+%d đá" % int(_d.data.get("bonus_gems", 0)), 20))
	if _d.bonus_ready(_slot) and not bonus_got:
		waiting += int(_d.data.get("bonus_gems", 0))
	var wl := Journal.ink("Đang chờ nhận: %d đá" % waiting, 20, Journal.INK_SOFT)
	right.add_child(wl)
	var seal := Journal.seal("Nhận thưởng ▶", Vector2(260, 62), 26)
	seal.position = RIGHT_PAGE.end - Vector2(260, 62)
	seal.focus_mode = Control.FOCUS_NONE
	seal.disabled = waiting == 0
	seal.set_meta("sfx", "")
	seal.pressed.connect(func() -> void:   # claims every finished task and, once all are claimed, the bonus
		var gems0 := _slot.gems
		var any := false
		for id: String in ids:
			any = _d.claim(_slot, id) or any
		if _d.claim_bonus(_slot):
			any = true
		if any:
			Sfx.play("chest")
			Notice.note("Đã nhận thưởng", "+%d đá · còn %d" % [_slot.gems - gems0, _slot.gems], UiIcons.texture("gem"))
			_rebuild())
	root.add_child(seal)
	if first != null:
		first.call_deferred("grab_focus")


## A task row (web .task): ink when focused; Enter / a click claims it once finished.
func _row(id: String) -> Button:
	var m := _d.mission(id)
	var done := _d.done(_slot, id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(LEFT_PAGE.size.x, 84)
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.border_color = Journal.DOTS
	flat.border_width_bottom = 2
	var inked := StyleBoxFlat.new()
	inked.bg_color = Journal.INK
	b.add_theme_stylebox_override("normal", flat)
	for st in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(st, inked)
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10
	h.offset_right = -10
	h.offset_top = 8
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var box := Control.new()   # the tick box (green tick once done)
	box.custom_minimum_size = Vector2(28, 28)
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var name := Journal.ink(String(m.get("name", id)), 26)
	v.add_child(name)
	var desc := Journal.ink(String(m.get("desc", "")), 18, Journal.INK_SOFT)
	v.add_child(desc)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(220, 12)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bar)
	var target := int(m.get("target", 1))
	var prog := mini(_d.progress(_slot, id), target)
	var gems := Journal.ink("%d/%d · %d đá" % [prog, target, int(m.get("gems", 0))], 22)
	gems.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(gems)
	var paint := func() -> void:
		var on := b.has_focus()
		var ink := Journal.PAPER if on else Journal.INK
		name.add_theme_color_override("font_color", ink)
		gems.add_theme_color_override("font_color", ink)
		desc.add_theme_color_override("font_color", Journal.GOLD if on else Journal.INK_SOFT)
		box.queue_redraw()
		bar.queue_redraw()
	box.draw.connect(func() -> void:
		box.draw_rect(Rect2(1.5, 1.5, 25, 25), Journal.GOLD if b.has_focus() else Journal.INK, false, 3.0)
		if done:
			box.draw_string(ThemeDB.fallback_font, Vector2(1, 26), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("2a7a3a")))
	bar.draw.connect(func() -> void:
		var c := Journal.PAPER if b.has_focus() else Journal.INK
		bar.draw_rect(Rect2(1, 1, 218, 10), c, false, 2.0)
		bar.draw_rect(Rect2(2, 2, 216.0 * float(prog) / maxf(1.0, target), 8), Journal.INK_RED))
	b.focus_entered.connect(paint)
	b.focus_exited.connect(paint)
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	b.pressed.connect(func() -> void:
		var gems0 := _slot.gems
		if _d.claim(_slot, id):
			Sfx.play("coin")
			Notice.note("Đã nhận thưởng", "+%d đá · còn %d" % [_slot.gems - gems0, _slot.gems], UiIcons.texture("gem"))
			_rebuild())
	paint.call()
	return b


