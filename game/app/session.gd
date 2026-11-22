class_name Session
extends Node3D
## One online shift. The host runs the Shift and streams deltas; the guest mirrors it and sends intents.
## Both draw the same RoomView, move their own worker locally and see the partner interpolated.

signal finished(again: bool)

const SEND_EVERY := 0.1
const SNAPSHOT_EVERY := 3.0
const CAMERA_AT := Vector3(0, 16.5, 8.4)
const SOUNDS := {
	"pick": ["pop_1", 1.1], "throw": ["sfx_whoosh", 1.0], "load": ["mx_clank", 1.0], "fall": ["pop_2", 0.8],
	"ship": ["sfx_horn", 1.0], "late": ["ui_error", 0.8], "wrong": ["ui_error", 1.1], "reject": ["ui_error", 0.7],
	"safe": ["ui_confirmation", 1.2], "jam": ["mx_clank", 0.6], "repaired": ["ui_back", 1.0], "door_open": ["ui_pluck", 0.8],
	"catch": ["pop_3", 1.3], "rush": ["sfx_alarm", 1.0], "rush_end": ["ui_back", 0.9], "contract": ["sfx_horn", 0.8],
	"drop_alert": ["sfx_alarm", 1.5], "drop": ["mx_fall", 1.0], "boom": ["mx_slam", 0.55], "tick": ["ui_tick", 1.7],
	"leak": ["ui_bong", 0.6], "steal": ["pop_3", 1.7], "eat": ["pop_2", 0.6], "shark_alert": ["sfx_alarm", 0.8], "shark": ["mx_slam", 0.8], "stun": ["pop_3", 0.7], "bonk": ["mx_clank", 1.4], "robot_down": ["ui_confirmation", 0.9], "rescued": ["sfx_horn", 1.3],
	"rot": ["pop_2", 0.5], "tilt": ["mx_clank", 0.5], "trip": ["sfx_alarm", 1.8],
	"raccoon_gone": ["ui_error", 1.0], "chaos": ["sfx_alarm", 0.7], "chaos_end": ["ui_back", 1.0], "final": ["sfx_alarm", 1.2],
	"level": ["sfx_horn", 1.4], "quest": ["gem_gather", 1.2], "combo_lost": ["ui_scratch", 1.0],
}

var room: RoomMap
var shift := Shift.new()
var view := RoomView.new()
var hud := Hud.new()
var controls := Controls.new()
var player := Player.new()
var partner: RemotePlayer
var camera := Camera3D.new()
var host := false
var tutorial: Tutorial
var _chaos_on := ""
var start_at := 0.0
var ends_at := 0.0

var _send_t := 0.0
var _snap_t := 0.0
var _need_full := true
var _state_t := 0.0
var _over := false
var _partner_id := -1
var _area := {}  ## the floor this player's worker can walk on (its side of the divider)


func setup(info: Dictionary) -> void:
	host = Match.is_host()
	start_at = float(info.start_at) / 1000.0
	ends_at = float(info.ends_at) / 1000.0
	var solo: bool = info.solo
	Rules.set_map(Match.players.get(Match.host_id, {}).get("ch", 0))  # the host's map, before the room (its routes)
	room = RoomMap.load_room(Rules.MAPS[Rules.map].room)
	shift.setup(room, int(info.seed), solo)
	# A calm training shift whenever either player still needs the tutorial; both phones know both flags.
	shift.training = Match.players.values().any(func(p: Dictionary) -> bool: return not p.get("tut", true))
	_area = room.reachable(room.spawns[1 if host else 2], solo)
	view.holder_point = _holder_point
	view.build(room, shift, solo)
	view.cue.connect(_on_cue)
	add_child(view)
	camera.position = CAMERA_AT
	camera.fov = 44.0
	add_child(camera)
	camera.look_at(Vector3(0, 0, -0.2))
	var me: Dictionary = Match.players.get(Match.my_id, {"skin": 0})
	player.avatar.setup(me.skin)
	player.avatar.ring(Avatar.TEAM[0 if host else 1])
	add_child(player)
	player.global_position = room.world(room.spawns[1 if host else 2])
	player.avatar.rotation.y = PI
	for id in Match.players:
		if id != Match.my_id:
			_partner_id = id
			partner = RemotePlayer.new()
			add_child(partner)
			partner.setup(Match.players[id].merged({"bot": false}), room.world(room.spawns[2 if host else 1]))
			partner.avatar.ring(Avatar.TEAM[1 if host else 0])
	if host:
		shift.add_player(Match.my_id, room.spawns[1])
		if _partner_id >= 0:
			shift.add_player(_partner_id, room.spawns[2])
	else:
		shift.items.clear()  # the host's snapshot fills the mirror
	add_child(controls)
	controls.add_child(hud)
	hud.again_pressed.connect(func() -> void: finished.emit(true))
	hud.menu_pressed.connect(func() -> void: finished.emit(false))
	controls.action_pressed.connect(_on_action_pressed)
	controls.action_released.connect(_on_action_released)
	controls.dash_pressed.connect(func() -> void:
		if player.frozen:
			return
		player.dash()
		var dir := player.facing_dir()
		_act({"a": "dash", "d": [dir.x, dir.y]})  # barging into an intruder stuns it
		Fx.puff(self, player.global_position + Vector3(0, 0.1, 0))
		Fx.burst(self, player.global_position + Vector3(0, 0.6, 0), Look.YELLOW, 10)  # dash sparkles
		Sfx.play("sfx_whoosh", 1.3, -4.0))
	Match.state.connect(_on_partner_state)
	Match.payload.connect(_on_payload)
	Match.snapshot.connect(func(d: Dictionary) -> void:
		if not host:
			shift.apply(d))
	Match.partner_left.connect(_on_partner_left)
	Match.ended.connect(_end)
	_countdown()


