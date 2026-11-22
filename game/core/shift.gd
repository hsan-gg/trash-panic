class_name Shift
extends RefCounted
## One shift in a room. The host runs it (tick, grab, use, throw); the guest keeps a mirror fed by `apply()`.
## Everything here is plain data so it can be tested headless and sent over the network.

const CAPACITY := {"counter": 1, "divider": 1, "gate": 1, "floor": 1, "belt": 1}
const DIRS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
## Guest-side caps on what a host delta may add, so a modified partner can't freeze this phone (a real shift
## peaks around 30 items and a handful of events per delta).
const MAX_ITEMS := 96
const MAX_EVENTS := 16

var room: RoomMap
var mayhem: Mayhem  ## the Dropper, hazards, creatures and the pollution meter
var solo := false
var training := false  ## host is in the tutorial: easy cans, one METAL order, a calm start
var rng := RandomNumberGenerator.new()
var elapsed := 0.0
var coins := 0
var stats := {"orders": 0, "wrong": 0, "late": 0, "booms": 0}
var items := {}  ## id -> {k, s: state (a bomb's fuse seconds), at: Vector2i (or null), by: player id or -1, since}
var stations := {}  ## Vector2i -> {p: progress s, t: seconds a door stays open, jam: the rail is jammed}
var orders := []  ## [{id, m: material, need, got, left, total, final}]
var players := {}  ## id -> {tile: Vector2i, face: Vector2i, use: Vector2i (or null)}
var events := []  ## one-shot happenings not yet sent to the guest: {e, at?, ...}
var cues := []  ## the same happenings for this phone's effects and the Dropper's voice; the view drains it

var _next_id := 1
var _order_t := 3.0
var _waste_t := 1.0
var _belt_t := 0.0
var _twist_t := 0.0  ## seconds to this chapter's next twist: a breaker tripping or the floor tilting
var _roll_t := 0.0
var tilt := 0  ## ROT & ROLL: the way the floor slopes, -1 left, +1 right, 0 flat
var combo := 0  ## right deliveries in a row (each less than Rules.COMBO_WINDOW_S after the last)
var best_combo := 0
var quests := Quests.new()
var _combo_t := 0.0
var _sides := {}  ## 1/2 -> floor tiles of that side, for drop_side()
var _dirty_items := {}
var _dirty_tiles := {}
var _dirty_globals := false
var _final_sent := false
var _contract_sent := false
var _used := {}  ## stations someone is working on this tick


func setup(p_room: RoomMap, seed: int, p_solo: bool) -> void:
	room = p_room
	solo = p_solo
	rng.seed = seed
	quests.pick(seed, Rules.map)
	mayhem = Mayhem.new(self)
	for at in room.tiles:
		if room.tiles[at] in ["divider", "exit", "belt", "bunker"]:
			stations[at] = {"p": 0.0, "t": 0.0, "jam": false}


func add_player(id: int, tile: Vector2i) -> void:
	players[id] = {"tile": tile, "face": Vector2i.UP, "use": null}


## A worker left: anything they carried is lost.
func release(pid: int) -> void:
	var item := held(pid)
	players.erase(pid)
	if item >= 0:
		_remove(item)


func set_player(id: int, tile: Vector2i, face: Vector2i) -> void:
	if players.has(id):
		players[id].tile = tile
		players[id].face = face


func finished() -> bool:
	return elapsed >= Rules.SHIFT_S


func time_left() -> float:
	return maxf(0.0, Rules.SHIFT_S - elapsed)


# ── host actions ──────────────────────────────────────────────────────────────

func held(pid: int) -> int:
	for id in items:
		if items[id].by == pid:
			return id
	return -1


func items_at(at: Vector2i) -> Array:
	var out := []
	for id in items:
		if items[id].at == at:
			out.append(id)
	out.sort()
	return out


## GRAB: put down what you hold, or pick up from the tile you face (else your own tile). True when something happened.
func grab(pid: int, at: Vector2i) -> bool:
	if not _reaches(pid, at):
		return false
	var item := held(pid)
	if item >= 0:
		return place(item, at)
	return _pick(pid, at) or _pick(pid, players[pid].tile)  # or whatever lies under your own feet


## USE: hold on a station or a creature (null to let go). Progress happens in tick().
func use(pid: int, at: Variant) -> void:
	if players.has(pid):
		players[pid].use = at if at != null and _reaches(pid, at) else null


