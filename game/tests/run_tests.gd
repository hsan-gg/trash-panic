extends SceneTree
## Headless checks: godot --headless --path game --script res://tests/run_tests.gd

const NetScript := preload("res://net/net.gd")
## The rule tests run in this fixed room, so level-design changes to rooms/*.txt never break them.
const FIXTURE := "#############\n#=====|MMMMM#\n#.....|.....#\n#.....|.....#\ne..1..g..2..e\n#.....|.....#\n#.....|.....#\n#K=R=B|=====#\n#############"


func _init() -> void:
	var failures := 0
	var cases := [
		# [net type, expected badge text]
		["5G_SA", "5G SA"],
		["5G_NSA", "5G NSA"],
		["4G", "4G"],
		["3G", "3G"],
		["CELL", "MOBILE DATA"],
		["WIFI", "WI-FI"],
		["ETHERNET", "ETHERNET"],
		["WEB", "BROWSER"],
		["NONE", "NO NETWORK"],
		["OTHER", "ONLINE"],
		["???", "NET ?"],
	]
	for c in cases:
		var got: String = NetScript.badge_for(c[0]).text
		if got != c[1]:
			failures += 1
			printerr("FAIL badge_for(%s) = %s, expected %s" % [c[0], got, c[1]])
	var green: Color = NetScript.badge_for("5G_SA").color
	for t in ["5G_NSA", "4G", "WIFI", "CELL", "NONE"]:
		if NetScript.badge_for(t).color == green:
			failures += 1
			printerr("FAIL %s must not use the 5G SA green" % t)
	failures += _test_gate_messages() + _test_online_rule() + _test_drop_rule() + _test_silence()
	failures += _test_exports() + _test_rules() + _test_rooms() + _test_belts() + _test_collision() + _test_chaos_pack() + _test_shift_loop() + _test_orders() + _test_tutorial() + _test_mayhem() + _test_shift_sync()
	failures += _test_maps() + _test_scoring() + _test_chaos_timing() + _test_scoreboard() + _test_records()
	print("tests: %d failures" % failures)
	quit(1 if failures else 0)


func _fail(msg: String) -> int:
	printerr("FAIL " + msg)
	return 1


func _test_gate_messages() -> int:
	var f := 0
	var cases := [
		["NONE", false, "No network"],
		["NONE", true, "Wi-Fi or turn on mobile data"],
		["WIFI", false, "Contacting"],
		["5G_SA", true, "Reconnecting"],
		["5G_NSA", false, "5G NSA is connected, but"],
	]
	for c in cases:
		var msg: String = NetScript.gate_message_for(c[0], c[1], 30.0 if c[2].contains("is connected") else 0.0)
		if not msg.contains(c[2]):
			f += _fail("gate message for %s/%s = '%s', expected it to mention '%s'" % [c[0], c[1], msg, c[2]])
	return f


func _test_online_rule() -> int:
	var f := 0
	var cases := [
		# [socket open, locked network present, now ms, last pong ms, expected]
		[true, true, 1000, 900, true],
		[true, true, 10000, 9000, true],
		[true, true, 10000, 3999, false],  # open socket but the server went quiet: counts as lost
		[false, true, 1000, 1000, false],  # closed socket is never online
		[true, false, 1000, 1000, false],  # locked network gone: offline even if the socket still looks open
	]
	for c in cases:
		if NetScript.is_online(c[0], c[1], c[2], c[3]) != c[4]:
			f += _fail("is_online(%s, %s, %d, %d) should be %s" % [c[0], c[1], c[2], c[3], c[4]])
	if not "NONE" in NetScript.NO_LINK:
		f += _fail("NONE must count as no link")
	for t in ["5G_SA", "5G_NSA", "4G", "WIFI", "CELL", "WEB"]:
		if t in NetScript.NO_LINK:
			f += _fail("%s must not count as no link" % t)
	return f


func _test_drop_rule() -> int:
	var f := 0
	var cases := [
		# [state, state age ms, pong age ms, expected]
		[WebSocketPeer.STATE_CONNECTING, 14000, 0, false],
		[WebSocketPeer.STATE_CONNECTING, 16000, 0, true],  # handshake never finished
		[WebSocketPeer.STATE_CLOSING, 1000, 0, false],
		[WebSocketPeer.STATE_CLOSING, 3000, 0, true],  # network vanished mid-close
		[WebSocketPeer.STATE_OPEN, 60000, 2000, false],  # open for ages but the server still answers
		[WebSocketPeer.STATE_OPEN, 60000, 10000, true],  # server stopped answering
		[WebSocketPeer.STATE_CLOSED, 60000, 60000, false],
	]
	for c in cases:
		if NetScript.should_drop(c[0], c[1], c[2]) != c[3]:
			f += _fail("should_drop(state %d, age %d, pong age %d) should be %s" % [c[0], c[1], c[2], c[3]])
	return f


func _test_silence() -> int:
	var f := 0
	# [now, last pong, connection opened at, expected silence]
	var cases := [
		[20000, 19000, 15000, 1000],  # normal: counted from the last pong
		[20000, 1000, 19500, 500],  # fresh connection: the old pong from long ago is ignored
		[20000, 20000, 20000, 0],
	]
	for c in cases:
		if NetScript.silence_ms(c[0], c[1], c[2]) != c[3]:
			f += _fail("silence_ms(%d, %d, %d) should be %d" % [c[0], c[1], c[2], c[3]])
	return f






