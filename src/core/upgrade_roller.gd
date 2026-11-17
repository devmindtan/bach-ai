class_name UpgradeRoller
extends RefCounted
## Picks the level-up choices: up to [param count] distinct upgrades, weighted by
## "weight", never one already at "max_level", never a "unique" (milestone) skill
## the player does not own yet.
##
## Example:
##   var ids := UpgradeRoller.roll(pool, {"sharpen": 2}, 3, rng)


## [param pool] is the "upgrades" array of upgrades_<class>.json; [param levels]
## maps id -> current level. Returns ids in pick order (fewer when the pool runs out).
static func roll(pool: Array, levels: Dictionary, count: int, rng: RandomNumberGenerator) -> Array[String]:
	var candidates: Array[Dictionary] = []
	for u: Variant in pool:
		if not u is Dictionary:
			continue
		var lv := int(levels.get(u.get("id", ""), 0))
		# a unique (milestone) skill is only offered once the slot owns it (level >= 1)
		if lv < int(u.get("max_level", 1)) and not (bool(u.get("unique", false)) and lv <= 0):
			candidates.append(u)
	var out: Array[String] = []
	while out.size() < count and not candidates.is_empty():
		var total := 0.0
		for u in candidates:
			total += maxf(0.0, float(u.get("weight", 1)))
		if total <= 0.0:
			break
		var pick := rng.randf() * total
		var idx := candidates.size() - 1
		for i in candidates.size():
			pick -= maxf(0.0, float(candidates[i].get("weight", 1)))
			if pick < 0.0:
				idx = i
				break
		out.append(String(candidates[idx]["id"]))
		candidates.remove_at(idx)
	return out
