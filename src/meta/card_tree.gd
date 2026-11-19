class_name CardTree
extends RefCounted
## Per-card upgrade trees (design/skill-tree-v2.md, after Last Epoch's skill specialisation): every
## skill card has a free-branching tree of multi-rank nodes bought with Mảnh thẻ (slot.shards).
## A node needs every node in its "requires" at rank >= 1, "requires_points" spent in the card,
## and no node of its "excludes" bought; a card holds at most "max_points". The k-th point spent in a
## card costs cost_base + cost_step * k (k from 0). Resetting a card refunds every shard.
## Ranks become effects like card levels (as_upgrades + levels -> PlayerStats) and statuses (on_hit).
##
## Example:
##   var t := CardTree.load_default()
##   if t.why_not(slot, "blade_arc", "sharp") == "": t.buy(slot, "blade_arc", "sharp")
##   pool.append_array(t.as_upgrades(slot)); levels.merge(t.levels(slot))

const PATH := "res://assets/data/card_trees.json"

var data: Dictionary


func _init(p_data: Dictionary) -> void:
	data = p_data


static func load_default() -> CardTree:
	return CardTree.new(GameData.load_json(PATH))


## Mảnh thẻ a run earns (card_trees.json "shards"): a win gives win_base + win_per_5_stages per 5 stages,
## plus boss per boss killed; every chest opened gives chest, won or lost.
static func shards_for_run(cfg: Dictionary, won: bool, stage: int, bosses: int, chests: int) -> int:
	var n := int(cfg.get("chest", 1)) * chests
	if won:
		n += int(cfg.get("win_base", 3)) + int(cfg.get("win_per_5_stages", 1)) * (stage / 5) + int(cfg.get("boss", 5)) * bosses
	return n


## Cards that have a tree.
func cards() -> Array:
	return data.get("cards", {}).keys()


## The tree of [param card]: {max_points, nodes: [...]} ({} when it has none).
func tree(card: String) -> Dictionary:
	return data.get("cards", {}).get(card, {})


func node(card: String, id: String) -> Dictionary:
	for n: Dictionary in tree(card).get("nodes", []):
		if String(n.get("id", "")) == id:
			return n
	return {}


func rank(slot: Slot, card: String, id: String) -> int:
	return int(slot.card_trees.get(card, {}).get(id, 0))


## Points spent in [param card].
func points(slot: Slot, card: String) -> int:
	var total := 0
	for r: Variant in slot.card_trees.get(card, {}).values():
		total += int(r)
	return total


## Mảnh thẻ the next point in [param card] costs.
func cost(slot: Slot, card: String) -> int:
	return int(data.get("cost_base", 2)) + int(data.get("cost_step", 1)) * points(slot, card)


## "" when a rank of node [param id] can be bought now, else why not (Vietnamese, for the UI).
func why_not(slot: Slot, card: String, id: String) -> String:
	var n := node(card, id)
	if n.is_empty():
		return "Không có nút này"
	if rank(slot, card, id) >= int(n.get("max_rank", 1)):
		return "Đã tối đa"
	if points(slot, card) >= int(tree(card).get("max_points", 99)):
		return "Thẻ đã dùng hết %d điểm" % int(tree(card).get("max_points", 99))
	for req: String in n.get("requires", []):
		if rank(slot, card, req) < 1:
			return "Cần mở " + String(node(card, req).get("name", req)) + " trước"
	var need := int(n.get("requires_points", 0))
	if points(slot, card) < need:
		return "Cần đã dùng %d điểm trong thẻ" % need
	for ex: String in n.get("excludes", []):
		if rank(slot, card, ex) > 0:
			return "Đã chọn " + String(node(card, ex).get("name", ex))
	if slot.shards < cost(slot, card):
		return "Thiếu Mảnh thẻ (cần %d)" % cost(slot, card)
	return ""


## Buys one rank of node [param id]; false (nothing changes) when why_not says no.
func buy(slot: Slot, card: String, id: String) -> bool:
	if why_not(slot, card, id) != "":
		return false
	slot.shards -= cost(slot, card)
	var t: Dictionary = slot.card_trees.get(card, {})
	t[id] = rank(slot, card, id) + 1
	slot.card_trees[card] = t
	return true


## Mảnh thẻ spent in [param card] (what a reset gives back).
func spent(slot: Slot, card: String) -> int:
	var total := 0
	for k in points(slot, card):
		total += int(data.get("cost_base", 2)) + int(data.get("cost_step", 1)) * k
	return total


## Clears [param card]'s tree and refunds every shard spent on it.
func reset(slot: Slot, card: String) -> void:
	slot.shards += spent(slot, card)
	slot.card_trees.erase(card)


## Every bought node as an upgrade (id "card.<card>.<node>") for PlayerStats; levels() gives its rank.
func as_upgrades(slot: Slot) -> Array:
	var out := []
	for card: String in slot.card_trees:
		for id: String in slot.card_trees[card]:
			var n := node(card, id)
			if not n.is_empty():
				out.append({"id": "card.%s.%s" % [card, id], "name": n.get("name", id), "kind": "card_tree",
					"effects": n.get("effects", {})})
	return out


func levels(slot: Slot) -> Dictionary:
	var out := {}
	for card: String in slot.card_trees:
		for id: String in slot.card_trees[card]:
			out["card.%s.%s" % [card, id]] = int(slot.card_trees[card][id])
	return out


## Statuses the bought nodes of [param card] add to its hits ({status, ...} like a skill's on_hit).
func on_hit(slot: Slot, card: String) -> Array:
	var out := []
	for id: String in slot.card_trees.get(card, {}):
		if int(slot.card_trees[card][id]) > 0:
			out.append_array(node(card, id).get("on_hit", []))
	return out