func _test_rules() -> int:
	var f := 0
	var routes := {"can": "metal", "bottle": "plastic", "box": "paper", "paper": "paper", "plank": "wood", "jar": "glass",
		"bomb": "chute", "nuke": "container", "battery": "batterybin"}
	for k in routes:
		if Rules.dest(k) != routes[k]:
			f += _fail("%s goes to %s" % [k, routes[k]])
	if not Rules.clean_load("can", "metal") or Rules.clean_load("can", "glass") or Rules.clean_load("bomb", "metal"):
		f += _fail("only the matching material loads cleanly")
	if not Rules.bin_ok("bomb", "chute") or Rules.bin_ok("bomb", "container") or not Rules.bin_ok("battery", "batterybin"):
		f += _fail("hazard bin routing is wrong")
	if Rules.order_coins(2, 40, 40) != 46 or Rules.order_coins(3, 0, 40) != 39:
		f += _fail("an order pays 15 + 8 per item + a tip up to 15")
	if Rules.stars(Rules.STARS[0] - 1) != 0 or Rules.stars(Rules.STARS[0]) != 1 or Rules.stars(Rules.STARS[2]) != 3:
		f += _fail("star thresholds follow Rules.STARS")
	if Rules.is_rush(Rules.RUSH_FROM_S - 1) or not Rules.is_rush(Rules.RUSH_FROM_S) or Rules.is_rush(Rules.RUSH_END_S):
		f += _fail("rush hour lasts from RUSH_FROM_S to RUSH_END_S")
	if Rules.rush_mult(Rules.RUSH_FROM_S) != 2 or Rules.rush_mult(0.0) != 1:
		f += _fail("points double during rush hour")
	if Rules.waste_gap(Rules.RUSH_FROM_S) >= Rules.waste_gap(0.0) or Rules.order_interval(Rules.RUSH_FROM_S) >= Rules.order_interval(0.0):
		f += _fail("rush hour speeds up the Dropper and the orders")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in 50:
		if not Rules.WASTE_WEIGHTS.has(Rules.waste(rng)):
			f += _fail("the Dropper only rains ordinary waste")
			break
	return f


func _test_rooms() -> int:
	var f := 0
	var room := RoomMap.load_room("sorting_room")
	for p in room.problems():
		f += _fail("sorting_room: " + p)
	if room.bunker_material(room.bunkers[0]) != "metal" or room.bunker_material(room.bunkers[4]) != "glass":
		f += _fail("machine inputs are METAL, PLASTIC, PAPER, WOOD, GLASS from left to right")
	var at := Vector2i(3, 4)
	if room.tile_of(room.world(at)) != at:
		f += _fail("world/tile conversion must round-trip")
	if room.belts.size() < 2 or room.belts.values().min() != -1 or room.belts.values().max() != 1:
		f += _fail("sorting_room needs a belt each way")
	var one_sided := RoomMap.parse(FIXTURE.replace("#.....|.....#\ne", "#..>>.|.....#\ne"))
	if not one_sided.problems().any(func(p: String) -> bool: return p.contains("belt")):
		f += _fail("the validator must reject a belt that stays on one side")
	var broken := RoomMap.parse("#####\n#1g2#\n#####")
	if broken.problems().is_empty():
		f += _fail("the validator must reject a room with no stations")
	return f


## A shift in the Sorting Floor: player 1 on the left, player 2 on the right.
func _shift(solo := false) -> Shift:
	var sh := Shift.new()
	sh.setup(RoomMap.parse(FIXTURE), 7, solo)
	sh.add_player(1, Vector2i(2, 2))
	sh.add_player(2, Vector2i(8, 2))
	return sh


func _stand(sh: Shift, pid: int, at: Vector2i) -> void:
	sh.set_player(pid, at, Vector2i.UP)


func _hold_use(sh: Shift, pid: int, at: Vector2i, seconds: float) -> void:
	sh.use(pid, at)
	_ticks(sh, seconds)
	sh.use(pid, null)


func _ticks(sh: Shift, seconds: float) -> void:
	for i in int(seconds * 10.0):
		sh.tick(0.1)


func _has_cue(sh: Shift, name: String) -> bool:
	return sh.cues.any(func(e: Dictionary) -> bool: return e.e == name)


## An item of `kind` already in player `pid`'s hands.
func _give(sh: Shift, pid: int, kind: String) -> int:
	var id := sh._spawn(kind, "", Vector2i(1, 1))
	sh.items[id].at = null
	sh.items[id].by = pid
	return id


## Belts in the shipped room: carry items across the divider, stop at the end, jam, and run backwards in REVERSE WORLD.
func _test_belts() -> int:
	var f := 0
	var sh := Shift.new()
	var room := RoomMap.load_room("sorting_room")
	sh.setup(room, 3, false)
	var first: Vector2i = room.belts.keys().filter(func(b: Vector2i) -> bool: return room.belts[b] == 1).min()
	var last: Vector2i = room.belts.keys().filter(func(b: Vector2i) -> bool: return room.belts[b] == 1).max()
	var can := sh._spawn("can", "", first)
	_ticks(sh, Rules.BELT_STEP_S * (last.x - first.x + 3))
	if sh.items[can].at != last:
		f += _fail("a belt carries an item to its end tile and stops there (at %s)" % str(sh.items[can].at))
	var jar := sh._spawn("jar", "", first)
	var mid := first + Vector2i(2, 0)
	sh.stations[mid].jam = true
	_ticks(sh, Rules.BELT_STEP_S * 6)
	if sh.items[jar].at != mid - Vector2i(1, 0):
		f += _fail("a jammed belt tile blocks the items behind it")
	sh.stations[mid].jam = false
	sh.mayhem.chaos = "reverse"
	sh.mayhem.chaos_left = Rules.CHAOS_S
	_ticks(sh, Rules.BELT_STEP_S * 8)
	if sh.items[jar].at != first or sh.items[can].at != first + Vector2i(1, 0):
		f += _fail("REVERSE WORLD runs the belts backwards (jar %s, can %s)" % [str(sh.items[jar].at), str(sh.items[can].at)])
	return f


