extends Node
## Trailer tool: steers the local worker like a (clumsy) player. Empty-handed it walks to the nearest loose item and
## grabs it; carrying, it walks to the nearest station that takes the item and drops it there (or throws it).

var session: Session
var _cool := 0.0


func _process(delta: float) -> void:
	if session == null or session.player == null or session.shift == null:
		return
	_cool -= delta
	var me := session.player.global_position
	var goal: Variant = _goal()
	for a in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(a)
	if goal == null:
		return
	var to: Vector3 = (goal as Vector3) - me
	to.y = 0.0
	if to.length() > RoomMap.TILE * 1.1:
		var d := to.normalized()
		Input.action_press("move_right" if d.x > 0 else "move_left", absf(d.x))
		Input.action_press("move_back" if d.z > 0 else "move_forward", absf(d.z))
	elif _cool <= 0.0:
		_cool = 0.35
		session.controls.action_pressed.emit()
		session.controls.action_released.emit()


func _goal() -> Variant:
	var sh := session.shift
	var me_tile := session.room.tile_of(session.player.global_position)
	var best: Variant = null
	var best_d := INF
	if sh.held(Match.my_id) >= 0:
		for at: Vector2i in sh.stations:
			if sh.can_place(Match.my_id, at) or _near_accept(sh, at):
				var d := Vector2(at).distance_to(Vector2(me_tile))
				if d < best_d:
					best_d = d
					best = at
	else:
		for id in sh.items:
			var it: Dictionary = sh.items[id]
			if it.at != null and it.by < 0 and sh.room.type_at(it.at) == "floor" and sh.room.walkable(it.at, false):
				var d := Vector2(it.at).distance_to(Vector2(me_tile))
				if d < best_d and session.room.reachable(me_tile, false).has(it.at):
					best_d = d
					best = it.at
	return session.room.world(best) if best != null else null


## can_place only checks reach; this asks whether the station would take the item at all.
static func _near_accept(sh: Shift, at: Vector2i) -> bool:
	var item := sh.held(Match.my_id)
	return item >= 0 and sh.room.type_at(at) not in ["floor", "wall"] and sh._accepts(item, at)
