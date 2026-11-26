extends RefCounted
## Album with the mouse (user 2026-11-23: "album hiện không thể thao tác bằng chuột"): a grid cell and a tab
## take clicks (mouse_filter STOP) and a click picks that cell / opens that tab.

const AlbumScript := preload("res://src/front/album.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _click() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e


func test_cell_click_selects() -> void:
	var a: Node2D = AlbumScript.new()
	a.set("_tab", 2)
	var c: Control = a.call("_cell", {"id": "fireball"}, false, 5)
	_check(c.mouse_filter == Control.MOUSE_FILTER_STOP, "a grid cell ignores the mouse")
	c.gui_input.emit(_click())
	_check(int(a.get("_sel")) == 5, "clicking cell 5 selects %d" % int(a.get("_sel")))
	c.free()
	a.free()


func test_ribbon_click_opens() -> void:
	# the chapters are bookmark ribbons (design-web screen-album-journal): pressing one opens it
	var a: Node2D = AlbumScript.new()
	var root := Control.new()
	var col: VBoxContainer = Journal.ribbons(root, AlbumScript.TABS, [Color.RED], 0, Callable(a, "_open_tab"))
	var b := col.get_child(1) as Button
	_check(b.mouse_filter == Control.MOUSE_FILTER_STOP, "a ribbon ignores the mouse")
	b.pressed.emit()
	_check(int(a.get("_tab")) == 1, "pressing the Boss ribbon does not open it")
	root.free()
	a.free()