## The idk.md chaos pack: the pig eats paper, intruders pay when caught, the magnet drags cans, low gravity throws far.
func _test_chaos_pack() -> int:
	var f := 0
	var sh := _shift()
	var paper := sh._spawn("paper", "", Vector2i(3, 3))
	sh.mayhem._add_creature("pig", Vector2i(3, 2), false)
	_ticks(sh, 3.0)
	if sh.items.has(paper) or not _has_cue(sh, "eat"):
		f += _fail("the pig walks to paper and eats it")
	sh = _shift()
	sh.mayhem._add_creature("chicken", Vector2i(3, 3), false)
	var chicken: int = sh.mayhem.creatures.keys()[0]
	sh.mayhem._goals[chicken].at = Vector2(5.0, 7.0)  # it is running off to a far corner
	_stand(sh, 1, Vector2i(3, 4))
	_hold_use(sh, 1, Vector2i(3, 3), Rules.SHOO_S.chicken + 0.2)
	if sh.mayhem.creatures.has(chicken) or sh.coins != Rules.CATCH_COINS.chicken:
		f += _fail("holding USE grabs the running chicken and catches it for %d points" % Rules.CATCH_COINS.chicken)
	sh = _shift()
	var can := sh._spawn("can", "", Vector2i(3, 5))
	sh.mayhem.chaos = "magnet"
	sh.mayhem.chaos_left = Rules.CHAOS_S
	_ticks(sh, Rules.MAGNET_STEP_S * 2 + 0.05)
	if sh.items[can].at.y >= 5:
		f += _fail("MAGNETIC MADNESS pulls loose cans toward the back wall")
	sh = _shift()
	_stand(sh, 1, Vector2i(1, 4))
	_give(sh, 1, "jar")
	sh.mayhem.chaos = "lowgrav"
	sh.mayhem.chaos_left = Rules.CHAOS_S
	var jar := sh.held(1)
	sh.throw(1, Vector2i.RIGHT)
	if sh.items[jar].at == null or sh.items[jar].at.x <= 1 + Rules.THROW_TILES:
		f += _fail("LOW GRAVITY throws fly further (landed at %s)" % str(sh.items[jar].at))
	# Soak finding: a special drop or a creature's leftovers never land on a tile that already holds an item.
	sh = _shift()
	sh._spawn("can", "", Vector2i(3, 3))
	sh.mayhem._land("bomb", Vector2i(3, 3))
	sh.mayhem._add_creature("robot", Vector2i(2, 2), false)
	sh._spawn("jar", "", Vector2i(2, 2))
	sh.mayhem._resolve(sh.mayhem.creatures.keys()[0])
	for at in [Vector2i(3, 3), Vector2i(2, 2)]:
		if sh.items_at(at).size() > 1:
			f += _fail("leftovers and drops go to a free tile (two items on %s)" % str(at))
	# Every item lands on the side that can't deliver it: waste left (machine is right), hazards right (bins are left).
	sh = Shift.new()
	var shipped := RoomMap.load_room("sorting_room")
	sh.setup(shipped, 11, false)
	var left_area := shipped.reachable(shipped.spawns[1], false)
	sh.elapsed = Rules.DROP_FIRST_S
	for n in 900:
		sh.tick(0.1)
		for id in sh.items:
			var it: Dictionary = sh.items[id]
			if it.at == null or it.has("checked"):
				continue
			it.checked = true
			var on_left := left_area.has(it.at)
			if (it.k in Rules.HAZARDS) == on_left:
				f += _fail("%s landed on the %s side, where its own bin is" % [it.k, "left" if on_left else "right"])
				break
	# The shark warns, then drags edge waste into the sea and makes a worker in reach drop what they carry.
	sh = _shift()
	sh.elapsed = Rules.SHARK_FIRST_S - 0.05
	_ticks(sh, 0.2)
	if not _has_cue(sh, "shark_alert"):
		f += _fail("the shark is announced before it bites")
	sh = _shift()
	var snack := sh._spawn("box", "", Vector2i(1, 2))
	_stand(sh, 1, Vector2i(2, 2))
	var carried := _give(sh, 1, "can")
	sh.mayhem.bite(Vector2i(1, 2))
	if sh.items.has(snack) or sh.held(1) >= 0 or not sh.items.has(carried) or not _has_cue(sh, "shark"):
		f += _fail("a bite eats edge waste and makes the worker drop what they hold")
	# Smart target: next to the rail but facing the floor, GRAB still drops onto the rail (the highlighted square).
	sh = _shift()
	_stand(sh, 1, Vector2i(5, 3))
	var parcel := _give(sh, 1, "can")
	var spot := sh.target(1, Vector2i(5, 3), Vector2i(5, 2))
	if spot != Vector2i(6, 3) or not sh.grab(1, spot) or sh.items[parcel].at != Vector2i(6, 3):
		f += _fail("carrying beside the rail, the target is the rail (got %s)" % str(spot))
	_stand(sh, 2, Vector2i(7, 3))
	if sh.target(2, Vector2i(7, 3), Vector2i(8, 3)) != Vector2i(6, 3):
		f += _fail("empty-handed beside a loaded rail, the target is the item on it")
	# Facing a station diagonally (out of reach): the target is never that tile, so the button never lies.
	_stand(sh, 1, Vector2i(5, 4))
	_give(sh, 1, "can")
	var diag := sh.target(1, Vector2i(5, 4), Vector2i(6, 5))
	if absi(diag.x - 5) + absi(diag.y - 4) > 1:
		f += _fail("the target is always within reach (got %s)" % str(diag))
	# DASH into an intruder: it's stunned (stops) for a moment; the elephant just bounces you.
	sh = _shift()
	sh.mayhem._add_creature("chicken", Vector2i(3, 3), false)
	var hen: int = sh.mayhem.creatures.keys()[0]
	_stand(sh, 1, Vector2i(2, 3))
	if not sh.dash(1, Vector2i.RIGHT) or not _has_cue(sh, "stun"):
		f += _fail("dashing into a chicken stuns it")
	var before := Vector2(sh.mayhem.creatures[hen].x, sh.mayhem.creatures[hen].y)
	_ticks(sh, 1.0)
	if Vector2(sh.mayhem.creatures[hen].x, sh.mayhem.creatures[hen].y).distance_to(before) > 0.01:
		f += _fail("a stunned creature stays put")
	# You can grab what lies under your own feet, not only on the tile you face.
	sh = _shift()
	_stand(sh, 1, Vector2i(2, 3))
	var under := sh._spawn("jar", "", Vector2i(2, 3))
	if not sh.grab(1, Vector2i(2, 2)) or sh.held(1) != under:
		f += _fail("GRAB picks up the item on your own tile when the faced tile is empty")
	# Review fixes: a full snapshot drops ghost items on the guest; a pig never crosses the divider for food.
	sh = _shift()
	var guest := _shift()
	var ghost := sh._spawn("can", "", Vector2i(2, 2))
	guest.apply(sh.delta(true))
	sh._remove(ghost)
	sh.delta()  # this delta is lost on the way
	guest.apply(sh.delta(true))
	if guest.items.has(ghost):
		f += _fail("a full snapshot removes items the guest missed being deleted")
	sh = _shift()
	var far := sh._spawn("paper", "", Vector2i(9, 3))
	sh.mayhem._add_creature("pig", Vector2i(2, 3), false)
	_ticks(sh, 6.0)
	var pig: Dictionary = sh.mayhem.creatures.values()[0]
	if not sh.items.has(far) or pig.x > 5.5:
		f += _fail("the pig stays on its own side of the divider")
	return f


