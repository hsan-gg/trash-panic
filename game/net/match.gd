extends Node
## Autoload "Match": the /play socket for co-op shifts. Pairs with a partner (quick match or room code),
## keeps Clock in sync with the server, relays this worker's state and the host's game data.

signal waiting(info: Dictionary)  ## {mode, code?}
signal started(info: Dictionary)  ## {seed, start_at, ends_at, host, solo, players}
signal state(id: int, s: Dictionary)
signal payload(d: Dictionary)  ## from the partner (host events, or guest intents)
signal snapshot(d: Dictionary)
signal partner_left
signal ended
signal failed(code: String)
signal disconnected

const URL := "wss://trash-panic.hasanghorbel.workers.dev/play"
const VERSION := 12  ## the server only pairs players running the same build: bump when the game changes
const URL_ARG := "--play-url="  ## e.g. `-- --play-url=ws://localhost:8787/play` against `wrangler dev`
const SYNC_PINGS := 8
const PING_EVERY_S := 2.0

var my_id := -1
var host_id := -1
var players := {}  ## id -> {id, name, skin}

var _ws := WebSocketPeer.new()
var _hello := {}
var _ping_timer := 0.0
var _ping_id := 0
var _pings := {}
var _best_rtt := 1 << 30
var _was_open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## mode: "quick", "create" or "join" (with a 4-letter code).
## chapter: the map this player picked (Rules.MAPS index, sent as "ch"); the host's pick is played.
func join(player_name: String, skin: int, mode: String, code := "", chapter := 0) -> void:
	_hello = {"t": "hello", "name": player_name, "skin": skin, "v": VERSION, "tut": Profile.tutorial_done(), "mode": mode, "ch": chapter}
	if mode == "join":
		_hello.code = code.to_upper()
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_send(_hello)
		return
	_ws = WebSocketPeer.new()
	_ws.connect_to_url(_url())
	_was_open = false


func leave() -> void:
	_ws.close()
	my_id = -1


func is_host() -> bool:
	return my_id >= 0 and my_id == host_id


func again() -> void:
	_send({"t": "again"})


func send_state(pos: Vector3, yaw: float, anim: int, held: int) -> void:
	_send({"t": "s", "p": _v(pos), "y": snappedf(yaw, 0.01), "a": anim, "h": held})


## Game data for the partner; false when it is too big for one frame.
func send_to(d: Dictionary) -> bool:
	var text := JSON.stringify({"t": "to", "d": d})
	if text.to_utf8_buffer().size() > 500:
		return false
	_send_text(text)
	return true


func send_snapshot(d: Dictionary) -> void:
	_send({"t": "snap", "d": d})


func _process(delta: float) -> void:
	_ws.poll()
	var st := _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _was_open:
			_was_open = true
			_best_rtt = 1 << 30
			for i in SYNC_PINGS:
				_ping()
			_send(_hello)
		while _ws.get_available_packet_count() > 0:
			_on_message(_ws.get_packet().get_string_from_utf8())
		_ping_timer += delta
		if _ping_timer > PING_EVERY_S:
			_ping_timer = 0.0
			_ping()
	elif st == WebSocketPeer.STATE_CLOSED and _was_open:
		_was_open = false
		my_id = -1
		disconnected.emit()


func _on_message(text: String) -> void:
	var msg = JSON.parse_string(text)
	if typeof(msg) != TYPE_DICTIONARY or not msg.has("t"):
		return
	match msg.t:
		"pong":
			_on_pong(msg)
		"welcome":
			my_id = int(msg.id)
		"waiting":
			waiting.emit(msg)
		"start":
			host_id = int(msg.host)
			players.clear()
			for p in msg.players:
				players[int(p.id)] = {"id": int(p.id), "name": str(p.name), "skin": int(p.skin), "ch": int(p.get("ch", 0)), "tut": bool(p.get("tut", true))}
			started.emit(msg)
		"s":
			state.emit(int(msg.id), msg)
		"from":
			if typeof(msg.get("d")) == TYPE_DICTIONARY:
				payload.emit(msg.d)
		"snap":
			if typeof(msg.get("d")) == TYPE_DICTIONARY:
				snapshot.emit(msg.d)
		"left":
			host_id = my_id
			players.erase(int(msg.id))
			partner_left.emit()
		"end":
			ended.emit()
		"error":
			failed.emit(str(msg.get("code", "")))


## Keep the lowest-RTT sample: offset = server_time - (local_send + rtt / 2).
static func clock_offset(sent_ms: int, received_ms: int, server_ms: float) -> int:
	return int(server_ms - (sent_ms + (received_ms - sent_ms) / 2.0))


func _ping() -> void:
	_ping_id += 1
	_pings[_ping_id] = Time.get_ticks_msec()
	_send({"t": "ping", "id": _ping_id, "ct": Time.get_ticks_msec()})


func _on_pong(msg: Dictionary) -> void:
	var id := int(msg.get("id", -1))
	if not _pings.has(id):
		return
	var now := Time.get_ticks_msec()
	var rtt: int = now - _pings[id]
	_pings.erase(id)
	if rtt <= _best_rtt:
		_best_rtt = rtt
		Clock.offset_ms = clock_offset(now - rtt, now, float(msg.st))


func _send(msg: Dictionary) -> void:
	_send_text(JSON.stringify(msg))


func _send_text(text: String) -> void:
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(text)


static func _url() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(URL_ARG):
			return arg.trim_prefix(URL_ARG)
	return URL


static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]
