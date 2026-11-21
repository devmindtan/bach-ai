class_name CardRarity
extends RefCounted
## Card rarity rolls (design/card-rarity.md, after Slay the Spire card rewards and Balatro's jokers):
## each hand slot rolls a tier with the source's weights (level / chest / gold_chest, assets/data/
## card_rarity.json), then picks a card of that tier from the pool (by "weight", not maxed, not a unique
## the run has not picked, not already in the hand). A tier the pool lacks steps down; when nothing below
## is left the slot is a filler card. A pity (Slay the Spire's rare offset) moves pity_step points from
## the common odds to the epic odds for every common / rare slot, and resets on an epic or better.
##
## Example:
##   var rr := CardRarity.new(GameData.load_json("res://assets/data/card_rarity.json"))
##   var hand := rr.roll(deck_pool, levels, 3, rng, "level")

const PATH := "res://assets/data/card_rarity.json"

var cfg: Dictionary
var tiers: Array = ["common", "rare", "epic", "legendary"]
var pity := 0.0   # points moved from common to epic (level rolls only)


func _init(p_cfg: Dictionary) -> void:
	cfg = p_cfg
	tiers = cfg.get("tiers", tiers)


static func load_default() -> CardRarity:
	return CardRarity.new(GameData.load_json(PATH))


## Level-up tier odds at run level [param level] (card_rarity.json level_curve: start + per_level x (level - 1),
## each clamped to [min, max], scaled to 100). Without a curve: the plain "level" weights.
func level_weights(level: int) -> Array:
	var lc: Dictionary = cfg.get("level_curve", {})
	if lc.is_empty():
		return (cfg.get("weights", {}).get("level", [60, 30, 9, 1]) as Array).duplicate()
	var w := []
	var total := 0.0
	for t in tiers.size():
		var v := float(lc["start"][t]) + float(lc["per_level"][t]) * maxi(0, level - 1)
		v = clampf(v, float(lc["min"][t]), float(lc["max"][t]))
		w.append(v)
		total += v
	for t in w.size():
		w[t] = snappedf(float(w[t]) * 100.0 / total, 0.01)
	return w


## The tier weights of [param source] now (pity applied to "level"); "level" follows the run [param level].
func chances(source: String, level := 1) -> Array:
	var w: Array = level_weights(level) if source == "level" else \
		(cfg.get("weights", {}).get(source, cfg.get("weights", {}).get("level", [60, 30, 9, 1]))).duplicate()
	if source == "level" and pity > 0.0 and w.size() > 2:
		var moved := minf(pity, float(w[0]))
		w[0] = float(w[0]) - moved
		w[2] = float(w[2]) + moved
	return w


## Records a slot of [param tier] for the pity.
func note(tier: String) -> void:
	var t := tiers.find(tier)
	if t >= 2:
		pity = 0.0
	elif t >= 0:
		pity += float(cfg.get("pity_step", 1.0))


## Tier index (0 common) of card [param u]; cards without "rarity" are common.
func tier_of(u: Dictionary) -> int:
	return maxi(0, tiers.find(String(u.get("rarity", "common"))))


## Up to [param count] card ids for a hand from [param pool] (fillers fill slots nothing else can).
func roll(pool: Array, levels: Dictionary, count: int, rng: RandomNumberGenerator, source := "level", run_level := 1) -> Array[String]:
	var by_tier := []
	for t in tiers.size():
		by_tier.append([])
	for u: Variant in pool:
		if not u is Dictionary:
			continue
		var lv := int(levels.get(u.get("id", ""), 0))
		if lv < UpgradeRoller.cap(u) and not (bool(u.get("unique", false)) and lv <= 0):
			by_tier[tier_of(u)].append(u)
	var out: Array[String] = []
	var fillers: Array = cfg.get("fillers", [])
	var filler_n := 0
	for slot in count:
		var w := chances(source, run_level)
		var total := 0.0
		for x in w:
			total += float(x)
		var r := rng.randf() * total
		var tier := 0
		for t in w.size():
			r -= float(w[t])
			if r < 0.0:
				tier = t
				break
		if source == "level":
			note(String(tiers[tier]))
		var picked := ""
		for t in range(tier, -1, -1):   # a tier the deck lacks steps down
			var cands: Array = by_tier[t].filter(func(u: Dictionary) -> bool: return not out.has(String(u["id"])))
			if not cands.is_empty():
				picked = _weighted(cands, rng)
				break
		if picked == "" and source != "level":   # chests: step up rather than give nothing
			for t in range(tier + 1, tiers.size()):
				var cands2: Array = by_tier[t].filter(func(u: Dictionary) -> bool: return not out.has(String(u["id"])))
				if not cands2.is_empty():
					picked = _weighted(cands2, rng)
					break
		if picked == "" and not fillers.is_empty():
			picked = String(fillers[filler_n % fillers.size()]["id"])
			filler_n += 1
		if picked != "":
			out.append(picked)
	return out


func _weighted(cands: Array, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for u: Dictionary in cands:
		total += maxf(0.0, float(u.get("weight", 1)))
	var pick := rng.randf() * total
	for u: Dictionary in cands:
		pick -= maxf(0.0, float(u.get("weight", 1)))
		if pick < 0.0:
			return String(u["id"])
	return String(cands[-1]["id"])
