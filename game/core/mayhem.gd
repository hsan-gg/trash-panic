class_name Mayhem
extends RefCounted
## The Dropper's trouble: bombs, nuclear waste, leaking batteries and intruders (robot, raccoon, elephant), plus the
## POLLUTION meter that triggers CHAOS STATE. The host runs it inside Shift.tick(); the guest only mirrors what
## `delta()` sends (creatures, meter, chaos modifier). Hazards are ordinary items; creatures walk between tiles.

var shift: Shift
var creatures := {}  ## id -> {k, x, y, p: progress s (scare timer for the elephant), loot: item kind a raccoon carries, chaos: bool, w: wait s}
var meter := 0.0
var chaos := ""  ## the modifier now active, or ""
var chaos_left := 0.0
var dirty := false  ## creatures changed since the last delta

var _drops: Array = []  ## [{k, at, t}] warnings counting down
var _next_drop := Rules.DROP_FIRST_S  ## shift second of the next special drop
var _fuses := {}  ## bomb item id -> seconds left
var _leaks := {}  ## nuclear waste / battery item id -> seconds left
var _goals := {}  ## creature id -> {at: Vector2, t: seconds until it scatters things}
var _reach := {}  ## creature id -> walkable tiles it may roam
var _shooed := {}  ## creature id -> true when someone used it this tick
var _next_chaos_ok := 0.0
var _had_chaos := false
var _catcher := {}  ## creature id -> the player who last shooed it (for the scoreboard)
var _magnet_t := 0.0
var _shark_next := Rules.SHARK_FIRST_S
var _shark := {}  ## the coming bite: {at: Vector2i, t: seconds left}
var _edge: Array = []  ## floor tiles along the outer wall: where the shark can reach

const GRAB_REACH := 1.1  ## tiles: raccoons and pigs grab from the next tile (items on belts and rails)


func _init(p_shift: Shift) -> void:
	shift = p_shift


func tick(dt: float) -> void:
	_schedule_drops(dt)
	_tick_hazards(dt)
	for id in creatures.keys():
		_tick_creature(id, dt)
	_tick_chaos(dt)
	_tick_shark(dt)


# ── the Dropper's special drops ──────────────────────────────────────────────

func _hazards_alive() -> int:
	return _fuses.size() + _leaks.size() + creatures.size() + _drops.size()


func _schedule_drops(dt: float) -> void:
	if shift.training and shift.elapsed < Rules.DROP_TRAINING_FIRST_S:
		return  # the tutorial shift starts calm
	if shift.elapsed >= _next_drop:
		_next_drop = shift.elapsed + Rules.drop_gap(shift.elapsed)
		if _hazards_alive() < Rules.max_hazards(shift.elapsed):
			var k := _pick_drop()
			var at: Variant = free_tile(shift.drop_side(k)) if k in Rules.HAZARDS else _free_tile()
			if k != "" and at != null:
				_drops.append({"k": k, "at": at, "t": Rules.DROP_WARN_S})
				shift._cue({"e": "drop_alert", "at": at, "k": k})
	for d in _drops.duplicate():
		d.t -= dt
		if d.t <= 0.0:
			_drops.erase(d)
			_land(d.k, d.at)


func _pick_drop() -> String:
	var bag := {}
	for k in Rules.DROP_WEIGHTS:
		if k == "elephant" and _count("elephant") > 0:
			continue
		bag[k] = Rules.DROP_WEIGHTS[k]
	var total := 0
	for k in bag:
		total += bag[k]
	var roll := shift.rng.randi() % total
	for k in bag:
		roll -= bag[k]
		if roll < 0:
			return k
	return ""


func _count(kind: String) -> int:
	var n := 0
	for c in creatures.values():
		if c.k == kind:
			n += 1
	for d in _drops:
		if d.k == kind:
			n += 1
	return n


