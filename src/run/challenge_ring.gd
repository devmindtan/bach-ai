class_name ChallengeRing
extends RefCounted
## Vòng thử thách (design/events.md, after Risk of Rain 2's holdout zones): a ring on the ground that
## charges only while the player stands inside it. `need` seconds inside complete it ("done"); the
## `limit` running out first fails it ("fail"). Leaving keeps the charge.
##
## Example:
##   var ring := ChallengeRing.new()
##   ring.start(pos, 70.0, 8.0, 30.0)
##   match ring.step(dt, player_pos):   # "", "done" or "fail"

var active := false
var center := Vector2.ZERO
var radius := 70.0
var need := 8.0
var limit := 30.0
var charge := 0.0
var elapsed := 0.0
var inside := false


## Starts a ring at [param p], kept inside an arena of half size [param arena_half] so the whole
## ring is reachable (it was once placed beyond the arena edge).
func start(p: Vector2, r: float, need_s: float, limit_s: float, arena_half := INF) -> void:
	active = true
	var lim := maxf(0.0, arena_half - r - 10.0)
	center = p.clamp(Vector2(-lim, -lim), Vector2(lim, lim)) if arena_half < INF else p
	radius = r
	need = maxf(0.1, need_s)
	limit = limit_s
	charge = 0.0
	elapsed = 0.0
	inside = false


## Advances the ring by [param dt]; returns "done", "fail" or "".
func step(dt: float, player: Vector2) -> String:
	if not active:
		return ""
	elapsed += dt
	inside = player.distance_to(center) <= radius
	if inside:
		charge += dt
		if charge >= need - 0.0001:
			active = false
			return "done"
	if elapsed >= limit:
		active = false
		return "fail"
	return ""


## Charge share 0..1.
func progress() -> float:
	return clampf(charge / need, 0.0, 1.0)


## Seconds left before the ring fails.
func time_left() -> float:
	return maxf(0.0, limit - elapsed)
