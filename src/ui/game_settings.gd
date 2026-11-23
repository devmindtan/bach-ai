class_name Prefs
extends Node
## Player settings (autoload "GameSettings"; reach it with Prefs.current()), saved in user://settings.cfg and
## applied at start: fullscreen, display scale, damage numbers, monster hp bars.
##
## The game draws 1:1 with the screen and only scales by whole numbers
## (project stretch mode "disabled" + Window.content_scale_factor), so pixel art
## and text stay sharp on any window size. A fractional canvas scale (a 1280x720
## window shrunk to 1237x696 by the window manager) blurred text and pixels.
##
## Example:
##   if Prefs.current().damage_numbers: draw_numbers()
##   Prefs.current().set_value("fullscreen", true)

signal changed

const PATH := "user://settings.cfg"
const TOUCH_NAMES := ["Nổi", "Cố định", "Tắt"]   # Cần điều khiển (J4)
const BASE := Vector2i(1280, 720)   # the design size; auto scale = how many whole times it fits

static func _volume_default(bus: String, fallback: int) -> int:
	return int(GameData.load_json("res://assets/data/audio.json").get("volume", {}).get(bus, fallback))


## Paths are variables so headless tests can point them at a temporary folder.
var settings_path := PATH

var fullscreen := false
var scale := 0                      # 0 = auto, else 1..3
var damage_numbers := true
var monster_hp := true
var screen_shake := true   # Rung màn hình (6C.2)
var preview_best := 10             # --preview-best=N: stages the preview slot has won
var touch_stick := 0       # Cần điều khiển (J4): 0 Nổi, 1 Cố định, 2 Tắt
var vfx := 0               # Hiệu ứng: 0 Đầy đủ, 1 Giảm, 2 Tối thiểu (review 2026-11-21: visual clutter late game)
const VFX_NAMES := ["Đầy đủ", "Giảm", "Tối thiểu"]
const VFX_ALPHA := [1.0, 0.7, 0.4]
var music_volume := _volume_default("music", 60)   # 0..100 %, Music bus (design/audio.md)
var sfx_volume := _volume_default("sfx", 80)       # 0..100 %, SFX bus
var hero := "knight"                # the class chosen in the lobby (classes.json id)
var slot_id := ""                   # the selected character slot ("" = legacy profile)
var stage_target := 1               # the stage the lobby will start
var card_target := ""               # the card the card-tree screen opens (design/ux/card-tree.md)
var endless_target := false        # the stage screen chose Vô tận (design/endless.md)
var challenge_target := ""          # a challenge chosen on the stage screen (design/challenge.md); "" = a stage
var _fixed := false
var _profile: Profile                 # screenshots / tests: defaults, never touch the window
var _store: SlotStore                 # character slots (user://slots, phase 3)
var active_slot: Slot                 # the slot in play; null in fixed/test mode unless set
var _ensuring_slots := false          # guards select_slot <-> ensure_slots recursion
var _force_slots := false             # --force-slots: in-memory slot for shots of slot mode

static var _default: Prefs


## The autoload when the game runs; a default instance where autoloads are not
## registered (the headless test runner), so callers never need a null check.
static func current() -> Prefs:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null and tree.root.has_node("GameSettings"):
		return tree.root.get_node("GameSettings")
	if _default == null:
		_default = Prefs.new()
		_default._fixed = true
	return _default


func _ready() -> void:
	UiFonts.install()   # bundled glyph fallbacks, before any screen draws text
	var forced_hero := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--gk-"):
			_fixed = true
		elif a == "--force-slots":
			_force_slots = true
		elif a.begins_with("--class="):   # shots / tests: play this class
			forced_hero = a.get_slice("=", 1)
		elif a.begins_with("--preview-best="):   # shots: the preview slot has won stages 1..N (0 = new player)
			preview_best = maxi(0, int(a.get_slice("=", 1)))
		elif a.begins_with("--touch-stick="):   # shots: Cần điều khiển mode (J4)
			touch_stick = clampi(int(a.get_slice("=", 1)), 0, 2)
		elif a == "--pad-hints":   # shots: button hints as with a gamepad connected (J5)
			UiKit.pad_override = 1
	if DisplayServer.get_name() == "headless":
		_fixed = true
	if not _fixed:
		_load()
	if forced_hero != "":
		hero = forced_hero
	if _fixed and _force_slots:
		_make_preview_slot()
	apply()
	get_tree().root.size_changed.connect(_fit_scale)