## A free floor tile on the given side (1 = left worker's, 2 = right worker's).
func free_tile(side: int) -> Variant:
	var tiles: Array = shift.room.reachable(shift.room.spawns[side], false).keys()
	tiles = tiles.filter(func(t: Vector2i) -> bool: return shift.items_at(t).is_empty() and shift.mayhem.creature_near(t) < 0)
	return tiles[shift.rng.randi() % tiles.size()] if not tiles.is_empty() else null


func _free_tile() -> Variant:
	return free_tile(shift.rng.randi() % 2 + 1)


func _land(kind: String, at: Vector2i) -> void:
	if kind in Rules.HAZARDS:  # waste may have fallen on the marked spot during the warning
		var free: Variant = _free_near(at)
		if free == null:
			return
		at = free
	match kind:
		"bomb":
			var id := shift._spawn("bomb", str(Rules.BOMB_FUSE_S), at)
			_fuses[id] = float(Rules.BOMB_FUSE_S)
		"nuke", "battery":
			_leaks[shift._spawn(kind, "", at)] = Rules.LEAK_S[kind]
		_:
			_add_creature(kind, at, false)
	shift._cue({"e": "drop", "at": at, "k": kind})


# ── bombs, nuclear waste and batteries ───────────────────────────────────────

func _tick_hazards(dt: float) -> void:
	for id in _fuses.keys():
		if not shift.items.has(id):  # thrown into the chute (or otherwise gone)
			_fuses.erase(id)
			continue
		var before := ceili(_fuses[id])
		_fuses[id] -= dt
		var left := ceili(_fuses[id])
		if _fuses[id] <= 0.0:
			_explode(id)
		elif left != before:
			shift.items[id].s = str(left)
			shift._dirty_items[id] = true
			shift._cue({"e": "tick", "at": _tile_of(id)})
	for id in _leaks.keys():
		if not shift.items.has(id):
			_leaks.erase(id)
			continue
		_leaks[id] -= dt
		if _leaks[id] <= 0.0:
			var at := _tile_of(id)
			var kind: String = shift.items[id].k
			shift._remove(id)
			_leaks.erase(id)
			shift._add_coins(-Rules.LEAK_PENALTY)
			shift._cue({"e": "leak", "at": at, "k": kind, "pts": -Rules.LEAK_PENALTY})


func _tile_of(item: int) -> Vector2i:
	var it: Dictionary = shift.items[item]
	if it.at != null:
		return it.at
	return shift.players[it.by].tile if shift.players.has(it.by) else shift.room.spawns[1]


func _explode(id: int) -> void:
	var at := _tile_of(id)
	shift._remove(id)
	_fuses.erase(id)
	for other in shift.items.keys():  # the blast scatters loose waste
		var it: Dictionary = shift.items[other]
		if it.at != null and Vector2(it.at).distance_to(Vector2(at)) <= 2.0 and shift.room.type_at(it.at) in ["floor", "counter", "divider", "belt"]:
			var spot: Variant = _free_tile()
			if spot != null:
				shift._move(other, spot)
	shift.stats.booms += 1
	shift._add_coins(-Rules.BLAST_PENALTY)
	shift._cue({"e": "boom", "at": at, "pts": -Rules.BLAST_PENALTY})
	shift.jam_rail(at)  # it may jam the rail


# ── creatures ────────────────────────────────────────────────────────────────

func spawn_robots(count: int) -> void:
	for i in count:
		var at: Variant = _free_tile()
		if at != null:
			_add_creature("robot", at, true)


func _add_creature(kind: String, at: Vector2i, from_chaos: bool) -> void:
	var id := shift._take_id()
	creatures[id] = {"k": kind, "x": float(at.x), "y": float(at.y), "p": 0.0, "loot": "", "chaos": from_chaos, "w": 0.0}
	_reach[id] = shift.room.reachable(at, false).keys()
	_goals[id] = {"at": Vector2(at), "t": 3.5}
	dirty = true


