class_name Deck
extends RefCounted
## Decks (design/skill-tree-v2.md §2): before a run the player picks up to cfg.skills skill cards and
## cfg.stats stat cards from the class's cards; the class's starting skills are always in; unique skills
## (level milestones) are never deck cards. A run offers only the active deck's cards (filter).
## A slot keeps up to cfg.slots decks ({name, cards}); with none saved, the default deck is used.
##
## Example:
##   var cards := Deck.active(slot, pool["upgrades"], class_data["start_skills"], cfg)
##   var offer_pool := Deck.filter(pool["upgrades"], cards)


static func _card(ups: Array, id: String) -> Dictionary:
	for u: Dictionary in ups:
		if String(u.get("id", "")) == id:
			return u
	return {}


## True for cards a deck holds: skill / stat cards that are not unique.
static func is_deck_card(u: Dictionary) -> bool:
	return String(u.get("kind", "")) in ["skill", "stat"] and not bool(u.get("unique", false))


static func count(cards: Array, ups: Array, kind: String) -> int:
	var n := 0
	for id: String in cards:
		if String(_card(ups, id).get("kind", "")) == kind:
			n += 1
	return n


## The default deck: the starting skills, then the heaviest other skills and stats up to the caps.
static func default_cards(ups: Array, start: Array, cfg: Dictionary) -> Array:
	var out: Array = start.duplicate()
	var sorted := ups.filter(func(u: Dictionary) -> bool: return is_deck_card(u))
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("weight", 1)) > float(b.get("weight", 1)))
	for u: Dictionary in sorted:
		var id := String(u["id"])
		if not out.has(id) and why_not_add(out, ups, id, cfg) == "":
			out.append(id)
	return out


## "" when [param id] can join [param cards], else why not (Vietnamese).
static func why_not_add(cards: Array, ups: Array, id: String, cfg: Dictionary) -> String:
	var u := _card(ups, id)
	if u.is_empty() or not is_deck_card(u):
		return "Thẻ này không vào bộ thẻ được"
	if cards.has(id):
		return "Đã có trong bộ"
	var kind := String(u["kind"])
	var cap := int(cfg.get("skills" if kind == "skill" else "stats", 8))
	if count(cards, ups, kind) >= cap:
		return "Bộ đã đủ %d thẻ %s" % [cap, "chiêu" if kind == "skill" else "chỉ số"]
	var budget := int(cfg.get("budget", -1))
	if budget >= 0 and points(cards, ups, cfg) + cost(u, cfg) > budget:   # design/card-rarity.md
		return "Vượt điểm bộ thẻ (%d / %d)" % [points(cards, ups, cfg) + cost(u, cfg), budget]
	return ""


## Deck points of card [param u] (cfg.cost by rarity; commons and untagged cards are free).
static func cost(u: Dictionary, cfg: Dictionary) -> int:
	return int(cfg.get("cost", {}).get(String(u.get("rarity", "common")), 0))


## Deck points [param cards] use (design/card-rarity.md: the budget that keeps a deck from being all rares).
static func points(cards: Array, ups: Array, cfg: Dictionary) -> int:
	var n := 0
	for id: String in cards:
		n += cost(_card(ups, id), cfg)
	return n


## [param cards] trimmed to the budget: the costliest non-starting cards leave first (decks saved
## before the budget existed).
static func within_budget(cards: Array, ups: Array, start: Array, cfg: Dictionary) -> Array:
	var budget := int(cfg.get("budget", -1))
	var out := cards.duplicate()
	if budget < 0:
		return out
	while points(out, ups, cfg) > budget:
		var worst := ""
		var hi := 0
		for id: String in out:
			var c := cost(_card(ups, id), cfg)
			if not start.has(id) and c > hi:
				hi = c
				worst = id
		if worst == "":
			break
		out.erase(worst)
	return out


static func why_not_remove(cards: Array, id: String, start: Array) -> String:
	if start.has(id):
		return "Chiêu khởi đầu luôn có trong bộ"
	if not cards.has(id):
		return "Không có trong bộ"
	return ""


static func remove(cards: Array, id: String, start: Array) -> Array:
	var out := cards.duplicate()
	if why_not_remove(cards, id, start) == "":
		out.erase(id)
	return out


## The cards of [param slot]'s active deck, or the default deck when none is saved.
static func active(slot: Slot, ups: Array, start: Array, cfg: Dictionary) -> Array:
	if slot != null and slot.deck_active >= 0 and slot.deck_active < slot.decks.size():
		var cards: Array = slot.decks[slot.deck_active].get("cards", [])
		if not cards.is_empty():
			return within_budget(cards, ups, start, cfg)
	return default_cards(ups, start, cfg)


## The run's card pool: deck cards plus every non-deck card (unique skills come from milestones).
static func filter(ups: Array, cards: Array) -> Array:
	return ups.filter(func(u: Dictionary) -> bool: return not is_deck_card(u) or cards.has(String(u.get("id", ""))))
