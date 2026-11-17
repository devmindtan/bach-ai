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
const BASE := Vector2i(1280, 720)   # the design size; auto scale = how many whole times it fits

## Paths are variables so headless tests can point them at a temporary folder.
var settings_path := PATH

var fullscreen := false
var scale := 0                      # 0 = auto, else 1..3
var damage_numbers := true
var monster_hp := true
var hero := "knight"                # the class chosen in the lobby (classes.json id)
var slot_id := ""                   # the selected character slot ("" = legacy profile)
var stage_target := 1               # the stage the lobby will start
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
	var forced_hero := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--gk-"):
			_fixed = true
		elif a == "--force-slots":
			_force_slots = true
		elif a.begins_with("--class="):   # shots / tests: play this class
			forced_hero = a.get_slice("=", 1)
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


## An in-memory slot for shots of slot mode (never saved: fixed mode blocks writes).
func _make_preview_slot() -> void:
	var s := SlotStore.new_slot("Nhân vật 1", hero, slot_store().defs)
	s.id = "slot1"
	# progress as record_win leaves it after winning stages 1-10 (stage 10 twice)
	var st := Stages.load_default()
	for n in range(1, 11):
		s.record_win(n, st)
	s.record_win(10, st)
	s.choose_milestone(10, "earthquake" if hero == "knight" else "void_orb")
	s.profile.equip(hero, "iron_helm")
	active_slot = s
	stage_target = 10


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
func current_scale() -> int:
	if scale > 0:
		return scale
	if not is_inside_tree():
		return 1
	var w := get_tree().root.size
	return maxi(1, mini(w.x / BASE.x, w.y / BASE.y))


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
	hero = String(cfg.get_value("game", "hero", hero))
	slot_id = String(cfg.get_value("game", "slot", slot_id))
	stage_target = maxi(1, int(cfg.get_value("game", "stage", stage_target)))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "scale", scale)
	cfg.set_value("hud", "damage_numbers", damage_numbers)
	cfg.set_value("hud", "monster_hp", monster_hp)
	cfg.set_value("game", "hero", hero)
	cfg.set_value("game", "slot", slot_id)
	cfg.set_value("game", "stage", stage_target)
	cfg.save(settings_path)
