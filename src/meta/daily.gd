class_name Daily
extends RefCounted
## Nhiệm vụ ngày (design/missions.md): per slot, per_day missions a day from
## assets/data/missions.json, picked from the date and the slot id (the same all
## day, new at local midnight). Progress is counters (stats) the game adds to;
## each finished mission is claimed for gems, all claimed unlock a bonus.
## State lives in Slot.daily: {date, ids, stats, claimed, bonus}.
##
## Example:
##   var d := Daily.load_default()
##   d.add(slot, "kills", 120)
##   if d.claim(slot, "slayer"): save(slot)

const DATA := "res://assets/data/missions.json"

var data: Dictionary


static func load_default() -> Daily:
	var d := Daily.new()
	d.data = GameData.load_json(DATA)
	return d


## "2026-11-18" for local time now ([param unix] for tests).
static func today(unix := -1.0) -> String:
	if unix >= 0.0:
		return Time.get_date_string_from_unix_time(int(unix))
	return Time.get_date_string_from_system()


func pool() -> Array:
	return data.get("pool", [])


func mission(id: String) -> Dictionary:
	for m: Dictionary in pool():
		if String(m["id"]) == id:
			return m
	return {}


## Today's missions for [param slot] (rolled once a day; a new day resets progress).
func ensure(slot: Slot, date := "") -> Array:
	if date == "":
		date = today()
	if String(slot.daily.get("date", "")) != date:
		var ids: Array = []
		for m: Dictionary in pool():
			ids.append(String(m["id"]))
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(slot.id + "/" + date)
		var picked: Array = []
		while picked.size() < mini(int(data.get("per_day", 4)), ids.size()):
			picked.append(ids.pop_at(rng.randi() % ids.size()))
		slot.daily = {"date": date, "ids": picked, "stats": {}, "claimed": [], "bonus": false}
	return slot.daily["ids"]


## Adds [param n] to counter [param stat] for today.
func add(slot: Slot, stat: String, n: int, date := "") -> void:
	if n <= 0:
		return
	ensure(slot, date)
	var st: Dictionary = slot.daily["stats"]
	st[stat] = int(st.get(stat, 0)) + n


func progress(slot: Slot, id: String) -> int:
	var m := mission(id)
	return mini(int(slot.daily.get("stats", {}).get(String(m.get("stat", "")), 0)), int(m.get("target", 1)))


func done(slot: Slot, id: String) -> bool:
	return progress(slot, id) >= int(mission(id).get("target", 1))


func claimed(slot: Slot, id: String) -> bool:
	return slot.daily.get("claimed", []).has(id)


## Pays a finished, unclaimed mission of today. True when paid.
func claim(slot: Slot, id: String) -> bool:
	if not slot.daily.get("ids", []).has(id) or not done(slot, id) or claimed(slot, id):
		return false
	slot.daily["claimed"].append(id)
	slot.gems += int(mission(id).get("gems", 0))
	return true


func bonus_ready(slot: Slot) -> bool:
	var ids: Array = slot.daily.get("ids", [])
	return not ids.is_empty() and not bool(slot.daily.get("bonus", false)) \
		and ids.all(func(id: String) -> bool: return claimed(slot, id))


## Pays the all-claimed bonus once a day.
func claim_bonus(slot: Slot) -> bool:
	if not bonus_ready(slot):
		return false
	slot.daily["bonus"] = true
	slot.gems += int(data.get("bonus_gems", 0))
	return true


## Missions finished and not yet claimed (a badge on the lobby button).
func ready_count(slot: Slot) -> int:
	var n := 0
	for id: String in slot.daily.get("ids", []):
		if done(slot, id) and not claimed(slot, id):
			n += 1
	return n + (1 if bonus_ready(slot) else 0)
