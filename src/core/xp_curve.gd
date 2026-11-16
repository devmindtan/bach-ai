class_name XpCurve
extends RefCounted
## Experience needed per level (formula in run_config.json "xp"):
##   xp_to_next(L) = round(base * growth^(L-1) + flat * (L-1))
##
## Example:
##   var curve := XpCurve.new(6.0, 1.22, 2.0)
##   curve.xp_to_next(1)  # 6

var base: float
var growth: float
var flat: float


func _init(p_base: float, p_growth: float, p_flat: float) -> void:
	base = maxf(1.0, p_base)
	growth = maxf(1.0, p_growth)
	flat = maxf(0.0, p_flat)


## Builds the curve from the "xp" block of run_config.json.
static func from_config(cfg: Dictionary) -> XpCurve:
	return XpCurve.new(float(cfg.get("base", 6.0)), float(cfg.get("growth", 1.22)), float(cfg.get("flat", 2.0)))


## XP needed to go from [param level] to level + 1 (at least 1).
func xp_to_next(level: int) -> int:
	var l := maxi(1, level)
	return maxi(1, roundi(base * pow(growth, l - 1) + flat * (l - 1)))


## Adds [param xp] to (level, current xp) and returns [new_level, new_xp, levels_gained].
func add(level: int, current: float, xp: float) -> Array:
	var l := maxi(1, level)
	var c := current + maxf(0.0, xp)
	var gained := 0
	while c >= xp_to_next(l):
		c -= xp_to_next(l)
		l += 1
		gained += 1
	return [l, c, gained]
