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

var fullscreen := false
var scale := 0                      # 0 = auto, else 1..3
var damage_numbers := true
var monster_hp := true
var hero := "knight"                # the class chosen in the lobby (classes.json id)
var _fixed := false                 # screenshots / tests: defaults, never touch the window

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
		elif a.begins_with("--class="):   # shots / tests: play this class
			forced_hero = a.get_slice("=", 1)
	if DisplayServer.get_name() == "headless":
		_fixed = true
	if not _fixed:
		_load()
	if forced_hero != "":
		hero = forced_hero
	apply()
	get_tree().root.size_changed.connect(_fit_scale)


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
	if cfg.load(PATH) != OK:
		return
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
	scale = clampi(int(cfg.get_value("display", "scale", scale)), 0, 3)
	damage_numbers = bool(cfg.get_value("hud", "damage_numbers", damage_numbers))
	monster_hp = bool(cfg.get_value("hud", "monster_hp", monster_hp))
	hero = String(cfg.get_value("game", "hero", hero))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "scale", scale)
	cfg.set_value("hud", "damage_numbers", damage_numbers)
	cfg.set_value("hud", "monster_hp", monster_hp)
	cfg.set_value("game", "hero", hero)
	cfg.save(PATH)
