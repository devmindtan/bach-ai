class_name FieldChallenge
extends RefCounted
## In-run challenges besides the ring (user 2026-11-21: more kinds, easier): "collect" (Thu thập sao: pick every
## star before the limit) and "hunt" (Săn tinh anh: kill the marked elite before the limit). The run spawns the
## elite / places the stars, draws them and pays the reward; this holds the rules.
##
## Example:
##   var c := FieldChallenge.new()
##   c.start_collect(points, 20.0, 24.0)
##   match c.step(dt, player_pos, hunted_alive):   # "", "done" or "fail"

var kind := ""        # "" (none), "collect", "hunt"
var stars: Array = []  # Vector2 still to pick (collect)
var total := 0
var pick_r := 24.0
var limit := 20.0
var elapsed := 0.0


func active() -> bool:
	return kind != ""


func start_collect(points: Array, p_limit: float, p_pick_r: float) -> void:
	kind = "collect"
	stars = points.duplicate()
	total = stars.size()
	pick_r = p_pick_r
	limit = p_limit
	elapsed = 0.0


func start_hunt(p_limit: float) -> void:
	kind = "hunt"
	limit = p_limit
	elapsed = 0.0


## Advances by [param dt]; [param hunted_alive]: the marked elite still lives. Returns "done", "fail" or "".
func step(dt: float, player: Vector2, hunted_alive: bool) -> String:
	if kind == "":
		return ""
	elapsed += dt
	if kind == "collect":
		stars = stars.filter(func(p: Vector2) -> bool: return p.distance_to(player) > pick_r)
		if stars.is_empty():
			kind = ""
			return "done"
	elif kind == "hunt" and not hunted_alive:
		kind = ""
		return "done"
	if elapsed >= limit:
		kind = ""
		return "fail"
	return ""


func time_left() -> float:
	return maxf(0.0, limit - elapsed)