## Fixed mode (shots, tests): makes the preview character active when none is.
func ensure_preview_slot() -> void:
	if active_slot == null:
		_make_preview_slot()


## An in-memory slot for shots of slot mode (never saved: fixed mode blocks writes).
func _make_preview_slot() -> void:
	var s := SlotStore.new_slot("Nhân vật 1", hero, slot_store().defs)
	s.id = "slot1"
	# progress as record_win leaves it after winning stages 1-10 (stage 10 twice)
	var st := Stages.load_default()
	for n in range(1, preview_best + 1):
		s.record_win(n, st)
	if preview_best >= 10:
		s.record_win(10, st)
	# a little of the skill-tree wallet for shots: Tinh hoa, one node bought, one Tẩy Tủy Đan
	var tree := SkillTree.load_default()
	s.essence = 30
	tree.buy(s, String(tree.nodes(hero)[0]["id"]))
	tree.buy(s, String(tree.nodes(hero)[0]["id"]))
	s.pills = 1
	# Mảnh thẻ and a started Chém kiếm tree for shots of the deck / card-tree screens
	s.shards = 40
	if hero == "knight":
		var ct := CardTree.load_default()
		for nid in ["keen", "keen", "keen", "wide", "quick"]:
			ct.buy(s, "blade_arc", nid)
	s.profile.equip(hero, "iron_cap" if hero == "knight" else "cloth_hat")
	# a fuller bag for shots of the equipment screen: every item this class can wear
	for id: String in slot_store().defs:
		var d: Dictionary = slot_store().defs[id]
		if not d.has("class") or String(d["class"]) == hero:
			if not s.profile.bag.has(id):
				s.profile.add(id)
				if String(d.get("rarity", "")) != "legendary":   # the legendary ones show the "MỚI" badge
					s.profile.mark_seen(id)
	active_slot = s
	stage_target = 10


## The slot list in fixed mode (shots, tests): the preview slot, a second one
## and a broken file, so the slot page shows every state without touching disk.
func preview_entries() -> Array:
	var out := []
	if active_slot != null:
		out.append({"id": active_slot.id, "slot": active_slot, "error": ""})
	if _force_slots:
		var other := SlotStore.new_slot("Lam Vân", "mage" if hero == "knight" else "knight", slot_store().defs)
		other.id = "slot2"
		var st := Stages.load_default()
		for n in range(1, 4):
			other.record_win(n, st)
		out.append({"id": "slot2", "slot": other, "error": ""})
		out.append({"id": "slot3", "slot": null, "error": "file hỏng"})
	return out


## True for screenshots and tests: nothing is read from or written to disk.
func is_fixed() -> bool:
	return _fixed


## The player's profile (equipment): the active slot's when playing progression,
## else the legacy profile (tests/shots). The first visit gets starter items.
func profile() -> Profile:
	if active_slot != null:
		return active_slot.profile
	if _profile == null:
		var items := GameData.load_json("res://assets/data/items.json")
		var defs: Dictionary = items.get("equipment", {}).duplicate()
		defs.erase("_doc")
		_profile = Profile.load_or_new(defs, _fixed)
		if not _profile.given_starter:
			_profile.given_starter = true
			for id: String in defs:
				if bool(defs[id].get("starter", false)):
					_profile.add(id)
					for cls in ["knight", "mage"]:
						_profile.equip(cls, id)
			save_profile()
	return _profile


## Saves the active slot's profile (phase 3) or the legacy profile.
func save_profile() -> void:
	if _fixed:
		return
	if active_slot != null and _store != null:
		_store.save(active_slot)
	elif _profile != null:
		_profile.save()


## Slot store and migration from the old single profile (design/progression.md).
func slot_store() -> SlotStore:
	if _store == null:
		var items := GameData.load_json("res://assets/data/items.json")
		var defs: Dictionary = items.get("equipment", {}).duplicate()
		defs.erase("_doc")
		_store = SlotStore.new(defs)
	return _store