## The tile GRAB acts on (and the highlight shows): carrying, the station next to you that takes your item (the one
## you face first); empty-handed, the nearest item around you. Falls back to the tile you face.
func target(pid: int, tile: Vector2i, face: Vector2i) -> Vector2i:
	var look := Vector2(face - tile)
	var around := DIRS.duplicate()
	around.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).dot(look) > Vector2(b).dot(look))
	var candidates := [face] if absi(face.x - tile.x) + absi(face.y - tile.y) <= 1 else []  # a diagonal face is out of reach
	for d in around:
		if tile + d != face:
			candidates.append(tile + d)
	candidates.append(tile)
	var item := held(pid)
	for at: Vector2i in candidates:
		if item >= 0:
			if room.type_at(at) not in ["floor", "wall"] and _accepts(item, at):
				return at
		elif not items_at(at).is_empty() and room.type_at(at) not in ["bunker", "chute", "container", "batterybin", "exit"]:
			return at
	return candidates[0]


## True when what `pid` carries can go onto the station at `at` (else the action button throws it).
func can_place(pid: int, at: Vector2i) -> bool:
	var item := held(pid)
	return item >= 0 and room.type_at(at) not in ["floor", "wall"] and _accepts(item, at)


## DASH: barging into an intruder in front of you (or beside you) stuns it; the elephant only bounces you back.
func dash(pid: int, dir: Vector2i) -> bool:
	if not players.has(pid) or dir not in DIRS:
		return false
	var tile: Vector2i = players[pid].tile
	for at in [tile + dir, tile]:
		var id := mayhem.creature_near(at)
		if id < 0:
			continue
		if mayhem.creatures[id].k == "elephant":
			_cue({"e": "bonk", "at": at, "who": pid})
		else:
			mayhem.stun(id)
			_cue({"e": "stun", "at": at, "who": pid})
		return true
	return false


## THROW the held item up to THROW_TILES in `dir`; it lands on the first station that takes it, else on the floor.
func throw(pid: int, dir: Vector2i) -> bool:
	var item := held(pid)
	if item < 0 or not players.has(pid) or dir not in DIRS:
		return false
	var landing: Variant = null
	var at: Vector2i = players[pid].tile
	for i in Rules.THROW_TILES + (Rules.LOWGRAV_THROW if mayhem.chaos == "lowgrav" else 0):
		at += dir
		var t := room.type_at(at)
		if t == "wall":
			break
		var catcher := _empty_handed_at(at, pid)
		if catcher >= 0:  # straight into a partner's hands
			items[item].by = catcher
			_dirty_items[item] = true
			_cue({"e": "catch", "at": at})
			return true
		if room.walkable(at, solo):
			if _has_room(at):
				landing = at
			continue
		if _accepts(item, at):
			return place(item, at)
		break
	if landing == null:
		return false
	_move(item, landing)
	_cue({"e": "throw", "at": landing})
	return true


func place(item: int, at: Vector2i) -> bool:
	if not _accepts(item, at):
		if room.type_at(at) == "bunker" or room.type_at(at) in Rules.BINS:
			_cue({"e": "reject", "at": at})  # that doesn't go in there
		return false
	match room.type_at(at):
		"bunker":
			_load_hopper(item, at)
		"chute", "container", "batterybin", "exit":
			_bin(item, at)
		_:
			_move(item, at)
			if room.type_at(at) == "belt":
				_cue({"e": "belt", "at": at})
	return true


# ── simulation ────────────────────────────────────────────────────────────────

func tick(dt: float) -> void:
	if finished():
		return
	_dirty_globals = true
	var was_rush := Rules.is_rush(elapsed)
	elapsed += dt
	if Rules.is_rush(elapsed) != was_rush:
		_cue({"e": "rush" if not was_rush else "rush_end"})
	if Rules.level(elapsed) != Rules.level(elapsed - dt):
		_cue({"e": "level", "n": Rules.level(elapsed)})  # it gets harder
	_scripted_events()
	_drop_waste(dt)
	mayhem.tick(dt)
	_tick_belts(dt)
	_tick_map(dt)
	_tick_orders(dt)
	quests.tick(dt, rng, Rules.map)
	_combo_t -= dt
	if combo > 0 and _combo_t <= 0.0:
		combo = 0  # too slow: the chain breaks
	_used.clear()
	for pid in players:
		var at: Variant = players[pid].use
		if at != null:
			_progress(pid, at, dt)
	for at in stations:
		var st: Dictionary = stations[at]
		if st.t > 0.0:
			st.t = maxf(0.0, st.t - dt)
			_dirty_tiles[at] = true
		if st.p > 0.0 and not _used.has(at):
			st.p = maxf(0.0, st.p - dt)


