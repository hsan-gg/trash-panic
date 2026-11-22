extends SceneTree
## Soak test: two scripted workers play whole shifts on the host Shift while a guest mirror is fed through JSON, with
## deltas randomly lost (healed by the 3 s snapshots). Checks sync, invariants and that the shift is winnable.
## godot --headless --path game --script res://tests/soak.gd [-- --seeds=5]

const DT := 0.1
const STEP_S := 0.25  ## a bot walks one tile this often (about the real 4.4 m/s worker)
const LOSS := 0.1  ## share of deltas lost on the way to the guest

const SNAP_LIMIT := 4096  ## server/src/validate.js MAX_SNAP_BYTES

var _fails := 0
var _max_snap := 0


func _init() -> void:
	var seeds := 5
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = int(a.trim_prefix("--seeds="))
	var totals := []
	for s in seeds:
		totals.append(_shift(s + 1))
	print("soak: %d shifts, coins %s, largest snapshot %d bytes, failures %d" % [seeds, str(totals), _max_snap, _fails])
	quit(1 if _fails > 0 else 0)


func _shift(seed: int) -> int:
	Rules.set_map(seed % Rules.MAPS.size())  # every map gets played
	var room := RoomMap.load_room(Rules.MAPS[Rules.map].room)
	var host := Shift.new()
	host.setup(room, seed, false)
	var guest := Shift.new()
	guest.setup(room, seed, false)
	guest.items.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 31
	var bots := {}
	for pid in [1, 2]:
		host.add_player(pid, room.spawns[pid])
		bots[pid] = {"tile": room.spawns[pid], "area": room.reachable(room.spawns[pid], false), "t": 0.0, "use": null, "use_t": 0.0}
	var snap_t := 0.0
	var ticks := 0
	var tally := {}
	while not host.finished():
		for pid in bots:
			_bot(host, pid, bots[pid])
		host.tick(DT)
		ticks += 1
		var d := host.delta()
		for e in d.get("e", []):
			tally[e.e] = tally.get(e.e, 0) + 1
		if rng.randf() >= LOSS:
			guest.apply(JSON.parse_string(JSON.stringify(d)))
		snap_t += DT
		if snap_t >= 3.0:
			snap_t = 0.0
			var snap := JSON.stringify({"t": "snap", "d": host.delta(true)})
			_max_snap = maxi(_max_snap, snap.to_utf8_buffer().size())
			if snap.to_utf8_buffer().size() > SNAP_LIMIT:  # the server drops it and the guest can't heal
				_fail(seed, ticks, "snapshot is %d bytes (server limit %d)" % [snap.to_utf8_buffer().size(), SNAP_LIMIT])
			guest.apply(JSON.parse_string(snap).d)
			_check_sync(host, guest, seed, ticks)
		_check_invariants(host, seed, ticks)
	print("seed %d (map %d): coins %d stars %d stats %s" % [seed, Rules.map + 1, host.coins, Rules.stars(host.coins), str(host.stats)])
	if OS.get_cmdline_user_args().has("--verbose"):
		print("  events ", tally)
	return host.coins


# ── a simple worker: hazards first, then what the orders want, then anything ────

func _bot(sh: Shift, pid: int, b: Dictionary) -> void:
	b.t -= DT
	if b.use != null:  # holding USE on something
		b.use_t -= DT
		if b.use_t <= 0.0:
			sh.use(pid, null)
			b.use = null
		return
	var held := sh.held(pid)
	var goal: Variant = _goal(sh, pid, b, held)  # the station/item tile to act on
	if goal == null:
		if held >= 0:  # belt full: throw it over the divider like a human would
			sh.throw(pid, Vector2i(_toward_other(pid), 0))
		return
	var stand: Variant = _stand_for(sh.room, b.area, goal)
	if stand == null:
		return
	if b.tile != stand:
		if b.t <= 0.0:
			b.t = STEP_S
			b.tile = _step(b.area, b.tile, stand)
		sh.set_player(pid, b.tile, goal - b.tile)
		return
	sh.set_player(pid, b.tile, goal - b.tile)
	var creature := sh.mayhem.creature_near(goal)
	if held >= 0 and sh.room.type_at(goal) == "bunker" and sh.stations.has(goal) and sh.stations[goal].jam:  # tripped: put it down, reset it
		sh.grab(pid, b.tile)
		return
	if held < 0 and (creature >= 0 or (sh.room.type_at(goal) in ["exit", "belt", "divider", "bunker"] and sh.stations.has(goal) and (sh.stations[goal].jam or sh.room.type_at(goal) == "exit") and sh.items_at(goal).is_empty())):
		sh.use(pid, goal)
		b.use = goal
		b.use_t = 2.6
		return
	sh.grab(pid, goal)