## Collision is merged into big boxes (no seams to snag on) that cover every blocked tile exactly once, and no floor.
func _test_collision() -> int:
	var f := 0
	var room := RoomMap.load_room("sorting_room")
	var rects := room.solid_rects(false)
	for at in room.tiles:
		var hits := rects.filter(func(r: Rect2i) -> bool: return r.has_point(at)).size()
		if hits != (0 if room.walkable(at, false) else 1):
			f += _fail("tile %s (%s) is covered by %d collision boxes" % [str(at), room.type_at(at), hits])
			break
	if rects.size() > 20:
		f += _fail("collision should be a few merged boxes, got %d" % rects.size())
	if not rects.any(func(r: Rect2i) -> bool: return r.size == Vector2i.ONE and room.type_at(r.position) == "gate"):
		f += _fail("the gate keeps its own collision box")
	return f


func _test_shift_loop() -> int:
	var f := 0
	var sh := _shift()
	# The machine's inputs: right material scores and fills the order, wrong costs points, hazards are refused.
	sh.orders = [{"id": 99, "m": "metal", "need": 2, "got": 0, "left": 40.0, "total": 40.0, "final": false}]
	_stand(sh, 2, Vector2i(7, 2))
	_give(sh, 2, "can")
	if not sh.grab(2, Vector2i(7, 1)) or sh.coins != Rules.SORT_POINTS or sh.orders[0].got != 1:
		f += _fail("a can in METAL scores and counts toward the order")
	_give(sh, 2, "can")
	sh.grab(2, Vector2i(7, 1))
	if not sh.orders.is_empty() or sh.stats.orders != 1 or sh.coins != 10 + Rules.order_coins(2, 40.0, 40.0) or not _has_cue(sh, "ship"):
		f += _fail("the second can finishes the order and pays its bonus")
	_give(sh, 2, "bottle")
	sh.coins = 20
	sh.grab(2, Vector2i(7, 1))
	if sh.coins != 15 or sh.stats.wrong != 1:
		f += _fail("a bottle in METAL is a mistake (-5)")
	var bomb := _give(sh, 2, "bomb")
	if sh.grab(2, Vector2i(7, 1)) or sh.held(2) != bomb:
		f += _fail("the machine refuses a bomb")
	sh.items[bomb].by = -1
	sh.items[bomb].at = Vector2i(0, 0)
	# The special bins take only their own hazard.
	sh = _shift()
	_stand(sh, 1, Vector2i(1, 6))
	_give(sh, 1, "can")
	if sh.grab(1, Vector2i(1, 7)):
		f += _fail("the emergency chute refuses ordinary waste")
	sh.items[sh.held(1)].by = -1
	sh.items[sh.items.keys()[-1]].at = Vector2i(0, 0)
	for pair in [["bomb", Vector2i(1, 6), Vector2i(1, 7)], ["nuke", Vector2i(3, 6), Vector2i(3, 7)], ["battery", Vector2i(5, 6), Vector2i(5, 7)]]:
		var s2 := _shift()
		_stand(s2, 1, pair[1])
		_give(s2, 1, pair[0])
		if not s2.grab(1, pair[2]) or s2.coins != Rules.HAZARD_POINTS[pair[0]] or not _has_cue(s2, "safe"):
			f += _fail("a %s in its own bin is safe and pays %d" % [pair[0], Rules.HAZARD_POINTS[pair[0]]])
	# The divider rail hands items across, jams, and gets repaired.
	sh = _shift()
	_stand(sh, 1, Vector2i(5, 5))
	var can := _give(sh, 1, "can")
	sh.grab(1, Vector2i(6, 5))
	_stand(sh, 2, Vector2i(7, 5))
	if sh.items[can].at != Vector2i(6, 5) or not sh.grab(2, Vector2i(6, 5)) or sh.held(2) != can:
		f += _fail("an item placed on the rail is picked up by the partner")
	sh.jam_rail(Vector2i(6, 5))
	if not sh.stations[Vector2i(6, 5)].jam:
		f += _fail("a blast jams the nearest rail tile")
	_stand(sh, 1, Vector2i(5, 5))
	var again := _give(sh, 1, "bottle")
	if sh.grab(1, Vector2i(6, 5)):
		f += _fail("a jammed rail takes no items")
	sh.items[again].by = -1
	sh.items[again].at = Vector2i(0, 0)
	_hold_use(sh, 1, Vector2i(6, 5), Rules.USE_TIME.repair + 0.2)
	if sh.stations[Vector2i(6, 5)].jam or not _has_cue(sh, "repaired"):
		f += _fail("holding USE repairs the rail")
	# Exit doors open for a while.
	sh = _shift()
	_stand(sh, 2, Vector2i(11, 4))
	_hold_use(sh, 2, Vector2i(12, 4), Rules.USE_TIME.door + 0.2)
	if sh.stations[Vector2i(12, 4)].t <= 0.0:
		f += _fail("holding USE opens the exit door")
	_give(sh, 2, "can")
	if sh.grab(2, Vector2i(12, 4)):
		f += _fail("an open door doesn't take ordinary waste")
	sh.items[sh.held(2)].k = "battery"
	var before := sh.coins
	if not sh.grab(2, Vector2i(12, 4)) or sh.coins <= before or sh.held(2) >= 0:
		f += _fail("an open exit door takes hazards out to the HAZMAT truck for points")
	_ticks(sh, Rules.DOOR_OPEN_S + 0.5)
	if sh.stations[Vector2i(12, 4)].t != 0.0:
		f += _fail("the exit door closes again")
	_give(sh, 2, "battery")
	if sh.grab(2, Vector2i(12, 4)):
		f += _fail("a shut door takes nothing")
	# The Dropper rains waste all shift long, calm specials only after DROP_FIRST_S.
	sh = _shift()
	_ticks(sh, 20.0)
	var rained := sh.items.values().filter(func(it): return it.k in Rules.WASTE_WEIGHTS)
	if rained.size() < 4 or sh.items.size() != rained.size() or _has_cue(sh, "drop_alert"):
		f += _fail("the Dropper rains ordinary waste from the start and no specials before %d s" % Rules.DROP_FIRST_S)
	# Piled-up waste pollutes the factory.
	sh = _shift()
	for i in Rules.LOOSE_MAX + 5:  # 25 floor tiles on the fixture's left side
		sh._spawn("can", "", Vector2i(1 + i % 5, 2 + i / 5))
	_ticks(sh, 4.0)
	if sh.mayhem.meter <= 0.0:
		f += _fail("too much loose waste fills the pollution meter")
	return f