func _scripted_events() -> void:
	if not _final_sent and time_left() <= Rules.FINAL_S:
		_final_sent = true
		_cue({"e": "final"})
	if not _contract_sent and elapsed >= Rules.FINAL_CONTRACT_AT:
		_contract_sent = true
		orders.append({"id": _take_id(), "m": Rules.order_material(rng), "need": Rules.FINAL_NEED, "got": 0,
			"left": Rules.FINAL_CONTRACT_S, "total": Rules.FINAL_CONTRACT_S, "final": true})
		_cue({"e": "contract"})


## Which side (1 left, 2 right) the Dropper drops `kind` on: the side that CAN'T deliver it, so every item needs a
## hand-off (waste falls by the catcher, hazards by the machine worker). Random if both or neither side can.
func drop_side(kind: String) -> int:
	if _sides.is_empty():
		for side in [1, 2]:
			_sides[side] = room.reachable(room.spawns[side], false)
	var dest := Rules.dest(kind)
	var can := {}
	for side in [1, 2]:
		for at in room.tiles:
			var t: String = room.tiles[at]
			if ((t == "bunker" and room.bunker_material(at) == dest) or t == dest) and Guide.touches(_sides[side], at):
				can[side] = true
	if can.size() == 1:
		return 2 if can.has(1) else 1
	return rng.randi() % 2 + 1


## THE DROPPER: ordinary waste rains down all shift long, each piece on the side that has to pass it on.
func _drop_waste(dt: float) -> void:
	_waste_t -= dt
	if _waste_t > 0.0:
		return
	_waste_t = Rules.waste_gap(elapsed)
	var kind := "can" if training and elapsed < 30.0 else Rules.waste(rng)
	var at: Variant = mayhem.free_tile(drop_side(kind))
	if at != null:
		_spawn(kind, "", at)
		_cue({"e": "fall", "at": at})
	var loose := items.values().filter(func(it: Dictionary) -> bool: return it.at != null and room.type_at(it.at) == "floor").size()
	if loose > Rules.LOOSE_MAX:  # waste piling up pollutes the factory
		mayhem.meter = minf(100.0, mayhem.meter + (loose - Rules.LOOSE_MAX) * Rules.CLUTTER_POLLUTION * Rules.waste_gap(elapsed))


## Belts carry loose items one tile per step toward their end; REVERSE WORLD runs them backwards.
func _tick_belts(dt: float) -> void:
	_belt_t += dt
	var step := Rules.belt_step(elapsed)
	if _belt_t < step:
		return
	_belt_t -= step
	var flip := -1 if mayhem.chaos == "reverse" else 1
	var tiles: Array = room.belts.keys()
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x * room.belts[a] > b.x * room.belts[b])  # downstream first
	if flip < 0:
		tiles.reverse()
	for at: Vector2i in tiles:
		var next: Vector2i = at + Vector2i(room.belts[at] * flip, 0)
		if stations[at].jam or not room.belts.has(next) or stations[next].jam or not _has_room(next):
			continue
		for id in items_at(at):
			_move(id, next)


## Each map's own trouble: ROT & ROLL rots food left lying and tilts the floor; CIRCUIT BREAKERS trips inputs.
func _tick_map(dt: float) -> void:
	match Rules.map:
		1:
			_rot()
			_roll(dt)
		2:
			_trip_breakers(dt)


func _rot() -> void:
	for id in items:
		var it: Dictionary = items[id]
		if it.k in Rules.FOOD and it.at != null and room.type_at(it.at) == "floor" and elapsed - it.since >= Rules.ROT_S:
			it.k = "rot"
			_dirty_items[id] = true
			mayhem.add_meter(Rules.ROT_POLLUTION)
			_cue({"e": "rot", "at": it.at})


func _roll(dt: float) -> void:
	if elapsed < Rules.TILT_FIRST_S:
		return
	_twist_t -= dt
	if _twist_t <= 0.0:
		_twist_t = Rules.TILT_S
		tilt = -1 if tilt > 0 else 1
		_dirty_globals = true
		_cue({"e": "tilt", "d": tilt})
	_roll_t -= dt
	if _roll_t <= 0.0:
		_roll_t = Rules.ROLL_STEP_S
		mayhem.slide(Rules.ROUND + ["rot"], Vector2i(tilt, 0))


