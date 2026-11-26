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
	var list := VBoxContainer.new()   # left page: today's tasks
	list.position = LEFT_PAGE.position + Vector2(0, -8)
	list.custom_minimum_size = Vector2(LEFT_PAGE.size.x, 0)
	list.add_theme_constant_override("separation", 8)
	root.add_child(list)
	list.add_child(Journal.ink("Nhiệm vụ", 44))
	list.add_child(Journal.ink("Việc trong ngày · làm mới lúc 0 giờ", 18, Journal.INK_RED))
	for id: String in _slot.daily["ids"]:
		list.add_child(_card(id))
	Journal.restyle(list)
	# right page: the rewards: gems, how many claimed, the completion bonus (the seal)
	var right := VBoxContainer.new()
	right.position = RIGHT_PAGE.position + Vector2(0, -8)
	right.custom_minimum_size = Vector2(RIGHT_PAGE.size.x, 0)
	right.add_theme_constant_override("separation", 6)
	root.add_child(right)
	right.add_child(Journal.ink("Phần thưởng", 40))
	var ids: Array = _slot.daily["ids"]
	var claimed := ids.filter(func(id: String) -> bool: return _d.claimed(_slot, id)).size()
	var total := 0
	for id: String in ids:
		total += int(_d.mission(id).get("gems", 0))
	right.add_child(Journal.ledger("gem", "Đá đang có", str(_slot.gems), 22))
	right.add_child(Journal.ledger("", "Đã nhận", "%d / %d nhiệm vụ" % [claimed, ids.size()], 22))
	right.add_child(Journal.ledger("", "Đá từ nhiệm vụ hôm nay", "%d" % total, 22))
	right.add_child(Journal.ledger("", "Thưởng hoàn thành", "+%d đá" % int(_d.data.get("bonus_gems", 0)), 22, Journal.INK_RED))
	var note := Journal.ink("Nhận đủ mọi nhiệm vụ hôm nay thì được thêm đá.", 18, Journal.INK_SOFT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(RIGHT_PAGE.size.x, 0)
	right.add_child(note)
	var ready := _d.bonus_ready(_slot)
	var got := bool(_slot.daily.get("bonus", false))
	var bonus := Journal.seal("Đã nhận" if got else "Nhận thưởng ▶", Vector2(260, 62), 24)
	bonus.position = RIGHT_PAGE.end - Vector2(260, 62)
	bonus.disabled = not ready
	bonus.set_meta("sfx", "")
	bonus.pressed.connect(func() -> void:
		if _d.claim_bonus(_slot):
			Sfx.play("chest")
			_rebuild())
	root.add_child(bonus)
	var first := UiKit.first_enabled_button(list)   # gamepad: a claim button if any, else the bonus (J5)
	(first if first != null else bonus).call_deferred("grab_focus")


func _card(id: String) -> PanelContainer:
	var m := _d.mission(id)
	var done := _d.done(_slot, id)
	var got := _d.claimed(_slot, id)
	var p := UiKit.panel(UiKit.PANEL_DARK if not done else Color(0.12, 0.16, 0.12), 10, DONE if done and not got else UiKit.GOLD)
	p.custom_minimum_size = Vector2(LEFT_PAGE.size.x, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	p.add_child(row)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	row.add_child(v)
	v.add_child(UiKit.label(String(m.get("name", id)), 20, UiKit.TEXT))
	var dl := UiKit.label("%s  ·  %d / %d" % [String(m.get("desc", "")), _d.progress(_slot, id), int(m.get("target", 1))], 15, UiKit.MUTED)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(dl)
	var bar := ProgressBar.new()
	bar.max_value = float(m.get("target", 1))
	bar.value = float(_d.progress(_slot, id))
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.add_theme_stylebox_override("background", UiKit.style(Journal.PAPER, 0, Journal.INK, 2))   # an ink bar on paper
	bar.add_theme_stylebox_override("fill", UiKit.style(DONE if done else Journal.INK_RED, 0))
	v.add_child(bar)
	row.add_child(_reward(int(m.get("gems", 0))))
	var b := UiKit.button("Đã nhận" if got else ("Nhận" if done else "Chưa xong"), func() -> void:
		if _d.claim(_slot, id):
			Sfx.play("coin")
			_rebuild(), Vector2(104, 44), 17, UiKit.PRIMARY if done and not got else UiKit.PANEL)
	b.disabled = got or not done
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if done and not got:
		b.set_meta("sfx", "")
	row.add_child(b)
	return p


func _bonus_card() -> PanelContainer:
	var ready := _d.bonus_ready(_slot)
	var got := bool(_slot.daily.get("bonus", false))
	var p := UiKit.panel(Color(0.16, 0.12, 0.06) if ready else UiKit.PANEL_DARK, 14, UiKit.RARITY["legendary"])
	p.custom_minimum_size = Vector2(800, 64)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	p.add_child(row)
	var l := UiKit.label("Thưởng hoàn thành: nhận đủ mọi nhiệm vụ hôm nay", 18, UiKit.RARITY["legendary"])
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	row.add_child(_reward(int(_d.data.get("bonus_gems", 0))))
	var b := UiKit.button("Đã nhận" if got else "Nhận thưởng", func() -> void:
		if _d.claim_bonus(_slot):
			Sfx.play("chest")
			_rebuild(), Vector2(140, 48), 17, UiKit.PRIMARY if ready else UiKit.PANEL)
	b.disabled = not ready
	b.set_meta("sfx", "")
	row.add_child(b)
	return p


func _reward(gems: int) -> HBoxContainer:
	var r := UiKit.stat("gem", "+%d" % gems, "Đá thưởng", 18)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.custom_minimum_size = Vector2(64, 0)
	return r