## Loads slots once: migrates user://profile.json into slot 1 on the first visit.
func ensure_slots() -> void:
	if _fixed or _ensuring_slots:
		return
	_ensuring_slots = true
	var store := slot_store()
	var all := store.list()
	if all.is_empty():
		var s := store.create("Nhân vật 1", hero)
		if s != null:
			if FileAccess.file_exists(Profile.PATH):
				var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(Profile.PATH))
				if data is Dictionary:
					s.profile.from_dict(data)
					store.save(s)
			all = store.list()
	# keep the slot chosen last time, else the first readable one
	var chosen := ""
	for e: Dictionary in all:
		if String(e["id"]) == slot_id and e.get("slot") != null:
			chosen = slot_id
		if chosen == "" and e.get("slot") != null:
			chosen = String(e["id"])
	_ensuring_slots = false
	if chosen != "":
		_apply_slot(chosen)
	elif active_slot == null:
		stage_target = clampi(stage_target, 1, Stages.load_default().count())


func select_slot(id: String) -> bool:
	ensure_slots()
	return _apply_slot(id)


## Sets the active slot without re-entering ensure_slots (which may call this).
func _apply_slot(id: String) -> bool:
	var e: Dictionary = slot_store().load_slot(id)
	if e.get("slot") == null:
		return false
	active_slot = e["slot"]
	slot_id = id
	hero = active_slot.cls
	stage_target = clampi(stage_target, 1, active_slot.unlocked(Stages.load_default().count()))
	if not _fixed:
		_save()
	return true


## Changes one setting, saves and applies it.
## Opacity of the player's skill / status effects at the chosen "Hiệu ứng" level.
func vfx_alpha() -> float:
	return float(VFX_ALPHA[clampi(vfx, 0, 2)])


func set_value(key: String, value: Variant) -> void:
	set(key, value)
	if not _fixed:
		_save()
	apply()


func apply() -> void:
	if not is_inside_tree():
		return
	if not _fixed:
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	_fit_scale()
	changed.emit()


## The whole-number scale in use now.
func current_scale() -> float:
	if not is_inside_tree():
		return 1.0
	var w := Vector2(get_tree().root.size)
	for a in OS.get_cmdline_user_args():   # gamekit shots: the capture size, not the window the WM gave
		if a.begins_with("--gk-size="):
			var wh := a.get_slice("=", 1).split("x")
			w = Vector2(float(wh[0]), float(wh[1]))
	return fit_scale(w, scale)


## The canvas scale for a [param window] (pixels) and the chosen scale (0 = auto):
## a whole number while the 1280x720 design fits (sharp pixels), the chosen one
## when it fits; below 1 when the window is smaller than the design, so screens
## always lay out on 1280x720 units (a 692-high window piled the lobby's card onto
## its buttons, 2026-11-17).
static func fit_scale(window: Vector2, chosen: int) -> float:
	var fit := minf(window.x / float(BASE.x), window.y / float(BASE.y))
	if fit < 1.0:
		return fit
	var whole := floorf(fit)
	return float(chosen) if chosen > 0 and float(chosen) <= whole else whole


func _fit_scale() -> void:
	get_tree().root.content_scale_factor = float(current_scale())


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK:
		return
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
	scale = clampi(int(cfg.get_value("display", "scale", scale)), 0, 3)
	damage_numbers = bool(cfg.get_value("hud", "damage_numbers", damage_numbers))
	monster_hp = bool(cfg.get_value("hud", "monster_hp", monster_hp))
	screen_shake = bool(cfg.get_value("hud", "screen_shake", screen_shake))
	vfx = clampi(int(cfg.get_value("hud", "vfx", vfx)), 0, 2)
	touch_stick = clampi(int(cfg.get_value("hud", "touch_stick", touch_stick)), 0, 2)
	music_volume = clampi(int(cfg.get_value("audio", "music", music_volume)), 0, 100)
	sfx_volume = clampi(int(cfg.get_value("audio", "sfx", sfx_volume)), 0, 100)
	hero = String(cfg.get_value("game", "hero", hero))
	slot_id = String(cfg.get_value("game", "slot", slot_id))
	stage_target = maxi(1, int(cfg.get_value("game", "stage", stage_target)))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "scale", scale)
	cfg.set_value("hud", "damage_numbers", damage_numbers)
	cfg.set_value("hud", "monster_hp", monster_hp)
	cfg.set_value("hud", "screen_shake", screen_shake)
	cfg.set_value("hud", "vfx", vfx)
	cfg.set_value("hud", "touch_stick", touch_stick)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("game", "hero", hero)
	cfg.set_value("game", "slot", slot_id)
	cfg.set_value("game", "stage", stage_target)
	cfg.save(settings_path)
