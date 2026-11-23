class_name VirtualStick
extends Control
## Touch controls for phones (roadmap J4, design/ux/touch-controls.md): a move stick plus a Lướt button
## (pause: the HUD gear, which takes taps already), shown when the device has a touch screen (or `--touch` for shots). The stick feeds the normal move
## actions through Input.action_press, so the run reads it like a keyboard or gamepad.
##
## Mode (Cài đặt → "Cần điều khiển"): 0 Nổi = the stick appears where a thumb lands on the left part of the
## screen; 1 Cố định = it stays at the bottom left; 2 Tắt = hidden.
##
## Example:
##   var s := VirtualStick.new(); s.run = self; layer.add_child(s)
##   VirtualStick.stick_vector(Vector2(100, 600), Vector2(160, 600), 70.0)   # -> (0.857.., 0)

const RADIUS := 70.0           # px the knob can travel
const DEAD := 0.15             # inner part of the travel that is no input
const LEFT_SHARE := 0.55       # Nổi: the left share of the screen starts the stick
const FIXED_AT := Vector2(150, 560)
const DASH_AT := Vector2(1150, 590)
const DASH_R := 54.0
const MOVES := {"move_left": Vector2.LEFT, "move_right": Vector2.RIGHT, "move_up": Vector2.UP, "move_down": Vector2.DOWN}

var run: Node                 # the Run; null in tests
var mode := 0
var origin := FIXED_AT        # stick centre
var knob := Vector2.ZERO      # knob offset from the centre
var _finger := -1             # touch index holding the stick
var _dash_finger := -1


## The move vector for a thumb at [param pos] on a stick centred at [param centre]: length 0..1, zero inside
## the dead zone, rescaled so the edge of the dead zone is 0.
static func stick_vector(centre: Vector2, pos: Vector2, radius := RADIUS) -> Vector2:
	var d := pos - centre
	var k := minf(1.0, d.length() / radius)
	if k <= DEAD:
		return Vector2.ZERO
	return d.normalized() * ((k - DEAD) / (1.0 - DEAD))


## True when touch controls should show: a touch screen, or `--touch` (shots), and mode not Tắt.
static func wanted(touch_mode: int) -> bool:
	if touch_mode == 2:
		return false
	return DisplayServer.is_touchscreen_available() or "--touch" in OS.get_cmdline_user_args()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode = Prefs.current().touch_stick
	origin = FIXED_AT


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if _dash_visible() and t.position.distance_to(DASH_AT) <= DASH_R + 10.0:
				_dash_finger = t.index
				if run != null and run.has_method("try_dash") and _playing():
					run.try_dash()
				_eat()
			elif _finger < 0 and _starts_stick(t.position):
				_finger = t.index
				if mode == 0:
					origin = t.position
				_move_to(t.position)
				_eat()
		else:
			if t.index == _finger:
				_release()
			if t.index == _dash_finger:
				_dash_finger = -1
	elif event is InputEventScreenDrag:
		var dr := event as InputEventScreenDrag
		if dr.index == _finger:
			_move_to(dr.position)
			_eat()


func _starts_stick(p: Vector2) -> bool:
	if not _playing():
		return false
	if mode == 1:
		return p.distance_to(FIXED_AT) <= RADIUS * 1.8
	return p.x <= get_viewport_rect().size.x * LEFT_SHARE and p.y >= 140.0   # not over the HUD bars


func _move_to(p: Vector2) -> void:
	var v := stick_vector(origin, p)
	knob = (p - origin).limit_length(RADIUS)
	for a: String in MOVES:
		var s := maxf(0.0, v.dot(MOVES[a]))
		if s > 0.0:
			Input.action_press(a, s)
		else:
			Input.action_release(a)
	queue_redraw()


func _release() -> void:
	_finger = -1
	knob = Vector2.ZERO
	if mode == 0:
		origin = FIXED_AT
	for a: String in MOVES:
		Input.action_release(a)
	queue_redraw()


func _process(_dt: float) -> void:
	if _finger >= 0 and not _playing():   # a panel opened mid-drag: let go
		_release()
	queue_redraw()


func _playing() -> bool:
	if run == null:
		return true
	return int(run.get("state")) == 0   # Run.State.PLAYING


func _dash_visible() -> bool:
	return run == null or int((run.get("levels") as Dictionary).get("dash", 0)) > 0


func _eat() -> void:
	if is_inside_tree():
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if not _playing():
		return
	var held := _finger >= 0
	if mode == 1 or held:
		draw_circle(origin, RADIUS + 6.0, Color(0.05, 0.06, 0.09, 0.35))
		draw_arc(origin, RADIUS + 6.0, 0.0, TAU, 48, Color(0.91, 0.77, 0.45, 0.55), 3.0)
		draw_circle(origin + knob, 30.0, Color(0.95, 0.9, 0.79, 0.75 if held else 0.45))
		draw_arc(origin + knob, 30.0, 0.0, TAU, 32, Color(0.07, 0.05, 0.03, 0.8), 3.0)
	if _dash_visible():
		var ready := run == null or float(run.get("_dash_cd")) <= 0.0
		draw_circle(DASH_AT, DASH_R, Color(0.08, 0.09, 0.14, 0.6))
		draw_arc(DASH_AT, DASH_R, 0.0, TAU, 48, Color(0.91, 0.77, 0.45, 0.9 if ready else 0.35), 4.0)
		var f := get_theme_default_font()
		var base := (f.get_ascent(24) - f.get_descent(24)) * 0.5
		draw_string(f, DASH_AT + Vector2(-DASH_R, base), "Lướt", HORIZONTAL_ALIGNMENT_CENTER, DASH_R * 2, 24,
			Color(0.95, 0.9, 0.79, 1.0 if ready else 0.45))
