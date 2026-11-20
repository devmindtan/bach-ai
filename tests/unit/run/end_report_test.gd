extends RefCounted
## Regression (user 2026-11-20 screenshot of "Vượt ải 17"): the damage table hugged the panel's left edge
## (right side empty), and the event row "Mưa thiên thạch" (event.meteor) had no icon and the same name
## as the mage skill. The table is centred; every row has an icon; event rows say they are an event.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_event_rows_have_an_icon_and_an_event_name_and_the_table_is_centred() -> void:
	var r: Node = Run.new()
	r.cfg = GameData.load_json("res://assets/data/run_config.json")
	r.pool = GameData.load_json("res://assets/data/upgrades_mage.json")
	var monsters := {"blob": {"sprite": "blob", "behaviour": "chase", "hp": 10.0, "damage": 1.0, "speed": 0.0, "xp": 1.0, "scale": 2}}
	var blob := SpriteSheet.from_meta("blob", {"frames": 1, "frame_size": [24, 24], "fps": 8.0, "anchor": [12.0, 12.0],
		"body": {"anim": "default", "center": [12.0, 12.0], "radius": 6.0}})
	r.enemies = Enemies.new(monsters, {"max_enemies": 4, "separation": {"push": 0.0}}, {"blob": blob}, 1)
	r.enemies.damage_by = {"arcane_bolt": 100.0, "event.meteor": 20.0}
	var rows: Array = r.damage_report()
	for row: Dictionary in rows:
		_check(r.icon_texture(String(row.get("icon", row["id"]))) != null, "row %s has an icon" % row["id"])
		if row["id"] == "event.meteor":
			_check(String(row["name"]).begins_with("Sự kiện"), "event row named as an event, got %s" % row["name"])
	var p := RunPanels.new()
	p.run = r
	var g: Control = p._damage_table(rows)
	_check(g.size_flags_horizontal == Control.SIZE_SHRINK_CENTER, "the table is centred in the panel")
	g.free()
	p.free()
	r.enemies = null
	r.free()
