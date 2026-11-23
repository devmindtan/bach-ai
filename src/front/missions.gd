extends Node2D
## Nhiệm vụ ngày screen (design/missions.md, design/ux/missions.md): today's
## missions as cards, top-down: name, task, a progress bar, the gem reward and a
## Nhận button when finished; a bonus row once all are claimed. Esc: lobby.
##
## Command line (after `--`), for shots: --missions-demo (some progress, one claimable).

const LOBBY_SCENE := "res://src/lobby/lobby.tscn"
const DONE := Color("8fe08a")

var _slot: Slot
var _d: Daily
var _layer: CanvasLayer
var _scroll := Vector2.ZERO


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


func _process(delta: float) -> void:
	_scroll += Vector2(18.0, 6.0) * delta
	queue_redraw()


func _draw() -> void:
	FrontArt.backdrop(self, _scroll, get_viewport_rect().size)


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
	var title := UiKit.label("Nhiệm vụ ngày · %s" % _slot.name, 34, UiKit.GOLD)
	title.position = Vector2(40, 24)
	root.add_child(title)
	var sub := UiKit.label("Làm mới lúc 0 giờ. Mỗi nhiệm vụ cho đá; nhận đủ cả %d thì thưởng thêm." % _slot.daily["ids"].size(), 16, UiKit.MUTED)
	sub.position = Vector2(42, 72)
	root.add_child(sub)
	var wallet := UiKit.stat("gem", "%d đá" % _slot.gems, "Đá: quay gacha.", 16)
	wallet.position = Vector2(root.size.x - 40 - 180 - 140, 36)
	root.add_child(wallet)
	var back := UiKit.button("Quay lại " + UiKit.hint("Esc"), func() -> void: get_tree().change_scene_to_file(LOBBY_SCENE), Vector2(180, 42), 17)
	back.position = Vector2(root.size.x - 40 - 180, 28)
	root.add_child(back)
	var list := VBoxContainer.new()
	list.position = Vector2(240, 108)
	list.custom_minimum_size = Vector2(800, 0)
	list.add_theme_constant_override("separation", 8)
	root.add_child(list)
	for id: String in _slot.daily["ids"]:
		list.add_child(_card(id))
	list.add_child(_bonus_card())
	var first := UiKit.first_enabled_button(list)   # gamepad: a claim button if any, else Quay lại (J5)
	(first if first != null else back).call_deferred("grab_focus")


func _card(id: String) -> PanelContainer:
	var m := _d.mission(id)
	var done := _d.done(_slot, id)
	var got := _d.claimed(_slot, id)
	var p := UiKit.panel(UiKit.PANEL_DARK if not done else Color(0.12, 0.16, 0.12), 14, DONE if done and not got else UiKit.GOLD)
	p.custom_minimum_size = Vector2(800, 88)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	p.add_child(row)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	row.add_child(v)
	v.add_child(UiKit.label(String(m.get("name", id)), 20, UiKit.TEXT))
	v.add_child(UiKit.label(String(m.get("desc", "")), 14, UiKit.MUTED))
	var bar := ProgressBar.new()
	bar.max_value = float(m.get("target", 1))
	bar.value = float(_d.progress(_slot, id))
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.add_theme_stylebox_override("background", UiKit.style(Color(0, 0, 0, 0.5), 0, Color("3a3448"), 1))
	bar.add_theme_stylebox_override("fill", UiKit.style(DONE if done else UiKit.GOLD, 0))
	v.add_child(bar)
	v.add_child(UiKit.label("%d / %d" % [_d.progress(_slot, id), int(m.get("target", 1))], 13, UiKit.MUTED))
	row.add_child(_reward(int(m.get("gems", 0))))
	var b := UiKit.button("Đã nhận" if got else ("Nhận" if done else "Chưa xong"), func() -> void:
		if _d.claim(_slot, id):
			Sfx.play("coin")
			_rebuild(), Vector2(140, 48), 17, UiKit.PRIMARY if done and not got else UiKit.PANEL)
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
	r.custom_minimum_size = Vector2(80, 0)
	return r