func _trip_breakers(dt: float) -> void:
	if elapsed < Rules.BREAKER_FIRST_S:
		return
	_twist_t -= dt
	if _twist_t > 0.0:
		return
	_twist_t = Rules.breaker_gap(elapsed)
	var live := room.bunkers.filter(func(at: Vector2i) -> bool: return not stations[at].jam)
	if room.bunkers.size() - live.size() >= Rules.MAX_TRIPPED or live.is_empty():
		return
	var at: Vector2i = live[rng.randi() % live.size()]
	stations[at].jam = true
	_dirty_tiles[at] = true
	_cue({"e": "trip", "at": at})


func _tick_orders(dt: float) -> void:
	_order_t -= dt
	if _order_t <= 0.0:
		_order_t = Rules.order_interval(elapsed)
		var open := orders.filter(func(o: Dictionary) -> bool: return not o.get("final", false)).size()
		if open < (1 if training else Rules.MAX_ORDERS):
			var need := 2 if training else (rng.randi_range(1, 2) if Rules.is_rush(elapsed) else rng.randi_range(2, 3))
			var total := 40.0 + 9.0 * need  # eased: plenty of time to fill an order
			orders.append({"id": _take_id(), "m": "metal" if training else Rules.order_material(rng), "need": need, "got": 0,
				"left": total, "total": total, "final": false})
			_cue({"e": "order"})
	for o in orders.duplicate():
		o.left -= dt
		if o.left <= 0.0:
			orders.erase(o)
			_add_coins(-Rules.LATE_PENALTY)
			stats.late += 1
			_cue({"e": "late"})


func _progress(pid: int, at: Vector2i, dt: float) -> void:
	var op := use_op(pid, at)
	if op.is_empty():
		return
	if op.op == "shoo":
		mayhem.shoo(op.creature, dt, pid)
		return
	var st: Dictionary = stations[at]
	st.p += dt
	_used[at] = true
	_dirty_tiles[at] = true
	if st.p < Rules.USE_TIME[op.op]:
		return
	st.p = 0.0
	match op.op:
		"repair":
			st.jam = false
			_cue({"e": "repaired", "at": at, "who": pid})
		"door":
			st.t = Rules.DOOR_OPEN_S
			_cue({"e": "door_open", "at": at})


## What USE on `at` would do for this player right now: {op, creature?} or {} for nothing.
func use_op(pid: int, at: Vector2i) -> Dictionary:
	var creature := mayhem.creature_near(at)
	if creature >= 0:
		return {"op": "shoo", "creature": creature}
	var st: Dictionary = stations.get(at, {})
	if st.is_empty() or held(pid) >= 0:
		return {}
	match room.type_at(at):
		"divider", "belt", "bunker":  # a jammed rail or belt, a tripped breaker
			return {"op": "repair"} if st.jam else {}
		"exit":
			return {"op": "door"} if st.t <= 0.0 else {}
	return {}


## A blast jams the rail or belt tile nearest to it (if the rail is close enough).
func jam_rail(from: Vector2i) -> void:
	var best: Variant = null
	for at in stations:
		if room.type_at(at) in ["divider", "belt"] and not stations[at].jam and Vector2(at).distance_to(Vector2(from)) <= Rules.JAM_RADIUS:
			if best == null or Vector2(at).distance_to(Vector2(from)) < Vector2(best).distance_to(Vector2(from)):
				best = at
	if best != null:
		stations[best].jam = true
		_dirty_tiles[best] = true
		_cue({"e": "jam", "at": best})


## A right item in the right machine input scores and counts toward the oldest open order for that material.
func _load_hopper(item: int, at: Vector2i) -> void:
	var it: Dictionary = items[item]
	var material := room.bunker_material(at)
	var who: int = it.by
	_remove(item)
	if Rules.clean_load(it.k, material):
		_chain()
		var pts := Rules.award(Rules.SORT_POINTS, elapsed, combo)
		_add_coins(pts)
		_cue({"e": "load", "at": at, "pts": pts, "who": who, "m": material})
		for o in orders:
			if o.m == material and o.got < o.need:
				o.got += 1
				_dirty_globals = true
				if o.got >= o.need:
					_finish_order(o, at, who)
				break
	else:
		if combo >= 3:
			_cue({"e": "combo_lost", "at": at, "n": combo})
		combo = 0
		_add_coins(-Rules.WRONG_POINTS)
		stats.wrong += 1
		_cue({"e": "wrong", "at": at, "k": it.k, "pts": -Rules.WRONG_POINTS, "who": who})