func _countdown() -> void:
	Sfx.music(Rules.MAPS[Rules.map].music)
	var map: Dictionary = Rules.MAPS[Rules.map]
	hud.slam(map.name, Look.YELLOW)
	for i in 3:
		var at := start_at - 3 + i
		await get_tree().create_timer(maxf(0.0, at - Clock.now())).timeout
		Sfx.play("ui_tick", 1.0 + i * 0.15)
		hud.slam(str(3 - i), Look.YELLOW)
	await get_tree().create_timer(maxf(0.0, start_at - Clock.now())).timeout
	Sfx.play("ui_confirmation")
	hud.slam("SORT IT!", Look.MINT)
	player.frozen = false
	if shift.training:  # both players get their side's tutorial (a veteran can skip it)
		tutorial = Tutorial.new()
		tutorial.setup(shift, Match.my_id, 1 if host else 2, _area)
		hud.add_child(tutorial)
	else:
		hud.say("left_side" if host else "right_side")
	if Rules.map > 0:  # after the side hint: what's different on this map
		await get_tree().create_timer(5.5).timeout
		hud.say(map.tag)


func _physics_process(delta: float) -> void:
	var now := Clock.now()
	var facing := _target()
	view.highlight(facing if not player.frozen else null)
	_guide()
	player.carrying = shift.held(Match.my_id) >= 0
	_update_use_label()
	_apply_mayhem(now)
	if host:
		shift.set_player(Match.my_id, room.tile_of(player.global_position), facing - room.tile_of(player.global_position))
		if now >= start_at and not _over:
			shift.tick(minf(delta, maxf(0.0, ends_at - now)))
		_stream(delta)
	elif now >= start_at and not _over:
		shift.elapsed = clampf(now - start_at, 0.0, Rules.SHIFT_S)
	hud.refresh(shift)
	_state_t += delta
	if _state_t >= SEND_EVERY:
		_state_t = 0.0
		Match.send_state(player.global_position, player.avatar.rotation.y, player.avatar.anim_id, shift.held(Match.my_id))
	if now >= ends_at and not _over:
		_end()


## The square GRAB acts on (shown highlighted): the best tile around the worker, not only the one it faces.
func _target() -> Vector2i:
	return shift.target(Match.my_id, room.tile_of(player.global_position), player.facing_tile(room))


## The arrow: where the carried item goes (always on), else the tutorial's next stop.
func _guide() -> void:
	var held := shift.held(Match.my_id)
	if held >= 0 and shift.items.has(held):
		var kind: String = shift.items[held].k
		var at: Variant = Guide.target(shift, _area, kind)
		view.mark(at, Guide.glyph(shift, at) if at != null else "", ItemArt.dest_color(kind))
	elif is_instance_valid(tutorial):
		view.mark(tutorial.target())
	else:
		view.mark(null)


