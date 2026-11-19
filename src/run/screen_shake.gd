class_name ScreenShake
extends RefCounted
## Camera shake (6C.2, after Vlambeer's "The Art of Screenshake"): add() a strength in px; step() gives
## the camera offset for this frame, a jitter that decays to rest. Off when the player turns it off
## (Cài đặt → Rung màn hình).
##
## Example:
##   shake.add(4.0)                                # the hero was hit
##   camera.offset = shake.step(dt, frame_count)

const DECAY := 9.0     # strength lost per second, as a share (exponential)
const MAX := 10.0      # px

var enabled := true
var _amount := 0.0


func add(px: float) -> void:
	if enabled:
		_amount = minf(MAX, _amount + px)


## The camera offset this frame ([param seed] varies it frame to frame without a RNG).
func step(dt: float, seed: int) -> Vector2:
	if not enabled or _amount < 0.3:
		_amount = 0.0
		return Vector2.ZERO
	var o := Vector2(sin(seed * 12.9898) , cos(seed * 78.233)) * _amount
	_amount *= exp(-DECAY * dt)
	return o.round()
