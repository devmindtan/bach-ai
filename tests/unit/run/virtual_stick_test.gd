extends RefCounted
## Touch controls (roadmap J4): the stick's move vector has a dead zone, is capped at 1 and points from the
## stick centre to the thumb; a stick drag presses the move actions with that strength.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_dead_zone() -> void:
	var c := Vector2(100, 600)
	_check(VirtualStick.stick_vector(c, c + Vector2(5, 0)) == Vector2.ZERO, "a thumb in the dead zone moves")


func test_capped_and_direction() -> void:
	var c := Vector2(100, 600)
	var v := VirtualStick.stick_vector(c, c + Vector2(0, 500))
	_check(is_equal_approx(v.length(), 1.0), "past the rim the vector is %s, not length 1" % v)
	_check(v.y > 0.99, "a thumb below the centre does not move down: %s" % v)
	var half := VirtualStick.stick_vector(c, c + Vector2(-VirtualStick.RADIUS * 0.5, 0))
	_check(half.x < -0.3 and half.x > -0.6, "half travel left gives %s" % half)


func test_drag_presses_move_actions() -> void:
	RunInput.register()
	var s := VirtualStick.new()
	s.origin = Vector2(100, 600)
	s._move_to(Vector2(100 + VirtualStick.RADIUS, 600))
	_check(Input.get_action_strength("move_right") > 0.99, "a full drag right does not press move_right")
	_check(Input.get_action_strength("move_left") == 0.0, "a drag right presses move_left")
	s._release()
	_check(Input.get_action_strength("move_right") == 0.0, "letting go keeps move_right pressed")
	s.free()