func _test_orders() -> int:
	var f := 0
	var sh := _shift()
	_ticks(sh, 3.2)
	if sh.orders.is_empty() or sh.orders[0].need < 2:
		f += _fail("the machine starts asking for materials")
	sh.orders[0].left = 0.05
	var before := sh.orders.size()
	sh.coins = 30
	_ticks(sh, 0.2)
	if sh.orders.size() != before - 1 or sh.coins != 30 - Rules.LATE_PENALTY or sh.stats.late != 1:
		f += _fail("an expired order costs %d" % Rules.LATE_PENALTY)
	sh = _shift()
	sh.elapsed = Rules.FINAL_CONTRACT_AT - 0.05
	_ticks(sh, 0.2)
	if not sh.orders.any(func(o): return o.final and o.need == Rules.FINAL_NEED):
		f += _fail("a big final contract arrives at %d s" % Rules.FINAL_CONTRACT_AT)
	# Tutorial shift: cans only, one METAL order, no specials yet.
	sh = _shift()
	sh.training = true
	_ticks(sh, 25.0)
	if sh.orders.size() != 1 or sh.orders[0].m != "metal" or sh.orders[0].need != 2:
		f += _fail("training: one METAL order for two items")
	if not sh.items.values().all(func(it): return it.k == "can"):
		f += _fail("training: the Dropper rains only cans")
	return f


func _test_tutorial() -> int:
	var f := 0
	var room := RoomMap.load_room("sorting_room")
	var types := room.tiles.values()
	var cues := ["load", "ship", "belt", "catch"]
	var steps: Array = Rules.TUTORIAL[1] + Rules.TUTORIAL[2]
	for step in steps:
		if step.at not in ["item", "belt_in"] and step.at not in types:
			f += _fail("tutorial points at a station the room has: %s" % step.at)
		for c in step.get("done_on", []):
			if c not in cues:
				f += _fail("tutorial waits for a real cue: %s" % c)
		if step.get("seconds", 0.0) == 0.0 and step.get("done_on", []).is_empty() and not step.get("held", false):
			f += _fail("every tutorial step can be completed")
	# The arrow: a can on the left goes to the belt, on the right to METAL; a bomb on the left to the chute.
	var sh := Shift.new()
	sh.setup(room, 3, false)
	var left := room.reachable(room.spawns[1], false)
	var right := room.reachable(room.spawns[2], false)
	var belt: Variant = Guide.target(sh, left, "can")
	if belt == null or room.type_at(belt) != "belt" or room.belts[belt] != 1:
		f += _fail("left worker's can goes on the belt to the machine side")
	if Guide.target(sh, right, "can") != room.bunkers[0]:
		f += _fail("right worker's can goes in the METAL input")
	if Guide.target(sh, left, "bomb") == null or room.type_at(Guide.target(sh, left, "bomb")) != "chute":
		f += _fail("left worker's bomb goes in the chute")
	var back: Variant = Guide.target(sh, right, "bomb")
	if back == null or room.belts.get(back, 0) != -1:
		f += _fail("right worker's bomb goes back on the lower belt")
	if Guide.incoming_belt(sh, right) == null:
		f += _fail("the right worker has a belt end where deliveries arrive")
	return f


