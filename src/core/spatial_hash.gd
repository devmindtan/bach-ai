class_name SpatialHash
extends RefCounted
## Uniform grid for "who is near this point" queries over many moving points
## (hundreds of enemies), rebuilt every frame. Cheaper than a physics body each.
##
## Example:
##   hash.clear(); for i in n: hash.insert(i, positions[i])
##   hash.query(player_pos, 80.0, result)   # indices of points within 80 px (by cell)

var cell: float
var _cells := {}   # Vector2i -> PackedInt32Array


func _init(p_cell: float) -> void:
	cell = maxf(1.0, p_cell)


func clear() -> void:
	_cells.clear()


func key(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / cell), floori(p.y / cell))


func insert(id: int, p: Vector2) -> void:
	var k := key(p)
	if not _cells.has(k):
		_cells[k] = PackedInt32Array()
	var arr: PackedInt32Array = _cells[k]
	arr.append(id)
	_cells[k] = arr


## Appends to [param out] the ids in every cell overlapping the square around
## [param p] of half-size [param radius]. Callers check the exact distance.
func query(p: Vector2, radius: float, out: PackedInt32Array) -> void:
	var lo := key(p - Vector2(radius, radius))
	var hi := key(p + Vector2(radius, radius))
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			var k := Vector2i(x, y)
			if _cells.has(k):
				out.append_array(_cells[k])