func creature_near(at: Vector2i) -> int:
	for id in creatures:
		var c: Dictionary = creatures[id]
		if Vector2(c.x, c.y).distance_to(Vector2(at)) <= 1.25:
			return id
	return -1


## One player USEs a creature. Robot and raccoon: progress builds while they keep at it. Elephant: it gets scared
## and bolts for an open exit door (open the door first!).
func shoo(id: int, dt: float, pid := -1) -> void:
	var c: Dictionary = creatures[id]
	_catcher[id] = pid
	_shooed[id] = true
	dirty = true
	if c.k == "elephant":
		c.p = Rules.ELEPHANT_SCARE_S
		return
	c.p += dt
	if c.p >= Rules.SHOO_S[c.k]:
		_resolve(id)


## The nearest empty floor tile to `at`, walking only over floor (so it stays on the same side); null if none.
func _free_near(at: Vector2i) -> Variant:
	var seen := {at: true}
	var todo := [at]
	while not todo.is_empty():
		var t: Vector2i = todo.pop_front()
		if shift.room.walkable(t, shift.solo) and shift.items_at(t).is_empty():
			return t
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = t + d
			if not seen.has(n) and shift.room.walkable(n, shift.solo):
				seen[n] = true
				todo.append(n)
	return null


func _spawn_near(kind: String, at: Vector2i) -> void:
	var free: Variant = _free_near(at)
	if free != null:
		shift._spawn(kind, "", free)


func stun(id: int) -> void:
	creatures[id].w = maxf(creatures[id].w, Rules.STUN_S)
	dirty = true


func _resolve(id: int) -> void:
	var c: Dictionary = creatures[id]
	var at := Vector2i(roundi(c.x), roundi(c.y))
	var who: int = _catcher.get(id, -1)
	_catcher.erase(id)
	match c.k:
		"robot":  # its scrap metal and its battery both get recycled (the battery goes in the battery bin)
			_spawn_near("can", at)
			_land("battery", at)
			shift._add_coins(Rules.ROBOT_COINS)
			shift._cue({"e": "robot_down", "at": at, "who": who, "pts": Rules.ROBOT_COINS})
		"raccoon":
			if c.loot != "":
				_spawn_near(c.loot, at)
			shift._add_coins(Rules.RACCOON_COINS)
			shift._cue({"e": "rescued", "at": at, "who": who, "k": "raccoon", "pts": Rules.RACCOON_COINS})
		"elephant":
			shift._add_coins(Rules.RESCUE_COINS)
			shift._cue({"e": "rescued", "at": at, "who": who, "k": "elephant", "pts": Rules.RESCUE_COINS})
		"chicken", "pig":
			shift._add_coins(Rules.CATCH_COINS[c.k])
			shift._cue({"e": "rescued", "at": at, "who": who, "k": c.k, "pts": Rules.CATCH_COINS[c.k]})
	_remove_creature(id)


func _remove_creature(id: int) -> void:
	creatures.erase(id)
	_goals.erase(id)
	_reach.erase(id)
	dirty = true


## The floor tile in front of an open exit door, nearest to `from` (null when every door is shut).
func _open_exit(from: Vector2) -> Variant:
	var best: Variant = null
	for at in shift.stations:
		if shift.room.type_at(at) == "exit" and shift.stations[at].t > 0.0:
			var inside := Vector2i(at.x + (1 if at.x == 0 else -1), at.y)
			if best == null or Vector2(inside).distance_to(from) < Vector2(best).distance_to(from):
				best = inside
	return best