func _test_mayhem() -> int:
	var f := 0
	# The Dropper warns first, then something lands.
	var sh := _shift()
	sh.elapsed = Rules.DROP_FIRST_S - 0.1
	_ticks(sh, 0.3)
	if not _has_cue(sh, "drop_alert"):
		f += _fail("the Dropper warns before it drops a special")
	_ticks(sh, Rules.DROP_WARN_S + 0.2)
	if not _has_cue(sh, "drop"):
		f += _fail("the special lands after the warning")
	# A bomb thrown into the chute never blows.
	sh = _shift()
	sh.mayhem._land("bomb", Vector2i(2, 5))
	_stand(sh, 1, Vector2i(2, 4))
	if not sh.grab(1, Vector2i(2, 5)):
		f += _fail("a bomb can be picked up")
	_stand(sh, 1, Vector2i(1, 6))
	sh.grab(1, Vector2i(1, 7))
	_ticks(sh, Rules.BOMB_FUSE_S + 1.0)
	if _has_cue(sh, "boom") or sh.items.values().any(func(it): return it.k == "bomb"):
		f += _fail("a bomb in the chute is safe")
	# An ignored bomb explodes: a mistake that pollutes, and it jams the rail when it goes off close to it.
	sh = _shift()
	sh.mayhem._land("bomb", Vector2i(5, 5))
	_ticks(sh, Rules.BOMB_FUSE_S + 0.5)
	if not _has_cue(sh, "boom") or sh.mayhem.meter <= 0.0 or sh.stats.booms != 1:
		f += _fail("an ignored bomb explodes and fills the meter")
	if not sh.stations.values().any(func(st): return st.jam):
		f += _fail("a blast next to the rail jams it")
	# Nuclear waste and batteries left alone leak.
	for kind in ["nuke", "battery"]:
		sh = _shift()
		sh.mayhem._land(kind, Vector2i(2, 5))
		_ticks(sh, Rules.LEAK_S[kind] + 0.5)
		if not _has_cue(sh, "leak"):
			f += _fail("a forgotten %s leaks" % kind)
	# Robot: deactivating it leaves scrap metal and a battery.
	sh = _shift()
	sh.mayhem._add_creature("robot", Vector2i(3, 3), false)
	var robot: int = sh.mayhem.creatures.keys()[0]
	if sh.mayhem.creature_near(Vector2i(3, 3)) != robot:
		f += _fail("a creature can be found where it stands")
	for i in 25:
		if sh.mayhem.creatures.has(robot):
			sh.mayhem.shoo(robot, 0.1)
	var kinds := sh.items.values().map(func(it): return it.k)
	if sh.mayhem.creatures.size() != 0 or not ("can" in kinds) or not ("battery" in kinds) or sh.coins != Rules.ROBOT_COINS:
		f += _fail("a deactivated robot leaves a can and a battery")
	# Raccoon: steals, and catching it gives the loot back.
	sh = _shift()
	var loot := sh._spawn("can", "", Vector2i(3, 3))
	sh.mayhem._add_creature("raccoon", Vector2i(3, 4), false)
	var coon: int = sh.mayhem.creatures.keys()[0]
	_ticks(sh, 1.2)
	if sh.mayhem.creatures[coon].loot != "can" or sh.items.has(loot):
		f += _fail("a raccoon steals loose waste")
	for i in 15:
		if sh.mayhem.creatures.has(coon):
			sh.mayhem.shoo(coon, 0.1)
	if sh.mayhem.creatures.size() != 0 or not sh.items.values().any(func(it): return it.k == "can"):
		f += _fail("catching the raccoon returns the loot")
	# Elephant: scaring it only works with an open exit door, then it bolts out for the rescue bonus.
	sh = _shift()
	sh.mayhem._add_creature("elephant", Vector2i(3, 3), false)
	var jumbo: int = sh.mayhem.creatures.keys()[0]
	sh.mayhem.shoo(jumbo, 0.1)
	_ticks(sh, 4.0)
	if sh.mayhem.creatures.size() != 1 or sh.coins != 0:
		f += _fail("a scared elephant can't leave through a closed door")
	sh.stations[Vector2i(0, 4)].t = Rules.DOOR_OPEN_S
	sh.mayhem.shoo(jumbo, 0.1)
	_ticks(sh, 5.0)
	if sh.mayhem.creatures.size() != 0 or sh.coins != Rules.RESCUE_COINS or not _has_cue(sh, "rescued"):
		f += _fail("a scared elephant bolts out of an open door (+%d)" % Rules.RESCUE_COINS)
	# A full pollution meter starts CHAOS STATE for 20 s, then the factory recovers.
	sh = _shift()
	sh.mayhem.add_meter(ceili(Rules.CHAOS_AT / Rules.METER_PER_POINT) + 2)
	_ticks(sh, 0.2)
	if sh.mayhem.chaos == "":
		f += _fail("a full meter starts CHAOS STATE")
	_ticks(sh, Rules.CHAOS_S + 0.5)
	if sh.mayhem.chaos != "" or sh.mayhem.meter > Rules.CHAOS_AFTER:
		f += _fail("chaos ends and the meter drops")
	return f


