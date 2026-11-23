class_name Endless
extends RefCounted
## Chế độ Vô tận (design/endless.md): the stage loops in Vòng (cycles) like Vampire Survivors' endless mode;
## each Vòng makes the monsters tougher. Numbers in assets/data/endless.json.
##
## Example:
##   var e := Endless.load_default()
##   e.base_stage(slot.best, stages)          # stage whose waves play
##   for span in Endless.spans(t0, t1, 300.0): run._spawn(span[0], span[1])

var data := {}


static func load_default() -> Endless:
	var e := Endless.new()
	e.data = GameData.load_json("res://assets/data/endless.json")
	return e


func unlock() -> int:
	return int(data.get("unlock", 10))


func is_open(slot: Slot) -> bool:
	return slot != null and slot.best >= unlock()


## The stage Vô tận plays: the highest won stage that has no boss (a boss stage ends with its boss), at least 1.
func base_stage(best: int, stages: Stages) -> int:
	var n := maxi(1, best)
	while n > 1 and stages != null and stages.is_boss(n):
		n -= 1
	return n


## Vòng (0-based) at clock [param t] for a stage of [param duration] s.
static func cycle(t: float, duration: float) -> int:
	return int(floorf(t / maxf(1.0, duration)))


## Monster hp multiplier in Vòng [param c].
func hp_mul(c: int) -> float:
	return 1.0 + float(data.get("cycle_hp", 1.0)) * c


## Monster damage multiplier in Vòng [param c].
func damage_mul(c: int) -> float:
	return 1.0 + float(data.get("cycle_damage", 0.25)) * c


## The wave-clock spans covered when the run clock goes [param t0] -> [param t1]: the wave clock wraps at
## [param duration], so a step over the edge gives two spans ([t0', duration] and [0, t1']).
static func spans(t0: float, t1: float, duration: float) -> Array:
	var d := maxf(1.0, duration)
	var a := fposmod(t0, d)
	var b := fposmod(t1, d)
	if cycle(t1, d) > cycle(t0, d):
		return [[a, d], [0.0, b]]
	return [[a, b]]