func _stream(delta: float) -> void:
	if _partner_id < 0:
		shift.delta()  # nobody to tell; keep dirty sets from growing
		return
	_send_t += delta
	_snap_t += delta
	if _send_t >= SEND_EVERY:
		_send_t = 0.0
		var d := shift.delta()
		if not d.is_empty() and not Match.send_to({"k": "d", "d": d}):
			_need_full = true  # too big for one frame: heal with a snapshot
	if _snap_t >= (1.05 if _need_full else SNAPSHOT_EVERY):
		_snap_t = 0.0
		_need_full = false
		Match.send_snapshot(shift.delta(true))


# ── input → actions (host) or intents (guest) ───────────────────────────────

## One ACTION button: carrying, it delivers to the station in reach that takes the item, else throws it;
## empty-handed, it holds USE when the faced tile needs it (creature, jam, breaker, door), else it grabs.
func _on_action_pressed() -> void:
	if player.frozen:
		return
	if _carrying() and not shift.can_place(Match.my_id, _target()):
		_throw()
		return
	if not _carrying() and not shift.use_op(Match.my_id, player.facing_tile(room)).is_empty():
		player.using = true
		_act({"a": "use", "t": _xy(player.facing_tile(room))})
		return
	_act({"a": "grab", "t": _xy(_target())})


func _on_action_released() -> void:
	if player.using:
		player.using = false
		_act({"a": "unuse"})


func _throw() -> void:
	var dir := player.facing_dir()
	_act({"a": "throw", "d": [dir.x, dir.y]})


func _carrying() -> bool:
	var held := shift.held(Match.my_id)
	return held >= 0 and shift.items.has(held)


func _act(intent: Dictionary) -> void:
	if host:
		_apply_intent(Match.my_id, intent)
	else:
		Match.send_to({"k": "a", "i": intent})


func _apply_intent(pid: int, i: Dictionary) -> void:
	match str(i.get("a", "")):
		"grab":
			shift.grab(pid, _tile(i.get("t")))
		"use":
			shift.use(pid, _tile(i.get("t")))
		"unuse":
			shift.use(pid, null)
		"throw", "dash":
			var d: Array = i.get("d", [0, 0]) if i.get("d") is Array else [0, 0]
			if d.size() == 2:
				var dir := Vector2i(int(d[0]), int(d[1]))
				if i.a == "throw":
					shift.throw(pid, dir)
				else:
					shift.dash(pid, dir)


func _on_payload(d: Dictionary) -> void:
	if host and d.get("k") == "a" and d.get("i") is Dictionary and _partner_id >= 0:
		_apply_intent(_partner_id, d.i)
	elif not host and d.get("k") == "d" and d.get("d") is Dictionary:
		shift.apply(d.d)


func _on_partner_state(id: int, s: Dictionary) -> void:
	if id != _partner_id or partner == null:
		return
	partner.push(s)
	if host:
		var p: Array = s.p
		var pos := Vector3(p[0], p[1], p[2])
		var yaw := float(s.y)
		var tile := room.tile_of(pos)
		var ahead := room.tile_of(pos + Vector3(sin(yaw), 0, cos(yaw)) * Player.REACH)
		shift.set_player(id, tile, ahead - tile)


func _on_partner_left() -> void:
	if _partner_id >= 0:
		shift.release(_partner_id)
	if partner:
		partner.queue_free()
		partner = null
	_partner_id = -1
	host = true
	shift.solo = true
	shift.add_player(Match.my_id, room.tile_of(player.global_position))
	view.open_gate()
	hud.say("partner_left")


func _end() -> void:
	if _over:
		return
	_over = true
	player.frozen = true
	player.using = false
	if host and _partner_id >= 0:
		Match.send_snapshot(shift.delta(true))
	Sfx.play("ui_bong")
	hud.slam("SHIFT OVER!", Look.YELLOW)
	await get_tree().create_timer(1.6).timeout
	controls.hide_buttons()
	hud.show_results(shift)


# ── feedback ────────────────────────────────────────────────────────────────

