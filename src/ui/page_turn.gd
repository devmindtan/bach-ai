class_name PageTurn
extends Control
## The page turn when a journal screen opens (design-web journal.js journalFlip, approved 2026-11-28): a paper leaf
## narrows from the right page to the spine, then opens over the left page, in STEPS whole-pixel steps (no
## rotation: pixels stay sharp), with the "page" rustle. Off when Hiệu ứng is Tối thiểu.
##
## Example:
##   PageTurn.play(get_tree())

const STEPS := 8
const STEP_S := 0.04
const HALF := 550.0   # one page of Journal.BOOK
## Scenes drawn as the open journal: entering one turns a page.
const SCENES := ["res://src/lobby/lobby.tscn", "res://src/front/characters.tscn", "res://src/front/equipment.tscn",
	"res://src/front/skill_tree.tscn", "res://src/front/deck.tscn", "res://src/front/card_tree.tscn",
	"res://src/front/stage_select.tscn", "res://src/front/missions.tscn", "res://src/front/gacha.tscn",
	"res://src/front/album.tscn"]

var _k := 0
var _acc := 0.0


## Leaf width and left edge (book-local) at step [param k] of STEPS: the right page closing, then the left opening.
static func leaf_at(k: int) -> Vector2:
	var t := float(k) / STEPS
	var w := roundf(HALF * (1.0 - t * 2.0) if t < 0.5 else HALF * (t * 2.0 - 1.0))
	w = maxf(4.0, w)
	return Vector2(w, HALF if t < 0.5 else HALF - w)


static func play(tree: SceneTree, parent: Node = null) -> void:
	if Prefs.current().vfx >= 2:
		return
	var layer := CanvasLayer.new()
	layer.layer = 100
	var leaf := PageTurn.new()
	leaf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(leaf)
	(parent if parent != null else tree.root).add_child(layer)
	Sfx.play("page")


func _process(delta: float) -> void:
	_acc += delta
	while _acc >= STEP_S:
		_acc -= STEP_S
		_k += 1
	if _k >= STEPS:
		get_parent().queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var b := Journal.BOOK
	var wl := leaf_at(maxi(_k, 1))
	var r := Rect2(b.position + Vector2(wl.y, 0), Vector2(wl.x, b.size.y))
	draw_rect(r, Journal.PAPER if _k < STEPS / 2 else Color("d8c498"))
	draw_rect(r, Journal.EDGE, false, 4.0)
