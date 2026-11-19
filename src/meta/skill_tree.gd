class_name SkillTree
extends RefCounted
## The character tree v2 (assets/data/skill_tree.json, design/skill-tree-v2.md §1): per class a grid of
## multi-rank nodes bought with Tinh hoa; a rank of a node costs row_cost[row], needs every node in
## "requires" at rank >= 1, "requires_points" spent in the tree, and no node of "excludes" bought.
## slot.tree lists node ids, one entry per rank bought. A reset takes 1 Tẩy Tủy Đan + gold and refunds
## every Tinh hoa; v1 node ids in old saves are refunded by migrate(). Ranks are levels for PlayerStats.
##
## Example:
##   var t := SkillTree.load_default()
##   if t.why_not(slot, "k_root") == "": t.buy(slot, "k_root")
##   PlayerStats.compute(base, pool + t.as_upgrades(slot), levels.merged(t.levels(slot)))

const PATH := "res://assets/data/skill_tree.json"

var data: Dictionary
var _nodes := {}   # node id -> {node..., "class"}


func _init(p_data: Dictionary) -> void:
	data = p_data
	for cls: String in data.get("classes", {}):
		for raw: Dictionary in data["classes"][cls]:
			var n: Dictionary = raw.duplicate()
			n["class"] = cls
			_nodes[String(n["id"])] = n


static func load_default() -> SkillTree:
	return SkillTree.new(GameData.load_json(PATH))


## The nodes of [param cls] (each {id, name, desc, col, row, max_rank, icon, effects, ...}).
func nodes(cls: String) -> Array:
	return data.get("classes", {}).get(cls, [])


func node(id: String) -> Dictionary:
	return _nodes.get(id, {})


## Tinh hoa one rank of node [param id] costs (row_cost by its row).
func cost(id: String) -> int:
	var rows: Array = data.get("row_cost", [3])
	return int(rows[clampi(int(node(id).get("row", 0)), 0, rows.size() - 1)])


func rank(slot: Slot, id: String) -> int:
	return slot.tree.count(id)


## Ranks bought in the tree.
func points(slot: Slot) -> int:
	var total := 0
	for id: String in slot.tree:
		if _nodes.has(id):
			total += 1
	return total


## "" when [param slot] can buy a rank of node [param id], else why not (Vietnamese, shown on screen).
func why_not(slot: Slot, id: String) -> String:
	var n := node(id)
	if n.is_empty() or String(n["class"]) != slot.cls:
		return "Không thuộc cây của lớp này."
	if rank(slot, id) >= int(n.get("max_rank", 1)):
		return "Đã tối đa."
	for req: String in n.get("requires", []):
		if rank(slot, req) < 1:
			return "Cần mở %s trước." % String(node(req).get("name", req))
	var need := int(n.get("requires_points", 0))
	if points(slot) < need:
		return "Cần đã dùng %d điểm trong cây (đang %d)." % [need, points(slot)]
	for ex: String in n.get("excludes", []):
		if rank(slot, ex) > 0:
			return "Đã chọn %s." % String(node(ex).get("name", ex))
	if slot.essence < cost(id):
		return "Cần %d Tinh hoa (đang có %d)." % [cost(id), slot.essence]
	return ""


func buy(slot: Slot, id: String) -> bool:
	if why_not(slot, id) != "":
		return false
	slot.essence -= cost(id)
	slot.tree.append(id)
	return true


## Tinh hoa spent on the tree (what a reset gives back).
func spent(slot: Slot) -> int:
	var total := 0
	for id: String in slot.tree:
		if _nodes.has(id):
			total += cost(id)
	return total


## Refunds v1 node ids (legacy_refund) still in an old save and drops them; true when anything changed.
func migrate(slot: Slot) -> bool:
	var legacy: Dictionary = data.get("legacy_refund", {})
	var keep := []
	var changed := false
	for id: String in slot.tree:
		if _nodes.has(id):
			keep.append(id)
		else:
			slot.essence += int(legacy.get(id, 0))
			changed = true
	if changed:
		slot.tree.assign(keep)
	return changed


## {pills, gold} a reset takes now.
func reset_cost(slot: Slot) -> Dictionary:
	var gold := maxi(int(data.get("reset_gold_min", 50)), int(data.get("reset_gold_per_essence", 10)) * spent(slot))
	return {"pills": 1, "gold": gold}


func why_not_reset(slot: Slot) -> String:
	if slot.tree.is_empty():
		return "Chưa mở nút nào."
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


## Bought nodes as upgrade entries ({id "tree.<node>", name, kind "tree", effects}); levels() gives ranks.
func as_upgrades(slot: Slot) -> Array:
	var out := []
	var seen := {}
	for id: String in slot.tree:
		var n := node(id)
		if not n.is_empty() and not seen.has(id):
			seen[id] = true
			out.append({"id": "tree." + id, "name": n.get("name", id), "kind": "tree", "effects": n.get("effects", {})})
	return out


func levels(slot: Slot) -> Dictionary:
	var out := {}
	for id: String in slot.tree:
		if _nodes.has(id):
			out["tree." + id] = int(out.get("tree." + id, 0)) + 1
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
			ups.append({"id": id, "name": d.get("name", id), "kind": "item", "effects": slot.profile.effects_of(id)})
			lv[id] = 1
	var t := load_default()
	t.migrate(slot)
	ups.append_array(t.as_upgrades(slot))
	lv.merge(t.levels(slot), true)
	return [ups, lv]