func _on_cue(e: Dictionary) -> void:
	if e.e in ["pick", "catch"] and e.has("at") and room.tile_of(player.global_position).distance_to(e.at) <= 1.5:
		Juice.squash3d(player.avatar)
	var s: Array = SOUNDS.get(e.e, [])
	if not s.is_empty():
		Sfx.play(s[0], s[1] * randf_range(0.96, 1.04))
	match e.e:
		"wrong", "jam":
			_shake(0.18)
			if e.e == "wrong":
				view.shout(_worker_at(e), ["WRONG BIN?!", "NOT A SNACK!", "SORTING IS HARD!", "OOPSIE DAISY!"].pick_random(), Look.DANGER)
			Juice.haptic(25)
		"ship":
			Juice.haptic(30)
			for c in [Look.YELLOW, Look.MINT, Look.PINK, Look.SKY]:  # confetti
				Juice.burst(hud, camera.unproject_position(room.world(e.at) + Vector3(0, 1.2, 0)), c, 10)
			hud.fly_coins(camera.unproject_position(room.world(e.at) + Vector3(0, 1.0, 0)), int(e.coins) / 5)
		"shark":
			_shake(0.4)
			Juice.haptic(80)
			var mine: Vector2i = room.tile_of(player.global_position)
			if absi(mine.x - e.at.x) + absi(mine.y - e.at.y) <= 1:  # bitten!
				_fling(room.world(e.at), Rules.SHARK_FREEZE_S)
				view.shout(player.global_position, "OUCH!!", Look.DANGER)
		"boom":
			_shake(0.6)
			Juice.haptic(100)
			if Vector2(room.tile_of(player.global_position)).distance_to(Vector2(e.at)) <= Rules.BOMB_RADIUS:
				_fling(room.world(e.at), Rules.BOMB_FREEZE_S)
				view.shout(player.global_position, ["MY EYEBROWS!", "KABOOM?!", "WHO DID THAT?"].pick_random(), Look.ORANGE)
		"bonk":
			if int(e.get("who", -1)) == Match.my_id:
				_fling(room.world(e.at), 0.6)
				view.shout(player.global_position, "BONK!", Look.SKY)
		"stun":
			view.shout(room.world(e.at), "DIZZY!", Look.PRIMARY)
		"catch":
			view.shout(room.world(e.at), "NICE CATCH!", Look.MINT)
		"safe":
			view.shout(_worker_at(e), "YEET!" if e.get("out", false) else ["SAVED IT!", "PHEW!", "NOT TODAY, BOOM!"].pick_random(), Look.MINT)
		"steal":
			view.shout(room.world(e.at), "YOINK!", Look.ORANGE)
		"tick":  # your own bomb is about to blow
			var held := shift.held(Match.my_id)
			if held >= 0 and shift.items.has(held) and shift.items[held].k == "bomb" and int(shift.items[held].s) <= 2:
				view.shout(player.global_position, "HOT HOT HOT!", Look.DANGER)
		"drop":
			_shake(0.08)
		"chaos":
			Sfx.music_pitch(1.06)
			Juice.haptic(80)
		"chaos_end":
			Sfx.music_pitch(1.0 + 0.04 * (Rules.level(shift.elapsed) - 1))
		"rot":
			view.shout(room.world(e.at), "EWW, IT ROTS!", Look.MINT)
		"tilt":  # the camera leans with the floor
			var d := int(e.get("d", 0))
			create_tween().tween_property(camera, "rotation:z", -0.035 * d, 0.6).set_trans(Tween.TRANS_BACK)
			view.shout(Vector3(0, 1.5, 0), "FLOOR TILTS %s!" % ("RIGHT" if d > 0 else "LEFT"), Look.ORANGE)
			_shake(0.25)
		"trip":
			_shake(0.2)
			Juice.haptic(40)
			view.shout(room.world(e.at), "BREAKER TRIPPED!", Look.DANGER)
		"final":
			Sfx.music_pitch(1.25)
			Juice.haptic(60)
		"rush":
			Sfx.music("boss")  # RUSH HOUR gets the boss-fight track
			Juice.haptic(60)
		"rush_end":
			Sfx.music(Rules.MAPS[Rules.map].music)
			Sfx.music_pitch(1.0 + 0.04 * (Rules.level(shift.elapsed) - 1))
		"level":
			Sfx.music_pitch(1.0 + 0.04 * (int(e.n) - 1))  # each level a little faster
			Juice.haptic(50)
			_shake(0.2)
			view.shout(player.global_position, ["ZOOM ZOOM!", "LEGS GO BRRR!", "SPEED UP!"].pick_random(), Look.SKY)
		"combo_lost":
			view.shout(_worker_at(e), "COMBO BROKEN!", Look.DANGER)
		"quest":
			Juice.haptic(40)
			_victory_spin()
		"door_open":
			view.shout(room.world(e.at), ["FRESH AIR!", "HAZMAT HERE!", "KNOCK KNOCK!"].pick_random(), Look.SKY)
		"load", "bin":
			Sfx.pop(mini(shift.combo, 8))  # the pop climbs with the combo
			Juice.haptic(10)
			if shift.combo >= 3:  # combo sparks on the machine input
				Fx.burst(view, room.world(e.at) + Vector3(0, 1.3, 0), Look.ORANGE, 8 + shift.combo)
			if COMBO_SHOUTS.has(shift.combo) and int(e.get("who", -1)) == Match.my_id:
				view.shout(player.global_position, COMBO_SHOUTS[shift.combo], Look.PRIMARY)
				_victory_spin()
	hud.on_cue(e)
	if is_instance_valid(tutorial):
		tutorial.on_cue(e)


