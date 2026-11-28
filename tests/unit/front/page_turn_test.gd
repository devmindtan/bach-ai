extends RefCounted
## The page turn (design-web journalFlip): the leaf closes over the right page to the spine, then opens over the left.

var failures: Array[String] = []


func test_leaf_starts_on_right_page_and_ends_on_left() -> void:
	var first := PageTurn.leaf_at(1)
	var last := PageTurn.leaf_at(PageTurn.STEPS - 1)
	if first.y != PageTurn.HALF:
		failures.append("step 1 leaf left %s, want the spine %s" % [first.y, PageTurn.HALF])
	if last.y + last.x != PageTurn.HALF:
		failures.append("last step leaf ends at %s, want the spine" % (last.y + last.x))
	for k in range(1, PageTurn.STEPS):
		var w := PageTurn.leaf_at(k).x
		if w != floorf(w) or w < 4.0:
			failures.append("step %d width %s: not a whole pixel >= 4" % [k, w])


func test_every_journal_scene_exists() -> void:
	for p: String in PageTurn.SCENES:
		if not ResourceLoader.exists(p):
			failures.append("missing scene " + p)
