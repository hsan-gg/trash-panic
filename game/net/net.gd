extends Node
## Autoload "Net": the game's connection to the edge server and the network that carries it.
## The game works on any network (Wi-Fi, 4G, 5G NSA, 5G SA) and shows which one it is on.

signal status_changed
signal online_changed(online: bool)

const SERVER_URL := "wss://trash-panic.hasanghorbel.workers.dev/ws"
const PING_EVERY := 2.0
const MAX_RETRY := 5.0
const CONNECT_TIMEOUT_MS := 15000  # a handshake slower than this is abandoned and retried
const CLOSING_TIMEOUT_MS := 2000  # a close that never completes (the network vanished) is abandoned
const HINT_AFTER_S := 10.0  # offline this long with a network present: say the connection may have no internet
const DEAD_TIMEOUT_MS := 9000  # an open socket the server stopped answering is abandoned
const PONG_TIMEOUT_MS := 6000  # an open socket with no pong for this long counts as lost
## Network states with no network at all: no connection can be made.
const NO_LINK := ["NONE"]

var net_type := "WEB"  # browsers can't see the radio; NetInfo overwrites this on Android
var rtt_ms := -1
var connected := false
var offline_s := 0.0  # how long the game has been offline, for the connection screen
var online := false  # connected and the server is answering; the game can only be played while true

var _ws := WebSocketPeer.new()
var _plugin: Object
var _ping_id := 0
var _ping_sent := {}  # ping id -> Time.get_ticks_msec() when sent
var _ping_timer := 0.0
var _retry_in := 0.0
var _retry_delay := 0.5
var _last_pong_ms := 0
var _net_handle := 0  # which network the current socket was opened on
var _last_state := WebSocketPeer.STATE_CLOSED
var _state_since_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep working while the game is paused behind the gate
	if OS.get_name() == "iOS":
		net_type = "OTHER"  # no radio info on iOS (the NetInfo plugin is Android only)
	if Engine.has_singleton("NetInfo"):
		_plugin = Engine.get_singleton("NetInfo")
		_plugin.net_changed.connect(_on_net_changed)
		_plugin.start()
		net_type = _plugin.getNetType()
		_net_handle = _plugin.getNetworkHandle()
		get_tree().on_request_permissions_result.connect(_on_permission_result)
		OS.request_permission("android.permission.READ_PHONE_STATE")
	if _link_ok():
		_connect()


func _process(delta: float) -> void:
	_ws.poll()
	var state := _ws.get_ready_state()
	var now_ms := Time.get_ticks_msec()
	if state != _last_state:
		_last_state = state
		_state_since_ms = now_ms
	if should_drop(state, now_ms - _state_since_ms, silence_ms(now_ms, _last_pong_ms, _state_since_ms)):
		_drop_socket()
		state = WebSocketPeer.STATE_CLOSED
	offline_s = 0.0 if online else offline_s + delta
	_update_online()
	match state:
		WebSocketPeer.STATE_OPEN:
			if not connected:
				connected = true
				if not OS.has_feature("web"):
					_ws.set_no_delay(true)  # only valid once the socket is open; unsupported in the browser
				_last_pong_ms = Time.get_ticks_msec()
				_retry_delay = 0.5
				_ping_timer = PING_EVERY  # ping right away so RTT shows immediately
				status_changed.emit()
			while _ws.get_available_packet_count() > 0:
				_on_message(_ws.get_packet().get_string_from_utf8())
			_ping_timer += delta
			if _ping_timer >= PING_EVERY:
				_ping_timer = 0.0
				_send_ping()
		WebSocketPeer.STATE_CLOSED:
			if connected:
				connected = false
				rtt_ms = -1
				status_changed.emit()
			_retry_in -= delta
			if _retry_in <= 0.0 and _link_ok():
				_retry_delay = min(_retry_delay * 2.0, MAX_RETRY)
				_retry_in = _retry_delay
				_connect()


## Skip the reconnect wait, e.g. when the player taps RETRY.
func retry_now() -> void:
	_retry_in = 0.0
	_retry_delay = 0.5


func badge() -> Dictionary:
	return badge_for(net_type)


