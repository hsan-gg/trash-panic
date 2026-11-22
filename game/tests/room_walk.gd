extends SceneTree
## Workers must never get stuck in a real room: for every map, from every floor tile (centre and off-centre), walking
## toward each open neighbour tile has to get there. Prints the tiles where a worker got stuck.

const OFFSETS := [Vector2(0, 0), Vector2(0.32, 0), Vector2(-0.32, 0)]
const DIRS := {Vector2i.LEFT: "move_left", Vector2i.RIGHT: "move_right", Vector2i.UP: "move_forward", Vector2i.DOWN: "move_back"}


func _initialize() -> void:
	Controls.register_actions()
	await process_frame
	var gate := get_root().get_node_or_null("Gate")
	if gate != null:  # offline tests: the connection gate would pause the game when the server is slow to answer
		gate.set_process(false)
	paused = false
	Engine.physics_ticks_per_second = 600  # with time_scale 10: steps stay 1/60 s, ten times faster than real time
	Engine.time_scale = 10.0
	var stuck := []
	for m in Rules.MAPS.size():
		Rules.set_map(m)
		var room := RoomMap.parse(FileAccess.get_file_as_string("res://rooms/%s.txt" % Rules.MAPS[m].room))
		var world := Node3D.new()
		get_root().add_child(world)
		var ground := StaticBody3D.new()
		var gs := CollisionShape3D.new()
		gs.shape = WorldBoundaryShape3D.new()
		ground.add_child(gs)
		world.add_child(ground)
		for r: Rect2i in room.solid_rects(false):
			var b := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var s := BoxShape3D.new()
			s.size = Vector3(r.size.x * RoomMap.TILE, 2.0, r.size.y * RoomMap.TILE)
			cs.shape = s
			b.add_child(cs)
			b.position = (room.world(r.position) + room.world(r.position + r.size - Vector2i.ONE)) / 2.0 + Vector3(0, 0.6, 0)
			world.add_child(b)
		var p := Player.new()
		p.frozen = false
		world.add_child(p)
		p.avatar.setup(0)
		await process_frame  # nodes enter the tree on the next frame
		for a in DIRS.values():  # warm-up: the first presses after start-up are not reliable headless
			Input.action_press(a)
			for i in 30:
				await physics_frame
			Input.action_release(a)
		for at: Vector2i in room.tiles:
			if not room.walkable(at, false):
				continue
			for d: Vector2i in DIRS:
				if not room.walkable(at + d, false):
					continue
				for o: Vector2 in OFFSETS:
					var side := Vector2(d).orthogonal() * o.x  # only offsets across the walking direction
					var start := room.world(at) + Vector3(side.x, 0, side.y)
					p.global_position = start
					p.velocity = Vector3.ZERO
					Input.action_press(DIRS[d])
					var goal := room.world(at + d)
					var ok := false
					for i in 45:
						await physics_frame
						if room.tile_of(p.global_position) == at + d:
							ok = true
							break
					Input.action_release(DIRS[d])
					if not ok:
						stuck.append("%s %s->%s off %s at %s" % [Rules.MAPS[m].room, at, at + d, o, p.global_position])
		for at: Vector2i in room.tiles:  # diagonal stick: both neighbours and the corner tile open
			if not room.walkable(at, false):
				continue
			for dx in [-1, 1]:
				for dy in [-1, 1]:
					var to := at + Vector2i(dx, dy)
					if not (room.walkable(to, false) and room.walkable(at + Vector2i(dx, 0), false) and room.walkable(at + Vector2i(0, dy), false)):
						continue
					p.global_position = room.world(at)
					p.velocity = Vector3.ZERO
					var acts := [DIRS[Vector2i(dx, 0)], DIRS[Vector2i(0, dy)]]
					for a in acts:
						Input.action_press(a)
					var ok := false
					for i in 60:
						await physics_frame
						if room.tile_of(p.global_position) == to:
							ok = true
							break
					for a in acts:
						Input.action_release(a)
					if not ok:
						stuck.append("%s %s->%s diagonal at %s" % [Rules.MAPS[m].room, at, to, p.global_position])
		world.queue_free()
		await process_frame
	print("room_walk: %d stuck" % stuck.size() if not stuck.is_empty() else "room_walk: ok")
	for s in stuck.slice(0, 25):
		print("  ", s)
	quit(0)