func _tick_creature(id: int, dt: float) -> void:
	var c: Dictionary = creatures[id]
	if c.k == "elephant":
		c.p = maxf(0.0, c.p - dt)  # the scare wears off
	elif not _shooed.has(id) and c.p > 0.0:
		c.p = maxf(0.0, c.p - dt)
	var grabbed: bool = _shooed.has(id) and c.k != "elephant"  # held with USE: it struggles but stays put
	_shooed.erase(id)
	if grabbed:
		dirty = true
		return
	if c.w > 0.0:  # a raccoon nibbling its loot: the moment to catch it
		c.w -= dt
		return
	var g: Dictionary = _goals[id]
	var pos := Vector2(c.x, c.y)
	var scared: bool = c.k == "elephant" and c.p > 0.0
	if scared:
		var door: Variant = _open_exit(pos)
		if door != null:
			g.at = Vector2(door)
			if pos.distance_to(g.at) < 0.4:
				_resolve(id)  # out the door: rescued
				return
		elif g.at.distance_to(pos) < 0.15:
			g.at = _next_goal(id, c)  # nowhere to go: it stampedes around
	var flee: bool = c.k == "raccoon" and c.loot != ""
	if not scared and g.at.distance_to(pos) < 0.15:
		if flee:  # it made it out with the loot
			shift._add_coins(-Rules.RACCOON_LOSS)
			shift._cue({"e": "raccoon_gone", "at": Vector2i(roundi(c.x), roundi(c.y)), "pts": -Rules.RACCOON_LOSS})
			_remove_creature(id)
			return
		g.at = _next_goal(id, c)
	var speed: float = Rules.ELEPHANT_RUN if scared else Rules.CREATURE_SPEED[c.k]
	var step: Vector2 = (g.at - pos).limit_length(speed * dt)
	c.x += step.x
	c.y += step.y
	dirty = true
	g.t -= dt
	if g.t <= 0.0:
		g.t = {"robot": 3.5, "chicken": 2.0}.get(c.k, 1.2 if scared else 5.0)
		if c.k not in ["raccoon", "pig"]:
			_scatter(Vector2(c.x, c.y), {"robot": 2.5, "chicken": 1.5}.get(c.k, 1.6))
	if c.k == "pig":
		_try_eat(id, c)
	if c.k == "raccoon" and c.loot == "":
		_try_steal(id, c)


func _next_goal(id: int, c: Dictionary) -> Vector2:
	var tiles: Array = _reach[id]
	if c.k == "pig":
		var food := _nearest_loot(id, Vector2(c.x, c.y), ["box", "paper"] + Rules.FOOD)
		if food >= 0:
			return _approach(id, shift.items[food].at)
	if c.k == "raccoon":
		if c.loot != "":  # run for the farthest corner
			var far: Vector2i = tiles[0]
			for t in tiles:
				if Vector2(t).distance_to(Vector2(c.x, c.y)) > Vector2(far).distance_to(Vector2(c.x, c.y)):
					far = t
			return Vector2(far)
		var loot := _nearest_loot(id, Vector2(c.x, c.y))
		if loot >= 0:
			return _approach(id, shift.items[loot].at)
	return Vector2(tiles[shift.rng.randi() % tiles.size()])


## The nearest loose item of `kinds` the creature can reach from its own side (on its floor or next to it).
func _nearest_loot(creature: int, from: Vector2, kinds: Array = Rules.WASTE_WEIGHTS.keys()) -> int:
	var best := -1
	var reach: Array = _reach[creature]
	for id in shift.items:
		var it: Dictionary = shift.items[id]
		if it.at != null and it.k in kinds and _within(reach, it.at) and shift.room.type_at(it.at) in ["floor", "counter", "divider", "belt"]:
			if best < 0 or Vector2(it.at).distance_to(from) < Vector2(shift.items[best].at).distance_to(from):
				best = id
	return best


func _try_steal(id: int, c: Dictionary) -> void:
	var loot := _nearest_loot(id, Vector2(c.x, c.y))
	if loot < 0 or Vector2(shift.items[loot].at).distance_to(Vector2(c.x, c.y)) > GRAB_REACH:
		if loot >= 0:
			_goals[id].at = _approach(id, shift.items[loot].at)
		return
	c.loot = shift.items[loot].k
	c.w = Rules.RACCOON_NIBBLE_S
	var at: Vector2i = shift.items[loot].at
	shift._remove(loot)
	_goals[id].at = _next_goal(id, c)
	shift._cue({"e": "steal", "at": at})


