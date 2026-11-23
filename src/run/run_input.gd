class_name RunInput
extends RefCounted
## Registers the run's input actions at startup (keyboard + gamepad), so the
## bindings live in one place in code instead of a hand-edited project.godot.
##
## Example:
##   RunInput.register()
##   Input.get_vector("move_left", "move_right", "move_up", "move_down")


static func register() -> void:
	_add("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])   # D-pad too (J5)
	_add("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_add("move_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1.0]])
	_add("move_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]])
	_add("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START], [])
	_add("choose_1", [KEY_1, KEY_KP_1], [JOY_BUTTON_X], [])
	_add("choose_2", [KEY_2, KEY_KP_2], [JOY_BUTTON_Y], [])
	_add("choose_3", [KEY_3, KEY_KP_3], [JOY_BUTTON_B], [])
	_add("restart", [KEY_R, KEY_ENTER], [JOY_BUTTON_A], [])
	_add("character", [KEY_TAB, KEY_C], [JOY_BUTTON_BACK], [])
	_add("peek", [KEY_H], [JOY_BUTTON_LEFT_SHOULDER], [])   # level-up: hide the cards
	_add("dash", [KEY_SPACE, KEY_SHIFT], [JOY_BUTTON_RIGHT_SHOULDER], [])


static func _add(action: String, keys: Array, buttons: Array, axes: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.2)
	for k: int in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b: int in buttons:
		var j := InputEventJoypadButton.new()
		j.button_index = b
		InputMap.action_add_event(action, j)
	for a: Array in axes:
		var m := InputEventJoypadMotion.new()
		m.axis = a[0]
		m.axis_value = a[1]
		InputMap.action_add_event(action, m)