func _finish_order(o: Dictionary, at: Vector2i, who: int) -> void:
	var gained := Rules.award(Rules.order_coins(o.need, o.left, o.total), elapsed, combo) * (Rules.FINAL_MULTIPLIER if o.final else 1)
	orders.erase(o)
	_add_coins(gained)
	stats.orders += 1
	_cue({"e": "ship", "at": at, "coins": gained, "m": o.m, "pts": gained, "who": who})


## A bomb in the chute, nuclear waste in the container, a battery in its bin: safe, and worth points.
func _bin(item: int, at: Vector2i) -> void:
	var it: Dictionary = items[item]
	var who: int = it.by
	_remove(item)
	_chain()
	var pts := Rules.award(Rules.HAZARD_POINTS[it.k], elapsed, combo)
	_add_coins(pts)
	_cue({"e": "safe", "at": at, "k": it.k, "pts": pts, "who": who, "out": room.type_at(at) == "exit"})


## One more right delivery in the COMBO chain (the window starts over).
func _chain() -> void:
	combo += 1
	best_combo = maxi(best_combo, combo)
	_combo_t = Rules.COMBO_WINDOW_S
	_dirty_globals = true


# ── rules for where things can go ─────────────────────────────────────────────

func _accepts(item: int, at: Vector2i) -> bool:
	var it: Dictionary = items[item]
	var t := room.type_at(at)
	if t == "gate" and solo:
		return false
	match t:
		"bunker":
			return Rules.dest(it.k) in Rules.MATERIALS and not stations[at].jam
		"chute", "container", "batterybin":
			return Rules.bin_ok(it.k, t)
		"exit":  # an open door: the HAZMAT truck outside takes hazards away
			return stations[at].t > 0.0 and it.k in Rules.HAZARDS
		"wall":
			return false
		"divider", "belt":
			return not stations[at].jam and _has_room(at)
	return _has_room(at)


func _has_room(at: Vector2i) -> bool:
	var t := room.type_at(at)
	if t == "gate" and solo:
		t = "floor"
	return items_at(at).size() < CAPACITY.get(t, 0)


func _pick(pid: int, at: Vector2i) -> bool:
	var here := items_at(at)
	if here.is_empty() or room.type_at(at) in ["bunker", "chute", "container", "batterybin", "exit"]:
		return false
	var id: int = here[-1]
	items[id].at = null
	items[id].by = pid
	_dirty_items[id] = true
	_cue({"e": "pick", "at": at})
	return true


func _empty_handed_at(at: Vector2i, except: int) -> int:
	for pid in players:
		if pid != except and players[pid].tile == at and held(pid) < 0:
			return pid
	return -1


func _reaches(pid: int, at: Vector2i) -> bool:
	if not players.has(pid):
		return false
	var d: Vector2i = at - players[pid].tile
	return absi(d.x) + absi(d.y) <= 1


func _cue(e: Dictionary) -> void:
	events.append(e)
	cues.append(e)
	for i in quests.on_cue(e, combo):  # a quest done pays a bonus
		_add_coins(Rules.QUEST_COINS)
		_cue({"e": "quest", "i": i, "pts": Rules.QUEST_COINS})


func _spawn(kind: String, state: String, at: Vector2i) -> int:
	var id := _take_id()
	items[id] = {"k": kind, "s": state, "at": at, "by": -1, "since": elapsed}
	_dirty_items[id] = true
	return id


func _move(item: int, at: Vector2i) -> void:
	items[item].at = at
	items[item].by = -1
	items[item].since = elapsed
	_dirty_items[item] = true
	_dirty_tiles[at] = true


func _remove(item: int) -> void:
	items.erase(item)
	_dirty_items[item] = true


func _add_coins(n: int) -> void:
	if n < 0:
		mayhem.add_meter(-n)  # every mistake pollutes the factory a little more
	coins = maxi(0, coins + n)
	_dirty_globals = true


func _take_id() -> int:
	_next_id += 1
	return _next_id - 1