## Where a creature stands to reach `at`: the tile itself if it can walk there, else a walkable neighbour (belts, rails).
func _approach(creature: int, at: Vector2i) -> Vector2:
	var reach: Array = _reach[creature]
	for d in [Vector2i.ZERO, Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
		if reach.has(at + d):
			return Vector2(at + d)
	return Vector2(at)


func _within(reach: Array, at: Vector2i) -> bool:
	for d in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if reach.has(at + d):
			return true
	return false


## The pig heads for paper, cardboard and food and eats it, chewing for a moment (the moment to catch it).
func _try_eat(id: int, c: Dictionary) -> void:
	var food := _nearest_loot(id, Vector2(c.x, c.y), ["box", "paper"] + Rules.FOOD)
	if food < 0:
		return
	var at: Vector2i = shift.items[food].at
	if Vector2(at).distance_to(Vector2(c.x, c.y)) > GRAB_REACH:
		_goals[id].at = _approach(id, at)
		return
	shift._remove(food)
	c.w = Rules.PIG_CHEW_S
	shift._add_coins(-Rules.EAT_LOSS)
	shift._cue({"e": "eat", "at": at, "pts": -Rules.EAT_LOSS})
	_goals[id].at = _next_goal(id, c)


## Robots, chickens and stomping elephants throw loose waste around.
func _scatter(from: Vector2, radius: float) -> void:
	for id in shift.items.keys():
		var it: Dictionary = shift.items[id]
		if it.at != null and Vector2(it.at).distance_to(from) <= radius and shift.room.type_at(it.at) in ["floor", "counter", "divider", "belt"]:
			var spot: Variant = _free_tile()
			if spot != null:
				shift._move(id, spot)
				shift._cue({"e": "throw", "at": spot})
				return


# ── THE SHARK ────────────────────────────────────────────────────────────────

func _tick_shark(dt: float) -> void:
	if shift.training and shift.elapsed < Rules.DROP_TRAINING_FIRST_S:
		return
	if not _shark.is_empty():
		_shark.t -= dt
		if _shark.t <= 0.0:
			bite(_shark.at)
			_shark = {}
		return
	if shift.elapsed >= _shark_next:
		_shark_next = shift.elapsed + (Rules.SHARK_GAP_RUSH_S if Rules.is_rush(shift.elapsed) else Rules.SHARK_GAP_S)
		var at: Variant = _shark_target()
		if at != null:
			_shark = {"at": at, "t": Rules.SHARK_WARN_S}
			shift._cue({"e": "shark_alert", "at": at})


## An edge tile, preferring one with waste or a worker on it (the shark smells lunch).
func _shark_target() -> Variant:
	if _edge.is_empty():
		var room := shift.room
		for at in room.tiles:
			if not room.walkable(at, false):
				continue
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n: Vector2i = at + d
				if room.type_at(n) == "wall" and (n.x == 0 or n.y == 0 or n.x == room.width - 1 or n.y == room.height - 1):
					_edge.append(at)
					break
	if _edge.is_empty():
		return null
	var tasty := _edge.filter(func(at: Vector2i) -> bool:
		return not shift.items_at(at).is_empty() or shift.players.values().any(func(p: Dictionary) -> bool: return p.tile == at))
	var pool: Array = tasty if not tasty.is_empty() and shift.rng.randf() < 0.7 else _edge
	return pool[shift.rng.randi() % pool.size()]


## The bite: loose waste on and next to `at` goes into the sea; a worker in reach drops what they hold.
func bite(at: Vector2i) -> void:
	var lost := 0
	for id in shift.items.keys():
		var it: Dictionary = shift.items[id]
		if it.at != null and shift.room.walkable(it.at, shift.solo) and absi(it.at.x - at.x) + absi(it.at.y - at.y) <= 1:
			shift._remove(id)
			lost += 1
	for pid in shift.players:
		var p: Dictionary = shift.players[pid]
		var held := shift.held(pid)
		if held >= 0 and absi(p.tile.x - at.x) + absi(p.tile.y - at.y) <= 1:
			var spot: Variant = _free_near(p.tile)
			if spot != null:
				shift._move(held, spot)
			else:
				shift._remove(held)
	if lost > 0:
		shift._add_coins(-Rules.SHARK_LOSS * lost)
	shift._cue({"e": "shark", "at": at, "pts": -Rules.SHARK_LOSS * lost} if lost > 0 else {"e": "shark", "at": at})


# ── POLLUTION and CHAOS STATE ────────────────────────────────────────────────

func add_meter(points: int) -> void:
	meter = minf(100.0, meter + points * Rules.METER_PER_POINT)


func _tick_chaos(dt: float) -> void:
	if chaos == "magnet":
		_magnet_t -= dt
		if _magnet_t <= 0.0:
			_magnet_t = Rules.MAGNET_STEP_S
			slide(["can"], Vector2i.UP)
	if chaos != "":
		chaos_left -= dt
		if chaos_left <= 0.0:
			_end_chaos()
		return
	meter = maxf(0.0, meter - Rules.METER_DECAY * dt)
	var room_left := shift.time_left() - Rules.CHAOS_END_GAP
	var due := (meter >= Rules.CHAOS_AT and shift.elapsed >= _next_chaos_ok) or (not _had_chaos and shift.elapsed >= Rules.CHAOS_FORCE_AT)
	if due and room_left >= Rules.CHAOS_S * 0.5:  # never a blackout right at the end
		_had_chaos = true
		chaos = Rules.CHAOS_MODS[shift.rng.randi() % Rules.CHAOS_MODS.size()]
		chaos_left = minf(Rules.CHAOS_S, room_left)
		if chaos == "robots":
			spawn_robots(3)
		shift._cue({"e": "chaos", "m": chaos})


## Loose `kinds` on the floor slide one tile in `dir` if it's free: MAGNETIC MADNESS pulls cans toward the back wall
## (the Dropper's magnet), ROT & ROLL's tilted floor rolls round waste downhill. Returns the items that moved.
func slide(kinds: Array, dir: Vector2i) -> Array:
	var ids: Array = shift.items.keys().filter(func(id: int) -> bool:
		var it: Dictionary = shift.items[id]
		return it.k in kinds and it.at != null and shift.room.type_at(it.at) == "floor")
	ids.sort_custom(func(a: int, b: int) -> bool:  # downhill first, so a row rolls together
		return Vector2(shift.items[a].at).dot(Vector2(dir)) > Vector2(shift.items[b].at).dot(Vector2(dir)))
	var moved := []
	for id in ids:
		var next: Vector2i = shift.items[id].at + dir
		if shift.room.walkable(next, shift.solo) and shift.items_at(next).is_empty():
			var since: float = shift.items[id].since
			shift._move(id, next)
			shift.items[id].since = since  # rolling doesn't keep food fresh
			moved.append(id)
	return moved


func _end_chaos() -> void:
	chaos = ""
	meter = Rules.CHAOS_AFTER
	_next_chaos_ok = shift.elapsed + 20.0
	for id in creatures.keys():
		if creatures[id].chaos:
			_remove_creature(id)
	shift._cue({"e": "chaos_end"})


# ── network sync ─────────────────────────────────────────────────────────────

func pack_creatures() -> Array:
	return creatures.keys().map(func(id: int) -> Array:
		var c: Dictionary = creatures[id]
		return [id, c.k, snappedf(c.x, 0.01), snappedf(c.y, 0.01), snappedf(c.p, 0.05)])


func unpack_creatures(rows: Array) -> void:
	creatures.clear()
	for r in rows:
		creatures[int(r[0])] = {"k": r[1], "x": float(r[2]), "y": float(r[3]), "p": float(r[4]), "loot": "", "chaos": false, "w": 0.0}