func _test_shift_sync() -> int:
	var f := 0
	var sh := _shift()
	sh.orders = [{"id": 5, "m": "wood", "need": 3, "got": 1, "left": 22.5, "total": 40.0, "final": true}]
	sh.mayhem._add_creature("elephant", Vector2i(3, 3), false)
	sh.mayhem.meter = 42.0
	sh.jam_rail(Vector2i(6, 3))
	sh._spawn("plank", "", Vector2i(2, 2))
	var guest := Shift.new()
	guest.setup(RoomMap.parse(FIXTURE), 7, false)  # the guest plays the host's room
	guest.apply(JSON.parse_string(JSON.stringify(sh.delta(true))))
	if guest.orders.size() != 1 or guest.orders[0].need != 3 or guest.orders[0].got != 1 or not guest.orders[0].final:
		f += _fail("orders (with progress) must reach the guest")
	if guest.mayhem.creatures.size() != 1 or int(guest.mayhem.meter) != 42:
		f += _fail("creatures and the pollution meter must reach the guest")
	if not guest.stations[Vector2i(6, 3)].jam or guest.items.size() != 1:
		f += _fail("a jammed rail and the waste must reach the guest")
	if not guest.cues.any(func(e): return e.e == "jam"):
		f += _fail("events must reach the guest")
	# A malicious host can't flood the guest: items, stations and events per delta are capped.
	var flood := {"i": {}, "t": {"99,99": [0, 0, true]}, "e": []}
	for n in 500:
		flood.i[str(10000 + n)] = ["can", "", 2, 2, -1]
		flood.e.append({"e": "fall"})
	guest.cues.clear()
	guest.apply(flood)
	if guest.items.size() > Shift.MAX_ITEMS or guest.stations.has(Vector2i(99, 99)) or guest.cues.size() > Shift.MAX_EVENTS:
		f += _fail("apply() caps items (%d), ignores unknown stations and caps events (%d)" % [guest.items.size(), guest.cues.size()])
	# Then only what changes travels.
	sh._spawn("jar", "", Vector2i(3, 2))
	var d := sh.delta()
	if d.has("c") or d.i.size() != 1:
		f += _fail("deltas carry only what changed")
	return f


func _test_exports() -> int:
	var cfg := ConfigFile.new()
	if cfg.load("res://export_presets.cfg") != OK:
		return _fail("export_presets.cfg is missing")
	var f := 0
	for section in cfg.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options"):
			if not str(cfg.get_value(section, "include_filter", "")).contains("rooms/*.txt"):
				f += _fail("%s (%s) must export rooms/*.txt" % [section, cfg.get_value(section, "name")])
	return f


## The maps: each one's room plays, ROT & ROLL rots food and rolls round waste downhill, CIRCUIT BREAKERS
## trips machine inputs that refuse waste until someone holds USE on them.
func _test_maps() -> int:
	var f := 0
	for n in Rules.MAPS.size():
		Rules.set_map(n)
		for p in RoomMap.load_room(Rules.MAPS[n].room).problems():
			f += _fail("map %d: %s" % [n + 1, p])
		for kind in Rules.WASTE_WEIGHTS:
			if Rules.dest(kind) not in Rules.MATERIALS:
				f += _fail("map %d: %s has no machine input" % [n + 1, kind])
	Rules.set_map(1)
	var sh := _shift()
	var apple := sh._spawn("apple", "", Vector2i(2, 5))
	_ticks(sh, Rules.ROT_S + 0.5)
	if sh.items[apple].k != "rot" or not _has_cue(sh, "rot") or sh.mayhem.meter <= 0.0:
		f += _fail("food left on the floor rots and pollutes (%s, meter %.1f)" % [sh.items[apple].k, sh.mayhem.meter])
	sh = _shift()
	sh.elapsed = Rules.TILT_FIRST_S
	var can := sh._spawn("can", "", Vector2i(3, 5))
	var box := sh._spawn("box", "", Vector2i(3, 6))
	sh.tick(0.1)
	if sh.tilt != 1 or not _has_cue(sh, "tilt") or sh.items[can].at != Vector2i(4, 5) or sh.items[box].at != Vector2i(3, 6):
		f += _fail("the tilted floor rolls round waste (not boxes) downhill (tilt %d, can %s)" % [sh.tilt, str(sh.items[can].at)])
	var guest := Shift.new()
	guest.setup(sh.room, 7, false)
	guest.apply(JSON.parse_string(JSON.stringify(sh.delta(true))))
	if guest.tilt != sh.tilt:
		f += _fail("the guest mirrors the tilt")
	Rules.set_map(2)
	sh = _shift()
	sh.elapsed = Rules.BREAKER_FIRST_S
	sh.tick(0.1)
	var tripped: Array = sh.room.bunkers.filter(func(at: Vector2i) -> bool: return sh.stations[at].jam)
	if tripped.size() != 1 or not _has_cue(sh, "trip"):
		f += _fail("CIRCUIT BREAKERS trips one machine input (%d tripped)" % tripped.size())
		Rules.set_map(0)
		return f
	var at: Vector2i = tripped[0]
	var kind: String = {"metal": "can", "plastic": "bottle", "circuit": "board", "copper": "cable", "glass": "jar"}[sh.room.bunker_material(at)]
	_stand(sh, 2, at + Vector2i.DOWN)
	var item := _give(sh, 2, kind)
	if sh.grab(2, at):
		f += _fail("a tripped input refuses waste")
	sh._remove(item)
	_hold_use(sh, 2, at, Rules.USE_TIME.repair + 0.2)
	var before := sh.coins
	_give(sh, 2, kind)
	if sh.stations[at].jam or not sh.grab(2, at) or sh.coins <= before:
		f += _fail("holding USE resets the breaker and the input takes waste again")
	Rules.set_map(0)
	return f



## The results scoreboard ranks workers by their own points and gives each a different title.
func _test_scoreboard() -> int:
	var f := 0
	var b := Scoreboard.new()
	for e in [{"e": "load", "who": 1, "pts": 10}, {"e": "load", "who": 1, "pts": 10}, {"e": "rescued", "who": 2, "pts": 30},
			{"e": "wrong", "who": 2, "pts": -5}, {"e": "load", "who": 2, "pts": 10}, {"e": "late"}]:
		b.track(e)
	if b.ranking([1, 2]) != [2, 1] or b.row(2).pts != 35 or b.row(2).oops != 1:
		f += _fail("the scoreboard sums each worker's points and ranks them (%s)" % str(b.ranking([1, 2])))
	var t := b.titles([1, 2])
	if t[1] != "SULTAN OF SORTING" or t[2] == t[1]:
		f += _fail("each worker gets their own title (%s)" % str(t))
	return f


