class_name BossFxNode
extends Node
## BossFX (autoload "BossFx"): draws boss-skill effects in the world independently of
## the runner code, so the boss's slam / split art can evolve without touching the
## main run loop. Singletons attach to an Enemies instance via [method Enemies._init];
## in headless / test runs without the autoload, the calls are no-ops.
##
## Example:
##   BossFx.current()     # the autoload
##   BossFxNode.attach(enemies)  # called by the Enemies constructor when the autoload exists
##
## Enemies (src/run/enemies.gd) emits [signal slam_done] and [signal split_done].

const SPRITES := "res://assets/sprites/custom/"
const BOSS_SCALE := 2.0    # whole scale (review 2026-11-21: x1.8 smeared the 72 px art); boss-sized like the boss
const SPLIT_SCALE := 2.0   # the split burst, same whole scale (was 1.8 x 0.8 = 1.44)

var _layer: CanvasLayer
var _view: Control
var _events: Array[Dictionary] = []  # {anim, sheet, t, pos, scale}
var _sheets: Dictionary = {}          # sprite name -> SpriteSheet (loaded lazily)


## The autoload instance, or null outside a running scene (tests, import).
static func current() -> BossFxNode:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("BossFX") as BossFxNode


## Wires the autoload to [param e]'s boss events. Safe to call with no autoload.
static func attach(e: RefCounted) -> void:
	var fx := current()
	if fx == null:
		return
	if e.has_signal("slam_done"):
		if not e.slam_done.is_connected(fx._on_slam):
			e.slam_done.connect(fx._on_slam)
	if e.has_signal("split_done"):
		if not e.split_done.is_connected(fx._on_split):
			e.split_done.connect(fx._on_split)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 1   # above the world (layer 0), below HUD on layer 0 drawn on its own node
	add_child(_layer)
	_view = Control.new()
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_view)
	_view.draw.connect(_draw)
	set_process(false)


func _on_slam(pos: Vector2) -> void:
	_spawn("boss-slam", "burst", pos, BOSS_SCALE)


func _on_split(pos: Vector2) -> void:
	_spawn("boss-split", "burst", pos, SPLIT_SCALE)


func _spawn(sprite: String, anim: String, pos: Vector2, scale: float) -> void:
	var sheet := _sheet(sprite)
	if sheet == null:
		return
	_events.append({"anim": anim, "sheet": sheet, "t": 0.0, "pos": pos, "scale": scale, "dur": sheet.duration(anim)})
	set_process(true)


func _sheet(name: String) -> SpriteSheet:
	if not _sheets.has(name):
		var sh := SpriteSheet.load_dir(SPRITES + name, name)
		if sh == null:
			push_error("BossFx: sprite %s not found in %s" % [name, SPRITES + name])
			_sheets[name] = null
		else:
			_sheets[name] = sh
	return _sheets[name]


func _process(delta: float) -> void:
	var done: Array[int] = []
	for i in range(_events.size()):
		_events[i]["t"] = float(_events[i]["t"]) + delta
		if float(_events[i]["t"]) >= float(_events[i]["dur"]):
			done.append(i)
	for i in range(done.size() - 1, -1, -1):
		_events.remove_at(done[i])
	_view.queue_redraw()
	set_process(not _events.is_empty())


## World → screen offset: the camera centres on the player.
func _camera_offset() -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return Vector2.ZERO
	var r := vp.get_visible_rect()
	var o := r.size * 0.5
	var cam := vp.get_camera_2d()
	if cam != null:
		o -= cam.position
	return o


func _draw() -> void:
	var offset := _camera_offset()
	for e in _events:
		var sheet: SpriteSheet = e["sheet"]
		var t: float = e["t"]
		sheet.draw(_view, e["anim"], t, e["pos"] + offset, e["scale"])