## Text + colour for FRU-01's signal meter. Green is reserved for real 5G SA.
static func badge_for(type: String) -> Dictionary:
	match type:
		"5G_SA": return {"text": "5G SA", "color": Color("#7fd68a")}
		"5G_NSA": return {"text": "5G NSA", "color": Color("#8fd0c0")}
		"4G": return {"text": "4G", "color": Color("#d8b040")}
		"3G": return {"text": "3G", "color": Color("#d8b040")}
		"CELL": return {"text": "MOBILE DATA", "color": Color("#d8b040")}
		"WIFI": return {"text": "WI-FI", "color": Color("#a9cfd6")}
		"ETHERNET": return {"text": "ETHERNET", "color": Color("#a9cfd6")}
		"WEB": return {"text": "BROWSER", "color": Color("#a3a4a6")}
		"NONE": return {"text": "NO NETWORK", "color": Color("#b03a2e")}
		"OTHER": return {"text": "ONLINE", "color": Color("#a9cfd6")}
	return {"text": "NET ?", "color": Color("#a3a4a6")}


## What to tell the player while the game can't reach the server.
static func gate_message_for(type: String, was_online: bool, offline_s := 0.0) -> String:
	if type != "NONE" and offline_s > HINT_AFTER_S:
		return "%s is connected, but the factory server can't be reached.\nCheck that this connection has internet access." % badge_for(type).text
	match type:
		"NONE":
			return "No network connection.\nConnect to Wi-Fi or turn on mobile data to play."
	if was_online:
		return "Reconnecting to the factory server...\nThe game resumes by itself."
	return "Contacting the factory server...\nTRASH PANIC! is played online."


## How long the server has been quiet on this connection. A new connection starts a fresh clock:
## pongs from an earlier connection must not make it look dead the moment it opens.
static func silence_ms(now_ms: int, last_pong_ms: int, state_since_ms: int) -> int:
	return now_ms - maxi(last_pong_ms, state_since_ms)


## A socket stuck in a state that should be brief, or silent for too long, is replaced rather than waited on.
static func should_drop(state: int, state_age_ms: int, pong_age_ms: int) -> bool:
	match state:
		WebSocketPeer.STATE_CONNECTING: return state_age_ms > CONNECT_TIMEOUT_MS
		WebSocketPeer.STATE_CLOSING: return state_age_ms > CLOSING_TIMEOUT_MS
		WebSocketPeer.STATE_OPEN: return pong_age_ms > DEAD_TIMEOUT_MS
	return false


## Abandon the current socket (freeing it closes the connection) and start over with a fresh one.
func _drop_socket() -> void:
	_ws = WebSocketPeer.new()
	_last_state = WebSocketPeer.STATE_CLOSED
	retry_now()


## The game is online only while the socket is open and the server answered recently.
static func is_online(socket_open: bool, link_ok: bool, now_ms: int, last_pong_ms: int) -> bool:
	return socket_open and link_ok and now_ms - last_pong_ms < PONG_TIMEOUT_MS


func _update_online() -> void:
	var now := is_online(connected, _link_ok(), Time.get_ticks_msec(), _last_pong_ms)
	if now != online:
		online = now
		online_changed.emit(online)
		status_changed.emit()


func _connect() -> void:
	var err := _ws.connect_to_url(SERVER_URL)
	if err != OK:
		push_warning("Net: connect_to_url failed (%s)" % error_string(err))
		return


func _send_ping() -> void:
	_ping_id += 1
	_ping_sent[_ping_id] = Time.get_ticks_msec()
	_ws.send_text(JSON.stringify({"t": "ping", "id": _ping_id, "net": net_type}))
	for old_id in _ping_sent.keys():  # forget pings that never came back
		if old_id < _ping_id - 5:
			_ping_sent.erase(old_id)


func _on_message(text: String) -> void:
	var msg = JSON.parse_string(text)
	if typeof(msg) != TYPE_DICTIONARY or not msg.has("t"):
		return  # ignore anything malformed from the network
	if msg.t == "pong" and _ping_sent.has(int(msg.get("id", -1))):
		_last_pong_ms = Time.get_ticks_msec()
		rtt_ms = _last_pong_ms - _ping_sent[int(msg.id)]
		_ping_sent.erase(int(msg.id))
		status_changed.emit()


func _link_ok() -> bool:
	return not net_type in NO_LINK


func _on_net_changed(type: String) -> void:
	net_type = type
	# A socket stays on the network it was opened on. When the phone switches network (say Wi-Fi to
	# 5G) or loses it, reopen the connection instead of waiting for the old one to time out.
	var handle: int = _plugin.getNetworkHandle()
	if handle != _net_handle or not _link_ok():
		_net_handle = handle
		_drop_socket()
	status_changed.emit()


func _on_permission_result(permission: String, granted: bool) -> void:
	if permission == "android.permission.READ_PHONE_STATE" and granted:
		_plugin.refreshTelephony()