## The menu's HALL OF FAME keeps the newest shifts first (at most KEEP) and the best score per map.
func _test_records() -> int:
	var f := 0
	Records.path = "user://test_records.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Records.path))
	for c in [50, 200, 120]:
		Records.add({"t": 0, "map": 1, "coins": c, "stars": Rules.stars(c), "mine": c / 2, "title": "X", "rank": 1, "partner": "PAL", "partner_pts": 0})
	for i in Records.KEEP:
		Records.add({"t": 0, "map": 0, "coins": i, "stars": 0, "mine": 0, "title": "X", "rank": 1, "partner": "PAL", "partner_pts": 0})
	if Records.best(1).get("coins", 0) != 200 or not Records.best(2).is_empty():
		f += _fail("the best score per map is kept")
	if Records.recent().size() != Records.KEEP or Records.recent()[0].coins != Records.KEEP - 1:
		f += _fail("recent shifts are newest first and capped")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Records.path))
	return f


## Chaos (blackout & co) is a mid-game twist: one comes by mid-shift even with a clean floor, none starts near the
## end, and none is still running when the shift ends.
func _test_chaos_timing() -> int:
	var f := 0
	var sh := _shift()
	sh.elapsed = Rules.CHAOS_FORCE_AT - 1.0
	_ticks(sh, 2.0)
	if sh.mayhem.chaos == "":
		f += _fail("a chaos twist starts by mid-shift even when the meter is low")
	sh = _shift()
	sh.elapsed = Rules.SHIFT_S - Rules.CHAOS_S + 2.0
	sh.mayhem.meter = 100.0
	_ticks(sh, 1.0)
	if sh.mayhem.chaos != "":
		f += _fail("no chaos starts when it couldn't finish before the whistle")
	sh = _shift()
	sh.elapsed = Rules.SHIFT_S - Rules.CHAOS_S - Rules.CHAOS_END_GAP - 1.0
	sh.mayhem.meter = 100.0
	_ticks(sh, 1.5)
	var started := sh.mayhem.chaos != ""
	_ticks(sh, Rules.CHAOS_S)
	if not started or sh.mayhem.chaos != "":
		f += _fail("a late chaos ends before the shift does (started %s, still %s)" % [started, sh.mayhem.chaos])
	return f


## v5 scoring (GAME_PLAN.md §3-4): levels climb, the combo chain multiplies points and breaks, quests pay once.
func _test_scoring() -> int:
	var f := 0
	if Rules.level(0.0) != 1 or Rules.level(Rules.LEVEL_S * 2 + 1) != 3 or Rules.level(999.0) != Rules.MAX_LEVEL:
		f += _fail("the difficulty climbs a level every LEVEL_S up to MAX_LEVEL")
	if Rules.waste_gap(Rules.LEVEL_S * 3 + 1) >= Rules.waste_gap(0.0) or Rules.max_hazards(Rules.LEVEL_S * 4 + 1) <= Rules.max_hazards(0.0):
		f += _fail("higher levels drop waste faster and allow more specials")
	if Rules.combo_mult(2) != 1.0 or Rules.combo_mult(3) != 1.5 or Rules.combo_mult(12) != 3.0:
		f += _fail("combo multiplier steps x1.5 at 3 and x3 at 10")
	Rules.set_map(0)
	var sh := _shift()
	sh.quests.list = [{"k": "sort", "need": 3, "got": 0}, {"k": "combo", "need": 3, "got": 0}, {"k": "hazards", "need": 9, "got": 0}]
	_stand(sh, 2, Vector2i(7, 2))
	var gains := []
	for i in 3:
		var before := sh.coins
		_give(sh, 2, "can")
		sh.grab(2, Vector2i(7, 1))
		gains.append(sh.coins - before)
	if sh.combo != 3 or gains[2] <= gains[0]:
		f += _fail("right loads in a row build a combo worth more (gains %s, combo %d)" % [str(gains), sh.combo])
	if sh.quests.done_count() != 2 or not _has_cue(sh, "quest"):
		f += _fail("quests count loads and the combo, and say when they're done")
	_stand(sh, 2, Vector2i(8, 2))
	_give(sh, 2, "can")
	sh.grab(2, Vector2i(8, 1))
	_stand(sh, 2, Vector2i(7, 2))
	if sh.combo != 0:
		f += _fail("a wrong input breaks the combo")
	_give(sh, 2, "can")
	sh.grab(2, Vector2i(7, 1))
	_ticks(sh, Rules.COMBO_WINDOW_S + 0.2)
	if sh.combo != 0:
		f += _fail("a combo breaks when the next delivery is too slow")
	_ticks(sh, Rules.QUEST_SWAP_S + 0.2)
	var fresh: Array = sh.quests.list.filter(func(q: Dictionary) -> bool: return q.got < q.need)
	var kinds := {}
	for q: Dictionary in sh.quests.list:
		kinds[q.k] = true
	if fresh.size() != 3 or kinds.size() != 3 or sh.quests.done_count() != 2:
		f += _fail("done quests make way for new random ones, and never run out (%s)" % str(sh.quests.pack()))
	var guest := Shift.new()
	guest.setup(RoomMap.parse(FIXTURE), 7, false)
	guest.apply(JSON.parse_string(JSON.stringify(sh.delta(true))))
	if JSON.stringify(guest.quests.pack()) != JSON.stringify(sh.quests.pack()) or guest.quests.done_count() != 2:
		f += _fail("the guest mirrors the quests")
	return f
