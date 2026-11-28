extends RefCounted
## Notice.ask (web screen-notices): a key the player ticked "Không hỏi lại" for runs the action at once.

var failures: Array[String] = []


func test_skipped_key_runs_action_without_slip() -> void:
	var prefs := Prefs.current()
	var before: Array = prefs.skip_confirm.duplicate()
	prefs.skip_confirm = ["reset_tree"]
	var ran := [false]
	Notice.ask("reset_tree", "t", "x", "", "Tẩy tuỷ", func() -> void: ran[0] = true)
	if not ran[0]:
		failures.append("a skipped confirm did not run its action")
	prefs.skip_confirm = before


func test_unknown_key_is_not_skipped() -> void:
	if Notice.skipped("no_such_key_for_test"):
		failures.append("an unticked key reads as skipped")
