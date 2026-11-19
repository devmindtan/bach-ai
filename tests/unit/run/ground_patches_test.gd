extends RefCounted
## Nền theo vùng (design/regions.md, 6B.3): each region lays terrain patches (forest dirt, marsh water,
## meadow clover) in clusters over the tile grid, so the floors differ in shape, not only in colour.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_patches_cover_about_their_share_in_clusters() -> void:
	var on := 0
	var same_neighbour := 0
	var pairs := 0
	for y in range(-40, 40):
		for x in range(-40, 40):
			var a := RunGround.patch_at(x, y, 0.25)
			if a:
				on += 1
				pairs += 1
				if RunGround.patch_at(x + 1, y, 0.25):
					same_neighbour += 1
	var share := float(on) / 6400.0
	_check(share > 0.15 and share < 0.35, "about 25%% of tiles are patch, got %.2f" % share)
	_check(float(same_neighbour) / maxf(1.0, pairs) > 0.5, "patches cluster: a patch tile's right neighbour is usually patch too (%.2f)" % (float(same_neighbour) / maxf(1.0, pairs)))
	_check(RunGround.patch_at(3, 7, 0.25) == RunGround.patch_at(3, 7, 0.25), "the same tile every frame")
	_check(not RunGround.patch_at(3, 7, 0.0), "share 0: no patches")


func test_each_region_lays_its_own_patches() -> void:
	var differ := 0
	for y in range(-20, 20):
		for x in range(-20, 20):
			if RunGround.patch_at(x, y, 0.3, 1) != RunGround.patch_at(x, y, 0.3, 2):
				differ += 1
	_check(differ > 200, "two regions' layouts differ on many tiles, got %d of 1600" % differ)
