extends RefCounted
## Regression (user 2026-11-20 "hiệu ứng của các buff mới vẫn chưa làm"): the run loaded the special effect
## sprites from items.json equipment specials, which moved to cards, so no ward / shock effect was drawn.
## Every special card's fx must be among the sprites the run loads, and each must exist on disk.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_every_special_card_fx_is_loaded() -> void:
	for cls in ["knight", "mage"]:
		var r: Node = Run.new()
		r.pool = GameData.load_json("res://assets/data/upgrades_%s.json" % cls)
		var loaded: Array = r.special_fx_sprites()
		for u: Dictionary in r.pool["upgrades"]:
			if u.has("special") and u["special"].has("fx"):
				var fx := String(u["special"]["fx"])
				_check(loaded.has(fx), "%s: %s fx %s is loaded" % [cls, u["id"], fx])
				_check(FileAccess.file_exists("res://assets/sprites/custom/%s/%s.json" % [fx, fx]), "%s sprite exists" % fx)
		r.free()
