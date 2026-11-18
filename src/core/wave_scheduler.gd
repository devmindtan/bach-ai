class_name WaveScheduler
extends RefCounted
## Turns a stage's wave list (waves/stage_NNN.json) into spawn counts per
## monster as the run clock advances. Deterministic: fractional spawns carry
## over between calls, so the total over a run does not depend on frame rate.
##
## Example:
##   var ws := WaveScheduler.new(stage["waves"])
##   for m in ws.advance(t, t + delta): spawn(m)

var _waves: Array = []
var _carry: Array[float] = []
var _burst_done: Array[bool] = []


func _init(waves: Array) -> void:
	_waves = waves
	for _w in waves:
		_carry.append(0.0)
		_burst_done.append(false)


## Rate (spawns / s) of wave [param w] at time [param t]: linear from rate to rate_end.
static func rate_at(w: Dictionary, t: float) -> float:
	var t0 := float(w.get("t_from", 0.0))
	var t1 := float(w.get("t_to", t0))
	if t < t0 or t > t1 or t1 <= t0:
		return 0.0
	var r0 := float(w.get("rate", 0.0))
	var r1 := float(w.get("rate_end", r0))
	return lerpf(r0, r1, (t - t0) / (t1 - t0))


## Wave calls for clock time (t0, t1] (design 6A pacing): the "announce" text of
## every wave whose t_from - "warn" (default 2 s) falls in the step, so a big
## wave is called before it arrives.
func announcements(t0: float, t1: float) -> Array[String]:
	var out: Array[String] = []
	for w: Dictionary in _waves:
		if not w.has("announce"):
			continue
		var tc := float(w.get("t_from", 0.0)) - float(w.get("warn", 2.0))
		if tc > t0 - 0.0001 and tc <= t1:
			out.append(String(w["announce"]))
	return out


## Monsters to spawn for clock time (t0, t1]: an Array of monster ids (repeats allowed).
func advance(t0: float, t1: float) -> Array[String]:
	var out: Array[String] = []
	if t1 <= t0:
		return out
	for i in _waves.size():
		var w: Dictionary = _waves[i]
		var monster := String(w.get("monster", ""))
		if w.has("burst"):
			var tb := float(w.get("t_from", 0.0))
			if not _burst_done[i] and tb > t0 - 0.0001 and tb <= t1:
				_burst_done[i] = true
				for _k in int(w["burst"]):
					out.append(monster)
			continue
		# trapezoid: average rate over the step
		var amount := 0.5 * (rate_at(w, t0) + rate_at(w, t1)) * (t1 - t0)
		_carry[i] += amount
		while _carry[i] >= 1.0:
			_carry[i] -= 1.0
			out.append(monster)
	return out
