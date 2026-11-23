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


func test_tab_click_opens() -> void:
	var a: Node2D = AlbumScript.new()
	var p: Control = a.call("_tab_plate", 1)
	_check(p.mouse_filter == Control.MOUSE_FILTER_STOP, "a tab ignores the mouse")
	p.gui_input.emit(_click())
	_check(int(a.get("_tab")) == 1, "clicking the Boss tab does not open it")
	p.free()
	a.free()
