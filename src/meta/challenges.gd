class_name Challenges
extends RefCounted
## Challenge mode (assets/data/challenges.json, design/challenge.md): challenges
## unlocked by stage progress, each built from a stage with its own rules, a win
## giving Tẩy Tủy Đan (more the first time) and the base stage's gold, never stage
## progress.
##
## Example:
##   var c := Challenges.load_default()
##   if c.is_open(slot, "bat_night"): var stage := c.build("bat_night")

const PATH := "res://assets/data/challenges.json"

var data: Dictionary


func _init(p_data: Dictionary) -> void:
	data = p_data


static func load_default() -> Challenges:
	return Challenges.new(GameData.load_json(PATH))


func ids() -> Array[String]:
	var out: Array[String] = []
	for c: Dictionary in data.get("challenges", []):
		out.append(String(c["id"]))
	return out


func get_def(id: String) -> Dictionary:
	for c: Dictionary in data.get("challenges", []):
		if String(c["id"]) == id:
			return c
	return {}


## The stage a slot must have won to open the mode (the lowest unlock).
func mode_unlock() -> int:
	var lo := 999
	for c: Dictionary in data.get("challenges", []):
		lo = mini(lo, int(c.get("unlock", 10)))
	return lo


func mode_open(slot: Slot) -> bool:
	return slot != null and slot.best >= mode_unlock()


func is_open(slot: Slot, id: String) -> bool:
	return slot != null and slot.best >= int(get_def(id).get("unlock", 999))


## The challenge as a stage to play: its base stage (scaled for that stage) with
## its rules applied, plus "challenge", "hp_mul", "win_on_boss".
func build(id: String) -> Dictionary:
	var c := get_def(id)
	var stages := Stages.load_default()
	var base := int(c.get("base", 1))
	var st := stages.load_stage(base)
	var dur := float(c.get("duration", st.get("duration", 300.0)))
	var drop: Array = c.get("drop", [])
	var rate_mul: Dictionary = c.get("rate_mul", {})
	var waves := []
	for w: Dictionary in st.get("waves", []):
		var m := String(w.get("monster", ""))
		if drop.has(m) or float(w.get("t_from", 0.0)) > dur:
			continue
		var x := w.duplicate()
		if rate_mul.has(m):
			for k in ["rate", "rate_end"]:
				if x.has(k):
					x[k] = float(x[k]) * float(rate_mul[m])
		waves.append(x)
	for w: Dictionary in c.get("add", []):
		waves.append(w.duplicate())
	var ev: Dictionary = c.get("every", {})
	if not ev.is_empty():
		var t := float(ev.get("from", ev.get("every", 20.0)))
		while t < dur:
			waves.append({"monster": ev["monster"], "t_from": t, "t_to": t, "burst": int(ev.get("burst", 1))})
			t += float(ev.get("every", 20.0))
	st["waves"] = waves
	st["duration"] = dur
	st["name"] = String(c.get("name", id))
	st["challenge"] = id
	st["hp_mul"] = float(c.get("hp_mul", 1.0))
	st["win_on_boss"] = bool(c.get("win_on_boss", true))
	st["boss"] = false
	for w: Dictionary in waves:
		if String(w.get("monster", "")) == "king_slime":
			st["boss"] = true
	return st


## A win of challenge [param id]: Tẩy Tủy Đan (pills_first the first time, else
## pills) and the base stage's gold go to the slot. Returns {pills, gold, first}.
func record_win(slot: Slot, id: String) -> Dictionary:
	var first := int(slot.challenge_wins.get(id, 0)) == 0
	slot.challenge_wins[id] = int(slot.challenge_wins.get(id, 0)) + 1
	var pills := int(data.get("pills_first", 2)) if first else int(data.get("pills", 1))
	slot.pills += pills
	var gold := int(Stages.load_default().rewards(int(get_def(id).get("base", 1)), false)["gold"])
	slot.gold += gold
	return {"pills": pills, "gold": gold, "first": first}
