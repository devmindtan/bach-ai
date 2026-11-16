class_name Pickups
extends RefCounted
## Experience gems and gold coins on the ground, as packed arrays. Items inside
## the magnet radius fly to the player; collect() sums what was picked up.
##
## Example:
##   var p := Pickups.new(run_config["pickups"], 400)
##   p.drop(Pickups.GEM, pos, 3.0)
##   var got := p.step(delta, player_center, magnet_mul)   # Vector2(xp, gold)

enum { GEM, COIN }

var count := 0
var capacity := 0
var pos := PackedVector2Array()
var value := PackedFloat32Array()
var kind := PackedInt32Array()
var pulled := PackedByteArray()

var radius := 70.0
var magnet_speed := 520.0
var collect_radius := 14.0


func _init(cfg: Dictionary, p_capacity := 400) -> void:
	radius = float(cfg.get("radius", 70.0))
	magnet_speed = float(cfg.get("magnet_speed", 520.0))
	collect_radius = float(cfg.get("collect_radius", 14.0))
	capacity = maxi(1, p_capacity)
	pos.resize(capacity)
	value.resize(capacity)
	kind.resize(capacity)
	pulled.resize(capacity)


## Drops an item. When full, its value is added to the oldest item of the same
## kind instead, so no xp is ever lost.
func drop(k: int, p: Vector2, v: float) -> void:
	if count >= capacity:
		for i in count:
			if kind[i] == k:
				value[i] += v
				return
		return
	pos[count] = p
	value[count] = v
	kind[count] = k
	pulled[count] = 0
	count += 1


## Moves pulled items and collects those that reach the player.
## Returns Vector2(xp collected, gold collected).
func step(delta: float, player_center: Vector2, magnet_mul: float) -> Vector2:
	var got := Vector2.ZERO
	var r := radius * magnet_mul
	var i := 0
	while i < count:
		var d := player_center - pos[i]
		var l := d.length()
		if pulled[i] == 0 and l < r:
			pulled[i] = 1
		if pulled[i] == 1:
			pos[i] += d / maxf(l, 0.001) * minf(l, magnet_speed * delta)
			l = (player_center - pos[i]).length()
		if l <= collect_radius:
			if kind[i] == GEM:
				got.x += value[i]
			else:
				got.y += value[i]
			_remove(i)
			continue
		i += 1
	return got


## Pulls every item to the player (end-of-run vacuum).
func pull_all() -> void:
	for i in count:
		pulled[i] = 1


func _remove(i: int) -> void:
	var last := count - 1
	pos[i] = pos[last]
	value[i] = value[last]
	kind[i] = kind[last]
	pulled[i] = pulled[last]
	count = last
