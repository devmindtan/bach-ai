class_name SkillTree
extends RefCounted
## The long-term skill tree (assets/data/skill_tree.json, design/skill-tree.md):
## per class 3 branches x 3 tiers bought once each with Tinh hoa, a tier needing
## the one before; a reset takes 1 Tẩy Tủy Đan + gold and refunds every Tinh hoa;
## bought nodes are level-1 upgrades for PlayerStats. State lives on the Slot
## (essence, pills, gold, tree).
##
## Example:
##   var t := SkillTree.load_default()
##   if t.why_not(slot, "k_fury_1") == "": t.buy(slot, "k_fury_1")
##   PlayerStats.compute(base, pool + t.as_upgrades(slot), levels.merged(t.levels(slot)))

const PATH := "res://assets/data/skill_tree.json"

var data: Dictionary
var _nodes := {}   # node id -> {node..., "class", "branch", "tier"}


func _init(p_data: Dictionary) -> void:
	data = p_data
	for cls: String in data.get("classes", {}):
		for b: Dictionary in data["classes"][cls]:
			var nodes: Array = b.get("nodes", [])
			for i in nodes.size():
				var n: Dictionary = nodes[i].duplicate()
				n["class"] = cls
				n["branch"] = String(b.get("id", ""))
				n["tier"] = i + 1
				_nodes[String(n["id"])] = n


static func load_default() -> SkillTree:
	return SkillTree.new(GameData.load_json(PATH))


func branches(cls: String) -> Array:
	return data.get("classes", {}).get(cls, [])


func node(id: String) -> Dictionary:
	return _nodes.get(id, {})


func cost(id: String) -> int:
	var tiers: Array = data.get("tier_cost", [5, 10, 20])
	var t := int(node(id).get("tier", 1))
	return int(tiers[clampi(t - 1, 0, tiers.size() - 1)])


## "" when [param slot] can buy node [param id], else why not (Vietnamese, shown on screen).
func why_not(slot: Slot, id: String) -> String:
	var n := node(id)
	if n.is_empty() or String(n["class"]) != slot.cls:
		return "Không thuộc cây của class này."
	if slot.tree.has(id):
		return "Đã mở."
	var t := int(n["tier"])
	if t > 1:
		var before := _id_at(String(n["class"]), String(n["branch"]), t - 1)
		if not slot.tree.has(before):
			return "Cần mở %s trước." % String(node(before).get("name", before))
	if slot.essence < cost(id):
		return "Cần %d Tinh hoa (đang có %d)." % [cost(id), slot.essence]
	return ""


func buy(slot: Slot, id: String) -> bool:
	if why_not(slot, id) != "":
		return false
	slot.essence -= cost(id)
	slot.tree.append(id)
	return true


func spent(slot: Slot) -> int:
	var total := 0
	for id: String in slot.tree:
		total += cost(id)
	return total


## {pills, gold} a reset takes now.
func reset_cost(slot: Slot) -> Dictionary:
	var gold := maxi(int(data.get("reset_gold_min", 50)), int(data.get("reset_gold_per_essence", 10)) * spent(slot))
	return {"pills": 1, "gold": gold}


func why_not_reset(slot: Slot) -> String:
	if slot.tree.is_empty():
		return "Chưa mở node nào."
	var c := reset_cost(slot)
	if slot.pills < int(c["pills"]):
		return "Cần 1 Tẩy Tủy Đan (thắng một thử thách)."
	if slot.gold < int(c["gold"]):
		return "Cần %d vàng (đang có %d)." % [int(c["gold"]), slot.gold]
	return ""


## Takes the pill and the gold, gives back every Tinh hoa spent, clears the tree.
func reset(slot: Slot) -> bool:
	if why_not_reset(slot) != "":
		return false
	var c := reset_cost(slot)
	slot.essence += spent(slot)
	slot.pills -= int(c["pills"])
	slot.gold -= int(c["gold"])
	slot.tree.clear()
	return true


## Bought nodes as upgrade entries ({id, name, kind "tree", effects}) for PlayerStats.
func as_upgrades(slot: Slot) -> Array:
	var out := []
	for id: String in slot.tree:
		var n := node(id)
		if not n.is_empty():
			out.append({"id": "tree." + id, "name": n.get("name", id), "kind": "tree", "effects": n.get("effects", {})})
	return out


func levels(slot: Slot) -> Dictionary:
	var out := {}
	for u: Dictionary in as_upgrades(slot):
		out[u["id"]] = 1
	return out


## A slot's lasting upgrades for PlayerStats: worn equipment + bought nodes,
## as [upgrades, levels] (lobby, character and equipment screens; the run adds cards).
## [param worn] overrides what is worn ({slot: item id}) for "what if" comparisons.
static func lasting(slot: Slot, worn = null) -> Array:
	var ups := []
	var lv := {}
	if worn == null:
		ups.append_array(slot.profile.as_upgrades(slot.cls))
		lv.merge(slot.profile.levels(slot.cls), true)
	else:
		for k: String in worn:
			var id := String(worn[k])
			var d: Dictionary = slot.profile.defs.get(id, {})
			ups.append({"id": id, "name": d.get("name", id), "kind": "item", "effects": d.get("effects", {})})
			lv[id] = 1
	var t := load_default()
	ups.append_array(t.as_upgrades(slot))
	lv.merge(t.levels(slot), true)
	return [ups, lv]


func _id_at(cls: String, branch: String, tier: int) -> String:
	for b: Dictionary in branches(cls):
		if String(b.get("id", "")) == branch:
			var nodes: Array = b.get("nodes", [])
			if tier - 1 < nodes.size():
				return String(nodes[tier - 1]["id"])
	return ""