# ── network sync (host → guest) ──────────────────────────────────────────────

## Everything (`full`) or only what changed since the last call, as compact JSON-ready data.
func delta(full := false) -> Dictionary:
	var d := {}
	if full:
		d.f = true  # a full snapshot: the guest drops anything not in it (heals lost deltas)
	if full or _dirty_globals:
		d.g = [snappedf(elapsed, 0.01), coins, stats.orders, stats.wrong, stats.late, stats.booms,
			orders.map(func(o: Dictionary) -> Array: return [o.id, o.m, o.need, o.got, snappedf(o.left, 0.1), o.total, o.final]),
			roundi(mayhem.meter), mayhem.chaos, snappedf(mayhem.chaos_left, 0.1), training, tilt, combo, quests.pack()]
	if full or mayhem.dirty:
		d.c = mayhem.pack_creatures()
		mayhem.dirty = false
	var item_ids: Array = items.keys() if full else _dirty_items.keys()
	if not item_ids.is_empty():
		d.i = {}
		for id in item_ids:
			d.i[str(id)] = _pack_item(items[id]) if items.has(id) else null
	var tiles: Array = stations.keys() if full else _dirty_tiles.keys()
	if not tiles.is_empty():
		d.t = {}
		for at in tiles:
			if stations.has(at):
				var st: Dictionary = stations[at]
				d.t["%d,%d" % [at.x, at.y]] = [snappedf(st.p, 0.01), snappedf(st.t, 0.1), st.jam]
	if not events.is_empty():
		d.e = events.map(func(e: Dictionary) -> Dictionary: return _pack_event(e))
		events.clear()
	_dirty_items.clear()
	_dirty_tiles.clear()
	_dirty_globals = false
	return d


## Guest side: merge a delta (or full snapshot) from the host.
func apply(d: Dictionary) -> void:
	if d.has("g"):
		var g: Array = d.g
		elapsed = g[0]
		coins = int(g[1])
		stats = {"orders": int(g[2]), "wrong": int(g[3]), "late": int(g[4]), "booms": int(g[5])}
		orders = g[6].map(func(o: Array) -> Dictionary: return {"id": int(o[0]), "m": o[1], "need": int(o[2]), "got": int(o[3]), "left": o[4], "total": o[5], "final": bool(o[6])})
		mayhem.meter = float(g[7])
		mayhem.chaos = str(g[8])
		mayhem.chaos_left = float(g[9])
		training = g.size() > 10 and bool(g[10])
		tilt = clampi(int(g[11]), -1, 1) if g.size() > 11 else 0
		combo = int(g[12]) if g.size() > 12 else 0
		if g.size() > 13 and g[13] is Array:
			quests.unpack(g[13])
	if d.has("c"):
		mayhem.unpack_creatures(d.c)
	if d.get("f", false):
		items.clear()
	for key in d.get("i", {}):
		var rec: Variant = d.i[key]
		if rec == null:
			items.erase(int(key))
		elif items.has(int(key)) or items.size() < MAX_ITEMS:
			items[int(key)] = _unpack_item(rec)
	for key in d.get("t", {}):
		var xy: PackedStringArray = key.split(",")
		var rec: Array = d.t[key]
		if xy.size() != 2 or not stations.has(Vector2i(int(xy[0]), int(xy[1]))):
			continue  # only this room's own stations
		stations[Vector2i(int(xy[0]), int(xy[1]))] = {"p": float(rec[0]), "t": float(rec[1]), "jam": bool(rec[2])}
	for e in d.get("e", []).slice(0, MAX_EVENTS):
		cues.append(_unpack_event(e))


static func _pack_item(it: Dictionary) -> Array:
	var at: Variant = it.at
	return [it.k, it.s, at.x if at != null else -1, at.y if at != null else -1, it.by]


static func _unpack_item(r: Array) -> Dictionary:
	var at: Variant = Vector2i(int(r[2]), int(r[3])) if int(r[2]) >= 0 else null
	return {"k": r[0], "s": r[1], "at": at, "by": int(r[4])}


static func _pack_event(e: Dictionary) -> Dictionary:
	var out := e.duplicate()
	if e.has("at"):
		out.at = [e.at.x, e.at.y]
	return out


static func _unpack_event(e: Dictionary) -> Dictionary:
	var out := e.duplicate()
	if e.has("at"):
		out.at = Vector2i(int(e.at[0]), int(e.at[1]))
	return out
