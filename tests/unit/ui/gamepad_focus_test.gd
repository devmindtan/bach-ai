extends RefCounted
## Roadmap J5 (2026-11-23): a gamepad needs a focused control on every screen and the D-pad to move the hero.

var failures: Array[String] = []


func test_first_enabled_button_skips_disabled_and_hidden() -> void:
	var root := VBoxContainer.new()
	var a := Button.new()
	a.disabled = true
	var b := Button.new()
	b.visible = false
	var c := Button.new()
	for x in [a, b, c]:
		root.add_child(x)
	if UiKit.first_enabled_button(root) != c:
		failures.append("first enabled button should be the third")
	c.disabled = true
	if UiKit.first_enabled_button(root) != null:
		failures.append("no enabled button should give null")
	root.free()


func test_dpad_moves_the_hero() -> void:
	RunInput.register()
	for pair in [["move_left", JOY_BUTTON_DPAD_LEFT], ["move_right", JOY_BUTTON_DPAD_RIGHT],
			["move_up", JOY_BUTTON_DPAD_UP], ["move_down", JOY_BUTTON_DPAD_DOWN]]:
		var e := InputEventJoypadButton.new()
		e.button_index = pair[1]
		e.pressed = true
		if not InputMap.event_is_action(e, pair[0]):
			failures.append("%s has no D-pad button" % pair[0])
