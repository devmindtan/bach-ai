class_name Slot
extends RefCounted
## One character slot (design/progression.md): name, class (fixed), progress
## (highest stage won, wins per stage), gold and gems, equipment (a Profile).
## Milestone rewards are not kept: they belong to one run. Saved by SlotStore as
## user://slots/<id>.json with a schema version.
##
## Example:
##   var r := slot.record_win(10, Stages.load_default())   # {gold, gems, first}

const VERSION := 1

var id := ""
var name := ""
var cls := "knight"
var best := 0                 # highest stage won
var wins := {}                # "n" -> times won
var gold := 0
var gems := 0
var profile: Profile


func _init(equipment_defs: Dictionary) -> void:
	profile = Profile.new(equipment_defs)


## Highest stage this slot may play: one past the best win, at most [param stage_count].
func unlocked(stage_count: int) -> int:
	return clampi(best + 1, 1, stage_count)


func won(n: int) -> bool:
	return int(wins.get(str(n), 0)) > 0


## Records a win of stage [param n]: progress, gold and gems. Returns {gold, gems, first}.
func record_win(n: int, stages: Stages) -> Dictionary:
	var first := not won(n)
	wins[str(n)] = int(wins.get(str(n), 0)) + 1
	best = maxi(best, n)
	var r := stages.rewards(n, first)
	gold += int(r["gold"])
	gems += int(r["gems"])
	r["first"] = first
	return r


func to_dict() -> Dictionary:
	return {"version": VERSION, "id": id, "name": name, "class": cls, "best": best, "wins": wins,
		"gold": gold, "gems": gems, "profile": profile.to_dict()}


## Fills the slot from [param d]; returns "" or why it cannot be read.
func from_dict(d: Dictionary) -> String:
	var v := int(d.get("version", 0))
	if v < 1:
		return "không có phiên bản"
	if v > VERSION:
		return "phiên bản mới hơn (%d)" % v
	id = String(d.get("id", ""))
	name = String(d.get("name", ""))
	cls = String(d.get("class", "knight"))
	best = int(d.get("best", 0))
	wins = d.get("wins", {})
	gold = int(d.get("gold", 0))
	gems = int(d.get("gems", 0))
	profile.from_dict(d.get("profile", {}))
	return ""