## A happy little twirl and hop.
func _victory_spin() -> void:
	var a := player.avatar
	var t := a.create_tween().set_parallel()
	t.tween_property(a, "rotation:y", a.rotation.y + TAU, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(a, "position:y", 0.6, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(a, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Where the worker who caused event `e` stands (falls back to the event's tile).
func _worker_at(e: Dictionary) -> Vector3:
	var who := int(e.get("who", -1))
	if who == Match.my_id:
		return player.global_position
	if partner != null and who == _partner_id:
		return partner.global_position
	return room.world(e.at) if e.has("at") else player.global_position


## Blown or bitten: the worker is flung away from `from`, spinning, then lies stunned for `seconds`.
func _fling(from: Vector3, seconds: float) -> void:
	var away := player.global_position - from
	away.y = 0.0
	player.fling(away.normalized() if away.length() > 0.05 else Vector3.BACK)
	_freeze(seconds)


## Knocked stiff by a blast.
func _freeze(seconds: float) -> void:
	player.frozen = true
	player.velocity = Vector3.ZERO
	await get_tree().create_timer(seconds).timeout
	if not _over:
		player.frozen = false


## CHAOS STATE modifiers, creature shoves and the nuclear-waste slowdown on this phone's worker.
func _apply_mayhem(now: float) -> void:
	var mode := shift.mayhem.chaos
	if mode != _chaos_on:
		_chaos_on = mode
		view.decor.dark(mode == "blackout")
		player.floaty = mode == "lowgrav"
	var push := Vector3.ZERO
	if mode == "hurricane":
		push = Vector3(sin(now * 0.9) * 3.2, 0, cos(now * 0.6) * 1.6)
	for c in shift.mayhem.creatures.values():
		if c.k == "elephant":  # it shoves workers out of its way
			var away := player.global_position - room.world_f(c.x, c.y)
			away.y = 0.0
			if away.length() < 1.7:
				push += away.normalized() * 5.0
	player.wind = push
	var held := shift.held(Match.my_id)
	player.speed_mult = Rules.worker_speed(shift.elapsed) * (Rules.NUKE_SLOW if held >= 0 and shift.items.has(held) and shift.items[held].k == "nuke" else 1.0)


func _shake(strength: float) -> void:
	var t := camera.create_tween()
	for i in 4:
		t.tween_property(camera, "h_offset", randf_range(-strength, strength), 0.03)
	t.tween_property(camera, "h_offset", 0.0, 0.04)


const COMBO_SHOUTS := {3: "NICE!", 5: "SPICY!", 8: "ON FIRE!", 12: "TRASH LEGEND!"}
const USE_LABELS := {"shoo": "SHOO", "repair": "FIX", "door": "OPEN"}


func _update_use_label() -> void:
	if _carrying():
		controls.set_label("DROP" if shift.can_place(Match.my_id, _target()) else "THROW")
		return
	var op: Dictionary = shift.use_op(Match.my_id, player.facing_tile(room))
	controls.set_label(USE_LABELS.get(op.get("op", ""), "GRAB"))


func _holder_point(pid: int) -> Vector3:
	if pid == Match.my_id:
		return player.hold_point()
	if partner and pid == _partner_id:
		return partner.hold_point()
	return Vector3.INF


static func _xy(at: Vector2i) -> Array:
	return [at.x, at.y]


static func _tile(v: Variant) -> Vector2i:
	if v is Array and v.size() == 2:
		return Vector2i(int(v[0]), int(v[1]))
	return Vector2i(-99, -99)
