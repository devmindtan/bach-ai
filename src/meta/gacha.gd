class_name Gacha
extends RefCounted
## Gacha (assets/data/gacha.json, design/gacha.md): pulls paid with gems, a
## rarity from the published rates, a legendary guaranteed on the pity pull of
## each banner (own counter on the Slot), an item of the banner's slots that the
## class can wear; a duplicate becomes gold.
##
## Example:
##   var g := Gacha.load_default()
##   var got := g.pull(slot, "weapon", 10, rng)   # [] when the gems are short

const PATH := "res://assets/data/gacha.json"
const ORDER := ["legendary", "epic", "rare", "common"]

var data: Dictionary


func _init(p_data: Dictionary) -> void:
	data = p_data


static func load_default() -> Gacha:
	return Gacha.new(GameData.load_json(PATH))


func banners() -> Array:
	return data.get("banners", [])


func banner(id: String) -> Dictionary:
	for b: Dictionary in banners():
		if String(b["id"]) == id:
			return b
	return {}


func cost(n: int) -> int:
	return int(data.get("cost_per_pull", 10)) * n


func pity_at() -> int:
	return int(data.get("pity_at", 50))


## A rarity for one pull; [param since] = pulls since the last legendary.
func roll_rarity(rng: RandomNumberGenerator, since: int) -> String:
	if since + 1 >= pity_at():
		return "legendary"
	var x := rng.randf()
	var rates: Dictionary = data.get("rates", {})
	for r in ORDER:
		if rates.has(r):
			x -= float(rates[r])
			if x < 0.0:
				return r
	return "rare"


## Items of banner [param bid] of [param rarity] that class [param cls] can wear.
func pool(defs: Dictionary, bid: String, cls: String, rarity: String) -> Array:
	var slots: Array = banner(bid).get("slots", [])
	var out := []
	for id: String in defs:
		var d: Dictionary = defs[id]
		if slots.has(String(d.get("slot", ""))) and String(d.get("rarity", "")) == rarity \
				and (not d.has("class") or String(d["class"]) == cls):
			out.append(id)
	out.sort()
	return out


## [param n] pulls on banner [param bid] for [param slot]: pays the gems, keeps the
## pity count, adds new items to the bag and gold for duplicates. Returns
## [{id, rarity, dup, gold}], or [] when the gems are short.
func pull(slot: Slot, bid: String, n: int, rng: RandomNumberGenerator, now := -1.0) -> Array:
	if banner(bid).is_empty() or slot.gems < cost(n):
		return []
	slot.gems -= cost(n)
	var out := []
	var defs := slot.profile.defs
	for i in n:
		var since := int(slot.pity.get(bid, 0))
		var rarity := roll_rarity(rng, since)
		var ids := pool(defs, bid, slot.cls, rarity)
		var k := ORDER.find(rarity)
		while ids.is_empty() and k + 1 < ORDER.size():   # no such item: the next lower rarity
			k += 1
			ids = pool(defs, bid, slot.cls, ORDER[k])
		slot.pity[bid] = 0 if rarity == "legendary" else since + 1
		if ids.is_empty():
			continue
		var id: String = ids[rng.randi() % ids.size()]
		var r := String(defs[id].get("rarity", rarity))
		var dup := slot.profile.bag.has(id)
		var gold := 0
		if dup:
			gold = int(data.get("dup_gold", {}).get(r, 20))
			slot.gold += gold
			slot.shards += int(data.get("dup_shards", 0))   # Mảnh thẻ (design/skill-tree-v2.md)
		else:
			slot.profile.add(id)
		out.append({"id": id, "rarity": r, "dup": dup, "gold": gold})
	_log(slot, bid, out, Time.get_unix_time_from_system() if now < 0.0 else now)
	return out


## Lịch sử quay: appends [param got] to the banner's log with time [param t]
## (unix s), keeping the last gacha.json "history_keep" entries.
func _log(slot: Slot, bid: String, got: Array, t: float) -> void:
	var log: Array = slot.gacha_log.get(bid, [])
	for r: Dictionary in got:
		var e := r.duplicate()
		e["t"] = t
		log.append(e)
	var keep := int(data.get("history_keep", 100))
	if log.size() > keep:
		log = log.slice(log.size() - keep)
	slot.gacha_log[bid] = log


## The banner's pulls, newest first.
static func history(slot: Slot, bid: String) -> Array:
	var log: Array = slot.gacha_log.get(bid, []).duplicate()
	log.reverse()
	return log
