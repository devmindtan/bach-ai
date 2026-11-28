class_name MoveFeel
extends RefCounted
## Walk and camera feel (user 2026-11-28: "gameplay movement hơi cứng", picked: ease in / out + a soft camera).
## Tuning: run_config.json "player.move" (accel_s, decel_s) and "camera" (follow_rate, max_lag). 0 = the old snap.


## The velocity one step toward [param target]: full speed in [param accel_s], a stop in [param decel_s].
static func step_velocity(vel: Vector2, target: Vector2, speed: float, accel_s: float, decel_s: float, dt: float) -> Vector2:
	var t := accel_s if target.length_squared() > 0.0001 else decel_s
	if t <= 0.0:
		return target
	return vel.move_toward(target, speed / t * dt)


## The camera eased toward [param target] ([param rate] per second, exponential) and never more than [param max_lag]
## behind it, so the hero stays near the centre.
static func follow(cam: Vector2, target: Vector2, rate: float, max_lag: float, dt: float) -> Vector2:
	if rate <= 0.0:
		return target
	var p := cam.lerp(target, 1.0 - exp(-rate * dt))
	var off := p - target
	if max_lag > 0.0 and off.length() > max_lag:
		p = target + off.limit_length(max_lag)
	return p
