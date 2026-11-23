extends RefCounted
## Album (roadmap 5): kills by monster id are kept in the slot and survive a save/load.

var failures: Array[String] = []


func test_kills_add_up_and_round_trip() -> void:
	var s := Slot.new({})
	s.record_kills({"slime": 3, "wolf": 1})
	s.record_kills({"slime": 2})
	var t := Slot.new({})
	var d := s.to_dict()
	d["version"] = Slot.VERSION
	t.from_dict(d)
	if int(t.bestiary.get("slime", 0)) != 5 or int(t.bestiary.get("wolf", 0)) != 1:
		failures.append("bestiary after load: %s" % [t.bestiary])
