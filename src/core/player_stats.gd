class_name PlayerStats
extends RefCounted
## Player stats for a run: the class base (classes.json "stats") with every
## chosen upgrade level applied (upgrades_<class>.json "effects").
## Effects: {"stat": {"add": x}} adds x per level; {"stat": {"mul": f}} adds f per
## level to a multiplier that starts at 1 (so -0.10 per level of "cooldown" makes
## it 0.9, 0.8, ... floored at 0.2). Keys like "skill_damage.whirlwind" are per skill.
##
## Example:
##   var s := PlayerStats.compute(base, pool, {"sharpen": 2})
##   s["damage"]  # base * 1.30


## Returns a new Dictionary of final stats.
static func compute(base: Dictionary, pool: Array, levels: Dictionary) -> Dictionary:
	var adds := {}
	var muls := {}
	for u: Variant in pool:
		if not u is Dictionary:
			continue
		var lv := int(levels.get(u.get("id", ""), 0))
		if lv <= 0:
			continue
		var effects: Dictionary = u.get("effects", {})
		for stat: String in effects:
			var e: Dictionary = effects[stat]
			if e.has("add"):
				adds[stat] = float(adds.get(stat, 0.0)) + float(e["add"]) * lv
			if e.has("mul"):
				muls[stat] = float(muls.get(stat, 0.0)) + float(e["mul"]) * lv
	var out := {}
	var keys := {}
	for k in base: keys[k] = true
	for k in adds: keys[k] = true
	for k in muls: keys[k] = true
	for k: String in keys:
		var b := float(base.get(k, 0.0 if not muls.has(k) else 1.0))
		var v := (b + float(adds.get(k, 0.0))) * maxf(0.2, 1.0 + float(muls.get(k, 0.0)))
		out[k] = v
	return out


## Multiplier for a per-skill key (e.g. "skill_damage.whirlwind"), 1 when absent.
static func skill_mul(stats: Dictionary, key: String) -> float:
	return float(stats.get(key, 1.0))


## Where every stat comes from, for the character sheet:
## { stat: { "base": float, "final": float, "parts": [ {"id", "name", "level",
##   "add": float (total for the level) or "mul": float (e.g. -0.4 = -40%)} ] } }.
## Only stats that exist in the base or that a chosen upgrade touches are listed.
## "final" is the same value compute() returns.
static func breakdown(base: Dictionary, pool: Array, levels: Dictionary) -> Dictionary:
	var final := compute(base, pool, levels)
	var out := {}
	for k: String in final:
		out[k] = {"base": float(base.get(k, 0.0 if not k.contains(".") else 1.0)), "final": float(final[k]), "parts": []}
	for u: Variant in pool:
		if not u is Dictionary:
			continue
		var lv := int(levels.get(u.get("id", ""), 0))
		if lv <= 0:
			continue
		var effects: Dictionary = u.get("effects", {})
		for stat: String in effects:
			if not out.has(stat):
				continue
			var e: Dictionary = effects[stat]
			var part := {"id": u.get("id", ""), "name": u.get("name", u.get("id", "")), "level": lv}
			if e.has("add"):
				part["add"] = float(e["add"]) * lv
			if e.has("mul"):
				part["mul"] = float(e["mul"]) * lv
			out[stat]["parts"].append(part)
	return out
