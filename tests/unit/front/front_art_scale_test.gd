extends RefCounted
## Menu heroes draw at whole-number scales: 3.6 drew a 48 px hero with uneven pixel columns, so the
## characters page lost the lines of the user's drawing (user 2026-11-27).

var failures: Array[String] = []


func test_scale_of_is_always_whole() -> void:
	for want in [2.0, 3.0, 3.6, 4.0, 2.5]:
		var k: float = FrontArt.scale_of(null, float(want))
		if k != floorf(k) or k < 1.0:
			failures.append("scale_of(%s) = %s, not a whole number" % [want, k])