func _goal(sh: Shift, pid: int, b: Dictionary, held: int) -> Variant:
	var room := sh.room
	if held >= 0:
		var dest := Rules.dest(sh.items[held].k)
		for at in room.tiles:
			var t: String = room.tiles[at]
			var fits := (t == "bunker" and room.bunker_material(at) == dest) or t == dest
			if fits and _stand_for(room, b.area, at) != null:
				return at
		return _outgoing_belt(sh, pid, b)
	var elephant := sh.mayhem.creatures.values().any(func(c: Dictionary) -> bool: return c.k == "elephant")
	for at in room.tiles:  # jams, and an exit door for the elephant
		var t: String = room.tiles[at]
		if sh.stations.has(at) and _stand_for(room, b.area, at) != null:
			if (t in ["belt", "divider", "bunker"] and sh.stations[at].jam) or (t == "exit" and elephant and sh.stations[at].t <= 0.0):
				return at
	for id in sh.mayhem.creatures:
		var c: Dictionary = sh.mayhem.creatures[id]
		var at := Vector2i(roundi(c.x), roundi(c.y))
		if b.area.has(at):
			return at
	var best: Variant = null
	var best_score := -INF
	for id in sh.items:
		var it: Dictionary = sh.items[id]
		if it.at == null or room.type_at(it.at) in ["bunker", "chute", "container", "batterybin"]:
			continue
		if room.type_at(it.at) in ["belt", "divider"] and not _can_deliver(sh, b, it.k):
			continue  # leave it for the partner (no ping-pong)
		if _stand_for(room, b.area, it.at) == null:
			continue
		var score: float = -Vector2(it.at).distance_to(Vector2(b.tile))
		if it.k in Rules.HAZARDS:
			score += 20.0
		if room.type_at(it.at) in ["belt", "divider"]:
			score += 8.0  # clear what the partner sent, or the belt backs up
		if sh.orders.any(func(o: Dictionary) -> bool: return o.m == Rules.dest(it.k)):
			score += 6.0
		if score > best_score:
			best_score = score
			best = it.at
	return best


func _can_deliver(sh: Shift, b: Dictionary, kind: String) -> bool:
	var dest := Rules.dest(kind)
	for at in sh.room.tiles:
		var t: String = sh.room.tiles[at]
		if ((t == "bunker" and sh.room.bunker_material(at) == dest) or t == dest) and _stand_for(sh.room, b.area, at) != null:
			return true
	return false


func _toward_other(pid: int) -> int:
	return 1 if pid == 1 else -1  # player 1 works the left side


func _outgoing_belt(sh: Shift, pid: int, b: Dictionary) -> Variant:
	for at in sh.room.belts:
		var flow: int = sh.room.belts[at] * (-1 if sh.mayhem.chaos == "reverse" else 1)
		if flow == _toward_other(pid) and sh.items_at(at).is_empty() and not sh.stations[at].jam and _stand_for(sh.room, b.area, at) != null:
			return at
	return null


## A floor tile of `area` next to `at` (or `at` itself if it is floor in the area).
func _stand_for(room: RoomMap, area: Dictionary, at: Vector2i) -> Variant:
	for d in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
		if area.has(at + d):
			return at + d
	return null


## One BFS step from `from` toward `to` inside `area`.
func _step(area: Dictionary, from: Vector2i, to: Vector2i) -> Vector2i:
	var prev := {from: from}
	var todo := [from]
	while not todo.is_empty():
		var at: Vector2i = todo.pop_front()
		if at == to:
			break
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = at + d
			if area.has(n) and not prev.has(n):
				prev[n] = at
				todo.append(n)
	if not prev.has(to):
		return from
	var at := to
	while prev[at] != from:
		at = prev[at]
	return at


# ── checks ───────────────────────────────────────────────────────────────────

func _check_sync(host: Shift, guest: Shift, seed: int, tick: int) -> void:
	if host.items.size() != guest.items.size():
		_fail(seed, tick, "guest has %d items, host %d" % [guest.items.size(), host.items.size()])
		return
	for id in host.items:
		var a: Dictionary = host.items[id]
		var b: Dictionary = guest.items.get(id, {})
		if b.is_empty() or a.k != b.k or a.at != b.at or a.by != b.by:
			_fail(seed, tick, "item %d differs: host %s guest %s" % [id, str(a), str(b)])
			return
	if host.coins != guest.coins or host.mayhem.creatures.size() != guest.mayhem.creatures.size():
		_fail(seed, tick, "coins or creatures differ")


func _check_invariants(sh: Shift, seed: int, tick: int) -> void:
	var holders := {}
	for id in sh.items:
		var it: Dictionary = sh.items[id]
		if it.by >= 0:
			if holders.has(it.by):
				_fail(seed, tick, "player %d holds two items" % it.by)
			holders[it.by] = true
		elif it.at == null:
			_fail(seed, tick, "item %d is nowhere" % id)
		elif sh.room.type_at(it.at) in ["wall", "bunker", "chute", "container", "batterybin", "exit"]:
			_fail(seed, tick, "item %d sits inside a %s" % [id, sh.room.type_at(it.at)])
		elif sh.items_at(it.at).size() > 1:
			_fail(seed, tick, "two items share tile %s" % str(it.at))
	for c in sh.mayhem.creatures.values():
		if c.x < 0.5 or c.y < 0.5 or c.x > sh.room.width - 1.5 or c.y > sh.room.height - 1.5:
			_fail(seed, tick, "a %s walked into the walls at %.1f,%.1f" % [c.k, c.x, c.y])


func _fail(seed: int, tick: int, msg: String) -> void:
	_fails += 1
	if _fails <= 20:
		printerr("FAIL seed %d t=%.1f: %s" % [seed, tick * DT, msg])
