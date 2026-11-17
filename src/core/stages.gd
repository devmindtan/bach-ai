class_name Stages
extends RefCounted
## The stage list and its difficulty curve (assets/data/stages.json,
## design/progression.md): monster hp / damage / spawn-rate multipliers per
## stage, regions, boss stages, which wave file a stage plays, win rewards.
##
## Example:
##   var s := Stages.load_default()
##   var stage := s.load_stage(12)          # waves scaled for stage 12
##   enemies.scale_kinds(s.hp_mul(12), s.damage_mul(12))

const PATH := "res://assets/data/stages.json"
const WAVES := "res://assets/data/waves/"

var data: Dictionary


func _init(p_data: Dictionary) -> void:
	data = p_data


static func load_default() -> Stages:
	return Stages.new(GameData.load_json(PATH))


func count() -> int:
	return int(data.get("count", 30))


func _k(key: String) -> float:
	return float(data.get("scale", {}).get(key, 0.0))


## Monster hp multiplier: 1 + hp_lin*(n-1) + hp_quad*(n-1)^2.
func hp_mul(n: int) -> float:
	var m := float(maxi(0, n - 1))
	return 1.0 + _k("hp_lin") * m + _k("hp_quad") * m * m


## Monster damage multiplier: 1 + dmg_lin*(n-1).
func damage_mul(n: int) -> float:
	return 1.0 + _k("dmg_lin") * float(maxi(0, n - 1))


## Spawn rate multiplier: min(rate_max, 1 + rate_lin*(n-1)).
func rate_mul(n: int) -> float:
	return minf(maxf(1.0, _k("rate_max")), 1.0 + _k("rate_lin") * float(maxi(0, n - 1)))


## Every boss_every-th stage has a boss.
func is_boss(n: int) -> bool:
	var every := int(data.get("boss_every", 10))
	return every > 0 and n % every == 0


## The region of stage [param n] ({id, name, from, to, waves, boss_waves, ground}).
func region(n: int) -> Dictionary:
	for r: Dictionary in data.get("regions", []):
		if n >= int(r.get("from", 0)) and n <= int(r.get("to", 0)):
			return r
	var all: Array = data.get("regions", [])
	return all.back() if not all.is_empty() else {}


## All regions, in stage order (the grid of 3 vùng × 10 ải).
func regions() -> Array:
	return data.get("regions", [])


## The palette a stage's region draws its floor with (stages.json "ground").
func ground(n: int) -> Dictionary:
	var r := region(n)
	return r.get("ground", {})


## The wave file stage [param n] plays: waves/stage_NNN.json when it exists, else
## its region's waves (boss stages: boss_waves).
func waves_path(n: int) -> String:
	var own := WAVES + "stage_%03d.json" % n
	if FileAccess.file_exists(own):
		return own
	var r := region(n)
	return WAVES + String(r.get("boss_waves" if is_boss(n) else "waves", "stage_001")) + ".json"


## Stage [param n] ready to play: its wave file with rates (and big bursts)
## scaled by rate_mul, plus number, name, region and boss.
func load_stage(n: int) -> Dictionary:
	var st := GameData.load_json(waves_path(n))
	st["number"] = n
	st["region"] = String(region(n).get("name", ""))
	if not is_boss(n):
		st["name"] = st["region"]
	st["boss"] = is_boss(n)
	st["waves"] = scale_waves(st.get("waves", []), rate_mul(n))
	return st


## [param waves] with rate / rate_end multiplied by [param mul]; bursts of more
## than 3 monsters too (single elites and bosses stay as they are).
static func scale_waves(waves: Array, mul: float) -> Array:
	var out := []
	for w: Dictionary in waves:
		var c := w.duplicate()
		if c.has("rate"):
			c["rate"] = float(c["rate"]) * mul
		if c.has("rate_end"):
			c["rate_end"] = float(c["rate_end"]) * mul
		if c.has("burst") and int(c["burst"]) > 3:
			c["burst"] = roundi(float(c["burst"]) * mul)
		out.append(c)
	return out


## What winning stage [param n] gives: {gold, gems}; [param first] = first win.
func rewards(n: int, first: bool) -> Dictionary:
	var r: Dictionary = data.get("rewards", {})
	var gems := int(r.get("gems_repeat", 0))
	if first:
		gems = int(r.get("gems_boss_first" if is_boss(n) else "gems_first", 0))
	return {"gold": int(r.get("gold_base", 0)) + int(r.get("gold_per_stage", 0)) * n, "gems": gems}
